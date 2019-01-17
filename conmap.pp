unit ConMap;
{
	GearHead: Arena, a roguelike mecha CRPG
	Copyright (C) 2005 Joseph Hewitt

	This library is free software; you can redistribute it and/or modify it
	under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation; either version 2.1 of the License, or (at
	your option) any later version.

	The full text of the LGPL can be found in license.txt.

	This library is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
	General Public License for more details. 

	You should have received a copy of the GNU Lesser General Public License
	along with this library; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
}

interface

uses crt,gears,locale;

const
	{ DISPLAYSHOT CONSTANTS }
	SHOT_Hit = 0;
	SHOT_Dodge = 1;
	SHOT_Parry = 2;

	TerrGfx: Array [1..NumTerr] of Char = (
		'.', '=', '#', '=', '%',
		'.', '.', '^', '^', '^',
		'.', '#', '#', '.', '#',
		'.', '.', '#', '+', '.',
		'=', '-', '#', '#', '.',
		'_', '#', '.', '#', '.',
		'#', '$', '#', '#', '#',
		'$', '$', '$', '.', '=',
		'-', '#'
	);
	TerrColor: Array [1..NumTerr] of Byte = (
		Green, LightGreen, LightGreen, LightBlue, DarkGray,
		LightGray, Cyan, DarkGray, LightGray, White,
		DarkGray, LightGray, LightGray, DarkGray, DarkGray,
		LightGray, Brown, Red, Cyan, LightBlue,
		Blue, Blue, White, Yellow, Red,
		Brown, Brown, Blue, Cyan, LightGray,
		Brown,LightGreen,Magenta,LightCyan,Blue,
		LightMagenta,Brown,Cyan,Yellow,Brown,
		Magenta,LightMagenta
	);


Function TeamColor( GB: GameBoardPtr; G: GearPtr ): Byte;
Function ScreenX( X: Integer ): Integer;
Function ScreenY( Y: Integer ): Integer;
Function OnTheScreen( X , Y: Integer ): Boolean;
Function OnTheScreen( Mek: GearPtr ): Boolean;
Function NeedsRecentering( X,Y: Integer ): Boolean;

procedure DisplayMap( gb: GameBoardPtr );

Procedure RedrawTile( gb: GameBoardPtr; X,Y: Integer );
procedure RedrawTile( gb: GameBoardPtr; Mek: GearPtr );

procedure IndicateTile( GB: GameBoardPtr; X , Y: Integer );
procedure IndicateTile( GB: GameBoardPtr; Mek: GearPtr );

Procedure RevealMek( GB: GameBoardPtr; Mek,Spotter: GearPtr );
Procedure VisionCheck( GB: GameBoardPtr; Mek: GearPtr );

Procedure DeployMek( GB: GameBoardPtr; Mek: GearPtr; PutOnMap: Boolean );
Procedure DeployMek( GB: GameBoardPtr; Mek,Pilot: GearPtr; Team: Integer );
Function LocateMekByUID( GB: GameBoardPtr; UID: Integer ): GearPtr;

Function TimeString( ComTime: LongInt ): String;
Procedure UpdateCombatDisplay( GB: GameBoardPtr );
Procedure GFCombatDisplay( GB: GameBoardPtr );

Procedure FocusOnMek( GB: GameBoardPtr; Mek: GearPtr );

Function DisplayEffectAnimations( GB: GameBoardPtr; N: Integer ): Boolean;

Procedure DisplayConsoleHistory( GB: GameBoardPtr );

Procedure ProcessMovement( GB: GameBoardPtr; Mek: GearPtr );

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
Function ReadCampaign( var F: Text ): CampaignPtr;

Procedure BeginTurn( GB: GameBoardPtr; M: GearPtr );


implementation

uses ability,action,damage,effects,gearutil,ghprop,menugear,movement,
     texutil,ui4gh,congfx,context;

const
	OriginX: Integer = 1;	{ These constants tell what tile is being }
	OriginY: Integer = 1;	{ displayed in the upper left corner of the }
				{ map area. }



	FROZEN_MAP_CONTINUE = 1;
	FROZEN_MAP_SENTINEL = -1;


Function TeamColor( GB: GameBoardPtr; G: GearPtr ): Byte;
	{ Select a good color based upon the team this }
	{ gear belongs to. }
var
	T,color: LongInt;
begin
	if ( G = Nil ) or ( GB = Nil ) then begin
		{ No gear provided - Neutral Gray. }
		color := NeutralGrey;

	end else if not GearOperational( G ) then begin
		{ Nonfunctioning gear. Color = DarkGrey. }
		color := DarkGray;

	end else begin
		T := NAttValue( G^.NA , NAG_Location , NAS_Team );

		if T = NAV_DefPlayerTeam then begin
			{ Player team. Color = Blue. }
			color := PlayerBlue;

		end else if AreEnemies( GB , NAV_DefPlayerTeam , T ) then begin
			{ Enemy team. Color = Red. }
			color := EnemyRed;

		end else if AreAllies( GB , NAV_DefPlayerTeam , T ) then begin
			{ Ally team. Color = Purple. }
			color := AllyPurple;

		end else begin
			{ Neutral team. Color = Brown. }
			color := NeutralBrown;

		end;
	end;
	TeamColor := Color;
end;


Function ScreenX( X: Integer ): Integer;
	{ Return the screen coordinates of map column X. }
begin
	ScreenX := X - OriginX + ScreenZone[ZONE_Map,1];
end;

Function ScreenY( Y: Integer ): Integer;
	{ Return the screen coordinates of map row Y. }
begin
	ScreenY := Y - OriginY + ScreenZone[ZONE_Map,1];
end;

Function OnTheScreen( X , Y: Integer ): Boolean;
	{ This function returns TRUE if the specified point is visible }
	{ on screen, FALSE if it isn't. }
var
	SX,SY: Integer;		{ Find Screen X and Screen Y and see if it's in the map area. }
begin
	SX := ScreenX( X );
	SY := ScreenY( Y );
	if ( SX >= ScreenZone[ZONE_Map,1] ) and ( SX <= ScreenZone[ZONE_Map,3] ) and ( SY >= ScreenZone[ZONE_Map,2] ) and ( SY <= ScreenZone[ZONE_Map,4] ) then begin
		OnTheScreen := True;
	end else begin
		OnTheScreen := False;
	end;
end;

Function OnTheScreen( Mek: GearPtr ): Boolean;
	{ Check to see whether or not the specified mek is visible on screen. }
begin
	OnTheScreen := OnTheScreen( NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) );
end;

Function MapDisplayHeight: Integer;
	{ Return the height of the map display, in tiles. }
begin
	MapDisplayHeight := ScreenZone[ZONE_Map,4] - ScreenZone[ZONE_Map,2] + 1;
end;

Function MapDisplayWidth: Integer;
	{ Return the width of the map display, in tiles. }
begin
	MapDisplayWidth := ScreenZone[ZONE_Map,3] - ScreenZone[ZONE_Map,1] + 1;
end;

Procedure RecenterDisplay( X , Y: Integer );
	{ Change the display so that point X,Y will be on screen. }
begin
	OriginX := X - (MapDisplayWidth div 2);
	OriginY := Y - (MapDisplayHeight div 2);

	if OriginX < 1 then
		OriginX := 1
	else if OriginX > (XMax - MapDisplayWidth) then
		OriginX := XMax - MapDisplayWidth + 1;

	if OriginY < 1 then
		OriginY := 1
	else if OriginY > (YMax - MapDisplayHeight) then
		OriginY := YMax - MapDisplayHeight + 1;

end;

Function NeedsRecentering( X,Y: Integer ): Boolean;
	{ Check point X,Y to see whether or not the screen needs to be }
	{ centered upon it. }
var
	RC: Boolean;
begin
	{ Start by assuming FALSE, then checking the various cases }
	{ to see if a recentering is called for. }
	RC := False;

	{The screen will be recentered if ScreenX or ScreenY are within 3 }
	{ squares of the edge of the display area, and that said edge is not}
	{the edge of the map.}
	if ( ScreenX( X ) <= 3 ) and ( OriginX > 1) then
		RC := True
	else if ( ScreenX( X ) >= (MapDisplayWidth - 3)) and ( OriginX < (XMax - MapDisplayWidth + 1)) then
		RC := True;

	if ( ScreenY( Y ) <= 3 ) and ( OriginY > 1) then
		RC := True
	else if ( ScreenY( Y ) >= (MapDisplayHeight - 3)) and (OriginY < (YMax - MapDisplayHeight + 1)) then
		RC := True;

	NeedsRecentering := RC;
end;


Procedure DrawMapImage( Gfx: Char; X,Y: Integer; C: Byte );
	{ Draw the specified image at the specified map coordinates. }
begin
	if not OnTheScreen( X , Y ) then exit;
	GotoXY( ScreenX( X ) , ScreenY( Y ) );
	TextColor( C );
	TextBackground( StdBlack );
	Write( Gfx );
end;

Procedure DrawRvsImage( Gfx: Char; X,Y: Integer; C: Byte );
	{ Draw the specified image at the specified map coordinates. }
begin
	if not OnTheScreen( X , Y ) then exit;
	GotoXY( ScreenX( X ) , ScreenY( Y ) );
	TextColor( StdBlack );
	if ( C = Black ) or ( C = DarkGray ) then C := Blue;
	TextBackground( C );
	Write( Gfx );
end;

procedure DrawMekX( GB: GameBoardPtr; Mek: GearPtr; Hilight: Boolean );
	{ Draw a mecha indicator at map location X , Y with }
	{ direction D. Got all that? }
var
	GFX: Char;
	roguechar: String;	{ ASCII display character. }
	Color: Byte;
	X,Y: Integer;
begin
	{ Error check- make sure we have a valid mek. }
	if Mek = Nil then Exit;
	if not OnTheScreen( Mek ) then Exit;

	{ Extract the position information. }
	X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );

	{ Error check - make sure the mecha is on the map. }
	if not OnTheMap(X,Y) then exit;

	{ Make sure the mek is visible to the player... }
	if MekVisible( gb , Mek ) then begin
		roguechar := SAttValue( Mek^.SA , 'ROGUECHAR' );

		{ If the mek is destroyed, draw wreckage instead of the regular image. }
		if ( Mek^.G <> GG_MetaTerrain ) and not IsMasterGear( Mek ) then begin
			Gfx := '-';
			Color := NeutralGrey;
		end else if Destroyed( Mek ) then begin
			Gfx := '%';
			Color := NeutralGrey;
		end else begin
			{ Pick an appropriate character for the mek. }
			{ If the mek is at a smaller scale than the map, }
			{ pick a smaller character. }
			if Mek^.Scale < ( GB^.Scale - 3 ) then begin
				Gfx := ',';
			end else if Mek^.Scale < GB^.Scale then begin
				Gfx := 'o';
			end else if roguechar <> '' then begin
				Gfx := roguechar[1];
			end else if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( NumActiveMasters( GB , NAV_DefPlayerTeam ) = 1 ) then begin
				Gfx := '@';
			end else begin
				Gfx := GearName( Mek )[1];
			end;
			if Mek^.G = GG_MetaTerrain then begin
				case Mek^.S of
					GS_MetaCloud:	if SAttValue( Mek^.SA , 'EFFECT' ) = '' then Color := LightGray
							else Color := LightGreen;
					GS_MetaFire:	Case Random( 3 ) of
								0,1:	Color := LightRed;
								2:	Color := Yellow;
							end;
				else Color := Yellow;
				end;

			end else begin
				Color := TeamColor( GB , Mek );
			end;
		end;

		if HiLight then DrawMapImage( Gfx , X , Y , StdWhite )
		else DrawMapImage( Gfx , X , Y , Color );	
	end;
end;

procedure DrawMek( gb: GameBoardPtr; Mek: GearPtr );
	{ Draw a mecha indicator at map location X , Y with }
	{ direction D. Got all that? }
begin
	DrawMekX( gb , Mek , False );
end;

procedure PlotTerrainX( gb: GameBoardPtr; X,Y: Integer; Hilight: Boolean );
	{ Display the terrain in location X,Y. }
	{ This is the X-tended version of the function, with more features. }
begin
	{ Error check - make sure the requested tile is on the map, }
	{ and is also on the screen. }
	if not OnTheMap( X , Y ) then exit;
	if not OnTheScreen( X , Y ) then exit;

	{ If this tile is marked as visible better show it. }
	{ Otherwise draw a blank spot. }
	if gb^.Map[ X , Y ].Visible then begin
		if Hilight then DrawRvsImage( TerrGfx[ gb^.map[X,Y].terr ] , X , Y , TerrColor[ gb^.map[X,Y].terr ] )
		else DrawMapImage( TerrGfx[ gb^.map[X,Y].terr ] , X , Y , TerrColor[ gb^.map[X,Y].terr ] );
	end else begin
		if Hilight then DrawRvsImage( '?' , X , Y , Blue )
		else DrawMapImage( ' ' , X , Y , Black );
	end;
end;

procedure PlotTerrain( gb: GameBoardPtr; X,Y: Integer );
	{ Display the terrain in location X,Y. }
begin
	PlotTerrainX( gb , X , Y , False );
end;

procedure DisplayMap( gb: GameBoardPtr );
	{ Actually display the map. }
var
	X,Y: Integer;
	N,S,W,E: Boolean;
	M: GearPtr;
begin
	{ Begin by clearing the screen & doing the border. }
	{ Figure out in which directions the map extends. }
	N := OriginY > 1;
	W := OriginX > 1;
	E := OriginX <= ( XMax - MapDisplayWidth );
	S := OriginY <= ( YMax - MapDisplayHeight );
	DrawMapBorder( N , E , S , W );

	{ Display all terrain. }
	for X := 0 to ( MapDisplayWidth - 1 ) do begin
		for Y := 0 to ( MapDisplayHeight - 1 ) do begin
			PlotTerrain( gb , X + OriginX , Y + OriginY );
		end;
	end;

	{ Display all stationary objects... }
	{ i.e. root level nonmaster gears. }
	{ Items only get displayed if the tile they're in is already visible. }
	M := gb^.Meks;
	while M <> Nil do begin
		if not IsMasterGear(M) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			if OnTheMap( X , Y ) and GB^.Map[X,Y].Visible then begin
				DrawMek( GB , M );
			end;
		end;
		M := M^.Next;
	end;

	{ Display the mecha, i.e. the master gears. }
	M := gb^.Meks;
	while M <> Nil do begin
		if IsMasterGear(M) then begin
			DrawMek( GB , M );
		end;
		M := M^.Next;
	end;

	{ While we're here, redo the shadow map. }
	UpdateShadowMap( GB );
end;

Procedure RedrawTileX( gb: GameBoardPtr; X,Y: Integer; Hilight: Boolean );
	{ Redraw the tile at X,Y including all mecha and }
	{ stuff that might be occupying this spot. }
var
	M: GearPtr;	{ Mecha, maybe... }
begin
	if OnTheMap( X , Y ) and OnTheScreen( X , Y ) then begin
		{ Seek a master gear at this spot, since that'll appear }
		{ on top of everything else. }
		M := FindVisibleBlockerAtSpot( GB , X , Y );

		{ If there's a visible gear here, plot that. }
		if M <> Nil then begin
			DrawMekX( GB , M , Hilight );

		end else begin
			{ No master here, check for an item. }
			M := FindVisibleItemAtSpot( GB , X , Y );

			if ( M <> Nil ) and GB^.Map[X,Y].Visible then begin
				{ Draw the item. }
				DrawMekX( GB , M , Hilight );
			end else begin
				{ If not, just display the terrain. }
				PlotTerrainX( gb , X , Y , Hilight );
			end;
		end;
	end;
end;

Procedure RedrawTile( gb: GameBoardPtr; X,Y: Integer );
	{ Just call the above procedure with a Hilight value of FASLE. }
begin
	RedrawTileX( gb , X , Y , False );
end;

procedure RedrawTile( gb: GameBoardPtr; Mek: GearPtr );
	{ Display the tile containing the listed gear. }
	{ If the tile is not currently visible, the map will be recentered. }
var
	Team: Integer;
	P: Point;
begin
	team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
	P := GearCurrentLocation( Mek );
	if ( Team = NAV_DefPlayerTeam ) and NeedsRecentering( P.X , P.Y ) then begin
		RecenterDisplay( P.X , P.Y );
		DisplayMap( gb );
	end else begin
		RedrawTile( gb , P.X , P.Y );
	end;
end;

procedure IndicateTile( GB: GameBoardPtr; X , Y: Integer );
	{Indicate the desired tile with a rectangle of the requested color. }
begin
	if not OnTheMap( X , Y ) then exit;
	if NeedsRecentering( X , Y ) then begin
		RecenterDisplay( X , Y );
		DisplayMap( gb );
	end;
	RedrawTileX( GB , X , Y , True );
    GotoXY( ScreenX( X ), ScreenY( Y ) );
end;

procedure IndicateTile( GB: GameBoardPtr; Mek: GearPtr );
	{ Indicate the tile containing the listed gear. }
var
	team: Integer;
begin
	team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
	if MekVisible( GB , Mek ) and ( OnTheScreen( Mek ) or ( Team = NAV_DefPlayerTeam ) ) then IndicateTile( GB , NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) );
end;

Procedure RevealMek( GB: GameBoardPtr; Mek,Spotter: GearPtr );
	{ This mek has been spotted. Light it up. }
var
	team: Integer;
begin
	team := NAttValue( Spotter^.NA , NAG_Location , NAS_Team );
	SetNAtt( Mek^.NA , NAG_Visibility , Team , NAV_Spotted );
	RedrawTile( gb , Mek );
end;

Procedure CheckVisibleArea( GB: GameBoardPtr; Mek: GearPtr );
	{ Expand the visual area around this model. }
var
	P: Point;
	X,Y,MZ,R,Obs: Integer;
begin
	P := GearCurrentLocation( Mek );
	R := MappingRange( Mek , GB^.Scale );
	MZ := MekAltitude( GB , Mek );

	{ Look through every tile within range. If it's on the map and }
	{ not yet revealed, do a check to see if it should be. }
	for X := ( P.X - R ) to ( P.X + R ) do begin
		for Y := ( P.Y - R ) to ( P.Y + R ) do begin
			if OnTheMap( X , Y ) and not GB^.Map[X,Y].Visible then begin
				{ This tile will be revealed if Range + Obscurement }
				{ is less than or equal to the mapping radius. }
				Obs := CalcObscurement( X , Y , TerrMan[ GB^.Map[ X , Y ].Terr ].Altitude , P.X , P.Y , MZ , GB );
				if (( Range( P.X , P.Y , X , Y ) + Obs ) <= R ) and ( Obs <> -1 ) then begin
					GB^.Map[X,Y].Visible := True;
					RedrawTile( GB , X , Y );
				end;
			end;
		end;
	end;
end;

Procedure VisionCheck( GB: GameBoardPtr; Mek: GearPtr );
	{ Perform a sensor check for MEK. It might spot hidden enemy }
	{ units; it may get spotted by enemy units itself. }
var
	M2: GearPtr;
begin
	if ( Mek = Nil ) or ( not GearOperational( Mek ) ) or ( not OnTheMap( Mek ) ) then exit;

	{ Start by assuming that the mek will be hidden after this. }
	{ Strip all of its visibility tokens. }
	StripNAtt( Mek , NAG_Visibility );

	M2 := GB^.Meks;
	while M2 <> Nil do begin
		{ We are only interested in this other mek if it's an }
		{ enemy of the one we're checking. }
		if OnTheMap( M2 ) then begin
			if not MekCanSeeTarget( gb , Mek , M2 ) then begin

				{ If this enemy mecha has not yet been spotted, }
				{ there's a chance it will become visible. }
				if IsMasterGear( M2 ) and CheckLOS( GB , Mek , M2 ) then begin
					{ M2 has just been spotted. }
					RevealMek( GB , M2 , Mek );
				end;
			end;

			{ There is also a chance that M2 might spot Mek. }
			if IsMasterGear( M2 ) and GearOperational( M2 ) and not MekCanSeeTarget( GB , M2 , Mek ) then begin
				if CheckLOS( GB , M2 , Mek ) then RevealMek( GB , Mek , M2 );
			end;
		end;

		M2 := M2^.Next;
	end;

	if (NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam) or (NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam) then begin
		CheckVisibleArea( GB , Mek );
	end;

	{ Redraw the spotter's tile. }
	RedrawTile( gb , Mek );
end;


Procedure DeployMek( GB: GameBoardPtr; Mek: GearPtr; PutOnMap: Boolean );
	{ Stick the provided MEK onto the game board. Assign a UID, }
	{ and set the default orders for MEK's team. }
	{ PRECONDITION: Mek must be unlinked. }
var
	Team: GearPtr;
	P: Point;
begin
	if ( GB = Nil ) or ( Mek = Nil ) then Exit;

	{ Find the team for this model. }
	Team := LocateTeam( GB , NAttValue( Mek^.NA , NAG_Location , NAS_Team ) );

	{ Gear up the mek. }
	if PutOnMap then GearUp( Mek );

	{ Determine the X and Y values for everything. }
	{ If, according to the PutOnMap parameter, we aren't supposed to put }
	{ this model on the map, set X and Y to 0. }
	{ If the model has X and Y already defined within the map boundaries, }
	{ place it on the map at its specified location. }
	{ Otherwise, determine a good spot to place this mek based upon its }
	{ assigned team. }
	if not PutOnMap then begin
		SetNAtt( mek^.NA , NAG_Location , NAS_X , 0 );
		SetNAtt( mek^.NA , NAG_Location , NAS_Y , 0 );

	end else if OnTheMap( Mek ) and ( SAttValue( Mek^.SA , 'HOME' ) = '' ) then begin
		{ Just set a random direction. }
		SetNAtt( mek^.NA , NAG_Location , NAS_D , Random( 8 ) );

	end else begin
		P := FindDeploymentSpot( GB , Mek );
		SetNAtt( mek^.NA , NAG_Location , NAS_X , P.X );
		SetNAtt( mek^.NA , NAG_Location , NAS_Y , P.Y );
		SetNAtt( mek^.NA , NAG_Location , NAS_D , Random( 8 ) );
	end;


	{ Assign a unique ID for this model. }
	SetNAtt( mek^.NA , NAG_EpisodeData, NAS_UID, MaxIdTag( GB^.Meks , NAG_EpisodeData, NAS_UID ) + 1 );

	{ Stick mek on board. }
	Mek^.Next := gb^.Meks;
	gb^.Meks := Mek;

	{ Set default orders. }
	if Team <> Nil then begin
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , Team^.Stat[ STAT_TeamOrders ] );
	end;
end;

Procedure DeployMek( GB: GameBoardPtr; Mek,Pilot: GearPtr; Team: Integer );
	{ Insert the supplied pilot into the supplied mecha, then insert both }
	{ into the provided scenario. Supply UIDs to mek and pilot. }
	{ PRECONDITION: Mek and Pilot are both unlinked gears. }
begin
	if ( GB = Nil ) or ( Mek = Nil ) or ( Pilot = Nil ) then Exit;

	{ Set the correct values for everything. }
	SetNAtt( mek^.NA , NAG_Location , NAS_Team , Team );

	SetNAtt( Pilot^.NA , NAG_Location , NAS_Team , Team );
	SetNAtt( Pilot^.NA , NAG_EpisodeData, NAS_UID, MaxIdTag( GB^.Meks , NAG_EpisodeData, NAS_UID ) + 2 );

	{ Locate cockpit, and install pilot. }
	if not BoardMecha( Mek , Pilot ) then begin
		{ PILOT couldn't be installed in MEK. }
		{ Stick PILOT off the map. }
		DeployMek( GB , Pilot, False );
	end;

	DeployMek( gb , Mek , True );
end;

Function LocateMekByUID( GB: GameBoardPtr; UID: Integer ): GearPtr;
	{ Search through the list of mecha associated with this scenario, and }
	{ return the mecha with the given Unique ID. Return Nil if it can't }
	{ be found. }
begin
	{ Error check - UID 0 is impossible. }
	if UID = 0 then Exit( Nil );

	{ Return whatever we found. }
	LocateMekByUID := SeekGearByIDTag( GB^.Meks , NAG_EpisodeData , NAS_UID , UID );
end;

Function TimeString( ComTime: LongInt ): String;
	{ Create a string to express the time listed in COMTIME. }
var
	msg: String;
	S,M,H,D: LongInt;	{ Seconds, Minutes, Hours, Days }
begin
	S := ComTime mod 60;
	M := ( ComTime div 60 ) mod 60;
	H := ( ComTime div AP_Hour ) mod 24;
	D := ComTime div AP_Day;

	msg := Bstr( H ) + ':' + WideStr( M , 2 ) + ':' + WideStr( S , 2 ) + MsgString( 'CLOCK_days' ) + BStr( D );
	TimeString := msg;
end;

Procedure UpdateCombatDisplay( GB: GameBoardPtr );
	{ Just update the screen; don't redraw everything. }
begin
	CMessage( TimeString( GB^.ComTime ) , ZONE_Clock , White );
end;

Procedure GFCombatDisplay( GB: GameBoardPtr );
	{ Do each of the standard GearFitr display elements. }
begin
	DisplayMap( GB );
	UpdateCombatDisplay( GB );
end;

Procedure FocusOnMek( GB: GameBoardPtr; Mek: GearPtr );
	{ Recenter the display on the indicated mecha. }
var
	P: Point;
begin
	if ( Mek <> Nil ) and ( GB <> Nil ) then begin
		P := GearCurrentLocation( Mek );
		RecenterDisplay( P.X , P.Y );
		DisplayMap( gb );
	end;
end;

Function ProcessShotAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
	{ Process this shot. Return TRUE if the missile }
	{ is visible on the screen, FALSE otherwise. }
	{ V = Timer }
	{ Stat 1 , 2 , 3 -> X1 , Y1 , Z1 }
	{ Stat 4 , 5 , 6 -> X2 , Y2 , Z2 }
const
	X1 = 1;
	Y1 = 2;
	X2 = 4;
	Y2 = 5;
var
	P: Point;
begin
	{ Redraw the tile from last time. }
	P := SolveLine( AnimOb^.Stat[ X1 ] , AnimOb^.Stat[ Y1 ] , AnimOb^.Stat[ X2 ] , AnimOb^.Stat[ Y2 ] , AnimOb^.V );
	RedrawTile( GB , P.X , P.Y );

	{ Increase the counter, and find the next spot. }
	Inc( AnimOb^.V );
	P := SolveLine( AnimOb^.Stat[ X1 ] , AnimOb^.Stat[ Y1 ] , AnimOb^.Stat[ X2 ] , AnimOb^.Stat[ Y2 ] , AnimOb^.V );

	{ If this is the destination point, then we're done. }
	if ( P.X = AnimOb^.Stat[ X2 ] ) and ( P.Y = AnimOb^.Stat[ Y2 ] ) then begin
		RemoveGear( AnimList , ANimOb );
		P.X := 0;

	{ If this is not the destination point, draw the missile. }
	end else begin
		{Display bullet...}
		DrawMapImage( '+' , P.X , p.Y , LightRed );
	end;

	ProcessShotAnimation := OnTheScreen( P.X , P.Y );
end;

Function ProcessPointAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
	{ Process this effect. Return TRUE if the blast }
	{ is visible on the screen, FALSE otherwise. }
	{ V = Timer }
	{ Stat 1 , 2 , 3 -> X , Y , Z }
const
	X = 1;
	Y = 2;
	NumBlastColor = 8;
	BlastColor: Array [0..NumBlastColor-1] of Byte = (
		Red, LightRed, LightRed, LightMagenta, Yellow, White,
		LightRed, Yellow
	);
var
	gfx: Char;
	c: Byte;
	it: Boolean;
begin
	if AnimOb^.V < 3 then begin
		case AnimOb^.S of
		GS_DamagingHit: begin
				gfx := '*';
				c := LightRed;
				end;
		GS_ArmorDefHit: begin
				gfx := '*';
				c := DarkGray;
				end;
		GS_Parry:	begin
				gfx := '!';
				c := DarkGray;
				end;
		GS_Dodge:	begin
				gfx := '-';
				c := DarkGray;
				end;
		GS_Backlash:	begin
				gfx := '*';
				c := Yellow;
				end;
		GS_AreaAttack:	begin
				gfx := '*';
				c := BlastColor[ Random( NumBlastColor ) ];
				end;
		end;
		DrawMapImage( gfx , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , c );

		{ Increment the counter. }
		Inc( AnimOb^.V );

		it := OnTheScreen( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] );
	end else begin
		RedrawTile( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] );
		RemoveGear( AnimList , AnimOb );
		it := False;
	end;

	ProcessPointAnimation := it;
end;

Procedure ProcessAnimations( GB: GameBoardPtr; var AnimList: GearPtr );
	{ Display all the queued animations, deleting them as we go along. }
var
	AnimOb,A2: GearPtr;
	DelayThisFrame,PointDelay: Boolean;
begin
	{ Keep processing until we run out of animation objects. }
	while AnimList <> Nil do begin
		AnimOb := AnimList;

		{ Assume there'll be no animation delay, unless }
		{ otherwise requested. }
		DelayThisFrame := False;

		while AnimOb <> Nil do begin
			A2 := AnimOb^.Next;

			{ Call a routine based upon the type of }
			{ animation requested. }
			case AnimOb^.S of

			GS_Shot: PointDelay := ProcessShotAnimation( GB , AnimList , AnimOb ) or DelayThisFrame;
			GS_DamagingHit: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_ArmorDefHit: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_Parry: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_Dodge: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_Backlash: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_AreaAttack: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );

			{ If no routine was found to deal with the animation }
			{ requested, just delete the gear. }
			else RemoveGear( AnimList , AnimOb );
			end;

			DelayThisFrame := DelayThisFrame or PointDelay;

			{ Move to the next animation. }
			AnimOb := A2;
		end;

		{ Delay the animations, if appropriate. }
		if ( FrameDelay > 0 ) and DelayThisFrame then Delay(FrameDelay);
	end;
end;

Function DisplayEffectAnimations( GB: GameBoardPtr; N: Integer ): Boolean;
	{ Display all the animations stored for sequence slice N. }
	{ Return TRUE if an animation was found, or FALSE otherwise. }
var
	A: SAttPtr;
	T: Integer;
	AnimFound: Boolean;
	AnimList,AnimItem: GearPtr;
	AnimLabel,AnimCode: String;
begin
	A := ATTACK_History;
	AnimFound := False;
	AnimList := Nil;

	AnimLabel := SATT_Anim_Direction + BStr( N ) + '_';

	{ Start by creating the animation list. }
	while A <> Nil do begin
		if HeadMatchesString( AnimLabel , A^.Info ) then begin
			AnimFound := True;

			{ Insert animation handling code here. }
			AnimItem := AddGear( AnimList , Nil );
			AnimCode := RetrieveAString( A^.Info );
			AnimItem^.S := ExtractValue( AnimCode );

			T := 1;
			while ( AnimCode <> '' ) and ( T <= NumGearStats ) do begin
				AnimItem^.Stat[ T ] := ExtractValue( AnimCode );
				Inc( T );
			end;
		end;
		A := A^.Next;
	end;

	{ Process each animation. }
	ProcessAnimations( GB , AnimList );

	DisplayEffectAnimations := AnimFound;
end;


Procedure DisplayConsoleHistory( GB: GameBoardPtr );
	{ Display the console history, then restore the display. }
var
	SL: SAttPtr;
begin
	MoreText( Console_History , MoreHighFirstLine( Console_History ) );
	GFCombatDisplay( GB );

	{ Restore the console display. }
	GotoXY( ScreenZone[ ZONE_Dialog , 1 ] , ScreenZone[ ZONE_Dialog , 2 ] -1 );
	TextColor( Green );
	SL := RetrieveSAtt( Console_History , NumSAtts( Console_History ) - ScreenRows + ScreenZone[ ZONE_Dialog , 2 ] );
	if SL = Nil then SL := Console_History;
	while SL <> Nil do begin
		writeln;
		write( SL^.Info );
		SL := SL^.Next;
	end;
end;

Procedure ProcessMovement( GB: GameBoardPtr; Mek: GearPtr );
	{ Call the LOCALE movement routine, then update the display }
	{ here if need be. }
var
	result,Team: Integer;
	X,Y: LongInt;
	msg: String;
begin
	{ Store the initial position of the mek. }
	X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );

	{ Call the movement procedure, and store the result. }
	result := EnactMovement( GB , Mek );

	{ Depending upon what happened, update the display. }
	if result > 0 then begin
		{ Update the display. }
		RedrawTile( GB , X , Y );
		RedrawTile( GB , Mek );

		{ Check for previously unseen enemies. }
		if OnTheMap( NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) ) then VisionCheck( GB , Mek )
		{ Print message if mek has fled the battle. }
		else begin
			DialogMSG( PilotName( Mek ) + ' has left this area.');

			{ Set trigger here. }
			Team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
			SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
			SetTrigger( GB , TRIGGER_UnitEliminated2 + BStr( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID ) ) );
		end;

	end else if result = EMR_Crash then begin
		{ Update the display. }
		RedrawTile( GB , X , Y );
		RedrawTile( GB , Mek );

		if Mek^.G = GG_Character then begin
			msg := ReplaceHash( MsgString( 'PROCESSMOVEMENT_Fall' ) , GearName( Mek ) );
		end else begin
			msg := ReplaceHash( MsgString( 'PROCESSMOVEMENT_Crash' ) , GearName( Mek ) );
		end;
		DialogMsg( ReplaceHash( msg , BStr( DAMAGE_DamageDone ) ) );
	end;
end;


Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
	{ Output the supplied campaign and all appropriate data to disk. }
var
	Frz: FrozenLocationPtr;
begin
	{ Output GameBoard. }
	writeln( F , Camp^.GB^.ComTime );
	writeln( F , Camp^.GB^.Scale );
	WriteMap( Camp^.GB^.Map , F );

	{ Can't output the scene gear directly, since it'll be outputted }
	{ with the rest of SOURCE later on. Output its reference number. }
	writeln( F , FindGearIndex( Camp^.Source , Camp^.GB^.Scene ) );

	{ Output map contents. }
	WriteCGears( F , Camp^.GB^.Meks );

	{ Output frozen maps. }
	Frz := Camp^.Maps;
	while Frz <> Nil do begin
		writeln( F , FROZEN_MAP_CONTINUE );
		writeln( F , Frz^.Name );
		WriteMap( Frz^.Map , F );
		Frz := Frz^.Next;
	end;

	{ Output frozen map sentinel marker. }
	writeln( F , FROZEN_MAP_SENTINEL );

	{ Output SOURCE. }
	WriteCGears( F , Camp^.Source );
end;

Function ReadCampaign( var F: Text ): CampaignPtr;
	{ Input the campaign and all appropriate data from disk. }
var
	Camp: CampaignPtr;
	SceneIndex: LongInt;
	N: Integer;
	Frz: FrozenLocationPtr;
begin
	{ Allocate the campaign and the gameboard. }
	Camp := NewCampaign;
	Camp^.GB := NewMap;

	readln( F , Camp^.GB^.ComTime );
	Camp^.ComTime := Camp^.GB^.ComTime;
	readln( F , Camp^.GB^.Scale );
	Camp^.GB^.Map := ReadMap( F );

	{ Read the index of this game board's SCENE gear, and }
	{ remember to set it in the GB structure after SOURCE is loaded. }
	readln( F , SceneIndex );

	{ Read the list of map contents. }
	Camp^.GB^.Meks := ReadCGears( F );

	{ Read the frozen maps. }
	repeat
		ReadLn( F , N );

		if N = FROZEN_MAP_CONTINUE then begin
			Frz := CreateFrozenLocation( Camp^.Maps );
			ReadLn( F , Frz^.Name );
			Frz^.Map := ReadMap( F );
		end;
	until N = FROZEN_MAP_SENTINEL;

	{ Read the source, and set the gameboard's scene. }
	Camp^.Source := ReadCGears( F );
	Camp^.GB^.Scene := LocateGearByNumber( Camp^.Source , SceneIndex );

	{ Return the restored campaign structure. }
	ReadCampaign := Camp;
end;

Procedure BeginTurn( GB: GameBoardPtr; M: GearPtr );
	{ Time to start the turn. }
var
	A: Char;
begin
	SetupMemoDisplay;
	GameMsg( 'Begin ' + PilotName( M ) + ' turn' , ZONE_MemoText , InfoHilight );
	EndOfGameMoreKey;
end;


end.
