unit sdlmap;
{$MODE FPC}
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

uses SDL,SDL_ttf,sdlgfx,gears,gearutil,damage,locale,movement,ability,action,randmaps,effects,ghmecha,ui4gh,ghprop;

const
	{ DISPLAYSHOT CONSTANTS }
	SHOT_Hit = 0;
	SHOT_Dodge = 1;
	SHOT_Parry = 2;

	{ This constant is used by stairs and other portals. If a value }
	{ is addigned to it, the player character should appear on that }
	{ terrain after leaving the current level. }
	SCRIPT_Terrain_To_Seek: Integer = 0;


Function TeamColor( GB: GameBoardPtr; G: GearPtr ): TSDL_Color;
Function OnTheScreen( X , Y: Integer ): Boolean;
Function OnTheScreen( Mek: GearPtr ): Boolean;
Function NeedsRecentering( X,Y: Integer ): Boolean;

Function TeamColorString( GB: GameBoardPtr; M: GearPtr ): String;

Procedure RedrawTile( gb: GameBoardPtr; X,Y: Integer );
procedure RedrawTile( gb: GameBoardPtr; Mek: GearPtr );

procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer; Primary: Boolean );
procedure IndicateTile( GB: GameBoardPtr; Mek: GearPtr; Primary: Boolean );
procedure IndicateTile( GB: GameBoardPtr; X,Y: Integer );
Procedure MouseAtTile( GB: GameBoardPtr; X,Y: Integer );

Procedure RevealMek( GB: GameBoardPtr; Mek,Spotter: GearPtr );
Procedure VisionCheck( GB: GameBoardPtr; Mek: GearPtr );

Procedure DeployMek( GB: GameBoardPtr; Mek: GearPtr; PutOnMap: Boolean );
Procedure DeployMek( GB: GameBoardPtr; Mek,Pilot: GearPtr; Team: Integer );
Function LocateMekByUID( GB: GameBoardPtr; UID: Integer ): GearPtr;

Function TimeString( ComTime: LongInt ): String;
Procedure SDLCombatDisplay( GB: GameBoardPtr );

Procedure FocusOnMek( GB: GameBoardPtr; Mek: GearPtr );

Function DisplayEffectAnimations( GB: GameBoardPtr; N: Integer ): Boolean;

Procedure DisplayConsoleHistory( GB: GameBoardPtr );

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
Function ReadCampaign( var F: Text ): CampaignPtr;

Function ProcessMovement( GB: GameBoardPtr; Mek: GearPtr ): Boolean;

Procedure PrepOpening;
Procedure RedrawOpening;

Function ScreenToMap( X,Y: Integer ): Point;
Function MouseMapPos: Point;

Procedure BeginTurn( GB: GameBoardPtr; M: GearPtr );

implementation

uses texutil,menugear,ghchars;

Type
	Overlay_Description = Record
		Sprite: SensibleSpritePtr;
		F: Integer;	{ The frame to be displayed. }
		SubIcon: Integer;	{ Substitute icon to show on map border. }
		UseAlpha: Boolean;	{ Use alpha blending as appropriate. }
		name: String;		{ if NAMES_ABOVE_HEADS, print this. }
	end;

const
	{ This array tells whether or not a given terrain type requires an overlay. }
	Terrain_Toupee: Array [1..NumTerr] of Byte = (
		0, 1, 2, 3, 0,  0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,  0, 0, 0, 4, 0,
		3, 3, 0, 0, 0,  0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,  0, 0, 0, 0, 5,
		0, 0
	);

	NumThinWalls = 5;
	ThinWall_Earth = 1;
	ThinWall_RustySteel = 2;
	ThinWall_Stone = 3;
	ThinWall_Industrial = 4;
	ThinWall_Residential = 5;

	Terrain_Image: Array [1..NumTerr] of SmallInt = (
		 1, 2, 3, 4, 5,  6, 7, 8, 9,10,
		11,12,-5,14,-3, 16,17,18,19,20,
		21,22,23,24,25, 26,27,28,-ThinWall_RustySteel,30,
		-1,32,33,34,-4, 36,37,38,39,40,
		41,42
	);

	HalfTileWidth = 32;
	HalfTileHeight = 16;

	OriginX: LongInt = 80;	 { These constants tell what tile is being }
	OriginY: LongInt = -260; { displayed in the upper left corner of the }
				 { map area. }

	Terrain_Sprite_Name = 'big_terrain.png';
	Meta_Terrain_Sprite_Name = 'meta_terrain.png';
	Terrain_Toupee_Sprite_Name = 'iso_64b.png';
	Targeting_Srpite_Name = 'target64.png';
	Items_Sprite_Name = 'default_items.png';

	Default_Wreckage = 1;
{	Default_Dead_Thing = 2;}
	Default_Dead_Thing = 5;
	Default_Shadow = 3;
	Default_Unknown = 4;

	DefaultMaleSpriteName = 'cha_m_citizen.png';
	DefaultFemaleSpriteName = 'cha_f_citizen.png';
	DefaultMaleSpriteHead = 'cha_m_';
	DefaultFemaleSpriteHead = 'cha_f_';


	Strong_Hit_Sprite_Name = 'blast64.png';
	Weak_Hit_Sprite_Name = 'nodamage64.png';
	Parry_Sprite_Name = 'misc_parry.png';
	Miss_Sprite_Name = 'misc_miss.png';

	FROZEN_MAP_CONTINUE = 1;
	FROZEN_MAP_SENTINEL = -1;

	LowAlt = -3; { Lowest altitude to render. }
	HiAlt = 5; { Highest altitude to render. }
	Altitude_Height = 20; { Pixel height of each altitude layer. }

	NumOverlayLayers = 7;
	NumConstantLayers = 6;

	OVERLAY_Terrain = 0;
	OVERLAY_ThinWall = 1;
	OVERLAY_Shadow = 2;
	OVERLAY_Item = 3;
	OVERLAY_Metaterrain = 4;
	OVERLAY_Master = 5;
	OVERLAY_Toupee = 6;
	OVERLAY_Image = 7;

	SI_Ally = 3;
	SI_Neutral = 2;
	SI_Enemy = 1;

	NumOMM = 16;
	OM_North = 1;
	OM_East = 2;
	OM_South = 4;
	OM_West = 3;

	Map_Mid_X = 285;
	Map_Mid_Y = 229;

var
	OVERLAY_MAP: Array [ 1..XMax, 1..YMax, LowAlt..HiAlt, 0..NumOverlayLayers ] of Overlay_Description;
	MINI_MAP: Array [1..XMax, 1..YMax] of Byte;

	OFF_MAP_MODELS: Array [1..4,0..NumOMM] of Integer;

	Terrain_Sprite,Meta_Terrain_Sprite,Terrain_Toupee_Sprite,Targeting_Srpite,Items_Sprite: SensibleSpritePtr;
	Strong_Hit_Sprite,Weak_Hit_Sprite,Parry_Sprite,Miss_Sprite: SensibleSpritePtr;
	Thin_wall_Cap: SensibleSpritePtr;
	hill_1,hill_2,hill_3: SensibleSpritePtr;
	Off_Map_Model_Sprite: SensibleSpritePtr;
	Mini_Map_Sprite: SensibleSpritePtr;
    Door_Sprite: SensibleSpritePtr;

	Thin_Wall_Sprites: Array [1..NumThinWalls] of SensibleSpritePtr;

	Opening_Last_Anim_Phase: Uint32;
	Opening_X,Opening_Y: Integer;
	Opening_Phase,Opening_Count: Integer;

Procedure ClearOverlayLayer( L: Integer );
	{ Clear sprite descriptions from the provided overlay layer. }
var
	X,Y,Z: Integer;
begin
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			for Z := LowAlt to HiAlt do begin
				Overlay_Map[ X , Y , Z , L ].Sprite := Nil;
				Overlay_Map[ X , Y , Z , L ].SubIcon := 0;
				Overlay_Map[ X , Y , Z , L ].UseAlpha := False;
				Overlay_Map[ X , Y , Z , L ].Name := '';
			end;
		end;
	end;
end;

Procedure AddInstantOverlay( X,Y,Z,L,F: Integer; SS: SensibleSpritePtr );
	{ Add an overlay image safely to the display. }
begin
	if not OnTheMap( X , Y ) then Exit;
	if ( Z < LowAlt ) or ( Z > HiAlt ) then Exit;
	if ( L < 0 ) or ( L > NumOverlayLayers ) then Exit;
	Overlay_MAP[ X , Y , Z , L ].Sprite := SS;
	Overlay_MAP[ X , Y , Z , L ].F := F;
end;

Procedure AddOverlayIfClear( X,Y,Z,L,F: Integer; SS: SensibleSpritePtr );
	{ If the requested overlay slot is empty, fill it. Otherwise leave it alone. }
begin
	if not OnTheMap( X , Y ) then Exit;
	if Overlay_Map[ X , Y , Z , L ].Sprite = Nil then AddInstantOverlay( X,Y,Z,L,F,SS );
end;


Procedure AddOverlay( X,Y,Z,L: Integer; Name,Color,GName: String; W,H,F: Integer );
	{ Add an overlay image safely to the display. }
var
	SS: SensibleSpritePtr;
begin
	if not OnTheMap( X , Y ) then Exit;
	if ( Z < LowAlt ) or ( Z > HiAlt ) then Exit;
	if ( L < 0 ) or ( L > NumOverlayLayers ) then Exit;

	SS := ConfirmSprite( Name , Color , W , H );
	Overlay_MAP[ X , Y , Z , L ].Sprite := SS;
	Overlay_MAP[ X , Y , Z , L ].F := F;
	Overlay_MAP[ X , Y , Z , L ].Name := GName;
end;

Function TeamColor( GB: GameBoardPtr; G: GearPtr ): TSDL_Color;
	{ Select a good color based upon the team this }
	{ gear belongs to. }
var
	color: TSDL_Color;
	T: LongInt;
begin
	if ( G = Nil ) or ( GB = Nil ) then begin
		{ No gear provided - Neutral Gray. }
		color := NeutralGrey;

	end else if not GearOperational( G ) then begin
		{ Nonfunctioning gear. Color = DarkGrey. }
		color := DarkGrey;

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

Function RelativeX( X,Y: Integer ): LongInt;
	{ Return the relative position of tile X,Y. The UpLeft corner }
	{ of tile [1,1] is the origin of our display. }
begin
	RelativeX := ( (X-1) * HalfTileWidth ) - ( (Y-1) * HalfTileWidth );
end;

Function ScreenX( X,Y: Integer ): LongInt;
	{ Return the screen coordinates of map column X. }
begin
	ScreenX := RelativeX( X , Y ) + ZONE_Map.X + OriginX;
end;

Function RelativeY( X,Y: Integer ): LongInt;
	{ Return the relative position of tile X,Y. The UpLeft corner }
	{ of tile [1,1] is the origin of our display. }
begin
	RelativeY := ( (Y-1) * HalfTileHeight ) + ( (X-1) * HalfTileHeight );
end;

Function ScreenY( X,Y: Integer ): Integer;
	{ Return the screen coordinates of map row Y. }
begin
	ScreenY := RelativeY( X , Y ) + ZONE_Map.Y + OriginY;
end;

Function OnTheScreen( X , Y: Integer ): Boolean;
	{ This function returns TRUE if the specified point is visible }
	{ on screen, FALSE if it isn't. }
var
	SX,SY: LongInt;		{ Find Screen X and Screen Y and see if it's in the map area. }
begin
	SX := ScreenX( X , Y );
	SY := ScreenY( X , Y );
	if ( SX >= ( ZONE_Map.X - 64 ) ) and ( SX <= (ZONE_Map.X+ZONE_Map.w + 64) ) and ( SY >= ( ZONE_Map.Y - 64 ) ) and ( SY <= (ZONE_Map.Y + ZONE_Map.h + 64) ) then begin
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

Procedure RecenterDisplay( X , Y: Integer );
	{ Change the display so that point X,Y will be on screen. }
begin
	OriginX := ( ZONE_Map.w div 2 ) - RelativeX( X , Y );
	OriginY := ( ZONE_Map.h div 2 ) - RelativeY( X , Y );
end;

Function NeedsRecentering( X,Y: Integer ): Boolean;
	{ Check point X,Y to see whether or not the screen needs to be }
	{ centered upon it. }
begin
	NeedsRecentering := False;
end;

Procedure DrawOffMap( Quad,N: Integer );
	{ Draw an off-map model as indicated by the OFF_MAP_MODEL array. }
var
	MyDest: TSDL_Rect;
begin
	if Quad = OM_East then begin
		MyDest.Y := ZONE_Map.Y + ( ZONE_Map.H * ( N + 1 ) ) div ( NumOMM + 2 );
		MyDest.X := ZONE_Map.X + ZONE_Map.W - 16;
	end else if Quad = OM_West then begin
		MyDest.Y := ZONE_Map.Y + ( ZONE_Map.H * ( N + 1 ) ) div ( NumOMM + 2 );
		MyDest.X := ZONE_Map.X + 8;
	end else if Quad = OM_South then begin
		MyDest.X := ZONE_Map.X + ( ( ZONE_Map.W * ( N + 1 ) ) div ( NumOMM + 2 ) );
		MyDest.Y := ZONE_Map.Y + 8;
	end else begin
		MyDest.X := ZONE_Map.X + ( ( ZONE_Map.W * ( N + 1 ) ) div ( NumOMM + 2 ) );
		MyDest.Y := ZONE_Map.Y + ZONE_Map.H - 16;
	end;
	DrawSprite( Off_Map_Model_Sprite , MyDest , OFF_MAP_MODELS[ Quad , N ] - 1 + ( Animation_Phase div 5 mod 2 ) * 3 );
end;

Procedure RenderMap;
	{ Display the map and all its contents in the correct screen zone, }
	{ but don't do a Flip afterwards. }
var
	X,Y,Z,T,Quad: Integer;
	MyDest: TSDL_Rect;
begin
	{ Set the clip area. }
	ClrZone( ZONE_Map );
	SDL_SetClipRect( Game_Screen , @ZONE_Map );

	{ Clear the OFF_MAP_MODELS. }
	for X := 1 to 4 do begin
		for Y := 0 to NumOMM do begin
			OFF_MAP_MODELS[ X , Y ] := 0;
		end;
	end;

	{ Go through each tile on the map, displaying terrain and }
	{ other contents. }
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			if OnTheScreen( X , Y ) then begin
				for Z := LowAlt to HiAlt do begin
					for t := 0 to NumOverlayLayers do begin
						if OVERLAY_MAP[ X ,Y , Z , T ].Sprite <> Nil then begin
							MyDest.X := ScreenX( X , Y );
							MyDest.Y := ScreenY( X , Y ) - Altitude_Height * Z;
							if OVERLAY_MAP[ X ,Y , Z , T ].Sprite^.H > 64 then MyDest.Y := MyDest.Y - 32;
							if Use_Alpha_Blending and OVERLAY_MAP[ X ,Y , Z , T ].UseAlpha and ( Abs( MyDest.Y - Map_Mid_Y ) < 64 ) and ( Abs( MyDest.X - Map_Mid_X ) < 128 ) then begin
								DrawAlphaSprite( OVERLAY_MAP[ X ,Y , Z , T ].Sprite , MyDest , OVERLAY_MAP[ X ,Y , Z , T ].F );
							end else begin
								DrawSprite( OVERLAY_MAP[ X ,Y , Z , T ].Sprite , MyDest , OVERLAY_MAP[ X ,Y , Z , T ].F );
							end;
							if ( OVERLAY_MAP[ X ,Y , Z , T ].name <> '' ) and NAMES_ABOVE_HEADS then begin
								MyDest.X := ScreenX( X , Y ) + HalfTileWidth;
								MyDest.Y := ScreenY( X , Y ) - Altitude_Height * Z - 10;
								QuickTinyText( OVERLAY_MAP[ X ,Y , Z , T ].name , MyDest , StdWhite );
							end;
						end;
					end;
				end; { For Z... }
			end else if OVERLAY_MAP[ X , Y , 0 , OVERLAY_Master ].SubIcon > 0 then begin
				{ This image is off the map, but has a substitute image }
				{ so it should be indicated on the edge. }
				{ Add a note to the OFF_MAP_MODELS array. }
				{ Figure out its relative coordinates, with the center of the map }
				{ as the origin. }
				MyDest.X := ScreenX( X , Y ) - ( ZONE_Map.X + ZONE_Map.W div 2 );
				MyDest.Y := ScreenY( X , Y ) - ( ZONE_Map.Y + ZONE_Map.H div 2 );

				{ Use W to save the segment total length, and H to store the }
				{ relative length. }

				Quad := 1;
				if MyDest.Y <= MyDest.X then Quad := Quad + 1;
				if MyDest.Y <= -MyDest.X then Quad := Quad + 2;

				if ( Quad = 1 ) or ( Quad = 4 ) then begin
					MyDest.W := Abs( MyDest.Y ) * 2;
					MyDest.H := MyDest.X + Abs( MyDest.Y );
				end else begin
					MyDest.W := Abs( MyDest.X ) * 2;
					MyDest.H := MyDest.Y + Abs( MyDest.X );
				end;

				OFF_MAP_MODELS[ Quad , ( MyDest.H * NumOMM ) div MyDest.W ] := OVERLAY_MAP[ X , Y , 0 , OVERLAY_Master ].SubIcon;
			end; { if OnTheScreen... }

		end;
	end;

	{ Display the OFF_MAP_MODELS along the appropriate map edges. }
	for t := 0 to NumOMM do begin
		if Off_Map_Models[ OM_North , T ] > 0 then DrawOffMap( OM_North , T );
		if Off_Map_Models[ OM_South , T ] > 0 then DrawOffMap( OM_South , T );
		if Off_Map_Models[ OM_West , T ] > 0 then DrawOffMap( OM_West , T );
		if Off_Map_Models[ OM_East , T ] > 0 then DrawOffMap( OM_East , T );
	end;

	{ Display the MINI_MAP }
	if Display_Mini_Map then begin
		for x := 1 to XMax do begin
			for y := 1 to YMax do begin
				MyDest.X := ZONE_Map.X + 8 + X*3;
				MyDest.Y := ZONE_Map.Y + 8 + Y*3;
				if ( Mini_Map[ X , Y ] > 0 ) and ( Mini_Map[ X , Y ] < 10 ) then begin
					DrawSprite( Mini_Map_Sprite , MyDest , Mini_Map[ X , Y ] + ( Animation_Phase div 5 mod 2 ) );
				end else begin
					DrawSprite( Mini_Map_Sprite , MyDest , Mini_Map[ X , Y ] );
				end;
			end;
		end;
	end;

	{ Restore the clip area. }
	SDL_SetClipRect( Game_Screen , Nil );
end;

Function GearSpriteName( GB: GameBoardPtr; M: GearPtr ): String;
	{ Locate the sprite name for this gear. If no sprite name is defined, }
	{ set the default sprite name for the gear type & store it as a string }
	{ attribute so we won't need to do this calculation later. }
const
	FORM_DEFAULT: Array [1..NumForm] of String = (
	'btr_buruburu.png','zoa_scylla.png','ghu_ultari.png',
	'ara_kojedo.png', 'aer_wraith.png', 'orn_wasp.png',
	'ger_harpy.png', 'aer_bluebird.png', 'gca_rover.png'
	);
	mini_sprite = 'cha_pilot.png';
var
	it: String;
	FList: SAttPtr;
begin
	{ If this model is an out-of-scale character, return the mini-sprite. }
	if ( M^.G = GG_Character ) and ( M^.Scale < GB^.Scale ) then Exit( mini_sprite );

	it := SAttValue( M^.SA , 'SDL_SPRITE' );
	if it = '' then begin
		if M^.G = GG_Character then begin
			if NAttValue( M^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
				it := DefaultMaleSpriteHead;
			end else begin
				it := DefaultFemaleSpriteHead;
			end;
			it := it + LowerCase( SAttValue( M^.SA , 'JOB' ) ) + '.*';
			FList := CreateFileList( Graphics_Directory + it );
			if FList <> Nil then begin
				it := SelectRandomSAtt( FList )^.Info;
				DisposeSAtt( FList );
			end else begin
				if NAttValue( M^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
					it := DefaultMaleSpriteName;
				end else begin
					it := DefaultFemaleSpriteName;
				end;
			end;
		end else if ( M^.G = GG_Mecha ) and ( M^.S >= 0 ) and ( M^.S < NumForm ) then begin
			it := FORM_DEFAULT[ M^.S + 1 ];
		end else begin
			it := Items_Sprite_Name;
		end;
		SetSAtt( M^.SA , 'SDL_SPRITE <' + it + '>' );
	end;
	GearSpriteName := it;
end;

Function TeamColorString( GB: GameBoardPtr; M: GearPtr ): String;
	{ Determine the color string for this model. }
var
	it: String;
	T: Integer;
	Team: GearPtr;
begin
	it := SAttValue( M^.SA , 'SDL_COLORS' );
	if ( it = '' ) then begin
		T := NAttValue( M^.NA , NAG_Location , NAS_Team );
		Team := LocateTeam( GB , T );
		if Team <> Nil then it := SAttValue( Team^.SA , 'TEAM_COLORS' );

		if it = '' then begin
			if M^.G = GG_Character then begin
				if T = NAV_DefPlayerTeam then begin
					it := '66 121 179';
				end else if AreEnemies( GB , T , NAV_DefPlayerTeam ) then begin
					it := '180 10 120';
				end else if AreAllies( GB , T , NAV_DefPlayerTeam ) then begin
					it := '66 121 119';
				end else begin
					it := '175 175 171';
				end;
			end else begin
				if T = NAV_DefPlayerTeam then begin
					it := '66 121 179 210 215 80 205 25 0';
				end else if AreEnemies( GB , T , NAV_DefPlayerTeam ) then begin
					it := '180 10 120  125 125 125 170 205 75';
				end else if AreAllies( GB , T , NAV_DefPlayerTeam ) then begin
					it := '66 121 119 190 190 190 0 205 0';
				end else begin
					it := '175 175 171 100 100 120 0 200 200';
				end;
			end;
		end;

		if M^.G = GG_Character then begin
            it := it + ' ' + RandomColorString( CS_Skin ) + ' ' + RandomColorString( CS_Hair );
        end;

		SetSAtt( M^.SA , 'SDL_COLORS <' + it + '>' );
	end;
	TeamColorString := it;
end;

procedure NFDisplayMap( gb: GameBoardPtr );
	{ Actually display the map. }
	Function EffectiveWall( X , Y : Integer ): Boolean;
		{ Return TRUE if X,Y is a wall, a threshold, or not on the map. }
	begin
		if Not OnTheMap( X , Y ) then begin
			EffectiveWall := True;
		end else if GB^.Map[ X , Y ].terr = Terrain_Threshold then begin
			EffectiveWall := True;
		end else if TerrMan[ GB^.Map[ X , Y ].terr ].Pass < -99 then begin
			EffectiveWall := True;
		end else begin
			EffectiveWall := False;
		end;
	end;
	Function WallFrame( X , Y : Integer ): Integer;
		{ Given 16 different thinwall frames, determine which one is right }
		{ for this tile. }
	var
		F: Integer;
	begin
		F := 0;
		if EffectiveWall( X - 1 , Y ) then F := 1;
		if EffectiveWall( X , Y - 1 ) then F := F + 2;
		if EffectiveWall( X + 1 , Y ) then F := F + 4;
		if EffectiveWall( X , Y + 1 ) then F := F + 8;
		WallFrame := F;
	end;
	Function WallCapFrame( X , Y : Integer ): Integer;
		{ Given 16 different thinwall frames, determine which one is right }
		{ for this tile. }
	var
		F: Integer;
	begin
		F := 0;
		if EffectiveWall( X - 1 , Y - 1 ) and EffectiveWall( X - 1 , Y ) and EffectiveWall( X , Y - 1 ) then F := 1;
		if EffectiveWall( X + 1 , Y - 1 ) and EffectiveWall( X + 1 , Y ) and EffectiveWall( X , Y - 1 ) then F := F + 2;
		if EffectiveWall( X + 1 , Y + 1 ) and EffectiveWall( X + 1 , Y ) and EffectiveWall( X , Y + 1 ) then F := F + 4;
		if EffectiveWall( X - 1 , Y + 1 ) and EffectiveWall( X - 1 , Y ) and EffectiveWall( X , Y + 1 ) then F := F + 8;
		WallCapFrame := F;
	end;
	Function EffectiveFloor( X , Y: Integer ): Boolean;
		{ Return TRUE if the listed tile is on the map and a non-threshold floor. }
	begin
		EffectiveFloor := OnTheMap( X , Y ) and ( GB^.Map[ X , Y ].terr <> terrain_threshold ) and ( TerrMan[ GB^.Map[ X , Y ].terr ].Obscurement = 0 );
	end;
	Function WallFloorFrame( X , Y: Integer ): Integer;
		{ The thin walls don't come with their own floors. So, we'll pick a floor style }
		{ from the surrounding terrain. }
	begin
		if EffectiveFloor( X + 1 , Y + 1 ) then WallFloorFrame := GB^.Map[ X + 1 , Y + 1 ].terr - 1
		else if EffectiveFloor( X , Y + 1 ) then WallFloorFrame := GB^.Map[ X , Y + 1 ].terr - 1
		else if EffectiveFloor( X + 1 , Y ) then WallFloorFrame := GB^.Map[ X + 1 , Y ].terr - 1
		else WallFloorFrame := 5;
	end;
	Function EffectiveHill( X , Y , MinZ : Integer ): Boolean;
		{ Return TRUE if X,Y is a hill, or not on the map. }
	begin
		if Not OnTheMap( X , Y ) then begin
			EffectiveHill := True;
		end else begin
			EffectiveHill := TerrMan[ GB^.Map[ X , Y ].terr ].Altitude >= MinZ;
		end;
	end;
	Function HillFrame( X , Y : Integer ): Integer;
		{ Given 16 different thinwall frames, determine which one is right }
		{ for this tile. }
	var
		F: Integer;
	begin
		F := 0;
		if EffectiveHill( X - 1 , Y , TerrMan[ GB^.Map[ X , Y ].terr ].Altitude ) then F := 1;
		if EffectiveHill( X , Y - 1 , TerrMan[ GB^.Map[ X , Y ].terr ].Altitude ) then F := F + 2;
		if EffectiveHill( X + 1 , Y , TerrMan[ GB^.Map[ X , Y ].terr ].Altitude ) then F := F + 4;
		if EffectiveHill( X , Y + 1 , TerrMan[ GB^.Map[ X , Y ].terr ].Altitude ) then F := F + 8;
		HillFrame := F;
	end;

var
	X,Y,Z,T: Integer;
	M: GearPtr;
begin
	{ Clear the overlay grids. We'll be calculating everything fresh. }
	for t := 0 to NumConstantLayers do ClearOverlayLayer( T );

	{ Draw the terrain itself first. }
	for x := 1 to XMax do begin
		for Y := 1 to YMax do begin
			if GB^.Map[ X , Y ].Visible then begin
				Mini_Map[ X , Y ] := GB^.Map[ X , Y ].terr + 9;
				if GB^.Map[ X , Y ].terr = 8 then begin
					AddInstantOverlay( X , Y , 0 , OVERLAY_Terrain , HillFrame( X , Y ) , Hill_1 );
					Overlay_Map[ X , Y , 0 , OVERLAY_Terrain ].UseAlpha := True;
				end else if GB^.Map[ X , Y ].terr = 9 then begin
					AddInstantOverlay( X , Y , 0 , OVERLAY_Terrain , HillFrame( X , Y ) , Hill_2 );
					Overlay_Map[ X , Y , 0 , OVERLAY_Terrain ].UseAlpha := True;
				end else if GB^.Map[ X , Y ].terr = 10 then begin
					AddInstantOverlay( X , Y , 0 , OVERLAY_Terrain , HillFrame( X , Y ) , Hill_3 );
					Overlay_Map[ X , Y , 0 , OVERLAY_Terrain ].UseAlpha := True;
				end else if Terrain_Image[ GB^.Map[ X , Y ].terr ] < 0 then begin
					AddInstantOverlay( X , Y , 0 , OVERLAY_Terrain , WallFloorFrame( X , Y ) , Terrain_Sprite );
					AddInstantOverlay( X , Y , 0 , OVERLAY_ThinWall , WallFrame( X , Y ) , Thin_Wall_Sprites[ -Terrain_Image[ GB^.Map[ X , Y ].terr ] ] );
					AddInstantOverlay( X , Y , 0 , OVERLAY_Toupee , WallCapFrame( X , Y ) , Thin_Wall_Cap );
					Overlay_Map[ X , Y , 0 , OVERLAY_ThinWall ].UseAlpha := True;
					Overlay_Map[ X , Y , 0 , OVERLAY_Toupee ].UseAlpha := True;
				end else begin
					AddInstantOverlay( X , Y , 0 , OVERLAY_Terrain , GB^.Map[ X , Y ].terr - 1 , Terrain_Sprite );
					if Terrain_Toupee[ GB^.Map[ X , Y ].terr ] <> 0 then AddInstantOverlay( X , Y , 0 , OVERLAY_Toupee , Terrain_Toupee[ GB^.Map[ X , Y ].terr ] - 1 , Terrain_Toupee_Sprite );
				end;
			end else begin
				Mini_Map[ X , Y ] := 0;
				AddInstantOverlay( X , Y , 0 , OVERLAY_Terrain , DEFAULT_Unknown , Items_Sprite );
			end;
		end;
	end;

	{ Next add the items to the map. }
	M := GB^.Meks;
	while M <> Nil do begin
		X := NAttValue( M^.NA , NAG_Location , NAS_X );
		Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
		Z := MekAltitude( GB , M );
		if IsMasterGear(M) and NotDestroyed( M ) then begin
			if OnTheMap( X , Y ) and MekVisible( GB , M ) then begin
				if M^.G = GG_Prop then begin
					AddOverlay( X , Y , Z , OVERLAY_Master , GearSpriteName( GB , M ) , '' , GearName( M ) , 64 , 64 , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) );
				end else begin
					AddOverlay( X , Y , Z , OVERLAY_Master , GearSpriteName( GB , M ) , TeamColorString( GB , M ) , PilotName( M ) , 64 , 64 , ( NAttValue( M^.NA , NAG_Location , NAS_D ) + 1 ) mod 8 );
				end;

				{ Record what substitute icon to use if this model is off the map. }
				if AreAllies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
					OVERLAY_MAP[ X , Y , 0 , OVERLAY_Master ].SubIcon := SI_Ally;
					Mini_Map[ X , Y ] := 5;
				end else if AreEnemies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
					OVERLAY_MAP[ X , Y , 0 , OVERLAY_Master ].SubIcon := SI_Enemy;
					Mini_Map[ X , Y ] := 1;
				end else begin
					OVERLAY_MAP[ X , Y , 0 , OVERLAY_Master ].SubIcon := SI_Neutral;
					Mini_Map[ X , Y ] := 3;
				end;

				{ Also record a shadow. }
				AddInstantOverlay( X , Y , TerrMan[ GB^.Map[ X , Y ].terr ].altitude , OVERLAY_Shadow , Default_Shadow , Items_Sprite );
			end;
		end else begin
			if OnTheMap( X , Y ) and GB^.Map[X,Y].Visible then begin
				if ( M^.G = GG_Mecha ) or ( M^.G = GG_Prop ) then begin
					AddInstantOverlay( X , Y , Z , OVERLAY_Item , Default_Wreckage , Items_Sprite );
				end else if M^.G = GG_Character then begin
					AddInstantOverlay( X , Y , Z , OVERLAY_Item , Default_Dead_Thing , Items_Sprite );
				end else if M^.G = GG_MetaTerrain then begin
					if NotDestroyed( M ) and MekVisible( GB , M ) then 
						if M^.S = GS_MetaCloud then begin
							for t := Z to HiAlt do begin
								AddOverlayIfClear( X , Y , T , OVERLAY_Metaterrain , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) , Meta_Terrain_Sprite );
							end;
						end else if ( M^.S = GS_MetaFire ) and ( Z < 1 ) then begin
							for t := Z to 1 do begin
								AddInstantOverlay( X , Y , T , OVERLAY_Metaterrain , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) , Meta_Terrain_Sprite );
							end;
                        end else if ( M^.S = GS_MetaDoor ) then begin
                            { New for 2016- thin doors to go with the thin walls. Yay! }
                            t := 0;
                            if EffectiveWall( X + 1, Y ) then t := t + 1;
                            if M^.stat[ STAT_Pass ] = 0 then t := t + 2;
							AddInstantOverlay( X , Y , Z , OVERLAY_Metaterrain , t , Door_Sprite );
						end else begin
							AddInstantOverlay( X , Y , Z , OVERLAY_Metaterrain , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) , Meta_Terrain_Sprite );
						end;
				end else begin
					AddOverlay( X , Y , Z , OVERLAY_Item , GearSpriteName( GB , M ) , '' , '' , 64 , 64 , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) );
				end;
			end;
		end;
		M := M^.Next;
	end;

	{ Call the main map rendering routine. }
	RenderMap;
end;

Procedure RedrawTile( gb: GameBoardPtr; X,Y: Integer );
	{ Just call the above procedure with a Hilight value of FASLE. }
var
	T: Integer;
begin
	if not OnTheMap( X , Y ) then Exit;
	for t := LowAlt to HiAlt do begin
		Overlay_MAP[ X , Y , T , OVERLAY_Image ].Sprite := Nil;
	end;
end;

procedure RedrawTile( gb: GameBoardPtr; Mek: GearPtr );
	{ Display the tile containing the listed gear. }
	{ If the tile is not currently visible, the map will be recentered. }
var
	P: Point;
begin
	P := GearCurrentLocation( Mek );
	if OnTheMap( p.X , P.Y ) then RedrawTile( gb , P.X , P.Y );
end;

procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer; Primary: Boolean );
	{Indicate the desired tile with a rectangle of the requested color. }
begin
	{ Check the range of the coordinates we've been given. }
	if not OnTheMap( X , Y ) then exit;
	if ( Z < LowAlt ) or ( Z > HiAlt ) then Z := 0;

	Overlay_MAP[ X , Y , Z , OVERLAY_IMAGE ].Sprite := Targeting_Srpite;
	Overlay_MAP[ X , Y , Z , OVERLAY_IMAGE ].F := 0;

	if Primary then begin
		RecenterDisplay( X , Y );
	end;
end;

procedure IndicateTile( GB: GameBoardPtr; Mek: GearPtr; Primary: Boolean );
	{ Indicate the tile containing the listed gear. }
var
	team: Integer;
begin
	team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
	if MekVisible( GB , Mek ) and ( OnTheScreen( Mek ) or ( Team = NAV_DefPlayerTeam ) ) then IndicateTile( GB , NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) , MekAltitude( GB , Mek ) , Primary );
end;

procedure IndicateTile( GB: GameBoardPtr; X,Y: Integer );
	{ Indicate a tile. }
begin
	if OnTheMap( X , Y ) then begin
		IndicateTile( GB , X , Y , TerrMan[ GB^.Map[ X , Y ].terr ].Altitude , True );
	end;
end;

Procedure MouseAtTile( GB: GameBoardPtr; X,Y: Integer );
	{ The mouse is apparently hovering over this tile. Draw the mouse cursor here. }
begin
	ClearOverlayLayer( OVERLAY_IMAGE );
	if OnTheMap( X , Y ) then begin
		Overlay_MAP[ X , Y , 0 , OVERLAY_IMAGE ].Sprite := Targeting_Srpite;
		Overlay_MAP[ X , Y , 0 , OVERLAY_IMAGE ].F := 1;
	end;
end;


Procedure RevealMek( GB: GameBoardPtr; Mek,Spotter: GearPtr );
	{ This mek has been spotted. Light it up. }
var
	team: Integer;
begin
	team := NAttValue( Spotter^.NA , NAG_Location , NAS_Team );
	SetNAtt( Mek^.NA , NAG_Visibility , Team , NAV_Spotted );
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
	if ( Mek = Nil ) or ( not GearOperational( Mek ) ) then exit;

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

	if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
		CheckVisibleArea( GB , Mek );
	end;
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
	SetNAtt( mek^.NA , NAG_EpisodeData, NAS_UID, MaxIdTag( GB^.Meks , NAG_EpisodeData, NAS_UID ) + 2 );

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

Procedure SDLCombatDisplay( GB: GameBoardPtr );
	{ Do each of the standard GearFitr display elements. }
var
	pmsg: PChar;
	MyImage: PSDL_Surface;
begin
	SetupCombatDisplay;
	NFDisplayMap( GB );
	CMessage( TimeString( GB^.ComTime ) , ZONE_Clock , NeutralGrey );

	{ Update the console. }
	RedrawConsole;
end;

Procedure FocusOnMek( GB: GameBoardPtr; Mek: GearPtr );
	{ Recenter the display on the indicated mecha. }
var
	P: Point;
begin
	if ( Mek <> Nil ) and ( GB <> Nil ) then begin
		P := GearCurrentLocation( Mek );
		RecenterDisplay( P.X , P.Y );
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
	Z1 = 3;
	X2 = 4;
	Y2 = 5;
	Z2 = 6;
var
	P: Point;
begin
	{ Increase the counter, and find the next spot. }
	Inc( AnimOb^.V );
	P := SolveLine( AnimOb^.Stat[ X1 ] , AnimOb^.Stat[ Y1 ] , AnimOb^.Stat[ Z1 ] , AnimOb^.Stat[ X2 ] , AnimOb^.Stat[ Y2 ] , AnimOb^.Stat[ Z2 ] , AnimOb^.V );

	{ If this is the destination point, then we're done. }
	if ( P.X = AnimOb^.Stat[ X2 ] ) and ( P.Y = AnimOb^.Stat[ Y2 ] ) then begin
		RemoveGear( AnimList , ANimOb );
		P.X := 0;

	{ If this is not the destination point, draw the missile. }
	end else begin
		{Display bullet...}
		AddInstantOverlay( P.X , P.Y , P.Z , OVERLAY_IMAGE , 1 , Strong_Hit_Sprite );
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
	Z = 3;
var
	it: Boolean;
begin
	if AnimOb^.V < 10 then begin
		case AnimOb^.S of
		GS_DamagingHit: begin
				AddInstantOverlay( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , OVERLAY_IMAGE , AnimOb^.V , Strong_Hit_Sprite );

				end;
		GS_ArmorDefHit: begin
				AddInstantOverlay( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , OVERLAY_IMAGE , AnimOb^.V , Weak_Hit_Sprite );

				end;

		GS_Parry:	begin
				AddInstantOverlay( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , OVERLAY_IMAGE , ( AnimOb^.V + 1 ) div 2 , Parry_Sprite );
				Inc( AnimOb^.V );
				end;

		GS_Dodge:	begin
				AddInstantOverlay( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , OVERLAY_IMAGE , ( AnimOb^.V + 1 ) div 2 , Miss_Sprite );
				Inc( AnimOb^.V );
				end;

		GS_Backlash:	begin
				AddInstantOverlay( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , OVERLAY_IMAGE , AnimOb^.V , Strong_Hit_Sprite );

				end;
		GS_AreaAttack:	begin
				AddInstantOverlay( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , OVERLAY_IMAGE , AnimOb^.V , Strong_Hit_Sprite );

				end;
		end;


		{ Increment the counter. }
		Inc( AnimOb^.V );

		it := OnTheScreen( AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] );
	end else begin

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
		{ Erase all current image overlays. }
		ClearOverlayLayer( OVERLAY_Image );

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
		if DelayThisFrame then begin
			SDLCombatDisplay( GB );
			GHFlip;
			if ( FrameDelay > 0 ) then SDL_Delay(FrameDelay);
		end;
	end;

	ClearOverlayLayer( OVERLAY_Image );
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

Function ProcessMovement( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ Call the LOCALE movement routine, then update the display }
	{ here if need be. }
var
	result,Team: Integer;
	X,Y: LongInt;
	MSV: Boolean;	{ Mek Started Visible. }
	Msg: String;
begin
	{ Store the initial position of the mek. }
	X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );

	MSV := MekVisible( GB , Mek ) and OnTheScreen( X , Y );

	{ Call the movement procedure, and store the result. }
	result := EnactMovement( GB , Mek );

	{ Depending upon what happened, update the display. }
	if result > 0 then begin
		{ Update the display. }

		{ Check for previously unseen enemies. }
		if OnTheMap( NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) ) then VisionCheck( GB , Mek )
		{ Print message if mek has fled the battle. }
		else begin
			DialogMSG( PilotName( Mek ) + ' has left this area.');

			{ Set trigger here. }
			Team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
			SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
		end;

	end else if result = EMR_Crash then begin
		if Mek^.G = GG_Character then begin
			msg := ReplaceHash( MsgString( 'PROCESSMOVEMENT_Fall' ) , GearName( Mek ) );
		end else begin
			msg := ReplaceHash( MsgString( 'PROCESSMOVEMENT_Crash' ) , GearName( Mek ) );
		end;
		DialogMsg( ReplaceHash( msg , BStr( DAMAGE_DamageDone ) ) );
	end;
	ProcessMovement := ( Result <> 0 ) and ( MSV or ( OnTheScreen( Mek ) and MekVisible( GB , Mek ) ) );
end;

Procedure PrepOpening;
	{ Prepare some graphics for the opening of the game. }
const
	FormPat: Array [1..NumForm] of String[6] = (
		'btr_*','zoa_*','ghu_*','ara_*','aer_*',
		'orn_*','ger_*','hov_*','gca_*'
	);
var
	GB: GameBoardPtr;
	Scene: GearPtr;
	X,Y,T: Integer;
	Sprite_Names: SAttPtr;
	name: String;
	SS: SensibleSpritePtr;
begin
	{ Clear the sprite list just to conserve memory. }
	CleanSpriteList;

	{ Start with a random forest map. }
	Scene := NewGear( Nil );
	Scene^.G := GG_Scene;
	Scene^.Stat[ 1 ] := 1;
	GB := RandomMap( Scene );

	{ Clear the overlays... }
	for t := 0 to NumOverlayLayers do ClearOverlayLayer( T );

	{ Copy this map to the overlays... }
	for x := 1 to XMax do begin
		for y := 1 to YMax do begin
			GB^.Map[ X , Y ].Visible := True;
		end;
	end;
	NFDisplayMap( GB );


	OriginX := 80;		{ Set the origin to default value. }
	OriginY := -260;

	{ Next we're going to add some mecha sprites. }
	{ First, locate all the mecha sprite filenames... }
	Sprite_Names := Nil;
	for t := 1 to NumForm do begin
		ExpandFileList( Sprite_Names , Graphics_Directory + FormPat[ T ] );
	end;

	{ Add one sprite per 10x10 area of the map. }
	for t := 0 to 24 do begin
		name := SelectRandomSAtt( Sprite_Names )^.Info;
		SS := ConfirmSprite( name , RandomColorString(CS_PrimaryMecha)+' '+RandomColorString(CS_SecondaryMecha)+' '+RandomColorString(CS_Detailing) , 64 , 64 );
		if ( SS <> Nil ) and ( SS^.Img <> Nil ) then begin
			{ The first part of the name will tell us what }
			{ kind of a mecha we're dealing with. This is }
			{ important to know since we want flyers to fly }
			{ and other types to stay close to the ground. }
			name := copy( name , 1 , 3 );

			X := ( T mod 5 ) * 10 + Random( 10 ) + 1;
			Y := ( T div 5 ) * 10 + Random( 10 ) + 1;

			if (name='ger') or (name='aer') or (name='orn') or (name='hov') then begin
				AddInstantOverlay( X , Y , 5 , OVERLAY_Master , Random( 5 ) , SS );
				AddInstantOverlay( X , Y , TerrMan[ GB^.Map[ X , Y ].terr ].altitude , OVERLAY_Shadow , Default_Shadow , Items_Sprite );
			end else begin
				AddInstantOverlay( X , Y , TerrMan[ GB^.Map[ X , Y ].terr ].altitude , OVERLAY_Master , Random( 5 ) , SS );
				AddInstantOverlay( X , Y , TerrMan[ GB^.Map[ X , Y ].terr ].altitude , OVERLAY_Shadow , Default_Shadow , Items_Sprite );
			end;
		end;
	end;

	{ Finally, get rid of the random map. }
	{ This will also get rid of the attached scene. Bonus! }
	DisposeMap( GB );

	DisposeSAtt( Sprite_Names );

	Opening_Phase := 1;
	Opening_Count := 0;
	Opening_Last_Anim_Phase := Animation_Phase;
end;

Procedure RedrawOpening;
	{ Redraw the screen for the opening display. }
const
	NumLeg = 6;
	Leg_Points: Array [1..NumLeg,1..2] of Point = (
		((X:15;Y:15),(X:25;Y:15)),
		((X:25;Y:15),(X:25;Y:35)),
		((X:25;Y:35),(X:35;Y:35)),
		((X:35;Y:35),(X:35;Y:25)),
		((X:35;Y:25),(X:15;Y:25)),
		((X:15;Y:25),(X:15;Y:15))
	);
var
	X0,Y0,X1,Y1: Integer;
	P: Point;
	Normally_Use_Alpha: Boolean;
begin
	SetupCombatDisplay;

	if Opening_Last_Anim_Phase <> Animation_Phase then begin
		Opening_Last_Anim_Phase := Animation_Phase;
		Inc( Opening_Count );
		Inc( Opening_Count );

		X0 := ( ZONE_Map.w div 2 ) - RelativeX( Leg_Points[ Opening_Phase , 1 ].X , Leg_Points[ Opening_Phase , 1 ].Y );
		Y0 := ( ZONE_Map.h div 2 ) - RelativeY( Leg_Points[ Opening_Phase , 1 ].X , Leg_Points[ Opening_Phase , 1 ].Y );
		X1 := ( ZONE_Map.w div 2 ) - RelativeX( Leg_Points[ Opening_Phase , 2 ].X , Leg_Points[ Opening_Phase , 2 ].Y );
		Y1 := ( ZONE_Map.h div 2 ) - RelativeY( Leg_Points[ Opening_Phase , 2 ].X , Leg_Points[ Opening_Phase , 2 ].Y );

		P := SolveLine( X0 , Y0 , X1 , Y1 , Opening_Count );

		ORIGINX := P.X;
		ORIGINY := P.Y;

		if ( OriginX = X1 ) and ( OriginY = Y1 ) then begin
			Opening_Phase := Opening_Phase + 1;
			if Opening_Phase > NumLeg then Opening_Phase := 1;
			Opening_Count := 0;
		end;
	end;
	Normally_Use_Alpha := Use_Alpha_Blending;
	Use_Alpha_Blending := False;
	RenderMap;
	Use_Alpha_Blending := Normally_Use_Alpha;
end;

Function ScreenToMap( X,Y: Integer ): Point;
	{ X and Y are screen coordinates. Convert these to map coordinates. }
var
	AX,AY,DX,TX,TY: Integer;	{ Absolute X , Absolute Y }
	P: Point;
begin
	AX := X - ZONE_Map.X - OriginX;
	AY := Y - ZONE_Map.Y - OriginY;

	P.Y := AY div HalfTileHeight - 1;
	P.X := 1;
	AX := AX + ( P.Y - 1 ) * HalfTileWidth;
	DX := AX div ( HalfTileWidth * 2 );

	TX := AX mod ( HalfTileWidth * 2 );
	TY := AY mod HalfTileHeight;

	if ( TX < HalfTileWidth ) and ( TX < ( 31 - 2 * TY ) ) then Dec( P.X )
	else if ( TX > HalfTileWidth ) and ( ( TX - 31 ) > TY ) then Dec( P.Y );

	P.Y := P.Y - DX;
	P.X := P.X + DX;

	ScreenToMap := P;
end;

Function MouseMapPos: Point;
	{ Return the map position of the mouse. }
begin
	MouseMapPos := ScreenToMap( Mouse_X , Mouse_Y );
end;

Procedure BeginTurn( GB: GameBoardPtr; M: GearPtr );
	{ Time to start the turn. }
var
	A: Char;
begin
	SetupMemoDisplay;
	CMessage( 'Begin ' + PilotName( M ) + ' turn' , ZONE_MemoText , InfoHilight );
	GHFlip;
	EndOfGameMoreKey;
end;

initialization
	Terrain_Sprite := ConfirmSprite( Terrain_Sprite_Name , '' , 64 , 96 );
	Meta_Terrain_Sprite := ConfirmSprite( Meta_Terrain_Sprite_Name , '' , 64 , 96 );
	Terrain_Toupee_Sprite := ConfirmSprite( Terrain_Toupee_Sprite_Name , '' , 64 , 64 );
	Targeting_Srpite := ConfirmSprite( Targeting_Srpite_Name , '' , 64 , 64 );
	Items_Sprite := ConfirmSprite( Items_Sprite_Name , '' , 64 , 64 );
	Strong_Hit_Sprite := ConfirmSprite( Strong_Hit_Sprite_Name , '' , 64 , 64 );
	Weak_Hit_Sprite := ConfirmSprite( Weak_Hit_Sprite_Name , '' , 64 , 64 );
	Parry_Sprite := ConfirmSprite( Parry_Sprite_Name , '' , 64 , 64 );
	Miss_Sprite := ConfirmSprite( Miss_Sprite_Name , '' , 64 , 64 );

	Thin_Wall_Sprites[ ThinWall_Earth ] := ConfirmSprite( 'wall_earth.png' , '' , 64 , 96 );
	Thin_Wall_Sprites[ ThinWall_RustySteel ] := ConfirmSprite( 'wall_rustysteel.png' , '' , 64 , 96 );
	Thin_Wall_Sprites[ ThinWall_Stone ] := ConfirmSprite( 'wall_stone.png' , '' , 64 , 96 );
	Thin_Wall_Sprites[ ThinWall_Industrial ] := ConfirmSprite( 'wall_industrial.png' , '' , 64 , 96 );
	Thin_Wall_Sprites[ ThinWall_Residential ] := ConfirmSprite( 'wall_extra_b.png' , '' , 64 , 96 );
{	Thin_Wall_Sprites[ ThinWall_Default ] := ConfirmSprite( 'wall_extra_a.png' , '' , 64 , 96 );}

	Thin_wall_Cap := ConfirmSprite( 'wall_cap.png' , '' , 64 , 96 );
	Hill_1 := ConfirmSprite( 'hill_1.png' , '' , 64 , 96 );
	Hill_2 := ConfirmSprite( 'hill_2.png' , '' , 64 , 96 );
	Hill_3 := ConfirmSprite( 'hill_3.png' , '' , 64 , 96 );
	Off_Map_Model_Sprite := ConfirmSprite( 'off_map.png' , '' , 16 , 16 );

    Door_Sprite := ConfirmSprite( 'terrain_door.png', '', 64, 64 );

	Mini_Map_Sprite := ConfirmSprite( 'minimap.png' , '' , 3 , 3 );
	if Use_Alpha_Blending then SDL_SetAlpha( Mini_Map_Sprite^.Img , SDL_SRCAlpha , Alpha_Level );

end.
