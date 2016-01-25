Program cosplay;
{$APPTYPE GUI}
{$DEFINE SDLMODE}

uses sdl,sdlgfx,sdlmenus,gears,texutil,ui4gh,sdl_image;



const
	NumStandardColors = 35;

	StandardColors: Array [1..NumStandardColors] of TSDL_Color = (
	( r:200; g:  0; b:  0 ) , ( r:200; g:200; b:  0 ) , ( r:  0; g:200; b:  0 ),
	( r:136; g:141; b:101 ) , ( r: 66; g:121; b:119 ) , ( r:201; g:205; b:229 ),
	( r:235; g:147; b:115 ) , ( r:  1; g: 75; b: 67 ) , ( r: 49; g: 91; b:161 ) ,
	( r:130; g:143; b:114 ) , ( r:103; g:  3; b: 45 ) , ( r: 88; g:113; b: 86 ) ,
	( r:123; g: 63; b:  0 ) , ( r:  6; g: 42; b:120 ) , ( r:199; g:188; b:162 ) ,
	( r:122; g: 88; b:193 ) , ( r: 56; g: 26; b: 81 ) , ( r:157; g:172; b:183 ) ,
	( r:168; g:153; b:230 ) , ( r:150; g:112; b: 89 ) , ( r:244; g:216; b: 28 ) ,
	( r:245; g:213; b:160 ) , ( r:116; g:100; b: 13 ) , ( r: 36; g: 46; b: 22 ) ,
	( r:112; g: 28; b: 28 ) , ( r:255; g:107; b: 83 ) , ( r:166; g: 47; b: 32 ) ,
	( r:152; g: 61; b: 97 ) , ( r:255; g:212; b:195 ) , ( r:208; g: 34; b: 51 ) ,
	( r:234; g:180; b: 88 ) , ( r:142; g: 62; b: 39 ) , ( r: 80; g: 80; b: 85 ) ,
	( r:  0; g:  0; b:  0 ) , ( r:255; g:255; b:255 )
	);

	StandardColorNames: Array [1..NumStandardColors] of String = (
	'Pure Red',		'Pure Yellow',		'Pure Green',
	'Avocado',		'Jade',			'Aero Blue',
	'Apricot',		'Aquamarine',		'Azure',
	'Battleship Grey',	'Black Rose',		'Cactus',
	'Cinnamon',		'Cobalt',		'Coral',
	'Fuschia',		'Grape', 		'Gull Grey',
	'Lavender',		'Leather',		'Lemon',
	'Maize',		'Mustard',		'Olive',
	'Plum',			'Persimmon',		'Terracotta',
	'Wine',			'Light Skin',		'Red Goes Faster',
	'Desert Yellow',	'Chocolate',		'Deep Grey',
	'True Black',		'True White'
	);

	Swap_Colors_X = 400;
	Color_Rows = 5;
	Color_Columns = 11;

	RSwap_Y = 10;
	YSwap_Y = 200;
	GSwap_Y = 390;

	ZONE_Sprite_Display: TSDL_Rect = ( x:10; y:10; w: 380 ; h: 500 );

	ZONE_RSwap_Name: TSDL_Rect = ( x:10; y:400; w: 380 ; h: 20 );
	ZONE_RSwap_Data: TSDL_Rect = ( x:10; y:430; w: 380 ; h: 20 );
	ZONE_YSwap_Name: TSDL_Rect = ( x:10; y:460; w: 380 ; h: 20 );
	ZONE_YSwap_Data: TSDL_Rect = ( x:10; y:490; w: 380 ; h: 20 );
	ZONE_GSwap_Name: TSDL_Rect = ( x:10; y:520; w: 380 ; h: 20 );
	ZONE_GSwap_Data: TSDL_Rect = ( x:10; y:550; w: 380 ; h: 20 );

Function CPRelativeX( T: Integer ): Integer;

begin
	CPRelativeX := ( ( T - 1 ) mod Color_Columns ) * 36;
end;

Function CPRelativeY( T: Integer ): Integer;

begin
	CPRelativeY := ( ( T - 1 ) div Color_Columns ) * 36;
end;

Function StandardColorString( T: Integer ): String;

begin
	StandardColorString := BStr( StandardColors[t].r ) + ' ' + BStr( StandardColors[t].g ) + ' ' + BStr( StandardColors[t].b );
end;

Procedure DrawAllColors( X , Y: Integer );

var
	T: Integer;
	CS: String;
	MyDest: TSDL_Rect;
	SS: SensibleSpritePtr;
begin
	for t := 1 to NumStandardColors do begin
		CS := StandardColorString( T );

		MyDest.X := CPRelativeX( T ) + X;
		MyDest.Y := CPRelativeY( T ) + Y;

		SS := ConfirmSprite( 'cosplay.png' , CS , 36 , 36 );
		DrawSprite( SS , MyDest , 0 );
	end;
end;

Procedure IndicateColor( X , Y , T: Integer; C: String );

var
	MyDest: TSDL_Rect;
	SS: SensibleSpritePtr;
begin
	MyDest.X := CPRelativeX( T ) + X;
	MyDest.Y := CPRelativeY( T ) + Y;
	SS := ConfirmSprite( 'cosplay.png' , C , 36 , 36 );
	DrawSprite( SS , MyDest , 1 );
end;

Procedure DetermineAreaHit( var RSwap , YSwap , GSwap: Integer );
	{ The mouse coordinates are held in MOUSE_X , MOUSE_Y. }
	{ Try to determine which of our brightly colored little boxes were hit. }
var
	X,Y,N: Integer;
begin
	{ Only process mouse hits within zone. }
	if ( Mouse_X >= Swap_Colors_X ) and ( Mouse_X <= ( Swap_Colors_X + Color_Columns * 36 ) ) then begin
		if ( Mouse_Y >= RSwap_Y ) and ( Mouse_Y <= ( RSwap_Y + Color_Rows * 36 ) ) then begin
			X := ( Mouse_X - Swap_Colors_X ) div 36;
			Y := ( Mouse_Y - RSwap_Y ) div 36;
			N := Y * Color_Columns + X + 1;
			if ( N >= 1 ) and ( N <= NumStandardColors ) then begin
				IndicateColor( Swap_Colors_X , RSwap_Y , RSwap, '0 0 0 0 0 0 0 0 0' );
				RSwap := N;
			end;
		end else if ( Mouse_Y >= YSwap_Y ) and ( Mouse_Y <= ( YSwap_Y + Color_Rows * 36 ) ) then begin
			X := ( Mouse_X - Swap_Colors_X ) div 36;
			Y := ( Mouse_Y - YSwap_Y ) div 36;
			N := Y * Color_Columns + X + 1;
			if ( N >= 1 ) and ( N <= NumStandardColors ) then begin
				IndicateColor( Swap_Colors_X , YSwap_Y , YSwap, '0 0 0 0 0 0 0 0 0' );
				YSwap := N;
			end;
		end else if ( Mouse_Y >= GSwap_Y ) and ( Mouse_Y <= ( GSwap_Y + Color_Rows * 36 ) ) then begin
			X := ( Mouse_X - Swap_Colors_X ) div 36;
			Y := ( Mouse_Y - GSwap_Y ) div 36;
			N := Y * Color_Columns + X + 1;
			if ( N >= 1 ) and ( N <= NumStandardColors ) then begin
				IndicateColor( Swap_Colors_X , GSwap_Y , GSwap, '0 0 0 0 0 0 0 0 0' );
				GSwap := N;
			end;
		end;
	end;
end;


Procedure EditSpriteColors( SpriteName: String );

var
	Z: TSDL_Rect;
	A: Char;
	RSwap,YSwap,GSwap: Integer;
	SS: SensibleSpritePtr;
begin
	ClrScreen;
	RSwap := 1;
	YSwap := 2;
	GSwap := 3;
	DrawAllColors( Swap_Colors_X , RSwap_Y );
	DrawAllColors( Swap_Colors_X , YSwap_Y );
	DrawAllColors( Swap_Colors_X , GSwap_Y );

	repeat
		ClrZone( ZONE_Sprite_Display );
		Z := ZONE_Sprite_Display;

		SS := ConfirmSprite(  SpriteName , StandardColorString( RSwap ) + ' ' + StandardColorString( YSwap ) + ' ' + StandardColorString( GSwap )  , Z.W , Z.H );
		DrawSprite( SS , Z , 0 );
{		RemoveSprite( SS );}
		IndicateColor( Swap_Colors_X , RSwap_Y , RSwap, '0 255 255' );
		IndicateColor( Swap_Colors_X , YSwap_Y , YSwap, '0 255 255' );
		IndicateColor( Swap_Colors_X , GSwap_Y , GSwap, '0 255 255' );
		NFCMessage( StandardColorNames[ RSwap ] , ZONE_RSwap_Name , StandardColors[ RSwap ] );
		NFCMessage( StandardColorString( RSwap ) , ZONE_RSwap_Data , StdWhite );
		NFCMessage( StandardColorNames[ YSwap ] , ZONE_YSwap_Name , StandardColors[ YSwap ] );
		NFCMessage( StandardColorString( YSwap ) , ZONE_YSwap_Data , StdWhite );
		NFCMessage( StandardColorNames[ GSwap ] , ZONE_GSwap_Name , StandardColors[ GSwap ] );
		NFCMessage( StandardColorString( GSwap ) , ZONE_GSwap_Data , StdWhite );

		GHFlip;

		A := RPGKey;

		if A = RPK_MouseButton then begin
			DetermineAreaHit( RSwap , YSwap , GSwap );
		end;

	until A = #27;
end;


var
	FileMenu: RPGMenuPtr;
	SpriteName: String;

begin
	Mouse_Pointer := Img_Load( 'Image\cosplay_pointer.png' );
	SDL_SetColorKey( Mouse_Pointer , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( Mouse_Pointer^.Format , 0 , 0, 255 ) );

	FileMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( FileMenu , Graphics_Directory + '*.*' );
	RPMSortAlpha( FileMenu );
	SpriteName := '';

	repeat
		SpriteName := SelectFile( FileMenu , Nil );
		if SpriteName <> '' then EditSpriteColors( SpriteName );

	until SpriteName = '';

	DisposeRPGMenu( FileMenu );
end.
