unit ghmodule;
	{This unit holds modules- arms, legs, pods... body}
	{parts, basically. Both mecha and living creatures}
	{use the same module descriptions.}
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

uses gears,ghmecha;

Type
	ModuleDesc = Record
		name: String;
		MHP: Byte;	{Module Hit Points}
	end;


Const
	NumModule = 8;

	GS_Body = 1;
	GS_Head = 2;
	GS_Arm = 3;
	GS_Leg = 4;
	GS_Wing = 5;
	GS_Tail = 6;
	GS_Turret = 7;
	GS_Storage = 8;

	STAT_Armor = 1;

	{ This array tells which modules are usable by which forms. }
	{ Some systems ( movers, sensors, cockpits ) will function no matter where they are mounted. }
	{ Others ( weapons, shields, hands ) will not function if placed in a bad module. }
	FORMxMODULE: Array [0..NumForm-1, 1..NumModule] of Boolean = (
{		 	Body	Head	Arm	Leg	Wing	Tail	Turret	Storage }
{Battroid}	(	True,	True,	True,	True,	True,	True,	False,	True	),
{Zoanoid}	(	True,	True,	False,	True,	True,	True,	False,	True	),
{GroundHugger}	(	True,	False,	False,	False,	False,	False,	True,	True	),
{Arachnoid}	(	True,	True,	False,	True,	False,	True,	True,	True	),
{AeroFighter}	(	True,	False,	False,	False,	True,	False,	False,	True	),
{Ornithoid}	(	True,	True,	False,	True,	True,	True,	False,	True	),
{Gerwalk}	(	True,	True,	True,	True,	True,	True,	False,	True	),
{HoverFighter}	(	True,	False,	False,	False,	True,	False,	True,	True	),
{GroundCar}	(	True,	False,	False,	False,	False,	False,	True,	True	)

	);

	{ MODULE HIT POINT DEFINITIONS }
	{All these definitions are based on the module's size.}
	MHP_NoHP = 0;		{Used for storage pods. All dmg passed on to SubMods.}
	MHP_HalfSize = 4;	{ HP = ( Size + 1 ) div 2 }
	MHP_EqualSize = 1;	{ HP = Size }
	MHP_SizePlusOne = 2;	{ HP = Size + 1 }
	MHP_SizeTimesTwo = 3;	{ HP = Size * 2 }

	CModule: Array [1..NumModule] of ModuleDesc = (
		(	name: 'Body';
			MHP: MHP_SizeTimesTwo;
		),
		(	name: 'Head';
			MHP: MHP_HalfSize;
		),
		(	name: 'Arm';
			MHP: MHP_EqualSize;
		),
		(	name: 'Leg';
			MHP: MHP_SizePlusOne;
		),
		(	name: 'Wing';
			MHP: MHP_HalfSize;
		),
		(	name: 'Tail';
			MHP: MHP_EqualSize;
		),
		(	name: 'Turret';
			MHP: MHP_HalfSize;
		),
		(	name: 'Storage';
			MHP: MHP_NoHP;
		)
	);


	{ MODIFIER GEAR }
	{ G = GG_Modifier             }
	{ S = Modification Type       }
	{ V = Cybernetic Trauma Value }

	GS_StatModifier = 1;
	GS_SkillModifier = 2;

	{ Only one gear with a given 'cyberslot' type should be installed }
	{ at any given time. Attempting to install another should result }
	{ in the first being deleted. }
	{ Without a cyberslot, the modifier won't interfere with other }
	{ modifier gears at all. }
	{ Sample slot names: EYE, EAR, MUSCULAR, SKELETON, HEART, etc. }
	SATT_CyberSlot = 'CYBERSLOT';

	STAT_SkillToModify = 1;
	STAT_SkillModBonus = 2;


Function LookupModuleCode(const name_in: String): Integer;

Procedure InitModule(Part: GearPtr);
Function ModuleBaseDamage(Part: GearPtr): Integer;
Function ModuleComplexity( Part: GearPtr ): Integer;
Function ModuleName(Part: GearPtr): String;
Function ModuleBaseMass(Part: GearPtr): Integer;

Procedure CheckModuleRange( Part: GearPtr );

Function IsLegalModuleInv( Slot, Equip: GearPtr ): Boolean;
Function IsLegalModuleSub( Slot, Equip: GearPtr ): Boolean;

Function ModifierCost( Part: GearPtr ): LongInt;
Procedure CheckModifierRange( Part: GearPtr );


implementation

uses ghholder,texutil;


Function LookupModuleCode(const name_In: String): Integer;
	{Locate the module code which corresponds to the name}
	{provided. If no such module type exists return a -1.}
var
	T,M: Integer;
        Name: String;
begin
	M := -1;

	{Set the NAME to upper case.}
	Name := UpCase(Name_In);
	for t := 1 to NumModule do begin
		if UpCase(CModule[T].Name) = Name then M := T;
	end;
	LookupModuleCode := M;
end;

Procedure InitModule(Part: GearPtr);
	{PART is a newly created module record.}
	{Initialize its stuff.}
begin
	{ Modules inherit GearOps/Material from their parent. }
	if Part^.Parent <> Nil then begin
		SetNAtt( Part^.NA , NAG_GearOps , NAS_Material , NAttValue( Part^.Parent^.NA , NAG_GearOps , NAS_Material ) );
	end;
end;

Function ModuleBaseDamage(Part: GearPtr): Integer;
	{For module PART, calculate the unscaled amount of}
	{damage that it can take before being destroyed.}
var
	it: Integer;
begin
	{Error check - make sure we actually have a Module.}
	if Part = Nil then Exit(0);
	if Part^.G <> GG_Module then Exit(0);
	if (Part^.S < 1) or (Part^.S > NumModule) then Exit(0);

	Case CModule[Part^.S].MHP of
		MHP_NoHP:		it := -1;
		MHP_HalfSize:		it := ( Part^.V + 1 ) div 2;
		MHP_EqualSize:		it := Part^.V;
		MHP_SizePlusOne:	it := Part^.V + 1;
		MHP_SizeTimesTwo: 	it := Part^.V * 2;
	else it := 0;
	end;

	ModuleBaseDamage := it;
end;

Function ModuleComplexity( Part: GearPtr ): Integer;
	{ Return the complexity value for this part. }
begin
	if ( Part^.S = GS_Body ) or ( Part^.S = GS_Storage ) then begin
		ModuleComplexity := ( Part^.V + 1 ) * 2;
	end else begin
		ModuleComplexity := Part^.V + 1;
	end;
end;

Function ModuleName(Part: GearPtr): String;
	{Determine the geneic name for this particular module.}
begin
	{Eliminate all error cases first off...}
	if (Part = Nil) or (Part^.G <> GG_Module) or (Part^.S < 1) or (Part^.S > NumModule) then Exit('Unknown');

	ModuleName := CModule[Part^.S].Name;
end;

Function ModuleBaseMass(Part: GearPtr): Integer;
	{For module PART, calculate the unscaled mass.}
var
	it: Integer;
begin
	{Error check - make sure we actually have a Module.}
	if Part = Nil then Exit(0);
	if Part^.G <> GG_Module then Exit(0);
	if (Part^.S < 1) or (Part^.S > NumModule) then Exit(0);

	Case CModule[Part^.S].MHP of
		MHP_NoHP:			it := 0;
		MHP_EqualSize,MHP_Halfsize:	it := Part^.V;
		MHP_SizePlusOne:		it := Part^.V + 1;
		MHP_SizeTimesTwo:	 	it := Part^.V * 2;
	else it := 0;
	end;

	{Armor also adds weight to a module.}
	it := it + Part^.Stat[ STAT_Armor ];

	ModuleBaseMass := it;
end;

Procedure CheckModuleRange( Part: GearPtr );
	{ Check a MODULE gear to make sure all values are within appropriate }
	{ range. }
var
	InAMek: Boolean;
	T: Integer;
begin
	{ Check S - Module Type }
	if Part^.S < 1 then Part^.S := GS_Storage
	else if Part^.S > NumModule then Part^.S := GS_Storage;

	if ( Part^.Parent = Nil ) then InAMek := False
	else if Part^.Parent^.G = GG_Mecha then InAMek := True
	else InAMek := False;

	{ Check V - Module Size }
	{ If this module is installed in a Mecha, there'll be a }
	{ limit on its size. }
	if InAMek then begin
		if Part^.S = GS_Body then Part^.V := Part^.Parent^.V
		else if Part^.V > ( Part^.Parent^.V + 1 ) then Part^.V := ( Part^.Parent^.V + 1 );
	end;
	if Part^.V > 10 then Part^.V := 10;

	{ Check Stats }
	{ Stat 1 - Armor }
	if Part^.Stat[1] < 0 then Part^.Stat[1] := 0
	else if InAMek then begin
		{ Armor rating may not exceed the size of the mecha. }
		if Part^.Stat[1] > Part^.Parent^.V then Part^.Stat[1] := Part^.Parent^.V;
	end else begin
		if Part^.Stat[1] > 10 then Part^.Stat[1] := 10;
	end;
	for t := 2 to NumGearStats do Part^.Stat[ T ] := 0;
end;

Function IsLegalModuleInv( Slot, Equip: GearPtr ): Boolean;
	{ Check EQUIP to see if it can be stored in SLOT. }
	{ INPUTS: Slot and Equip must both be properly allocated gears. }
	{ See therules.txt for a list of acceptable equipment. }
var
	it: Boolean;
begin
	if Slot^.S = GS_Arm then begin
		Case Equip^.G of
			GG_ExArmor:	begin
					it := Slot^.S = Equip^.S;
					end;
			GG_Shield:	it := true;
			else it := False;
		end;
	end else if Slot^.S = GS_Tail then begin
		Case Equip^.G of
			GG_ExArmor:	begin
					it := Slot^.S = Equip^.S;
					end;
			GG_Shield:	it := true;
			else it := False;
		end;
	end else begin
		Case Equip^.G of
			GG_ExArmor:	begin
					it := Slot^.S = Equip^.S;
					end;
			else it := False;
		end;
	end;

	{ If the item is of a different scale than the holder, }
	{ it can't be held. }
	if Equip^.Scale <> Slot^.Scale then it := False;

	IsLegalModuleInv := it;
end;

Function IsLegalModuleSub( Slot, Equip: GearPtr ): Boolean;
	{ Return TRUE if EQUIP can be installed in SLOT, }
	{ FALSE otherwise. }
begin
	if Slot^.S = GS_Body then begin
		case Equip^.G of
			GG_Cockpit:	IsLegalModuleSub := True;
			GG_Weapon:	IsLegalModuleSub := True;
			GG_MoveSys:	IsLegalModuleSub := True;
			GG_Holder:	begin
						if Equip^.S = GS_Hand then IsLegalModuleSub := False
						else IsLegalModuleSub := True;
					end;
			GG_Sensor:	IsLegalModuleSub := True;
			GG_Electronics:	IsLegalModuleSub := True;
			GG_Support:	IsLegalModuleSub := True;
		else IsLegalModuleSub := False
		end;
	end else begin
		case Equip^.G of
			GG_Cockpit:	IsLegalModuleSub := True;
			GG_Weapon:	IsLegalModuleSub := True;
			GG_MoveSys:	IsLegalModuleSub := True;
			GG_Holder:	begin
						if ( Equip^.S = GS_Hand ) and ( Slot^.S <> GS_Arm ) then IsLegalModuleSub := False
						else IsLegalModuleSub := True;
					end;
			GG_Sensor:	IsLegalModuleSub := True;
			GG_Electronics:	IsLegalModuleSub := True;

		else IsLegalModuleSub := False
		end;
	end;
end;

Function ModifierCost( Part: GearPtr ): LongInt;
	{ The cost of a modifier part will depend upon how many +s it }
	{ gives versus how many -s it imparts. }
const
	BasePrice: Array [1..5] of Byte = (10,25,45,70,100);
	PriceFactor = 2000;
var
	plusses,minuses,T: Integer;
	it: LongInt;
begin
	{ Initialize our counters. }
	plusses := 0;
	minuses := 0;

	{ Count up the plusses and minuses. }
	if Part^.S = GS_StatModifier then begin
		for t := 1 to NumGearStats do begin
			if Part^.Stat[ T ] > 0 then begin
				plusses := plusses + Part^.Stat[ T ];
			end else if Part^.Stat[ T ] < 0 then begin
				minuses := minuses - Part^.Stat[ T ];
			end;
		end;
	end else if Part^.S = GS_SkillModifier then begin
		Plusses := Part^.Stat[ STAT_SkillModBonus ];
	end;

	it := 0;
	if Plusses > 5 then begin
		it := it + ( PriceFactor * 50 * ( Plusses - 5 ) );
		Plusses := 5;
	end;
	if Plusses > 0 then begin
		it := BasePrice[ Plusses ] * PriceFactor + it;
	end;
	if Minuses > 0 then begin
		it := it - PriceFactor * 5 * Minuses;
	end else begin
		{ If no minuses, a 50% increase in price. }
		it := ( it * 3 ) div 2;
	end;

	{ Reduce cost by the trauma value of the system. }
	if AStringHasBString( SAttValue( Part^.SA , 'TYPE' ) , 'CHARA' ) then begin
		it := ( it * ( 100 - Part^.V ) ) div 100;
	end else begin
		{ Non-character modifiers are considerably cheaper. }
		it := it div 2;
	end;

	{ Reduce cost for a non-combat skillmodifier. }
	if ( Part^.S = GS_SkillModifier ) and ( Part^.Stat[ STAT_SkillToModify ] > 10 ) then it := it div 2;

	{ Make sure the cost doesn't fall below the minimum value. }
	if it < PriceFactor then it := PriceFactor;

	{ Return the calculated value. }
	ModifierCost := it;
end;

Procedure CheckModifierRange( Part: GearPtr );
	{ Make sure that this modification gear is within the accepted }
	{ range bands. }
var
	T: Integer;
begin
	{ S = Modifier Type, must be 1 or 2. }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > 2 then Part^.S := 2;

	{ V = Trauma Value, may be from 0 to 80 }
	if Part^.V < 0 then Part^.V := 0
	else if Part^.V > 100 then Part^.V := 80;

	{ Scale - Must be 0! }
	if Part^.Scale <> 0 then Part^.Scale := 0;

	{ Check the stats for range. }
	if Part^.S = GS_StatModifier then begin
		for t := 1 to NumGearStats do begin
			if Part^.Stat[ T ] > 10 then Part^.Stat[ T ] := 10
			else if Part^.Stat[ T ] < -5 then Part^.Stat[ T ] := -5;
		end;

	end else if Part^.S = GS_SkillModifier then begin
		if Part^.Stat[ 2 ] < 1 then Part^.Stat[ 2 ] := 1
		else if Part^.Stat[ 2 ] > 10 then Part^.Stat[ 2 ] := 10;
	end;

end;

end.
