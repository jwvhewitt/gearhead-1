unit ghsupport;
	{ This unit handles support gears - various things needed for a }
	{ mecha's operation which don't fit in elsewhere. }
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

	{ *** RULES *** }
	{ - Support gears may only be installed in the BODY module. }
	{ - Every mecha needs an engine. }

interface

uses gears;

	{ *** SUPPORT FORMAT *** }
	{ G = GG_Support }
	{ S = System Type }
	{ V = System Rating }
	{ Stat[1] = Armor Rating }
	{ Stat[2] = Engine Subtype }

const
	NumSupportType = 2;
	GS_Gyro = 1;
	GS_Engine = 2;

	STAT_EngineSubType = 2;
	EST_HighOutput = 1;


Function SupportBaseDamage( Part: GearPtr ): Integer;
Function SupportName( Part: GearPtr ): String;
Function SupportBaseMass( Part: GearPtr ): Integer;
Function SupportValue( Part: GearPtr ): LongInt;
Procedure CheckSupportRange( Part: GearPtr );


implementation

const
	{ PATCH_I18N: Don't translate here, use GameData/I18N_name.txt. }
	SupName: Array [1..NumSupportType] of String = (
		'Gyroscope','Engine'
	);

Function SupportBaseDamage( Part: GearPtr ): Integer;
	{ Return the amount of damage this system can withstand. }
begin
	if Part^.S = GS_Engine then begin
		SupportBaseDamage := 3;
	end else begin
		SupportBaseDamage := 1;
	end;
end;

Function SupportName( Part: GearPtr ): String;
	{ Return a name for this particular sensor. }
begin
	SupportName := SupName[ Part^.S ];
end;

Function SupportBaseMass( Part: GearPtr ): Integer;
	{ Return the mass of this system. }
begin
	{ The mass is equal to the armor value }
	SupportBaseMass := Part^.Stat[1];
end;

Function SupportValue( Part: GearPtr ): LongInt;
	{ Calculate the base cost of this sensor type. }
var
	it: LongInt;
begin
	if Part^.S = GS_Gyro then begin
		it := Part^.V * Part^.V * 30;
	end else if Part^.S = GS_Engine then begin
		case Part^.Stat[ STAT_EngineSubType ] of
			EST_HighOutput: it := Part^.V * 1000;
			else it := Part^.V * 45;
		end;
	end else it := Part^.V * 45;

	{ Add the armor cost. }
	it := it + Part^.Stat[1] * 25;

	SupportValue := it;
end;


Procedure CheckSupportRange( Part: GearPtr );
	{ Examine this support system to make sure everything is legal. }
begin
	{ Check S - System Type }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > NumSupportType then Part^.S := 1;

	{ Check V - System Rating. Must be in the range from 1 to 10. }
	if ( Part^.S = GS_Engine ) and ( Part^.Parent <> Nil ) then begin
		if Part^.V <> Part^.Parent^.V then Part^.V := Part^.Parent^.V;
		if Part^.Scale <> Part^.Parent^.Scale then Part^.Scale := Part^.Parent^.Scale;
	end else begin
		if Part^.V < 1 then Part^.V := 1
		else if Part^.V > 10 then Part^.V := 10;
	end;


	{ Check Stats - Stat 1 is armor. }
	if Part^.Stat[1] < 0 then Part^.Stat[1] := 0
	else if Part^.Stat[1] > 2 then Part^.Stat[2] := 2;
end;

end.
