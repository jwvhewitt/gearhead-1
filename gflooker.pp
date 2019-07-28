unit gflooker;
	{ This is the map cursor browser tool thingie. }
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
    { As far as I remember, this unit is called "gflooker" because the original }
    { version of this program was going to be an arena battle game called }
    { GearFight. That didn't last long before I jumped into making it a fully }
    { featured RPG instead. }

interface

uses gears,locale;

const
	LOOKER_AutoSelect: Boolean = True;	{ Auto select new target if no current target. }

var
	LOOKER_X,LOOKER_Y: Integer;	{ Last X , Y position accessed. }
	LOOKER_Gear: GearPtr;		{ Last mecha accessed. }
	LOOKER_LastGearSelected: GearPtr;	{ Last enemy selected with select next enemy key. }

Procedure DisplayTileInfo( GB: GameBoardPtr; X,Y: Integer; ShowEmpty: Boolean );

Function LookAround( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
Function SelectTarget( GB: GameBoardPtr; Mek: GearPtr; var Wpn: GearPtr; var CallShot: boolean; var RapidFire: Integer ): Boolean;

implementation

{$IFDEF SDLMODE}
uses ability,damage,gearutil,ghweapon,menugear,texutil,ui4gh,
     sdlgfx,sdlinfo,sdlmap,sdlmenus;
{$ELSE}
uses ability,damage,gearutil,ghweapon,menugear,texutil,ui4gh,
     congfx,coninfo,conmap,conmenus,context;
{$ENDIF}

var
	LOOKER_Origin,LOOKER_Weapon: GearPtr;
	LOOKER_CallShot: Boolean;
	LOOKER_RapidFire: Integer;
{$IFDEF SDLMODE}
	LOOKER_GB: GameBoardPtr;
	LOOKER_Desc: String;
{$ENDIF}

Procedure DoSwitchBV;
	{ Switch the burst value used for LOOKER_Weapon, then store the }
	{ new burst value as the weapon's default. }
var
	BV: Integer;
begin
	if LOOKER_Weapon = Nil then Exit;

	{ Determine the current BV; this will tell us what to do next. }
	BV := WeaponBVSetting( LOOKER_Weapon );
	if LOOKER_Weapon^.G = GG_Weapon then begin
		if LOOKER_Weapon^.S = GS_Missile then begin
			BV := BV + 1;
			if BV > 4 then BV := 1;
			SetNAtt( LOOKER_Weapon^.NA , NAG_Prefrences , NAS_DefAtOp , BV );
		end else if ( LOOKER_Weapon^.S = GS_Ballistic ) or ( LOOKER_Weapon^.S = GS_BeamGun ) then begin
			BV := 5 - BV;
			SetNAtt( LOOKER_Weapon^.NA , NAG_Prefrences , NAS_DefAtOp , BV );
		end;
	end;
end;

Procedure WeaponDisplay;
	{ Show the weapon display, and the instructions/options. }
var
	msg: String;
begin
	{ Generate instructions. }
	msg := '[' + KeyMap[ KMC_SwitchWeapon ].KCode + '] Change Weapon' + #13;
	msg := msg + ' [' + KeyMap[ KMC_CalledShot ].KCode + '] Called Shot: ';
	if LOOKER_CallShot then msg := msg + 'On'
	else msg := msg + 'Off';
	msg := msg + #13 + ' [' + KeyMap[ KMC_SwitchBV ].KCode + '] Burst Value: ';
	msg := msg + BVTypeName[ WeaponBVSetting( LOOKER_Weapon ) ];
	msg := msg + #13 + ' [' + KeyMap[ KMC_SwitchTarget ].KCode + '] Switch Target';

	{ Print instructions. }
    {$IFDEF SDLMODE}
    InfoBox( ZONE_Menu1.GetRect() );
    InfoBox( ZONE_Menu2.GetRect() );
	GameMSG( msg , ZONE_Menu2.GetRect() , NeutralGrey );
    {$ELSE}
	GameMSG( msg , ZONE_Menu2 , NeutralGrey );
    {$ENDIF}

	QuickWeaponInfo( LOOKER_Weapon );
end;

{$IFDEF SDLMODE}
Procedure GFLRedraw;
	{ menu redrawer for this unit. }
begin
	if LOOKER_GB <> Nil then SDLCombatDisplay( LOOKER_GB );
	if LOOKER_Weapon <> Nil then WeaponDisplay;
    InfoBox( ZONE_TargetDistance.GetRect() );
	CMessage( LOOKER_Desc , ZONE_TargetDistance.GetRect() , InfoHilight );
    InfoBox( ZONE_TargetInfo.GetRect() );
end;
{$ENDIF}


Function CreateTileMechaMenu( GB: GameBoardPtr; X,Y: Integer; ShowAll: Boolean ): RPGMenuPtr;
	{ Make a menu listing each of the mecha at spot X , Y. }
var
	TMM: RPGMenuPtr;
	N,T: Integer;
	Mek: GearPtr;
	msg,PName: String;
begin
    {$IFDEF SDLMODE}
	TMM := CreateRPGMenu( menuitem , menuselect , ZONE_TargetInfo );
    {$ELSE}
	TMM := CreateRPGMenu( menuitem , menuselect , ZONE_Menu );
    {$ENDIF}

	N := NumVisibleGears( GB , X , Y );

	for t := 1 to N do begin
		{ We need to list both the name of the mecha and the name of }
		{ the pilot. }
		Mek := FindVisibleGear( GB , X , Y , T );
		msg := GearName( Mek );
		PName := PilotName( Mek );
		if PName <> msg then msg := msg + ' - ' + PName;
		if not GearOperational( Mek ) then begin

		    if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Gutted) = 1
		    then begin
			if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Flayed) = 1
			then
			    msg := msg + ' (stripped'
			else
			    msg := msg + ' (gutted';
			end
		    else begin
			if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Flayed) = 1
			then
			    msg := msg + ' (flayed'
			else
			    msg := msg + ' (X';
			end;
			
		    if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Ransacked) = 1
		    then
			msg := msg + ', looted)'
		    else
			msg := msg + ')';
		end;
		if ShowAll or GearOperational( Mek ) then begin
			AddRPGMenuItem( TMM , msg , T );
		end;
	end;

	CreateTileMechaMenu := TMM;
end;

Procedure DisplayTileInfo( GB: GameBoardPtr; X,Y: Integer; ShowEmpty: Boolean );
	{ Display info on the contents of location X,Y. }
	{ If the tile is empty, give a description of the terrain. }
	{ Otherwise provide a sumamry for whatever gears are there. }
var
	N: Integer;	{ The number of gears present in the tile. }
	Mek: GearPtr;
	TMM: RPGMenuPtr;
	msg: String;
begin
	{ Display info for target square. }
	N := NumVisibleGears( GB , X , Y );
	if not OnTheMap( X , Y ) then begin
{$IFDEF SDLMODE}
		GameMSG( 'Off The Map' , ZONE_TargetInfo.GetRect() , StdWhite );
{$ELSE}
		GameMSG( 'Off The Map' , ZONE_Info , StdWhite );
{$ENDIF}
		LOOKER_Gear := Nil;

	end else if ( N = 0 ) and ShowEmpty then begin
		if GB^.Map[X,Y].Visible then begin
			msg := '';
			if GB^.Scene <> Nil then msg := SAttValue( GB^.Scene^.SA , 'LOOKER' + BStr( X ) + '%' + BStr( Y ) );
			if msg = '' then msg := TerrMan[GB^.map[X,Y].Terr].Name;
{$IFDEF SDLMODE}
			CMessage( msg , ZONE_TargetInfo.GetRect() , InfoGreen );
{$ELSE}
			CMessage( msg , ZONE_Info , TerrainGreen );
{$ENDIF}
		end else begin
{$IFDEF SDLMODE}
			CMessage( 'UNKNOWN' , ZONE_TargetInfo.GetRect() , InfoGreen );
{$ELSE}
			CMessage( 'UNKNOWN' , ZONE_Info , TerrainGreen );
{$ENDIF}
		end;

		LOOKER_Gear := Nil;

	end else if N = 1 then begin
		Mek := FindVisibleGear( GB , X , Y , 1 );
{$IFDEF SDLMODE}
        { If we aren't showing empty tiles, this is getting called from outside }
        { of gflooker, so draw the infobox border. }
        if not ShowEMpty then InfoBox( ZONE_TargetInfo.GetRect() );
		DisplayTargetInfo( Mek , gb, ZONE_TargetInfo );
{$ELSE}
		DisplayGearInfo( Mek , gb, ZONE_Info );
{$ENDIF}
		LOOKER_Gear := Mek;

	end else if N > 1 then begin
		TMM := CreateTileMechaMenu( GB , X , Y , True );
{$IFDEF SDLMODE}
        { If we aren't showing empty tiles, this is getting called from outside }
        { of gflooker, so draw the infobox border. }
        if not ShowEMpty then InfoBox( ZONE_TargetInfo.GetRect() );
		DisplayMenu( TMM , Nil );
{$ELSE}
		DisplayMenu( TMM );
{$ENDIF}
		DisposeRPGMenu( TMM );
		LOOKER_Gear := Nil;

	end;

end;

Function CoverDesc( C: Integer ): String;
	{ Return a string telling how much cover the target has. }
begin
	if C < 0 then begin
		CoverDesc := 'X';
	end else begin
		CoverDesc := BStr( C );
	end;
end;

Function FindNextTarget( GB: GameBoardPtr; Origin: GearPtr ): GearPtr;
	{ ORIGIN is looking for a new target. Return the next visible enemy found. }
var
	M,NextTarget,FirstTarget: GearPtr;
	PickNext: Boolean;
begin
	{ If we've already selected an enemy, find the next one from that point. }
	if ( LOOKER_LastGearSelected = Nil ) and ( LOOKER_Gear <> Nil ) then LOOKER_LastGearSelected := LOOKER_Gear;

	{ Cycle through all the models on the map looking for a visible, operational enemy. }
	M := GB^.Meks;
	NextTarget := Nil;
	PickNext := False;
	FirstTarget := Nil;
	while M <> Nil do begin
		{ If M fits our target criteria, check it to see what's going on. }
		if OnTheMap( M ) and AreEnemies( GB , Origin , M ) and GearOperational( M ) and MekCanSeeTarget( GB , Origin , M ) then begin
			{ If M is the target we started with, set the flag to pick the next }
			{ target encountered. }
			if M = LOOKER_LastGearSelected then begin
				PickNext := True;
			end else if PickNext then begin
				NextTarget := M;
				PickNext := False;
			end;
			if FirstTarget = Nil then FirstTarget := M;
		end;

		M := M^.Next;
	end;
	{ If NextTarget = Nil, either we started with no target or the target we had }
	{ was the last target in the list. So, go with the first target found. }
	if NextTarget = Nil then NextTarget := FirstTarget;
	LOOKER_LastGearSelected := NextTarget;
	FindNextTarget := NextTarget;
end;

Function TrueLooker( GB: GameBoardPtr; X , Y: Integer ): Boolean;
	{ Scan the map, starting at location X,Y. }
	{ Return TRUE if this procedure is exited with the space bar, }
	{ FALSE if it is exited with the ESC key. }
	{ If Mek <> Nil, do range calculations from that spot. }
	{ If WPN <> Nil, allow weapon selection. }
var
	N,MekNum: Integer;
	TMM: RPGMenuPtr;
	A: Char;
	P: Point;
	Procedure RepositionCursor( D: Integer );
	begin
		RedrawTile( gb, X , Y );
		if OnTheMap( X + AngDir[ D , 1 ] , Y + AngDir[ D , 2 ] ) then begin
			X := X + AngDir[ D , 1 ];
			Y := Y + AngDir[ D , 2 ];
		end;
	end;
begin
	{ Error check- make sure the start point is on the screen. }
	if not OnTheMap(X,Y) then begin
		X := 1;
		Y := 1;
	end;

	LOOKER_LastGearSelected := Nil;
    LOOKER_Gear := Nil;

	if LOOKER_Origin <> Nil then P := GearCurrentLocation( LOOKER_Origin );

	{ Start going here. }
	repeat
		{ Display info on the selected tile. }
        {$IFNDEF SDLMODE}
		DisplayTileInfo( GB , X , Y, True );
		if ( LOOKER_Origin <> Nil ) and OnTheMap( LOOKER_Origin ) then begin
			if LOOKER_Gear = Nil then begin
				CMessage( 'Range: ' + BStr( ScaleRange( Range(LOOKER_Origin,X,Y) , GB^.Scale ) ) + '   Cover: '+CoverDesc( CalcObscurement( LOOKER_Origin , X , Y , gb )) , ZONE_Clock , InfoGreen );
			end else begin
				CMessage( 'Range: ' + BStr( ScaleRange( Range(gb,LOOKER_Origin,LOOKER_Gear) , GB^.Scale )) + '   Cover: '+CoverDesc( CalcObscurement( LOOKER_Origin , LOOKER_Gear , gb )) , ZONE_Clock , InfoGreen );
			end;
		end;
{$ENDIF}

		{ Display info on the selected weapon. }
        {$IFNDEF SDLMODE}
		if LOOKER_Weapon <> Nil then WeaponDisplay;
        {$ENDIF}

		{ Indicate origin and target squares. }
{$IFDEF SDLMODE}
		if ( LOOKER_Origin <> Nil ) then IndicateTile( GB , LOOKER_Origin , False );
		IndicateTile( GB , X , Y , TerrMan[ GB^.Map[ X , Y ].terr ].Altitude , True );
{$ELSE}
		if ( LOOKER_Origin <> Nil ) and ( not NeedsRecentering( P.X , P.Y ) ) then IndicateTile( GB , LOOKER_Origin );
		IndicateTile( GB , X , Y );
{$ENDIF}

		A := RPGKey{$IFDEF SDLMODE}(CONTEXT_LOOKER){$ENDIF};

		if A = KeyMap[ KMC_North ].KCode then begin
			RepositionCursor( 6 );

		end else if A = KeyMap[ KMC_South ].KCode then begin
			RepositionCursor( 2 );

		end else if A = KeyMap[ KMC_West ].KCode then begin
			RepositionCursor( 4 );

		end else if A = KeyMap[ KMC_East ].KCode then begin
			RepositionCursor( 0 );

		end else if A = KeyMap[ KMC_NorthEast ].KCode then begin
			RepositionCursor( 7 );

		end else if A = KeyMap[ KMC_SouthWest ].KCode then begin
			RepositionCursor( 3 );

		end else if A = KeyMap[ KMC_NorthWest ].KCode then begin
			RepositionCursor( 5 );

		end else if A = KeyMap[ KMC_SouthEast ].KCode then begin
			RepositionCursor( 1 );

		end else if ( A = KeyMap[ KMC_SwitchWeapon ].KCode ) and ( LOOKER_Weapon <> Nil ) and ( LOOKER_Origin <> Nil ) then begin
			LOOKER_Weapon := FindNextWeapon( GB , LOOKER_Origin , LOOKER_Weapon , Range( LOOKER_Origin , X , Y ) );

		end else if ( A = KeyMap[ KMC_SwitchTarget ].KCode ) and ( LOOKER_Weapon <> Nil ) and ( LOOKER_Origin <> Nil ) then begin
			RedrawTile( gb, X , Y );
			LOOKER_Gear := FindNextTarget( GB , LOOKER_Origin );
			if LOOKER_Gear <> Nil then begin
				X := NATtValue( LOOKER_Gear^.NA , NAG_Location , NAS_X );
				Y := NATtValue( LOOKER_Gear^.NA , NAG_Location , NAS_Y );
			end;

		end else if ( A = KeyMap[ KMC_SwitchBV ].KCode ) and ( LOOKER_Weapon <> Nil ) and ( LOOKER_Origin <> Nil ) then begin
			DoSwitchBV;

		end else if ( A = KeyMap[ KMC_CalledShot ].KCode ) and ( LOOKER_Weapon <> Nil ) and ( LOOKER_Origin <> Nil ) then begin
			LOOKER_CallShot := not LOOKER_CallShot;

		end else if A = KeyMap[ KMC_ExamineMap ].KCode then begin
			A := #27;

		end else if A = KeyMap[ KMC_Attack ].KCode then begin
			A := ' ';

{$IFDEF SDLMODE}
		end else if A = #8 then begin
			A := #27;

        end else if A = RPK_TimeEvent then begin
    		LOOKER_GB := GB;
		    if ( LOOKER_Origin <> Nil ) and OnTheMap( LOOKER_Origin ) then begin
			    if LOOKER_Gear = Nil then begin
				    LOOKER_Desc := 'Range: ' + BStr( ScaleRange( Range(LOOKER_Origin,X,Y) , GB^.Scale ) ) + '   Cover: '+CoverDesc( CalcObscurement( LOOKER_Origin , X , Y , gb ));
			    end else begin
				    LOOKER_Desc := 'Range: ' + BStr( ScaleRange( Range(gb,LOOKER_Origin,LOOKER_Gear) , GB^.Scale )) + '   Cover: '+CoverDesc( CalcObscurement( LOOKER_Origin , LOOKER_Gear , gb ));
			    end;
		    end;
    		GFLRedraw;
    		DisplayTileInfo( GB , X , Y, True );
            ghflip();
{$ENDIF}

		end;

	until (A = ' ') or (A = #27) or (A = #10);

	{ Restore the display. }
	RedrawTile( gb, X , Y );
	if LOOKER_Origin <> Nil then RedrawTile( gb, LOOKER_Origin );
    {$IFNDEF SDLMODE}
	UpdateCombatDisplay( GB );
    {$ENDIF}

	{ Store the values in the global variables. }
	LOOKER_X := X;
	LOOKER_Y := Y;

	N := NumVisibleGears( GB , X , Y );
	if N = 1 then begin
		LOOKER_Gear := FindVisibleGear( GB , X , Y , 1 );

	end else if N > 1 then begin
		TMM := CreateTileMechaMenu( GB , X , Y , Looker_Weapon = Nil );
		if TMM^.NumItem > 1 then begin
{$IFDEF SDLMODE}
			MekNum := SelectMenu( TMM , @GFLRedraw );
{$ELSE}
			MekNum := SelectMenu( TMM );
{$ENDIF}
		end else if TMM^.NumItem > 0 then begin
			MekNum := TMM^.FirstItem^.Value;
		end else begin
			MekNum := -1;
		end;
		DisposeRPGMenu( TMM );

		if MekNum <> -1 then LOOKER_Gear := FindVisibleGear( GB , X , Y , MekNum )
		else LOOKER_Gear := Nil;

	end else begin
		LOOKER_Gear := Nil;
	end;

	{ Return TRUE if a space was pressed, FALSE otherwise. }
	TrueLooker := ( A = ' ' ) or ( A = #10 );
end;

Function LookAround( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ This function just calls the above one with the location of }
	{ the specified mek. }
var
	X,Y: Integer;
begin
	LOOKER_Origin := Mek;
	LOOKER_Weapon := Nil;

	if Mek <> Nil then begin
		X := NAttValue( Mek^.NA , NAG_Location, NAS_X );
		Y := NAttValue( Mek^.NA , NAG_Location, NAS_Y );
	end else begin
		X := 1;
		Y := 1;
	end;

	LookAround := TrueLooker( GB , X , Y );
end;

Function SelectTarget( GB: GameBoardPtr; Mek: GearPtr; var Wpn: GearPtr; var CallShot: boolean; var RapidFire: Integer ): Boolean;
	{ This function just calls LookAround with the location of }
	{ the specified mek and its current target. }
	{ Record the target selected as this mecha's target. }
var
	T: GearPtr;		{ The Target }
	X,Y: Integer;
	FunResult: Boolean;	{ Function Result }
begin
	LOOKER_Origin := Mek;
	LOOKER_Weapon := Wpn;
	LOOKER_CallShot := CallShot;
	LOOKER_RapidFire := RapidFire;

	{ Get the default values from this mek. }
	T := LocateMekByUID( GB , NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Target ) );

	{ If this mek has a target, start out the targeting cursor in the }
	{ target's square. If it has no target, start the targeting cursor }
	{ in the mek's own square. }
	if ( T <> Nil ) and MekCanSeeTarget( gb , Mek , T ) and GearOperational( T ) then begin
		X := NAttValue( T^.NA , NAG_Location, NAS_X );
		Y := NAttValue( T^.NA , NAG_Location, NAS_Y );
	end else if LOOKER_AutoSelect then begin
		T := SeekTarget( GB , Mek );
		if T <> Nil then begin
			X := NAttValue( T^.NA , NAG_Location, NAS_X );
			Y := NAttValue( T^.NA , NAG_Location, NAS_Y );
		end else begin
			X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
			Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );
		end;
	end else begin
		X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
		Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );
	end;

	{ Call the look around procedure. }
	FunResult := TrueLooker( GB , X , Y );

	{ If the targeting wasn't cancelled, record the target. }
	if FunResult and ( LOOKER_Gear <> Nil ) and ( FindRoot( LOOKER_Gear ) <> Mek ) then begin
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Target , NAttValue( LOOKER_Gear^.NA , NAG_EpisodeData , NAS_UID ) );
	end;

	{ Set the values of the VAR parameters. }
	Wpn := LOOKER_Weapon;
	CallShot := LOOKER_CallShot;
	RapidFire := LOOKER_RapidFire;

	{ Return the value. }
	SelectTarget := FunResult;
end;



end.
