unit sdlinfo;
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

uses sdl,sdl_ttf,sdlgfx,gears,gearutil,damage,movement,texutil,ability,locale,sdlmap,interact,effects;

var
	CHAT_Message: String;
	CHAT_React,CHAT_Endurance: Integer;

Function JobAgeGenderDesc( NPC: GearPtr ): String;

Procedure LocationInfo( Part: GearPtr; gb: GameBoardPtr );
Procedure DisplayGearInfo( Part: GearPtr );
Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr );
Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr; Z: TSDL_Rect );

Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
Procedure QuickWeaponInfo( Part: GearPtr );
Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
Procedure InjuryViewer( PC: GearPtr );

Procedure MapEditInfo( Pen,Palette,X,Y: Integer );


implementation

uses ghmodule,ghweapon,ghmecha,ghchars,ghsupport;

const
	StatusPerfect:TSDL_Color =	( r:  0; g:255; b: 65 );
	StatusOK:TSDL_Color =		( r: 30; g:190; b: 10 );
	StatusFair:TSDL_Color =		( r:220; g:190; b:  0 );
	StatusBad:TSDL_Color =		( r:220; g: 50; b:  0 );
	StatusCritical:TSDL_Color =	( r:150; g:  0; b:  0 );
	StatusKO:TSDL_Color =		( r: 75; g: 75; b: 75 );

	Interact_Sprite_Name = 'interact.png';
	Module_Sprite_Name = 'modules.png';
	Backdrop_Sprite_Name = 'backdrops.png';

	Altimeter_Sprite_Name = 'altimeter.png';
	Speedometer_Sprite_Name = 'speedometer.png';
	StatusFX_Sprite_Name = 'statusfx.png';
	OtherFX_Sprite_Name = 'otherfx.png';

var
	CZone,CDest: TSDL_Rect;		{ Current Zone, Current Destination }
	Interact_Sprite,Module_Sprite,Backdrop_Sprite: SensibleSpritePtr;
	Altimeter_Sprite,Speedometer_Sprite: SensibleSpritePtr;
	StatusFX_Sprite,OtherFX_Sprite: SensibleSpritePtr;
    Master_Portrait_List: SAttPtr;

Function JobAgeGenderDesc( NPC: GearPtr ): String;
	{ Return the Job, Age, and Gender of the provided character in }
	{ a nicely formatted string. }
var
	msg,job: String;
begin
	msg := BStr( NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) + 20 );
	msg := msg + ' year old ' + LowerCase( GenderName[ NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) ] );
	job := SAttValue( NPC^.SA , 'JOB' );
	if job <> '' then msg := msg + ' ' + LowerCase( job );
	msg := msg + '.';
	JobAgeGenderDesc := msg;
end;

Function MaxTArmor( Part: GearPtr ): LongInt;
	{ Find the max amount of armor on this gear, counting external armor. }
var
	it: LongInt;
	S: GearPtr;
begin
	it := GearMaxArmor( Part );
	S := Part^.InvCom;
	while S <> Nil do begin
		if S^.G = GG_ExArmor then it := it + GearMaxArmor( S );
		S := S^.Next;
	end;
	MaxTArmor := it;
end;

Function CurrentTArmor( Part: GearPtr ): LongInt;
	{ Find the current amount of armor on this gear, counting external armor. }
var
	it: LongInt;
	S: GearPtr;
begin
	it := GearCurrentArmor( Part );
	S := Part^.InvCom;
	while S <> Nil do begin
		if S^.G = GG_ExArmor then it := it + GearCurrentArmor( S );
		S := S^.Next;
	end;
	CurrentTArmor := it;
end;


Procedure AI_NextLine;
	{ Move the cursor to the next line. }
begin
	CDest.Y := CDest.Y + TTF_FontLineSkip( Info_Font );
end;

Procedure AI_Title( msg: String; C: TSDL_Color );
	{ Draw a centered message on the current line. }
var
	MyImage: PSDL_Surface;
	PLine: PChar;
begin
	pline := QuickPCopy( msg );
	MyImage := TTF_RenderText_Solid( Game_Font , pline , C );
	Dispose( pline );

	if MyImage <> Nil then CDest.X := CZone.X + ( ( CZone.W - MyImage^.W ) div 2 );

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );

	CDest.Y := CDest.Y + TTF_FontLineSkip( Game_Font );
end;

Procedure AI_SmallTitle( msg: String; C: TSDL_Color );
	{ Draw a centered message on the current line. }
var
	MyImage: PSDL_Surface;
	PLine: PChar;
begin
	pline := QuickPCopy( msg );
	MyImage := TTF_RenderText_Solid( Info_Font , pline , C );
	Dispose( pline );

	CDest.X := CZone.X + ( ( CZone.W - MyImage^.W ) div 2 );

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );

	CDest.Y := CDest.Y + TTF_FontLineSkip( Info_Font );
end;


Procedure AI_Line( msg: String; C: TSDL_Color );
	{ Draw a left justified message on the current line. }
var
	MyImage: PSDL_Surface;
	PLine: PChar;
begin
	pline := QuickPCopy( msg );
	MyImage := TTF_RenderText_Solid( Info_Font , pline , C );
	Dispose( pline );

	CDest.X := CZone.X;

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );

	AI_NextLine;
end;

Procedure AI_PrintFromRight( msg: String; Tab: Integer; C: TSDL_Color );
	{ Draw a left justified message on the current line. }
var
	MyImage: PSDL_Surface;
	PLine: PChar;
begin
	pline := QuickPCopy( msg );
	MyImage := TTF_RenderText_Solid( Info_Font , pline , C );
	Dispose( pline );

	CDest.X := CZone.X + Tab;

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );
end;

Procedure AI_PrintFromLeft( msg: String; Tab: Integer; C: TSDL_Color );
	{ Draw a left justified message on the current line. }
var
	MyImage: PSDL_Surface;
	PLine: PChar;
begin
	pline := QuickPCopy( msg );
	MyImage := TTF_RenderText_Solid( Info_Font , pline , C );
	Dispose( pline );

	CDest.X := CZone.X + Tab - MyImage^.W;

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );
end;

Function StatusColor( Full , Current: LongInt ): TSDL_Color;
	{ Given a part's Full and Current hit ratings, decide on a good status color. }
begin
	if Full = Current then StatusColor := StatusPerfect
	else if Current > ( Full div 2 ) then StatusColor := StatusOK
	else if Current > ( Full div 4 ) then StatusColor := StatusFair
	else if Current > ( Full div 8 ) then StatusColor := StatusBad
	else if Current > 0 then StatusColor := StatusCritical
	else StatusColor := StatusKO;
end;

Function EnduranceColor( Full , Current: LongInt ): TSDL_Color;
	{ Choose color to show remaining endurance (stamina or mental points)}
begin
	if Full = Current then EnduranceColor := StatusPerfect
	else if Current > 5 then EnduranceColor := StatusOK
	else if Current > 0 then EnduranceColor := StatusFair
	else EnduranceColor := StatusBad;
end;

Function HitsColor( Part: GearPtr ): TSDL_Color;
	{ Decide upon a nice color to represent the hits of this part. }
begin
	if PartActive( Part ) then
		HitsColor := StatusColor( GearMaxDamage( Part ) , GearCurrentDamage( Part ) )
	else
		HitsColor := StatusColor( 100 , 0 );
end;

Function ArmorColor( Part: GearPtr ): TSDL_Color;
	{ Decide upon a nice color to represent the armor of this part. }
begin
	ArmorColor := StatusColor( MaxTArmor( Part ) , CurrentTArmor( Part ) );
end;

Function ArmorDamageColor( Part: GearPtr ): TSDL_Color;
	{ Decide upon a nice color to represent the armor of this part. }
var
	MA,CA: LongInt;	{ Max Armor, Current Armor }
begin
	MA := MaxTArmor( Part );
	CA := CurrentTArmor( Part );

	if ( CA >= ( MA * 3 div 4 ) ) then begin
		ArmorDamageColor := StatusPerfect;
	end else if ( CA > MA div 4 ) then begin
		ArmorDamageColor := StatusFair;
	end else begin
		ArmorDamageColor := StatusCritical;
	end;
end;

Procedure DisplayModules( Mek: GearPtr );
	{ Draw a lovely little diagram detailing this mek's modules. }
var
	X0: LongInt;	{ Midpoint of the info display. }
	N: Integer;	{ Module number on the current line. }
	MyDest: TSDL_Rect;
	MM,A,B: Integer;
	MD: GearPtr;

	Function PartStructImage( GS, CuD, MxD: Integer ): Integer;
		{ Given module type GS, with current damage score CuD and maximum damage }
		{ score MxD, return the correct image to use for it in the diagram. }
	begin
		if ( MxD > 0 ) and ( CuD < 1 ) then begin
			PartStructImage := ( MD^.S * 9 ) - 1;
		end else begin
			PartStructImage := ( MD^.S * 9 ) - 1 - ( CuD * 8 div MxD );
		end;
	end;

	Function PartArmorImage( GS, CuD, MxD: Integer ): Integer;
		{ Given module type GS, with current armor score CuD and maximum armor }
		{ score MxD, return the correct image to use for it in the diagram. }
	begin
		if CuD < 1 then begin
			PartArmorImage := ( MD^.S * 9 ) + 71;
		end else begin
			PartArmorImage := ( MD^.S * 9 ) + 71 - ( CuD * 8 div MxD );
		end;
	end;

	Procedure AddPartsToDiagram( GS: Integer );
		{ Add parts to the status diagram whose gear S value }
		{ is equal to the provided number. }
	var
		CuD,MxD,Armor,Structure: Integer;	{ Armor & Structural damage values. }
	begin
		MD := Mek^.SubCom;
		while ( MD <> Nil ) do begin
			if ( MD^.G = GG_Module ) and ( MD^.S = GS ) then begin
				{ First, determine the spot at which to display the image. }
				if Odd( N ) then MyDest.X := X0 - ( N div 2 ) * 12 - 12
				else MyDest.X := X0 + ( N div 2 ) * 12;
				Inc( N );

				{ Display the structure. }
				MxD := GearMaxDamage( MD );
				CuD := GearCurrentDamage( MD );
				DrawSprite( Module_Sprite , MyDest , PartStructImage( MD^.S , CuD , MxD ) );

				{ Display the armor. }
				MxD := MaxTArmor( MD );
				CuD := CurrentTArmor( MD );
				if MxD <> 0 then begin
					DrawSprite( Module_Sprite , MyDest , PartArmorImage( MD^.S , CuD , MxD ) );

				end;
			end;
			MD := MD^.Next;
		end;
	end;
begin
	{ Draw the status diagram for this mek. }
	{ Line One - Heads, Turrets, Storage }
	MyDest.Y := CDest.Y + 12;
	X0 := CZone.X + ( CZone.W div 2 ) - 7;

	N := 0;
	AddPartsToDiagram( GS_Head );
	AddPartsToDiagram( GS_Turret );
	if N < 1 then N := 1;	{ Want pods to either side of body; head and/or turret in middle. }
	AddPartsToDiagram( GS_Storage );

	{ Line Two - Torso, Arms, Wings }
	N := 0;
	MyDest.Y := MyDest.Y + 17;
	AddPartsToDiagram( GS_Body );
	AddPartsToDiagram( GS_Arm );
	AddPartsToDiagram( GS_Wing );

	{ Line Three - Tail, Legs }
	N := 0;
	MyDest.Y := MyDest.Y + 17;
	AddPartsToDiagram( GS_Tail );
	if N < 1 then N := 1;	{ Want legs to either side of body; tail in middle. }
	AddPartsToDiagram( GS_Leg );
	AI_NextLine;
end;

Procedure DisplayStatusFX( Part: GearPtr );
	{ Show status effects and other things this part might be suffering from. }
var
	MyDest: TSDL_Rect;
	T: Integer;
begin
	MyDest.X := CZone.X + 8;
	MyDest.Y := CZone.Y + CZone.H - 20;

	if Part^.G = GG_Character then begin
		T := NAttValue( Part^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
		if T > ( NumGearStats * 3 ) then begin
			DrawSprite( OtherFX_Sprite , MyDest , 4 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > ( NumGearStats * 2 ) then begin
			DrawSprite( OtherFX_Sprite , MyDest , 2 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > 0 then begin
			DrawSprite( OtherFX_Sprite , MyDest , ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end;

		T := NAttValue( Part^.NA , NAG_Condition , NAS_MoraleDamage );
		if T < -20 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 12 );
			MyDest.X := MyDest.X + 10;
		end else if T > 20 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 13 );
			MyDest.X := MyDest.X + 10;
		end;

	end else if Part^.G = GG_Mecha then begin
		T := NAttValue( Part^.NA , NAG_Condition , NAS_Overload ) - OverloadCapacity( Part );
		if T > 25 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 10 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > 10 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 8 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > 0 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 6 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end;

	end;

	for t := 1 to Num_Status_FX do begin
		if NAttValue( Part^.NA , NAG_StatusEffect , T ) <> 0 then begin
			DrawSprite( STatusFX_Sprite , MyDest , (( T - 1 ) * 2 ) + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end;
	end;

end;

Procedure LocationInfo( Part: GearPtr; gb: GameBoardPtr );
	{ Display location info for this part, if it is on the map. }
	{ This procedure is meant to be called after a GearInfo call, }
	{ since it assumes that ZX1,ZY1...etc will have been set up }
	{ properly beforehand. }
var
	MyDest: TSDL_Rect;
	n: Integer;
begin
	if ( GB <> Nil ) and OnTheMap( Part ) and IsMasterGear( Part ) and ( Part^.G <> GG_Prop ) then begin
		{ Props are master gears, but they don't get location info. }
		MyDest.Y := CDest.Y + 12;
		MyDest.X := CZone.X + ( CZone.W div 8 );
		DrawSprite( Module_Sprite , MyDest , 144 + ( NAttValue( Part^.NA , NAG_Location , NAS_D ) + 1 ) mod 8 );

		n := mekAltitude( GB , Part ) + 3;
		if N < 0 then n := 0
		else if N > 8 then n := 8;
		MyDest.Y := CDest.Y - 8;
		MyDest.X := CZone.X + ( CZone.W div 8 ) + 15;
		DrawSprite( Altimeter_Sprite , MyDest , N );

		N := NAttValue( Part^.Na , NAG_Action , NAS_MoveAction );
		if N = NAV_FullSpeed then begin
			N := ( Animation_Phase div 2 ) mod 4 + 6;
		end else if ( N <> NAV_Stop ) and ( N <> NAV_Hover ) then begin
			N := ( Animation_Phase div 3 ) mod 4 + 2;
		end else if BaseMoveRate( Part ) > 0 then begin
			N := 1;
		end else begin
			N := 0;
		end;
		MyDest.Y := CDest.Y - 8;
		MyDest.X := CZone.X + ( CZone.W div 8 ) - 24;
		DrawSprite( Speedometer_Sprite , MyDest , N );

	end else if SAttValue( Part^.SA , 'SDL_SPRITE' ) <> '' then begin
		MyDest.Y := CDest.Y - 12;
		MyDest.X := CZone.X + ( CZone.W div 8 ) - 8;
		DrawSprite( ConfirmSprite( SAttValue( Part^.SA , 'SDL_SPRITE' ) , SAttValue( Part^.SA , 'SDL_COLORS' ) , 64 , 64 ) , MyDest , ( Animation_Phase div 10 ) mod 8 );
	end;
end;

Procedure MekStatDisplay( Mek: GearPtr; GB: GameBoardPtr );
	{ Display the stats for MEK. }
	{ MEK absolutely must be a valid mecha; otherwise }
	{ there's gonna be a strange display. }
var
	msg: String;
	MM,A,B,CurM,MaxM: Integer;
	MD: GearPtr;
	C: TSDL_Color;
begin
	{ General mecha information - Name, mass, maneuver }
	AI_Title( GearName(Mek) , NeutralGrey );

	{ Draw the status diagram for this mek. }
	DisplayModules( Mek );
	LocationInfo( Mek , GB );

	{ Print MV, TR, and SN. }
	AI_PrintFromRight( 'MV:' + SgnStr(MechaManeuver(Mek)) , ( CZone.W * 3 ) div 4 , NeutralGrey );
	AI_NextLine;
	AI_PrintFromRight( 'TR:' + SgnStr(MechaTargeting(Mek)) , ( CZone.W * 3 ) div 4 , NeutralGrey );
	AI_NextLine;
	AI_PrintFromRight( 'SE:' + SgnStr(MechaSensorRating(Mek)) , ( CZone.W * 3 ) div 4 , NeutralGrey );
	AI_NextLine;
	AI_NextLine;

	{ Pilot Information - Name, health, rank }
	MD := LocatePilot( Mek );
	if MD <> Nil then begin
		{ Pilot's name - Left Justified. }
		msg := GearName( MD );

		{ Color determined by exhaustion. }
		A := CharCurrentMental( MD );
		B := CharCurrentStamina( MD );
		if ( A=0 ) and ( B=0 ) then begin
			C := StatusBad;
		end else if ( A=0 ) or ( B=0 ) then begin
			C := StatusFair;
		end else begin
			C := NeutralGrey;
		end;

		AI_PrintFromRight( msg , 2 , C );

		AI_PrintFromLeft( BStr( GearCurrentDamage( MD ) ) + 'HP' , ( CZone.W * 3 ) div 4 , HitsColor( MD ) );
		AI_NextLine;
	end;

	AI_SmallTitle( MassString( Mek ) + ' ' + FormName[Mek^.S] + '  PV:' + BStr( GearValue( Mek ) ) , NeutralGrey );

	{ Movement information. }
	MM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	if MM > 0 then begin
		msg := MoveModeName[ MM ];
		msg := msg + ' (' + BStr( Speedometer( Mek ) ) + 'dpr)';
	end else msg := 'Immobile';
	AI_SmallTitle( msg , NeutralGrey );

	{ Encumbrance information. }

	{ Get the current mass of carried equipment. }
	CurM := EquipmentMass( Mek );

	{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
	MaxM := ( GearEncumberance( Mek ) * 2 ) - 1;

	AI_PrintFromRight( 'Enc:' , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , 'Enc:' + BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' ) - 24 , NeutralGrey );
	AI_PrintFromRight( BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' ) - 24 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );

	DisplayStatusFX( Mek );
end;

Procedure CharacterInfo( Part: GearPtr; GB: GameBoardPtr );
	{ This gear is a character. Print a list of stats and skills. }
var
	T,TT,Width,S,CurM,MaxM: Integer;
	C: TSDL_Color;
	
begin
	{ Show the character's name and health status. }
	AI_Title( GearName(Part) , NeutralGrey );

	DisplayModules( Part );
	LocationInfo( Part , GB );

	{ Print HP, ME, and SP. }
	AI_PrintFromRight( 'HP:' , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , 'HP:' ) - 2 , NeutralGrey );
	AI_PrintFromRight( BStr( GearCurrentDamage(Part)) + '/' + BStr( GearMaxDamage(Part)) , ( CZone.W * 13 ) div 16 , HitsColor( Part ) );
	AI_NextLine;
	AI_PrintFromRight( 'St:' , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , 'St:' ) - 2 , NeutralGrey );
	AI_PrintFromRight( BStr( CharCurrentStamina(Part)) + '/' + BStr( CharStamina(Part)) , ( CZone.W * 13 ) div 16 , EnduranceColor( CharStamina(Part) , CharCurrentStamina(Part) ) );
	AI_NextLine;
	AI_PrintFromRight( 'Me:' , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , 'Me:' ) - 2 , NeutralGrey );
	AI_PrintFromRight( BStr( CharCurrentMental(Part)) + '/' + BStr( CharMental(Part)) , ( CZone.W * 13 ) div 16 , EnduranceColor( CharMental(Part) , CharCurrentMental(Part) ) );
	AI_NextLine;
	AI_NextLine;


	{ Determine the spacing for the character's stats. }
	Width := CZone.W div 4;

	{ Show the character's stats. }
	for t := 1 to ( NumGearStats div 4 ) do begin
		for tt := 1 to 4 do begin
			AI_PrintFromRight( StatName[ T * 4 + TT - 4 ][1] + StatName[ T * 4 + TT - 4 ][2] + ':' , ( TT-1 ) * Width + 1 , NeutralGrey );

			{ Determine the stat value. This may be higher or lower than natural... }
			S := CStat( Part , T * 4 + TT - 4 );
			if S > Part^.Stat[ T * 4 + TT - 4 ] then C := StatusPerfect
			else if S < Part^.Stat[ T * 4 + TT - 4 ] then C := StatusBad
			else C := StatusOK;
			AI_PrintFromLeft( BStr( S ) , TT * Width -5 , C );
		end;
		AI_NextLine;
	end;

	{ Encumbrance information. }

	{ Get the current mass of carried equipment. }
	CurM := EquipmentMass( Part );

	{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
	MaxM := ( GearEncumberance( Part ) * 2 ) - 1;

	AI_PrintFromRight( 'Enc:' , 1 , NeutralGrey );
	AI_PrintFromRight( BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 'kg' , 36 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );

	DisplayStatusFX( Part );
end;

Procedure MiscInfo( Part: GearPtr );
	{ Display info for any gear that doesn't have its own info }
	{ procedure. }
var
	N: LongInt;
	msg: String;
	AI_Dest: TSDL_Rect;
begin
	{ Show the part's name. }
	AI_Title( GearName(Part) , NeutralGrey );

	{ Display the part's armor rating. }
	N := GearCurrentArmor( Part );
	if N > 0 then msg := '[' + BStr( N )
	else msg := '[-';
	msg := msg + '] ';
	AI_PrintFromRight( msg , 1 , ArmorColor( Part ) );

	{ Display the part's damage rating. }
	N := GearCurrentDamage( Part );
	if N > 0 then msg := BStr( N )
	else msg := '-';
	AI_PrintFromRight( msg + ' DP' , CZone.W div 2 , HitsColor( Part ) );

	N := ( GearMass( Part ) + 1 ) div 2;
	if N > 0 then AI_PrintFromLeft( MassString( Part ) , CZone.W - 1 , NeutralGrey );

	if Part^.G < 0 then begin
		AI_NextLine;
		AI_PrintFromRight( Bstr( Part^.G ) + ',' + BStr( Part^.S ) + ',' + BStr( Part^.V ) , CZone.W div 2 , StdWhite );
	end;

	AI_Dest := CZone;
	AI_Dest.X := AI_Dest.X + 10;
	AI_Dest.Y := CDest.Y + TTF_FontLineSkip( Info_Font ) + 10;
	AI_Dest.W := AI_Dest.W - 20;
	AI_Dest.H := AI_Dest.H - ( CDest.Y - CZone.Y ) - 20 - TTF_FontLineSkip( Info_Font );
	NFGameMsg( ExtendedDescription( Part ) , AI_Dest , NeutralGrey );
end;

Procedure SetInfoZone( var Z: TSDL_Rect; var BorColor: TSDL_Color );
	{ Copy the provided coordinates into this unit's global }
	{ variables, then draw a nice little border and clear the }
	{ selected area. }
begin
	{ Copy the dimensions provided into this unit's global variables. }
	CZone := Z;
	CDest := Z;
	ClrZone( Z );
end;

Procedure RepairFuelInfo( Part: GearPtr );
	{ Display info for any gear that doesn't have its own info }
	{ procedure. }
var
	N: Integer;
begin
	{ Show the part's name. }
	AI_Title( GearName(Part) , NeutralGrey );

	N := GearMass( Part );
	if N > 0 then AI_PrintFromLeft( MassString( Part ) , CZone.W - 1 , NeutralGrey );

	AI_NextLine;
	AI_SmallTitle( SkillMan[ Part^.S ].Name , BrightYellow );
	AI_SmallTitle( BStr( Part^.V ) + ' DP' , InfoGreen );
end;


Procedure GearInfo( Part: GearPtr; var Z: TSDL_Rect; BorColor: TSDL_Color; GB: GameBoardPtr );
	{ Display some information for this gear inside the screen area }
	{ X1,Y1,X2,Y2. }
begin
	SetInfoZone( Z,BorColor );

	{ Error check }
	{ Note that we want the area cleared, even in case of an error. }
	if Part = Nil then exit;

	{ Depending upon PART's type, branch to an appropriate procedure. }
	case Part^.G of
		GG_Mecha:	MekStatDisplay( Part , GB );
		GG_Character:	CharacterInfo( Part , GB );
		GG_RepairFuel:	RepairFuelInfo( Part );
	else MiscInfo( Part );
	end;
end;


Procedure DisplayGearInfo( Part: GearPtr );
	{ Show some stats for whatever sort of thing PART is. }
begin
	{ All this procedure does is call the ArenaInfo unit procedure }
	{ with the dimensions of the Info Zone. }
	GearInfo( Part, ZONE_Info, NeutralGrey , Nil );
end;

Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr; Z: TSDL_Rect );
	{ Show some stats for whatever sort of thing PART is. }
begin
	{ All this procedure does is call the ArenaInfo unit procedure }
	{ with the dimensions of the provided Zone. }
	GearInfo( Part , Z , TeamColor( GB , Part ) , GB );
end;

Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr );
	{ Show some stats for whatever sort of thing PART is. }
begin
	DisplayGearInfo( Part , GB , ZONE_Info );
end;

Function PortraitName( NPC: GearPtr ): String;
	{ Return a name for this NPC's protrait. }
var
	it,Criteria: String;
	PList,P,P2: SAttPtr;	{ Portrait List. }
	IsOld: Integer;	{ -1 for young, 0 for medium, 1 for old }
	IsCharming: Integer;	{ -1 for low Charm, 0 for medium, 1 for high charm }
	HasMecha: Boolean;	{ TRUE if NPC has a mecha, FALSE otherwise. }
		{ Y Must have positive value }
		{ N Must have negative valie }
		{ - May have either value }
	PisOK: Boolean;
begin
	{ Error check - better safe than sorry, unless in an A-ha song. }
	if NPC = Nil then Exit( '' );

	{ Check the standard place first. If no portrait is defined, }
	{ grab one from the IMAGE/ directory. }
	it := SAttValue( NPC^.SA , 'SDL_PORTRAIT' );
	if (it = '') or not StringInList( it, Master_Portrait_List ) then begin
		{ Create a portrait list based upon the character's gender. }
		if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
			PList := CreateFileList( Graphics_Directory + 'por_m_*.*' );
		end else begin
			PList := CreateFileList( Graphics_Directory + 'por_f_*.*' );
		end;

		{ Filter the portrait list based on the NPC's traits. }
		if NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) < 6 then begin
			IsOld := -1;
		end else if NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) > 15 then begin
			IsOld :=  1;
		end else IsOld := 0;
		if NPC^.Stat[ STAT_Charm ] < 10 then begin
			IsCharming := -1;
		end else if NPC^.Stat[ STAT_Charm ] >= 15 then begin
			IsCharming :=  1;
		end else IsCharming := 0;
		HasMecha := SAttValue( NPC^.SA, 'MECHA' ) <> '';
		P := PList;
		while P <> Nil do begin
			P2 := P^.Next;
			Criteria := RetrieveBracketString( P^.Info );
			PisOK := True;
			if Length( Criteria ) >= 3 then begin
				{ Check youth. }
				Case Criteria[1] of
					'O':	PisOK := IsOld > 0;
					'Y':	PisOK := IsOld < 0;
					'A':	PisOK := IsOld > -1;
					'J':	PisOK := IsOld < 1;
				end;

				{ Check charm. }
				if PisOK then Case Criteria[2] of
					'C':	PisOK := IsCharming > 0;
					'U':	PisOK := IsCharming < 0;
					'P':	PisOK := IsCharming < 1;
					'A':	PisOK := IsCharming > -1;
				end;

				{ Check mecha. }
				if PisOK then Case Criteria[3] of
					'Y':	PisOK := HasMecha;
					'N':	PisOK := not HasMecha;
				end;
			end;
			if not PisOK then RemoveSAtt( PList , P );
			P := P2;
		end;

		{ As long as we found some appropriate files, select one of them }
		{ randomly and save it for future reference. }
		if PList <> Nil then begin
			it := SelectRandomSAtt( PList )^.Info;
			DisposeSAtt( PList );
			SetSAtt( NPC^.SA , 'SDL_PORTRAIT <' + it + '>' );
		end;
	end;

	PortraitName := it;
end;


Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
	{ Show the needed information regarding this conversation. }
var
	msg,job: String;
	MyDest: TSDL_Rect;
	T,RStep: Integer;
	SS: SensibleSpritePtr;
begin
	SetInfoZone( ZONE_InteractStatus , NeutralBrown );

	CHAT_React := React;
	CHAT_Endurance := Endurance;

	{ First the name, then the description. }
	AI_Title( GearName( NPC ) , InfoHiLight );
	AI_Title( JobAgeGenderDesc( NPC ) , InfoGreen );

	{ Prepare to draw the reaction indicators. }
	ClrZone( ZONE_InteractInfo );
	MyDest := ZONE_InteractInfo;
	MyDest.Y := MyDest.Y + ( MyDest.H - 32 ) div 4;
	MyDest.X := MyDest.X + ( MyDest.H - 32 ) div 4;
	for t := 0 to 3 do begin
		DrawSprite( INTERACT_SPRITE , MyDest , t );
		MyDest.X := MyDest.X + 4;
	end;

	{ Calculate how many 4-pixel-wide measures we can show in the zone, }
	{ to indicate a Reaction of 100. }
	RStep := 400 div ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 );
	if RStep < 1 then RStep := 1;

	{ Draw the reaction indicators. }
	if React > 0 then begin
		for t := 0 to ( React * ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 ) div 400 ) do begin
			DrawSprite( INTERACT_SPRITE , MyDest , 8 );
			MyDest.X := MyDest.X + 4;
		end;
	end else if React < 0 then begin
		for t := 0 to ( Abs( React ) * ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 ) div 400 ) do begin
			DrawSprite( INTERACT_SPRITE , MyDest , 9 );
			MyDest.X := MyDest.X + 4;
		end;
	end else begin
		DrawSprite( INTERACT_SPRITE , MyDest , 10 );
	end;

	MyDest := ZONE_InteractInfo;
	MyDest.Y := MyDest.Y + MyDest.H div 2 + ( MyDest.H - 32 ) div 4;
	MyDest.X := MyDest.X + ( MyDest.H - 32 ) div 4;
	for t := 4 to 7 do begin
		DrawSprite( INTERACT_SPRITE , MyDest , t );
		MyDest.X := MyDest.X + 4;
	end;
	if Endurance > 5 then begin
		RStep := 11;
	end else if Endurance > 2 then begin
		RStep := 12;
	end else begin
		RStep := 13;
	end;
	for t := 1 to ( Endurance * ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 ) div 40 ) do begin
		DrawSprite( INTERACT_SPRITE , MyDest , RStep );
		MyDest.X := MyDest.X + 4;
	end;

	{ Draw the portrait. }
	DrawSprite( Backdrop_Sprite , ZONE_InteractPhoto , 0 );
	SS := ConfirmSprite( PortraitName( NPC ) , TeamColorString( GB , NPC ) , 100 , 150 );
	DrawSprite( SS , ZONE_InteractPhoto , 0 );
end;

Procedure QuickWeaponInfo( Part: GearPtr );
	{ Provide quick info for this weapon in the MENU2 zone. }
begin
	if Part = Nil then exit;

	{ Display the weapon description. }
	NFCMessage( GearName( Part ) + ' ' + WeaponDescription( Part ) , ZONE_Menu1 , InfoGreen );
end;

Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
	{ Display the important stats for this PC in the map zone. }
var
	msg,job: String;
	T,R,FID: Integer;
	S: LongInt;
	C: TSDL_Color;
	X0,X1,Y0: Integer;
	Mek: GearPtr;
	MyDest: TSDL_Rect;
	SS: SensibleSpritePtr;
begin
	{ Begin with one massive error check... }
	if PC = Nil then Exit;
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

	SetInfoZone( ZONE_Map , PlayerBlue );

	AI_Title( GearName( PC ) , NeutralGrey );
	AI_Title( JobAgeGenderDesc( PC ) , InfoGreen );
	AI_NextLine;

	{ Record the current Y position- we'll be coming back here later. }
	Y0 := CDest.Y;

	MyDest.Y := CDest.Y;
	X0 := ZONE_Map.X + ( ZONE_Map.W div 3 );

	for t := 1 to NumGearStats do begin
		{ Find the adjusted stat value for this stat. }
		S := CStat( PC , T );
		R := ( S + 2 ) div 3;
		if R > 7 then R := 7;

		{ Determine an appropriate color for the stat, depending }
		{ on whether its adjusted value is higher or lower than }
		{ the basic value. }
		if S > PC^.Stat[ T ] then C := InfoHilight
		else if S < PC^.Stat[ T ] then C := StatusBad
		else C := InfoGreen;

		{ Do the output. }
		MyDest.X := ZONE_Map.X + 10;
		QuickText( StatName[ T ] , MyDest , NeutralGrey );
		msg := BStr( S );
		MyDest.X := X0 - 30 - TextLength( Game_Font , msg );
		QuickText( msg , MyDest , C );

		MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
	end;

	{ Set column measurements for the next column. }
	MyDest.Y := Y0;
	X0 := ZONE_Map.X + ( ZONE_Map.W div 3 );
	X1 := ZONE_Map.X + ( ZONE_Map.W * 2 div 3 ) - 10;

	MyDest.X := X0;
	QuickText( MsgString( 'INFO_XP' ) , MyDest , NeutralGrey );
	msg := BStr( NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP ) );
	MyDest.X := X1 - TextLength( Game_Font , msg );
	QuickText( msg , MyDest , InfoGreen );
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

	MyDest.X := X0;
	QuickText( MsgString( 'INFO_XPLeft' ) , MyDest , NeutralGrey );
	msg := BStr( NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttVAlue( PC^.NA , NAG_Experience , NAS_SpentXP ) );
	MyDest.X := X1 - TextLength( Game_Font , msg );
	QuickText( msg , MyDest , InfoGreen );
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

	MyDest.X := X0;
	QuickText( MsgString( 'INFO_Credits' ) , MyDest , NeutralGrey );
	msg := '$' + BStr( NAttVAlue( PC^.NA , NAG_Experience , NAS_Credits ) );
	MyDest.X := X1 - TextLength( Game_Font , msg );
	QuickText( msg , MyDest , InfoGreen );
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

	if ( GB <> Nil ) then begin
		{ Print the name of the PC's mecha. }
		Mek := FindPilotsMecha( GB^.Meks , PC );
		if Mek <> Nil then begin
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
			MyDest.X := X0;
			QuickText( MsgString( 'INFO_MekSelect' ) , MyDest , NeutralGrey );
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

			msg := FullGearName( Mek );
			MyDest.X := X1 - TextLength( Game_Font , msg );
			QuickText( msg , MyDest , InfoGreen );
		end;

		{ And also of the PC's faction. }
		FID := NAttValue( PC^.NA , NAG_Personal , NAS_FactionID );
		if ( FID <> 0 ) and ( GB^.Scene <> Nil ) then begin
			Mek := SeekFaction( GB^.Scene , FID );
			if Mek <> Nil then begin
				MyDest.X := X0;
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
				QuickText( MsgString( 'INFO_Faction' ) , MyDest , NeutralGrey );
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

				msg := GearName( Mek );
				MyDest.X := X1 - TextLength( Game_Font , msg );
				QuickText( msg , MyDest , InfoGreen );
			end;
		end;
	end;

	{ Show the character portrait. }
	MyDest.X := ZONE_Map.X + ( ZONE_Map.W * 5 div 6 ) - 50;
	MyDest.Y := Y0;
	DrawSprite( Backdrop_Sprite , MyDest , 0 );
	SS := ConfirmSprite( PortraitName( PC ) , SAttValue( PC^.SA , 'SDL_COLORS' ) , 100 , 150 );
	DrawSprite( SS , MyDest , 0 );


	{ Print the biography. }
	MyDest.X := ZONE_Map.X + 49;
	MyDest.W := ZONE_Map.W - 98;
	MyDest.Y := Y0 + TTF_FontLineSkip( Game_Font ) * 10;
	MyDest.H := 150;
	SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );

	MyDest.X := MyDest.X + 1;
	MyDest.Y := MyDest.Y + 1;
	MyDest.W := MyDest.W - 2;
	MyDest.H := MyDest.H - 2;
	NFGameMsg( SAttValue( PC^.SA , 'BIO1' ) , MyDest , InfoGreen );
end;

Procedure InjuryViewer( PC: GearPtr );
	{ Display a brief listing of all the PC's major health concerns. }
	Procedure ShowSubInjuries( Part: GearPtr );
		{ Show the injuries of this part, and also for its subcoms. }
	var
		MD,CD: Integer;
	begin
		while Part <> Nil do begin
			MD := GearMaxDamage( Part );
			CD := GearCurrentDamage( Part );
			if not PartActive( Part ) then begin
				AI_PrintFromRight( GearName( Part ) + MsgString( 'INFO_IsDisabled' ) , 2 , StatusColor( MD , CD ) );
				AI_NextLine;
			end else if CD < MD then begin
				AI_PrintFromRight( GearName( Part ) + MsgString( 'INFO_IsHurt' ) , 2 , StatusColor( MD , CD ) );
				AI_NextLine;
			end;
			ShowSubInjuries( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
	Procedure RealInjuryDisplay;
	var
		SP,MP,T: Integer;
	begin
		{ Begin with one massive error check... }
		if PC = Nil then Exit;
		if PC^.G <> GG_Character then PC := LocatePilot( PC );
		if PC = Nil then Exit;

		SetInfoZone( ZONE_Map , PlayerBlue );

		AI_Title( MsgString( 'INFO_InjuriesTitle' ) , StdWhite );

		{ Show exhaustion status first. }
		SP := CharCurrentStamina( PC );
		MP := CharCurrentMental( PC );
		if ( SP = 0 ) and ( MP = 0 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_FullExhausted' ) , 2 , StatusBad );
			AI_NextLine;
		end else if ( SP = 0 ) or ( MP = 0 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_PartExhausted' ) , 2 , StatusFair );
			AI_NextLine;
		end;

		{ Hunger next. }
		T := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
		if T > ( NumGearStats * 3 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_ExtremeHunger' ) , 2 , StatusBad );
			AI_NextLine;
		end else if T > ( NumGearStats * 2 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_Hunger' ) , 2 , StatusFair );
			AI_NextLine;
		end else if T > 0 then begin
			AI_PrintFromRight( MsgString( 'INFO_MildHunger' ) , 2 , StatusOK );
			AI_NextLine;
		end;

		{ Low morale next. }
		T := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );
		if T > 65 then begin
			AI_PrintFromRight( MsgString( 'INFO_ExtremeMorale' ) , 2 , StatusBad );
			AI_NextLine;
		end else if T > 40 then begin
			AI_PrintFromRight( MsgString( 'INFO_Morale' ) , 2 , StatusFair );
			AI_NextLine;
		end else if T > 20 then begin
			AI_PrintFromRight( MsgString( 'INFO_MildMorale' ) , 2 , StatusOK );
			AI_NextLine;
		end;


		for t := 1 to Num_Status_FX do begin
			if NAttValue( PC^.NA , NAG_StatusEffect , T ) <> 0 then begin
				AI_PrintFromRight( MsgString( 'INFO_Status' + BStr( T ) ) , 2 , StatusBad );
				AI_NextLine;
			end;
		end;

		{ Show limb injuries. }
		ShowSubInjuries( PC^.SubCom );
	end;
var
	A: Char;
begin
	repeat
		SetupCombatDisplay;
		RedrawConsole;
		DisplayGearInfo( PC );

		RealInjuryDisplay;
		GHFlip;
		A := RPGKey;
	until ( A = ' ' ) or ( A = #27 ) or ( A = #8 );
end;

Procedure MapEditInfo( Pen,Palette,X,Y: Integer );
	{ Show the needed info for the map editor- the current pen }
	{ terrain, the terrain palette, and the cursor position. }
begin
	CMessage( BStr( X ) + ',' + BStr( Y ) , ZONE_Clock , StdWhite );
end;

initialization
	Interact_Sprite := ConfirmSprite( Interact_Sprite_Name , '' , 4 , 16 );
	Module_Sprite := ConfirmSprite( Module_Sprite_Name , '' , 16 , 16 );
	Backdrop_Sprite := ConfirmSprite( Backdrop_Sprite_Name , '' , 100 , 150 );
	Altimeter_Sprite := ConfirmSprite( Altimeter_Sprite_Name , '' , 26 , 65 );
	Speedometer_Sprite := ConfirmSprite( Speedometer_Sprite_Name , '' , 26 , 65 );
	StatusFX_Sprite := ConfirmSprite( StatusFX_Sprite_Name , '' , 10 , 12 );
	OtherFX_Sprite := ConfirmSprite( OtherFX_Sprite_Name , '' , 10 , 12 );

	Master_Portrait_List := CreateFileList( Graphics_Directory + 'por_*.*' );

finalization
    DisposeSAtt( Master_Portrait_List );


end.
