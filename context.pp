unit context;
	{ This unit deals with text output & keyboard input. }
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

uses gears;

const
	Console_History_Length = 240;

var
	Text_Messages: SAttPtr;
	Console_History: SAttPtr;

Procedure WriteMBCharStr( const arg_msg: String; Xwidth: Integer );

Function RPGKey: Char;
Function DirKey: Integer;
Procedure EndOfGameMoreKey;
Procedure CMessage( const msg: String; Z: Integer; C: Byte );
Procedure GameMSG( msg: string; X1,Y1,X2,Y2,C: Byte ); {no const}
Procedure GameMSG( const msg: string; Z,C: Byte );
Procedure DialogMSG(msg: string); {no const}
Function GetStringFromUser( const Prompt: String ): String;
Function MsgString( const MsgLabel: String ): String;

Function MoreHighFirstLine( LList: SAttPtr ): Integer;
Procedure MoreText( LList: SAttPtr; FirstLine: Integer );

implementation

uses crt,termenc,texutil,ui4gh,congfx;

Procedure WriteMBCharStr( const arg_msg: String; Xwidth: Integer );
	{ NOTE: In CJK, there are many charctors, one charactor have double size for one ANK charactor and data length is 3 or 4 bytes. }
	{ NOTE: But, a function Write() clipped by data length. }
	{ NOTE: FPC's unicode functions is not stable, is its? }
const
	tmsgLen = 288; { 254; }

var
	msg: String;
	tmsg: Array[0..tmsgLen] of Char;
	pmsg, ptmsg: PChar;
	MaxLen: Integer;
	P, lastP: Integer;
	X, Y: Integer;
	Len: Integer;

begin
	if SYSTEM_CHARSET = TERMINAL_CHARSET then begin
		if TERMINAL_bidiRTL then begin
			msg := Conv_bidiRTL(arg_msg);
		end else begin
			msg := arg_msg;
		end;
	end else begin
		ptmsg := tmsg;
		if TERMINAL_bidiRTL then begin
			pmsg := QuickPCopy(Conv_bidiRTL(arg_msg));
		end else begin
			pmsg := QuickPCopy(arg_msg);
		end;
		Conv_ToTenc( pmsg, Length(arg_msg), ptmsg, tmsgLen );
		Dispose( pmsg );
		msg := StrPas( tmsg );
	end;

	MaxLen := Length(msg);
	P := 1;	lastP := 1;
	X := WhereX;	Y := WhereY;
	if TERMINAL_bidiRTL and (0 < Xwidth) then begin
		X := X + Xwidth - WidthMBCharStr(msg);
		if X < GOTOXY_MIN then begin
			X := GOTOXY_MIN;
		end;
		GotoXY(X,Y);
	end;

{$IF DEFINED(PASCAL_WRITE_BUG_HACK)}
	while (P <= MaxLen) do begin
		Len := LengthMBChar( msg[P], TENC );
		if 0 < Len then begin
			if Len <= 2 then begin
				{ BUG: Display width is mistook if use JISx0201-KANA. }
				P := P + Len;
				X := X + Len;
			end else begin
				Write(Copy(msg,lastP,P-lastP+len));
				P := P + Len;
				lastP := P;
				X := X + 2;
				GotoXY(X,Y+1);
				if (Y+1) <> WhereY then begin
					GotoXY(X,Y-1);
					if (Y-1) <> WhereY then begin
						GotoXY(X+2,Y);
					end;
				end;
				GotoXY(X,Y);
			end;
		end else begin
			Inc(P);
			Inc(X);
		end;
	end;
	if lastP < P then Write(Copy(msg,lastP,MaxLen-lastP+1));
{$ELSE PASCAL_WRITE_BUG_HACK}
	Write( msg );
{$ENDIF PASCAL_WRITE_BUG_HACK}
end;


Function RPGKey: Char;
	{Read a keypress from the keyboard. Convert it into a form}
	{that my other procedures would be willing to call useful.}
var
	rk,getit: Char;
begin
	RK := ReadKey;

	Case RK of
		#0: begin	{We have a two-part special key.}
			{Obtain the scan code.}
			getit := Readkey;
			case getit of
				#72: RK := KeyMap[ KMC_North ].KCode; {Up Cursor Key}
				#71: RK := KeyMap[ KMC_NorthWest ].KCode; {Home Cursor Key}
				#73: RK := KeyMap[ KMC_NorthEast ].KCode; {PageUp Cursor Key}
				#80: RK := KeyMap[ KMC_South ].KCode; {Down Cursor Key}
				#79: RK := KeyMap[ KMC_SouthWest ].KCode; {End Cursor Key}
				#81: RK := KeyMap[ KMC_SouthEast ].KCode; {PageDown Cursor Key}
				#75: RK := KeyMap[ KMC_West ].KCode; {Left Cursor Key}
				#77: RK := KeyMap[ KMC_East ].KCode; {Right Cursor Key}
			end;
		end;

		{Convert the Backspace character to ESCape.}
		#8: RK := #27;	{Backspace => ESC}

		{Normally, SPACE is the selection button, but ENTER should}
		{work as well. Therefore, convert all enter codes to spaces.}
		#10: RK := ' ';
		#13: RK := ' ';
	end;

	RPGKey := RK;
end;

Function DirKey: Integer;
	{ Get a direction selection from the user. If a standard direction }
	{ key was selected, return its direction (0 is East, increase }
	{ clockwise). See Locale.pp for details. }
	{ Return -1 if no good direction was chosen. }
var
	K: Char;
begin
	K := RPGKey;
	if K = KeyMap[ KMC_East ].KCode then begin
		DirKey := 0;
	end else if K = KeyMap[ KMC_SouthEast ].KCode then begin
		DirKey := 1;
	end else if K = KeyMap[ KMC_South ].KCode then begin
		DirKey := 2;
	end else if K = KeyMap[ KMC_SouthWest ].KCode then begin
		DirKey := 3;
	end else if K = KeyMap[ KMC_West ].KCode then begin
		DirKey := 4;
	end else if K = KeyMap[ KMC_NorthWest ].KCode then begin
		DirKey := 5;
	end else if K = KeyMap[ KMC_North ].KCode then begin
		DirKey := 6;
	end else if K = KeyMap[ KMC_NorthEast ].KCode then begin
		DirKey := 7;
	end else begin
		DirKey := -1;
	end;

end;

Procedure EndOfGameMoreKey;
	{ The end of the game has been reached. Wait for the user to }
	{ press either the space bar or the ESC key. }
var
	A: Char;
begin
	{ First, get rid of any pending keypresses. }
	while keypressed do readkey;

	{ Keep reading keypresses until either a space or an ESC is found. }
	repeat
		A := RPGKey;
	until ( A = ' ' ) or ( A = #27 );
end;

Procedure CMessage( const msg: String; Z: Integer; C: Byte );
	{ Display MSG centered in zone Z. }
var
	X,Y: Integer;
begin
	{ Figure out the coordinates for centered display. }
	X := ( ScreenZone[Z,3] + ScreenZone[Z,1] ) div 2 - ( WidthMBCharStr( msg ) div 2 ) + 1;
	Y := ( ScreenZone[Z,4] + ScreenZone[Z,2] ) div 2;

	{ Actually do the output. }
	ClrZone( Z );
	if X < 1 then X := 1;
	if Y < 1 then Y := 1;
	GotoXY( X , Y );
	TextColor( C );
	WriteMBCharStr(msg,0);
end;

Procedure GameMSG( msg: string; X1,Y1,X2,Y2,C: Byte );  {not const-able}
	{Prettyprint the string MSG with color C in screen zone Z.}
var
	Width: Integer;		{Our pixel width.}
	NextWord: String;
	THELine: String;	{The line under construction.}
	LC: Boolean;		{Loop Condition.}
	LW_I18N: Boolean;	{Is the last word I18N character?}
	CW_I18N: Boolean;	{Is the current word I18N character?}
	DItS: Boolean;		{Do insert the space, or not.}
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	TextColor( C );
	TextBackground( StdBlack );

	{Clear the message area, and set clipping bounds.}
	Window( X1 , Y1 , X2 , Y2 );
	ClrScr;

	{Calculate the width of the text area.}
	Width := X2 - X1;

	{THELine = The first word in this iteration}
	LW_I18N := False;
	THELine := ExtractWordForPrint( msg, DItS, CW_I18N );

	{Start the main processing loop.}
	while TheLine <> '' do begin
		{Set the LoopCondition to True.}
		LC := True;

		{ Start building the line. }
		repeat
			NextWord := ExtractWordForPrint( Msg, DItS, CW_I18N );

			if (False = LW_I18N) and (False = CW_I18N) then begin
				DItS := True;
			end;
			LW_I18N := CW_I18N;
			if DItS then begin
				if WidthMBCharStr(THEline + ' ') <= Width then begin
					THEline := THEline + ' ';
				end;
			end;
			if WidthMBCharStr(THEline + NextWord) <= Width then begin
				THEline := THEline + NextWord;
			end else begin
				LC := False;
			end;

		until (not LC) or (NextWord = '') or ( TheLine[Length(TheLine)] = #13 );

		{ If the line ended due to a line break, deal with it. }
		if ( TheLine[Length(TheLine)] = #13 ) then begin
			{ Display the line break as a space. }
			TheLine[Length(TheLine)] := ' ';
			NextWord := ExtractWordForPrint( msg, DItS, CW_I18N );
		end;

		{ Output the line. }
		if NextWord = '' then begin
			WriteMBCharStr(THELine,Width);
		end else begin
			WriteMBCharStr(THELine,Width);
			WriteLn;
		end;

		{ Prepare for the next iteration. }
		TheLine := NextWord;

	end; { while msg <> '' }

	{Restore the clip window to its maximum size.}
	MaxClipZone;
end;

Procedure GameMSG( const msg: string; Z,C: Byte );
	{ Print a message in zone Z. }
begin
	GameMSG( msg , ScreenZone[Z,1], ScreenZone[Z,2], ScreenZone[Z,3], ScreenZone[Z,4], C );
end;

Procedure DialogMSG(msg: string); {not const-able}
	{ Print a message in the scrolling dialog box. }
var
	Width: Integer;		{Our pixel width.}
	NextWord: String;
	THELine: String;	{The line under construction.}
	LC: Boolean;		{Loop Condition.}
	SA: SAttPtr;
	LW_I18N: Boolean;	{Is the last word I18N ?}
	CW_I18N: Boolean;	{Is the current word I18N ?}
	DItS: Boolean;		{Do insert the space, or not.}
	SL: SAttPtr;
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	TextColor( InfoGreen );
	TextBackground( StdBlack );
	msg := '> ' + msg;

	{Clear the message area, and set clipping bounds.}
	ClipZone( ZONE_Dialog );

	{Set initial cursor position.}
	GotoXY( 1 , ScreenZone[ZONE_Dialog,4] - ScreenZone[ZONE_Dialog,2] + 1 );

	{Calculate the width of the text area.}
	Width := ScreenZone[ZONE_Dialog,3] - ScreenZone[ZONE_Dialog,1];

	{THELine = The first word in this iteration}
	LW_I18N := False;
	THELine := ExtractWordForPrint( msg, DItS, CW_I18N );

	{Start the main processing loop.}
	while TheLine <> '' do begin
		{Set the LoopCondition to True.}
		LC := True;

		{ Start building the line. }
		repeat
			NextWord := ExtractWordForPrint( Msg, DItS, CW_I18N );

			if (False = LW_I18N) and (False = CW_I18N) then begin
				DItS := True;
			end;
			LW_I18N := CW_I18N;
			if DItS then begin
				if WidthMBCharStr(THEline + ' ') <= Width then begin
					THEline := THEline + ' ';
				end;
			end;
			if WidthMBCharStr(THEline + NextWord) <= Width then begin
				THEline := THEline + NextWord;
			end else begin
				LC := False;
			end;

		until (not LC) or (NextWord = '') or ( TheLine[Length(TheLine)] = #13 );

		{ If the line ended due to a line break, deal with it. }
		if ( TheLine[Length(TheLine)] = #13 ) then begin
			{ Display the line break as a space. }
			TheLine[Length(TheLine)] := ' ';
			NextWord := ExtractWordForPrint( msg, DItS, CW_I18N );
		end;

		{ Output the line. }
		if TheLine <> '' then begin
			if NumSAtts( Console_History ) >= Console_History_Length then begin
				SA := Console_History;
				RemoveSAtt( Console_History , SA );
			end;
			StoreSAtt( Console_History , TheLine );
		end;

		{ Prepare for the next iteration. }
		TheLine := NextWord;

	end; { while msg <> '' }

	{ NOTE: In CJK, there are many charctors, one charactor have double size for one ANK charactor and data length is 3 or 4 bytes. }
	{ NOTE: But, a function Writeln() fail scrolling these charactors. }
	{ NOTE: FPC's unicode functions is not stable, is its? }

	ClrZone( ZONE_Dialog );
	MaxClipZone;

	{ Restore the console display. }
	GotoXY( ScreenZone[ ZONE_Dialog , 1 ] , ScreenZone[ ZONE_Dialog , 2 ] -1 );
	TextColor( Green );
	SL := RetrieveSAtt( Console_History , NumSAtts( Console_History ) - ScreenRows + ScreenZone[ ZONE_Dialog , 2 ] );
	if SL = Nil then SL := Console_History;
	while SL <> Nil do begin
		writeln;
		WriteMBCharStr( SL^.Info, Width );
		SL := SL^.Next;
	end;
end;

Function GetStringFromUser( const Prompt: String ): String;
	{ Does what it says. }
var
	it: String;
	RK: Char;
	state: ShortInt = 0;
	mbchar_work: String = '';
	MaxInputWidth: Integer = 0;
	X: Integer;
begin
	DrawZoneBorder( ScreenZone[ ZONE_TextInput , 1 ] - 1 , ScreenZone[ ZONE_TextInput , 2 ] -1 , ScreenZone[ ZONE_TextInput , 3 ] + 1 , ScreenZone[ ZONE_TextInput , 4 ] + 1 , LightCyan );
	ClrZone( ZONE_TextInput );
	X := ( ScreenZone[ZONE_TextInput,3] + ScreenZone[ZONE_TextInput,1] ) div 2 - ( WidthMBCharStr( Prompt ) div 2 ) + 1;
	if X < GOTOXY_MIN then begin
		X := GOTOXY_MIN;
	end;
	GotoXY( X, ScreenZone[ ZONE_TextInput , 4 ] );
	TextColor( InfoGreen );
	WriteMBCharStr( Prompt, 0 );
	TextColor( InfoHilight );
	CursorOn;
	ClipZone( ZONE_TextInput );

	it := '';
	MaxInputWidth := ScreenZone[ ZONE_TextInput , 3 ] - ScreenZone[ ZONE_TextInput , 1 ];
	if 127 < MaxInputWidth then MaxInputWidth := 127;
	repeat
		if TERMINAL_bidiRTL then begin
			GotoXY( 1, 1 );
		end else begin
			GotoXY( 1 + WidthMBCharStr(it) , 1 );
		end;
		repeat
			RK := ReadKey;
			RK := EditMBCharStr( it, 127, MaxInputWidth, RK, NIL, state, mbchar_work );
		until not(RK = #255);
		GotoXY( 1 , 1 );
		ClrEOL;
		WriteMBCharStr( it, MaxInputWidth );
	until (RK = #10) or (RK = #13) or (RK = #27);

	CursorOff;
	ClrZone( ZONE_Map );
	MaxClipZone;

	GetStringFromUser := it;
end;

Function MsgString( const MsgLabel: String ): String;
	{ Return the standard message string which has the requested }
	{ label. }
begin
	MsgString := SAttValue( Text_Messages , MsgLabel );
end;

Function MoreHighFirstLine( LList: SAttPtr ): Integer;
	{ Determine the highest possible FirstLine value. }
var
	it: Integer;
begin
	it := NumSAtts( LList ) - ( ScreenRows - 3 );
	if it < 1 then it := 1;
	MoreHighFirstLine := it;
end;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer );
	{ Browse this text file across the majority of the screen. }
	{ Clear the screen upon exiting, though restoration of the }
	{ previous display is someone else's responsibility. }
	Procedure DisplayTextHere;
	var
		CLine: SAttPtr;	{ Current Line }
		trimedlength: integer;
	begin
		{ Error check. }
		if FirstLine < 1 then FirstLine := 1
		else if FirstLine > MoreHighFirstLine( LList ) then FirstLine := MoreHighFirstLine( LList );
		GotoXY( 1 , 1 );

		CLine := RetrieveSATt( LList , FirstLine );
		while ( WhereY < ( ScreenRows - 1 ) ) do begin
			ClrEOL;
			if CLine <> Nil then begin
				trimedlength := MBCharTrimedLength( CLine^.Info, ScreenColumns - 2 );
				if (0 < trimedlength) then begin
					WriteMBCharStr( Copy(CLine^.Info,1,trimedlength), ScreenColumns );
				end;
				WriteLn;
				CLine := CLine^.Next;
			end else begin
				writeln;
			end;
		end;
	end;
var
	A: Char;
begin
	ClrScr;
	GotoXY( 1 , ScreenROws );
	TextColor( LightGreen );
	TextBackground( Black );
	WriteMBCharStr( MsgString( 'MORETEXT_Prompt' ), ScreenColumns );

	{ Display the screen. }
	TextColor( LightGray );
	DisplayTextHere;

	repeat
		{ Get input from user. }
		A := RPGKey;

		{ Possibly process this input. }
		if A = KeyMap[ KMC_South ].KCode then begin
			Inc( FirstLine );
			DisplayTextHere;
		end else if A = KeyMap[ KMC_North ].KCode then begin
			Dec( FirstLine );
			DisplayTextHere;
		end;

	until ( A = #27 ) or ( A = 'Q' );

	{ CLear the display area. }
	ClrScr;
end;

initialization
	Text_Messages := LoadStringList( Standard_Message_File );
	Console_History := Nil;

finalization
	DisposeSAtt( Text_Messages );
	DisposeSAtt( Console_History );

end.
