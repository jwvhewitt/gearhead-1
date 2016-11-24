unit ghprop;
	{ What do props do? Well, not much by themselves... But they }
	{ can be used to make buildings, safes, machinery, or whatever }
	{ else you can think to do with them. }
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

	{ PROP DEFINITION }
	{ G => GG_Prop }
	{ S => Undefined }
	{ V => Prop Size; translates to mass and damage. }

	{ METATERRAIN DEFINITION }
	{ G => GG_MetaTerrain }
	{ S => Specific Type, 0 = Generic }
	{ V => Terrain Size; translates to armor and damage. }
	{         if MetaTerrain V = 0, cannot be destroyed. }


const
	{ Please note that a metaterrain gear does not need to have }
	{ its "S" value within the 1..NumBasicMetaTerrain range, }
	{ but those which do lie within this range will be initialized }
	{ with the default scripts. }
	NumBasicMetaTerrain = 14;
	GS_MetaDoor = 1;
	GS_MetaCloud = 2;
	GS_MetaCity = 3;
	GS_MetaTown = 4;
	GS_MetaVillage = 5;
	GS_MetaStairsUp = 6;
	GS_MetaStairsDown = 7;
	GS_MetaCave = 8;
	GS_MetaTemple = 9;
	GS_MetaElevator = 10;
	GS_MetaTrapDoor = 11;
	GS_MetaRubble = 12;
	GS_MetaSign = 13;
	GS_MetaFire = 14;

	STAT_Altitude = 1;
	STAT_Obscurement = 2;
	STAT_Pass = 3;
	STAT_Destination = 4;
	STAT_MetaVisibility = 5;	{ If nonzero, this terrain can't be seen. }
	STAT_Lock = 6;
	STAT_CloudDuration = 7;

var
	{ This array holds the scripts. }
	Meta_Terrain_Scripts: Array [1..NumBasicMetaTerrain] of SAttPtr;


Procedure CheckPropRange( Part: GearPtr );

Procedure InitMetaTerrain( Part: GearPtr );



implementation

uses texutil;

const
	{ This array holds the default SDL sprite numbers. }
	Meta_Terrain_Sprite: Array [1..NumBasicMetaTerrain] of Integer = (
		0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
	);



Procedure CheckPropRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check V - Size Category }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 100 then Part^.V := 100;


end;

Procedure InitMetaTerrain( Part: GearPtr );
	{ Initialize this metaterrain gear for a nice default example of }
	{ the terrain type it's supposed to represent. }
begin
	{ If this is a part for which we have a standard script, }
	{ install that script now. }
	if ( Part^.S >= 1 ) and ( Part^.S <= NumBasicMetaTerrain ) then begin
		SetNAtt( Part^.NA , NAG_Display , 0 , Meta_Terrain_Sprite[ Part^.S ] );
		SetSAtt( Part^.SA , 'ROGUECHAR <' + SAttValue( Meta_Terrain_Scripts[ Part^.S ] , 'roguechar' ) + '>' );
		SetSAtt( Part^.SA , 'NAME <' + SAttValue( Meta_Terrain_Scripts[ Part^.S ] , 'NAME' ) + '>' );
		SetSAtt( Part^.SA , 'SDL_SPRITE <' + SAttValue( Meta_Terrain_Scripts[ Part^.S ] , 'SDL_SPRITE' ) + '>' );
	end;

	{ Do part-specific initializations here. }
	if Part^.S = GS_MetaDoor then begin
		{ Begin with the stats for a closed door. }
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 6;
		SetNAtt( Part^.NA , NAG_Display , 1 , 1 );
	end else if ( Part^.S = GS_MetaRubble ) or ( Part^.S = GS_MetaSign ) then begin
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 1;
		Part^.Stat[ STAT_Obscurement ] := 1;
	end;
end;

Procedure LoadMetaScripts;
	{ Load the metascripts from disk. }
var
	T: Integer;
begin
	for t := 1 to NumBasicMetaTerrain do begin
		Meta_Terrain_Scripts[ t ] := LoadStringList( MetaTerrain_File_Base + BStr( T ) + Default_File_Ending );
	end;
end;

Procedure ClearMetaScripts;
	{ Free the metascripts from memory. }
var
	T: Integer;
begin
	for t := 1 to NumBasicMetaTerrain do begin
		DisposeSAtt( Meta_Terrain_Scripts[ t ] );
	end;
end;

initialization
	LoadMetaScripts;

finalization
	ClearMetaScripts;

end.
