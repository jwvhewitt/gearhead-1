unit colormenu;
	{ This unit contains the color selector menu code. }
{
	GearHead2, a roguelike mecha CRPG
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

uses 	gears,sdl,sdlgfx;

const
	colormenu_mode_allcolors = 0;
	colormenu_mode_character = 1;
	colormenu_mode_mecha = 2;

	Num_Color_Sets = 6;
	CS_Clothing = 1;
	CS_Skin = 2;
	CS_Hair = 3;
	CS_PrimaryMecha = 4;
	CS_SecondaryMecha = 5;
	CS_Detailing = 6;

type
	ColorDesc = Record
		name: String;
		rgb: TSDL_Color;
		cs: Array [1..Num_Color_Sets] of Boolean;
	end;

var
	Available_Colors: Array of ColorDesc;
	Num_Available_Colors: Integer;
	Num_Colors_Per_Set: Array [1..Num_Color_Sets] of Integer;


Function SelectColorPalette( init_mode: Integer; image_name,color_palette: String; image_width,image_height,anim_frames: Integer; Redrawer: RedrawProcedureType ): String;

implementation

uses texutil,ui4gh;

const
	Swatch_Columns = 20;
	Swatch_Rows = 5;
	Swatch_Width = 16;
	Swatch_Height = 24;

	cm_panel_width = 600;
	cm_panel_height = 456;

	cm_window_dx = -cm_panel_width div 2;
	cm_window_dy = -230;

	cm_image_x_offset = 20;
	cm_image_y_offset = 20;

	{ Relative positioning of the color selection boxes. }
	cm_swatchzone_x_offset = 250;
	cm_swatchzone_y_start = 11;
	cm_swatchzone_height = 145;

	{ Offset from the upper left corner of the selection box }
	{ where the swatch areas start. }
	off_swatches_x = 3;
	off_swatches_y = 19;

	ZONE_colormenu_base: DynamicRect =  ( dx: cm_window_dx; dy: cm_window_dy; w: cm_panel_width; h: cm_panel_height; anchor: ANC_MIDDLE );
	ZONE_colormenu_sprite: DynamicRect =  ( dx: cm_image_x_offset+cm_window_dx; dy: cm_window_dy + cm_image_y_offset; w: 211; h: 308; anchor: ANC_MIDDLE );

	ZONE_colorselectionboxes: Array [1..3] of DynamicRect = (
		( dx: cm_window_dx + cm_swatchzone_x_offset; dy: cm_window_dy + cm_swatchzone_y_start; w: 600; h: 145; anchor: ANC_MIDDLE ),
		( dx: cm_window_dx + cm_swatchzone_x_offset; dy: cm_window_dy + cm_swatchzone_y_start + cm_swatchzone_height; w: 600; h: 145; anchor: ANC_MIDDLE ),
		( dx: cm_window_dx + cm_swatchzone_x_offset; dy: cm_window_dy + cm_swatchzone_y_start + 2 * cm_swatchzone_height; w: 600; h: 145; anchor: ANC_MIDDLE )
	);

	ZONE_swatch_area: Array [1..3] of DynamicRect = (
		( dx: cm_window_dx + cm_swatchzone_x_offset + off_swatches_x; dy: cm_window_dy + cm_swatchzone_y_start + off_swatches_y; w: Swatch_Width * Swatch_Columns; h: Swatch_Height * Swatch_Rows; anchor: ANC_MIDDLE ),
		( dx: cm_window_dx + cm_swatchzone_x_offset + off_swatches_x; dy: cm_window_dy + cm_swatchzone_y_start + cm_swatchzone_height + off_swatches_y; w: Swatch_Width * Swatch_Columns; h: Swatch_Height * Swatch_Rows; anchor: ANC_MIDDLE ),
		( dx: cm_window_dx + cm_swatchzone_x_offset + off_swatches_x; dy: cm_window_dy + cm_swatchzone_y_start + 2 * cm_swatchzone_height + off_swatches_y; w: Swatch_Width * Swatch_Columns; h: Swatch_Height * Swatch_Rows; anchor: ANC_MIDDLE )
	);

var
	colormenu_ReDrawer: RedrawProcedureType;
	colormenu_imagename, colormenu_imagepalette: String;
	colormenu_imagewidth, colormenu_imageheight: Integer;
    colormenu_animframes: Integer;

	cm_panel,cm_bits: SensibleSpritePtr;

	colormenu_colorset: Array [1..3] of Integer;	{ What color set is being used in each selection box? }
	colormenu_currentpen: Array [1..3] of Integer;	{ What pen is being used in each selection box? }
	colormenu_penswap: Array [1..3] of String;	{ The swap strings for each channel, separated. }
	colormenu_rowoffset: Array [1..3] of Integer;	{ Controls the positioning of the color swatches in each box. }
	colormenu_channel, colormenu_curs_x, colormenu_curs_y: Integer;	{ Where is the cursor? }

Procedure DrawColorSelectionBox( Z: TSDL_Rect; CSet, CPen, CTop, Curs_X, Curs_Y: Integer );
	{ Draw this color selection box in the provided zone. }
	{  CSet: The color set being used. }
	{  CPen: The currently selected pen, or -1 for an unknown color. }
	{  CTop: The first row to be displayed, starting from 0. }
const
	off_palettename_x = 3;
	off_palettename_y = 3;
	off_colorname_x = 122;
var
	MyDest: TSDL_Rect;
	T,X,Y,N: Integer;
    myswatch: SensibleSpritePtr;
begin
	MyDest := Z;

	{ Display the palette type. }
	{ If the color set is out of range, set it to "0" for all colors. }
	MyDest.X := MyDest.X + off_palettename_x;
	MyDest.Y := MyDest.Y + off_palettename_y;
	if ( CSet >= 0 ) and ( CSet <= Num_Color_Sets ) then QuickText( MsgString( 'ColorSet_' + BStr( CSet ) ) , MyDest , StdBlack )
	else CSet := 0;

	{ Display the pen name. }
	MyDest.X := Z.X + off_colorname_x;
	if ( CPen >= 0 ) and ( CPen < Num_Available_Colors ) then QuickText( Available_Colors[ CPen ].name , MyDest , InfoHiLight )
	else QuickText( '???' , MyDest , InfoHiLight );

	{ Display the swatches. }
	{ T will cycle through all colors; N will count the number of colors displayed so far. }
	N := 0;
	MyDest.W := Swatch_Width - 2;
	MyDest.H := Swatch_Height - 2;

	for t := 0 to ( Num_Available_Colors - 1 ) do begin
		{ Figure out whether or not we should display this color for this palette. }
		if ( CSet = 0 ) or Available_Colors[ t ].cs[ CSet ] then begin
			{ Alright, this is one of the ones we're supposed to display. }
			{ Figure out its position, based on N and CTop. }
			X := N mod Swatch_Columns;
			Y := ( N div Swatch_Columns ) - CTop;

			if ( Y >= 0 ) and ( Y < Swatch_Rows ) then begin
				{ Display the color first, then the cursor and selection check. }
				MyDest.X := Z.X + off_swatches_x + X * Swatch_Width + 1;
				MyDest.Y := Z.Y + off_swatches_y + Y * Swatch_Height + 1;
				{SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , Available_Colors[ T ].rgb.R , Available_Colors[ T ].rgb.G , Available_Colors[ T ].rgb.B ) );}
                myswatch := ConfirmSprite('color_menu_swatch.png',BStr( Available_Colors[ T ].rgb.R) +' '+ Bstr(Available_Colors[ T ].rgb.G)+' '+BStr(Available_Colors[ T ].rgb.B)+' 0 0 0  0 0 0',Swatch_Width,Swatch_Height);
                DrawSprite( myswatch, MyDest, 0 );

				MyDest.X := MyDest.X - 1;
				MyDest.Y := MyDest.Y - 1;

				if ( X = Curs_X ) and ( Y = Curs_Y ) then begin
					{ This is where the cursor is. Draw the selector. }
					DrawSprite( cm_bits , MyDest , 0 );
				end;

				if T = CPen then begin
					{ This is the selected color. Draw a checkmark in the box. }
					DrawSprite( cm_bits , MyDest , 1 );
				end;
			end;

			Inc( N );
		end;
	end;
end;

Procedure ColorMenuRedraw;
	{ Do the redraw for the color menu. Yay! }
var
	MySprite: SensibleSpritePtr;
	MyDest: TSDL_Rect;
	t: Integer;
begin
	{ If a redraw procedure has been specified, call it. }
	if colormenu_ReDrawer <> Nil then colormenu_ReDrawer;

	{ Display the panel. }
    MyDest := ZONE_colormenu_base.GetRect();
	ClearExtendedBorder( MyDest );
	SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , PlayerBlue.R , PlayerBlue.G , PlayerBlue.B ) );
	DrawSprite( cm_panel , MyDest , 0 );

	{ Display the sprite we're editing. }
	MySprite := ConfirmSprite( colormenu_imagename, colormenu_imagepalette, colormenu_imagewidth, colormenu_imageheight );
	MyDest := ZONE_colormenu_sprite.GetRect();
	if MySprite <> Nil then begin
		MyDest.X := MyDest.X + ( MyDest.W div 2 ) - ( colormenu_imagewidth div 2 );
		MyDest.Y := MyDest.Y + ( MyDest.H div 2 ) - ( colormenu_imageheight div 2 );
        if colormenu_animframes > 0 then begin
            t := Animation_Phase div 5 mod colormenu_animframes;
        end else begin
            t := 0;
        end;
		DrawSprite( MySprite , MyDest , t );
	end;

	{ Display the instructions. }

	{ Display the three color swatch areas. }
	for t := 1 to 3 do begin
		if t = colormenu_channel then begin
			DrawColorSelectionBox( ZONE_colorselectionboxes[t].GetRect(), colormenu_colorset[ t ], colormenu_currentpen[ t ], colormenu_rowoffset[ t ], colormenu_Curs_X, colormenu_Curs_Y );
		end else begin
			DrawColorSelectionBox( ZONE_colorselectionboxes[t].GetRect(), colormenu_colorset[ t ], colormenu_currentpen[ t ], colormenu_rowoffset[ t ], -1, -1 );
		end;
	end;
end;

Function GetColorAtSpot( Channel, Curs_X, Curs_Y: Integer ): Integer;
	{ Determine which color is being shown at the provided location. If there's no color there, }
	{ return -1. }
var
	t,N,it,x,y: Integer;
begin
	N := 0;
	it := -1;
	for t := 0 to ( Num_Available_Colors - 1 ) do begin
		{ Figure out whether or not this color is being displayed. }
		if ( colormenu_colorset[ Channel ] = 0 ) or Available_Colors[ t ].cs[ colormenu_colorset[ Channel ] ] then begin
			{ Alright, this is one of the ones being displayed. }
			{ Figure out its position, based on N and colormenu_rowoffset. }
			X := N mod Swatch_Columns;
			Y := ( N div Swatch_Columns ) - colormenu_rowoffset[ Channel ];

			if ( X = Curs_X ) and ( Y = Curs_Y ) then begin
				it := t;
				Break;
			end;

			Inc( N );
		end;
	end;
	GetColorAtSpot := it;
end;

Procedure ProcessMouseHit;
	{ Alright, so the mouse button has just been pressed. Figure out if it hit anything }
	{ interesting and maybe change one of the color pens. }
var
    MyHit: TSDL_Rect;
	T,C,HitX,HitY: Integer;
begin
	{ There are three color channels to worry about. See if it hit any of those. }
	for t := 1 to 3 do begin
        MyHit := ZONE_swatch_area[t].GetRect();
		if ( Mouse_X >= MyHit.X ) and ( Mouse_Y >= MyHit.Y ) and ( Mouse_X < ( MyHit.X + MyHit.W ) ) and ( Mouse_Y < ( MyHit.Y + MyHit.H ) ) then begin
			{ Alright, we're in the hit box. We've definitely hit a swatch, if there's one at this position. }
			{ Determine HitX and HitY. }
			HitX := ( Mouse_X - MyHit.X ) div Swatch_Width;
			HitY := ( Mouse_Y - MyHit.Y ) div Swatch_Height;

			{ Now the question becomes, is there a color at this area? }
			colormenu_channel := T;
			colormenu_curs_x := HitX;
			colormenu_curs_y := HitY;

			C := GetColorAtSpot( T , HitX , HitY );
			if C <> -1 then begin
				colormenu_currentpen[ T ] := C;
				colormenu_penswap[ t ] := BStr( Available_Colors[ C ].rgb.r ) + ' ' + BStr( Available_Colors[ C ].rgb.g ) + ' ' + BStr( Available_Colors[ C ].rgb.b );
			end;
		end;
	end;
end;

Function SelectColorPalette( init_mode: Integer; image_name,color_palette: String; image_width,image_height, anim_frames: Integer; Redrawer: RedrawProcedureType ): String;
	{ Select a color palette for this image name. }
	{ init_mode tells what initial palettes to use. }
var
	T,tt: Integer;
	A: Char;
	tmp_string: String;
	tmp_color: TSDL_Color;
begin
	{ Store all the values that we've been given. }
	colormenu_imagename := image_name;
	colormenu_imagewidth := image_width;
	colormenu_imageheight := image_height;
    colormenu_animframes := anim_frames;
	colormenu_ReDrawer := Redrawer;

	{ Initialize the selection variables. }
	colormenu_channel := 1;
	colormenu_curs_x := 0;
	colormenu_curs_y := 0;

	for t := 1 to 3 do begin
		if init_mode = colormenu_mode_character then begin
			colormenu_colorset[ t ] := t;
		end else if init_mode = colormenu_mode_mecha then begin
			colormenu_colorset[ t ] := t + 3;
		end else begin
			colormenu_colorset[ t ] := 0;
		end;

		{ Determine if this color in the provided default is a standard color or not. }
		tmp_string := ExtractWord( color_palette );
		colormenu_penswap[ t ] := tmp_string;
		tmp_color.R := ExtractValue( tmp_string );
		tmp_string := ExtractWord( color_palette );
		colormenu_penswap[ t ] := colormenu_penswap[ t ] + ' ' + tmp_string;
		tmp_color.G := ExtractValue( tmp_string );
		tmp_string := ExtractWord( color_palette );
		colormenu_penswap[ t ] := colormenu_penswap[ t ] + ' ' + tmp_string;
		tmp_color.B := ExtractValue( tmp_string );

		colormenu_currentpen[ t ] := -1;
		for tt := 0 to ( Num_Available_Colors - 1 ) do begin
			if ( Available_Colors[ tt ].rgb.r = tmp_color.r ) and ( Available_Colors[ tt ].rgb.g = tmp_color.g ) and ( Available_Colors[ tt ].rgb.b = tmp_color.b ) then begin
				colormenu_currentpen[ t ] := tt;
			end;
		end;

		colormenu_rowoffset[ t ] := 0;
	end;

	{ I think we're ready to begin polling for input. }
	repeat
		colormenu_imagepalette := colormenu_penswap[1] + ' ' + colormenu_penswap[2] + ' ' + colormenu_penswap[3];
		ColorMenuRedraw;
		GHFlip;

		a := RPGKey;

		if a = #8 then begin
			a := #27;

		end else if a = RPK_MouseButton then begin
			{ Crap, mouse input!!! I wonder if I can simply copy and paste the code from }
			{ the first Cosplay program? }
			ProcessMouseHit;
		end;

	until a = #27;

	SelectColorPalette := colormenu_imagepalette;
end;

Procedure LoadColorList;
	{ Load the standard colors from disk, and convert them to the colormenu format. }
var
	CList,C: SAttPtr;
	T,tt: Integer;
	msg: String;
begin
	{ Begin by loading the definitions from disk. }
	CList := LoadStringList( Data_Directory + 'sdl_colors.txt' );

	{ Clear the Num_Colors_Per_Set array. }
	for t := 1 to Num_Color_Sets do begin
		Num_Colors_Per_Set[ t ] := 0;
	end;

	{ Now that we know how many colors we're dealing with, we can size the }
	{ colors array to the perfect dimensions. }
	Num_Available_Colors := NumSAtts( CList );
	SetLength( Available_Colors , Num_Available_Colors );

	{ Copy the data into the array. }
	C := CList;
	T := 0;
	while C <> Nil do begin
		msg := RetrieveAPreamble( C^.Info );
		if Length( msg ) < 8 then msg := msg + '------:ERROR';

		Available_Colors[ t ].name := Copy( msg , 8 , 255 );
		for tt := 1 to Num_Color_Sets do begin
			Available_Colors[ t ].cs[tt] := msg[tt] = '+';
			if Available_Colors[ t ].cs[tt] then Inc( Num_Colors_Per_Set[ tt ] );
		end;

		msg := RetrieveAString( C^.Info );
		Available_Colors[ t ].rgb.r := ExtractValue( msg );
		Available_Colors[ t ].rgb.g := ExtractValue( msg );
		Available_Colors[ t ].rgb.b := ExtractValue( msg );

		C := C^.Next;
		Inc( T );
	end;

	{ Get rid of the color definitions. }
	DisposeSAtt( CList );
end;


initialization
	LoadColorList;
	cm_bits := ConfirmSprite( 'color_menu_bits.png' , '', Swatch_Width , Swatch_Height );
	cm_panel := ConfirmSprite( 'color_menu.png' , '', cm_panel_width , cm_panel_height );

finalization


end.
