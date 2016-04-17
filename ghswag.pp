unit ghswag;
	{ This unit handles various items that will probably be }
	{ carried around by adventurers, but not might be found }
	{ in the tactical game. }
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

	{ SWAG format }
	{ G = GG_Swag               }
	{ S = Swag Exponent         }
	{ V = Swag Value            }
	{   Treasure:    V = Unscaled value in credits }

	{ USABLE format }
	{ G = GG_Usable             }
	{ S = Action Type           }
	{ V = Gear Value            }
	{ STAT 1 -> Skill Roll Bonus }
	{ STAT 2 -> Damage Rating    }

	{ REPAIRFUEL format }
	{ G = GG_Usable             }
	{ S = Repair Type           }
	{ V = DP Capacity           }

	{ CONSUMABLE format }
	{ G = GG_CONSUMABLE         }
	{ S = NA                    }
	{ V = Hunger Points         }

Const
	STAT_MoraleBoost = 1;
	STAT_FoodEffectValue = 2;
	STAT_FoodQuantity = 3;

	NumUsableType = 1;
	GS_Instrument = 1;
	STAT_UseBonus = 1;
	STAT_UseRange = 2;


Function SwagName( Part: GearPtr ): String;
Function SwagBaseMass( Part: GearPtr ): Integer;
Procedure CheckSwagRange( Part: GearPtr );
Function SwagValue( Part: GearPtr ): LongInt;

Function UsableName( Part: GearPtr ): String;
Function UsableDamage( Part: GearPtr ): Integer;
Function UsableValue( Part: GearPtr ): Integer;
Procedure CheckUsableRange( Part: GearPtr );

Function RepairFuelName( Part: GearPtr ): String;
Procedure CheckRepairFuelRange( Part: GearPtr );

Procedure CheckFoodRange( Part: GearPtr );
Function FoodMass( Part: GearPtr ): Integer;
Function FoodValue( Part: GearPtr ): LongInt;

implementation

uses ghchars;

Const
	{ PATCH_I18N: Don't translate here, use GameData/I18N_name.txt. }
	UsableTypeName: Array [1..NumUsableType] of String = (
	'Instrument'
	);


Function SwagName( Part: GearPtr ): String;
	{ This function will make up a default name for the provided item. }
begin
	{ PATCH_I18N: Don't translate it. }
	SwagName := 'Thing';
end;

Function SwagBaseMass( Part: GearPtr ): Integer;
	{ This function will find the mass of the provided item. }
begin
	SwagBaseMass := 1;
end;

Procedure CheckSwagRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check S - Swag Exponent }
	if Part^.S < 0 then Part^.S := 0
	else if Part^.S > 6 then Part^.S := 6;
end;

Function SwagValue( Part: GearPtr ): LongInt;
	{ This function will find the cost of the provided item. }
var
	it,T: LongInt;
begin
	it := Part^.V;
	for t := 1 to Part^.S do it := it * 10;
	SwagValue := it;
end;

Function UsableName( Part: GearPtr ): String;
	{ This function will make up a default name for the provided item. }
begin
	UsableName := UsableTypeName[ Part^.S ];
end;

Function UsableDamage( Part: GearPtr ): Integer;
	{ Return how much damage this usable gear can withstand. }
begin
	UsableDamage := Part^.V + 1;
end;

Function UsableValue( Part: GearPtr ): Integer;
	{ Return the value of this usavle gear. }
begin
	UsableValue := ( 50 + Part^.Stat[ STAT_UseBonus ] * Part^.Stat[ STAT_UseBonus ] * Part^.Stat[ STAT_UseBonus ] * 10 + Part^.V * 5 ) * ( Part^.Stat[ STAT_UseRange ] + 5 ) div 10;
end;

Procedure CheckUsableRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check S - Swag Type }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > NumUsableType then Part^.S := NumUsableType;

	{ Check V - Damage Capacity }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 20 then Part^.V := 20;

	{ Check STAT 1 - Ability Bonus }
	if Part^.Stat[ STAT_UseBonus ] < 0 then Part^.Stat[ STAT_UseBonus ] := 0
	else if Part^.Stat[ STAT_UseBonus ] > 5 then Part^.Stat[ STAT_UseBonus ] := 5;

	{ Check stat 2 - Range }
	if Part^.Stat[ STAT_UseRange ] < 1 then Part^.Stat[ STAT_UseRange ] := 1
	else if Part^.Stat[ STAT_UseRange ] > 10 then Part^.Stat[ STAT_UseRange ] := 10;
end;

Function RepairFuelName( Part: GearPtr ): String;
	{ Returns a default name for some repairfuel. }
begin
	{ PATCH_I18N: Don't translate it. }
	RepairFuelName := SkillMan[ Part^.S ].Name + ' Kit';
end;

Procedure CheckRepairFuelRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check S - Skill Type }
	if Part^.S < 1 then Part^.S := 23
	else if Part^.S > NumSkill then Part^.S := 23;
end;

Procedure CheckFoodRange( Part: GearPtr );
	{ Check the range for this consumable gear. }
begin
	{ V = Hunger Value }
	if Part^.V < 0 then Part^.V := 0
	else if Part^.V > 60 then Part^.V := 60;

	{ Stat 1 = Morale Boost }
	if Part^.Stat[ STAT_MoraleBoost ] > 10 then Part^.Stat[ STAT_MoraleBoost ] := 10
	else if Part^.Stat[ STAT_MoraleBoost ] < -5 then Part^.Stat[ STAT_MoraleBoost ] := -5;

	{ Stat 2 - Extra Value }
	if Part^.Stat[ STAT_FoodEffectValue ] < 0 then Part^.Stat[ STAT_FoodEffectValue ] := 0;

	{ Stat 3 - Quantity }
	if Part^.Stat[ STAT_FoodQuantity ] > 50 then Part^.Stat[ STAT_FoodQuantity ] := 50
	else if Part^.Stat[ STAT_FoodQuantity ] < 1 then Part^.Stat[ STAT_FoodQuantity ] := 1;
end;

Function FoodMass( Part: GearPtr ): Integer;
	{ Return the basic mass value for this food. }
begin
	FoodMass := ( Part^.V * Part^.Stat[ STAT_FoodQuantity ] ) div 5;
end;

Function FoodValue( Part: GearPtr ): LongInt;
	{ Return the cost of this food. }
var
	it,M: LongInt;
begin
	it := Part^.V + Part^.Stat[ Stat_FoodEffectValue ];

	if Part^.Stat[ STAT_MoraleBoost ] > 0 then begin
		it := it + ( Part^.Stat[ STAT_MoraleBoost ] * ( 150 - 2 * Part^.V ) );
	end else begin
		M := it * ( Part^.Stat[ STAT_MoraleBoost ] + 10 ) div 10;
		if M < ( it div 2 ) then M := it div 2;
		it := M;
	end;

	it := it * Part^.Stat[ sTAT_FoodQuantity ];

	FoodValue := it;
end;

end.
