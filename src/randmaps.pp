unit RandMaps;
	{ ******************************* }
	{ ***   NEW  SPECIFICATIONS   *** }
	{ ******************************* }

	{ Every feature, both the SCENE gear and the MAP FEATURES, }
	{ needs three SAtts defined: PARAM describes the rendering }
	{ parameters to be sent to the actual drawing routine, while }
	{ SELECTOR holds the parameters to be sent to the sub-area }
	{ selection routine. GAPFILL describes how to plug empty spaces. }

	{ If these strings are not defined in the scene/feature gear, }
	{ a default value is obtained from the GameData/randmaps.txt file }
	{ based upon the scene/feature's listed style. }

	{ All map features are to be recursive. Bottom level features }
	{ fit into the SCENE gear. }
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

uses gears,locale;

const
	MG_Normal = 0;
	MG_City = 1;
	MG_Cave = 2;

	DEFAULT_FLOOR_TYPE = 20;
	DEFAULT_WALL_TYPE = 23;

	SPECIAL_StartHere = 'STARTHERE';
	SPECIAL_ShowAll = 'SHOWALL';
	SPECIAL_ConvertDoors = 'CELL';

	DW_Horizontal = 1;
	DW_Vertical = 2;

function RandomMap( Scene: GearPtr ): GameBoardPtr;


implementation

{$IFDEF SDLMODE}
uses gearutil,ghprop,rpgdice,texutil,sdlgfx;
{$ELSE}
uses gearutil,ghprop,rpgdice,texutil,context;
{$ENDIF}

var
	Standard_Param_List: SAttPtr;

Function IsLegalTerrain( T: Integer ): Boolean;
	{ Return TRUE if T is a legal terrain type, or FALSE otherwise. }
begin
	IsLegalTerrain := ( T >= 1 ) and ( T <= NumTerr );
end;

Function GetSpecial( MF: GearPtr ): String;
	{ Retrieve the special string for this map feature, }
	{ convert it to uppercase and return it. }
begin
	GetSpecial := UpCase( SAttValue( MF^.SA , 'SPECIAL' ) );
end;

Function RectPointOverlap( X1,Y1,X2,Y2,PX,PY: Integer ): Boolean;
	{ Return TRUE if point PX,PY is located inside the provided }
	{ rectangle, FALSE if it isn't. }
begin
	RectPointOverlap := ( PX >= X1 ) and ( PX <= X2 ) and ( PY >= Y1 ) and ( PY <= Y2 );
end;

Function RectRectOverlap( X1,Y1,W1,H1,X2,Y2,W2,H2: Integer ): Boolean;
	{ Return TRUE if the two rectangles described by X,Y,Width,Height }
	{ overlap, FALSE if they don't. }
var
	OL: Boolean;
	XB,YB: Integer;
begin
	OL := False;

	{ Check all points of the first rectangle against the second. }
	for XB := X1 to (X1 + W1 - 1 ) do begin
		for YB := Y1 to (Y1 + H1 - 1 ) do begin
			Ol := OL or RectPointOverlap( X2 , Y2 , X2 + W2 - 1 , Y2 + H2 - 1 , XB , YB );
		end;
	end;

	RectRectOverlap := OL;
end;

Function RegionClear( GB: GameBoardPtr; SCheck,STerr,X,Y,W,H: Integer ): Boolean;
	{ Return TRUE if the specified region counts as clear for the purpose }
	{ of sticking a map feature there, FALSE if it doesn't. }
	Function InclusiveRegionClear: Boolean;
		{ Return TRUE if this region contains at least one }
		{ tile of STERR, false otherwise. }
	var
		IsClear: Boolean;
		TX,TY: Integer;
	begin
		IsClear := False;
		for TX := ( X - 1 ) to ( X + W ) do begin
			for TY := ( Y - 1 ) to ( Y + H ) do begin
				if OnTheMap( TX , TY ) then begin
					if GB^.Map[TX,TY].Terr = STerr then begin
						IsClear := True;
					end;
				end;
			end;
		end;
		InclusiveRegionClear := IsClear;
	end;

	Function ExclusiveRegionClear: Boolean;
		{ Return TRUE if this region is free from tiles }
		{ of type STERR, false otherwise. }
	var
		IsClear: Boolean;
		TX,TY: Integer;
	begin
		IsClear := True;
		for TX := ( X - 1 ) to ( X + W ) do begin
			for TY := ( Y - 1 ) to ( Y + H ) do begin
				if OnTheMap( TX , TY ) then begin
					if GB^.Map[TX,TY].Terr = STerr then begin
						IsClear := False;
					end;
				end;
			end;
		end;
		ExclusiveRegionClear := IsClear;
	end;

begin
	{ Call the appropriate checking routine based upon what kind of }
	{ map generator we're dealing with. }
	if SCheck > 0 then begin
		RegionClear := InclusiveRegionClear;
	end else if SCheck < 0 then begin
		RegionClear := ExclusiveRegionClear;
	end else begin
		RegionClear := True;
	end;
end;

Function RandomPointWithinBounds( Container: GearPtr; W,H: Integer ): Point;
	{ Select a placement point within the bounds of this container. }
var
	P: Point;
begin
	if ( Container = Nil ) or ( Container^.G = GG_Scene ) then begin
		P.X := Random( XMax - 3 - W ) + 3;
		P.Y := Random( YMax - 3 - H ) + 3;
	end else begin
		P.X := Container^.Stat[ STAT_XPos ] + 1;
		if W < ( Container^.Stat[ STAT_MFWidth ] - 3 ) then P.X := P.X + Random( Container^.Stat[ STAT_MFWidth ] - W - 4 );
		P.Y := Container^.Stat[ STAT_YPos ] + 1;
		if H < ( Container^.Stat[ STAT_MFHeight ] - 3 ) then P.Y := P.Y + Random( Container^.Stat[ STAT_MFHeight ] - H - 4 );
	end;
	RandomPointWithinBounds := P;
end;

Function PlacementPointIsGood( GB: GameBoardPtr; Container: GearPtr; SCheck,STerr,X0,Y0,W,H: Integer ): Boolean;
	{ Return TRUE if the specified area is free for adding a new }
	{ map feature, or FALSE otherwise. }
var
	BadPosition: Boolean;
	MF2: GearPtr;
begin
	{ Assume it isn't a bad position until shown otherwise. }
	BadPosition := False;

	{ Check One - see if this position intersects with any }
	{ other map feature at this same depth. }
	{ Only those map features which have }
	{ already been placed need be checked. }
	if Container <> Nil then begin
		MF2 := Container^.SubCom;
		while MF2 <> Nil do begin
			if ( MF2^.G = GG_MapFeature ) and OnTheMap( MF2^.Stat[ STAT_XPos ] , MF2^.Stat[ STAT_YPos ] ) then begin
				BadPosition := BadPosition or RectRectOverlap( X0 - 1 , Y0 - 1 , W + 2 , H + 2 , MF2^.Stat[ STAT_XPos ] , MF2^.Stat[ STAT_YPos ] , MF2^.Stat[ STAT_MFWidth ] , MF2^.Stat[ STAT_MFHeight ] );
			end;
			MF2 := MF2^.Next;
		end;
	end;

	{ Check Two - see if this position is in a "clear" area }
	{ of the map. }
	if not BadPosition then BadPosition := not RegionClear( GB , SCheck , STerr , X0 , Y0 , W , H );

	{ So, the placement point is good if X,Y isn't a bad position. }
	PlacementPointIsGood := not BadPosition;
end;

Procedure SelectPlacementPoint( GB: GameBoardPtr; Container,MF: GearPtr; var Cells: SAttPtr; SCheck,STerr: Integer );
	{ Attempt to find a decent place to put map feature MF. }
	{ - It should not intersect with any other map feature         }
	{   currently placed.                                          }
	{ - It should be at least one tile from the edge of the map    }
	{   on all sides.                                              }
	{ - It should be placed in an area that is considered "clear", }
	{   depending upon the SCheck, STerr values.                   }
var
	Tries: Integer;
	P: Point;
	TheCell: SAttPtr;
begin
	{ If we have been provided with a list of cells, then in theory }
	{ or work here has already been done for us. Pick one of the cells }
	{ at random and return that. On the other hand, if we have no }
	{ cells, we'll need to search for a free spot ourselves. }
	if Cells <> Nil then begin
		{ Select a cell at random. }
		TheCell := SelectRandomSAtt( Cells );

		{ Extract the needed info from this cell. }
		MF^.Stat[ STAT_XPos ] := ExtractValue( TheCell^.Info );
		MF^.Stat[ STAT_YPos ] := ExtractValue( TheCell^.Info );
		MF^.Stat[ STAT_MFWidth ] := ExtractValue( TheCell^.Info );
		MF^.Stat[ STAT_MFHeight ] := ExtractValue( TheCell^.Info );

		{ Delete this cell, to prevent it from being chosen again. }
		RemoveSAtt( Cells , TheCell );

	end else if not OnTheMap( MF^.Stat[ STAT_XPos ] , MF^.Stat[ STAT_YPos ] ) then begin
		Tries := 0;
		repeat
			P := RandomPointWithinBounds( Container , MF^.Stat[ STAT_MFWidth ] , MF^.Stat[ STAT_MFHeight ] );
			Inc( Tries );

			{ If we've been trying and trying with no success, }
			{ get rid of the terrain check condition and just go }
			{ on nonintersection. }
			if Tries > 9000 then SCheck := 0;
		until ( Tries > 10000 ) or PlacementPointIsGood( GB , Container , SCheck , STerr , P.X , P.Y , MF^.Stat[ STAT_MFWidth ] , MF^.Stat[ STAT_MFHeight ] );

		MF^.Stat[ STAT_XPos ] := P.X;
		MF^.Stat[ STAT_YPos ] := P.Y;
	end;
end;

Function DecideTerrainType( MF: GearPtr; var Cmd: String; D: Integer ): Integer;
	{ Given the default provided by the instruction string and the }
	{ value stored in the map feature gear, decide what terrain type }
	{ to use for the current operation. }
var
	it: Integer;
begin
	it := ExtractValue( CMD );
	if ( MF <> Nil ) and IsLegalTerrain( MF^.Stat[ D ] ) then begin
		it := MF^.Stat[ D ];
	end;
	DecideTerrainType := it;
end;

Procedure DrawTerrain( GB: GameBoardPtr; X,Y,T1,T2: Integer );
	{ Draw a terrain type into the designated tile. If two terrain }
	{ types have been provided, pick one of them randomly. }
begin
	if OnTheMap( X , Y ) then begin
		if ( Random( 3 ) = 1 ) and ( T2 <> 0 ) then GB^.Map[X,Y].terr := T2
		else GB^.Map[X,Y].terr := T1;
	end;
end;

Procedure RectFill( GB: GameBoardPtr; T1,T2,X0,Y0,W,H: Integer );
	{ Fill a rectangular area with the specified terrain. }
	{ This is needed by several of the commands, so here it is }
	{ as a separate procedure. }
var
	X,Y: Integer;
begin
	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if OnTheMap( X , Y ) then begin
				DrawTerrain( GB , X , Y , T1 , T2 );
			end;
		end;
	end;
end;

Procedure ProcessFill( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Just fill this region with a terrain type. }
var
	T1,T2: Integer;
begin
	T1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	T2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );

	{ Fill in the building area with the floor terrain. }
	RectFill( GB , T1 , T2 , X0 , Y0 , W , H );
end;

Procedure AddDoor( GB: GameBoardPtr; MF,DoorPrototype: GearPtr; X,Y: Integer );
	{ Add a standard door to the map at the specified location. }
	function LocalWall: Integer;
		{ Take a look at the four neighboring squares to locate }
		{ a wall. }
	var
		D,T: Integer;
	begin
		D := 0;
		while D <= 8 do begin
			T := GB^.Map[ X + AngDir[ D , 1 ] , Y + AngDir[ D , 2 ] ].terr;
			D := D + 2;
			if TerrMan[ T ].Pass < -99 then D := 10;
		end;
		LocalWall := T;
	end;
var
	NewDoor: GearPtr;
	Name: String;
	Roll,Chance: Integer;
begin
	if DoorPrototype <> Nil then begin
		NewDoor := CloneGear( DoorPrototype );
	end else begin
		NewDoor := NewGear( Nil );
		NewDoor^.G := GG_MetaTerrain;
		NewDoor^.S := GS_MetaDoor;
		NewDoor^.V := 5;
		InitGear( NewDoor );
	end;

	SetNAtt( NewDoor^.NA , NAG_Location , NAS_X , X );
	SetNAtt( NewDoor^.NA , NAG_Location , NAS_Y , Y );

	if MF <> Nil then begin
		Name := SAttValue( MF^.SA , 'NAME' );
		if Name <> '' then begin
			SetSAtt( NewDoor^.SA , 'NAME <' + MsgString( 'RANDMAPS_DoorSign' ) + Name + '>' );
		end;

		{ Possibly make the door either LOCKED or SECRET, }
		{ depending on the random chances stored in the MF. }
		Chance := NAttValue( MF^.NA , NAG_Narrative , NAS_LockedDoorChance );
		if Chance > 0 then begin
			Roll := Random( 100 );
			if Roll < Chance then begin
				NewDoor^.Stat[ STAT_Lock ] := ( Roll div 4 ) + 5;
			end;
		end;
		Chance := NAttValue( MF^.NA , NAG_Narrative , NAS_SecretDoorChance );
		if Chance > 0 then begin
			Roll := Random( 100 );
			if Roll < Chance then begin
				DrawTerrain( GB , X , Y , LocalWall , 0 );
				NewDoor^.Stat[ STAT_MetaVisibility ] := ( Roll div 4 ) + 5;
			end;
		end;

	end;

	InsertInvCom( GB^.Scene , NewDoor );
end;

Procedure ConvertDoors( GB: GameBoardPtr; DoorPrototype: GearPtr; X0,Y0,W,H: Integer );
	{ Convert any doors within the specified range to the door }
	{ prototype requested. }
var
	map: Array[ 1..XMax , 1..YMax ] of Boolean;
	M,M2,D2: GearPtr;
	X,Y: Integer;
begin
	{ For this procedure to work, we must have the scene and }
	{ a prototype door. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) or ( DoorPrototype = Nil ) then Exit;

	{ Clear our replacement map. }
	{ Set each tile to TRUE; change to FALSE once the door at this }
	{ spot has been replaced. This should keep us from repeatedly }
	{ replacing the same door over and over in an endless loop. }
	for x := 1 to XMax do begin
		for y := 1 to YMax do begin
			map[ X,Y] := True;
		end;
	end;

	M := GB^.Scene^.InvCom;
	while M <> Nil do begin
		M2 := M^.Next;

		if ( M^.G = GG_MetaTerrain ) and ( M^.S = GS_MetaDoor ) then begin
			{ This is a door. Check it out. }
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			if OnTheMap( X , Y ) and Map[ X , Y ] and RectPointOverlap( X0 - 1 , Y0 - 1 , X0 + W , Y0 + H , X , Y ) then begin
				D2 := CloneGear( DoorPrototype );
				RemoveGear( GB^.Scene^.InvCom , M );
				SetNAtt( D2^.NA , NAG_Location , NAS_X , X );
				SetNAtt( D2^.NA , NAG_Location , NAS_Y , Y );
				InsertInvCom( GB^.Scene , D2 );
				Map[ X , Y ] := False;
			end;
		end;

		M := M2;
	end;
end;

Procedure DrawWall( GB: GameBoardPtr; X, Y, L, Style, WallType: Integer; DoorPrototype: GearPtr );
	{ Draw a wall starting at X0,Y0 and continuing for L tiles in }
	{ the direction indicated by Style. Use WallType as the wall }
	{ terrain, and DoorPrototype for the door. } 
var
	DL: Integer;	{ Door longitude. The tile at which to add the door. }
	T: Integer;
begin
	{ Select the door point now. }
	DL := Random( L - 2 ) + 2;
	for t := 1 to L do begin
		{ If our point is on the map, do drawing here. }
		if OnTheMap( X , Y ) then begin
			{ If this is our door point, do that now. }
			if T = DL then begin
				GB^.Map[ X , Y ].Terr := TERRAIN_Threshold;
				AddDoor( GB , Nil , DoorPrototype , X , Y );

			{ Otherwise draw the wall terrain. }
			end else begin
				GB^.Map[ X , Y ].Terr := WallType;

			end;

			if Style = DW_Horizontal then begin
				Inc( X );
			end else begin
				Inc( Y );
			end;
		end;
	end;
end;

Procedure ProcessWall( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer; AddGaps,AddDoors: Boolean );
	{ Draw a wall around this map feature. Use the MFBORDER terrain, if }
	{ appropriate. }
var
	DX,DY: Integer;	{ Door Position }
	Terrain,X,Y: Integer;
	Procedure DrawWallNow;
	begin
		if OnTheMap( X , Y ) then begin
			{ If this is the door position, deal with that. }
			if AddGaps and ( MF <> Nil ) and ( X = DX ) and ( Y = DY ) then begin
				if AddDoors then begin
					GB^.Map[ X , Y ].Terr := TERRAIN_Threshold;
					AddDoor( GB , MF , SeekCurrentLevelGear( MF^.SubCom , GG_MetaTerrain , GS_MetaDoor ) , X , Y );
				end else begin
					GB^.Map[ X , Y ].Terr := 1;
				end;

			{ If this isn't the door position, draw a wall. }
			end else begin
				GB^.Map[ X , Y ].Terr := Terrain;
			end;
		end;
	end;
begin
	{ Decide on what terrain to use for the walls. }
	Terrain := DecideTerrainType( MF , Cmd ,  STAT_MFBorder );

	{ Top wall. }
	DX := Random( W - 2 ) + X0 + 1;
	Y := Y0;
	DY := Y0;
	for X := X0 to ( X0 + W - 1 ) do begin
		DrawWallNow;
	end;

	{ Bottom wall. }
	DX := Random( W - 2 ) + X0 + 1;
	Y := Y0 + H - 1;
	DY := Y;
	for X := X0 to ( X0 + W - 1 ) do begin
		DrawWallNow;
	end;

	{ Right wall. }
	DY := Random( H - 2 ) + Y0 + 1;
	X := X0 + W - 1;
	DX := X;
	for Y := Y0 to ( Y0 + H - 1 ) do begin
		DrawWallNow;
	end;

	{ Left wall. }
	DY := Random( H - 2 ) + Y0 + 1;
	X := X0;
	DX := X;
	for Y := Y0 to ( Y0 + H - 1 ) do begin
		DrawWallNow;
	end;
end;

Function WallCoverage( GB: GameBoardPtr; X0,Y0,W,H,WallType: Integer ): Integer;
	{ Return the percentage of the map covered in walls. }
var
	X,Y,Walls,Tiles: Integer;
begin
	Walls := 0;
	Tiles := 0;

	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if GB^.Map[X,Y].Terr = WallType then Inc( Walls );
			Inc( Tiles );
		end;
	end;
	WallCoverage := ( Walls * 100 ) div Tiles;
end;

Procedure ProcessCarve( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ This should draw a cave using the 'L' method. }
var
	Floor1,Floor2,Wall: Integer;
	P: Point;

	Procedure DrawAnL( X , Y: Integer );
	var
		X1,X2,Y1,Y2,XT,YT: Integer;
	begin
		{ Determine X0,X1,Y0,Y1 points. }
		if Random( 2 ) = 1 then begin
			X1 := X - 3 - Random( 15 );
			X2 := X;
		end else begin
			X1 := X;
			X2 := X + 3 + Random( 15 );
		end;
		if Random( 2 ) = 1 then begin
			Y1 := Y - 2 - Random( 10 );
			Y2 := Y;
		end else begin
			Y1 := Y;
			Y2 := Y + 2 + Random( 10 );
		end;
		for XT := X1 to X2 do begin
			DrawTerrain( GB , XT , Y , Floor1 , Floor2 );
		end;
		for YT := Y1 to Y2 do begin
			DrawTerrain( GB , X , YT , Floor1 , Floor2 );
		end;
	end;
begin
	Floor1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	Floor2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );
	Wall := DecideTerrainType( MF , Cmd , STAT_MFBorder );

	{ Fill in entire area with rocks. }
	RectFill( GB , Wall , 0 , X0 , Y0 , W , H );

	{ Draw L's until the map is sufficiently perforated. }
	DrawAnL( X0 + ( W div 2 ) , Y0 + ( H div 2 ) );
	while WallCoverage( GB , X0 , Y0 , W , H , Wall ) > 50 do begin
		P.X := X0 + Random( W - 2 ) + 1;
		P.Y := Y0 + Random( H - 2 ) + 1;
		if OnTheMap( P.X , P.Y ) and ( GB^.Map[P.X,P.Y].Terr <> Wall ) then DrawAnL( P.X , P.Y );
	end;
end;

Procedure ProcessScatter( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Do a scattering of terrain. Useful for forests, hills, etc. }
var
	T1,T2,T3: Integer;
	N,T: LongInt;
	X,Y: Integer;
begin
	{ Begin by reading the terrain definitions. }
	T1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	T2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );
	T3 := DecideTerrainType( MF , Cmd , STAT_MFSpecial );

	{ Calculate how many iterations to do. }
	N := W * H div 2;
	for t := 1 to N do begin
		{ Pick a random point within the bounds. }
		X := X0 + ( W div 2 ) + Random( ( W + 1 ) div 2 ) - Random( ( W + 1 ) div 2 );
		Y := Y0 + ( H div 2 ) + Random( ( H + 1 ) div 2 ) - Random( ( H + 1 ) div 2 );
		if OnTheMap( X , Y ) then begin
			{ Check the terrain at this spot, then move up to the next terrain. }
			if ( GB^.Map[ X , Y ].Terr = T1 ) and IsLegalTerrain( T2 ) then begin
				GB^.Map[ X , Y ].Terr := T2
			end else if ( GB^.Map[ X , Y ].Terr = T2 ) and IsLegalTerrain( T3 ) then begin
				GB^.Map[ X , Y ].Terr := T3
			end else if (  GB^.Map[ X , Y ].Terr <> T3 ) and IsLegalTerrain( T1 ) then begin
				GB^.Map[ X , Y ].Terr := T1
			end;
		end;
	end;
end;

Procedure ProcessEllipse( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Do a vaguely ellipsoid area of terrain. }
var
	T1,T2,T3: Integer;
	X,Y,MX,MY,SX,SY,SR: Integer;
begin
	{ Begin by reading the terrain definitions. }
	T1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	T2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );
	T3 := DecideTerrainType( MF , Cmd , STAT_MFSpecial );

	MX := X0 + ( ( W - 1 ) div 2 );
	MY := Y0 + ( ( H - 1 ) div 2 );
	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if OnTheMap( X , Y ) then  begin
				{ Calculate scaled X and Y values. }
				{ Scale things for a circle of radius 100. }
				SX := Abs( X - MX ) * 100 div W;
				SY := Abs( Y - MY ) * 100 div H;

				{ Calculate the radius to this spot. }
				SR := Range( 0 , 0 , SX , SY );
				if ( SR <= 17 ) and IsLegalTerrain( T3 ) then begin
					GB^.Map[ X , Y ].terr := T3;
				end else if ( SR <= 33 ) and IsLegalTerrain( T2 ) then begin
					GB^.Map[ X , Y ].terr := T2;
				end else if ( SR <= 50 ) and IsLegalTerrain( T1 ) then begin
					GB^.Map[ X , Y ].terr := T1;
				end;
			end;
		end;
	end;

end;

Procedure ProcessLattice( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Draw a grid of lines on the map. }
var
	LineTerr,FieldTerr,X,Y: Integer;
	P: Point;
begin
	FieldTerr := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	LineTerr := DecideTerrainType( MF , Cmd , STAT_MFSpecial );

	{ Fill in entire area with the field terrain type. }
	RectFill( GB , FieldTerr , 0 , X0 , Y0 , W , H );

	{ Draw the vertical lines. }
	P.X := X0;
	while P.X < ( X0 + W ) do begin
		P.X := P.X + 8 + RollStep( 10 );
		for x := P.X to ( P.X + 3 ) do begin
			if X < ( X0 + W ) then begin
				for Y := Y0 to ( Y0 + H - 1 ) do begin
					if OnTheMap( X , Y ) then GB^.Map[ X , Y ].Terr := LineTerr;
				end;
			end;
		end;
	end;

	{ Draw the horizontal lines. }
	P.Y := Y0;
	while P.Y < ( Y0 + H ) do begin
		P.Y := P.Y + 8 + RollStep( 10 );
		for Y := P.Y to ( P.Y + 3 ) do begin
			if Y < ( Y0 + H ) then begin
				for X := X0 to ( X0 + W - 1 ) do begin
					if OnTheMap( X , Y ) then GB^.Map[ X , Y ].Terr := LineTerr;
				end;
			end;
		end;
	end;
end;

Function ProcessMitose( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SAttPtr;
	{ The requested area will split in two. A wall will be drawn }
	{ between the two halves, and a door placed in the wall. }
	{ This division will continue until we have a bunch of little }
	{ rooms. }
var
	Cells: SAttPtr;
	FloorType,WallType: Integer;
	ProtoDoor: GearPtr;

	Function IsGoodWallAnchor( AX,AY: Integer ): Boolean;
		{ This spot is a good anchor point for a wall as long as }
		{ there isn't a door. }
	begin
		IsGoodWallAnchor := OnTheMap( AX , AY ) and ( GB^.Map[ AX , AY ].terr <> TERRAIN_Threshold );
	end;

	Procedure DivideArea( CX0 , CY0 , CW , CH: Integer );
		{ If this area is large enough, divide it into two }
		{ smaller areas, then recurse for each of the }
		{ sub-areas. If it is not large enough, then just }
		{ add its coordinates to the CELLS list. }
		Procedure VerticalDivison;
			{ Attempt to divide this area with a vertical wall. }
		var
			MaybeD,D,Tries: Integer;
		begin
			tries := 0;
			D := 0;
			repeat
				MaybeD := Random( CH - 2 ) + 1;
				if IsGoodWallAnchor( CX0 - 1 , CY0 + MaybeD ) and IsGoodWallAnchor( CX0 + CW , CY0 + MaybeD ) then D := MaybeD;
				Inc( Tries );
			until ( D <> 0 ) or ( Tries > 5 );

			{ Check to make sure it's a good place. }
			if D <> 0 then begin
				{ Draw the wall. }
				DrawWall( GB, CX0, CY0 + D , CW, DW_Horizontal, WallType, ProtoDoor );

				{ Recurse to the two sub-areas. }
				DivideArea( CX0 , CY0 , CW , D );
				DivideArea( CX0 , CY0 + D + 1 , CW , CH - D - 1 );

			end else begin
				{ No room for further divisions. Just store this cell. }
				StoreSAtt( Cells , BStr( CX0 ) + ' ' + BStr( CY0 ) + ' ' + BStr( CW ) + ' ' + BStr( CH ) );
			end;
		end;

		Procedure HorizontalDivison;
			{ Attempt to divide this area with a vertical wall. }
		var
			MaybeD,D,Tries: Integer;
		begin
			tries := 0;
			D := 0;
			repeat
				MaybeD := Random( CW - 2 ) + 1;
				if IsGoodWallAnchor( CX0 + MaybeD , CY0 - 1 ) and IsGoodWallAnchor( CX0 + MaybeD , CY0 + CH ) then D := MaybeD;
				Inc( Tries );
			until ( D <> 0 ) or ( Tries > 5 );

			{ Check to make sure it's a good place. }
			if D <> 0 then begin
				{ Draw the wall. }
				DrawWall( GB, CX0 + D , CY0 , CH, DW_Vertical, WallType, ProtoDoor );

				{ Recurse to the two sub-areas. }
				DivideArea( CX0 , CY0 , D , CH );
				DivideArea( CX0 + D + 1 , CY0 , CW - D - 1 , CH );

			end else begin
				{ No room for further divisions. Just store this cell. }
				StoreSAtt( Cells , BStr( CX0 ) + ' ' + BStr( CY0 ) + ' ' + BStr( CW ) + ' ' + BStr( CH ) );
			end;
		end;
	begin
		if ( CW > 6 ) and ( CH > 1 ) and ( Random( 2 ) = 1 ) then begin
			HorizontalDivison;
		end else if ( CH > 6 ) and ( CW > 1 ) and ( Random( 2 ) = 1 ) then begin
			VerticalDivison;
		end else if ( CW > CH ) and ( CW > 4 ) and ( CH > 1 ) then begin
			HorizontalDivison;
		end else if ( CH > 4 ) and ( CW > 1 ) then begin
			VerticalDivison;
		end else begin
			{ No room for further divisions. Just store this cell. }
			StoreSAtt( Cells , BStr( CX0 ) + ' ' + BStr( CY0 ) + ' ' + BStr( CW ) + ' ' + BStr( CH ) );
		end;
	end;
begin
	{ Initialize values. }
	Cells := Nil;
	FloorType := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	WallType  := DecideTerrainType( MF , Cmd , STAT_MFBorder );
	ProtoDoor := SeekCurrentLevelGear( MF , GG_MetaTerrain , GS_MetaDoor );

	RectFill( GB , FloorType , 0 , X0 + 1 , Y0 + 1 , W - 2 , H - 2 );
	DivideArea( X0 + 1 , Y0 + 1 , W - 2 , H - 2 );
	ProcessMitose := Cells;
end;

Function ProcessMonkeyMaze( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer; MakeExternalDoor: Boolean ): SAttPtr;
	{ Draw a maze as featured in my non-hit game, Dungeon Monkey. }
	{ This procedure is lifted straight from that game's random map }
	{ generator, actually... It's about time GearHead got a new map }
	{ type, isn't it? }
var
	Cells: SAttPtr;
	FloorType,WallType: Integer;
	ProtoDoor: GearPtr;
	NXMax,NYMax: Integer;
const
	VecDir: Array [1..9,1..2] of Integer = (
	(-1, 1),( 0, 1),( 1, 1),
	(-1, 0),( 0, 0),( 1, 0),
	(-1,-1),( 0,-1),( 1,-1)
	);

	Function GetTerrain( X,Y: Integer ): Integer;
		{ Safely return the terrain of this tile. }
	begin
		if OnTheMap( X , Y ) then begin
			GetTerrain := gb^.Map[X,Y].terr;
		end else begin
			GetTerrain := 1;
		end;
	end;
	Function NodeX( ND: Integer ): Integer;
		{ Convert node coordinate ND to an actual map coordinate. }
	begin
		NodeX := ND * 5 - 3 + X0;
	end;
	Function NodeY( ND: Integer ): Integer;
		{ Convert node coordinate ND to an actual map coordinate. }
	begin
		NodeY := ND * 5 - 3 + Y0;
	end;
	Function AllNodesConnected: Boolean;
		{ Return TRUE if all the nodes have been connected, or }
		{ FALSE if some of them haven't been. }
	var
		FoundAWall: Boolean;
		NX,NY: Integer;
	begin
		{ At the beginning, we haven't found any walls yet. }
		FoundAWall := False;
		for NX := 1 to NXMax do begin
			for NY := 1 to NYMax do begin
				if GetTerrain( NodeX( NX ) , NodeY( NY ) ) = WallType then FoundAWall := True;
			end;
		end;
		AllNodesConnected := Not FoundAWall;
	end;
	Procedure DrawAnL( NX , NY: Integer );
		{ Draw an L-Shaped corridor on the map, centered on }
		{ node point NX, NY. }
	var
		X1,X2,Y1,Y2,XT,YT: Integer;
	begin
		{ Determine X0,X1,Y0,Y1 points. }
		if ( NX > 1 ) and ( ( Random( 2 ) = 1 ) or ( NX = NXMax ) ) then begin
			X1 := NodeX( NX ) - ( 5 * ( Random( NX - 1 ) + 1 ) );
			X2 := NodeX( NX );
		end else begin
			X1 := NodeX( NX );
			X2 := NodeX( NX ) + ( 5 * ( Random( NXMax - NX ) + 1 ) );
		end;
		if ( NY > 1 ) and ( ( Random( 2 ) = 1 ) or ( NY = NYMax ) ) then begin
			Y1 := NodeY( NY ) - ( 5 * ( Random( NY - 1 ) + 1 ) );
			Y2 := NodeY( NY );
		end else begin
			Y1 := NodeY( NY );
			Y2 := NodeY( NY ) + ( 5 * ( Random( NYMax - NY ) + 1 ) );
		end;
		for XT := X1 to X2 do begin
			if ( XT <> X1 ) and ( GetTerrain( XT , NodeY( NY ) ) = FloorType ) then break
			else DrawTerrain( GB , XT , NodeY( NY ) , FloorType , 0 );
		end;
		for YT := Y1 to Y2 do begin
			if ( YT <> Y1 ) and ( GetTerrain( NodeX( NX ) , YT ) = FloorType ) then break
			else DrawTerrain( GB , NodeX( NX ) , YT , FloorType , 0 );
		end;
	end; {DrawAnL}
	Procedure DrawOneLine( NX , NY: Integer );
		{ Draw an regular corridor on the map, centered on }
		{ node point NX, NY. }
	var
		X1,X2,Y1,Y2,XT,YT: Integer;
	begin
		{ Determine X0,X1,Y0,Y1 points. }
		if Random( 2 ) = 1 then begin
			if ( NX > 1 ) and ( ( Random( 2 ) = 1 ) or ( NX = NXMax ) ) then begin
				X1 := NodeX( NX ) - ( 5 * ( Random( NX - 1 ) + 1 ) );
				X2 := NodeX( NX );
			end else begin
				X1 := NodeX( NX );
				X2 := NodeX( NX ) + ( 5 * ( Random( NXMax - NX ) + 1 ) );
			end;

			for XT := X1 to X2 do begin
				if ( XT <> X1 ) and ( GetTerrain( XT , NodeY( NY ) ) = FloorType ) then break
				else DrawTerrain( GB , XT , NodeY( NY ) , FloorType , 0 );
			end;

		end else begin
			if ( NY > 1 ) and ( ( Random( 2 ) = 1 ) or ( NY = NYMax ) ) then begin
				Y1 := NodeY( NY ) - ( 5 * ( Random( NY - 1 ) + 1 ) );
				Y2 := NodeY( NY );
			end else begin
				Y1 := NodeY( NY );
				Y2 := NodeY( NY ) + ( 5 * ( Random( NYMax - NY ) + 1 ) );
			end;

			for YT := Y1 to Y2 do begin
				if ( YT <> Y1 ) and ( GetTerrain( NodeX( NX ) , YT ) = FloorType ) then break

				else DrawTerrain( GB , NodeX( NX ) , YT , FloorType , 0 );
			end;
		end;
	end; {DrawOneLine}

	Procedure CarveALine( NX , NY: Integer );
		{ Starting at the indicated node, attempt to carve a line from }
		{ NX,NY to another floor tile. }
	var
		D: Integer;
		X,Y: Integer;
	begin
		{ Select one of the four cardinal directions at random. }
		D := Random( 4 ) * 2 + 2;

		{ We'll use the VecDir array to direct the line. }
		X := NodeX( NX );
		Y := NodeY( NY );

		{ Keep traveling until we either find a floor or go off the map. }
		repeat
			X := X + VecDir[ D , 1 ];
			Y := Y + VecDir[ D , 2 ];
		until ( GetTerrain( X , Y ) = FloorType ) or ( Not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y ) );

		{ If we didn't go off the map, we must have hit a floor. Bonus! }
		{ Start carving the line in the randomly prescribed direction. }
		if RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y ) then begin
			X := NodeX( NX );
			Y := NodeY( NY );
			repeat
				DrawTerrain( GB , X , Y , FloorType , 0 );
				X := X + VecDir[ D , 1 ];
				Y := Y + VecDir[ D , 2 ];
			until ( GetTerrain( X , Y ) = FloorType ) or ( Not OnTheMap( X , Y ) );
		end;

	end; {CarveALine}

	Procedure DrawTheMaze;
		{ First step, generate a decent maze. }
	var
		NX,NY,Tries: Integer;
	begin
		{ Start with a random point, then draw an "L" there. }
		NX := Random( NXMax - 2 ) + 2;
		NY := Random( NYMax - 2 ) + 2;
		DrawAnL( NX , NY );

		Tries := 500;

		{ Randomly expand upon this maze until all the nodes have }
		{ been connected to one another. }
		repeat
			for NX := 1 to NXMax do begin
				for NY := 1 to NYMax do begin
					if GetTerrain( NodeX( NX ) , NodeY( NY ) ) = FloorType then begin
						if Random( 12 ) = 1 then DrawOneLine( NX , NY );
					end else begin
						CarveALine( NX , NY );
					end;
				end;
			end;

			Dec( Tries );
		until AllNodesConnected or ( Tries < 1 );

	end; {DrawTheMaze}

	Procedure FillDungeon;
		{ Fill the dungeon with rooms. }
	var
		NodeClear: Array [1..XMax div 5,1..YMax div 5] of Boolean;
			{ Lists nodes which have not yet been developed. }
		X,Y,NumRooms,TRoom: Integer;

		Function SelectClearNode: Point;
			{ Select a node which is free for development. }
		var
			P: Point;
			Tries: Integer;
		begin
			Tries := 500;
			repeat
				P.X := Random( NXMax ) + 1;
				P.Y := Random( NYMax ) + 1;
				Dec( Tries );
			until NodeClear[ P.X , P.Y ] or ( Tries < 1 );
			SelectClearNode := P;
		end;

		Procedure RoomRenderer( X1,Y1,W,H: Integer );
			{ Render a room, adding doors at whimsy. }
			Procedure MaybeAddDoor( DX,DY: Integer );
				{ Maybe add a door to this spot, or maybe not. }
			begin
				if Random( 4 ) <> 1 then begin
					DrawTerrain( GB , DX , DY , TERRAIN_Threshold , 0 );
					AddDoor( GB , MF , ProtoDoor , DX , DY );
				end;
			end;
		var
			RX,RY: Integer;
		begin
			RectFill( GB , FloorType , 0 , X1 , Y1 , W , H );

			for RX := X1 to ( X1 + W - 1 ) do begin
				if GetTerrain( RX , Y1 - 1 ) = FloorType then MaybeAddDoor( RX , Y1 - 1 );
				if GetTerrain( RX , Y1 + H ) = FloorType then MaybeAddDoor( RX , Y1 + H );
			end;
			for RY := Y1 to ( Y1 + H - 1 ) do begin
				if GetTerrain( X1 - 1 , RY ) = FloorType then MaybeAddDoor( X1 - 1 , RY );
				if GetTerrain( X1 + W , RY ) = FloorType then MaybeAddDoor( X1 + W , RY );
			end;

			{ Record this cell in the list. }
			StoreSAtt( Cells , BStr( X1 ) + ' ' + BStr( Y1 ) + ' ' + BStr( W ) + ' ' + BStr( H ) );
		end;

		Procedure DrawRoom( NX , NY: Integer );
			{ Draw a small square room centered on this node. }
		var
			NW,NH,X1,Y1,W,H,TX,TY: Integer;
		begin
			X1 := NodeX( NX ) - 1;
			Y1 := NodeY( NY ) - 1;
			NW := 1;
			NH := 1;
			W := 3;
			H := 3;

			{ Maybe expand this room, if space permits. }
			if ( NX < ( NXMax - 1 ) ) and ( NY < ( NYMax - 1 ) ) and ( Random( 5 ) = 1 ) then begin
				if NodeClear[ NX + 1 , NY ] and NodeClear[ NX + 1 , NY + 1 ] and NodeClear[ NX , NY + 1 ] then begin
					NW := NW + 1;
					NH := NH + 1;
					W := W + 5;
					H := H + 5;
				end;
			end else if ( NX < ( NXMax - 1 ) ) and ( Random( 4 ) = 1 ) then begin
				TX := Random( 3 ) + 1;
				while ( TX > 0 ) and ( ( NX + NW ) <= NXMax ) do begin
					if NodeClear[ NX + NW , NY ] then begin
						Inc( NW );
						W := W + 5;
						Dec( TX );
					end else begin
						TX := 0;
					end;
				end;
			end else if ( NX < ( NXMax - 1 ) ) and ( Random( 4 ) = 1 ) then begin
				TY := Random( 3 ) + 1;
				while ( TY > 0 ) and ( ( NY + NH ) <= NYMax ) do begin
					if NodeClear[ NX , NY + NH ] then begin
						Inc( NH );
						H := H + 5;
						Dec( TY );
					end else begin
						TY := 0;
					end;
				end;
			end;


			{ Call the renderer, block out the used nodes. }
			RoomRenderer( X1 , Y1 , W , H );
			for TX := NX to ( NX + NW - 1 ) do begin
				for TY := NY to ( NY + NH - 1 ) do begin
					NodeCLear[ TX , TY ] := False;
				end;
			end;
		end;
		Procedure AddRandomRoom;
			{ Add a randomly placed room to the map. }
		var
			P: Point;
		begin
			P := SelectClearNode;
			if NodeClear[ P.X , P.Y ] then DrawRoom( P.X , P.Y );
		end;

	begin
		{ First, prepare the nodemap. }
		{ Each node is ready for development if there's a floor tile there. }
		{ It's possible (though unlikely) that the maze generator didn't }
		{ fill the entire map, so check the status of each node tile to see }
		{ whether or not it's okay to build there. }
		for X := 1 to NXMax do begin
			for Y := 1 to NYMax do begin
				NodeClear[ X , Y ] := GetTerrain( NodeX( X ) , NodeY( Y ) ) = FloorType;
			end;
		end;

		NumRooms := ( NXMax * NYMax ) div 3;
		if NumRooms < 1 then NumRooms := 1;
		for TRoom := 1 to NumRooms do begin
			AddRandomRoom;
		end;
	end;

	Procedure AddWayOut;
		{ Far out! The DungeonMonkey maze generator can also }
		{ be used to build complex buildings! They have to be }
		{ pretty big (at least 15x10 or 10x15) but they should }
		{ work well. }
		Function IsGoodEntrance( X, Y, D: Integer ): Boolean;
			{ Check this point and direction to make sure }
			{ that it links up to a part of the maze. }
		var
			FoundFloor: Boolean;
		begin
			{ The entrance must start at a wall; I don't want }
			{ any double doors on the same tile. }
			if GetTerrain( X , Y ) <> WallType then Exit( False );

			{ If we're starting at a wall, check to make sure }
			{ this entrance will connect to the maze. }
			FoundFloor := False;
			{ Keep searching until we find a floor tile or exit }
			{ the bounding box. }
			repeat
				X := X + AngDir[ D , 1 ];
				Y := Y + AngDir[ D , 2 ];
				FoundFloor := GetTerrain( X , Y ) = FloorType;
			until FoundFloor or not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y );
			IsGoodEntrance := FoundFloor;
		end;
		Procedure RenderEntrance( X , Y , D: Integer );
			{ Render the maze as per above. }
		var
			FoundFloor: Boolean;
		begin
			{ Add the door. }
			DrawTerrain( GB , X , Y , TERRAIN_Threshold , 0 );
			AddDoor( GB , MF , ProtoDoor , X , Y );
			{ Add the hallway. }
			FoundFloor := False;
			repeat
				X := X + AngDir[ D , 1 ];
				Y := Y + AngDir[ D , 2 ];
				if GetTerrain( X , Y ) = FloorType then begin
					FoundFloor := True;
				end else begin
					DrawTerrain( GB , X , Y , FloorType , 0 );
				end;
			until FoundFloor or not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y );
		end;
	var
		Tries,DX,DY: Integer;
	begin
		{ This may take several attempts to get a good entrance... }
		Tries := 50;
		while Tries > 0 do begin
			{ Decide on a random direction and entry point. }
			Case Random( 4 ) of
			0:	begin
					DX := X0 + Random( W - 2 ) + 2;
					DY := Y0;
					if IsGoodEntrance( DX , DY , 2 ) then begin
						RenderEntrance( DX , DY , 2 );
						Tries := Tries - ( 10 + Random( 50 ) );
					end;
				end;
			1:	begin
					DX := X0 + Random( W - 2 ) + 2;
					DY := Y0 + H - 1;
					if IsGoodEntrance( DX , DY , 6 ) then begin
						RenderEntrance( DX , DY , 6 );
						Tries := Tries - ( 10 + Random( 50 ) );
					end;
				end;
			2:	begin
					DX := X0;
					DY := Y0 + Random( H - 2 ) + 2;
					if IsGoodEntrance( DX , DY , 0 ) then begin
						RenderEntrance( DX , DY , 0 );
						Tries := Tries - ( 10 + Random( 50 ) );
					end;
				end;
			else begin
					DX := X0 + W - 1;
					DY := Y0 + Random( W - 2 ) + 2;
					if IsGoodEntrance( DX , DY , 4 ) then begin
						RenderEntrance( DX , DY , 4 );
						Tries := Tries - ( 10 + Random( 50 ) );
					end;
				end;
			end;
			Dec( Tries );
		end;
	end;
begin
	{ Initialize values. }
	Cells := Nil;
	FloorType := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	WallType  := DecideTerrainType( MF , Cmd , STAT_MFBorder );
	ProtoDoor := SeekCurrentLevelGear( MF , GG_MetaTerrain , GS_MetaDoor );
	NXMax := W div 5;
	NYMax := H div 5;

	{ The entire area starts out devoid of stuff. }
	RectFill( GB , WallType , 0 , X0 , Y0 , W , H );

	{ If we have enough space, add cells! }
	if ( NXMax > 0 ) and ( NYMax > 0 ) then begin
		DrawTheMaze;
		FillDungeon;
		if MakeExternalDoor then AddWayOut;
	end;

	ProcessMonkeyMaze := Cells;
end;

Function ThingInSpot( GB: GameBoardPtr; X,Y: Integer ): Boolean;
	{ Return TRUE if there's a thing in the specified spot, FALSE otherwise. }
var
	M: GearPtr;
	it: Boolean;
begin
	it := False;
	if GB^.Scene <> Nil then begin
		M := GB^.Scene^.InvCom;
		while ( M <> Nil ) and not it do begin
			it := ( NAttValue( M^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( M^.NA , NAG_Location , NAS_Y ) = Y );
			M := M^.Next;
		end;
	end;
	ThingInSpot := it;
end;

Function SelectSpotInFeature( GB: GameBoardPtr; MF: GearPtr ): Point;
	{ Select a tile within the boundaries of this particular }
	{ map feature. }
var
	P: Point;
	T: Integer;
begin
	{ We will test random points a maximum of 100 times, after which }
	{ we'll just leave it wherever. }
	T := 100;

	repeat
		{ Select random X and Y values within the interior space of this feature. }
		if ( MF^.Stat[ Stat_MFWidth ] > 4 ) and ( MF^.Stat[ Stat_MFHeight ] > 4 ) then begin
			P.X := Random( MF^.Stat[ Stat_MFWidth ] - 4 ) + MF^.Stat[ STAT_XPos ] + 2;
			P.Y := Random( MF^.Stat[ Stat_MFHeight ] - 4 ) + MF^.Stat[ STAT_YPos ] + 2;
		end else if ( MF^.Stat[ Stat_MFWidth ] > 2 ) and ( MF^.Stat[ Stat_MFHeight ] > 2 ) and ( T = 100 ) then begin
			P.X := Random( MF^.Stat[ Stat_MFWidth ] - 2 ) + MF^.Stat[ STAT_XPos ] + 1;
			P.Y := Random( MF^.Stat[ Stat_MFHeight ] - 2 ) + MF^.Stat[ STAT_YPos ] + 1;
		end else if ( MF^.Stat[ Stat_MFWidth ] > 1 ) and ( MF^.Stat[ Stat_MFHeight ] > 1 ) then begin
			P.X := Random( MF^.Stat[ Stat_MFWidth ] ) + MF^.Stat[ STAT_XPos ];
			P.Y := Random( MF^.Stat[ Stat_MFHeight ] ) + MF^.Stat[ STAT_YPos ];
		end else begin
			P.X := MF^.Stat[ STAT_XPos ];
			P.Y := MF^.Stat[ STAT_YPos ];
			T := 0;
		end;
		Dec( T );
	until ( Not ThingInSpot( GB , P.X , P.Y ) ) or ( T < 1 );

	SelectSpotInFeature := P;
end;

Procedure PlaceMetaTerrain( GB: GameBoardPtr; MF: GearPtr );
	{ This map feature may contain metaterrain gears which }
	{ are meant to be placed inside of it. Do so now. }
var
	MT,MT2: GearPtr;
	P: Point;
begin
	MT := MF^.SubCom;
	while MT <> Nil do begin
		MT2 := MT^.Next;

		{ Check the InvComs for MetaTerrain, placing non-doors }
		{ on the map and deleting doors (since those will already }
		{ have been cloned and placed when the wall was drawn). }
		if ( MT^.G = GG_MetaTerrain ) then begin
			DelinkGear( MF^.SubCOm , MT );

			if MT^.S = GS_MetaDoor then begin
				{ This is a door. Delete it. }
				DisposeGear( MT );
			end else begin
				{ This is not a door. Place it somewhere }
				{ appropriate in the map feature. }
				P := SelectSpotInFeature( GB , MF );
				SetNAtt( MT^.NA , NAG_Location , NAS_X , P.X );
				SetNAtt( MT^.NA , NAG_Location , NAS_Y , P.Y );

				MT^.Scale := GB^.Scene^.V;

				{ Then, stick it into the scene's invcom, }
				{ so DeployJjang will place it on the map. }
				InsertInvCom( GB^.Scene , MT );
			end;
		end;

		MT := MT2;
	end;
end;

Procedure ShowArea( GB: GameBoardPtr; X0,Y0,W,H: Integer );
	{ Set the "visible" field for all tiles in the requested area to TRUE. }
Var
	X,Y: Integer;
begin
	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if OnTheMap( X , Y ) then GB^.Map[X,Y].Visible := True;
		end;
	end;
end;

Function TheRenderer( GB: GameBoardPtr; MF: GearPtr; X , Y , W , H , Style: Integer ): SAttPtr;
	{ Do some damage to the game board in the shape of this feature. }
	{ This function returns the STYLE of the part; }
	{ it describes what kind of feature we should be drawing. }
var
	Command_String,Cmd,Special: String;
	Cells: SAttPtr;
begin
	{ Determine the command string to use for this feature. }
	Command_String := '';
	if MF <> Nil then Command_String := SAttValue( MF^.SA , 'PARAM' );
	if Command_String = '' then Command_String := SAttValue( Standard_Param_List , 'PARAM' + BStr( Style ) );
	if Command_String = '' then Command_String := SAttValue( Standard_Param_List , 'PARAMDEFAULT' );

	Cells := Nil;

	while Command_String <> '' do begin
		cmd := UpCase( ExtractWord( Command_String ) );

		if cmd = 'FILL' then begin
			ProcessFill( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'WALL' then begin
			ProcessWall( GB , MF , Command_String , X , Y , W , H , False , False );

		end else if cmd = 'OWALL' then begin
			ProcessWall( GB , MF , Command_String , X , Y , W , H , True , False );

		end else if cmd = 'DWALL' then begin
			ProcessWall( GB , MF , Command_String , X , Y , W , H , True , True );

		end else if cmd = 'CARVE' then begin
			ProcessCarve( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'SCATTER' then begin
			ProcessScatter( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'ELLIPSE' then begin
			ProcessEllipse( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'LATTICE' then begin
			ProcessLattice( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'MITOSE' then begin
			Cells := ProcessMitose( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'MONKEYMAZE' then begin
			Cells := ProcessMonkeyMaze( GB , MF , Command_String , X , Y , W , H , FALSE );

		end else if cmd = 'MONKEYHOUSE' then begin
			Cells := ProcessMonkeyMaze( GB , MF , Command_String , X , Y , W , H , TRUE );

		end;
	end;

	{ Handle any SPECIAL commands associated with this map feature. }
	if ( MF <> Nil ) then begin
		Special := GetSpecial( MF );

		{ If this feature is indicated as the starting point for this scene }
		{ set the ParaX , ParaY attributes now. }
		if AStringHasBString( Special , SPECIAL_StartHere ) then begin
			SetNAtt( GB^.Scene^.NA , NAG_ParaLocation , NAS_X , MF^.Stat[ STAT_Xpos ] + 1 );
			SetNAtt( GB^.Scene^.NA , NAG_ParaLocation , NAS_Y , MF^.Stat[ STAT_Ypos ] + 1 );
		end;
		if AStringHasBString( Special , SPECIAL_ShowAll ) then begin
			ShowArea( GB , X , Y , W , H );
		end;
		if AStringHasBString( Special , SPECIAL_ConvertDoors ) then begin
			ConvertDoors( GB , SeekCurrentLevelGear( MF^.SubCom , GG_MetaTerrain , GS_MetaDoor ) , MF^.Stat[ STAT_XPos ] , MF^.Stat[ STAT_YPos ] , MF^.Stat[ STAT_MFWidth ] , MF^.Stat[ STAT_MFHeight ] );
		end;
	end;

	{ Place any metaterrain associated with this feature. }
	if MF <> Nil then PlaceMetaTerrain( GB , MF );

	TheRenderer := Cells;
end;

Procedure DoGapFilling( GB: GameBoardPtr; Container: GearPtr; C_X,C_Y,C_W,C_H,SCheck,STerr: Integer; Gapfill_String: String );
	{ Search the container for empty regions, filling them with junk }
	{ as appropriate. }
const
	MaxGFStyle = 7;
var
	P: Point;
	N,T,W,H,Style: Integer;
	GFStyle: Array [0..MaxGFStyle] of Integer;
	NewMF: GearPtr;
begin
	{ Only do this if the container area meets our minimum size. }
	if ( C_W > 12 ) and ( C_H > 12 ) then begin
		{ Extract the GF styles. }
		N := 0;
		for t := 0 to MaxGFStyle do begin
			GFStyle[ T ] := ExtractValue( Gapfill_String );
			if GFStyle[ t ] <> 0 then Inc( N );
		end;

		if N > 0 then begin
			{ Try to place an item on the map 100 times. }
			for t := 1 to 15000 do begin
				{ Choose a random width, height, and placement point in container. }
				W := Random( 15 ) + 3;
				H := Random( 15 ) + 3;
				Style := GFStyle[ Random( N ) ];
				P := RandomPointWithinBounds( Container , W , H );

				{ if this placement point is good, i.e. empty, then }
				{ fill it with one of the style types taken from the }
				{ GapFiller parameter string. }
				if PlacementPointIsGood( GB , Container , SCheck , STerr , P.X , P.Y , W , H  ) then begin
					if Container <> Nil then begin
						{ Create a new gear for this gap filler. }
						NewMF := NewGear( Nil );
						InsertSubCom( Container , NewMF );
						NewMF^.G := GG_MapFeature;
						NewMF^.S := Style;
						InitGear( NewMF );
						NewMF^.Stat[ STAT_XPos ] := P.X;
						NewMF^.Stat[ STAT_YPos ] := P.Y;
						NewMF^.Stat[ STAT_MFHeight ] := H;
						NewMF^.Stat[ STAT_MFWidth ] := W;
					end else begin
						NewMF := Nil;
					end;

					{ Render it on the map. }
					TheRenderer( GB , NewMF , P.X , P.Y , W , H , Style );
				end;
			end; { for t = 1 to 100 }
		end;
	end;
end;

Procedure RenderFeature( GB: GameBoardPtr; MF: GearPtr );
	{ Render the provided map feature on the provided game board }
	{ in all it's glory. GB must already be initialized for this }
	{ procedure to do it work. The order in which things will be }
	{ done is as follows: }
	{ - MF itself will be rendered. }
	{ - MF's subcoms will be recursively rendered via this procedure. }
	{ - If a GAPFILL string is defined, empty spaces within the }
	{   boundaries of MF will be sought and stuffed with stuff. }
var
	Cells: SAttPtr;
	SubFeature: GearPtr;
	Placement_String,Gapfill_String: String;
	X,Y,W,H,Style,Select_Check,Select_Terrain: Integer;
begin
	{ Initialize miscellaneous values. }
	Cells := Nil;
	if MF = Nil then begin
		{ This will be a basic-form scene. }
		Style := 0;
		X := 1;
		Y := 1;
		W := XMax;
		H := YMax;
	end else if MF^.G = GG_Scene then begin
		Style := MF^.Stat[ STAT_MapGenerator ];
		X := 1;
		Y := 1;
		W := XMax;
		H := YMax;
	end else if MF^.G = GG_MapFeature then begin
		Style := MF^.S;
		X := MF^.Stat[ STAT_XPos ];
		Y := MF^.Stat[ STAT_YPos ];
		W := MF^.Stat[ STAT_MFWidth ];
		H := MF^.Stat[ STAT_MFHeight ];
	end;

	{ Do the drawing. }
	Cells := TheRenderer( GB , MF , X , Y , W , H , Style );

	{ Now that we know the style, determine the SELECTOR parameters. }
	Placement_String := '';
	if MF <> Nil then Placement_String := SAttValue( MF^.SA , 'SELECTOR' );
	if Placement_String = '' then Placement_String := SAttValue( Standard_Param_List , 'SELECTOR' + BStr( Style ) );
	Select_Check := ExtractValue( Placement_String );
	if Select_Check <> 0 then Select_Terrain := DecideTerrainType( MF , Placement_String , ExtractValue( Placement_String ) );

	{ Also the GapFill parameters. }
	GapFill_String := '';
	if MF <> Nil then GapFill_String := SAttValue( MF^.SA , 'GAPFILL' );
	if GapFill_String = '' then GapFill_String := SAttValue( Standard_Param_List , 'GAPFILL' + BStr( Style ) );

	{ Loop through MF's subcoms here. }
	if MF <> Nil then begin
		SubFeature := MF^.SubCom;
		while SubFeature <> Nil do begin
			{ Select placement of SubFeature within boundaries of MF. }
			if SubFeature^.G = GG_MapFeature then begin
				SelectPlacementPoint( GB , MF , SubFeature , Cells , Select_Check , Select_Terrain );

				{ Call the renderer. }
				RenderFeature( GB , SubFeature );
			end;

			{ Move to the next sub-feature. }
			SubFeature := SubFeature^.Next;
		end;
	end;


	{ If GAPFILL defined, check for empty spaces. }
	if GapFill_String <> '' then DoGapFilling( GB , MF , X , Y , W , H , Select_Check , Select_Terrain , Gapfill_String );

	{ Delete the cells, since we're finished with them. }
	if Cells <> Nil then DisposeSAtt( Cells );
end;

function RandomMap( Scene: GearPtr ): GameBoardPtr;
	{Allocate a new GameBoard and stock it with random terrain.}
var
	it: GameBoardPtr;
	FName: String;
	F: Text;
begin
	it := NewMap;

	it^.Scene := Scene;
	if Scene <> Nil then begin
		FName := SAttValue( Scene^.SA , 'MAP' );
		if FName <> '' then begin
			Assign( F , Series_Directory + FName );
			Reset( F );
			it^.Map := ReadMap( F );
			Close( F );
		end;
	end else begin
		FName := '';
	end;
	if FName = '' then RenderFeature( it , Scene );

	RandomMap := it;
end;

initialization
	Standard_Param_List := LoadStringList( RandMaps_Param_File );

finalization
	DisposeSAtt( Standard_Param_List );

end.
