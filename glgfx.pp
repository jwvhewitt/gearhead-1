unit glgfx;
{$MODE FPC}
	{ SDL/OpenGL rendering unit. }
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

uses gl,glu,SDL,SDL_TTF,SDL_Image,gears,texutil,dos,ui4gh;

const
	MaxImagesPerTexture = 25;

Type
	SensibleSpritePtr = ^SensibleSprite;
	SensibleSprite = Record
		Name: String;
		W,H: Integer;	{ Width and Height of each cell. }
		Img: PSDL_Surface;
		Next: SensibleSpritePtr;
	end;

	SensibleTexPtr = ^SensibleTex;	{ Like a sprite, but holds a texture. }
	SensibleTex = Record
		Name,Color: String;
		N: Integer;
		Img: Array [1..MaxImagesPerTexture] of GLUInt;
		Next: SensibleTexPtr;
	end;


	RedrawProcedureType = Procedure;


const
	Avocado: TSDL_Color =		( r:136; g:141; b:101 );
	Bacardi: TSDL_Color =		( r:121; g:105; b:137 );
	Jade: TSDL_Color =		( r: 66; g:121; b:119 );
	BrightJade: TSDL_Color =	( r:100; g:200; b:180 );

	StdBlack: TSDL_Color =		( r:  0; g:  0; b:  0 );
	StdWhite: TSDL_Color =		( r:255; g:255; b:255 );
	MenuItem: TSDL_Color =		( r: 66; g:121; b:119 );
	MenuSelect: TSDL_Color =	( r:100; g:200; b:180 );
	TerrainGreen: TSDL_Color =	( r:100; g:210; b:  0 );
	PlayerBlue: TSDL_Color =	( r:  0; g:141; b:211 );
	AllyPurple: TSDL_Color =	( r:236; g:  0; b:211 );
	EnemyRed: TSDL_Color =		( r:230; g:  0; b:  0 );
	NeutralGrey: TSDL_Color =	( r:150; g:150; b:150 );
	DarkGrey: TSDL_Color =		( r:100; g:100; b:100 );
	InfoGreen: TSDL_Color =		( r:  0; g:141; b:  0 );
	InfoHiLight: TSDL_Color =	( r:  0; g:210; b:  0 );
	TextboxGrey: TSDL_Color =	( r:130; g:120; b:125 );
	NeutralBrown: TSDL_Color =	( r:230; g:191; b: 81 );
	BorderBlue: TSDL_Color =	( r:  0; g:101; b:151 );
	Cyan: TSDL_Color = 		( r:  0; g:255; b:155 );

	BorderColor: TSDL_Color = 	( r:200; g: 50; b:  0 );


{	ScreenWidth = 640;
	ScreenHeight = 480;}

	ScreenWidth = 800;
	ScreenHeight = 600;


	ZONE_TextInputPrompt: TSDL_Rect = ( x: ScreenWidth div 2 - 160 ; y: ScreenHeight div 2 - 25 ; w:320 ; h:20 );
	ZONE_TextInput: TSDL_Rect = ( x: ScreenWidth div 2 - 160 ; y: ScreenHeight div 2 ; w:320 ; h:20 );
	ZONE_TextInputBigBox: TSDL_Rect = ( x: ScreenWidth div 2 - 170 ; y: ScreenHeight div 2 - 35 ; w:340 ; h:70 );
	ZONE_TextInputSmallBox: TSDL_Rect = ( x: ScreenWidth div 2 - 165 ; y: ScreenHeight div 2 - 30 ; w:330 ; h:60 );

	ZONE_Dialog: TSDL_Rect = ( x: 10; y: ScreenHeight - 60; w: ScreenWidth - 20; h: 50 );

	KEY_REPEAT_DELAY = 200;
	KEY_REPEAT_INTERVAL = 50;

	RPK_MouseButton = #$90;
	RPK_TimeEvent = #$91;
	RPK_RightButton = #$92;

	Console_History_Length = 240;

	ZONE_MoreText: TSDL_Rect = ( x:10; y:10; w: ScreenWidth - 20 ; h: ScreenHeight - 50 );
	ZONE_MorePrompt: TSDL_Rect = ( x:10; y: ScreenHeight - 40 ; w:ScreenWidth - 20; h:30 );


var
	Actual_Screen,Game_Screen: PSDL_Surface;
	Game_Font: PTTF_Font;
	Game_Sprites: SensibleSpritePtr;
	Game_Textures: SensibleTexPtr;
	Last_Clock_Update: UInt32;
	Animation_Phase: Integer;
	Mouse_X, Mouse_Y: LongInt;
	Game_Messages: SAttPtr;
	Cursor_Sprite: SensibleSpritePtr;
	Console_History: SAttPtr;

	RK_NumKeys:	PInt;
	RK_KeyState:	PUInt8;

Procedure GHFlip;

Procedure QuickText( const msg: String; MyDest: TSDL_Rect; C: TSDL_Color );
Procedure QuickTextRJ( const msg: String; MyDest: TSDL_Rect; C: TSDL_Color );

Procedure DisposeSpriteList(var LList: SensibleSpritePtr);
Procedure RemoveSprite(var LMember: SensibleSpritePtr);

procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
procedure DrawSprite( Spr: SensibleSpritePtr; MyCanvas: PSDL_Surface; MyDest: TSDL_Rect; Frame: Integer );

function LocateSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;

Procedure DisposeTexList;
Function LocateTexture( const Name,Color: String ): SensibleTexPtr;


function RPGKey: Char;

Procedure ClrZone( var Z: TSDL_Rect );
Procedure ClrScreen;

Procedure GetNextLine( var TheLine , msg , const NextWord: String; Width: Integer );
Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean ): PSDL_Surface; {no const}
Procedure NFCMessage( const msg: String; Z: TSDL_Rect; var C: TSDL_Color );
Procedure NFGameMSG( const msg: string; Z: TSDL_Rect; var C: TSDL_Color );

Function IsMoreKey( A: Char ): Boolean;
Procedure MoreKey;
Function TextLength( F: PTTF_Font; const msg: String ): LongInt;

Function MsgString( const key: String ): String;

Function GetStringFromUser( const Prompt: String; ReDrawer: RedrawProcedureType ): String;

Procedure ComicsBox( Dest: TSDL_Rect );

Procedure MoreText( LList: SAttPtr; FirstLine: Integer );

Procedure InsertDialogLine( const TheLine: String );
Procedure RedrawConsole;
Procedure DialogMSG(msg: string); {can't const}


implementation

const
	WindowName: PChar = 'Dungeon Monkey!';
	IconName: PChar = 'Dungeon Monkey!';

Procedure GHFlip;
	{ The normal SDL_Flip command isn't used here. Instead, we'll be using }
	{ this custom routine to stick Game_Screen on top of the OpenGL rendering }
	{ and then flip the actual display. }
begin
	glMatrixMode( GL_Projection );
	glLoadIdentity;
	glDisable( GL_Depth_Test );
	gluOrtho2d( 0.0 , screenwidth , 0.0 , screenheight );
	glMatrixMode( GL_ModelView );
	glLoadIdentity;
	glRasterPos2i( 0 , screenheight );
	glPixelZoom( 1.0 , -1.0 );
	glEnable( GL_BLEND );

	glDrawPixels( Game_Screen^.W , Game_Screen^.H , GL_RGBA , GL_Unsigned_Byte , Game_Screen^.Pixels );

	SDL_gl_SwapBuffers;
end;

Procedure QuickText( const msg: String; MyDest: TSDL_Rect; C: TSDL_Color );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( game_font , pline , C );
	Dispose( pline );
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure QuickTextRJ( const msg: String; MyDest: TSDL_Rect; C: TSDL_Color );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
	{ This variation on the procedure is right-justified. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( game_font , pline , C );
	Dispose( pline );
	MyDest.X := MyDest.X - MyText^.W;
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure DrawAnimImage( Image,Canvas: PSDL_Surface; W,H,Frame: Integer; var MyDest: TSDL_Rect );
	{ This procedure is modeled after the command from Blitz Basic. }
var
	MySource: TSDL_Rect;
begin
	MySource.W := W;
	MySource.H := H;
	if W > Image^.W then W := Image^.W;
	MySource.X := ( Frame mod ( Image^.W div W ) ) * W;
	MySource.Y := ( Frame div ( Image^.W div W ) ) * H;

	SDL_BlitSurface( Image , @MySource , Canvas , @MyDest );
end;


Function LocateSpriteByName( const name: String ): SensibleSpritePtr;
	{ Locate the sprite which matches the name provided. }
	{ If no such sprite exists, return Nil. }
var
	S: SensibleSpritePtr;
begin
	S := Game_Sprites;
	while ( S <> Nil ) and ( S^.Name <> name ) do begin
		S := S^.Next;
	end;
	LocateSpriteByName := S;
end;

Function NewSprite: SensibleSpritePtr;
	{ Add an empty sprite description to the list. }
var
	it: SensibleSpritePtr;
begin
	New(it);
	if it = Nil then exit( Nil );
	{Initialize values.}
	it^.Next := Game_Sprites;
	Game_Sprites := it;
	NewSprite := it;
end;

Function AddSprite( const name: String ): SensibleSpritePtr;
	{ Add a new element to the Sprite List. Load the image for this sprite }
	{ from disk, if possible. }
var
	fname: PChar;
	it: SensibleSpritePtr;
begin
	{Allocate memory for our new element.}
	it := NewSprite;
	if it = Nil then Exit( Nil );
	it^.Name := Name;

	name := FSearch( name , Graphics_Directory );

	if name <> '' then begin
		fname := QuickPCopy( name );

		{ Attempt to load the image. }
		it^.Img := IMG_Load( fname );
		{ Set transparency color. }
		SDL_SetColorKey( it^.Img , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( it^.Img^.Format , 0 , 0, 255 ) );

		Dispose( fname );
	end else begin
		it^.Img := Nil;

	end;

	{Return a pointer to the new element.}
	AddSprite := it;
end;

Procedure DisposeSpriteList(var LList: SensibleSpritePtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: SensibleSpritePtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;

		if LList^.Img <> Nil then SDL_FreeSurface( LList^.Img );

		Dispose(LList);
		LList := LTemp;
	end;
end;


Procedure RemoveSprite(var LMember: SensibleSpritePtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: SensibleSpritePtr;
begin
	{Initialize A and B}
	B := Game_Sprites;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveLink asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		Game_Sprites := B^.Next;
		B^.Next := Nil;
		DisposeSpriteList(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.Next := Nil;
		DisposeSpriteList(B);
	end;
end;

procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		DrawAnimImage( Spr^.Img , Game_Screen , Spr^.W , Spr^.H , Frame , MyDest );
	end;
end;

procedure DrawSprite( Spr: SensibleSpritePtr; MyCanvas: PSDL_Surface; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite to an arbitrary canvas. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		DrawAnimImage( Spr^.Img , MyCanvas , Spr^.W , Spr^.H , Frame , MyDest );
	end;
end;


function LocateSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;
	{ Find the requested sprite, either in memory or from disk. }
var
	S: SensibleSpritePtr;
begin
	{ First, find the sprite. If by some strange chance it hasn't been }
	{ loaded yet, load it now. }
	S := LocateSpriteByName( Name );
	if S = Nil then S := AddSprite( Name );

	{ Set the width and height fields. }
	S^.W := W;
	S^.H := H;

	LocateSprite := S;
end;

Function NewTex: SensibleTexPtr;
	{ Add an empty texture description to the list. }
	{ Give it a texture name. }
var
	it: SensibleTexPtr;
begin
	{ Next, allocate a SensibleTex and initialize it. }
	New(it);
	if it = Nil then exit( Nil );
	{Initialize values.}
	it^.Next := Game_Textures;
	Game_Textures := it;
	glGenTextures( MaxImagesPerTexture, @it^.Img );
	NewTex := it;
end;

Procedure DisposeTexList;
	{ Dispose of the current texture list, and all associated system resources. }
var
	LTemp: SensibleTexPtr;
begin
	while Game_Textures <> Nil do begin
		LTemp := Game_Textures^.Next;
		glDeleteTextures( MaxImagesPerTexture , @Game_Textures^.Img );
		Dispose( Game_Textures );
		Game_Textures := LTemp;
	end;
end;

Function ScaleColorValue( V , I: Integer ): Byte;
	{ Scale a color value. }
begin
	V := ( V * I ) div 200;
	if V > 255 then V := 255;
	ScaleColorValue := V;
end;

Function MakeSwapBitmap( MyImage: PSDL_Surface; RSwap,YSwap,GSwap: PSDL_Color ): PSDL_Surface;
	{ Given a bitmap, create an 8-bit copy with pure colors. }
	{         0 : Transparent (0,0,255) }
	{   1 -  63 : Grey Scale            }
	{  64 - 127 : Pure Red              }
	{ 128 - 191 : Pure Yellow           }
	{ 192 - 255 : Pure Green            }
	{ Then, swap those colors out for the requested colors. }
var
	MyPal: Array [0..255] of TSDL_Color;
	T: Integer;
	MyImage2: PSDL_Surface;
begin
	{ Initialize the palette. }
	for t := 1 to 64 do begin
		MyPal[ T - 1 ].r := ( t * 4 ) - 1;
		MyPal[ T - 1 ].g := ( t * 4 ) - 1;
		MyPal[ T - 1 ].b := ( t * 4 ) - 1;

		MyPal[ T + 63 ].r := ( t * 4 ) - 1;
		MyPal[ T + 63 ].g := 0;
		MyPal[ T + 63 ].b := 0;

		MyPal[ T + 127 ].r := ( t * 4 ) - 1;
		MyPal[ T + 127 ].g := ( t * 4 ) - 1;
		MyPal[ T + 127 ].b := 0;

		MyPal[ T + 191 ].r := 0;
		MyPal[ T + 191 ].g := ( t * 4 ) - 1;
		MyPal[ T + 191 ].b := 0;
	end;
	MyPal[ 0 ].r := 0;
	MyPal[ 0 ].g := 0;
	MyPal[ 0 ].b := 255;

	{ Create replacement surface. }
	MyImage2 := SDL_CreateRGBSurface( SDL_SWSURFACE , MyImage^.W , MyImage^.H , 8 , 0 , 0 , 0 , 0 );
	SDL_SetPalette( MyImage2 , SDL_LOGPAL or SDL_PHYSPAL , MyPal , 0 , 256 );
	SDL_FillRect( MyImage2 , Nil , SDL_MapRGB( MyImage2^.Format , 0 , 0 , 255 ) );
	SDL_SetColorKey( MyImage2 , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( MyImage2^.Format , 0 , 0, 255 ) );

	{ Blit from the original to the copy. }
	SDL_BlitSurface( MyImage , Nil , MyImage2 , Nil );

	{ Redefine the palette. }
	for t := 1 to 64 do begin
		MyPal[ T + 63 ].r := ScaleColorValue( RSwap^.R , t * 4 );
		MyPal[ T + 63 ].g := ScaleColorValue( RSwap^.G , t * 4 );
		MyPal[ T + 63 ].b := ScaleColorValue( RSwap^.B , t * 4 );

		MyPal[ T + 127 ].r := ScaleColorValue( YSwap^.R , t * 4 );
		MyPal[ T + 127 ].g := ScaleColorValue( YSwap^.G , t * 4 );
		MyPal[ T + 127 ].b := ScaleColorValue( YSwap^.B , t * 4 );

		MyPal[ T + 191 ].r := ScaleColorValue( GSwap^.R , t * 4 );
		MyPal[ T + 191 ].g := ScaleColorValue( GSwap^.G , t * 4 );
		MyPal[ T + 191 ].b := ScaleColorValue( GSwap^.B , t * 4 );
	end;
	SDL_SetPalette( MyImage2 , SDL_LOGPAL or SDL_PHYSPAL , MyPal , 0 , 256 );

	MakeSwapBitmap := MyImage2;
end;

Procedure GenerateColor( var ColorString: String; var ColorStruct: TSDL_Color );
	{ Generate the color from the string. }
var
	n: Integer;
begin
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.R := n;
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.G := n;
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.B := n;
end;


Function AddTexture( const Name,Color: String ): SensibleTexPtr;
	{ Add a texture to the list. }
	{ PRECOND: Must be a good image for generating a texture!!! }
var
	MyTex: SensibleTexPtr;
	MyImage: SensibleSpritePtr;
	tmp: PSDL_Surface;
	RSwap,YSwap,GSwap: TSDL_Color;
	T: Integer;
	MyDest: TSDL_Rect;
begin
	MyTex := NewTex;
	MyTex^.Name := UpCase( Name );
	MyTex^.Color := Color;

	MyImage := LocateSprite( name , 64 , 64 );
	if color <> '' then begin
		GenerateColor( Color , RSwap );
		GenerateColor( Color , YSwap );
		GenerateColor( Color , GSwap );
		tmp := MakeSwapBitmap( MyImage^.Img , @RSwap , @YSwap , @GSwap );
		SDL_FreeSurface( MyImage^.Img );
		MyImage^.img := tmp;
	end;
	MyDest.X := 0;
	MyDest.Y := 0;

	tmp := SDL_CreateRGBSurface( SDL_SWSURFACE , 64 , 64 , 32 , $000000ff , $0000ff00 , $00ff0000 , $ff000000 );

	MyTex^.N := ( ( MyImage^.img^.H div 64 ) * ( MyImage^.img^.W div 64 ) );
	if MyTex^.N > MaxImagesPerTexture then MyTex^.N := MaxImagesPerTexture;

	for t := 1 to MyTex^.N do begin
		SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
		DrawSprite( MyImage , tmp , MyDest , T - 1 );

		glBindTexture( GL_TEXTURE_2D, MyTex^.Img[t] );
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
		glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
	end;

	RemoveSprite( MyImage );
	SDL_FreeSurface(tmp);

	AddTexture := MyTex;
end;

Function LocateTexture( const name_in,color: String ): SensibleTexPtr;
	{ Get the number of the texture identified by the provided ID number. }
var
	T,it: SensibleTexPtr;
        name: String
begin
	T := Game_Textures;
	it := Nil;
	name := Upcase( Name_In );
	while T <> Nil do begin
		if ( T^.name = name ) and ( T^.Color = Color ) then it := T;
		T := T^.Next;
	end;
	if it = Nil then it := AddTexture( name , color );
	LocateTexture := it;
end;

function RPGKey: Char;
	{ Read a readable key from the keyboard and return its ASCII value. }
	{ This function will always return within a close approximation of 30ms }
	{ from the last time it was called. It will also update the array of }
	{ keypresses. }
var
	a: String;
	event : TSDL_Event;
begin
	if SDL_GetTicks < ( Last_Clock_Update + 20 ) then SDL_Delay( Last_Clock_Update + 30 - SDL_GetTicks );
	Last_Clock_Update := SDL_GetTicks + 30;
	Animation_Phase := ( Animation_Phase + 1 ) mod 6000;
	a := RPK_TimeEvent;

	if SDL_PollEvent( @event ) = 1 then begin
		{ See if this event is a keyboard one... }
		if event.type_ = SDL_KEYDOWN then begin
			{ Check to see if it was an ASCII character we received. }
			case event.key.keysym.sym of
				SDLK_Up,SDLK_KP8:	a := RPK_Up;
				SDLK_Down,SDLK_KP2:	a := RPK_Down;
				SDLK_Left,SDLK_KP4:	a := RPK_Left;
				SDLK_Right,SDLK_KP6:	a := RPK_Right;
				SDLK_KP7:		a := RPK_UpLeft;
				SDLK_KP9:		a := RPK_UpRight;
				SDLK_KP1:		a := RPK_DownLeft;
				SDLK_KP3:		a := RPK_DownRight;
				SDLK_Backspace:		a := #8;
				SDLK_KP_Enter:		a := #10;
				SDLK_KP5:		a := '5';
			else
				if( event.key.keysym.unicode <  $80 ) and ( event.key.keysym.unicode > 0 ) then begin
					a := Char( event.key.keysym.unicode );
				end;
			end;

		end else if ( event.type_ = SDL_MOUSEButtonDown ) then begin
			{ Return a mousebutton event, and call GHFlip to set the mouse position }
			{ variables. }
			if event.button.button = SDL_BUTTON_LEFT then begin
				a := RPK_MouseButton;
			end else if event.button.button = SDL_BUTTON_RIGHT then begin
				a := RPK_RightButton;
			end;
		end;
	end;

	RK_KeyState := SDL_GetKeyState( RK_NumKeys );
	SDL_GetMouseState( Mouse_X , Mouse_Y );

	if a <> '' then RPGKey := a[1]
	else RPGKey := 'Z';
end;

Procedure ClrZone( var Z: TSDL_Rect );
	{ Clear the specified screen zone. }
begin
	SDL_FillRect( game_screen , @Z , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
end;

Procedure ClrScreen;
	{ Clear the specified screen zone. }
begin
	glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
	SDL_FillRect( game_screen , Nil , SDL_MapRGBA( Game_Screen^.Format , 0 , 0 , 255 , 0 ) );
end;

Function TextLength( F: PTTF_Font; const msg: String ): LongInt;
	{ Determine how long "msg" will be using the default "game_font". }
var
	pmsg: PChar;	{ Gotta convert to pchar, pain in the ass... }
	W,Y: LongInt;	{ W means width I guess... Y is anyone's guess. Height? }
begin
	{ Convert the string to a pchar. }
	pmsg := QuickPCopy( msg );

	{ Call the alleged size calculation function. }
	TTF_SizeText( F , pmsg , W , Y );

	{ get rid of the PChar, since it's served its usefulness. }
	Dispose( pmsg );

	TextLength := W;
end;

Procedure GetNextLine( var TheLine , msg , NextWord: String; Width: Integer );
	{ Get a line of text of maximum width "Width". }
var
	LC: Boolean;	{ Loop Condition. So I wasn't very creative when I named it, so what? }
begin
	{ Loop condition starts out as TRUE. }
	LC := True;

	{ Start building the line. }
	repeat
		NextWord := ExtractWord( Msg );

		if TextLength( Game_Font , THEline + ' ' + NextWord) < Width then
			THEline := THEline + ' ' + NextWord
		else
			LC := False;

	until (not LC) or (NextWord = '') or ( TheLine[Length(TheLine)] = #13 );

	{ If the line ended due to a line break, deal with it. }
	if ( TheLine[Length(TheLine)] = #13 ) then begin
		{ Display the line break as a space. }
		TheLine[Length(TheLine)] := ' ';
		NextWord := ExtractWord( msg );
	end;

end;

{can't const}
Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean ): PSDL_Surface;
	{ Create a SDL_Surface containing all the text within "msg" formatted }
	{ in lines of no longer than "width" pixels. Sound simple? Mostly just }
	{ tedious, I'm afraid. }
var
	SList,SA: SAttPtr;
	S_Total,S_Temp: PSDL_Surface;
	MyDest: SDL_Rect;
	pline: PChar;
	NextWord: String;
	THELine: String;	{The line under construction.}
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	if msg = '' then Exit( Nil );

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );
	NextWord := '';
	SList := Nil;

	{Start the main processing loop.}
	while TheLine <> '' do begin
		GetNextLine( TheLine , msg , NextWord , Width );

		{ Output the line. }
		{ Next append it to whatever has already been created. }
		StoreSAtt( SList , TheLine );

		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }

	{ Create a bitmap for the message. }
	if SList <> Nil then begin
		{ Create a big bitmap to hold everything. }
		S_Total := SDL_CreateRGBSurface( SDL_SWSURFACE , width , TTF_FontLineSkip( game_font ) * NumSAtts( SList ) , 32 , $FF000000 , $00FF0000 , $0000FF00 , $000000FF );
		MyDest.X := 0;
		MyDest.Y := 0;

		{ Add each stored string to the bitmap. }
		SA := SList;
		while SA <> Nil do begin
			pline := QuickPCopy( SA^.Info );
			S_Temp := TTF_RenderText_Solid( game_font , pline , fg );
			Dispose( pline );

			{ We may or may not be required to do centering of the text. }
			if DoCenter then begin
				MyDest.X := ( Width - TextLength( Game_Font , SA^.Info ) ) div 2;
			end else begin
				MyDest.X := 0;
			end;

			SDL_BlitSurface( S_Temp , Nil , S_Total , @MyDest );
			SDL_FreeSurface( S_Temp );
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( game_font );
			SA := SA^.Next;
		end;
		DisposeSAtt( SList );

	end else begin
		S_Total := Nil;
	end;


	PrettyPrint := S_Total;
end;

Procedure NFCMessage( const msg: String; Z: TSDL_Rect; var C: TSDL_Color );
	{ Print a message to the screen, centered in the requested rect. }
	{ Clear the specified zone before doing so. }
var
	MyText: PSDL_Surface;
	MyDest: TSDL_Rect;
begin
	MyText := PrettyPrint( msg , Z.W , C , True );
	if MyText <> Nil then begin
		MyDest := Z;
		MyDest.Y := MyDest.Y + ( Z.H - MyText^.H ) div 2;
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Procedure NFGameMSG( const msg: string; Z: TSDL_Rect; var C: TSDL_Color );
	{ As above, but no pageflip. }
var
	MyText: PSDL_Surface;
begin
	MyText := PrettyPrint( msg , Z.W , C , True );
	if MyText <> Nil then begin
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @Z );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Function IsMoreKey( A: Char ): Boolean;
	{ Return TRUE if A is a "more" key, that should skip to the next message in a list. }
begin
	IsMoreKey := ( A = ' ' ) or ( A = #27 ) or ( A = RPK_MouseButton );
end;

Procedure MoreKey;
	{ Wait for the user to press either the space bar or the ESC key. }
var
	A: Char;
begin
	{ Keep reading keypresses until either a space or an ESC is found. }
	repeat
		A := RPGKey;
	until IsMoreKey( A );
end;

Function MsgString( const key: String ): String;
	{ Return one of the standard messages. }
begin
	MsgString := SAttValue( Game_Messages , key );
end;

Procedure ClearExtendedBorder( Dest: TSDL_Rect );
	{ Draw the inner box for border displays. }
begin
	Dest.X := Dest.X - 1;
	Dest.Y := Dest.Y - 1;
	Dest.W := Dest.W + 2;
	Dest.H := Dest.H + 2;
	SDL_FillRect( game_screen , @Dest , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
end;

Procedure ComicsBox( Dest: TSDL_Rect );
	{ Do a yellow comics text box, as popularized by Marvel... gosh, }
	{ I hope I don't get sued for admitting that... }
begin
	Dest.X := Dest.X - 5;
	Dest.Y := Dest.Y - 5;
	Dest.W := Dest.W + 10;
	Dest.H := Dest.H + 10;
	ClearExtendedBorder( Dest );
	SDL_FillRect( game_screen , @(Dest) , SDL_MapRGBA( Game_Screen^.Format , 255 , 248 , 21 , 155 ) );
end;

Function GetStringFromUser( const Prompt: String; ReDrawer: RedrawProcedureType ): String;
	{ Does what it says. }
const
	AllowableCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890()-=_+,.?"';
	MaxInputLength = 80;
var
	A: Char;
	it: String;
	MyDest: TSDL_Rect;
begin
	{ Initialize string. }
	it := '';

	repeat
		{ Set up the display. }
		if ReDrawer <> Nil then ReDrawer;
		ClearExtendedBorder( ZONE_TextInputBigBox );
		SDL_FillRect( game_screen , @ZONE_TextInputBigBox , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );
		SDL_FillRect( game_screen , @ZONE_TextInputSmallBox , SDL_MapRGB( Game_Screen^.Format , StdBlack.R , StdBlack.G , StdBlack.B ) );

		NFCMessage( Prompt , ZONE_TextInputPrompt , StdWhite );
		NFCMessage( it , ZONE_TextInput , InfoGreen );
		MyDest.Y := ZONE_TextInput.Y + 2;
		MyDest.X := ZONE_TextInput.X + ( ZONE_TextInput.W div 2 ) + ( TextLength( Game_Font , it ) div 2 );
		DrawSprite( Cursor_Sprite , MyDest , ( Animation_Phase div 2 ) mod 4 );

		GHFlip;
		A := RPGKey;

		if ( A = #8 ) and ( Length( it ) > 0 ) then begin
			it := Copy( it , 1 , Length( it ) - 1 );
		end else if ( Pos( A , AllowableCharacters ) > 0 ) and ( Length( it ) < MaxInputLength ) then begin
			it := it + A;
		end;
	until ( A = #13 ) or ( A = #27 );

	GetStringFromUser := it;
end;

Function MoreHighFirstLine( LList: SAttPtr ): Integer;
	{ Determine the highest possible FirstLine value. }
var
	it: Integer;
begin
	it := NumSAtts( LList ) - ( ZONE_MoreText.H  div  TTF_FontLineSkip( game_font ) ) + 1;
	if it < 1 then it := 1;
	MoreHighFirstLine := it;
end;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer );
	{ Browse this text file across the majority of the screen. }
	{ Clear the screen upon exiting, though restoration of the }
	{ previous display is someone else's responsibility. }
	Procedure DisplayTextHere;
	var
		T: Integer;
		MyDest: TSDL_Rect;
		MyImage: PSDL_Surface;
		CLine: SAttPtr;	{ Current Line }
		PLine: PChar;
	begin
		{ Set the clip area. }
		ClrZone( ZONE_MoreText );
		SDL_SetClipRect( Game_Screen , @ZONE_MoreText );
		MyDest := ZONE_MoreText;

		{ Error check. }
		if FirstLine < 1 then FirstLine := 1
		else if FirstLine > MoreHighFirstLine( LList ) then FirstLine := MoreHighFirstLine( LList );

		CLine := RetrieveSATt( LList , FirstLine );
		for t := 1 to ( ZONE_MoreText.H  div  TTF_FontLineSkip( game_font ) ) do begin
			if CLine <> Nil then begin
				pline := QuickPCopy( CLine^.Info );
				MyImage := TTF_RenderText_Solid( game_font , pline , NeutralGrey );
				Dispose( pline );
				SDL_BlitSurface( MyImage , Nil , Game_Screen , @MyDest );
				SDL_FreeSurface( MyImage );
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( game_font );
				CLine := CLine^.Next;
			end;
		end;

		{ Restore the clip area. }
		SDL_SetClipRect( Game_Screen , Nil );
		GHFlip;
	end;
var
	A: Char;
begin
	NFCMessage( MsgString( 'MORETEXT_Prompt' ) , ZONE_MorePrompt , InfoGreen );

	{ Display the screen. }
	DisplayTextHere;

	repeat
		{ Get input from user. }
		A := RPGKey;

		{ Possibly process this input. }
		if A = '2' then begin
			Inc( FirstLine );
			DisplayTextHere;
		end else if A = '8' then begin
			Dec( FirstLine );
			DisplayTextHere;
		end;

	until ( A = #27 ) or ( A = 'Q' ) or ( A = #8 );
end;

Procedure InsertDialogLine( const TheLine: String );
	{ Insert a line of text into the dialog message area. }
var
	PLine: PChar;
	MySource,MyDest: TSDL_Rect;
	S_Temp: PSDL_Surface;	
begin
	{Clear the message area, and set clipping bounds.}
	SDL_SetClipRect( Game_Screen , @ZONE_Dialog );

	{ Scroll the current console messages up. }
	S_Temp := SDL_CreateRGBSurface( SDL_SWSURFACE , ZONE_Dialog.w , ZONE_Dialog.H , 16 , 0 , 0 , 0 , 0 );
	MySource := ZONE_Dialog;
	MyDest := ZONE_Dialog;
	MyDest.Y := MyDest.Y - TTF_FontLineSkip( game_font );
	SDL_BlitSurface( Game_Screen, @MySource, S_Temp, Nil );
	ClrZone( ZONE_Dialog );
	SDL_BlitSurface( S_Temp, Nil, Game_Screen, @MyDest );
	SDL_FreeSurface( S_Temp );

	{ Display the line in the bottom space. }
	MyDest := ZONE_Dialog;
	MyDest.Y := MyDest.Y + MyDest.H - TTF_FontLineSkip( game_font );
	pline := QuickPCopy( TheLine );
	S_Temp := TTF_RenderText_Solid( game_font , pline , InfoGreen );
	Dispose( pline );
	SDL_BlitSurface( S_Temp , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( S_Temp );

	{ Restore the clip zone to the full screen. }
	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure RedrawConsole;
	{ Redraw the console. Yay! }
var
	SL: SAttPtr;
begin
	SL := RetrieveSAtt( Console_History , NumSAtts( Console_History ) - ( ZONE_Dialog.H div TTF_FontLineSkip( game_font ) ));
	if SL = Nil then SL := Console_History;
	while SL <> Nil do begin
		InsertDialogLine( SL^.Info );
		SL := SL^.Next;
	end;
end;

{can't const}
Procedure DialogMSG(msg: string);
	{ Print a message in the scrolling dialog box, }
	{ then store the line in Console_History. }
var
	NextWord: String;
	THELine: String;	{The line under construction.}
	SA: SAttPtr;
begin
	{ CLean up the message a bit. }
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	if msg = '' then Exit;
	msg := '> ' + Msg;

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );
	NextWord := '';

	{Start the main processing loop.}
	while TheLine <> '' do begin
		GetNextLine( TheLine , msg , NextWord , ZONE_Dialog.w );

		{ Output the line. }
		if TheLine <> '' then begin
			InsertDialogLine( TheLine );

			{ If appropriate, save the line. }
			if NumSAtts( Console_History ) >= Console_History_Length then begin
				SA := Console_History;
				RemoveSAtt( Console_History , SA );
			end;
			StoreSAtt( Console_History , TheLine );
		end;


		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }

	GHFlip;
end;


initialization

	SDL_Init( SDL_INIT_VIDEO );

	SDL_GL_SetAttribute( SDL_GL_RED_SIZE, 5 );
	SDL_GL_SetAttribute( SDL_GL_GREEN_SIZE, 5 );
	SDL_GL_SetAttribute( SDL_GL_BLUE_SIZE, 5 );
	SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE, 16 );
	SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );


	Actual_Screen := SDL_SetVideoMode(ScreenWidth, ScreenHeight, 24, SDL_OPENGL or SDL_FULLSCREEN );

	Game_Screen := SDL_CreateRGBSurface( SDL_SWSURFACE , ScreenWidth, ScreenHeight , 32 , $000000ff , $0000ff00 , $00ff0000 , $ff000000 );
	ClrScreen;
	SDL_SetColorKey( Game_Screen , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 255 ) );

        SDL_EnableUNICODE( 1 );
	SDL_EnableKeyRepeat( KEY_REPEAT_DELAY , KEY_REPEAT_INTERVAL );

	glClearColor( 0 , 0 , 0 , 0 );
	glViewport( 0, 0, screenwidth, screenheight );

	glMatrixMode( GL_PROJECTION );
	glLoadIdentity;
	gluPerspective( 120.0, screenwidth/screenheight , 1.0, 1024.0 );

	glEnable( GL_BLEND );
	glBlendFunc( GL_SRC_ALPHA , GL_ONE_MINUS_SRC_ALPHA );

	Game_Messages := LoadStringList( Standard_Message_File );

	TTF_Init;

	Game_Font := TTF_OpenFont( 'graphics/VeraBd.ttf' , 10 );

	Game_Sprites := Nil;
	Game_Textures := Nil;

finalization

	DisposeSAtt( Console_History );
	DisposeSpriteList( Game_Sprites );
	DisposeTexList;
	TTF_CloseFont( Game_Font );
	TTF_Quit;

	DisposeSAtt( Game_Messages );

	SDL_FreeSurface( Game_Screen );
	SDL_Quit;
end.
