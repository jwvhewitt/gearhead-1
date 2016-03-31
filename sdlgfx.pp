unit sdlgfx;
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

uses SDL,SDL_TTF,SDL_Image,texutil,gears,dos,ui4gh;

Type
	SensibleSpritePtr = ^SensibleSprite;
	SensibleSprite = Record
		Name,Color: String;
		W,H: Integer;	{ Width and Height of each cell. }
		Img: PSDL_Surface;
		Next: SensibleSpritePtr;
	end;

	RedrawProcedureType = Procedure;

    DynamicRect = Object
        dx,dy,w,h,anchor: Integer;
        function GetRect: TSDL_Rect;
    end;


const
	StdBlack: TSDL_Color =		( r:  0; g:  0; b:  0 );
	StdWhite: TSDL_Color =		( r:255; g:255; b:255 );
	MenuItem: TSDL_Color =		( r:90; g:156; b:179 );
	MenuSelect: TSDL_Color =	( r:128; g:255; b:230 );
	PlayerBlue: TSDL_Color =	( r:  0; g:141; b:211 );
	AllyPurple: TSDL_Color =	( r:236; g:  0; b:211 );
	EnemyRed: TSDL_Color =		( r:230; g:  0; b:  0 );
	NeutralGrey: TSDL_Color =	( r:150; g:150; b:150 );
	DarkGrey: TSDL_Color =		( r:100; g:100; b:100 );
	InfoGreen: TSDL_Color =		( r: 50; g:200; b:  0 );
	InfoHiLight: TSDL_Color =	( r:100; g:250; b:  0 );

	TextboxGrey: TSDL_Color =	( r:130; g:120; b:125 );
	NeutralBrown: TSDL_Color =	( r:240; g:201; b: 20 );
	BorderBlue: TSDL_Color =	( r:  0; g:101; b:151 );
	BrightYellow: TSDL_Color =	( r:255; g:201; b:  0 );

	ScreenWidth = 800;
	ScreenHeight = 600;
	BigFontSize = 13;
	SmallFontSize = 11;
	Right_Column_Width = 220;
	Dialog_Area_Height = 110;

    ANC_upperleft = 0;
    ANC_upper = 1;
    ANC_upperright = 2;
    ANC_left = 3;
    ANC_middle = 4;
    ANC_right = 5;
    ANC_lowerleft = 6;
    ANC_lower = 7;
    ANC_lowerright = 8;

	ZONE_Map: TSDL_Rect = ( x:10; y:10; w: ScreenWidth - Right_Column_Width - 30 ; h: ScreenHeight - Dialog_Area_Height - 20 );
	ZONE_Clock: TSDL_Rect = ( x: ScreenWidth - Right_Column_Width - 10 ; y:ScreenHeight - Dialog_Area_Height - 30; w:Right_Column_Width; h:20 );
	ZONE_PCInfo: TSDL_Rect = ( x:  ScreenWidth - Right_Column_Width - 10 ; y:10; w:Right_Column_Width; h:150 );
	ZONE_Dialog: TSDL_Rect = ( x:10; y: ScreenHeight - Dialog_Area_Height ; w: ScreenWidth - 20 ; h:Dialog_Area_Height-10 );

    ZONE_TitleScreenMenu: DynamicRect = ( dx:-100; dy:50; w:200; h:100; anchor: ANC_middle );
    ZONE_TitleScreenLogo: DynamicRect = ( dx:-250; dy:-190; w:500; h:215; anchor: ANC_middle );

	ZONE_TargetInfo: DynamicRect = ( dx:  -Right_Column_Width -10 ; dy:10; w:Right_Column_Width; h:150; anchor: ANC_upperright );
    ZONE_TargetDistance: DynamicRect = ( dx:  -Right_Column_Width -10 ; dy:176; w:Right_Column_Width; h:20; anchor: ANC_upperright );

    ZONE_CharGenChar: DynamicRect = ( dx:-368; dy:-210; w: 500 ; h: 420; anchor: ANC_middle );
	ZONE_CharGenMenu: DynamicRect = ( dx:148; dy:-50; w:220; h:230; anchor: ANC_middle );
	ZONE_CharGenCaption: DynamicRect = ( dx:148; dy:190; w:220; h:20; anchor: ANC_middle );
	ZONE_CharGenDesc: DynamicRect = ( dx:148; dy:-210; w:220; h:150; anchor: ANC_middle );
	ZONE_CharGenPrompt: DynamicRect = ( dx:-150; dy:-245; w:300; h:20; anchor: ANC_middle );
	ZONE_CharGenHint: DynamicRect = ( dx:-160; dy:225; w:320; h:20; anchor: ANC_middle );

    ZONE_CharViewChar: DynamicRect = ( dx:-368; dy:-260; w: 500 ; h: 420; anchor: ANC_middle );
	ZONE_CharViewMenu: DynamicRect = ( dx:148; dy:-100; w:220; h:230; anchor: ANC_middle );
	ZONE_CharViewCaption: DynamicRect = ( dx:148; dy:140; w:220; h:20; anchor: ANC_middle );
	ZONE_CharViewDesc: DynamicRect = ( dx:148; dy:-260; w:220; h:150; anchor: ANC_middle );


	ZONE_TextInputPrompt: DynamicRect = ( dx:-210; dy:-51; w:420; h:16; anchor: ANC_middle );
	ZONE_TextInput: DynamicRect = ( dx:-210; dy:-27; w:420; h:16; anchor: ANC_middle );
	ZONE_TextInputBigBox: DynamicRect = ( dx:-220; dy:-61; w:440; h:56; anchor: ANC_middle );
    ZONE_PhoneInstructions: DynamicRect = ( dx:-200; dy:15; w:400; h:16; anchor: ANC_middle );

	ZONE_InteractStatus: DynamicRect = ( dx:-250; dy: -210; w: 395; h: 40; anchor: ANC_middle );
	ZONE_InteractMsg: DynamicRect = ( dx: -250; dy:-120; w:395; h: 110; anchor: ANC_middle );
	ZONE_InteractMenu: DynamicRect = ( dx: -250; dy:-5; w:500; h: 120; anchor: ANC_middle );
	ZONE_InteractPhoto: DynamicRect = ( dx: 150; dy: -185; w: 100; h: 150; anchor: ANC_middle );
	ZONE_InteractInfo: DynamicRect = ( dx: -250; dy:-165; w:395; h:40; anchor: ANC_middle );
	ZONE_InteractTotal: DynamicRect = ( dx: -255; dy: -215; w: 510; h: 335; anchor: ANC_middle );


	ZONE_Menu: DynamicRect = ( dx: 10; dy:10; w:Right_Column_Width; h:205; anchor: ANC_upperleft );
	ZONE_Menu1: DynamicRect = ( dx: 10; dy:10; w:Right_Column_Width; h:100; anchor: ANC_upperleft );
	ZONE_Menu2: DynamicRect = ( dx: 10; dy:126; w:Right_Column_Width; h:80; anchor: ANC_upperleft );

	ZONE_MemoText: DynamicRect = ( dx:-175; dy:-150; w:350; h:200; anchor: ANC_middle );
	ZONE_MemoMenu: DynamicRect = ( dx:-175; dy:55; w:350; h:50; anchor: ANC_middle );
    ZONE_MemoTotal: DynamicRect = ( dx:-180; dy:-155; w:360; h:265; anchor: ANC_middle );

    ZONE_CenterMenu: DynamicRect = ( dx:-120; dy:-155; w:240; h:210; anchor: ANC_middle );

    ZONE_FHQTitle: DynamicRect = ( dx:-165; dy:-255; w:300; h:20; anchor: ANC_middle ); 
    ZONE_FHQMenu: DynamicRect = ( dx:-280; dy:-210; w:292; h:340; anchor: ANC_middle );
	ZONE_FHQInfo: DynamicRect = (dx:30; dY:-210; W: 250; H: 340; anchor: ANC_middle);
    ZONE_FHQMenu1: DynamicRect = ( dx:-280; dy:-210; w:292; h:180; anchor: ANC_middle );
    ZONE_FHQMenu2: DynamicRect = ( dx:-280; dy: -15; w:292; h:145; anchor: ANC_middle );

	ZONE_BPTotal: DynamicRect = (dx:-285; dY:-215; W: 570; H: 350; anchor: ANC_middle);
    ZONE_BPHeader: DynamicRect = (dx:-280; dY:-210; W: 292; H: 40; anchor: ANC_middle);
	ZONE_EqpMenu: DynamicRect = ( dx:-280; dy:-165; w:292; h:100; anchor: ANC_middle );
	ZONE_InvMenu: DynamicRect = ( dx:-280; dy:-60; w:292; h:145; anchor: ANC_middle );
	ZONE_BPInstructions: DynamicRect = (dx:-280; dY:90; W: 292; H: 40; anchor: ANC_middle);
	ZONE_BPInfo: DynamicRect = (dx:30; dY:-210; W: 250; H: 340; anchor: ANC_middle);

    ZONE_ShopNPCName: DynamicRect = ( dx:-330; dy: -230; w: 100; h: 16; anchor: ANC_middle );
    ZONE_ShopNPCPortrait: DynamicRect = ( dx:-330; dy: -210; w: 100; h: 150; anchor: ANC_middle );
    ZONE_ShopText: DynamicRect = ( dx:-225; dy: -230; w: 287; h: 170; anchor: ANC_middle );
    ZONE_ShopPCName: DynamicRect = ( dx:-330; dy: -30; w: 100; h: 16; anchor: ANC_middle );
    ZONE_ShopPCPortrait: DynamicRect = ( dx:-330; dy: -10; w: 100; h: 150; anchor: ANC_middle );
    ZONE_ShopMenu: DynamicRect = ( dx:-225; dy: -30; w: 287; h: 190; anchor: ANC_middle );

	ZONE_ShopInfo: DynamicRect = (dx:85; dY:-225; W: 250; H: 340; anchor: ANC_middle);
    ZONE_ShopCash: DynamicRect = ( dx:135; dy: 130; w: 150; h: 16; anchor: ANC_middle );
    ZONE_ShopTop: DynamicRect = ( dx:-335; dy: -235; w: 402; h: 180; anchor: ANC_middle );
    ZONE_ShopBottom: DynamicRect = ( dx:-335; dy: -35; w: 402; h: 180; anchor: ANC_middle );

	ZONE_MoreText: DynamicRect = ( dx:-350; dy:-270; w: 700 ; h: 385; anchor: ANC_middle );
	ZONE_MorePrompt: DynamicRect = ( dx:-300; dy: 130 ; w:600; h:30; anchor: ANC_middle );

	ZONE_YesNoTotal: DynamicRect = ( dx:-180; dy:-155; w:360; h:265; anchor: ANC_middle );
	ZONE_YesNoPrompt: DynamicRect = ( dx:-175; dy:-150; w:350; h:200; anchor: ANC_middle );
	ZONE_YesNoMenu: DynamicRect = ( dx:-175; dy:55; w:350; h:50; anchor: ANC_middle );

	Console_History_Length = 240;

	GH_REPEAT_DELAY = 200;
	GH_REPEAT_INTERVAL = 50;

    {Color set constants.}
	CS_Clothing = 1;
	CS_Skin = 2;
	CS_Hair = 3;
	CS_PrimaryMecha = 4;
	CS_SecondaryMecha = 5;
	CS_Detailing = 6;


var
	Game_Screen: PSDL_Surface;
	Mouse_Pointer: PSDL_Surface;
	Game_Font,Info_Font: PTTF_Font;
	Game_Sprites,Cursor_Sprite: SensibleSpritePtr;
	Text_Messages: SAttPtr;
	Console_History: SAttPtr;
	Mouse_X, Mouse_Y: LongInt;	{ Current mouse position. }
	Animation_Phase: Integer;
	Last_Clock_Update: UInt32;

    MasterColorList: SAttPtr;

	Music_List: SAttPtr;
{	MyMusic: P_Mix_Music;}

Function RandomColorString( ColorSet: Integer ): String;


Procedure GHFlip;

Procedure DisposeSpriteList(var LList: SensibleSpritePtr);
Procedure RemoveSprite(var LMember: SensibleSpritePtr);
Procedure CleanSpriteList;
procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
procedure DrawAlphaSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
Function ConfirmSprite( Name: String; const Color: String; W,H: Integer ): SensibleSpritePtr;

function RPGKey: Char;
Procedure ClrZone( var Z: TSDL_Rect );
Procedure ClrScreen;

Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean; MyFont: PTTF_Font ): PSDL_Surface;

Procedure QuickText( const msg: String; MyDest: TSDL_Rect; Color: TSDL_Color );
Procedure QuickTinyText( const msg: String; MyDest: TSDL_Rect; Color: TSDL_Color );
Procedure CMessage( const msg: String; Z: TSDL_Rect; C: TSDL_Color );
Procedure GameMSG( const msg: string; Z: TSDL_Rect; var C: TSDL_Color );
Procedure GameMSG( const msg: string; Z: TSDL_Rect; var C: TSDL_Color; MyFont: PTTF_FONT );

Function DirKey( ReDrawer: RedrawProcedureType ): Integer;
Procedure EndOfGameMoreKey;
Function TextLength( F: PTTF_Font; const msg: String ): LongInt;

Procedure RedrawConsole;
Procedure DialogMSG(msg: string); {can't const}

Function GetStringFromUser( const Prompt: String; ReDrawer: RedrawProcedureType ): String;
Function MsgString( const MsgLabel: String ): String;
Function MoreHighFirstLine( LList: SAttPtr ): Integer;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer; ReDrawer: RedrawProcedureType );

Procedure ClearExtendedBorder( Dest: TSDL_Rect );
Procedure InfoBox( MyBox: TSDL_Rect );

Procedure DrawBPBorder;
Procedure DrawCharGenBorder;
Procedure SetupCombatDisplay;
Procedure SetupHQDisplay;
Procedure SetupFactoryDisplay;
Procedure SetupYesNoDisplay;
Procedure SetupInteractDisplay( TeamColor: TSDL_Color );
Procedure SetupMemoDisplay;

Procedure SetupWizardDisplay();

implementation

const
	WindowName: PChar = 'GearHead Arena SDL Version';
	IconName: PChar = 'GearHead';

var
	Infobox_Border,Infobox_Backdrop: SensibleSpritePtr;

Function DynamicRect.GetRect: TSDL_Rect;
    { Return the TSDL_Rect described by this DynamicRect, given the current }
    { screen size. }
var
    MyRect: TSDL_Rect;
begin
    MyRect.W := Self.W;
    MyRect.H := Self.H;
    MyRect.X := Game_Screen^.W * (self.anchor mod 3) div 2 + Self.DX;
    MyRect.Y := Game_Screen^.H * (self.anchor div 3) div 2 + Self.DY;
    GetRect := MyRect;
end;

Function RandomColorString( ColorSet: Integer ): String;
	{ Select a random color string belonging to the provided color set. }
var
    C,Candidates: SAttPtr;
    it: String;
begin
    Candidates := Nil;
    C := MasterColorList;

	while C <> Nil do begin
		if ( Length( C^.Info ) > 6 ) and ( C^.Info[ ColorSet ] = '+' ) then begin
			StoreSAtt( Candidates, RetrieveAString( C^.Info ) );
		end;
		C := C^.Next;
	end;

	if Candidates <> Nil then begin
		it := SelectRandomSAtt( Candidates )^.Info;
	end else begin
        it := '100 100 100';
	end;
    DisposeSAtt( Candidates );
    RandomColorString := it;
end;


Procedure GHFlip;
	{ Copy from the GH screen bitmap to the actual screen. }
var
	MyDest: TSDL_Rect;
begin
	SDL_PumpEvents;
	SDL_GetMouseState( Mouse_X , Mouse_Y );
	MyDest.X := Mouse_X;
	MyDest.Y := Mouse_Y;

	{ If a mouse pointer is defined, draw it. }
	if Mouse_Pointer <> Nil then begin
		SDL_BlitSurface( Mouse_Pointer , Nil , Game_Screen , @MyDest );
	end;

	SDL_Flip( game_Screen );
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

Procedure RedefinePalette( MyImage: PSDL_Surface; RSwap,YSwap,GSwap: PSDL_Color );
	{ For a paletted image, redefine the bitmap. }
var
	MyPal: Array [0..255] of TSDL_Color;
	T: Integer;
begin
	{ Redefine the palette. }
	for t := 1 to 64 do begin
		MyPal[ T - 1 ].r := ( t * 4 ) - 1;
		MyPal[ T - 1 ].g := ( t * 4 ) - 1;
		MyPal[ T - 1 ].b := ( t * 4 ) - 1;

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
	SDL_SetPalette( MyImage , SDL_LOGPAL or SDL_PHYSPAL , MyPal , 0 , 256 );
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


Function LocateSpriteByNameColor( const name,color: String ): SensibleSpritePtr;
	{ Locate the sprite which matches the name provided. }
	{ If no such sprite exists, return Nil. }
var
	S: SensibleSpritePtr;
begin
	S := Game_Sprites;
	while ( S <> Nil ) and ( ( S^.Name <> name ) or ( S^.Color <> Color ) ) do begin
		S := S^.Next;
	end;
	LocateSpriteByNameColor := S;
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
	it^.Color := '';
	Game_Sprites := it;
	NewSprite := it;
end;

Function AddSprite( name, color: String; W,H: Integer ): SensibleSpritePtr;
	{ Add a new element to the Sprite List. Load the image for this sprite }
	{ from disk, if possible. }
var
	fname: PChar;
	it: SensibleSpritePtr;
	tmp: PSDL_Surface;
	RSwap,YSwap,GSwap: TSDL_Color;
begin
	{Allocate memory for our new element.}
	it := NewSprite;
	if it = Nil then Exit( Nil );
	it^.Name := Name;
	it^.Color := Color;
	it^.W := W;
	it^.H := H;

	name := FSearch( name , Graphics_Directory );

	if name <> '' then begin
		fname := QuickPCopy( name );

		{ Attempt to load the image. }
		it^.Img := IMG_Load( fname );

		if it^.Img <> Nil then begin
			{ Set transparency color. }
			SDL_SetColorKey( it^.Img , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( it^.Img^.Format , 0 , 0, 255 ) );

			{ If a color swap has been specified, handle that here. }
			if Color <> '' then begin
				GenerateColor( Color , RSwap );
				GenerateColor( Color , YSwap );
				GenerateColor( Color , GSwap );

				if UseAdvancedColoring and ( it^.Img^.format^.palette <> Nil ) then begin
					RedefinePalette( it^.Img , @RSwap , @YSwap , @GSwap );
				end else begin
					tmp := MakeSwapBitmap( it^.Img , @RSwap , @YSwap , @GSwap );
					SDL_FreeSurface( it^.Img );
					it^.img := tmp;
				end;

			end;

			{ Convert to the screen mode. }
			{ This will make blitting far quicker. }
			tmp := SDL_ConvertSurface( it^.Img , Game_Screen^.Format , SDL_SRCCOLORKEY );
			SDL_FreeSurface( it^.Img );
			it^.Img := TMP;

		end;

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

Procedure CleanSpriteList;
	{ Go through the sprite list and remove those sprites we aren't likely to }
	{ need immediately... i.e., erase those ones which have a COLOR string defined. }
var
	S,S2: SensibleSpritePtr;
begin
	S := Game_Sprites;
	while S <> Nil do begin
		S2 := S^.Next;

		if ( S^.Color <> '' ) or ( S^.img = Nil ) then begin
			RemoveSprite( S );
		end;

		S := S2;
	end;
end;

Procedure DrawAnimImage( Image: PSDL_Surface; W,H,Frame: Integer; var MyDest: TSDL_Rect );
	{ This procedure is modeled after the command from Blitz Basic. }
var
	MySource: TSDL_Rect;
begin
	MySource.W := W;
	MySource.H := H;
	if W > Image^.W then W := Image^.W;
	MySource.X := ( Frame mod ( Image^.W div W ) ) * W;
	MySource.Y := ( Frame div ( Image^.W div W ) ) * H;

	SDL_BlitSurface( Image , @MySource , Game_Screen , @MyDest );
end;

procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		DrawAnimImage( Spr^.Img , Spr^.W , Spr^.H , Frame , MyDest );
	end;
end;

procedure DrawAlphaSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		SDL_SetAlpha( Spr^.Img , SDL_SRCAlpha , Alpha_Level );
		DrawAnimImage( Spr^.Img , Spr^.W , Spr^.H , Frame , MyDest );
		SDL_SetAlpha( Spr^.Img , SDL_SRCAlpha , SDL_Alpha_Opaque );
	end;
end;

Function ConfirmSprite( Name: String; const Color: String; W,H: Integer ): SensibleSpritePtr;
	{ Try to locate the requested sprite in the requested color. If the sprite }
	{ is already loaded, then return its address. If not, load it and color it. }
var
	S: SensibleSpritePtr;
begin
	{ First, find the sprite. If by some strange chance it hasn't been }
	{ loaded yet, load it now. }
	S := LocateSpriteByNameColor( Name , Color );
	if S = Nil then S := AddSprite( Name , Color , W , H );

	{ Set the width and height fields. }
	S^.W := W;
	S^.H := H;

	ConfirmSprite := S;
end;


function RPGKey: Char;
	{ Read a readable key from the keyboard and return its ASCII value. }
var
	a: String;
	event : TSDL_Event;
	m2: PChar;
    width,height: Integer;
    pmsg: PChar;
begin
	a := '';
	repeat
		{ Wait for events. }
		if SDL_PollEvent( @event ) = 1 then begin
			{ See if this event is a keyboard one... }
			if event.type_ = SDL_KEYDOWN then begin
				{ Check to see if it was an ASCII character we received. }
				case event.key.keysym.sym of
					SDLK_F1:    begin
                                pmsg := QuickPCopy( Config_Directory + replacehash('Demo#.bmp',Bstr(animation_phase)) );
                        		SDL_SaveBmp( Game_Screen , pmsg );
                                Dispose( pmsg );
                                end;
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
				{ Return a mousebutton event. }
				if event.button.button = SDL_BUTTON_LEFT then begin
					a := RPK_MouseButton;
				end else if event.button.button = SDL_BUTTON_RIGHT then begin
					a := RPK_RightButton;
				end;

            end else if event.type_ = SDL_VIDEORESIZE then begin
                width := event.resize.w;
                if width < 800 then width := 800;
                height := event.resize.h;
                if height < 600 then height := 600;
                Game_Screen := SDL_SetVideoMode(width, height, 0, SDL_HWSURFACE or SDL_DoubleBuf or SDL_RESIZABLE );

			end;

		end else begin
			if SDL_GetTicks < ( Last_Clock_Update + 20 ) then SDL_Delay( Last_Clock_Update + 30 - SDL_GetTicks );
			Last_Clock_Update := SDL_GetTicks + 30;
			Animation_Phase := ( Animation_Phase + 1 ) mod 6000;
			a := RPK_TimeEvent;

		end;

	{ Keep going until either a character is found, or an error is reported. }
	until ( a <> '' );

	{ Possibly load music now. }
{	if ( Music_List <> Nil ) and ( Mix_PlayingMusic() = 0 ) then begin
		if MyMusic <> Nil then MIX_FreeMusic( MyMusic );
		m2 := QuickPCopy( SelectRandomSAtt( Music_List )^.info );
		MyMusic := MIX_LoadMus( m2 );
		Dispose( m2 );
		Mix_PlayMusic( MyMusic , 1 );
	end;}

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
	SDL_FillRect( game_screen , Nil , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
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

Procedure GetNextLine( var TheLine , msg , NextWord: String; Width: Integer; MyFont: PTTF_Font );
	{ Get a line of text of maximum width "Width". }
var
	LC: Boolean;	{ Loop Condition. So I wasn't very creative when I named it, so what? }
begin
	{ Loop condition starts out as TRUE. }
	LC := True;

	{ Start building the line. }
	repeat
		NextWord := ExtractWord( Msg );

		if TextLength( MyFont , THEline + ' ' + NextWord) < Width then
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

{Can't const}
Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean; MyFont: PTTF_Font ): PSDL_Surface;
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
		GetNextLine( TheLine , msg , NextWord , Width, MyFont );

		{ Output the line. }
		{ Next append it to whatever has already been created. }
		StoreSAtt( SList , TheLine );

		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }

	{ Create a bitmap for the message. }
	if SList <> Nil then begin
		{ Create a big bitmap to hold everything. }
{		S_Total := SDL_CreateRGBSurface( SDL_SWSURFACE , width , TTF_FontLineSkip( MyFont ) * NumSAtts( SList ) , 16 , 0 , 0 , 0 , 0 );
}		S_Total := SDL_CreateRGBSurface( SDL_SWSURFACE , width , TTF_FontLineSkip( MyFont ) * NumSAtts( SList ) , 32 , $FF000000 , $00FF0000 , $0000FF00 , $000000FF );
		MyDest.X := 0;
		MyDest.Y := 0;

		{ Add each stored string to the bitmap. }
		SA := SList;
		while SA <> Nil do begin
			pline := QuickPCopy( SA^.Info );
			S_Temp := TTF_RenderText_Solid( MyFont , pline , fg );
{$IFDEF LINUX}
			SDL_SetColorKey( S_Temp , SDL_SRCCOLORKEY , SDL_MapRGB( S_Temp^.Format , 0 , 0, 0 ) );
{$ENDIF}

			Dispose( pline );

			{ We may or may not be required to do centering of the text. }
			if DoCenter then begin
				MyDest.X := ( Width - TextLength( MyFont , SA^.Info ) ) div 2;
			end else begin
				MyDest.X := 0;
			end;

			SDL_BlitSurface( S_Temp , Nil , S_Total , @MyDest );
			SDL_FreeSurface( S_Temp );
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( MyFont );
			SA := SA^.Next;
		end;
		DisposeSAtt( SList );

	end else begin
		S_Total := Nil;
	end;


	PrettyPrint := S_Total;
end;

Procedure QuickText( const msg: String; MyDest: TSDL_Rect; Color: TSDL_Color );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( game_font , pline , Color );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure QuickTinyText( const msg: String; MyDest: TSDL_Rect; Color: TSDL_Color );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( info_font , pline , Color );
	Dispose( pline );
	MyDest.X := MyDest.X - ( MyText^.W div 2 );
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure CMessage( const msg: String; Z: TSDL_Rect; C: TSDL_Color );
	{ Print a message to the screen, centered in the requested rect. }
	{ Clear the specified zone before doing so. }
var
	MyText: PSDL_Surface;
	MyDest: TSDL_Rect;
begin
	MyText := PrettyPrint( msg , Z.W , C , True, game_font );
	if MyText <> Nil then begin
		MyDest := Z;
		MyDest.Y := MyDest.Y + ( Z.H - MyText^.H ) div 2;
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;


Procedure GameMSG( const msg: string; Z: TSDL_Rect; var C: TSDL_Color; MyFont: PTTF_FONT );
	{ Print a line-justified message in the requested screen zone. }
	{ Clear the specified zone before doing so. }
var
	MyText: PSDL_Surface;
begin
	{ClrZone( Z );}
	MyText := PrettyPrint( msg , Z.W , C , False, MyFont );
	if MyText <> Nil then begin
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @Z );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Procedure GameMSG( const msg: string; Z: TSDL_Rect; var C: TSDL_Color );
    { Call the above procedure with the default font. }
begin
    GameMSG( msg, Z, C, game_font );
end;

Function DirKey( ReDrawer: RedrawProcedureType ): Integer;
	{ Get a direction selection from the user. If a standard direction }
	{ key was selected, return its direction (0 is East, increase }
	{ clockwise). See Locale.pp for details. }
	{ Return -1 if no good direction was chosen. }
var
	K: Char;
begin
	repeat
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
		end else if K = RPK_TimeEvent then begin
			ReDrawer;
			DirKey := -2;
		end else begin
			DirKey := -1;
		end;
	until DirKey <> -2;
end;

Procedure EndOfGameMoreKey;
	{ The end of the game has been reached. Wait for the user to }
	{ press either the space bar or the ESC key. }
var
	A: Char;
begin
	{ Keep reading keypresses until either a space or an ESC/Backspace is found. }
	repeat
		A := RPGKey;
	until ( A = ' ' ) or ( A = #27 ) or ( A = #8 );
end;

Procedure RedrawConsole;
	{ Redraw the console. Yay! }
var
	SL: SAttPtr;
	MyDest: TSDL_Rect;
	NumLines,LineNum: Integer;
begin
	SDL_SetClipRect( Game_Screen , @ZONE_Dialog );

	MyDest := ZONE_Dialog;
	NumLines := ( ZONE_Dialog.H div TTF_FontLineSkip( game_font ) ) + 1;
	LineNum := NumLines;
	SL := RetrieveSAtt( Console_History , NumSAtts( Console_History ) - NumLines + 1 );
	if SL = Nil then begin
		SL := Console_History;
		LineNum := NumSAtts( Console_History );
	end;

	while LineNum > 0 do begin
		{ Set the coords for this line. }
		MyDest.X := ZONE_Dialog.X;
		MyDest.Y := ZONE_Dialog.Y + ZONE_Dialog.H - LineNum * TTF_FontLineSkip( game_font );

		{ Output the line. }
		QuickText( SL^.Info , MyDest , InfoGreen );

		Dec( LineNum );
		SL := SL^.Next;
	end;

	{ Restore the clip zone to the full screen. }
	SDL_SetClipRect( Game_Screen , Nil );
end;


Procedure DialogMSG( msg: string );
	{ Print a message in the scrolling dialog box, }
	{ then store the line in Console_History. }
	{ Don't worry about screen output since the console will be redrawn the next time }
	{ the screen updates. }
var
	NextWord: String;
	THELine: String;	{The line under construction.}
	SA: SAttPtr;
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	if msg = '' then Exit;
	msg := '> ' + Msg;

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );
	NextWord := '';

	{Start the main processing loop.}
	while TheLine <> '' do begin
		GetNextLine( TheLine , msg , NextWord , ZONE_Dialog.w, Game_Font );

		{ If appropriate, save the line. }
		if TheLine <> '' then begin
			if NumSAtts( Console_History ) >= Console_History_Length then begin
				SA := Console_History;
				RemoveSAtt( Console_History , SA );
			end;
			StoreSAtt( Console_History , TheLine );
		end;


		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }
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

Function GrowRect( MyRect: TSDL_Rect; GrowX,GrowY: Integer ): TSDL_Rect;
    { Expand this rect by the requested amount, remaining centered on the }
    { original rect. }
begin
    MyRect.x := MyRect.x - GrowX;
    MyRect.y := MyRect.y - GrowY;
    MyRect.w := MyRect.w + 2 * GrowX;
    MyRect.h := MyRect.h + 2 * GrowY;
    GrowRect := MyRect;
end;

Procedure FillRectWithSprite( MyRect: TSDL_Rect; MySprite: SensibleSpritePtr; MyFrame: Integer );
    { Fill this area of the screen perfectly with the provided sprite. }
var
    MyDest: TSDL_Rect;
    X,Y,GridW,GridH: Integer;
begin
	GridW := MyRect.W div MySprite^.W + 1;
	GridH := MyRect.H div MySprite^.H + 1;
	SDL_SetClipRect( Game_Screen , @MyRect );

	{ Draw the backdrop. }
	for X := 0 to GridW do begin
		MyDest.X := MyRect.X + X * MySprite^.W;
		for Y := 0 to GridH do begin
			MyDest.Y := MyRect.Y + Y * MySprite^.H;
			DrawSprite( MySprite , MyDest , MyFrame );
		end;
	end;

	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure InfoBox( MyBox: TSDL_Rect );
	{ Do a box for drawing something else inside of. }
const
	tex_width = 16;
	border_width = tex_width div 2;
	half_dat = border_width div 2;
var
    MyFill,Dest: TSDL_Rect;
	X0,Y0,W32,H32,X,Y: Integer;
begin
    { Fill the middle of the box with the backdrop. }
    MyFill := GrowRect( MyBox, 4, 4 );
    FillRectWithSprite( MyFill, Infobox_Backdrop, 0 );

    { Expand the rect to its full dimensions, and draw the outline. }
    MyFill := GrowRect( MyBox, 8, 8 );
	DrawSprite( Infobox_Border , MyFill , 0 );

    Dest.X := MyFill.X;
	Dest.Y := MyFill.Y + MyFill.H - 8;
	DrawSprite( Infobox_Border , Dest , 4 );

    Dest.X := MyFill.X + MyFill.W - 8;
	Dest.Y := MyFill.Y;
	DrawSprite( Infobox_Border , Dest , 3 );

    Dest.X := MyFill.X + MyFill.W - 8;
	Dest.Y := MyFill.Y + MyFill.H - 8;
	DrawSprite( Infobox_Border , Dest , 5 );

    MyFill := GrowRect( MyBox, 0, 8 );
	SDL_SetClipRect( Game_Screen , @MyFill );
	for X := 0 to ( MyFill.W div 8 + 1 ) do begin
		Dest.X := MyFill.X + X * 8;
		Dest.Y := MyFill.Y;
		DrawSprite( Infobox_Border , Dest , 1 );
		Dest.Y := MyFill.Y + MyFill.H - 8;
		DrawSprite( Infobox_Border , Dest , 1 );
	end;
    MyFill := GrowRect( MyBox, 8, 0 );
	SDL_SetClipRect( Game_Screen , @MyFill );
	for Y := 0 to ( MyFill.H div 8 + 1 ) do begin
		Dest.Y := MyFill.Y + Y * 8;
		Dest.X := MyFill.X;
		DrawSprite( Infobox_Border , Dest , 2 );
		Dest.X := MyFill.X + MyFill.W - 8;
		DrawSprite( Infobox_Border , Dest , 2 );
	end;
	SDL_SetClipRect( Game_Screen , Nil );
end;


Function GetStringFromUser(const Prompt: String; ReDrawer: RedrawProcedureType ): String;
	{ Does what it says. }
const
	AllowableCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890()-=_+,.?"*';
	MaxInputLength = 80;
var
	A: Char;
	it: String;
	MyBigBox,MyInputBox,MyDest: TSDL_Rect;
begin
	{ Initialize string. }
	it := '';

	repeat
        MyBigBox := ZONE_TextInputBigBox.GetRect();
        MyInputBox := ZONE_TextInput.GetRect();

		{ Set up the display. }
		if ReDrawer <> Nil then ReDrawer;
		InfoBox( MyBigBox );
		{SDL_FillRect( game_screen , @MyBigBox , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );}
		SDL_FillRect( game_screen , @MyInputBox , SDL_MapRGB( Game_Screen^.Format , StdBlack.R , StdBlack.G , StdBlack.B ) );

		CMessage( Prompt , ZONE_TextInputPrompt.GetRect() , StdWhite );
		CMessage( it , MyInputBox , InfoGreen );
		MyDest.Y := MyInputBox.Y + 2;
		MyDest.X := MyInputBox.X + ( MyInputBox.W div 2 ) + ( TextLength( Game_Font , it ) div 2 );
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

Function MsgString(const MsgLabel: String ): String;
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
	it := NumSAtts( LList ) - ( ZONE_MoreText.H  div  TTF_FontLineSkip( game_font ) ) + 1;
	if it < 1 then it := 1;
	MoreHighFirstLine := it;
end;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer; ReDrawer: RedrawProcedureType );
	{ Browse this text file across the majority of the screen. }
	{ Clear the screen upon exiting, though restoration of the }
	{ previous display is someone else's responsibility. }
	Procedure DisplayTextHere( const MyZone: TSDL_Rect );
	var
		T: Integer;
		MyDest: TSDL_Rect;
		MyImage: PSDL_Surface;
		CLine: SAttPtr;	{ Current Line }
		PLine: PChar;
	begin
		{ Set the clip area. }
		SDL_SetClipRect( Game_Screen , @MyZone );
		MyDest := MyZone;

		{ Error check. }
		if FirstLine < 1 then FirstLine := 1
		else if FirstLine > MoreHighFirstLine( LList ) then FirstLine := MoreHighFirstLine( LList );

		CLine := RetrieveSATt( LList , FirstLine );
		for t := 1 to ( MyZone.H  div  TTF_FontLineSkip( game_font ) ) do begin
			if CLine <> Nil then begin
				pline := QuickPCopy( CLine^.Info );
				MyImage := TTF_RenderText_Solid( game_font , pline , NeutralGrey );
				Dispose( pline );
                {$IFDEF LINUX}
		        SDL_SetColorKey( MyImage , SDL_SRCCOLORKEY , SDL_MapRGB( MyImage^.Format , 0 , 0, 0 ) );
                {$ENDIF}

				SDL_BlitSurface( MyImage , Nil , Game_Screen , @MyDest );
				SDL_FreeSurface( MyImage );
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( game_font );
				CLine := CLine^.Next;
			end;
		end;

        if (Animation_Phase div 10 mod 2) = 1 then begin
            if FirstLine > 1 then begin
                MyDest.X := MyZone.X + MyZone.W - 16;
                MyDest.Y := MyZone.Y;
                QuickText('+', MyDest, MenuSelect );
            end;
            if CLine <> Nil then begin
                MyDest.X := MyZone.X + MyZone.W - 16;
                MyDest.Y := MyZone.Y + MyZone.H - TTF_FontLineSkip( game_font );
                QuickText('+', MyDest, MenuSelect );
            end;
        end;

		{ Restore the clip area. }
		SDL_SetClipRect( Game_Screen , Nil );
		GHFlip;
	end;
var
	A: Char;
    MyPromptZone,MyTextZone: TSDL_Rect;
begin
	repeat
		{ Get input from user. }
		A := RPGKey;

		{ Possibly process this input. }
		if A = RPK_Down then begin
			Inc( FirstLine );
		end else if A = RPK_Up then begin
			Dec( FirstLine );
        end else if A = RPK_TimeEvent then begin
            MyTextZone := ZONE_MoreText.GetRect();
            MyPromptZone := ZONE_MorePrompt.GetRect();
            if Redrawer <> Nil then Redrawer();
            InfoBox( MyTextZone );
            InfoBox( MyPromptZone );
	        CMessage( MsgString( 'MORETEXT_Prompt' ) , MyPromptZone , InfoGreen );

	        { Display the screen. }
	        DisplayTextHere( MyTextZone );
		end;

	until ( A = #27 ) or ( A = 'Q' ) or ( A = #8 );
end;

Procedure DrawBPBorder;
	{ Draw borders for the backpack display. }
var
    MyRect: TSDL_Rect;
begin
    MyRect := ZONE_BPTotal.GetRect();
	ClearExtendedBorder( MyRect );
	SDL_FillRect( game_screen , @MyRect , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );
	ClearExtendedBorder( ZONE_EqpMenu.GetRect() );
	ClearExtendedBorder( ZONE_InvMenu.GetRect() );
	ClearExtendedBorder( ZONE_BPHeader.GetRect() );
	ClearExtendedBorder( ZONE_BPInstructions.GetRect() );
	ClearExtendedBorder( ZONE_BPInfo.GetRect() );
    FillRectWithSprite( ZONE_BPInfo.GetRect(), Infobox_Backdrop, 0 );
end;


Procedure DrawCharGenBorder;
	{ Draw borders for the character generator. }
begin
	SDL_FillRect( game_screen , Nil , SDL_MapRGB( Game_Screen^.Format , 47 , 64 , 91 ) );
	InfoBox( ZONE_CharGenChar.GetRect() );
	InfoBox( ZONE_CharGenMenu.GetRect() );
	InfoBox( ZONE_CharGenDesc.GetRect() );
	InfoBox( ZONE_CharGenPrompt.GetRect() );
	InfoBox( ZONE_CharGenCaption.GetRect() );
end;

Procedure SetupCombatDisplay;
	{ Draw the combat background. }
begin
{	SDL_FillRect( game_screen , Nil , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );
	ClearExtendedBorder( ZONE_Map );
	ClearExtendedBorder( ZONE_Info );
	ClearExtendedBorder( ZONE_Menu );
	ClearExtendedBorder( ZONE_Dialog );
	ClearExtendedBorder( ZONE_Clock );}
end;

Procedure SetupHQDisplay;
begin
end;
Procedure SetupFactoryDisplay;
begin
end;

Procedure SetupYesNoDisplay;
	{ Draw an outline around the YesNoMenu display area. }
begin
	ClearExtendedBorder( ZONE_YesNoTotal.GetRect() );
	SDL_FillRect( game_screen , @ZONE_YesNoTotal , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );
	ClearExtendedBorder( ZONE_YesNoPrompt.GetRect() );
	ClearExtendedBorder( ZONE_YesNoMenu.GetRect() );
end;

Procedure SetupMemoDisplay;
	{ Draw an outline around the memo display. Fortunately, that's the same region as the }
	{ YesNo display. }
begin
	InfoBox( ZONE_MemoTotal.GetRect() );
end;

Procedure SetupInteractDisplay( TeamColor: TSDL_Color );
	{ Draw the display for the interaction interface. }
var
    MyDest: TSDL_Rect;
begin
    MyDest := ZONE_InteractTotal.GetRect();
	ClearExtendedBorder( MyDest );
	SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , TeamColor.R , TeamColor.G , TeamColor.B ) );
	ClearExtendedBorder( ZONE_InteractStatus.GetRect() );
	ClearExtendedBorder( ZONE_InteractMsg.GetRect() );
	ClearExtendedBorder( ZONE_InteractMenu.GetRect() );
	ClearExtendedBorder( ZONE_InteractPhoto.GetRect() );
	ClearExtendedBorder( ZONE_InteractInfo.GetRect() );
end;

Procedure SetupWizardDisplay();
    { This procedure will set the Wizard display decorations and resize all }
    { the relevant game zones. Yay? }
var
    MyRect: TSDL_Rect;
    Procedure AddHorizontalDivider( Y: Integer );
        { Add a divider to the Wizard UI. }
    var
        Dest: TSDL_Rect;
        X: Integer;
    begin
        Dest.X := MyRect.X-8;
        Dest.Y := Y;
        DrawSprite( Infobox_Border, Dest, 6 );
        Dest.X := MyRect.X + MyRect.W;
        DrawSprite( Infobox_Border, Dest, 7 );

        Dest := GrowRect( MyRect, 0, 8 );
	    SDL_SetClipRect( Game_Screen , @Dest );
	    Dest.Y := Y;
	    for X := 0 to ( MyRect.W div 8 + 1 ) do begin
		    Dest.X := MyRect.X + X * 8;
		    DrawSprite( Infobox_Border , Dest , 1 );
	    end;
	    SDL_SetClipRect( Game_Screen , Nil );
    end;
    Procedure AddVerticalDivider( X: Integer );
        { Add a divider to the Wizard UI. }
    var
        Dest: TSDL_Rect;
        Y: Integer;
    begin
        Dest.X := X;
        Dest.Y := MyRect.Y-8;
        DrawSprite( Infobox_Border, Dest, 8 );
        Dest.Y := MyRect.Y + MyRect.H;
        DrawSprite( Infobox_Border, Dest, 9 );

        Dest := GrowRect( MyRect, 8, 0 );
	    SDL_SetClipRect( Game_Screen , @Dest );
	    Dest.X := X;
	    for Y := 0 to ( MyRect.H div 8 + 1 ) do begin
		    Dest.Y := MyRect.Y + Y * 8;
		    DrawSprite( Infobox_Border , Dest , 2 );
	    end;
	    SDL_SetClipRect( Game_Screen , Nil );
    end;
begin
    MyRect.X := Game_Screen^.w div 2 - 390;
    MyRect.Y := Game_Screen^.h - Dialog_Area_Height - 10;
    MyRect.w := 780;
    MyRect.h := Dialog_Area_Height;

    InfoBox( MyRect );

    ZONE_Dialog.x := MyRect.X + Right_Column_Width + 8;
    ZONE_Dialog.y := MyRect.Y;
    ZONE_Dialog.w := MyRect.W - Right_Column_Width - 8;
    ZONE_Dialog.h := Dialog_Area_Height;

    ZONE_Map.X := 0;
    ZONE_Map.Y := 0;
    ZONE_Map.W := Game_Screen^.W;
    ZONE_Map.H := Game_Screen^.H;

    ZONE_Clock.x := MyRect.X;
    ZONE_Clock.y := Game_Screen^.h - 28;

	ZONE_PCInfo.X := MyRect.X;
	ZONE_PCInfo.Y := MyRect.Y;

    AddVerticalDivider( ZONE_Dialog.x - 8 );

{    AddDivider( 160 );
    AddDivider( Game_Screen^.H - 36 );

    if menus > 0 then begin
        AddDivider( ZONE_Menu.Y + ZONE_Menu.H );
        ZONE_Dialog.y := ZONE_Menu.Y + ZONE_Menu.H + 8;
        if menus > 1 then begin
            AddDivider( ZONE_Menu1.Y + ZONE_Menu1.H );
        end;
    end else begin
        ZONE_Dialog.y := 168;
    end;
    ZONE_Dialog.h := Game_Screen^.H - ZONE_Dialog.y - 36;
}
end;


initialization

	SDL_Init( SDL_INIT_VIDEO or SDL_INIT_AUDIO );

	if DoFullScreen then begin
		Game_Screen := SDL_SetVideoMode(ScreenWidth, ScreenHeight, 0, SDL_HWSURFACE or SDL_FULLSCREEN or SDL_DoubleBuf );
		Mouse_Pointer := IMG_Load( Graphics_Directory + 'cosplay_pointer.png' );
		SDL_SetColorKey( Mouse_Pointer , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( Mouse_Pointer^.Format , 0 , 0, 255 ) );
	end else begin
		Game_Screen := SDL_SetVideoMode(ScreenWidth, ScreenHeight, 0, SDL_HWSURFACE or SDL_DoubleBuf or SDL_RESIZABLE );
		Mouse_Pointer := Nil;
	end;

    SDL_EnableUNICODE( 1 );
	SDL_EnableKeyRepeat( GH_REPEAT_DELAY , GH_REPEAT_INTERVAL );


	Game_Sprites := Nil;

	Cursor_Sprite := ConfirmSprite( 'cursor.png' , '' , 8 , 16 );

	TTF_Init;
	Game_Font := TTF_OpenFont( 'Image' + OS_Dir_Separator + 'VeraBd.ttf' , BigFontSize );
	Info_Font := TTF_OpenFont( 'Image' + OS_Dir_Separator + 'VeraMoBd.ttf' , SmallFontSize );

	Text_Messages := LoadStringList( Standard_Message_File );
	Console_History := Nil;

	SDL_WM_SetCaption( WindowName , IconName );

	Animation_Phase := 0;
	Last_Clock_Update := 0;

	MasterColorList := LoadStringList( Data_Directory + 'sdl_colors.txt' );

	Infobox_Border := ConfirmSprite( 'sys_boxborder.png' , '', 8 , 8 );
	Infobox_Backdrop := ConfirmSprite( 'sys_boxbackdrop.png' , '', 16 , 16 );

	SDL_SetAlpha( Infobox_Backdrop^.Img , SDL_SRCAlpha , 224 );

{	MIX_OpenAudio( MIX_DEFAULT_FREQUENCY , MIX_DEFAULT_FORMAT , MIX_CHANNELS , 4096 );
	Music_List := LoadStringList( 'music.cfg' );
	MyMusic := Nil;
}
finalization

{	if MyMusic <> Nil then MIX_FreeMusic( MyMusic );
	MIX_CloseAudio;
	DisposeSAtt( Music_List );
}
	DisposeSpriteList( Game_Sprites );
	TTF_CloseFont( Game_Font );
	TTF_CloseFont( Info_Font );
	TTF_Quit;

	if Mouse_Pointer <> Nil then SDL_FreeSurface( Mouse_Pointer );

	SDL_FreeSurface( Game_Screen );
	SDL_Quit;

	DisposeSAtt( Text_Messages );
	DisposeSAtt( Console_History );

    DisposeSAtt( MasterColorList )

end.
