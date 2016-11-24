unit ghguard;
	{ This unit is meant to handle Shields and External Armor. }
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

	{ *** SHIELD FORMAT *** }
	{ G = GG_Shield }
	{ S = Shield Type }
	{ V = Armor Rating }

	{ *** EXARMOR FORMAT *** }
	{ G = GG_ExArmor }
	{ S = Module Fit }
	{ V = Armor Rating }


const
	STAT_ShieldBonus = 1;	{ Bonus to defense roll when using this shield. }

	NumShieldType = 2;
	GS_PhysicalShield = 0;
	GS_EnergyShield = 1;

Function ShieldName( Part: GearPtr ): String;
Function ShieldBaseMass( Part: GearPtr ): Integer;
Function ShieldValue( Part: GearPtr ): LongInt;
Procedure CheckShieldRange( Part: GearPtr );
Function IsLegalShieldSub( Part, Equip: GearPtr ): Boolean;

Function ArmorName( Part: GearPtr ): String;
Function ArmorBaseMass( Part: GearPtr ): Integer;
Function ArmorValue( Part: GearPtr ): LongInt;
Procedure CheckArmorRange( Part: GearPtr );
Function IsLegalArmorSub( Part, Equip: GearPtr ): Boolean;

Function ArmorFitsMaster( Armor,Master: GearPtr ): Boolean;


implementation

uses ghchars,ghmecha,ghmodule,texutil;

Function ShieldName( Part: GearPtr ): String;
	{ Return a name for this particular shield. }
begin
	if Part^.S = GS_PhysicalShield then begin
		ShieldName := 'Class '+BStr( Part^.V ) + ' Shield';
	end else begin
		ShieldName := 'Class '+BStr( Part^.V ) + ' Beam Shield';
	end;
end;

Function ShieldBaseMass( Part: GearPtr ): Integer;
	{ Return the weight of this shield. }
	{ Regular shields are heavy; Energy shields are almost weightless. }
var
	it: Integer;
begin
	{ The base weight of a shield is its PV + Bonus. }
	{ Easier to defend with shields tend to be larger, so they are heavier. }
	if Part^.S = GS_PhysicalShield then begin
		it := Part^.V + Part^.Stat[ STAT_ShieldBonus ];
		if it < 1 then it := 1;
	end else begin
		{ Energy shields weigh 1 unit for the emitter. }
		it := 1;
	end;
	ShieldBaseMass := it;
end;

Function ShieldValue( Part: GearPtr ): LongInt;
	{ Calculate the value of this shield, ignoring for the moment }
	{ its subcomponents. }
var
	it: LongInt;
begin
	if Part^.S = GS_EnergyShield then it := Part^.V * 75
	else it := Part^.V * 25;

	{ Modify the cost for the shield's defense bonus. }
	if Part^.Stat[ STAT_ShieldBonus ] > 0 then begin
		{ +25% per positive point. }
		it := it * ( 4 + Part^.Stat[ STAT_ShieldBonus ] ) div 4;
	end else if Part^.Stat[ STAT_ShieldBonus ] < 0 then begin
		{ -10% per negative point. }
		it := it * ( 10 + Part^.Stat[ STAT_ShieldBonus ] ) div 10;
	end;

	ShieldValue := it;
end;

Procedure CheckShieldRange( Part: GearPtr );
	{ Examine this sensor to make sure everything is legal. }
begin
	{ Check S - Shield Type }
	if Part^.S < 0 then Part^.S := 0
	else if Part^.S >= NumShieldType then Part^.S := 0;

	{ Check V - Armor Value }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 10 then Part^.V := 10;

	{ Check Stats - Stat 1 = Shield Bonus. }
	if Part^.Stat[ STAT_ShieldBonus ] < -5 then Part^.Stat[ STAT_ShieldBonus ] := -5
	else if Part^.Stat[ STAT_ShieldBonus ] > 5 then Part^.Stat[ STAT_ShieldBonus ] := 5;

end;

Function IsLegalShieldSub( Part, Equip: GearPtr ): Boolean;
	{ TRUE if EQUIP can be installed in the shield, FALSE otherwise. }
begin
	if Part^.S = GS_PhysicalShield then begin
		if Equip^.G = GG_Weapon then IsLegalShieldSub := True
		else IsLegalShieldSub := False;
	end else IsLegalShieldSub := False;
end;

Function ArmorName( Part: GearPtr ): String;
	{ Return a name for this particular armor. }
begin
	ArmorName := 'Class ' + BStr( Part^.V ) + ' ' + CModule[Part^.S].Name + ' Armor';
end;

Function ArmorBaseMass( Part: GearPtr ): Integer;
	{ Return the weight of this armor. }
begin
	ArmorBaseMass := Part^.V * 2;
end;

Function ArmorValue( Part: GearPtr ): LongInt;
	{ Return the cost of this armor. }
begin
	ArmorValue := Part^.V * Part^.V * Part^.V * 5 + Part^.V * Part^.V * 10 + Part^.V * 35;
end;

Procedure CheckArmorRange( Part: GearPtr );
	{ Examine this sensor to make sure everything is legal. }
begin
	{ Check S - Shield Type }
	if Part^.S < 1 then Part^.S := GS_Storage
	else if Part^.S > NumModule then Part^.S := GS_Storage;

	{ Check V - Armor Value }
	{ Note that PV-0 armor may represent normal clothing. }
	if Part^.V < 0 then Part^.V := 0
	else if Part^.V > 10 then Part^.V := 10;

	{ Check Stats - No Stats Defined. }

end;

Function IsLegalArmorSub( Part, Equip: GearPtr ): Boolean;
	{ Return TRUE if EQUIP can be mounted in PART, FALSE otherwise. }
begin
	case Equip^.G of
		GG_Weapon:	IsLegalArmorSub := True;
		GG_MoveSys:	IsLegalArmorSub := True;
		GG_Electronics:	IsLegalArmorSub := True;
	else IsLegalArmorSub := False
	end;
end;

Function ArmorFitsMaster( Armor,Master: GearPtr ): Boolean;
	{ Determine whether or not ARMOR fits MASTER, based upon the }
	{ armor's FITS string. }
var
	ADesc,MDesc: String;
begin
	ADesc := SATTValue( Armor^.SA , 'FITS' );

	if Master = Nil then begin
		MDesc := '';
	end else begin
		case Master^.G of
			GG_Mecha:	MDesc := MechaTraitDesc( Master );
			GG_Character:	MDesc := NPCTraitDesc( Master );
		else MDesc := '';
		end;
	end;

	ArmorFitsMaster := PartMatchesCriteria( MDesc , ADesc );
end;


end.
