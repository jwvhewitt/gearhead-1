unit ConGfx;
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

uses crt;

const

{ For the purpose of making things easy on me, the }
{ screen is divided into several zones. }
	NumZones = 30;
	ZONE_Map = 1;
	ZONE_Clock = 2;
	ZONE_Info = 3;
	ZONE_Menu = 4;
	ZONE_Menu1 = 5;
	ZONE_Menu2 = 6;
	ZONE_Dialog = 7;
	ZONE_HQPilots = 8;
	ZONE_HQMecha = 9;
	ZONE_CharGenMenu = 10;
	ZONE_CharGenDesc = 11;
	ZONE_InteractStatus = 12;
	ZONE_InteractMenu = 13;
	ZONE_InteractMsg = 14;
	ZONE_InteractTotal = 15;

	ZONE_TextInput = 16;
	ZONE_EqpMenu = 17;
	ZONE_InvMenu = 18;
	ZONE_CharGenPrompt = 19;
	ZONE_Biography = 20;

	ZONE_SkillGenMenu = 21;
	ZONE_SkillGenDesc = 22;
	ZONE_SubInfo = 23;
	ZONE_Factory_Caption = 24;
	ZONE_Factory_Parts = 25;

	ZONE_YesNoTotal = 26;
	ZONE_YesNoPrompt = 27;
	ZONE_YesNoMenu = 28;
	ZONE_UsagePrompt = 29;
	ZONE_UsageMenu = 30;

	ZONE_MemoText = 27;
	ZONE_MemoMenu = 28;

	ScreenZone: Array [1..NumZones , 1..4] of Integer = (
	(   2 ,   2  ,  -32 , -6 ),
	(  -30 , -5  ,  -1 , -5 ),
	(  -30 ,   1  ,  -1 , 10 ),
	(  -30 ,  11  ,  -1 , -6 ),
	(  -30 ,  11  ,  -1 , 13 ),

	(  -30 ,  14  ,  -1 , -6 ),
	(   1 , -4  ,  -1 , 0 ),
	(   3 ,   3  ,   -62 , -6 ),
	(  -60 ,   3  ,  -32 , -6 ),
	(  -29 ,   4  ,  -2 , 0 ),

	(   2 , -4  ,  -32 , 0 ),
	(   2 ,   2  ,   46 ,  5 ),
	(   2 ,  13  ,  46 , 19 ),
	(   2 ,  6  ,  46 , 12 ),
	(   1 ,   1  ,  47 , 20 ),

	(   -71 ,  -15  ,  -40 , -12 ),
	(   4 ,   3  ,  44 , 7 ),
	(   4 ,  9  ,  44 , 18 ),
	(  -28 ,   2  ,  -3 , 2 ),
	(   4 ,   -10  , -34 , -6 ),

	(  -29 ,   -21  ,  -2 , -10 ),
	(  -28 ,   -7  ,  -3 , -2 ),
	(  -29 ,   2  ,  -2 , 9 ),
	(   2 ,   2  ,  -32 , -20 ),
	(   2 ,   -18 ,  -32 , -6 ),

	(   -69 ,   -21  ,  -37 , -9 ),
	(   -68 ,   -20  ,  -38 , -13 ),
	(   -68 ,   -11  ,  -38 , -10 ),
	(   -68 ,   -20  ,  -38 , -17 ),
	(   -68 ,   -15  ,  -38 , -10 )

	);

{ *** STANDARD COLORS *** }
	StdBlack: Byte = Black;
	StdWhite: Byte = White;
	MenuItem: Byte = Cyan;
	MenuSelect: Byte = LightCyan;
	TerrainGreen: Byte = Green;
	PlayerBlue: Byte = LightBlue;
	AllyPurple: Byte = LightMagenta;
	EnemyRed: Byte = Red;
	NeutralGrey: Byte = LightGray;
	InfoGreen: Byte = Green;
	InfoHiLight: Byte = LightGreen;
	TextboxGrey: Byte = DarkGray;
	AttackColor: Byte = LightRed;
	NeutralBrown: Byte = Yellow;
	BorderBlue: Byte = Blue;


Procedure ClipZone( ZoneNumber: Integer );
Procedure MaxClipZone;
Procedure ClrZone( ZoneNumber: Integer );
Procedure ClrScreen;
Procedure DrawZoneBorder( X1, Y1, X2, Y2, Color: Byte );
Procedure DrawZoneBorder( Z: Integer; C: Byte );
Procedure DrawExtBorder( Z: Integer; C: Byte );
Procedure DrawMapBorder( N,E,S,W: Boolean );

Procedure DrawBPBorder;
Procedure DrawCharGenBorder;
Procedure SetupCombatDisplay;
Procedure SetupHQDisplay;
Procedure SetupFactoryDisplay;
Procedure SetupYesNoDisplay;
Procedure SetupMemoDisplay;
Procedure SetupInteractDisplay( TeamColor: Byte );

implementation

uses ui4gh;

{$I boxdraw.inc}

Procedure ClipZone( ZoneNumber: Integer );
	{ Set the clipping bounds to this defined zone. }
begin
	Window( ScreenZone[ZoneNumber,1] , ScreenZone[ZoneNumber,2] , ScreenZone[ZoneNumber,3] , ScreenZone[ZoneNumber,4] );
end;

Procedure MaxClipZone;
	{ Restore the clip area to the maximum possible area. }
begin
	Window( 1 , 1 , ScreenColumns , ScreenRows );
end;

Procedure ClrZone( ZoneNumber: Integer );
	{ Clear the specified screen zone. }
begin
	ClipZone( ZoneNumber );
	TextBackground( Black );
	ClrScr;
	MaxClipZone;
end;

Procedure ClrScreen;
	{ Clear the entire screen. }
begin
	TextBackground( Black );
	MaxClipZone;
	ClrScr;
end;

Procedure DrawZoneBorder( X1, Y1, X2, Y2, Color: Byte );
	{ Do a lovely box in the specified color around the specified zone. }
var
	t: integer;		{a counter, of the house of CBM.}
begin
	{Set the color for the box.}
	TextColor(Color);
	TextBackground( Black );

{$IFDEF NeedShifts}
	ShiftAltCharset;
{$ENDIF}

	{Print the four corners.}
	GotoXY(X1,Y1);
	write(BoxUpperLeft);
	GotoXY(X2,Y1);
	write(BoxUpperRight);
	GotoXY(X1,Y2);
	write(BoxLowerLeft);
	GotoXY(X2,Y2);
	write(BoxLowerRight);

	{Print the two horizontal edges.}
	for t := X1+1 to X2-1 do begin
		GotoXY(t,Y1);
		write(BoxHorizontal);
		GotoXY(t,Y2);
		write(BoxHorizontal);
	end;

	{Print the two vertical edges.}
	for t := Y1+1 to Y2-1 do begin
		GotoXY(X1,t);
		write(BoxVertical);
		GotoXY(X2,t);
		write(BoxVertical);
	end;

{$IFDEF NeedShifts}
	ShiftNormalCharset;
{$ENDIF}

end;

Procedure DrawZoneBorder( Z: Integer; C: Byte );
	{ Do a box around this zone. }
begin
	DrawZoneBorder( ScreenZone[Z,1], ScreenZone[Z,2], ScreenZone[Z,3], ScreenZone[Z,4], C );
end;

Procedure DrawExtBorder( Z: Integer; C: Byte );
	{ Do a box around this zone. }
begin
	DrawZoneBorder( ScreenZone[Z,1] - 1, ScreenZone[Z,2] - 1, ScreenZone[Z,3] + 1, ScreenZone[Z,4] + 1, C );
end;

Procedure DrawMapBorder( N,E,S,W: Boolean );
	{ Draw a box one character outside of the map zone. }
	{ If any of the directions are set to TRUE, print a "MORE" }
	{ prompt along that side. }
var
	T: Integer;
begin
	{ Start by drawing the border itself. }
	DrawZoneBorder( ScreenZone[ ZONE_Map , 1 ] - 1 , ScreenZone[ ZONE_Map , 2 ] - 1 , ScreenZone[ ZONE_Map , 3 ] + 1 , ScreenZone[ ZONE_Map , 4 ] + 1 , Cyan );

	{ Draw "MORE"s as appropriate. }
	If N then begin
		GotoXY( ( ScreenZone[ ZONE_Map , 1 ] + ScreenZone[ ZONE_Map , 3 ] ) div 2 - 2 , ScreenZone[ ZONE_Map , 2 ] - 1 );
		Write( '+++++' );
	end;
	If S then begin
		GotoXY( ( ScreenZone[ ZONE_Map , 1 ] + ScreenZone[ ZONE_Map , 3 ] ) div 2 - 2 , ScreenZone[ ZONE_Map , 4 ] + 1 );
		Write( '+++++' );
	end;
	If W then begin
		for t := 1 to 4 do begin
			GotoXY( ScreenZone[ ZONE_Map , 1 ] - 1 , ( ScreenZone[ ZONE_Map , 2 ] + ScreenZone[ ZONE_Map , 4 ] ) div 2 - 2 + T );
			Write( '+' );
		end;
	end;
	If E then begin
		for t := 1 to 4 do begin
			GotoXY( ScreenZone[ ZONE_Map , 3 ] + 1 , ( ScreenZone[ ZONE_Map , 2 ] + ScreenZone[ ZONE_Map , 4 ] ) div 2 - 2 + T );
			Write( '+' );
		end;
	end;
end;

Procedure DrawBPBorder;
	{ Do the border for the BackPack routines. }
var
	T: Integer;
begin
	DrawZoneBorder( ScreenZone[ ZONE_EqpMenu , 1 ] - 1 , ScreenZone[ ZONE_EqpMenu , 2 ] - 1 , ScreenZone[ ZONE_InvMenu , 3 ] + 1 , ScreenZone[ ZONE_InvMenu , 4 ] + 1 , White );
	GotoXY( ScreenZone[ ZONE_EqpMenu , 1 ] , ScreenZone[ ZONE_EqpMenu , 4 ] + 1 );
{$IFDEF NeedShifts}
	ShiftAltCharset;
{$ENDIF}
	for t := 1 to (ScreenZone[ ZONE_EqpMenu , 3 ] - ScreenZone[ ZONE_EqpMenu , 1 ] + 1 ) do
		write(BoxSeperator);
{$IFDEF NeedShifts}
	ShiftNormalCharset;
{$ENDIF}

end;

Procedure DrawCharGenBorder;
	{ Do the border for the character generator routines. }
begin
	DrawZoneBorder( ScreenZone[ ZONE_Map , 1 ] - 1 , ScreenZone[ ZONE_Map , 2 ] - 1 , ScreenZone[ ZONE_Map , 3 ] + 1 , ScreenZone[ ZONE_Map , 4 ] + 1 , PlayerBlue );
	DrawZoneBorder( ScreenZone[ ZONE_CharGenPrompt , 1 ] - 1 , ScreenZone[ ZONE_CharGenPrompt , 2 ] - 1 , ScreenZone[ ZONE_CharGenPrompt , 3 ] + 1 , ScreenZone[ ZONE_CharGenPrompt , 4 ] + 1 , Blue );
end;


Procedure SetupCombatDisplay;
	{ Clear the screen & draw boxes. }
begin
	ClrScr;
end;

Procedure SetupHQDisplay;
	{ CLear the screen & draw boxes. }
begin
	ClrScr;
end;


Procedure SetupFactoryDisplay;
	{ CLear the screen & draw boxes. }
begin
	ClrScr;
	DrawExtBorder( ZONE_Factory_Parts , LightGray );
	DrawExtBorder( ZONE_Factory_Caption , White );
end;

Procedure SetupYesNoDisplay;
	{ Set up the display for the YesNo box. }
var
	T: Integer;
begin
	ClrZone( ZONE_YesNoTotal );
	DrawZoneBorder( ZONE_YesNoTotal  , LightBlue );
	GotoXY( ScreenZone[ ZONE_YesNoMenu , 1 ] , ScreenZone[ ZONE_YesNoMenu , 2 ] - 1 );
{$IFDEF NeedShifts}
	ShiftAltCharset;
{$ENDIF}
	for t := 1 to (ScreenZone[ ZONE_YesNoMenu , 3 ] - ScreenZone[ ZONE_YesNoMenu , 1 ] + 1 ) do
		write(BoxSeperator);
{$IFDEF NeedShifts}
	ShiftNormalCharset;
{$ENDIF}
end;

Procedure SetupMemoDisplay;
	{ Draw a nice border and some instructions for the memo display. }
var
	T: Integer;
begin
	ClrZone( ZONE_YesNoTotal );
	DrawZoneBorder( ZONE_YesNoTotal  , LightMagenta );
	GotoXY( ScreenZone[ ZONE_YesNoMenu , 1 ] , ScreenZone[ ZONE_YesNoMenu , 2 ] - 1 );
{$IFDEF NeedShifts}
	ShiftAltCharset;
{$ENDIF}
	for t := 1 to (ScreenZone[ ZONE_YesNoMenu , 3 ] - ScreenZone[ ZONE_YesNoMenu , 1 ] + 1 ) do
		write(BoxSeperator);
{$IFDEF NeedShifts}
	ShiftNormalCharset;
{$ENDIF}
end;

Procedure SetupInteractDisplay( TeamColor: Byte );
	{ Draw the display for the interaction interface. }
begin
	ClrZone( ZONE_InteractTotal );
	DrawZoneBorder( ZONE_InteractTotal , TeamColor );
end;


Procedure AnchorEdge(var value: Integer; limit: Integer);
begin
      if value < 1 then value := limit + value;
end;

Procedure CheckDimensions;
	{ If the screen dimensions have been redefined, we'll need to alter }
	{ the dimensions of the screen zones. }
var
	t, uRows, uCols, iRowOff, iColOff: Integer;
begin

	if ScreenRows > 57 then uRows := 57 else uRows := ScreenRows;
	if ScreenColumns > 83 then uCols := 83 else uCols := ScreenColumns;

	iRowOff := (uRows - 25) div 2;
	iColOff := (uCols - 78) div 2;

	for t := 1 to NumZones do begin
	    case t of
	      ZONE_InteractStatus, ZONE_InteractMenu, 
	      ZONE_InteractMsg, ZONE_InteractTotal,
	      ZONE_InvMenu, ZONE_EqpMenu:
		  begin
		      { Center the interaction and inventory windows within
			the map window }
		      ScreenZone[t,1] := ScreenZone[t,1] + iColOff;
		      ScreenZone[t,2] := ScreenZone[t,2] + iRowOff;
		      ScreenZone[t,3] := ScreenZone[t,3] + iColOff;
		      ScreenZone[t,4] := ScreenZone[t,4] + iRowOff;
		  end;
	      ZONE_Dialog:
		  begin 
		      { The dialog window recieves any slop lines at the
			bottom of the screen }
		      AnchorEdge(ScreenZone[t,1],uCols);
		      AnchorEdge(ScreenZone[t,2],uRows);
		      AnchorEdge(ScreenZone[t,3],uCols);
		      ScreenZone[t,4] := ScreenRows;
		  end;
	      else 
		  begin
		      { Normal zone anchoring. Most zone corners are 
			specified relative to edges of an screen area
			which ranges from 80x25 to 83x57 depending on the 
			underlying terminal support.} 
		      AnchorEdge(ScreenZone[t,1],uCols);
		      AnchorEdge(ScreenZone[t,2],uRows);
		      AnchorEdge(ScreenZone[t,3],uCols);
		      AnchorEdge(ScreenZone[t,4],uRows);
		  end;
	      end;
	end;
end;

initialization
	CursorOff; {LINUX ALERT... Maybe also doesn't work on Win2000}
	ClrScr;
	CheckDimensions;

finalization
{$IFNDEF DEBUG}
	NormVideo;
	ClrScr;
{$ENDIF}
	CursorOn;
end.
