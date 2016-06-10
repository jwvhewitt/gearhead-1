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

Function DefaultPortraitList( NPC: GearPtr ): SAttPtr;
Function JobAgeGenderDesc( NPC: GearPtr ): String;

Procedure DrawPortrait( GB: GameBoardPtr; NPC: GearPtr; MyDest: TSDL_Rect; WithBackground: Boolean );

Procedure DisplayTargetInfo( Part: GearPtr; gb: GameBoardPtr; Z: DynamicRect );
Procedure DisplayPCInfo( Part: GearPtr; GB: GameBoardPtr );

Procedure LongformGearInfo( Part: GearPtr; gb: GameBoardPtr; Z: DynamicRect );

Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
Procedure QuickWeaponInfo( Part: GearPtr );
Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr; DZone: DynamicRect );
Procedure InjuryViewer( PC: GearPtr; Redrawer: RedrawProcedureType );

Procedure DrawBackpackHeader( PC: GearPtr );

Procedure MapEditInfo( Pen,Palette,X,Y: Integer );

Procedure PilotInfoForSelectingAMecha( PC: GearPtr; GB: GameBoardPtr; Z: DynamicRect );
Procedure MechaInfoForSelectingAPilot( Mek: GearPtr; GB: GameBoardPtr; Z: DynamicRect );
Procedure MechaEngineeringInfo( Mek: GearPtr; GB: GameBoardPtr; Z: DynamicRect );


implementation

uses i18nmsg,termenc,ghmodule,ghweapon,ghmecha,ghchars,ghsupport,ghmovers,ui4gh;

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

	Altimeter_Sprite_Name = 'sys_altimeter.png';
	Speedometer_Sprite_Name = 'sys_speedometer.png';
	StatusFX_Sprite_Name = 'statusfx.png';
	OtherFX_Sprite_Name = 'otherfx.png';

var
	CZone,CDest: TSDL_Rect;		{ Current Zone, Current Destination }
	Interact_Sprite,Module_Sprite,Backdrop_Sprite: SensibleSpritePtr;
	Altimeter_Sprite,Speedometer_Sprite: SensibleSpritePtr;
	StatusFX_Sprite,OtherFX_Sprite: SensibleSpritePtr;
    Master_Portrait_List: SAttPtr;

Function DefaultPortraitList( NPC: GearPtr ): SAttPtr;
    { Return the default list of sprites for this NPC, based on gender. }
var
    PList: SAttPtr;
begin
	if (NPC<>Nil) and (NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male) then begin
		PList := CreateFileList( Graphics_Directory + 'por_m_*.*' );
	end else if (NPC<>Nil) and (NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Female) then begin
		PList := CreateFileList( Graphics_Directory + 'por_f_*.*' );
	end else begin
		PList := CreateFileList( Graphics_Directory + 'por_m_*.*' );
        ExpandFileList( PList, Graphics_Directory + 'por_f_*.*' );
	end;
    DefaultPortraitList := PList;
end;

Function JobAgeGenderDesc( NPC: GearPtr ): String;
	{ Return the Job, Age, and Gender of the provided character in }
	{ a nicely formatted string. }
var
	gender: String;
begin
	gender := '';
	if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) <> NAV_Undefined then begin
		gender := GenderName[ NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) ];
	end;
	JobAgeGenderDesc := ReplaceHash( I18N_MsgString('JobAgeGenderDesc'),
				BStr( NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) + 20 ),
				I18N_Name('GenderName',gender),
				I18N_Name('Jobs',SAttValue( NPC^.SA , 'JOB' )) );
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
begin
	MyImage := I18N_TTF_RenderText( Game_Font , msg , C );

	if MyImage <> Nil then CDest.X := CZone.X + ( ( CZone.W - MyImage^.W ) div 2 );

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );

	CDest.Y := CDest.Y + TTF_FontLineSkip( Game_Font );
end;

Procedure AI_SmallTitle( msg: String; C: TSDL_Color );
	{ Draw a centered message on the current line. }
var
	MyImage: PSDL_Surface;
begin
	MyImage := I18N_TTF_RenderText( Info_Font , msg , C );

	CDest.X := CZone.X + ( ( CZone.W - MyImage^.W ) div 2 );

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );

	CDest.Y := CDest.Y + TTF_FontLineSkip( Info_Font );
end;


Procedure AI_Text( msg: String; C: TSDL_Color );
	{ Draw a text message starting from the current line. }
var
	MyText: PSDL_Surface;
begin
	MyText := PrettyPrint( msg , CDest.W, C, True, Info_Font );
	if MyText <> Nil then begin
		SDL_SetClipRect( Game_Screen , @CZone );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @CDest );
		CDest.X := CZone.X;
		if TERMINAL_bidiRTL then begin
			CDest.X := CDest.X + CZone.W - MyText^.W;
		end;
		CDest.Y := CDest.Y + MyText^.H + 8;
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Procedure AI_PrintFromRight( msg: String; Tab: Integer; C: TSDL_Color );
	{ Draw a left justified message on the current line. }
var
	MyImage: PSDL_Surface;
begin
	MyImage := I18N_TTF_RenderText( Info_Font , msg , C );

	CDest.X := CZone.X + Tab;

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );
end;

Procedure AI_PrintFromLeft( msg: String; Tab: Integer; C: TSDL_Color );
	{ Draw a left justified message on the current line. }
var
	MyImage: PSDL_Surface;
begin
	MyImage := I18N_TTF_RenderText( Info_Font , msg , C );

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

Procedure DisplayModules( Mek: GearPtr; MyZone: TSDL_Rect );
	{ Draw a lovely little diagram detailing this mek's modules. }
var
	X0: LongInt;	{ Midpoint of the info display. }
	N: Integer;	{ Module number on the current line. }
	MyDest: TSDL_Rect;
	MM,A,B: Integer;

	Function PartStructImage( MD: GearPtr; CuD, MxD: Integer ): Integer;
		{ Given module type GS, with current damage score CuD and maximum damage }
		{ score MxD, return the correct image to use for it in the diagram. }
	begin
		if ( MxD > 0 ) and ( CuD < 1 ) then begin
			PartStructImage := ( MD^.S * 9 ) - 1;
		end else begin
			PartStructImage := ( MD^.S * 9 ) - 1 - ( CuD * 8 div MxD );
		end;
	end;

	Function PartArmorImage( MD: GearPtr; CuD, MxD: Integer ): Integer;
		{ Given module type GS, with current armor score CuD and maximum armor }
		{ score MxD, return the correct image to use for it in the diagram. }
	begin
		if CuD < 1 then begin
			PartArmorImage := ( MD^.S * 9 ) + 71;
		end else begin
			PartArmorImage := ( MD^.S * 9 ) + 71 - ( CuD * 8 div MxD );
		end;
	end;
    Procedure DrawThisPart( MD: GearPtr );
        { Display part MD. }
	var
		CuD,MxD: Integer;	{ Armor & Structural damage values. }
    begin
		{ First, determine the spot at which to display the image. }
		if Odd( N ) then MyDest.X := X0 - ( N div 2 ) * 12 - 12
		else MyDest.X := X0 + ( N div 2 ) * 12;
		Inc( N );

		{ Display the structure. }
		MxD := GearMaxDamage( MD );
		CuD := GearCurrentDamage( MD );
		DrawSprite( Module_Sprite , MyDest , PartStructImage( MD , CuD , MxD ) );

		{ Display the armor. }
		MxD := MaxTArmor( MD );
		CuD := CurrentTArmor( MD );
		if MxD <> 0 then begin
			DrawSprite( Module_Sprite , MyDest , PartArmorImage( MD , CuD , MxD ) );

		end;
    end;
	Procedure AddPartsOfType( GS: Integer );
		{ Add parts to the status diagram whose gear S value }
		{ is equal to the provided number and haven't overridden their tier. }
    var
        MD: GearPtr;
	begin
		MD := Mek^.SubCom;
		while ( MD <> Nil ) do begin
			if ( MD^.G = GG_Module ) and ( MD^.S = GS ) and ( MD^.Stat[ STAT_InfoTier ] = 0 ) then begin
                DrawThisPart( MD );
			end;
			MD := MD^.Next;
		end;
	end;
	Procedure AddPartsOfTier( Tier: Integer );
		{ Add parts to the status diagram whose InfoTier value }
		{ is equal to the provided number. }
    var
        MD: GearPtr;
	begin
		MD := Mek^.SubCom;
		while ( MD <> Nil ) do begin
			if ( MD^.G = GG_Module ) and ( MD^.Stat[ STAT_InfoTier ] = Tier ) then begin
                DrawThisPart( MD );
			end;
			MD := MD^.Next;
		end;
	end;
begin
	{ Draw the status diagram for this mek. }
	{ Line One - Heads, Turrets, Storage }
	MyDest.Y := MyZone.Y;
	X0 := MyZone.X + ( MyZone.W div 2 ) - 7;

	N := 0;
	AddPartsOfType( GS_Head );
	AddPartsOfType( GS_Turret );
	if N < 1 then N := 1;	{ Want pods to either side of body; head and/or turret in middle. }
	AddPartsOfType( GS_Storage );
    AddPartsOfTier( 1 );

	{ Line Two - Torso, Arms, Wings }
	N := 0;
	MyDest.Y := MyDest.Y + 17;
	AddPartsOfType( GS_Body );
	AddPartsOfType( GS_Arm );
	AddPartsOfType( GS_Wing );
    AddPartsOfTier( 2 );

	{ Line Three - Tail, Legs }
	N := 0;
	MyDest.Y := MyDest.Y + 17;
	AddPartsOfType( GS_Tail );
	if N < 1 then N := 1;	{ Want legs to either side of body; tail in middle. }
	AddPartsOfType( GS_Leg );
    AddPartsOfTier( 3 );
end;

Procedure DisplayStatusFX( Part: GearPtr; MyZone: TSDL_Rect );
	{ Show status effects and other things this part might be suffering from. }
var
	MyDest: TSDL_Rect;
	T: Integer;
begin
	MyDest := MyZone;

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
		MyDest.Y := CDest.Y + 16;
		MyDest.X := CZone.X + ( CZone.W div 8 );
		DrawSprite( Module_Sprite , MyDest , 144 + ( NAttValue( Part^.NA , NAG_Location , NAS_D ) + 1 ) mod 8 );

		n := mekAltitude( GB , Part ) + 3;
		if N < 0 then n := 0
		else if N > 8 then n := 8;
		MyDest.Y := CDest.Y;
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
		MyDest.Y := CDest.Y;
		MyDest.X := CZone.X + ( CZone.W div 8 ) - 24;
		DrawSprite( Speedometer_Sprite , MyDest , N );

	end else if SAttValue( Part^.SA , 'SDL_SPRITE' ) <> '' then begin
		MyDest.Y := CDest.Y - 12;
		MyDest.X := CZone.X + ( CZone.W div 8 ) - 8;
		DrawSprite( ConfirmSprite( SAttValue( Part^.SA , 'SDL_SPRITE' ) , SAttValue( Part^.SA , 'SDL_COLORS' ) , 64 , 64 ) , MyDest , ( Animation_Phase div 10 ) mod 8 );
	end;
end;

Procedure MekStatDisplay( Mek: GearPtr; GB: GameBoardPtr; LongForm: Boolean );
	{ Display the stats for MEK. }
	{ MEK absolutely must be a valid mecha; otherwise }
	{ there's gonna be a strange display. }
var
	msg: String;
	MM,A,B,CurM,MaxM: Integer;
	MD: GearPtr;
	C: TSDL_Color;
    MyDest: TSDL_Rect;
begin
	{ General mecha information - Name, mass, maneuver }
	AI_Title( GearName(Mek) , InfoHilight );

	{ Draw the status diagram for this mek. }
	DisplayModules( Mek, CDest );
	LocationInfo( Mek , GB );

	{ Print MV, TR, and SN. }
	AI_PrintFromRight( ReplaceHash( I18N_MsgString('MekStatDisplay','MV:') , SgnStr(MechaManeuver(Mek)) ) , ( CZone.W * 3 ) div 4 , InfoGreen );
	AI_NextLine;
	AI_PrintFromRight( ReplaceHash( I18N_MsgString('MekStatDisplay','TR:') , SgnStr(MechaTargeting(Mek)) ) , ( CZone.W * 3 ) div 4 , InfoGreen );
	AI_NextLine;
	AI_PrintFromRight( ReplaceHash( I18N_MsgString('MekStatDisplay','SE:') , SgnStr(MechaSensorRating(Mek)) ) , ( CZone.W * 3 ) div 4 , InfoGreen );
	AI_NextLine;

    MyDest := CDest;
    MyDest.X := ( CZone.W * 3 ) div 4 + CZone.X - 12;
	DisplayStatusFX( Mek, MyDest );

    CDest.Y := CZone.Y + 50 + TTF_FontLineSkip( Game_Font );
	if LongForm then AI_NextLine;

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

		AI_PrintFromLeft( ReplaceHash( I18N_MsgString('MekStatDisplay','HP') , BStr( GearCurrentDamage( MD ) ) ) , ( CZone.W * 3 ) div 4 , HitsColor( MD ) );
		AI_NextLine;
	end;

	{ Movement information. }
	MM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	if MM > 0 then begin
		msg := I18N_Name('MoveModeName',MoveModeName[ MM ]);
		msg := msg + ' (' + BStr( Speedometer( Mek ) ) + 'dpr)';
	end else begin
		msg := I18N_MsgString('MekStatDisplay','Immobile');
	end;
	AI_SmallTitle( msg , InfoGreen );

	if Longform then begin
		AI_SmallTitle( MassString( Mek ) + ' ' + FormName[Mek^.S] + '  ' + ReplaceHash( I18N_MsgString('MekStatDisplay','PV:') , BStr( GearValue( Mek ) ) ) , InfoHilight );

		{ Encumbrance information. }

		{ Get the current mass of carried equipment. }
		CurM := EquipmentMass( Mek );

		{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
		MaxM := ( GearEncumberance( Mek ) * 2 ) - 1;

		AI_PrintFromRight( I18N_MsgString('MekStatDisplay','Enc:') , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , I18N_MsgString('MekStatDisplay','Enc:') + BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' ) - 24 , InfoGreen );
		AI_PrintFromRight( BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' ) - 24 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );
	end;
end;

Procedure CharacterInfo( Part: GearPtr; GB: GameBoardPtr; LongForm: Boolean );
	{ This gear is a character. Print a list of stats and skills. }
var
	T,TT,Width,S,CurM,MaxM: Integer;
	C: TSDL_Color;
	MyDest: TSDL_Rect;
begin
	{ Show the character's name and health status. }
	AI_Title( GearName(Part) , InfoHilight );

	DisplayModules( Part, CDest );
	LocationInfo( Part , GB );

	{ Print HP, ME, and SP. }
	AI_PrintFromRight( I18N_MsgString('CharacterInfo','HP:') , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , 'HP:' ) - 2 , InfoGreen );
	AI_PrintFromRight( BStr( GearCurrentDamage(Part)) + '/' + BStr( GearMaxDamage(Part)) , ( CZone.W * 13 ) div 16 , HitsColor( Part ) );
	AI_NextLine;
	AI_PrintFromRight( I18N_MsgString('CharacterInfo','St:') , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , 'St:' ) - 2 , InfoGreen );
	AI_PrintFromRight( BStr( CharCurrentStamina(Part)) + '/' + BStr( CharStamina(Part)) , ( CZone.W * 13 ) div 16 , EnduranceColor( CharStamina(Part) , CharCurrentStamina(Part) ) );
	AI_NextLine;
	AI_PrintFromRight( I18N_MsgString('CharacterInfo','Me:') , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , 'Me:' ) - 2 , InfoGreen );
	AI_PrintFromRight( BStr( CharCurrentMental(Part)) + '/' + BStr( CharMental(Part)) , ( CZone.W * 13 ) div 16 , EnduranceColor( CharMental(Part) , CharCurrentMental(Part) ) );
	AI_NextLine;

	MyDest := CDest;
	MyDest.X := ( CZone.W * 3 ) div 4 + CZone.X - 12;
	DisplayStatusFX( Part, MyDest );

	CDest.Y := CZone.Y + 50 + TTF_FontLineSkip( Game_Font );
	if LongForm then AI_NextLine;


	{ Determine the spacing for the character's stats. }
	Width := CZone.W div 4;

	{ Show the character's stats. }
	for t := 1 to ( NumGearStats div 4 ) do begin
		for tt := 1 to 4 do begin
			AI_PrintFromRight( HeadMBChar( I18N_Name('StatName', StatName[ T * 4 + TT - 4 ]) ) + ':' , ( TT-1 ) * Width + 1 , InfoGreen );

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
	if Longform then begin

		{ Get the current mass of carried equipment. }
		CurM := EquipmentMass( Part );

		{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
		MaxM := ( GearEncumberance( Part ) * 2 ) - 1;

		AI_PrintFromRight( I18N_MsgString('CharacterInfo','Enc:') , 1 , InfoGreen );
		AI_PrintFromRight( BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 'kg' , 36 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );
	end;
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
	AI_Title( GearName(Part) , InfoHilight );

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

	N := ( Int64(GearMass( Part )) + 1 ) div 2;
	if N > 0 then AI_PrintFromLeft( MassString( Part ) , CZone.W - 1 , InfoGreen );

	if Part^.G < 0 then begin
		AI_NextLine;
		AI_PrintFromRight( Bstr( Part^.G ) + ',' + BStr( Part^.S ) + ',' + BStr( Part^.V ) , CZone.W div 2 , StdWhite );
	end;

	AI_Dest := CZone;
	AI_Dest.X := AI_Dest.X + 10;
	AI_Dest.Y := CDest.Y + TTF_FontLineSkip( Info_Font ) + 10;
	AI_Dest.W := AI_Dest.W - 20;
	AI_Dest.H := AI_Dest.H - ( CDest.Y - CZone.Y ) - 20 - TTF_FontLineSkip( Info_Font );
	GameMsg( ExtendedDescription( Part ) , AI_Dest , InfoGreen );
end;

Procedure SetInfoZone( var Z: TSDL_Rect );
	{ Copy the provided coordinates into this unit's global }
	{ variables, then draw a nice little border and clear the }
	{ selected area. }
begin
	{ Copy the dimensions provided into this unit's global variables. }
	CZone := Z;
	CDest := Z;
	{ClrZone( Z );}
end;

Procedure RepairFuelInfo( Part: GearPtr );
	{ Display info for any gear that doesn't have its own info }
	{ procedure. }
var
	N: LongInt;
begin
	{ Show the part's name. }
	AI_Title( GearName(Part) , InfoHilight );

	N := GearMass( Part );
	if N > 0 then AI_PrintFromLeft( MassString( Part ) , CZone.W - 1 , InfoGreen );

	AI_NextLine;
	AI_SmallTitle( I18N_Name('SkillMan',SkillMan[ Part^.S ].Name) , BrightYellow );
	AI_SmallTitle( BStr( Part^.V ) + ' DP' , InfoGreen );
end;


Procedure GearInfo( Part: GearPtr; var Z: TSDL_Rect; BorColor: TSDL_Color; GB: GameBoardPtr );
	{ Display some information for this gear inside the screen area }
	{ X1,Y1,X2,Y2. }
begin
	SetInfoZone( Z );

	{ Error check }
	{ Note that we want the area cleared, even in case of an error. }
	if Part = Nil then exit;

	{ Depending upon PART's type, branch to an appropriate procedure. }
	case Part^.G of
		GG_Mecha:	MekStatDisplay( Part , GB, True );
		GG_Character:	CharacterInfo( Part , GB, True );
		GG_RepairFuel:	RepairFuelInfo( Part );
	else MiscInfo( Part );
	end;
end;


Procedure DisplayPCInfo( Part: GearPtr; GB: GameBoardPtr );
	{ Show some stats for whatever sort of thing PART is. }
begin
	{ All this procedure does is call the ArenaInfo unit procedure }
	{ with the dimensions of the Info Zone. }
	CZone := ZONE_PCInfo;
	CDest := ZONE_PCInfo;

	{ Error check }
	{ Note that we want the area cleared, even in case of an error. }
	if Part = Nil then exit;

	{ Depending upon PART's type, branch to an appropriate procedure. }
	case Part^.G of
		GG_Mecha:	MekStatDisplay( Part , GB, False );
		GG_Character:	CharacterInfo( Part , GB, False );
	end;
end;


Procedure DisplayTargetInfo( Part: GearPtr; gb: GameBoardPtr; Z: DynamicRect );
	{ Show some stats for whatever sort of thing PART is. }
var
    MyRect: TSDL_Rect;
begin
	{ All this procedure does is call the ArenaInfo unit procedure }
	{ with the dimensions of the provided Zone. }
    MyRect := Z.GetRect();
	GearInfo( Part , MyRect , TeamColor( GB , Part ) , GB );
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
        PList := DefaultPortraitList( NPC );

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

Procedure DrawPortrait( GB: GameBoardPtr; NPC: GearPtr; MyDest: TSDL_Rect; WithBackground: Boolean );
    { Draw this character's portrait in the requested area. }
    { Note that if we have a pet rather than a character, }
    { draw its sprite instead. }
var
    SS: SensibleSpritePtr;
begin
    if NAttValue( NPC^.NA, NAG_CharDescription, NAS_Sentience ) = NAV_IsCharacter then begin
	    if WithBackground then DrawSprite( Backdrop_Sprite , MyDest , 0 );
	    SS := ConfirmSprite( PortraitName( NPC ) , TeamColorString( GB , NPC ) , 100 , 150 );
	    DrawSprite( SS , MyDest , 0 );
    end else begin
        MyDest.X := MyDest.X + 18;
        MyDest.Y := MyDest.Y + 43;
        SS := ConfirmSprite( GearSpriteName(Nil,NPC) , TeamColorString( GB , NPC ) , 64 , 64 );
	    if SS <> Nil then DrawSprite( SS , MyDest , Animation_Phase div 5 mod 8 );
    end;
end;


Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
	{ Show the needed information regarding this conversation. }
var
	msg,job: String;
	MyDest: TSDL_Rect;
	T,RStep: Integer;
	SS: SensibleSpritePtr;
begin
    MyDest := ZONE_InteractStatus.GetRect();
	SetInfoZone( MyDest );

	CHAT_React := React;
	CHAT_Endurance := Endurance;

	{ First the name, then the description. }
	AI_Title( GearName( NPC ) , InfoHiLight );
	AI_Title( JobAgeGenderDesc( NPC ) , InfoGreen );

	{ Prepare to draw the reaction indicators. }
	{ClrZone( ZONE_InteractInfo.GetRect() );}
	MyDest := ZONE_InteractInfo.GetRect();
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

	MyDest := ZONE_InteractInfo.GetRect();
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
    DrawPortrait( GB, NPC, ZONE_InteractPhoto.GetRect(), True );
end;

Procedure QuickWeaponInfo( Part: GearPtr );
	{ Provide quick info for this weapon in the MENU2 zone. }
begin
	if Part = Nil then exit;

	{ Display the weapon description. }
	CMessage( GearName( Part ) + ' ' + WeaponDescription( Part ) , ZONE_Menu1.GetRect() , InfoGreen );
end;

Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr; DZone: DynamicRect );
	{ Display the important stats for this PC in the specified zone. }
var
	msg,job: String;
	T,R,FID: Integer;
	S: LongInt;
	C: TSDL_Color;
	X0,X1,Y0: Integer;
	Mek: GearPtr;
	MyZone,MyDest: TSDL_Rect;
	SS: SensibleSpritePtr;
begin
	{ Begin with one massive error check... }
	if PC = Nil then Exit;
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

    MyZone := DZone.GetRect();
	SetInfoZone( MyZone );

	AI_Title( GearName( PC ) , InfoHilight );
	AI_Title( JobAgeGenderDesc( PC ) , InfoGreen );
	AI_NextLine;

	{ Record the current Y position- we'll be coming back here later. }
	Y0 := CDest.Y;

	MyDest.Y := CDest.Y;
	X0 := MyZone.X + ( MyZone.W div 3 );

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
		MyDest.X := MyZone.X + 10;
		QuickText( I18N_Name( 'StatName', StatName[ T ] ) , MyDest , NeutralGrey );
		msg := BStr( S );
		MyDest.X := X0 - 30 - TextLength( Game_Font , msg );
		QuickText( msg , MyDest , C );

		MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
	end;

	{ Set column measurements for the next column. }
	MyDest.Y := Y0;
	X0 := MyZone.X + ( MyZone.W div 3 );
	X1 := MyZone.X + ( MyZone.W * 2 div 3 ) - 10;

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
	MyDest.X := MyZone.X + ( MyZone.W * 5 div 6 ) - 50;
	MyDest.Y := Y0;

    DrawPortrait( GB, PC, MyDest, True );

	{ Print the biography. }
	MyDest.X := MyZone.X + 49;
	MyDest.W := MyZone.W - 98;
	MyDest.Y := Y0 + TTF_FontLineSkip( Game_Font ) * 10;
	MyDest.H := 150;
    InfoBox( MyDest );

	MyDest.X := MyDest.X + 1;
	MyDest.Y := MyDest.Y + 1;
	MyDest.W := MyDest.W - 2;
	MyDest.H := MyDest.H - 2;
	GameMsg( SAttValue( PC^.SA , 'BIO1' ) , MyDest , InfoGreen );
end;

Procedure InjuryViewer( PC: GearPtr; Redrawer: RedrawProcedureType );
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
        MyZone: TSDL_Rect;
	begin
		{ Begin with one massive error check... }
		if PC = Nil then Exit;
		if PC^.G <> GG_Character then PC := LocatePilot( PC );
		if PC = Nil then Exit;

        MyZone := ZONE_MoreText.GetRect();
        InfoBox( MyZone );
		SetInfoZone( MyZone );

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
		A := RPGKey;
        if A = RPK_TimeEvent then begin
            if Redrawer <> Nil then Redrawer();
    		RealInjuryDisplay;
            ghflip();
        end;
	until ( A = ' ' ) or ( A = #27 ) or ( A = #8 );
end;

Procedure LFGI_ForItems( Part: GearPtr; gb: GameBoardPtr );
    { Longform info for whatever the heck this is. }
var
    AI_Dest: TSDL_Rect;
    msg: String;
	N: LongInt;
begin
    msg := GenericName( Part );
    if msg <> GearName( Part ) then begin
        AI_SmallTitle( msg, InfoGreen );
        AI_NextLine();
    end;

	{ Display the part's damage rating. }
	N := GearCurrentDamage( Part );
	if N > 0 then msg := BStr( N )
	else msg := '-';
	AI_PrintFromRight( ReplaceHash( I18N_MsgString('LFGI_ForItems','Damage:') , msg ) , 8 , HitsColor( Part ) );
	AI_NextLine;

	{ Display the part's armor rating. }
	N := GearCurrentArmor( Part );
	if N > 0 then msg := BStr( N )
	else msg := '-';
	AI_PrintFromRight( ReplaceHash( I18N_MsgString('LFGI_ForItems','Armor:') , msg ) , 8 , ArmorColor( Part ) );
	AI_NextLine;

	AI_PrintFromRight( ReplaceHash( I18N_MsgString('LFGI_ForItems','Mass:') , MassString( Part ) ) , 8 , InfoGreen );
	AI_NextLine;
	AI_NextLine;

    if Part^.G = GG_Weapon then begin

	end else if Part^.G < 0 then begin
		AI_NextLine;
		AI_PrintFromRight( Bstr( Part^.G ) + ',' + BStr( Part^.S ) + ',' + BStr( Part^.V ) , CZone.W div 2 , StdWhite );
	end;

    CDest.X := CZone.X;
    CDest.W := CZone.W;
    AI_Text( ExtendedDescription( Part ) , InfoGreen );
    msg := FormatDescString(Part);
    if msg <> '' then AI_Text( msg, InfoGreen );
end;

Procedure LFGI_ForMecha( Part: GearPtr; gb: GameBoardPtr; ReallyLong: Boolean );
    { Longform info for whatever the heck this is. }
var
    MyDest: TSDL_Rect;
    msg: String;
    n,mm,mspeed,hispeed,CurM,MaxM: Integer;
    SS: SensibleSpritePtr;
begin
	msg := TeamColorString( GB , Part );
	CDest.X := CZone.X;
	SS := ConfirmSprite( SAttValue(Part^.SA,'SDL_PORTRAIT') , msg , 160 , 160 );
	if (SS = Nil) or (SS^.Img = Nil) then SS := ConfirmSprite( 'mecha_noimage.png', msg, 160 , 160 );
	if SS <> Nil then DrawSprite( SS , CDest , 0 );
	CDest.X := CDest.X + 173;
	SS := ConfirmSprite( GearSpriteName(Nil,Part) , msg , 64 , 64 );
	if SS <> Nil then DrawSprite( SS , CDest , Animation_Phase div 5 mod 8 );

	CDest.X := CZone.X + 160;
	CDest.Y := CDest.Y + 72;
	CDest.W := CZone.W - 160;
	DisplayModules( Part, CDest );
	CDest.Y := CDest.Y + 50;
	n := PercentDamaged( Part );
	msg := BStr(n) + '%';
	CMessage( msg, CDest, StatusColor( 100, n ) );

	if ReallyLong then begin
		CDest.Y := CZone.Y + 174;
		AI_SmallTitle( MassString( Part ) + ' ' + FormName[Part^.S] + '  PV:' + BStr( GearValue( Part ) ) , InfoHilight );

		{ Get the current mass of carried equipment. }
		CurM := EquipmentMass( Part );

		{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
		MaxM := ( GearEncumberance( Part ) * 2 ) - 1;
		AI_SmallTitle( ReplaceHash( I18N_MsgString('LFGI_ForMecha','Enc:') , MakeMassString( CurM, Part^.Scale ) , MakeMassString( MaxM, Part^.Scale ) ) , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );

		CDest.Y := CDest.Y + 5;
		n := CDest.Y;
		CDest.X := CZone.X;
		AI_PrintFromRight( ReplaceHash( I18N_MsgString('LFGI_ForMecha','MV:') , SgnStr(MechaManeuver(Part)) ) , 175, InfoGreen );
		AI_NextLine;
		AI_PrintFromRight( ReplaceHash( I18N_MsgString('LFGI_ForMecha','TR:') , SgnStr(MechaTargeting(Part)) ) , 175, InfoGreen );
		AI_NextLine;
		AI_PrintFromRight( ReplaceHash( I18N_MsgString('LFGI_ForMecha','SE:') , SgnStr(MechaSensorRating(Part)) ) , 175, InfoGreen );
		AI_NextLine;
		hispeed := 0;
		for mm := 1 to NumMoveMode do begin
			mspeed := AdjustedMoveRate( Part , MM , NAV_NormSpeed );
			if mspeed > 0 then begin
				AI_PrintFromRight( MoveDesc(Part,MM), 175, InfoGreen );
				AI_NextLine;
			end;
			if MoveLegal( Part, MM, NAV_FullSpeed, 0 ) then begin
				mspeed := AdjustedMoveRate( Part , MM , NAV_FullSpeed );
				if mspeed > hispeed then hispeed := mspeed;
			end;
		end;
		AI_PrintFromRight( ReplaceHash(MsgString('MAX_SPEED'),BStr(hispeed)), 175, InfoGreen );
		AI_NextLine;

		MyDest.X := CZone.X;
		MyDest.Y := n;
		MyDest.W := 170;
		MyDest.H := CZone.Y + CZone.H - n;
		GameMsg( FormatDescString(Part) , MyDest , InfoGreen, Info_Font );
	end;
end;

Procedure LFGI_ForCharacters( Part: GearPtr; gb: GameBoardPtr );
	{ Longform info for whatever the heck this is. }
var
	MyDest: TSDL_Rect;
	msg: String;
	n,sval,CurM,MaxM: Integer;
	SS: SensibleSpritePtr;
begin
	msg := TeamColorString( GB , Part );
	CDest.X := CZone.X;
	DrawPortrait( GB, Part, CDest, False );

	N := CDest.Y;
	AI_NextLine;

	{ Print HP, ME, and SP. }
	AI_PrintFromLeft( I18N_MsgString('LFGI_ForCharacters','HP:') , 170 , InfoGreen );
	AI_PrintFromRight( BStr( GearCurrentDamage(Part)) + '/' + BStr( GearMaxDamage(Part)) , 175 , HitsColor( Part ) );
	AI_NextLine;
	AI_PrintFromLeft( I18N_MsgString('LFGI_ForCharacters','St:') , 170 , InfoGreen );
	AI_PrintFromRight( BStr( CharCurrentStamina(Part)) + '/' + BStr( CharStamina(Part)) , 175 , EnduranceColor( CharStamina(Part) , CharCurrentStamina(Part) ) );
	AI_NextLine;
	AI_PrintFromLeft( I18N_MsgString('LFGI_ForCharacters','Me:') , 170 , InfoGreen );
	AI_PrintFromRight( BStr( CharCurrentMental(Part)) + '/' + BStr( CharMental(Part)) , 175 , EnduranceColor( CharMental(Part) , CharCurrentMental(Part) ) );
	AI_NextLine;
	{ Get the current mass, max mass of carried equipment. }
	CurM := EquipmentMass( Part );
	MaxM := ( GearEncumberance( Part ) * 2 ) - 1;
	AI_PrintFromLeft( I18N_MsgString('LFGI_ForCharacters','Enc:') , 170 , InfoGreen );
	AI_PrintFromRight( MakeMassString( CurM, Part^.Scale ), 175 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );
	AI_NextLine;

	CDest.X := CZone.X + 160;
	CDest.Y := N + 72;
	CDest.W := CZone.W - 160;
	DisplayModules( Part, CDest );
	CDest.Y := CDest.Y + 50;
	n := PercentDamaged( Part );
	msg := BStr(n) + '%';
	CMessage( msg, CDest, StatusColor( 100, n ) );

	CDest.X := CZone.X;
	CDest.Y := CZone.Y + 174;


	for n := 1 to 4 do begin
		AI_PrintFromRight( StatName[n] + ':' , 8 , InfoGreen );
		AI_PrintFromLeft( BStr( CStat( Part, n ) ) , CZone.W div 2 - 8 , InfoGreen );
		AI_PrintFromRight( StatName[n+4] + ':' , CZone.W div 2 + 8 , InfoGreen );
		AI_PrintFromLeft( BStr( CStat( Part, n+4 ) ) , CZone.W - 8 , InfoGreen );
		AI_NextLine;
	end;

	MyDest := CZone;
	MyDest.X := MyDest.X + 10;
	MyDest.Y := CDest.Y + TTF_FontLineSkip( Info_Font );
	MyDest.W := MyDest.W - 20;
	MyDest.H := MyDest.H - ( CDest.Y - CZone.Y ) - 40 - TTF_FontLineSkip( Info_Font );
	GameMsg( SAttValue( Part^.SA, 'BIO1' ) , MyDest , InfoGreen );
end;

Procedure LFGI_ForScenes( Part: GearPtr; gb: GameBoardPtr );
    { Longform info for a scene. }
var
    MyDest: TSDL_Rect;
    SS: SensibleSpritePtr;
begin
    CDest.X := CZone.X;
    CDest.Y := CDest.Y + 8;
	SS := ConfirmSprite( SAttValue(Part^.SA,'SDL_PORTRAIT') , '' , 250 , 150 );
	if (SS = Nil) or (SS^.Img = Nil) then SS := ConfirmSprite( 'scene_default.png', '' , 250 , 150 );
	if SS <> Nil then DrawSprite( SS , CDest , 0 );

    MyDest := CZone;
    MyDest.X := MyDest.X + 10;
    MyDest.Y := CZone.Y + TTF_FontLineSkip( Info_Font ) + 165;
    MyDest.W := MyDest.W - 20;
    MyDest.H := MyDest.H - ( CDest.Y - CZone.Y ) - 40 - TTF_FontLineSkip( Info_Font );
    GameMsg( FormatDescString(Part) , MyDest , InfoGreen );
end;


Procedure LongformGearInfo( Part: GearPtr; gb: GameBoardPtr; Z: DynamicRect );
    { Display the longform info for this part. }
var
    MyDest: TSDL_Rect;
    msg: String;
    n: Integer;
begin
    MyDest := Z.GetRect();
	SetInfoZone( MyDest );

	{ Show the part's name. }
	AI_Title( FullGearName(Part) , InfoHilight );

    if Part^.G = GG_Mecha then LFGI_ForMecha( Part, gb, True )
    else if Part^.G = GG_Character then LFGI_ForCharacters( Part, gb )
    else if Part^.G = GG_Scene then LFGI_ForScenes( Part, gb )
    else LFGI_ForItems( Part, gb );
end;

Procedure DrawBackpackHeader( PC: GearPtr );
	{ Add a header to the backpack display showing the PC's name and }
	{ encumberance status. }
var
	MyDest: TSDL_Rect;
	CurM,MaxM: Integer;
begin
	MyDest := ZONE_BPHeader.GetRect();
	SetInfoZone( MyDest );
	AI_Title( LanceMateMenuName(PC) , NeutralGrey );

	{ Get the current mass of carried equipment. }
	CurM := EquipmentMass( PC );

	{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
	MaxM := ( GearEncumberance( PC ) * 2 ) - 1;

	AI_PrintFromRight( I18N_MsgString('MekStatDisplay','Enc:') , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , I18N_MsgString('MekStatDisplay','Enc:') + BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' ) - 24 , NeutralGrey );
	AI_PrintFromRight( MakeMassString( CurM, PC^.Scale ) + '/' + MakeMassString( MaxM, PC^.Scale ) , ( CZone.W * 13 ) div 16 - TextLength( Info_Font , BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' ) - 24 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );

end;

Procedure MapEditInfo( Pen,Palette,X,Y: Integer );
	{ Show the needed info for the map editor- the current pen }
	{ terrain, the terrain palette, and the cursor position. }
begin
	CMessage( BStr( X ) + ',' + BStr( Y ) , ZONE_Clock , StdWhite );
end;

Procedure PilotInfoForSelectingAMecha( PC: GearPtr; GB: GameBoardPtr; Z: DynamicRect );
    { We are going to select a mecha for this pilot. Remind us of who the }
    { pilot is, and maybe show their mecha related skills? }
    Procedure CheckSkill( sk: Integer );
        { If this skill is known by the PC, print it. }
    begin
        if NAttValue( PC^.NA , NAG_Skill, sk ) > 0 then begin
        	AI_PrintFromRight( SkillMan[sk].name + ': ' + SgnStr(NAttValue( PC^.NA , NAG_Skill, sk )) , 116, InfoGreen );
        	AI_NextLine;
        end;
    end;
var
    SS: SensibleSpritePtr;
    MyDest: TSDL_Rect;
    t: Integer;
begin
    MyDest := Z.GetRect();
	SetInfoZone( MyDest );
	AI_Title( GearName(PC) , InfoHilight );

    CDest.X := CZone.X;
	SS := ConfirmSprite( SAttValue(PC^.SA,'SDL_PORTRAIT') , TeamColorString( GB , PC ) , 100 , 150 );
	if SS <> Nil then DrawSprite( SS , CDest , 0 );
    CDest.X := CDest.X + 116;
    AI_NextLine();

    for t := 1 to 5 do begin
        CheckSkill( t );
    end;
    CheckSkill( NAS_Awareness );
    CheckSkill( NAS_ElectronicWarfare );
    CheckSkill( NAS_Initiative );
    CheckSkill( NAS_SpotWeakness );
    CheckSkill( NAS_Stealth );
end;

Procedure MechaInfoForSelectingAPilot( Mek: GearPtr; GB: GameBoardPtr; Z: DynamicRect );
    { We are going to select a pilot for this mecha. }
var
    MyDest: TSDL_Rect;
begin
    MyDest := Z.GetRect();
	SetInfoZone( MyDest );
	AI_Title( GearName(Mek) , InfoHilight );
    LFGI_ForMecha( Mek, GB, False );
end;

Procedure MechaEngineeringInfo( Mek: GearPtr; GB: GameBoardPtr; Z: DynamicRect );
    { Display the technical info for this mecha. }
var
    SS: SensibleSpritePtr;
    MyDest: TSDL_Rect;
    t,needed_pts,active_pts: Integer;
    MyText: PSDL_Surface;
begin
    MyDest := Z.GetRect();
	SetInfoZone( MyDest );
    AI_Title( FullGearName( Mek ), InfoHilight );
    if Mek^.G = GG_Mecha then begin
        MyText := PrettyPrint( MassString( Mek ) + ' ' + FormName[Mek^.S] + ': ' + MsgString( 'FORMINFO_' + BStr( Mek^.S ) ) , MyDest.W, InfoHilight, True, Info_Font );
	    if MyText <> Nil then begin
            CDest.X := CZone.X;
            CDest.W := CZone.W;
		    SDL_SetClipRect( Game_Screen , @CZone );
		    SDL_BlitSurface( MyText , Nil , Game_Screen , @CDest );
            CDest.Y := CDest.Y + MyText^.H + 8;
		    SDL_FreeSurface( MyText );
		    SDL_SetClipRect( Game_Screen , Nil );
	    end;
        AI_PrintFromRight( MsgString('MEI_IntrinsicMass') + MakeMassString( IntrinsicMass(Mek), Mek^.Scale ) + ReplaceHash( MsgString('MEI_MVTRPenalty'),SgnStr(IntrinsicMVTVMod(Mek))), 0, InfoGreen);
        AI_NextLine();
        AI_PrintFromRight( MsgString('MEI_ExtrinsicMass') + MakeMassString( EquipmentMass(Mek), Mek^.Scale ) + ReplaceHash( MsgString('MEI_MVTRPenalty'),SgnStr(EquipmentMVTVMod(Mek))), 0, InfoGreen);
        AI_NextLine();
        AI_NextLine();

        if BaseMoveRate( Mek, MM_Walk ) > 0 then begin
            needed_pts := NeededLegPoints( mek );
            active_pts := CountActivePoints( Mek , GG_Module , GS_Leg );
            if active_pts > needed_pts then begin
                AI_PrintFromRight( MsgString('MEI_LegPoints') + '100%+', 0, InfoGreen);
            end else begin
                AI_PrintFromRight( MsgString('MEI_LegPoints') + BStr((active_pts * 100 ) div needed_pts) + '%', 0, InfoGreen);
            end;
            AI_NextLine();
        end;

        if BaseMoveRate( Mek, MM_Roll ) > 0 then begin
            needed_pts := NeededWheelPoints( mek );
            active_pts := CountActivePoints( Mek , GG_MoveSys , GS_Wheels ) + CountActivePoints( Mek , GG_MoveSys , GS_Tracks );
            if active_pts > needed_pts then begin
                AI_PrintFromRight( MsgString('MEI_RollPoints') + '100%+', 0, InfoGreen);
            end else begin
                AI_PrintFromRight( MsgString('MEI_RollPoints') + BStr((active_pts * 100 ) div needed_pts) + '%', 0, InfoGreen);
            end;
            AI_NextLine();
        end;

        if BaseMoveRate( Mek, MM_Skim ) > 0 then begin
            active_pts :=  CountThrustPoints( mek , MM_Skim , mek^.Scale );
            if active_pts > 0 then begin
                AI_PrintFromRight( MsgString('MEI_SkimThrust') + BStr(active_pts), 0, InfoGreen);
                AI_NextLine();
            end;
        end;

        if BaseMoveRate( Mek, MM_Fly ) > 0 then begin
            active_pts :=  FlightThrust( mek );
            if active_pts > 0 then begin
                AI_PrintFromRight( MsgString('MEI_FlyThrust') + BStr(active_pts), 0, InfoGreen);
                AI_NextLine();
            end;
        end;

        active_pts :=  OverchargeBonus( mek );
        if active_pts > 0 then begin
            AI_PrintFromRight( MsgString('MEI_OverChargeBonus') + SgnStr(active_pts), 0, InfoGreen);
            AI_NextLine();
        end;
    end;
end;


initialization
	Interact_Sprite := ConfirmSprite( Interact_Sprite_Name , '' , 4 , 16 );
	Module_Sprite := ConfirmSprite( Module_Sprite_Name , '' , 16 , 16 );
	Backdrop_Sprite := ConfirmSprite( Backdrop_Sprite_Name , '' , 100 , 150 );
	Altimeter_Sprite := ConfirmSprite( Altimeter_Sprite_Name , '' , 26 , 48 );
	Speedometer_Sprite := ConfirmSprite( Speedometer_Sprite_Name , '' , 26 , 48 );
	StatusFX_Sprite := ConfirmSprite( StatusFX_Sprite_Name , '' , 10 , 12 );
	OtherFX_Sprite := ConfirmSprite( OtherFX_Sprite_Name , '' , 10 , 12 );

	Master_Portrait_List := CreateFileList( Graphics_Directory + 'por_*.*' );

finalization
    DisposeSAtt( Master_Portrait_List );


end.
