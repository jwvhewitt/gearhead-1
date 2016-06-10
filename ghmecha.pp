unit ghmecha;
	{This unit handles stuff for MECHA GEARS.}
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

	{ G = GG_MECHA }
	{ S = Mecha Form (Transformation Mode) }
	{ V = Size Class of Mecha }

interface

uses gears;

Const
	NumForm = 9;		{ The number of different FORMs which exist in the game.}

	GS_Battroid = 0;	{ Default form }
	GS_Zoanoid = 1;		{ Animal Form Mecha }
	GS_GroundHugger = 2;	{ Land Vehicle - Heavy Armor }
	GS_Arachnoid = 3;	{ Walker type tank }
	GS_AeroFighter = 4;	{ Fighter Jet type }
	GS_Ornithoid = 5;	{ Bird Form Mecha }
	GS_Gerwalk = 6;		{ Half robot half plane }
	GS_HoverFighter = 7;	{ Helicopter, etc. }
	GS_GroundCar = 8;	{ Land Vehicle - High Speed }


	{ PATCH_I18N: Don't translate here, use GameData/I18N_name.txt. }
	FormName: Array[ 0 .. ( NumForm - 1 ) ] of String = (
		'Battroid','Zoanoid','GroundHugger','Arachnoid','AeroFighter',
		'Ornithoid','Gerwalk','HoverFighter','GroundCar'
	);

	FormMVBonus: Array [ 0 .. ( NumForm - 1 ) ] of SmallInt = (
		1, 2, -1, 0, -5,
		-1, -3, -3, -1
	);

	FormTRBonus: Array [ 0 .. ( NumForm - 1 ) ] of SmallInt = (
		1, -1, 2, 1 , -1,
		-2, 0, 0, 1
	);


Procedure InitMecha(Part: GearPtr);
Function MechaName(Part: GearPtr): String;
Procedure CheckMechaRange( Mek: GearPtr );
Function IsLegalMechaSubCom( Part, Equip: GearPtr ): Boolean;

Function MechaTraitDesc( Mek: GearPtr ): String;


implementation

uses texutil;

Procedure InitMecha(Part: GearPtr);
	{Part is a newly created Mecha record.}
	{Initialize fields to default values.}
begin
	{Default Scale = 2}
	Part^.Scale := 2;
end;

Function MechaName(Part: GearPtr): String;
	{Figure out a default name for a mecha.}
begin
	{Error Check - if the thing isn't a mecha, return smartass answer.}
	{ PATCH_I18N: Don't translate it. }
	if Part^.G <> GG_Mecha then Exit('Not A Mecha');

	MechaName := FormName[Part^.S];
end;

Procedure CheckMechaRange( Mek: GearPtr );
	{ Check a MECHA gear to make sure all values are within appropriate }
	{ range. }
var
	T: Integer;
begin
	{ Check S - Mecha Form }
	if Mek^.S < 0 then Mek^.S := 0
	else if Mek^.S > ( NumForm - 1 ) then Mek^.S := GS_Battroid;

	{ Check V - Mecha Size }
	if Mek^.V < 1 then Mek^.V := 1
	else if Mek^.V > 10 then Mek^.V := 10;

	{ Check Stats - No Stats are defined. }
	for t := 1 to NumGearStats do Mek^.Stat[ T ] := 0;
end;

Function IsLegalMechaSubCom( Part, Equip: GearPtr ): Boolean;
	{ Return TRUE if EQUIP can be installed as a subcomponent }
	{ of PART, FALSE otherwise. Both inputs should be properly }
	{ defined & initialized. }
begin
	if Equip^.G = GG_Module then begin
		{ The size of a module may not exceed the declared }
		{ size of the mecha by more than one, and the size }
		{ of the BODY module must exactly match the size of }
		{ the mecha. }
		if Equip^.S = 1 then begin
			if Equip^.V = Part^.V then IsLegalMechaSubCom := True
			else IsLegalMechaSubCom := False;
		end else begin
			if Equip^.V <= ( Part^.V + 1 ) then IsLegalMechaSubCom := True
			else IsLegalMechaSubCom := False;
		end;

	{ Mecha can mount modification gears. }
	end else if Equip^.G = GG_Modifier then begin
		IsLegalMechaSubCom := AStringHasBString( SAttValue( Equip^.SA , 'TYPE' ) , 'MECHA' );

	{ No other components may be subcoms of a mecha. }
	end else IsLegalMechaSubCom := False;
end;

Function MechaTraitDesc( Mek: GearPtr ): String;
	{ Create a string describing the traits of this mecha. }
	{ At the moment, this only contains form name. }
begin
	MechaTraitDesc := FormName[ Mek^.S ];
end;

end.
