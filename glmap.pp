unit renderer;
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

uses sdl,sdl_image,gl,glu,glgfx,locale,math,gears;

const
	Num_Terrain_Textures = 10;
	Num_Anim_Sequences = 10;
	Anim_Sequence_Length = 10;

	Num_Rotation_Angles = 90;

var
	tile_x,tile_y: LongInt;	{ Tile where the mouse pointer is pointing. }
	origin_x,origin_y,origin_zoom: GLFloat;	{ Tile which the camera is pointing at. }
	origin_d: Integer;

	TerrTex: Array [1..Num_Terrain_Textures] of GLUInt;
	AnimTex: Array [1..Num_Anim_Sequences,1..Anim_Sequence_Length] of GLUInt;
	NumberTex: Array [0..9] of GLUInt;

	overlays: Array [1..XMax,1..YMax] of Integer;
	underlays: Array [1..XMax,1..YMax] of Integer;


	FineDir: Array [0..(Num_Rotation_Angles-1),1..2] of glFloat;

Procedure ScrollMap;

Procedure RenderMap;

Procedure ClearOverlays;
Procedure IndicateTile( X,Y,G: Integer );
Procedure DeIndicateTile( X,Y: Integer );


implementation

var
	Terrain_GL_Base: GLUInt;

Procedure ScrollMap;
	{ Asjust the position of the map origin. }
	Procedure CheckOrigin;
		{ Make sure the origin position is legal. }
	begin
		if Origin_X < 1 then Origin_X := 1
		else if Origin_X > XMax then Origin_X := XMax;
		if Origin_Y < 1 then Origin_Y := 1
		else if Origin_Y > YMax then Origin_Y := YMax;
	end;
begin
	if Mouse_X < 20 then begin
		Origin_X := Origin_X + FineDir[ ( Origin_D + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ ( Origin_D + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles , 2 ]/3;
		checkorigin;
	END else if Mouse_X > ( screenwidth - 20 ) then begin
		Origin_X := Origin_X + FineDir[ ( Origin_D + Num_Rotation_Angles * 3 div 4 ) mod Num_Rotation_Angles , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ ( Origin_D + Num_Rotation_Angles * 3 div 4 ) mod Num_Rotation_Angles , 2 ]/3;
		checkorigin;
	end else if ( Mouse_Y < 20 ) or ( RK_KeyState[ SDLK_Up ] = 1 ) then begin
		Origin_X := Origin_X + FineDir[ ( Origin_D + Num_Rotation_Angles div 2 ) mod Num_Rotation_Angles , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ ( Origin_D + Num_Rotation_Angles div 2 ) mod Num_Rotation_Angles , 2 ]/3;
		checkorigin;
	END else if ( Mouse_Y > ( screenheight - 20 ) ) or ( RK_KeyState[ SDLK_Down ] = 1 ) then begin
		Origin_X := Origin_X + FineDir[ Origin_D , 1 ]/3;
		Origin_Y := Origin_Y + FineDir[ Origin_D , 2 ]/3;
		checkorigin;
	end;


	if ( RK_KeyState[ SDLK_Right ] = 1 ) then begin
		origin_d := ( origin_d + 1 ) mod Num_Rotation_Angles;
	end else if ( RK_KeyState[ SDLK_Left ] = 1 ) then begin
		origin_d := ( origin_d + Num_Rotation_Angles - 1 ) mod Num_Rotation_Angles;
	end;
	if ( RK_KeyState[ SDLK_PageUp ] = 1 ) and ( origin_zoom > 10 ) then begin
		origin_zoom := origin_zoom - 1;
	end else if ( RK_KeyState[ SDLK_PageDown ] = 1 ) and ( origin_zoom < 30 ) then begin
		origin_zoom := origin_zoom + 1;
	end;

end;

Procedure DrawWall( Tex: Integer );
	{ Draw a wall at the current model coordinates in the current texture. }
begin
	glbegin( GL_QUADS );
	GLNormal3i( 0 , 1 , 0 );
	GLColor3F( 0.0 , 0.0 , 0.0 );
	glVertex3i( 0 , 1 , 0 );
	glVertex3i( 1 , 1 , 0 );
	glVertex3i( 1 , 1 , 1 );
	glVertex3i( 0 , 1 , 1 );
 	glEnd;

	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );

	glBindTexture(GL_TEXTURE_2D, TerrTex[ Tex ] );
	glEnable( GL_Texture_2D );

	glEnable( GL_ALPHA_TEST );
	glAlphaFunc( GL_Equal , 1.0 );

	glbegin( GL_QUADS );
	GLColor3F( 1.0 , 1.0 , 1.0 );

	GLNormal3i( 0 , 0 , 0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3i( 0 , 0 , 0 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3i( 0 , 1 , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3i( 1 , 1 , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3i( 1 , 0 , 0 );

	GLNormal3i( -1 , 0 , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3i( 0 , 0 , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3i( 0 , 1 , 0 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3i( 0 , 1 , 1 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3i( 0 , 0 , 1 );

	GLNormal3i( 1 , 0 , 0 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3i( 1 , 0 , 0 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3i( 1 , 1 , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3i( 1 , 1 , 1 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3i( 1 , 0 , 1 );

	GLNormal3i( 0 , 0 , 1 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3i( 1 , 0 , 1 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3i( 1 , 1 , 1 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3i( 0 , 1 , 1 );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3i( 0 , 0 , 1 );

 	glEnd;

	glDisable( GL_Texture_2D );

end;

Procedure DrawFloor( Tex: Integer; Offset: GLFloat );
	{ Draw a floor. This is like a wall, but only one quad and it's }
	{ horizontal. }
begin
	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
	glBindTexture(GL_TEXTURE_2D, TerrTex[ Tex ] );
	glEnable( GL_Texture_2D );

	glbegin( GL_QUADS );

	GLColor3F( 1.0 , 1.0 , 1.0 );

	glTexCoord2f( 0.0 , 0.0 );
	GLNormal3i( 0 , 1 , 0 );
	glVertex3f( 0 , Offset , 0 );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( 1 , Offset , 0 );
	glTexCoord2f( 1.0 , 1.0 );
	glVertex3f( 1 , Offset , 1 );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( 0 , Offset , 1 );

 	glEnd;

	glDisable( GL_Texture_2D );

end;

Procedure DrawModel( Tex: Integer; Width,Offset: GLFloat );
	{ Draw a model. This is like a floor, but facing the camera and vertical. }
begin
	GLColor3F( 1.0 , 1.0 , 1.0 );
	glPushMatrix();

	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
	glBindTexture(GL_TEXTURE_2D, Tex );
	glEnable( GL_Texture_2D );

	glTranslatef( 0.5 , 0 , 0.5 );
	glRotatef( -( ( origin_d + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles ) * ( 360 / Num_Rotation_Angles ) , 0 , 1 , 0 );
	glbegin( GL_QUADS );

	glTexCoord2f( 1.0 , 1.0 );
	GLNormal3f( 0 , 0 , 1 );
	glVertex3f( -( Width / 2 ) , 0 , Offset );
	glTexCoord2f( 0.0 , 1.0 );
	glVertex3f( ( Width / 2 ) , 0 , Offset );
	glTexCoord2f( 0.0 , 0.0 );
	glVertex3f( ( Width / 2 ) , Width , Offset );
	glTexCoord2f( 1.0 , 0.0 );
	glVertex3f( -( Width / 2 ) , Width , Offset );

 	glEnd;

	glDisable( GL_Texture_2D );
	glPopMatrix();
end;

Procedure DrawNumber( N: Integer );
	{ Draw a number hovering above the tile. }
var
	X: GLFloat;
begin
	if N > 0 then begin
		GLColor3F( 1.0 , 0.1 , 0.0 );
	end else begin
		GLColor3F( 0.0 , 1.0 , 0.3 );
		N := Abs( N );
	end;

	glTexEnvi( GL_TEXTURE_ENV , GL_TEXTURE_ENV_MODE , GL_MODULATE );
	glEnable( GL_Texture_2D );

	glTranslatef( 0.5 , 0 , 0.5 );
	glRotatef( -( ( origin_d + Num_Rotation_Angles div 4 ) mod Num_Rotation_Angles ) * ( 360 / Num_Rotation_Angles ) , 0 , 1 , 0 );

	X := -0.3;

	while N > 0 do begin
		glBindTexture(GL_TEXTURE_2D, NumberTex[ N mod 10 ] );

		glbegin( GL_QUADS );

		glTexCoord2f( 1.0 , 1.0 );
		GLNormal3f( 0 , 0 , 1 );
		glVertex3f( X - 0.2 , 1.0 , 0 );
		glTexCoord2f( 0.0 , 1.0 );
		glVertex3f( X + 0.2 , 1.0 , 0 );
		glTexCoord2f( 0.0 , 0.0 );
		glVertex3f( X + 0.2 , 1.5 , 0 );
		glTexCoord2f( 1.0 , 0.0 );
		glVertex3f( X - 0.2 , 1.5 , 0 );

	 	glEnd;

		N := N div 10;
		X := X + 0.3;
	end;
	glDisable( GL_Texture_2D );
end;


Procedure RenderMap;
	{ Render the location stored in G_Map, along with all items and characters on it. }
	{ Also save the position of the mouse pointer, in world coordinates. }
const
	LightPos: Array [1..4] of GLFloat = (
	60 , 25.0 , 30 , 1
	);
	mat_specular: Array [1..4] of GLFloat = ( 1.0, 1.0, 1.0, 1.0 );
	OutdoorAmbient: Array [1..4] of GLFloat = (
	0.1,0.1,0.1,1.0
	);
	LightAmbient: Array [1..4] of GLFloat = (
	0.2,0.2,0.2,1.0
	);
	LightDiffuse: Array [1..4] of GLFloat = (
	1.0,1.0,1.0,1.0
	);
	LightSpecular: Array [1..4] of GLFloat = (
	0.9,0.9,0.9,1.0
	);

var
	X,Y: Integer;
	BZ: GLFloat;
	SX,SY,SZ: GLDouble;
	Viewport: TViewPortArray;
	mvmatrix,projmatrix: T16DArray;
	M: GearPtr;
begin
	glDisable( GL_BLEND );

	glMatrixMode( GL_PROJECTION );
	glLoadIdentity;
	gluPerspective( 20.0, screenwidth/screenheight , 0.5, 256.0 );
	gluLookAt( origin_x + 0.5 + FineDir[origin_d,1]*origin_zoom , origin_zoom / 2 , origin_y + 0.5 + FineDir[origin_d,2]* origin_zoom , origin_x + 0.5 , 0 , origin_y + 0.5 , 0 , 1 , 0 );

	glMatrixMode( GL_MODELVIEW );
	glLoadIdentity();

{	LightPos[1] := origin_x + 0.5 + 30;
	LightPos[3] := origin_y;}
	LightPos[1] := origin_x + 0.5 + FineDir[origin_d,1]*20 + 30;
	LightPos[3] := origin_y + 0.5 + FineDir[origin_d,2]*20;

	glLightfv( GL_Light1 , GL_POSITION , @LightPos[1] );
	glLightModelfv( GL_Light_Model_Ambient , @OutDoorAmbient[1] );
	glLightfv( GL_Light1 , GL_AMBIENT , @LightAmbient[1] );
	glLightfv( GL_Light1 , GL_DIFFUSE , @LightDiffuse[1] );
	glLightfv( GL_Light1 , GL_SPECULAR , @LightSpecular[1] );
	glLightf( GL_Light1 , GL_QUADRATIC_ATTENUATION , 0.0008 );

	glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );

	glEnable( GL_Depth_Test );

	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, @mat_specular);
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, @mat_specular);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, @mat_specular);

	glEnable( GL_ALPHA_TEST );
	glAlphaFunc( GL_Equal , 1.0 );


	{ Draw all the tiles in memory order. }
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			if G_Map[ X , Y ].visible then begin
				glMatrixMode( GL_MODELVIEW );
				glLoadIdentity();
				glTranslated( X - 1 , 0 , Y - 1 );
				glEnable( GL_Lighting );
				glEnable( GL_Light1 );
				glCallList( Terrain_GL_Base + G_Map[ X , Y ].terr - 1 );

				glDisable( GL_Lighting );
				glDisable( GL_Light1 );
				{ Draw any overlays that may be pending. }
				if Overlays[ X , Y ] > 0 then begin
					DrawModel( Overlays[ X , Y ] , 1.5 , -0.1 );
				end;
				if Underlays[ X , Y ] > 0 then begin
					DrawFloor( Underlays[ X , Y ] , 0.1 );
				end;
				if InfoNumbers[ X , Y ] > 0 then begin
					DrawNumber( InfoNumbers[ X , Y ] );
				end;
			end;
		end;
	end;

	{ Draw the contents of the map. }
	M := G_Contents;
	glDisable( GL_Lighting );
	glDisable( GL_Light1 );
	while M <> Nil do begin
		if OnTheMap( M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			if G_Map[ X , Y ].Visible then begin
				glMatrixMode( GL_MODELVIEW );
				glLoadIdentity();
				glTranslated( X - 1 , 0 , Y - 1 );
				DrawModel( LocateTextureByID( NAttValue( M^.NA , NAG_Location , NAS_Image ) ) , 1.0 + ( ( Animation_Phase + X + Y ) div 5 mod 2 ) / 80 , 0 );
			end;
		end;
		M := M^.Next;
	end;

	glDisable( GL_Texture_2D );
	glDisable( GL_ALPHA_TEST );
	glDisable( GL_Depth_Test );

	{ Record the coordinates of the mouse, in map terms. }
	glMatrixMode( GL_MODELVIEW );
	glLoadIdentity();

	glGetIntegerv (GL_VIEWPORT, viewport);
	glGetDoublev (GL_MODELVIEW_MATRIX, mvmatrix);
	glGetDoublev (GL_PROJECTION_MATRIX, projmatrix);

	glReadPixels( mouse_x, screenheight - mouse_y, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, @BZ);

	gluUnProject( Mouse_X , screenheight - Mouse_Y , BZ , mvmatrix , projmatrix , viewPort , @SX , @SY , @SZ );

	tile_X := Floor( SX ) + 1;
	tile_Y := Floor( SZ ) + 1;
end;

Procedure LoadTextures;
	{ Load the textures for the walls, and format them for OpenGL. }
var
	tmp: PSDL_Surface;
	T2: SensibleSpritePtr;
	MySource: TSDL_Rect;
	T,TT: Integer;
begin
	MySource.X := 0;
	MySource.Y := 0;

	{ First, generate names for the textures, and load the terrain image sprite. }
	glGenTextures( Num_Terrain_Textures, @TerrTex );
	T2 := LocateSprite( 'terrain.png' , 32 , 32 );

	{ Create a temporary image for the transfer. }
	tmp := SDL_CreateRGBSurface( SDL_SWSURFACE , 32 , 32 , 32 , $000000ff , $0000ff00 , $00ff0000 , $ff000000 );

	{ Transfer the images one by one to gl textures. }
	for t := 1 to Num_Terrain_Textures do begin
		SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
		DrawSprite( t2 , tmp , MySource , T-1 );
		glBindTexture( GL_TEXTURE_2D, TerrTex[T] );
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
		glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
	end;
	glFinish;
	RemoveSprite( t2 );

	{ Next the animations. }
	T2 := LocateSprite( 'anim.png' , 32 , 32 );
	glGenTextures( Num_Anim_Sequences * Anim_Sequence_Length, @AnimTex );
	for t := 1 to Num_Anim_Sequences do begin
		for tt := 1 to Anim_Sequence_Length do begin
			SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
			DrawSprite( t2 , tmp , MySource , tt - 1 + ( t - 1 ) * Anim_Sequence_Length  );
			glBindTexture( GL_TEXTURE_2D, AnimTex[T,TT] );
			glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
			glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
			glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
		end;
	end;
	glFinish;
	RemoveSprite( t2 );

	{ Next the numbers. }
	T2 := LocateSprite( 'numbers.png' , 16 , 16 );
	glGenTextures( 10, @NumberTex );
	for t := 0 to 9 do begin
		SDL_FillRect( tmp , Nil , SDL_MapRGBA( tmp^.Format , 0 , 0 , 255 , 0 ) );
		DrawSprite( t2 , tmp , MySource , t  );
		glBindTexture( GL_TEXTURE_2D, NumberTex[T] );
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
		glTexImage2D(GL_TEXTURE_2D,0,4,tmp^.w,tmp^.h,0,GL_RGBA,GL_UNSIGNED_BYTE,tmp^.pixels);
	end;
	glFinish;
	RemoveSprite( t2 );
	SDL_FreeSurface(tmp);
end;

Procedure ClearOverlays;
	{ Clear all overlay graphics. }
var
	X,Y: Integer;
begin
	for x := 1 to xmax do begin
		for y := 1 to ymax do begin
			Overlays[X,Y] := 0;
			Underlays[X,Y] := 0;
			InfoNumbers[X,Y] := 0;
		end;
	end;
end;

Procedure FillFineDir;
	{ Fill the "Fine Dir" array with data. }
var
	T: Integer;
begin
	for t := 0 to ( Num_Rotation_Angles - 1 ) do begin
		FineDir[ T , 1 ] := Cos( -Pi * 2 * t / Num_Rotation_Angles );
		FineDir[ T , 2 ] := -Sin( -Pi * 2 * t / Num_Rotation_Angles );
	end;
end;


Procedure IndicateTile( X,Y,G: Integer );
	{ Indicate the requested tile with the requested glyph. }
begin
	if OnTheMap( X , Y ) then Underlays[X,Y] := G;
end;

Procedure DeIndicateTile( X,Y: Integer );
	{ Clear any indicators from the requested tile. }
begin
	IndicateTile( X , Y , 0 );
end;

Procedure CreateDisplayLists;
	{ Create display lists for each type of terrain to be drawn. }
begin
	Terrain_GL_Base := glGenLists( NumTerr );
	glNewList( Terrain_GL_Base + TERR_Wall - 1 , GL_COMPILE );
		DrawWall( TerrTex[2] );
	glEndList;
	glNewList( Terrain_GL_Base + TERR_Floor - 1 , GL_COMPILE );
		DrawFloor( TerrTex[1] , 0 );
	glEndList;

end;

initialization
	LoadTextures;
	ClearOverlays;

	origin_x := 25.0;
	origin_y := 25.0;
	origin_d := 0;
	origin_zoom := 20;

	tile_x := 1;
	tile_y := 1;

	FillFineDir;
	RPGKey;

	CreateDisplayLists;

finalization
	glDeleteLists( Terrain_GL_Base , NumTerr );

end.
