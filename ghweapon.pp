unit ghweapon;
	{This unit holds the constants and procedures for dealing}
	{with weapon gears. It also holds the constants and procedures}
	{for dealing with ammunition.}
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

	{ *** WEAPON GEARS *** }
	{ G = GG_WeaponSys }
	{ S = Weapon Type }
	{ V = Damage Value }
	{ Stat[1] = Range. MWs, EMWs, and Missiles with Range = 0 }
	{           may still be thrown. Maybe. }
	{ Stat[2] = Accuracy }
	{ Stat[3] = Recharge Period. Generally 2 shots per round. }
	{ Stat[4] = Burst Value }
	{ Stat[8] = Ammunition Capacity. Only for Ballistic and Missile.}

	{ *** WEAPON ADDON GEARS *** }
	{ G = GG_WeaponAddOn }
	{ S = Fitting type }
	{ V = DC Modifier }
	{ Stat[1] = Range modifier }
	{ Stat[2] = Accuracy modifier }
	{ Stat[3] = Recharge Period modifier }

	{ *** AMMUNITION GEARS *** }
	{ G = GG_Ammo }
	{ S = Weapon Type. Must be Ballistic or Missile.}
	{ V = Ammunition Caliber. Must correspond to weapon size.}
	{ Stat[7] = Ammunition Quantity }

Const
	{This defines the different weapon types.}
	GS_Melee = 0;
	GS_EMelee = 1;
	GS_Ballistic = 2;
	GS_BeamGun = 3;
	GS_Missile = 4;
	GS_Grenade = 5;

	STAT_Range = 1;
	STAT_Accuracy = 2;
	STAT_Recharge = 3;
	STAT_BurstValue = 4;

	STAT_GrenadeSkill = 5;

	{For ballistic weapons & missile weapons}
	STAT_Magazine = 8;

	{For ammunition}
	STAT_AmmoPresent = 7;

	{ Weapon Modification Codes }
	NAG_WeaponModifier = -3;
	NAS_AmmoSpent = 0;
	NAS_Recharge = 1;	{ Recharge time / used in ComTime engine }
	NAS_SafetySwitch = 2;	{ Safety Switch - if nonzero, weapon can't be used. }

	{ Weapon Arc Codes }
	ARC_F90  = 0;	{ Attack Arc - Front 90 degrees }
	ARC_F180 = 1;	{ Attack Arc - Front 180 degrees }
	ARC_360  = 2;	{ Attack Arc - 360 degree fire }

	{ Weapon Damage Data }
	ZoaDmgBonus = 2;	{ H2H damage bonus for Zoanoids. }

	{ ************************************ }
	{ ***   ATTACK  ATTRIBUTES  DATA   *** }
	{ ************************************ }
	{ Stick an attack attribute or status effect name in a weapon's TYPE string }
	{ attribute to activate said ability. }
	Num_Attack_Attributes = 22;
	{ PATCH_I18N: Don't translate it. }
	AA_Name: Array [1..Num_Attack_Attributes] of string = (
		'SWARM', 'BLAST', 'LINE', 'SCATTER', 'EXTEND',
		'HYPER', 'ARMORPIERCING', 'MYSTERY', 'THROWN', 'RETURN',
		'ARMORIGNORE','INTERCEPT','OVERLOAD','BRUTAL', 'FLAIL',
		'ANTIAIR','SMOKE','GAS','DRONE','NOMETAL',
		'STRAIN','COMPLEX'
	);
	AA_Cost: Array [1..Num_Attack_Attributes] of SmallInt = (
		15, 15, 20,  9, 11,     250, 20, 10,15,30,
		85, 25, 15, 20, 25,	12,2,10, 20,10,
		7, 7
	);

	AA_SwarmAttack = 1;
	AA_BlastAttack = 2;
	AA_LineAttack = 3;
	AA_Scatter = 4;
	AA_Extended = 5;
	AA_Hyper = 6;
	AA_ArmorPiercing = 7;
	AA_Mystery = 8;
	AA_Thrown = 9;
	AA_RETURNING = 10;
	AA_ArmorIgnore = 11;
	AA_Intercept = 12;
	AA_Overload = 13;
	AA_Brutal = 14;
	AA_Flail = 15;
	AA_AntiAir = 16;
	AA_Smoke = 17;
	AA_Gas = 18;
	AA_Drone = 19;
	AA_NoMetal = 20;
	AA_Strain = 21;
	AA_Complex = 22;

	Max_Blast_Rating = 16;
	BlastModCost: Array [1..Max_Blast_Rating] of Byte = (
		10, 20, 30, 35, 40, 45,
		50, 55, 60, 65, 70, 75,
		80, 85, 90, 95
	);

	{ ******************************** }
	{ ***   STATUS  EFFECT  DATA   *** }
	{ ******************************** }
	NAG_StatusEffect = 14;
	Num_Status_FX = 25;
	{ When adding a new status effect, remember to update the display }
	{ bits in xxxinfo.pp and also messages.txt and effects.txt. }

	NAS_Haywire = 5;
	NAS_Stoned = 4;
	NAS_Rejection = 9;
	NAS_Depression = 8;
	NAS_Anger = 12;
	NAS_Anemia = 11;
	NAS_Rust = 18;

	{ PATCH_I18N: Don't translate it. }
	SX_Name: Array [1..Num_Status_FX] of String = (
		'POISON','BURN','REGEN','STONE','HAYWIRE',
		'Inhuman Visage', 'Twitchy Hands', 'Depression', 'Rejection', 'Body Aches',
		'Anemia', 'Irrational Anger', 'Neural Lag', 'Major Neural Failure', 'Cerebrospinal Shock',
		'Toxic Leakage', 'Shutdown', 'RUST', 'STUN', 'SICKNESS',
		'Half-Blinded', 'Spinal Injury', 'Torn Ligaments', 'Crushed Bones', 'Heart Injury'
	);
	SX_ResistTarget: Array [1..Num_Status_FX] of SmallInt = (
	{ Determines how hard it is to get rid of this status }
	{ effect once you have it. }
		12, -1, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 10, 4, 20,
		0,0,0,0,0
	);
	SX_RepSkill: Array [1..Num_Status_FX] of Byte = (
	{ This tells what repair skill is needed to heal the status effect, or 0 for none. }
		16,23,0,0,15,
		16,16,16,16,16,
		16,16,16,16,16,
		16,16,15,20,16,
		0,0,0,0,0
	);
	SX_RepCost: Array [1..Num_Status_FX] of Integer = (
	{ This tells how many repair points to remove FX. }
		10,5,0,0,15,
		60,50,75,100,120,
		150,500,1500,2000,3000,
		4500,10000,100,1,20,
		0,0,0,0,0
	);
	SX_Cost: Array [1..Num_Status_FX] of Byte = (
	{ This tells how much a weapon with this status effect costs. }
		15,19,5,20,20,
		10,10,10,10,10,
		10,10,10,10,10,
		10,10,95,12,15,
		10,10,10,10,10
	);
	SX_Vunerability: Array [1..Num_Status_FX,0..NumMaterial] of Boolean = (
	{ tells what materials are affected by this status effect. }
		( False , True , False ),	{ Poison }
		( True , True , True ),	{ Burn }
		( False, True , True ),	{ Regen }
		( False, True , False ),	{ Stoned }
		( True, False , False ),	{ Haywire }
		( False, False , False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( False, False, False ),	{ Cyber side effect }
		( True, False, False ),		{ Rust }
		( FALSE, TRUE, True ),		{ Stun }
		( FALSE, TRUE, False ),		{ Sickness }
		( False, False , False ),	{ Perminant Injury }
		( False, False , False ),	{ Perminant Injury }
		( False, False , False ),	{ Perminant Injury }
		( False, False , False ),	{ Perminant Injury }
		( False, False , False )	{ Perminant Injury }
	);
	SX_Effect_String: Array [1..Num_Status_FX] of String = (
		'0 1 0 12 ARMORIGNORE CANRESIST',
		'0 2 0 16 CANRESIST',
		'2 1 20 0',	{ Regen: Heal(2) Step1 by FirstAid(20) }
		'',	{ Stoned }
		'',	{ Haywire }
		'','','','','',	{ Cyber side effects }
		'','','','',	{ Cyber side effects }
		'1 1 4 5 CanResist',	{ Cerebrospinal Shock }
		'1 1 1 5 CanResist',	{ Toxic Leak }
		'0 1 0 10 ARMORIGNORE CANRESIST',	{ Shutdown }
		'',	{ Rust }
		'',	{ Stun }
		'',	{ Sickness }
		'','','','',''	{ Perminant injuries }
	);
	SX_StatMod: Array [1..Num_Status_FX , 1..NumGearStats ] of SmallInt = (
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Poison }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Burn }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Regen }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Stoned }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Haywire }
		( 0, 0, 0, 0, 0, 0, 0,-5),	{ Inhuman Visage }
		( 0, 0, 0, 0,-5, 0, 0, 0),	{ Twitchy Hands }
		( 0, 0, 0, 0, 0, 0, 0,-2),	{ Depression }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Rejection }
		(-5, 0, 0, 0, 0, 0, 0, 0),	{ Body Aches }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Anemia }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Irrational Anger }
		( 0, 0,-5, 0, 0, 0, 0, 0),	{ Neural Lag }
		(-5, 0,-6,-5,-3,-5,-1,-7),	{ Major Neural Failure }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Cerebrospinal Shock }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Toxic Leak }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Shutdown }
		( 0, 0, 0, 0, 0, 0, 0, 0),	{ Rust }
		( 0, 0,-5, 0, 0, 0, 0, 0),	{ Stun }
		(-2,-2,-2,-2,-2,-2,-2,-2),	{ Sickness }
		( 0, 0, 0,-7, 0, 2, 0, 0),	{ Blinded in one eye }
		(-2,-4,-3, 0, 0, 0, 0, 0),	{ Spinal Injury }
		(-5,-2,-2, 0, 0, 0, 0, 0),	{ Torn Ligaments }
		(-3,-3,-4, 0,-2, 0, 0, 0),	{ Crushed Bones }
		(-2,-5,-2, 0, 0,-2, 0, 0)	{ Heart Problem }
	);

	{ PATCH_I18N: Don't translate here, use GameData/I18N_name.txt. }
	DefaultWeaponName: Array [0..4] of String = (
		'Melee Weapon',
		'Energy Weapon',
		'Gun',
		'Beam Gun',
		'Missile Launcher'
	);

	GS_General_AO = 0;	{ These constants describe what kind of weapon }
	GS_Gun_AO = 1;		{ an addon can be assigned to. }
	GS_Heavy_AO = 2;
	GS_Melee_AO = 3;



Function ScaleDC( DC,Scale: LongInt ): LongInt;
Function DCName( DC,Scale: LongInt ): String;

Procedure InitWeapon( Weapon: GearPtr );
Procedure InitAmmo( Ammo: GearPtr );
Function WeaponBaseDamage( Weapon: GearPtr ): Integer;
Function WeaponBaseMass( Weapon: GearPtr ): Integer;
Function AmmoBaseDamage( Ammo: GearPtr ): Integer;
Function AmmoBaseMass( Ammo: GearPtr ): Integer;
Function AmmoName( Ammo: GearPtr ): String;

Function NotGoodAmmo( Wep , Mag: GearPtr ): Boolean;
Procedure CheckWeaponRange( Wpn: GearPtr );
Procedure CheckWeaponAddOnRange( Wpn: GearPtr );
Function IsLegalWeaponInv( Slot , Equip: GearPtr ): Boolean;
Function IsLegalWeaponSub( Wep, Equip: GearPtr ): Boolean;
Procedure CheckAmmoRange( Ammo: GearPtr );

Function WeaponValue( Part: GearPtr ): LongInt;
Function WeaponAddOnCost( Part: GearPtr ): LongInt;
Function BaseAmmoValue( Part: GearPtr ): Int64;
Function AmmoValue( Part: GearPtr ): LongInt;

Function WeaponComplexity( Part: GearPtr ): Integer;

Function WeaponArc( Weapon: GearPtr ): Integer;
Function WeaponName( Weapon: GearPtr ): String;

Function CanDamageBeamShield( Weapon: GearPtr ): Boolean;

Function HasStatus( Mek: GearPtr; SFX: Integer ): Boolean;

implementation

uses texutil,gearutil,ghmodule,ghintrinsic;

Function ScaleDC( DC,Scale: LongInt ): LongInt;
	{ Take the basic, unscaled damage class DC and change it }
	{ to a scaled value. }
var
	T: Integer;
begin
	if Scale > 0 then DC := DC * 2;
	if Scale > 1 then begin
		for t := 2 to Scale do DC := DC * 5;
	end;
	ScaleDC := DC;
end;

Function DCName( DC,Scale: LongInt ): String;
	{ Take the requested Damage Class, and express it as a string. }
var
	msg: String;
begin
	msg := 'DC' + BStr( DC );
	if Scale > 0 then begin
		{ Find the scale multiplier factor for this scale }
		{ by scaling up one point of damage. }
		Scale := ScaleDC( 1 , Scale );

		{ Add this to the message. }
		msg := msg + 'x' + BStr( Scale );
	end;
	DCName := msg;
end;

Procedure InitWeapon( Weapon: GearPtr );
	{Given Weapon's size and type, initialize all of its}
	{fields to the default values.}
begin
	{ The main purpose of this unit is to fill in default missile weapon }
	{ ranges so "vanilla" weapons will have some character. }
	if Weapon^.S = GS_Ballistic then begin
		{Set default range.}
		Weapon^.Stat[STAT_Range] := ( Weapon^.V + 1 ) div 2;

		{Set default ammo capacity.}
		Weapon^.Stat[STAT_Magazine] := 10;

	end else if Weapon^.S = GS_BeamGun then begin
		{Set default range.}
		Weapon^.Stat[STAT_Range] := Weapon^.V div 2 + 2;

	end else if Weapon^.S = GS_Missile then begin
		{Set default range.}
		Weapon^.Stat[STAT_Range] := Weapon^.V div 3 + 3;

		{Set default ammo capacity.}
		Weapon^.Stat[STAT_Magazine] := 10;
	end;

	{ Set default recharge period for all weapons. }
	Weapon^.Stat[STAT_Recharge] := 2;
end;

Procedure InitAmmo( Ammo: GearPtr );
	{Initialize an ammo gear.}
begin
	{ Set default # of shots. If the ammo is loaded into a gun, the default }
	{ is the magazine capacity of the gun. }
	if ( Ammo^.Parent <> Nil ) and ( Ammo^.Parent^.G = GG_Weapon ) then begin
		Ammo^.Stat[STAT_AmmoPresent] := Ammo^.Parent^.Stat[STAT_Magazine];
		{ Also set name to match the gun }
		SetSAtt(Ammo^.SA,'NAME <' + GearName(Ammo^.Parent) +
			' Clip' + '>');
	end else begin
		Ammo^.Stat[STAT_AmmoPresent] := 1;
	end;
	Ammo^.Stat[ STAT_GrenadeSkill ] := 2;
end;

Function WeaponBaseDamage( Weapon: GearPtr ): Integer;
	{The base damage of most weapons is equal to its Damage.}
	{The exceptions are EMWs, which are fragile, and}
	{missile launchers, which pass damage on to their payload.}
var
	it: Integer;
begin
	if Weapon^.S = GS_EMelee then begin
		it := ( Weapon^.V + 1 ) div 2;
	end else if Weapon^.S = GS_Missile then begin
		it := -1;
	end else begin
		it := Weapon^.V;
	end;

	{Return the value.}
	WeaponBaseDamage := it;
end;

Function WeaponBaseMass( Weapon: GearPtr ): Integer;
	{ Calculate the mass of this weapon. Most weapons weigh the same as }
	{ their damage class, but there are exceptions. High rate of fire }
	{ increases weapon weight. }
var
	it: Integer;
begin
	if Weapon^.S = GS_Missile then begin
		{ Missile launchers weigh just one unit. It's the missiles }
		{ themselves which are heavy. }
		it := 1;

	end else if Weapon^.S = GS_EMelee then begin
		{ Energy melee weapons weigh only one unit, for the emitter. }
		it := 1;

	end else begin
		{ Other weapons weight is equal to their damage class. }
		it := WeaponBaseDamage(Weapon);

		if ( Weapon^.S = GS_Ballistic ) then begin
			{ Ballistic weapons are made heavier by having a }
			{ burst value... more barrels to rotate. }
			it := it + Weapon^.Stat[ STAT_BurstValue ];
		end;
	end;
	WeaponBaseMass := it;
end;

Function AmmoBaseDamage( Ammo: GearPtr ): Integer;
	{Calculate the base damage of Ammo. For missiles, this}
	{actually takes some figuring. For regular ammunition,}
	{one direct hit will cause it to blow up.}
var
	it: Integer;
	NumShots: Integer;
begin
	NumShots := Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent );

	if Ammo^.S = GS_Missile then begin
		it := Ammo^.V * NumShots div 25;
		if it < 1 then it := 1;
	end else begin
		it := 1;
	end;

	{Return the value.}
	AmmoBaseDamage := it;
end;

Function AmmoBaseMass( Ammo: GearPtr ): Integer;
	{Calculate the weight of the ammunition.}
var
	it: Integer;
	NumShots: Integer;
begin
	NumShots := Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent );

	if ( Ammo^.S = GS_Missile ) or ( Ammo^.S = GS_Grenade ) then begin
		it := AmmoBaseDamage(Ammo);
	end else begin
		it := Ammo^.V * NumShots div 100;
	end;
	AmmoBaseMass := it;
end;


Function AmmoName( Ammo: GearPtr ): String;
	{Make up a default name for the ammunition being referred to.}
var
	it: String;
	NumShots: Integer;
begin
	{Fill in the size of the ammunition.}
	it := DCName( Ammo^.V , Ammo^.Scale );

	{Fill in the description of the ammo.}
	if Ammo^.S = GS_Missile then begin
		it := it + ' Missile';
	end else it := it + ' Round';

	{Pluralize if necessary.}
	NumShots := Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent );
	if NumShots > 1 then it := it + 's';

	it := it + ' x ' + BStr( NumShots );

	{Return the finished string.}
	AmmoName := it;
end;

Function NotGoodAmmo( Wep , Mag: GearPtr ): Boolean;
	{ Check to see if the ammunition contained in MAG is suitable }
	{ for use with weapon WEP. WEP absolutely must be a weapon of }
	{ type ballistic or missile; if MAG is not an ammunition gear, }
	{ this function will return FALSE. }
var
	NumShots: Integer;
begin
	{ Start with an error check. }
	if ( Wep = Nil ) or ( Mag = Nil ) then Exit( True );

	NumShots := Mag^.Stat[STAT_AmmoPresent] - NAttValue( Mag^.NA , NAG_WeaponModifier , NAS_AmmoSpent );

	{ Check compatability. }
	if ( Mag^.G <> GG_Ammo ) or ( Mag^.S <> Wep^.S ) or ( Mag^.V <> Wep^.V ) or ( Mag^.Scale <> Wep^.Scale ) then
		NotGoodAmmo := True

	{ Check ammunition remaining. }
	else if NumShots < 1 then
		NotGoodAmmo := True

	{ Everything is okay. This is good ammunition. }
	else
		NotGoodAmmo := False;
end;

Procedure CheckWeaponRange( Wpn: GearPtr );
	{ Check all of the values associated with this weapon to make }
	{ sure everything is nice and legal. }
begin
	{ Check S - Weapon Type }
	if Wpn^.S < 0 then Wpn^.S := 0
	else if Wpn^.S > 4 then Wpn^.S := 4;

	{ Check V - Weapon Size }
	if Wpn^.V < 1 then Wpn^.V := 1
	else if Wpn^.V > 25 then Wpn^.V := 25;

	{ Check Stats }
	{ Stat[1] = Range. }
	if ( Wpn^.S = GS_Ballistic ) or ( Wpn^.S = GS_Beamgun ) or ( Wpn^.S = GS_Missile ) then begin
		if Wpn^.Stat[1] < 1 then Wpn^.Stat[1] := 1
		else if Wpn^.Stat[1] > 50 then Wpn^.Stat[1] := 50;
	end else begin
		Wpn^.Stat[1] := 0;
	end;

	{ Stat[2] = Accuracy }
	if Wpn^.Stat[2] < -5 then Wpn^.Stat[2] := -5
	else if Wpn^.Stat[2] > 5 then Wpn^.Stat[2] := 5;

	{ Stat[3] = Recharge Period. Generally 2 shots per round. }
	if Wpn^.Stat[3] < 1 then Wpn^.Stat[3] := 1;

	{ Stat[4] = Burst Value }
	if ( Wpn^.S = GS_Ballistic ) or ( Wpn^.S = GS_Beamgun ) or ( Wpn^.S = GS_Missile ) then begin
		if Wpn^.Stat[4] < 0 then Wpn^.Stat[4] := 0
		else if Wpn^.Stat[4] > 10 then Wpn^.Stat[4] := 10;
	end else begin
		Wpn^.Stat[4] := 0;
	end;

	{ Stat[8] = Ammunition Capacity. Only for Ballistic and Missile.}
	if ( Wpn^.S = GS_Ballistic ) or ( Wpn^.S = GS_Missile ) then begin
		if Wpn^.Stat[8] < 1 then Wpn^.Stat[8] := 1;
	end else begin
		Wpn^.Stat[8] := 0;
	end;
end;

Procedure CheckWeaponAddOnRange( Wpn: GearPtr );
	{ Check all of the values associated with this weapon to make }
	{ sure everything is nice and legal. }
begin
	{ Check S - Mount Type }
	if Wpn^.S < 0 then Wpn^.S := 0
	else if Wpn^.S > 3 then Wpn^.S := 3;

	{ Check V - Damage Modifier }
	if Wpn^.V < 0 then Wpn^.V := 0
	else if Wpn^.V > 2 then Wpn^.V := 2;

	{ Check Stats }
	{ Stat[1] = Range. }
	if Wpn^.Stat[1] < 0 then Wpn^.Stat[1] := 0
	else if Wpn^.Stat[1] > 5 then Wpn^.Stat[1] := 5;

	{ Stat[2] = Accuracy }
	if Wpn^.Stat[2] < 0 then Wpn^.Stat[2] := 0
	else if Wpn^.Stat[2] > 3 then Wpn^.Stat[2] := 3;

	{ Stat[3] = Recharge Period. Generally 2 shots per round. }
	if Wpn^.Stat[3] < 0 then Wpn^.Stat[3] := 0
	else if Wpn^.Stat[3] > 3 then Wpn^.Stat[3] := 3;
end;

Function IsLegalWeaponInv( Slot , Equip: GearPtr ): Boolean;
	{ Return TRUE if Slot can have Equip as an InvCom. Weapons can only }
	{ have Weapon AddOns as inventory, and then only if they themselves }
	{ are inventory-held weapons. }
begin
	if ( Equip^.G = GG_WeaponAddOn ) and IsInvCom( Slot ) and ( Slot^.Scale = Equip^.Scale ) then begin
		{ Whether or not this Add-On can be equipped to this weapon will }
		{ depend upon its listed mounting type, which is the S descriptor. }
		case Equip^.S of
			GS_General_AO:	IsLegalWeaponInv := True;
			GS_Gun_AO:	IsLegalWeaponInv := ( Slot^.S = GS_Ballistic ) or ( Slot^.S = GS_BeamGun );
			GS_Heavy_AO:	IsLegalWeaponInv := Slot^.S = GS_Missile;
			GS_Melee_AO:	IsLegalWeaponInv := ( Slot^.S = GS_Melee ) or ( Slot^.S = GS_EMelee );
			else IsLegalWeaponInv := False;
		end;
	end else IsLegalWeaponInv := False;
end;

Function IsLegalWeaponSub( Wep, Equip: GearPtr ): Boolean;
	{ Return TRUE if the provided EQUIP can be installed in WEP, }
	{ FALSE if it can't be. }
begin
	if Equip^.G = GG_Weapon then begin
		IsLegalWeaponSub := PartHasIntrinsic( Equip , NAS_Integral );
	end else if ( Wep^.S = GS_Ballistic ) or ( Wep^.S = GS_Missile ) then begin
		if NotGoodAmmo( Wep, Equip ) then IsLegalWeaponSub := False
		else if Equip^.Stat[ STAT_AmmoPresent ] > Wep^.Stat[ STAT_Magazine ] then IsLegalWeaponSub := False
		else IsLegalWeaponSub := True;
	end else IsLegalWeaponSub := False;
end;

Procedure CheckAmmoRange( Ammo: GearPtr );
	{ Check all of the values associated with this ammo to make }
	{ sure everything is nice and legal. }
begin
	{ Check S - Weapon Type }
	if ( Ammo^.S <> GS_Ballistic ) and ( Ammo^.S <> GS_Missile ) and ( Ammo^.S <> GS_Grenade ) then begin
		Ammo^.S := GS_Ballistic;
	end;

	{ Check V - Weapon Size }
	if Ammo^.V < 1 then Ammo^.V := 1
	else if Ammo^.V > 25 then Ammo^.V := 25;

	{ Check Stats }
	if ( Ammo^.S = GS_Grenade ) then begin
		{ Stat[4] = Burst Value }
		if Ammo^.Stat[4] < 0 then Ammo^.Stat[4] := 0
		else if Ammo^.Stat[4] > 10 then Ammo^.Stat[4] := 10;

		{ Stat[5] = Skill }
		if Ammo^.Stat[5] < 1 then Ammo^.Stat[5] := 2
		else if Ammo^.Stat[5] > 5 then Ammo^.Stat[5] := 2;

	end else begin
		Ammo^.Stat[4] := 0;
	end;

	{ Stat[7] = Number of Shots. }
	if Ammo^.Stat[7] < 1 then Ammo^.Stat[7] := 1;
end;

Function AttackAttributeValue( Part: GearPtr ): LongInt;
	{ Returns the cost (in tenths of total) of the attack attributes }
	{ associated with this weapon. }
var
	N,T,R: LongInt;
	AList,AA: String;
begin
	{ Find the basic attack attributes string. }
	AList := SAttValue( Part^.SA , 'TYPE' );
	N := 10;

	{ Go through the string one word at a time looking for }
	{ relevant attributes. }
	while AList <> '' do begin
		AA := UpCase( ExtractWord( AList ) );

		{ If this can be found as an attack attribute, }
		{ add the listed cost. }
		for t := 1 to Num_Attack_Attributes do begin
			if AA = AA_Name[ T ] then begin
				N := ( N * AA_Cost[ T ] ) div 10;
			end;
		end;

		{ If this can be found as a status effect, add the }
		{ listed cost. }
		for t := 1 to Num_Status_FX do begin
			if AA = SX_Name[ T ] then begin
				N := ( N * SX_Cost[ T ] ) div 10;
			end;
		end;

		{ Add special modifiers for attack attributes which }
		{ require parameters. }
		if AA = AA_Name[ AA_BlastAttack ] then begin
			AA := AList;
			R := ExtractValue( AA );
			if R < 1 then R := 1
			else if R > Max_Blast_Rating then R := Max_Blast_Rating;
			N := ( N * BlastModCost[ R ] ) div 10;
		end;
	end;
	if N < 5 then N := 5;

	AttackAttributeValue := N;
end;

Function WeaponValue( Part: GearPtr ): LongInt;
	{ Decide how many standard points this weapon should cost. }
var
	it: LongInt;
	N,D: LongInt;	{ Numerator and Denominator }
	Procedure AddToTotal( DN,DD: Integer );
	begin
		N := N * DN;
		D := D * DD;
		if ( N > 100000 ) or ( D > 100000 ) then begin
			N := N div 100;
			D := D div 100;
		end;
	end;
begin
	{ The base cost of a weapon is 35x Damage Class, }
	{ unless it's an energy melee weapon in which case 125x Damage Class, }
	{ or a beam weapon in which case 75x Damage Class. }
	if Part^.S = GS_EMelee then begin
		it := Part^.V * 125;

		{ Personal scale beam weapons are far more expensive. }
		if Part^.Scale = 0 then it := it * 2;
	end else if Part^.S = GS_BeamGun then begin
		it := Part^.V * 75;

		{ Personal scale beam weapons are far more expensive. }
		if Part^.Scale = 0 then it := it * 3;
	end else it := Part^.V * 35;

	{ Set the numerator to 1 and the denominator to 1. }
	N := 1;
	D := 1;

	{ All the different modifiers that a weapon can have will have an }
	{ effect upon its cost. }

	{ STAT 1 - Range }
	{ At Range = 0, weapon is 2/5 cost. At Range = 3, weapon is full cost. }
	AddToTotal( ( 2 + Part^.Stat[ STAT_Range ] ) , 5 );

	{ STAT 2 - Accuracy }
	{ Acc 0 = No effect }
	if Part^.Stat[ STAT_Accuracy ] > 0 then begin
		{ High accuracy costs 20% per pip. }
		N := N * ( 5 + Part^.Stat[ STAT_Accuracy ] );
		D := D * 5;
	end else if Part^.Stat[ STAT_Accuracy ] < 0 then begin
		{ Lowered accuracy costs 10% per pip. }
		N := N * ( 10 + Part^.Stat[ STAT_Accuracy ] );
		D := D * 10;
	end;

	{ STAT 3 - Recharge Time }
	{ Each point of recharge time is 2/5 the weapon's cost, or }
	{ a little less than half. }
	AddToTotal( 1 + 2 * Part^.Stat[ STAT_Recharge ] , 5 );

	{ STAT 4 - Burst Value }
	{ Each point of burst value costs 3/4 the weapon's cost. }
	if ( Part^.S = GS_Ballistic ) or ( Part^.S = GS_BeamGun ) then begin
		AddToTotal( 4 + 3 * Part^.Stat[ STAT_BurstValue ] , 4 );

		{ If this part is a beam gun rather than a projectile weapon, }
		{ there's an extra 50% mark-up on burst firing weapons. }
		if Part^.S = GS_BeamGun then begin
			N := N * 3;
			D := D * 2;
		end;
	end;

	{ STAT 8 - Magazine Capacity }
	{ This only applies to ballistic and missile weapons. They might }
	{ get a points rebate if they have a low number of shots. }
	if ( Part^.S = GS_Ballistic ) then begin
		if Part^.Stat[ STAT_Magazine ] < 7 then begin
			{ -5% per shot + -20%. }
			N := N * ( 9 + Part^.Stat[ STAT_Magazine ] );
			D := D * 20;
		end else if Part^.Stat[ STAT_Magazine ] < 10 then begin
			{ -20% total. }
			N := N * 4;
			D := D * 5;
		end else if Part^.Stat[ STAT_Magazine ] < 20 then begin
			{ -10% total. }
			N := N * 9;
			D := D * 10;
		end;
	end else if ( Part^.S = GS_Missile ) then begin
		N := N * Part^.Stat[ STAT_Magazine ];
		D := D * 5;
	end;

	{ Add Attack Attributes. }
	AddToTotal( AttackAttributeValue( Part ) , 10 );

	{ Do the final cost calculation here. }
	WeaponValue := ( it * N ) div D;
end;

Function WeaponAddOnCost( Part: GearPtr ): LongInt;
	{ Decide how many standard points this weapon should cost. }
var
	it,AA: LongInt;
begin
	{ Base price is 120. }
	it := 120;

	{ General add-ons are more expensive. }
	if Part^.S = GS_General_AO then it := it * 3;

	{ All the different modifiers that a weapon can have will have an }
	{ effect upon its cost. }
	if Part^.V > 0 then it := it * Part^.V * 2;

	{ STAT 1 - Range }
	if Part^.Stat[ STAT_Range ] > 0 then it := ( it * ( Part^.Stat[ STAT_Range ] + 3 ) ) div 2;

	{ STAT 2 - Accuracy }
	if Part^.Stat[ STAT_Accuracy ] > 0 then it := ( it * ( Part^.Stat[ STAT_Accuracy ] + 3 ) ) div 2;

	{ STAT 3 - Recharge Time }
	if Part^.Stat[ STAT_Recharge ] > 0 then it := it * ( Part^.Stat[ STAT_Recharge ] + 1 );

	{ Add Attack Attributes. }
	AA := AttackAttributeValue( Part );
	if AA > 10 then it := it * AA div 5;

	{ Do the final cost calculation here. }
	WeaponAddOnCost := it;
end;

Function BaseAmmoValue( Part: GearPtr ): Int64;
	{ Return the value for this ammunition, ignoring for the moment any shots that }
	{ have already been spent. }
var
	AAV: LongInt;
	NumShots: LongInt;
	AA: String;
begin
	{ The base cost of a weapon is based on its Damage Class. }
	NumShots := Part^.Stat[STAT_AmmoPresent];

	{ Missiles are more expensive than bullets. }
	if Part^.S = GS_Missile then NumShots := NumShots * 10
	{ Grenades are also more expensive. }
	else if Part^.S = GS_Grenade then NumShots := NumShots * 2;

	{ STAT 4 - Burst Value }
	if Part^.S = GS_Grenade then begin
		NumShots := NumShots * ( Part^.Stat[ STAT_BurstValue ] + 1 );
	end;

	AAV := AttackAttributeValue( Part ) - 5;
	if AAV < 1 then AAV := 1
	else if AAV > 5 then AAV := AAV * 3;

	{ Extra cost for BLAST, HYPER ammo. }
	AA := SAttValue( Part^.SA , 'TYPE' );
	if AStringHasBString( AA , AA_NAME[ AA_BLASTATTACK ] ) then AAV := AAV * 2;
	if AStringHasBString( AA , AA_NAME[ AA_HYPER ] ) then AAV := AAV * 3;

	BaseAmmoValue := ( NumShots * Part^.V * AAV ) div 50;
end;

Function AmmoValue( Part: GearPtr ): LongInt;
	{ Decide how many standard points this weapon should cost. }
var
	NumShots: LongInt;
begin
	{ The base cost of a weapon is based on its Damage Class. }
	NumShots := Part^.Stat[STAT_AmmoPresent] - NAttValue( Part^.NA , NAG_WeaponModifier , NAS_AmmoSpent );

	AmmoValue := ( ( NumShots + 1 ) * BaseAmmoValue( Part ) ) div ( Part^.Stat[STAT_AmmoPresent] + 1 );
end;


Function WeaponComplexity( Part: GearPtr ): Integer;
	{ Calculate how much space inside a module or other holder this }
	{ weapon should take. }
var
	it: Integer;
begin
	if Part^.S = GS_Missile then begin
		{ The formula for Missiles is ( Dmg x Mag ) div 10 }
		it := Part^.V * Part^.Stat[ STAT_Magazine ] div 10;
	end else begin
		it := ( Part^.V div 3 ) + 1;
		if Part^.S = GS_BeamGun then it := it + 1;
	end;
	if it < 1 then it := 1;
	WeaponComplexity := it;
end;

Function WeaponArc( Weapon: GearPtr ): Integer;
	{ Determine what arc this weapon can attack in. }
var
	M: GearPtr;
begin
	if ( weapon = Nil ) or ( weapon^.Parent = Nil ) then WeaponArc := ARC_F90
	else if weapon^.G = GG_Module then begin
		if ( Weapon^.S = GS_Arm ) then WeaponArc := ARC_F180 
		else if ( Weapon^.S = GS_Tail ) then WeaponArc := ARC_360
		else WeaponArc := ARC_F90;

	end else if weapon^.G = GG_Ammo then begin
		{ Grenades can only be thrown in the front 90 arc. }
		WeaponArc := ARC_F90;

	end else begin
		M := Weapon^.Parent;
		while ( M <> Nil ) and ( M^.G <> GG_Module ) do M := M^.Parent;
		if ( M = Nil ) then WeaponArc := ARC_F90
		else if ( M^.S = GS_Arm ) or ( M^.S = GS_Head ) or ( M^.S = GS_Tail ) then WeaponArc := ARC_F180
		else if M^.S = GS_Turret then WeaponArc := ARC_360
		else WeaponArc := ARC_F90;

	end;
end;


Function WeaponName( Weapon: GearPtr ): String;
	{Supply a default name for this particular weapon.}
begin
	{Convert the size of the weapon to a string.}
	if Weapon^.G = GG_Weapon then begin
		WeaponName := DCName( Weapon^.V , Weapon^.Scale ) + ' ' + DefaultWeaponName[Weapon^.S];
	end else begin
		WeaponName := 'Other';
	end;
end;


Function CanDamageBeamShield( Weapon: GearPtr ): Boolean;
	{ Return TRUE if the listed weapon will do damage to a beam }
	{ shield, or FALSE otherwise. In general only beam weapons }
	{ can affect a beam shield. }
begin
	if Weapon^.V = GG_Weapon then begin
		{ If it's a beamgun or emelee, it will damage a beam shield. }
		CanDamageBeamShield := ( Weapon^.S = GS_BeamGun ) or ( Weapon^.S = GS_EMelee );
	end else begin
		{ If it's a module, it can't damage a beam shield. }
		CanDamageBeamShield := False;
	end;
end;

Function HasStatus( Mek: GearPtr; SFX: Integer ): Boolean;
	{ Return TRUE if the listed status effect is active in this }
	{ gear, or FALSE otherwise. }
begin
	if Mek = Nil then begin
		HasStatus := False;
	end else begin
		HasStatus := NAttValue( Mek^.NA , NAG_StatusEffect , SFX ) <> 0;
	end;
end;

end.
