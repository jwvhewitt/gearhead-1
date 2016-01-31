unit ConInfo;
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

Procedure GearInfo( Part: GearPtr; X1,Y1,X2,Y2,BorColor: Byte );
Procedure LocationInfo( Part: GearPtr; gb: GameBoardPtr );
Procedure DisplayGearInfo( Part: GearPtr );
Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr; Z: Integer );
Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr );

Function JobAgeGenderDesc( NPC: GearPtr ): String;
Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
Procedure QuickWeaponInfo( Part: GearPtr );
Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
Procedure InjuryViewer( PC: GearPtr );

Procedure MapEditInfo( Pen,Palette,X,Y: Integer );

implementation

uses crt,ability,damage,gearutil,ghchars,ghmecha,ghmodule,ghweapon,
     interact,movement,texutil,congfx,conmap,context;

var
	CX,CY: Byte;			{ Cursor Position }
	ZX1,ZY1,ZX2,ZY2: Byte;		{ Info Zone coords }
	LastGearShown: GearPtr;

const
	SX_Char: Array [1..Num_Status_FX] of Char = (
		'P','B','R','S','H',
		'V','T','D','R','P',
		'A','G','L','N','Z',
		'X','S','R','S','I',
		'@','@','@','@','@'
	);
	SX_Color: Array [1..Num_Status_FX] of Byte = (
		Magenta, LightRed, LightGreen, Magenta, Yellow,
		Cyan, Cyan, Cyan, Cyan, Cyan,
		Cyan, Cyan, Cyan, Cyan, Cyan,
		Cyan, Cyan, Red, Yellow, Magenta,
		Red, Red, Red, Red, Red
	);


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

Procedure AI_Title( msg: String; C: Byte );
	{ Draw a centered message on the current line. }
var
	X: Integer;
begin
	X := ( ( ZX2 - ZX1 ) div 2 ) - ( Length( msg ) div 2 ) + 1;
	if X < 1 then X := 1;
	GotoXY( X , CY );
	TextColor( C );
	Write( msg );
	CX := 1;
	CY := CY + 1;
end;

Procedure AI_Line( msg: String; C: Byte );
	{ Draw a left justified message on the current line. }
begin
	GotoXY( ZX1 , CY );
	TextColor( C );
	Write( msg );
	CX := 1;
	Inc( CY );
end;

Procedure AI_PrintFromRight( msg: String; Tab,C: Byte );
	{ Draw a left justified message on the current line. }
begin
	GotoXY( Tab , CY );
	TextColor( C );
	Write( msg );
	CX := WhereX;
end;

Procedure AI_PrintFromLeft( msg: String; Tab,C: Byte );
	{ Draw a left justified message on the current line. }
var
	TP: Integer;
begin
	TP := Tab - Length( msg );
	if TP < 1 then TP := 1;
	GotoXY( TP , CY );
	TextColor( C );
	Write( msg );
	CX := WhereX;
end;

Procedure AI_PrintChar( msg: Char; C: Byte );
	{ Print a character on the current line, unless doing so would }
	{ cause the line to spread onto the next line. }
begin
	if WhereX < ( ZX2 - ZX1 - 1 ) then begin
		TextColor( C );
		Write( msg );
		CX := WhereX;
	end;
end;

Procedure AI_NextLine;
	{ Move the cursor to the next line. }
begin
	Inc( CY );
end;

Function StatusColor( Full , Current: LongInt ): Byte;
	{ Given a part's Full and Current hit ratings, decide on a good status color. }
begin
	if Full = Current then StatusColor := LightGreen
	else if Current > ( Full div 2 ) then StatusColor := Green
	else if Current > ( Full div 4 ) then StatusColor := Yellow
	else if Current > ( Full div 8 ) then StatusColor := LightRed
	else if Current > 0 then StatusColor := Red
	else StatusColor := DarkGray;
end;

Function EnduranceColor( Full , Current: LongInt ): Byte;
	{ Choose colour to show remaining endurance (Stamina or Mental points)}
begin
        { This is absolute rather than relative. }
	if Full = Current then EnduranceColor := LightGreen
	else if Current > 5 then EnduranceColor := Green
	else if Current > 0 then EnduranceColor := Yellow
	else EnduranceColor := LightRed;
end;

Function HitsColor( Part: GearPtr ): LongInt;
	{ Decide upon a nice color to represent the hits of this part. }
begin
	if PartActive( Part ) then
		HitsColor := StatusColor( GearMaxDamage( Part ) , GearCurrentDamage( Part ) )
	else
		HitsColor := StatusColor( 100 , 0 );
end;

Function ArmorColor( Part: GearPtr ): LongInt;
	{ Decide upon a nice color to represent the armor of this part. }
begin
	ArmorColor := StatusColor( MaxTArmor( Part ) , CurrentTArmor( Part ) );
end;

Function ArmorDamageColor( Part: GearPtr ): LongInt;
	{ Decide upon a nice color to represent the armor of this part. }
var
	MA,CA: LongInt;	{ Max Armor, Current Armor }
begin
	MA := MaxTArmor( Part );
	CA := CurrentTArmor( Part );

	if MA = 0 then begin
		ArmorDamageColor := Magenta;
	end else if ( CA >= ( MA * 3 div 4 ) ) then begin
		ArmorDamageColor := Black;
	end else if ( CA > MA div 4 ) then begin
		ArmorDamageColor := Blue;
	end else begin
		ArmorDamageColor := LightGray;
	end;
end;

Procedure ShowStatus( Part: GearPtr );
	{ Display all this part's status conditions. }
var
	T: LongInt;
begin
	{ Show the character's status conditions. }
	GotoXY( 2 , CY );

	{ Hunger and morale come first. }
	if Part^.G = GG_Character then begin
		T := NAttValue( Part^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
		if T > ( NumGearStats * 3 ) then begin
			AI_PrintChar( 'H' , LightRed );
		end else if T > ( NumGearStats * 2 ) then begin
			AI_PrintChar( 'H' , Yellow );
		end else if T > 0 then begin
			AI_PrintChar( 'H' , Green );
		end;

		T := NAttValue( Part^.NA , NAG_Condition , NAS_MoraleDamage );
		if T < -20 then begin
			AI_PrintChar( '+' , LightGreen );
		end else if T > ( 65 ) then begin
			AI_PrintChar( '-' , LightRed );
		end else if T > ( 40 ) then begin
			AI_PrintChar( '-' , Yellow );
		end else if T > 20 then begin
			AI_PrintChar( '-' , Green );
		end;

	end else if Part^.G = GG_Mecha then begin
		{ Mecha may be overloaded. }
		T := NAttValue( Part^.NA , NAG_Condition , NAS_Overload ) - OverloadCapacity( Part );
		if T > 10 then begin
			AI_PrintChar( 'O' , LightRed );
		end else if T > 0 then begin
			AI_PrintChar( 'O' , DarkGray );
		end;
	end;

	for t := 1 to Num_Status_FX do begin
		if NAttValue( Part^.NA , NAG_StatusEffect , T ) <> 0 then begin
			AI_PrintChar( SX_Char[ T ] , SX_Color[ T ] );
		end;
	end;

	if NAttValue( Part^.NA , NAG_EpisodeData , NAS_Ransacked ) = 1
	then AI_PrintChar( '$' , DarkGray );
end;

Procedure DisplayModules( Mek: GearPtr );
	{ Draw a lovely little diagram detailing this mek's modules. }
var
	MM,N,X0: Integer;
	MD: GearPtr;
	Flayed, Gutted : Boolean;
	Procedure AddPartsToDiagram( GS: Integer );
		{ Add parts to the status diagram whose gear S value }
		{ is equal to the provided number. }
	var
		X: Integer;
		FG, BG: Byte;
	begin
		MD := Mek^.SubCom;
		while ( MD <> Nil ) do begin
			if ( MD^.G = GG_Module ) and ( MD^.S = GS ) then begin

				FG := HitsColor( MD );
				BG := ArmorDamageColor( MD );
				
				if (FG = DarkGray) And (BG <> Black)
				    then FG := Black;

				if Flayed Or (Gutted And (GS = GS_Body)) 
				then begin
				    if Gutted
				    then FG := White
				    else FG := LightMagenta;
				    BG := Red;
				end;

				TextColor(FG);
				TextBackground(BG);

				if Odd( N ) then X := X0 - ( N div 2 ) - 1
				else X := X0 + ( N div 2 );
				Inc( N );
				GotoXY( X , CY );
				Case GS of
					GS_Head:	write('o');
					GS_Turret:	write('=');
					GS_Storage:	write('x');
					GS_Body:	begin
							write('B');
							end;
					GS_Arm:		write('+');
					GS_Wing:	write('W');
					GS_Tail:	write('t');
					GS_Leg:		write('l');
				end;
			end;
			MD := MD^.Next;
		end;
	end;

begin

	{ this "if" is just a shortcut }
	if GearOperational(Mek)
	then begin
	    Gutted := False;
	    Flayed := False;             
	end
	else begin
	    Gutted := (NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Gutted) = 1);
	    Flayed := (NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Flayed) = 1);
	end;

	{ Draw the status diagram for this mek. }
	{ Line One - Heads, Turrets, Storage }
	X0 := ( ZX2 - ZX1 ) div 2 + 2;
	MM := CY;	{ Save the CY value, since we want to print info }
			{ on these same three lines. }
	N := 0;
	AddPartsToDiagram( GS_Head );
	AddPartsToDiagram( GS_Turret );
	if N < 1 then N := 1;	{ Want storage to either side of body. }
	AddPartsToDiagram( GS_Storage );
	AI_NextLine;

	{ Line Two - Torso, Arms, Wings }
	N := 0;
	AddPartsToDiagram( GS_Body );
	AddPartsToDiagram( GS_Arm );
	AddPartsToDiagram( GS_Wing );
	AI_NextLine;

	{ Line Three - Tail, Legs }
	N := 0;
	AddPartsToDiagram( GS_Tail );
	if N < 1 then N := 1;	{ Want legs to either side of body; tail in middle. }
	AddPartsToDiagram( GS_Leg );
	AI_NextLine;

	{ Restore background color to black. }
	TextBackground( Black );

	{ Restore CY. }
	CY := MM;
end;

Procedure MekStatDisplay( Mek: GearPtr );
	{ Display the stats for MEK. }
	{ MEK absolutely must be a valid mecha; otherwise }
	{ there's gonna be a strange display. }
var
	msg: String;
	MM,N,A,B,CurM,MaxM: Integer;
	MD: GearPtr;
begin
	{ General mecha information - Name, mass, maneuver }
	AI_Title( GearName(Mek) , White );

	DisplayModules( Mek );

	AI_PrintFromRight( 'MV:' + SgnStr(MechaManeuver(Mek)) , ZX2 - ZX1 - 5 , LightGray );
	AI_NextLine;
	AI_PrintFromRight( 'TR:' + SgnStr(MechaTargeting(Mek)) , ZX2 - ZX1 - 5 , LightGray );
	AI_NextLine;
	AI_PrintFromRight( 'SE:' + SgnStr(MechaSensorRating(Mek)) , ZX2 - ZX1 - 5 , LightGray );
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
			N := LightRed;
		end else if ( A=0 ) or ( B=0 ) then begin
			N := Yellow;
		end else begin
			N := LightGray;
		end;

		AI_PrintFromRight( msg , 2 , N );

		AI_PrintFromLeft( BStr( GearCurrentDamage( MD ) ) + 'HP' , ZX2 - ZX1 - 1 , HitsColor( MD ) );
		AI_NextLine;
	end;

	AI_Title( MassString( Mek ) + ' ' + FormName[Mek^.S] + '  PV:' + BStr( GearValue( Mek ) ) , DarkGray );

	{ Movement information. }
	MM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	if MM > 0 then begin
		msg := MoveModeName[ MM ];
		msg := msg + ' (' + BStr( Speedometer( Mek ) ) + 'dpr)';
	end else msg := 'Immobile';
	AI_PrintFromRight( msg , ZX2 - ZX1 - 25 , DarkGray );

	{ Encumbrance information. }

	{ Get the current mass of carried equipment. }
	CurM := EquipmentMass( Mek );

	{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
	MaxM := ( GearEncumberance( Mek ) * 2 ) - 1;

	AI_PrintFromRight( 'Enc:' , ZX2 - ZX1 - 14 , NeutralGrey );
	AI_PrintFromRight( BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 't' , ZX2 - ZX1 - 9 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );

	AI_NextLine;
	ShowStatus( Mek );
end;

Procedure CharacterInfo( Part: GearPtr );
	{ This gear is a character. Print a list of stats and skills. }
var
	T,TT,Width,S,CurM,MaxM: Integer;
	C: Byte;
begin
	{ Show the character's name and health status. }
	AI_Title( GearName(Part) , White );

	DisplayModules( Part );

	AI_PrintFromLeft( BStr( GearCurrentDamage(Part)) + '/' + BStr( GearMaxDamage(Part)) , ZX2 - ZX1 - 2 , HitsColor( Part ) );
	AI_PrintFromLeft( 'HP' , ZX2 - ZX1 + 1 , LightGray );
	AI_NextLine;
	AI_PrintFromLeft( BStr( CharCurrentStamina(Part)) + '/' + BStr( CharStamina(Part)) , ZX2 - ZX1 - 2 , EnduranceColor( CharStamina(Part) , CharCurrentStamina(Part) ) );
	AI_PrintFromLeft( 'St' , ZX2 - ZX1 + 1 , LightGray );
	AI_NextLine;
	AI_PrintFromLeft( BStr( CharCurrentMental(Part)) + '/' + BStr( CharMental(Part)) , ZX2 - ZX1 - 2 , EnduranceColor( CharMental(Part) , CharCurrentMental(Part) ) );
	AI_PrintFromLeft( 'Me' , ZX2 - ZX1 + 1 , LightGray );
	AI_NextLine;

	{ Encumbrance information. }

	{ Get the current mass of carried equipment. }
	CurM := EquipmentMass( Part );

	{ Get the maximum mass that can be carried before encumbrance penalties are incurred. }
	MaxM := ( GearEncumberance( Part ) * 2 ) - 1;

	AI_PrintFromLeft( BStr( CurM div 2 ) + '.' + BStr( ( CurM mod 2 ) * 5 ) + '/' + BStr( ( MaxM ) div 2 ) + '.' + BStr( ( ( MaxM ) mod 2 ) * 5 ) + 'kg' , ZX2 - ZX1 - 2 , EnduranceColor( ( MaxM + 1  ) , ( MaxM + 1  ) - CurM ) );
	AI_PrintFromRight( 'Enc' , ZX2 - ZX1 - 1 , NeutralGrey );
	AI_NextLine;


	{ Determine the spacing for the character's stats. }
	Width := ( ZX2 - ZX1 ) div 4;

	{ Show the character's stats. }
	for t := 1 to ( NumGearStats div 4 ) do begin
		for tt := 1 to 4 do begin
			AI_PrintFromRight( StatName[ T * 4 + TT - 4 ][1] + StatName[ T * 4 + TT - 4 ][2] + ':' , ( TT-1 ) * Width + 1 , LightGray );

			{ Determine the stat value. This may be higher or lower than natural... }
			S := CStat( Part , T * 4 + TT - 4 );
			if S > Part^.Stat[ T * 4 + TT - 4 ] then C := LighTGreen
			else if S < Part^.Stat[ T * 4 + TT - 4 ] then C := LightRed
			else C := Green;
			AI_PrintFromLeft( BStr( S ) , ( TT - 1 ) * Width + 6 , C );
		end;
		AI_NextLine;
	end;

	ShowStatus( Part );
end;

Procedure MiscInfo( Part: GearPtr );
	{ Display info for any gear that doesn't have its own info }
	{ procedure. }
var
	N: LongInt;
	msg: String;
begin
	{ Show the part's name. }
	AI_Title( GearName(Part) , White );

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
	AI_PrintFromRight( msg + ' DP' , CX , HitsColor( Part ) );

	N := ( GearMass( Part ) + 1 ) div 2;
	if N > 0 then AI_PrintFromLeft( MassString( Part ) , ZX2 - ZX1 + 2 , LightGray );

	GameMsg( ExtendedDescription( Part ) , ZX1 , ZY1 + 3 , ZX2 , ZY2 , LightGray );
end;

Procedure SetInfoZone( X1,Y1,X2,Y2,BorColor: Byte );
	{ Copy the provided coordinates into this unit's global }
	{ variables, then draw a nice little border and clear the }
	{ selected area. }
begin
	{ Copy the dimensions provided into this unit's global variables. }
	ZX1 := X1 + 1;
	ZY1 := Y1 + 1;
	ZX2 := X2 - 1;
	ZY2 := Y2 - 1;

	DrawZoneBorder( X1 , Y1 , X2 , Y2 , BorColor );
	CX := 1;
	CY := 1;

	Window( ZX1 , ZY1 , ZX2 , ZY2 );
	ClrScr;
end;

Procedure MetaTerrainInfo( Part: GearPtr );
	{ Display info for any gear that doesn't have its own info }
	{ procedure. }
begin
	AI_Title( GearName(Part) , TerrainGreen );
end;

Procedure RepairFuelInfo( Part: GearPtr );
	{ Display info for any gear that doesn't have its own info }
	{ procedure. }
var
	N: Integer;
begin
	{ Show the part's name. }
	AI_Title( GearName(Part) , White );

	N := ( GearMass( Part ) + 1 ) div 2;
	if N > 0 then AI_PrintFromLeft( MassString( Part ) , ZX2 - ZX1 + 2 , LightGray );

	AI_NextLine;
	AI_Title( SkillMan[ Part^.S ].Name , Yellow );
	AI_Title( BStr( Part^.V ) + ' DP' , Green );
end;

Procedure GearInfo( Part: GearPtr; X1,Y1,X2,Y2,BorColor: Byte );
	{ Display some information for this gear inside the screen area }
	{ X1,Y1,X2,Y2. }
begin
	{ draw info window no larger than necessary }
	if Y2 - Y1 > 9 then Y2 := Y1 + 9;

	SetInfoZone( X1,Y1,X2,Y2,BorColor );

	{ Record this gear's address. }
	LastGearShown := Part;

	{ Error check }
	{ Note that we want the area cleared, even in case of an error. }
	if Part = Nil then exit;

	{ Depending upon PART's type, branch to an appropriate procedure. }
	case Part^.G of
		GG_Mecha:	MekStatDisplay( Part );
		GG_Character:	CharacterInfo( Part );
		GG_MetaTerrain:	MetaTerrainInfo( Part );
		GG_RepairFuel:	RepairFuelInfo( Part );
	else MiscInfo( Part );
	end;

	{ Restore the clip area to the full screen. }
	maxclipzone;
end;

Procedure LocationInfo( Part: GearPtr; gb: GameBoardPtr );
	{ Display location info for this part, if it is on the map. }
	{ This procedure is meant to be called after a GearInfo call, }
	{ since it assumes that ZX1,ZY1...etc will have been set up }
	{ properly beforehand. }
const
	OX = 3;
	OY = 2;
var
	D,Z: Integer;
begin
	{ Props are master gears, but they don't get location info. }
	if OnTheMap( Part ) and IsMasterGear( Part ) and ( Part^.G <> GG_Prop ) then begin
		{ Clear the compass area. }
		gotoXY( ZX1 + OX - 1 , ZY1 + OY - 1 );
		write( '   ' );
		gotoXY( ZX1 + OX - 1 , ZY1 + OY );
		write( '   ' );
		gotoXY( ZX1 + OX - 1 , ZY1 + OY + 1 );
		write( '   ' );

		D := NAttValue( Part^.NA , NAG_Location , NAS_D );
		Z := MekAltitude( gb , Part );
		if Z >= 0 then begin
			GotoXY( ZX1 + OX , ZY1 + OY );
			TextColor( NeutralGrey );
			Write( BStr ( Z ) );

		end else begin
			GotoXY( ZX1 + OX , ZY1 + OY );
			TextColor( PlayerBlue );
			Write( BStr ( Abs( Z ) ) );

		end;

		TextColor( White );
		GotoXY( ZX1 + OX + AngDir[D,1] , ZY1 + OY + AngDir[D,2] );
		Write( '+' );
		TextColor( DarkGray );
		GotoXY( ZX1 + OX - AngDir[D,1] , ZY1 + OY - AngDir[D,2] );
		Write( '=' );

		{ Speedometer. }
		if Speedometer( Part ) > 0 then begin
			GotoXY( ZX1 + OX - 3 , ZY1 + OY );
			if NAttValue( Part^.NA , NAG_Action , NAS_MoveAction ) = NAV_FullSPeed then begin
				TextColor( LightCyan );
			end else begin
				TextColor( Cyan );
			end;

			Write( 'G' );
			GotoXY( ZX1 + OX - 3 , ZY1 + OY + 1 );
			TextColor( DarkGray );
			Write( 'S' );
		end else begin
			GotoXY( ZX1 + OX - 3 , ZY1 + OY );
			TextColor( DarkGray );
			Write( 'G' );
			GotoXY( ZX1 + OX - 3 , ZY1 + OY + 1 );
			TextColor( Cyan );
			Write( 'S' );
		end;
	end;
end;

Procedure DisplayGearInfo( Part: GearPtr );
	{ Show some stats for whatever sort of thing PART is. }
begin
	{ All this procedure does is call the ArenaInfo unit procedure }
	{ with the dimensions of the Info Zone. }
	GearInfo( Part , ScreenZone[ ZONE_Info , 1 ] , ScreenZone[ ZONE_Info , 2 ] , ScreenZone[ ZONE_Info , 3 ] , ScreenZone[ ZONE_Info , 4 ] , NeutralGrey );
end;

Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr; Z: Integer );
	{ Show some stats for whatever sort of thing PART is. }
begin
	{ All this procedure does is call the ArenaInfo unit procedure }
	{ with the dimensions of the provided Zone. }
	GearInfo( Part , ScreenZone[ Z , 1 ] , ScreenZone[ Z , 2 ] , ScreenZone[ Z , 3 ] , ScreenZone[ Z , 4 ] , TeamColor( GB , Part ) );

	LocationInfo( Part , gb );
end;

Procedure DisplayGearInfo( Part: GearPtr; gb: GameBoardPtr );
	{ Show some stats for whatever sort of thing PART is. }
begin
	DisplayGearInfo( Part , GB , ZONE_Info );
end;

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

Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
	{ Show the needed information regarding this conversation. }
var
	msg: String;
	C: Byte;
	T: Integer;
begin
	ZX1 := ScreenZone[ ZONE_InteractStatus , 1 ];
	ZY1 := ScreenZone[ ZONE_InteractStatus , 2 ];
	ZX2 := ScreenZone[ ZONE_InteractStatus , 3 ];
	ZY2 := ScreenZone[ ZONE_InteractStatus , 4 ];
	CX := 1;
	CY := 1;
	Window( ZX1 , ZY1 , ZX2 , ZY2 );
	ClrScr;

	{ First the name, then the description. }
	AI_Title( GearName( NPC ) , InfoHiLight );

	AI_Title( JobAgeGenderDesc( NPC ) , InfoGreen );

	if React > 0 then begin
		msg := '';
		for T := 0 to ( React div 4 ) do msg := msg + '+';
		C := LightGreen;
	end else if React < 0 then begin
		msg := '';
		for T := 0 to ( Abs(React) div 4 ) do msg := msg + '-';
		C := LightRed;
	end else begin
		msg := '~~~';
		C := Yellow;
	end;
	AI_PrintFromRight( '[:)]' , 1 , Green );
	AI_PrintFromRight( msg , 5 , C );

	msg := '';
	if Endurance > 10 then Endurance := 10;
	for t := 1 to Endurance do msg := msg + '>';
	AI_PrintFromRight( '[Zz]' , ZX2 - ZX1 - 12 , Green );
	AI_PrintFromRight( msg , ZX2 - ZX1 - 8 , LightGreen );

	{ Restore the clip area to the full screen. }
	maxclipzone;
end;

Procedure QuickWeaponInfo( Part: GearPtr );
	{ Provide quick info for this weapon in the MENU1 zone. }
begin
	{ Error check }
	{ Note that we want the area cleared, even in case of an error. }
	if Part = Nil then exit;

	{ Display the weapon description. }
	GameMsg( GearName( Part ) + ' ' + WeaponDescription( Part ) , ZONE_Menu1 , InfoGreen );
end;

Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
	{ Display the important stats for this PC in the map zone. }
var
	msg: String;
	T,FID: Integer;
	S: LongInt;
	C: Byte;
	CY0,R: Integer;
	Mek: GearPtr;
begin
	{ Begin with one massive error check... }
	if PC = Nil then Exit;
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

	SetInfoZone( ScreenZone[ ZONE_Map , 1 ] - 1 , ScreenZone[ ZONE_Map , 2 ] - 1 , ScreenZone[ ZONE_Map , 3 ] + 1 , ScreenZone[ ZONE_Map , 4 ] + 1 , PlayerBlue );

	AI_Title( GearName( PC ) , White );
	AI_Title( JobAgeGenderDesc( PC ) , InfoGreen );
	AI_NextLine;

	{ Print the stats. }
	{ Save the CY value, since we'll want to come back and add more }
	{ info to the right side of the screen. }
	CY0 := CY;
	for t := 1 to NumGearStats do begin
		{ Find the adjusted stat value for this stat. }
		S := CStat( PC , T );
		R := ( S + 2 ) div 3;
		if R > 7 then R := 7;

		{ Determine an appropriate color for the stat, depending }
		{ on whether its adjusted value is higher or lower than }
		{ the basic value. }
		if S > PC^.Stat[ T ] then C := LighTGreen
		else if S < PC^.Stat[ T ] then C := LightRed
		else C := Green;

		{ Do the output. }
		AI_PrintFromRight( StatName[ T ] , 2 , LightGray );
		AI_PrintFromLeft( BStr( S ) , 15 , C );
		AI_PrintFromRight( MsgString( 'STATRANK' + BStr( R ) ) , 16 , C );

		AI_NextLine;
	end;

	{ Retsore CY. }
	CY := CY0;

	{ Calculate the mid point at which to print the second column. }
	T := ( ZX2 - ZX1 ) div 2 + 3;

	AI_PrintFromRight( MsgString( 'INFO_XP' ) , T , LightGray );
	S := NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP );
	AI_PrintFromLeft( BStr( S ) , ZX2 - ZX1 + 1 , Green );
	AI_NextLine;

	AI_PrintFromRight( MsgString( 'INFO_XPLeft' ) , T , LightGray );
	S := S - NAttVAlue( PC^.NA , NAG_Experience , NAS_SpentXP );
	AI_PrintFromLeft( BStr( S ) , ZX2 - ZX1 + 1 , Green );
	AI_NextLine;

	AI_PrintFromRight( MsgString( 'INFO_Credits' ) , T , LightGray );
	S := NAttVAlue( PC^.NA , NAG_Experience , NAS_Credits );
	AI_PrintFromLeft( '$' + BStr( S ) , ZX2 - ZX1 + 1 , Green );
	AI_NextLine;

	{ Print info on the PC's mecha, if appropriate. }
	if ( GB <> Nil ) then begin
		Mek := FindPilotsMecha( GB^.Meks , PC );
		if Mek <> Nil then begin
			AI_NextLine;
			AI_PrintFromRight( MsgString( 'INFO_MekSelect' ) , T , LightGray );
			AI_NextLine;

			msg := FullGearName( Mek );

			AI_PrintFromLeft( Msg , ZX2 - ZX1 + 1 , Green );
		end;
	end;

	{ Print info on the PC's faction, if appropriate. }
	FID := NAttValue( PC^.NA , NAG_Personal , NAS_FactionID );
	if ( FID <> 0 ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Mek := SeekFaction( GB^.Scene , FID );
		if Mek <> Nil then begin
			AI_NextLine;
			AI_PrintFromRight( MsgString( 'INFO_Faction' ) , T , LightGray );
			AI_NextLine;

			msg := GearName( Mek );

			AI_PrintFromLeft( Msg , ZX2 - ZX1 + 1 , Green );
		end;
	end;

	msg := SAttValue( PC^.SA , 'BIO1' );
	if msg <> '' then begin
		GameMsg( msg , ZONE_Biography , Green );
	end;

	{ Restore the display. }
	MaxClipZone;
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
var
	SP,MP,T: Integer;
begin
	{ Begin with one massive error check... }
	if PC = Nil then Exit;
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

	SetInfoZone( ScreenZone[ ZONE_Map , 1 ] - 1 , ScreenZone[ ZONE_Map , 2 ] - 1 , ScreenZone[ ZONE_Map , 3 ] + 1 , ScreenZone[ ZONE_Map , 4 ] + 1 , PlayerBlue );

	AI_Title( MsgString( 'INFO_InjuriesTitle' ) , White );

	{ Show exhaustion status first. }
	SP := CharCurrentStamina( PC );
	MP := CharCurrentMental( PC );
	if ( SP = 0 ) and ( MP = 0 ) then begin
		AI_PrintFromRight( MsgString( 'INFO_FullExhausted' ) , 2 , LightRed );
		AI_NextLine;
	end else if ( SP = 0 ) or ( MP = 0 ) then begin
		AI_PrintFromRight( MsgString( 'INFO_PartExhausted' ) , 2 , Yellow );
		AI_NextLine;
	end;

	{ Hunger next. }
	T := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
	if T > ( NumGearStats * 3 ) then begin
		AI_PrintFromRight( MsgString( 'INFO_ExtremeHunger' ) , 2 , LightRed );
		AI_NextLine;
	end else if T > ( NumGearStats * 2 ) then begin
		AI_PrintFromRight( MsgString( 'INFO_Hunger' ) , 2 , Yellow );
		AI_NextLine;
	end else if T > 0 then begin
		AI_PrintFromRight( MsgString( 'INFO_MildHunger' ) , 2 , Green );
		AI_NextLine;
	end;

	{ Low morale next. }
	T := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );
	if T > 65 then begin
		AI_PrintFromRight( MsgString( 'INFO_ExtremeMorale' ) , 2 , LightRed );
		AI_NextLine;
	end else if T > 40 then begin
		AI_PrintFromRight( MsgString( 'INFO_Morale' ) , 2 , Yellow );
		AI_NextLine;
	end else if T > 20 then begin
		AI_PrintFromRight( MsgString( 'INFO_MildMorale' ) , 2 , Green );
		AI_NextLine;
	end;


	for t := 1 to Num_Status_FX do begin
		if NAttValue( PC^.NA , NAG_StatusEffect , T ) <> 0 then begin
			AI_PrintFromRight( MsgString( 'INFO_Status' + BStr( T ) ) , 2 , LightRed );
			AI_NextLine;
		end;
	end;

	{ Show limb injuries. }
	ShowSubInjuries( PC^.SubCom );

	{ Restore the display. }
	MaxClipZone;
end;

Procedure MapEditInfo( Pen,Palette,X,Y: Integer );
	{ Show the needed info for the map editor- the current pen }
	{ terrain, the terrain palette, and the cursor position. }
begin
	GotoXY( ScreenZone[ ZONE_Info , 1 ] + 1 , ScreenZone[ ZONE_Info , 2 ] + 1 );
	TextBackground( Black );
	ClrEOL;
	TextColor( White );
	Write( '[' );
	TextColor( TerrColor[ Pen ] );
	Write( TerrGfx[ Pen ] );
	TextColor( White );
	Write( '] ' + TerrMan[ Pen ].Name );

	CMessage( BStr( X ) + ',' + BStr( Y ) , ZONE_Clock , White );
end;

end.
