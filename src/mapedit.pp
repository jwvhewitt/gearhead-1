unit MapEdit;
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

Procedure EditMap;

implementation

{$IFDEF SDLMODE}
uses gears,locale,ui4gh,congfx,sdlinfo,sdlmap,sdlmenus;
{$ELSE}
uses gears,locale,ui4gh,congfx,coninfo,conmap,conmenus,context;
{$ENDIF}

Procedure SaveMap( GB: GameBoardPtr );
	{ Prompt for a file name, then save a map to disk. }
var
	FName: String;
	F: Text;
	X,Y: Integer;
begin
	FName := GetStringFromUser( 'Enter filename - format "MAP_*.txt"' );
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			GB^.Map[ X , Y ].Visible := False;
		end;
	end;
	if FName <> '' then begin
		Assign( F , Series_Directory + FName );
		Rewrite( F );
		WriteMap( GB^.Map , F );
		Close( F );
	end;
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			GB^.Map[ X , Y ].Visible := True;
		end;
	end;
	DisplayMap( GB );
end;

Procedure LoadMap( GB: GameBoardPtr );
	{ Prompt for a file name, then load a map from disk. }
var
	RPM: RPGMenuPtr;
	FName: String;
	F: Text;
	X,Y: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( RPM , Series_Directory + '*MAP_*.txt' );
	FName := SelectFile( RPM );
	DisposeRPGMenu( RPM );
	if FName <> '' then begin
		Assign( F , Series_Directory + FName );
		Reset( F );
		GB^.Map := ReadMap( F );
		Close( F );
	end;
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			GB^.Map[ X , Y ].Visible := True;
		end;
	end;
	DisplayMap( GB );
end;

Procedure ClearMap( GB: GameBoardPtr; Pen: Integer );

var
	X,Y: Integer;
begin
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			GB^.Map[ X , Y ].Terr := Pen;
		end;
	end;
end;

Procedure EditMap;
	{ Edit the given map. Save it to disk if need be. }
	{ The map is edited with visibility all turned on. When the map }
	{ is saved. the visibility will be turned off. }
var
	A: CHar;
	Pen,Palette,X,Y: Integer;
	GB: GameBoardPtr;
	Procedure RepositionCursor( D: Integer );
	begin
		RedrawTile( gb, X , Y );
		if OnTheMap( X + AngDir[ D , 1 ] , Y + AngDir[ D , 2 ] ) then begin
			X := X + AngDir[ D , 1 ];
			Y := Y + AngDir[ D , 2 ];
		end;
	end;
begin
	{ Create a map, and clear it. }
	GB := NewMap;
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			GB^.Map[ X , Y ].Visible := True;
			GB^.Map[ X , Y ].Terr := 1;
		end;
	end;
	DisplayMap( GB );

	{ Initialize our pointer. }
	Pen := 1;
	Palette := 1;
	X := 1;
	Y := 1;

	repeat
		IndicateTile( GB , X , Y );
		MapEditInfo( Pen , Palette , X , Y );
		A := RPGKey;

		if A = KeyMap[ KMC_North ].KCode then begin
			RepositionCursor( 6 );

		end else if A = KeyMap[ KMC_South ].KCode then begin
			RepositionCursor( 2 );

		end else if A = KeyMap[ KMC_West ].KCode then begin
			RepositionCursor( 4 );

		end else if A = KeyMap[ KMC_East ].KCode then begin
			RepositionCursor( 0 );

		end else if A = KeyMap[ KMC_NorthEast ].KCode then begin
			RepositionCursor( 7 );

		end else if A = KeyMap[ KMC_SouthWest ].KCode then begin
			RepositionCursor( 3 );

		end else if A = KeyMap[ KMC_NorthWest ].KCode then begin
			RepositionCursor( 5 );

		end else if A = KeyMap[ KMC_SouthEast ].KCode then begin
			RepositionCursor( 1 );

		end else if A = ']' then begin
			Pen := Pen + 1;
			if Pen > NumTerr then pen := 1;

		end else if A = '[' then begin
			Pen := Pen - 1;
			if Pen < 1 then pen := NumTerr;

		end else if A = ' ' then begin
			GB^.Map[ X , Y ].Terr := Pen;

		end else if A = 'S' then begin
			SaveMap( GB );

		end else if A = 'L' then begin
			LoadMap( GB );

		end else if A = 'C' then begin
			ClearMap( GB , Pen );

		end;

	until A = 'Q';

	{ Get rid of the map. }
	DisposeMap( GB );
end;

end.
