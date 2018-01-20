unit texutil;
	{This unit contains various useful functions for dealing}
	{with strings.}
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

Procedure DeleteWhiteSpace(var S: String);
Procedure DeleteFirstChar(var S: String);
Function ExtractWord(var S: String): String;
Function ExtractValue(var S: String): LongInt;
Function RetrieveAString(const S: String): String;
Function RetrieveBracketString(const S: String): String;
Function RetrieveAPreamble(const S: String ): String;

Function BStr( N: LongInt ): String;
Function SgnStr( N: Integer ): String;
Function WideStr( N,Width: Integer ): String;

Function Acronym( phrase: String ): String; {can't const}
Function Acronym( const phrase: String ; NumPlaces: Byte ): String;
Function Concentrate( const S: String ): String;

Function Sgn( N: LongInt ): Integer;
Function PartMatchesCriteria( const Part_In,Desc_In: String ): Boolean;

Function AStringHasBString( const A,B: String ): Boolean;
Function HeadMatchesString( const H,S: String ): Boolean;

Function QuickPCopy( const msg: String ): PChar;

Function IsPunctuation( C: Char ): Boolean;

Procedure ReplacePat( var msg: String; const pat_in,s: String );
Function ReplaceHash( const msg, s: String ): String;

Procedure SanitizeFilename( var S: String );


implementation

uses strings;

Procedure DeleteWhiteSpace(var S: String);
	{Delete any whitespace which is at the beginning of}
	{string S. If S is nothing but whitespace, or if it}
	{contains nothing, return an empty string.}
	{ BUGS - None detected. Test harnessed and everything.}
var
	P: Integer;
begin
	{ Error check }
	if S = '' then Exit;

	{Locate the first relevant char.}
	P := 1;
	while (P < Length(S)) and ((S[P] = ' ') or (S[P] = #9)) do begin
		Inc(P);
	end;

	{Copy the string from the first nonspace to the end.}
	if (S[P] = ' ') or (S[P] = #9) then S := ''
	else S := Copy(S,P,Length(S));
end;

Procedure DeleteFirstChar(var S: String);
	{ Remove the first character from string S. }
begin
	{Copy the string from the first nonspace to the end.}
	if Length( S ) < 2 then S := ''
	else S := Copy(S,2,Length(S));
end;

Function ExtractWord(var S: String): String;
	{Extract the next word from string S.}
	{Return this substring as the function's result;}
	{truncate S so that it is now the remainder of the string.}
	{If there is no word to extract, both S and the function}
	{result will be set to empty strings.}
	{ BUGS - None found.}
var
	P: Integer;
	it: String;
begin
	{To start the process, strip all whitespace from the}
	{beginning of the string.}
	DeleteWhiteSpace(S);

	{Error check- make sure that we have something left to}
	{extract! The string could have been nothing but white space.}
	if S <> '' then begin

		{Determine the position of the next whitespace.}
		P := Pos(' ',S);
		if P = 0 then P := Pos(#9,S);

		{Extract the command.}
		if P <> 0 then begin
			it := Copy(S,1,P-1);
			S := Copy(S,P,Length(S));
		end else begin
			it := Copy(S,1,Length(S));
			S := '';
		end;

	end else begin
		it := '';
	end;

	ExtractWord := it;
end;

Function ExtractValue(var S: String): LongInt;
	{This is similar to the above procedure, but}
	{instead of a word it extracts a numeric value.}
	{Return 0 if the extraction should fail for any reason.}
var
	S2: String;
	it,C: LongInt;
begin
	S2 := ExtractWord(S);
	Val(S2,it,C);
	if C <> 0 then it := 0;
	ExtractValue := it;
end;

Function RetrieveAString(const S: String): String;
	{Retrieve an Alligator String from S.}
	{Alligator Strings are defined as the part of the string}
	{that both alligarors want to eat, i.e. between < and >.}
var
	A1,A2: Integer;
begin
	{Locate the position of the two alligators.}
	A1 := Pos('<',S);
	A2 := Pos('>',S);

	{If the string has not been declared with <, return}
	{an empty string.}
	if A1 = 0 then Exit('');

	{If the string has not been closed with >, return the}
	{entire remaining length of the string.}
	if A2 = 0 then A2 := Length(S)+1;

	RetrieveAString := Copy(S,A1+1,A2-A1-1);
end;

Function RetrieveBracketString(const S: String): String;
	{ Like the above, but the string is surrounded by ( and ) . }
var
	A1,A2: Integer;
begin
	{Locate the position of the two alligators.}
	A1 := Pos('(',S);
	A2 := Pos(')',S);

	{If the string has not been declared with <, return}
	{an empty string.}
	if A1 = 0 then Exit('');

	{If the string has not been closed with >, return the}
	{entire remaining length of the string.}
	if A2 = 0 then A2 := Length(S)+1;

	RetrieveBracketString := Copy(S,A1+1,A2-A1-1);
end;


Function RetrieveAPreamble( const S: String ): String;
	{ Usually an alligator string will have some kind of label in }
	{ front of it. This function will retrieve the label in its }
	{ entirety. }
	{ LIMITATION: Doesn't return the character immediately before }
	{ the AString, which should be a space. }
var
	A1: Integer;
	msg: String;
begin
	A1 := Pos('<',S);

	if A1 <> 0 then begin
		msg := Copy(S, 1 , A1-2);
	end else begin
		msg := '';
	end;

	RetrieveAPreamble := msg;
end;

Function BStr( N: LongInt ): String;
	{ This function functions as the BASIC Str function. }
var
	it: String;
begin
	Str(N, it);
	BStr := it;
end;

Function SgnStr( N: Integer ): String;
	{ Convert the string to a number, including either a '+' or '-'. }
var
	it: String;
begin
	it := BStr( N );
	if N>= 0 then it := '+' + it;
	SgnStr := it;
end;

Function WideStr( N,Width: Integer ): String;
	{ Pack the string with zeroes until it's the specified width. }
	{ This command is being used for my clock. }
var
	msg: String;
begin
	msg := BStr( Abs( N ) );
	while Length( msg ) < Width do msg := '0' + msg;
	if N < 0 then msg := '-' + msg;
	WideStr := msg;
end;

function IsAlpha( C: Char ): Boolean;
	{ Return TRUE if C is a letter, FALSE otherwise. }
begin
	if ( UpCase( C ) >= 'A' ) and ( UpCase( C ) <= 'Z' ) then IsAlpha := True
	else IsAlpha := False;
end;

Function Acronym( phrase: String ): String; {can't const}
	{ Copy all the capital letters from the PHRASE, and construct an acronym. }
var
	A: String;	{ A String. In honor of the C64. }
	T: Integer;	{ A loop counter. In honor of the C64. }
begin
	A := '';

	for t := 1 to Length( phrase ) do begin
		if ( phrase[T] = UpCase( phrase[T] ) ) and IsAlpha( phrase[T] ) then A := A + phrase[T];
	end;

	Acronym := A;
end;

Function Acronym( const phrase: String ; NumPlaces: Byte ): String; 
	{ This function works like the above one, but pad out the acronym to }
	{ NumPlaces characters. }
var
	A: String;
begin
	A := Acronym( phrase );

	if Length( A ) > NumPlaces then begin
		A := Copy( A , 1 , NumPlaces );
	end else if Length( A ) < NumPlaces then begin
		while Length( A ) < NumPlaces do A := A + ' ';
	end;

	Acronym := A;
end;

Function Concentrate( const S: String ): String;
	{ Remove all white space from this string, leaving nothing }
	{ but concentrated alphanumeric goodness. }
var
	T: Integer;
	CS: String;
begin
	CS := '';
	for T := 1 to Length( S ) do begin
		{ If this character is neither a space nor a tab, }
		{ add it to our concentrated string. }
		if (S[T] <> ' ') and (S[T] = #9) then CS := CS + S[T];
	end;
	Concentrate := CS;
end;

Function Sgn( N: LongInt ): Integer;
	{ Return the sign of this number, just like in BASIC. }
begin
	if N > 0 then Sgn := 1
	else if N < 0 then Sgn := -1
	else Sgn := 0;
end;

Function PartMatchesCriteria( const Part_In,Desc_In: String ): Boolean;
	{ Return TRUE if the provided part description matches the provided }
	{ search criteria. Return FALSE otherwise. }
	{ A match is had if all the words in DESC are found in PART. }
var
	Trait: String;
	it: Boolean;
        Part, Desc: String;
begin
	Part := UpCase( Part_In );
	Desc := UpCase( Desc_In );

	{ Assume TRUE unless a trait is found that isn't in NDesc. }
	it := True;

	DeleteWhiteSpace( Desc );

	while Desc <> '' do begin
		Trait := ExtractWord( Desc );
		if Pos( Trait , Part ) = 0 then it := False;
	end;

	PartMatchesCriteria := it;
end;

Function AStringHasBString( const A,B: String ): Boolean;
	{ Return TRUE if B is contained in A, FALSE otherwise. }
begin
	AStringHasBString := Pos( UpCase( B ) , UpCase( A ) ) > 0;
end;

Function HeadMatchesString( const H,S: String ): Boolean;
	{ Return TRUE if the beginning characters of S are H. }
var
	T : String;
begin
	T := Copy( S , 1 , Length( H ) );
	HeadMatchesString := UpCase( T ) = UpCase( H );
end;

Function QuickPCopy( const msg: String ): PChar;
	{ Life is short. Copy msg to a pchar without giving me any attitude about it. }
	{ Remember to deallocate that sucker when you're done playing with it. }
var
	pmsg: PChar;
begin
	pmsg := StrAlloc( length(msg ) + 1 );
	StrPCopy( pmsg , msg );
	QuickPCopy := pmsg;
end;

Function IsPunctuation( C: Char ): Boolean;
	{ Return TRUE if C is some kind of punctuation, or FALSE otherwise. }
	{ This is used for the message scripting commands so please }
	{ forgive me if my definition of punctuation in this function }
	{ is not the same as my own. }
begin
	case C of
		'.',',',':',';','@','!','/','?','''': IsPunctuation := True;
		else IsPunctuation := False;
	end;
end;

Procedure ReplacePat( var msg: String; const pat_in,s: String );
	{ Replace all instances of PAT in MSG with S. }
var
	N: Integer;
	pat: String;
begin
	pat := UpCase( pat_in);
	repeat
		N := Pos( pat , UpCase( msg ) );
		if N <> 0 then begin
			msg := Copy( msg , 1 , N - 1 ) + S + Copy( msg , N + Length( pat ) , 255 );
		end;
	until N = 0;
end;

Function ReplaceHash( const msg,s: String ): String;
	{ Look for a hash sign in MSG. Replace it with S. }
var
	N: Integer;
        msg_out: String;
begin
	N := Pos( '#' , msg );
	if N <> 0 then begin
		msg_out := Copy( msg , 1 , N - 1 ) + S + Copy( msg , N + 1 , 255 );
	end else begin
                msg_out := msg;
	end;
	ReplaceHash := msg_out;
end;

Procedure SanitizeFilename( var S: String );
	{ Replace all proscribed characters with an underscore. }
const
    ProscribedCharacters = ',?"*~#%&{}:<>+|';
var
	T: Integer;
begin
	for T := 1 to Length( S ) do begin
        if Pos( S[T] , ProscribedCharacters ) > 0 then begin
            S[T] := '_';
        end;
	end;
end;


end.
