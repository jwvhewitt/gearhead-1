unit gearutil;
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

uses gears,damage;

Function IsMasterGear(G: GearPtr): Boolean;
Procedure InitGear(Part: GearPtr);
Function MasterSize(Part: GearPtr): Integer;
function FindMaster( Part: GearPtr ): GearPtr;
function FindModule( Part: GearPtr ): GearPtr;

function ModifiersSkillBonus( Part: GearPtr; Skill: Integer ): Integer;
Function CharaSkillRank( PC: GearPtr; Skill: Integer ): Integer;

function InGoodModule( Part: GearPtr ): Boolean;

Function ScaleDP( DP , Scale , Material: Integer ): Integer;
Function UnscaledMaxDamage( Part: GearPtr ): Integer;
Function GearMaxDamage(Part: GearPtr): Integer;
Function GearMaxArmor(Part: GearPtr): Integer;
Function GenericName( Part: GearPtr ): String;
Function GearName(Part: GearPtr): String;
Function FullGearName(Part: GearPtr): String;

Function GearMass( Master: GearPtr ): LongInt;
Function IntrinsicMass( Master: GearPtr ): LongInt;
Function EquipmentMass( Master: GearPtr ): LongInt;

Function MakeMassString( BaseMass: LongInt; Scale: Integer ): String;
Function MassString( Master: GearPtr ): String;
Function GearDepth( Part: GearPtr ): Integer;

Function ComponentComplexity( Part: GearPtr ): Integer;
Function SubComComplexity( Part: GearPtr ): Integer;

Function IsLegalSlot( Slot, Equip: GearPtr ): Boolean;
Function IsLegalSubcom( Part, Equip: GearPtr ): Boolean;
Function CanBeInstalled( Part , Equip: GearPtr ): Boolean;

Procedure CheckGearRange( Part: GearPtr );
Function EquipGear( Slot , Part: GearPtr ): GearPtr;

Function SeekGear( Master: GearPtr; G,S: Integer; CheckInv: Boolean ): GearPtr;
Function SeekGear( Master: GearPtr; G,S: Integer ): GearPtr;
Function SeekCurrentLevelGear( Master: GearPtr; G,S: Integer ): GearPtr;

Function GearEncumberance( Mek: GearPtr ): Integer;

Function IntrinsicMVTVMod( Mek: GearPtr ): Integer;
Function EquipmentMVTVMod( Mek: GearPtr ): Integer;
Function BaseMVTVScore( Mek: GearPtr ): Integer;

Function BaseGearValue( Master: GearPtr ): Int64;
Function GearValue( Master: GearPtr ): LongInt;

function SeekGearByName( LList: GearPtr; Name: String ): GearPtr;
function SeekGearByDesig( LList: GearPtr; Name: String ): GearPtr;
function SeekGearByIDTag( LList: GearPtr; G,S,V: LongInt ): GearPtr;
function SeekGearByG( LList: GearPtr; G: Integer ): GearPtr;
function SeekSubsByG( LList: GearPtr; G: Integer ): GearPtr;
function MaxIDTag( LList: GearPtr; G,S: Integer ): LongInt;

function CStat( PC: GearPtr; Stat: Integer ): Integer;

Procedure WriteCGears( var F: Text; G: GearPtr );
Function ReadCGears( var F: Text ): GearPtr;

Function IsExternalPart( Master,Part: GearPtr ): Boolean;

implementation

uses ghchars,ghcpit,ghguard,ghholder,ghmecha,ghmodule,ghmovers,
     ghintrinsic,ghprop,ghsensor,ghsupport,
     ghswag,ghweapon,texutil;

Const
	SaveFileContinue = 0;
	SaveFileSentinel = -1;
	GMMODE_AddAll = 0;
	GMMODE_Intrinsic = 1;
	GMMODE_Equipment = 2;
	Storage_Armor_Bonus = 2;

Function IsMasterGear(G: GearPtr): Boolean;
	{This function checks gear G to see whether or not it counst}
	{as a Master Gear. Currently the only gears which count}
	{as masters are Mecha and Characters.}
var
	it: Boolean;
begin
	if G <> Nil then begin
		if (G^.G = GG_Mecha) or (G^.G = GG_Character) or (G^.G = GG_Prop) then it := true
		else it := false;
	end else it := False;
	IsMasterGear := it;
end;

Procedure InitGear(Part: GearPtr);
	{ Part has just been created. G, S, and V have been defined but }
	{ nothing else. Initialize its fields to the default values.}
var
	T: Integer;
begin
	{Error check- make sure we haven't just been sent a Nil.}
	if Part = Nil then exit;

	{ Clear all stats, to prevent nasty errors. }
	for t := 1 to NumGearStats do Part^.Stat[ T ] := 0;

	{For gears which are not master gears, take the scale}
	{from its parent.}
	if not IsMasterGear(Part) then begin
		if Part^.Parent <> NIl then begin
			Part^.Scale := Part^.Parent^.Scale;

			{ In addition, sub-components inherit material from }
			{ their parents. }
			if IsSubCom( Part ) then begin
				SetNAtt( Part^.NA , NAG_GearOps , NAS_Material , NAttValue( Part^.Parent^.NA , NAG_GearOps , NAS_Material ) );
			end;
		end;
	end;

	{Do the type-specific initialization routines here.}
	case Part^.G of
		GG_Mecha: InitMecha(Part);
		GG_Character: InitChar(Part);
		GG_Weapon: InitWeapon(Part);
		GG_Ammo: InitAmmo(Part);
		GG_Module: InitModule(Part);
		GG_MetaTerrain: InitMetaTerrain(Part);
	end;
end;

Function MasterSize(Part: GearPtr): Integer;
	{Determine the size of the Master for the current gear.}
	{If the Master is a mecha, this will be its Value field.}
	{If its a Character, this will be its Body stat.}
	{If no Master can be found, return Nil.}
var
	it: Integer;
begin
	while (Part <> Nil) and not IsMasterGear(Part) do begin
		Part := Part^.Parent;
	end;

	if Part = Nil then it := 0
	else if Part^.G = GG_Mecha then it := Part^.V
	else if Part^.G = GG_Character then begin
		{ The main purpose of this for character gears is to }
		{ determine the size of the character's limbs. }
		it := ( Part^.Stat[ STAT_Body ] + 2 ) div 3;
		if it < 1 then it := 1
		else if it > 10 then it := 10;
	end;

	MasterSize := it;
end;

function FindMaster( Part: GearPtr ): GearPtr;
	{ Locate the master of PART. Return NIL if there is no master. }
begin
	{ Move the pointer up to either root level or the first Master parent. }
	while ( Part <> Nil ) and ( not IsMasterGear(Part) ) do Part := Part^.Parent;

	FindMaster := Part;
end;

function FindModule( Part: GearPtr ): GearPtr;
	{ Locate the module of PART. Return NIL if there is no master. }
begin
	{ Move the pointer up to either root level or the first Master parent. }
	while ( Part <> Nil ) and ( Part^.G <> GG_Module ) do Part := Part^.Parent;

	FindModule := Part;
end;

function ModifiersSkillBonus( Part: GearPtr; Skill: Integer ): Integer;
	{ Determine the total skill bonus gained from MODIFIER }
	{ gears installed in PART. }
var
	MD: GearPtr;	{ Modifier gears. }
	it: Integer;
begin
	MD := Part^.SubCom;
	it := 0;
	while MD <> Nil do begin
		if ( MD^.G = GG_Modifier ) and ( MD^.S = GS_SkillModifier ) then begin
			if ( MD^.Stat[ STAT_SkillToModify ] = Skill ) and ( MD^.Stat[ STAT_SkillModBonus ] > it ) then it := MD^.Stat[ STAT_SkillModBonus ];
		end;
		MD := MD^.Next;
	end;
	ModifiersSkillBonus := it;
end;

Function CharaSkillRank( PC: GearPtr; Skill: Integer ): Integer;
	{ Return the PC's rank in this skill. }
	{ Note that PC _MUST_ be the actual PC!!! This does not work on }
	{ mecha, or props, or anything else!!! }
	{ Also note that this function does not check the presence of tools. }
var
	it: Integer;
begin
	if PC <> Nil then begin
		it := NAttValue( PC^.NA , NAG_Skill , Skill ) + ModifiersSkillBonus( PC , Skill );

		{ Normally to check for a talent we'd use the HAStALENT function, }
		{ but since that isn't available here and we know we're dealing with }
		{ the PC and also because you can't be granted talents from items or }
		{ mecha, I'll just check the NAtt to see if it's present. }
		if ( it = 0 ) and ( NAttValue( PC^.NA , NAG_Talent , NAS_JackOfAll ) <> 0 ) then it := 1;

		CharaSkillRank := it;
	end else begin
		CharaSkillRank := 0;
	end;
end;


function InGoodModule( Part: GearPtr ): Boolean;
	{ Check PART to make sure that it is mounted in a good module. }
var
	Ms,Md: GearPtr;		{ Master and Module }
begin
	Ms := FindMaster( Part );
	Md := FindModule( Part );

	{ If no master can be found, this function returns FALSE. }
	if ( Ms = Nil ) then Exit( False );

	if Ms^.G = GG_Mecha then begin
		if Md = Nil then begin
			{ This gear must be located in the general }
			{ inventory, since it isn't in a module. Items }
			{ in the general inventory can't be used until }
			{ equipped. }
			InGoodModule := False;
		end else begin
			{ With both the master and the module, look up }
			{ this combo in the Form X Module array. }
			InGoodModule := FormXModule[ Ms^.S , Md^.S ] and IsSubCom( Md );
		end;

	end else begin
		{ For characters and whatever else, every module is a }
		{ good module. If there's no module, i.e. the item is in }
		{ the general inventory, that's not good. }
		InGoodModule := ( Md <> Nil ) and IsSubCom( Md );
	end;
end;


Function ScaleDP( DP , Scale , Material: Integer ): Integer;
	{ Modify the damage point score DP for scale and construction. }
var
	T: Integer;
begin
	if DP > 0 then begin
		if Scale < 1 then begin
			if Material = NAV_Meat then DP := DP * 2
			else DP := DP * 3;
		end else begin
			if Material = NAV_Meat then DP := DP * 4
			else if Material = NAV_BioTech then DP := DP * 6
			else if Material = NAV_Metal then DP := DP * 5;

			if Scale > 1 then begin
				for t := 2 to Scale do DP := DP * 5;
			end;
		end;
	end;
	ScaleDP := DP;
end;

Function UnscaledMaxDamage( Part: GearPtr ): Integer;
	{ Return the maxdamage rating of this part, unadjusted for }
	{ scale or construction. }
var
	it: Integer;
begin
	case Part^.G of
		GG_Module:	it := ModuleBaseDamage(Part);
		GG_Mecha:	it := -1;
		GG_Character:	it := CharBaseDamage(Part , CStat( Part , STAT_Body ) );
		GG_Cockpit:	it := -1;
		GG_Weapon:	it := WeaponBaseDamage(Part);
		GG_Ammo:	it := AmmoBaseDamage(Part);
		GG_MoveSys:	it := MovesysBaseDamage(Part);
		GG_Holder:	it := 1;
		GG_Sensor:	it := SensorBaseDamage( Part );
		GG_Support:	it := SupportBaseDamage( Part );
		GG_Shield:	it := -1;
		GG_ExArmor:	it := -1;
		GG_Swag:	it := 1;
		GG_Prop:	it := Part^.V;
		GG_MetaTerrain:	it := Part^.V;
		GG_Electronics:	it := ElecBaseDamage( Part );
		GG_Usable:	it := UsableDamage( Part );
		GG_RepairFuel:	it := 0;
		GG_Consumable:	it := 0;
		GG_Modifier:	it := 0;
		GG_WeaponAddOn:	it := 1;
	else it := -1;
	end;

	UnscaledMaxDamage := it;
end;

Function GearMaxDamage(Part: GearPtr): Integer;
	{Calculate how much damage this particular part can take}
	{before being destroyed.}
var
	it: Integer;
begin
	{ Start with the unscaled mass damage. }
	it := UnscaledMaxDamage( Part );

	{Modify damage for scale and construction.}
	it := ScaleDP( it , PART^.Scale , NAttValue( Part^.NA , NAG_GearOps , NAS_Material ) );

	GearMaxDamage := it;
end;

Function GearMaxArmor(Part: GearPtr): Integer;
	{Calculate how much armor protection PART has. This should}
	{include both intrinsic armor and equipped armor.}
var
	M: GearPtr;
	it: Integer;
begin
	{Error Check}
	if Part = Nil then Exit(0);

	{Modules and Cockpits have armor ratings.}
	if Part^.G = GG_Module then begin
		it := Part^.Stat[STAT_Armor];
		if Part^.S = GS_Storage then it := it + Storage_Armor_Bonus;
	end else if ( Part^.G = GG_Cockpit ) or ( Part^.G = GG_Support ) then it := Part^.Stat[STAT_Armor]
	else if ( Part^.G = GG_Shield ) then it := Part^.V * 2
	else if ( Part^.G = GG_ExArmor ) then it := Part^.V
	else if ( Part^.G = GG_MetaTerrain ) then it := Part^.V
	else it := 0;

	{ If this is an armored part, perform additional checks now. }
	if it > 0 then begin
		{ Modify armor for a GroundHugger or Arachnoid }
		M := FindMaster( Part );
		if ( M <> Nil ) and ( M^.G = GG_Mecha ) then begin
			if  M^.S = GS_GroundHugger then it := it + 2
			else if  M^.S = GS_Arachnoid then it := it + 1;
		end;

		{Modify it for scale.}
		it := ScaleDP( it , Part^.Scale , NAV_Metal );
	end;

	GearMaxArmor := it;
end;

Function GenericName( Part: GearPtr ): String;
    { Return a generic name for this part. }
begin
    case Part^.G of
		GG_Module:	GenericName := ModuleName(Part);
		GG_Mecha:	GenericName := MechaName(Part);
		GG_Character:	GenericName := 'Character';
		GG_Cockpit:	GenericName := 'Cockpit';
		GG_Weapon:	GenericName := WeaponName(Part);
		GG_Ammo:	GenericName := AmmoName(Part);
		GG_MoveSys:	GenericName := MoveSysName(Part);
		GG_Holder:	GenericName := HolderName( Part );
		GG_Sensor:	GenericName := SensorName( Part );
		GG_Support:	GenericName := SupportName( Part );
		GG_Shield:	GenericName := ShieldName( Part );
		GG_ExArmor:	GenericName := ArmorName( Part );
		GG_Scene:	GenericName := 'Scene ' + BStr( Part^.S );
		GG_Swag:	GenericName := SwagName( Part );
		GG_Prop:	GenericName := 'Prop';
		GG_MetaTerrain:	GenericName := 'Scenery';
		GG_Electronics:	GenericName := ElecName( Part );
		GG_Usable:	GenericName := UsableName( Part );
		GG_RepairFuel:	GenericName := RepairFuelName( Part );
		GG_Consumable:	GenericName := 'Food';
		GG_WeaponAddOn:	GenericName := 'Weapon Accessory';
		else GenericName := 'Platonic Form';
	end;
end;

Function GearName(Part: GearPtr): String;
	{Determine the name of Part. If Part has a NAME attribute,}
	{this is easy. If not, locate a default name based upon}
	{Part's type.}
var
	it: String;
begin
	{Error check- make sure we aren't trying to find a name}
	{for nothing.}
	if Part = Nil then Exit( '' );

	it := SAttValue(Part^.SA,'NAME');

	if it = '' then it := GenericName( Part );

    if Part^.g = GG_AbsolutelyNothing then it := '~!' + it;

	GearName := it;
end;

Function FullGearName(Part: GearPtr): String;
	{ Return the name + designation for this gear. }
var
	it: String;
begin
	it := SAttValue( Part^.SA , 'DESIG' );
	if it <> '' then it := it + ' ';
	FullGearName := it + GearName( Part );
end;

Function ComponentMass( Part: GearPtr ): LongInt;
	{Calculate the unscaled mas of PART, ignoring for the}
	{moment its subcomponents.}
const
	Mass_MAX = 2147483647;
	Mass_MIN = -2147483648;
var
	it,MAV: Int64;
begin
	Case Part^.G of
		GG_Module:	it := ModuleBaseMass(Part);
		GG_Cockpit:	it := CockpitBaseMass(Part);
		GG_Weapon:	it := WeaponBaseMass(Part);
		GG_Ammo:	it := AmmoBaseMass(Part);
		GG_MoveSys:	it := MovesysBaseMass(Part);
		GG_Holder:	it := 1;
		GG_Sensor:	it := SensorBaseMass( Part );
		GG_Support:	it := SupportBaseMass( Part );
		GG_Shield:	it := ShieldBaseMass( Part );
		GG_ExArmor:	it := ArmorBaseMass( Part );
		GG_Swag:	it := SwagBaseMass( Part );
		GG_Prop:	it := Part^.V;
		GG_MetaTerrain:	it := Part^.V;
		GG_Electronics:	it := ElecBaseMass( Part );
		GG_Usable:	it := UsableDamage( Part );
		GG_Consumable:	it := FoodMass( Part );
		GG_WeaponAddOn:	it := 1;

	{If a component type is not listed above, it has no mass.}
	else it := 0
	end;

	{ Reduce component mass by mass adjustment value. }
	MAV := NAttValue( Part^.NA , NAG_GearOps , NAS_MassAdjust );
	it := it + MAV;
	{ Mass adjustment can't result in a negative mass. }
	if it < 0 then it := 0;

	if it < Mass_MIN then begin
		it := Mass_MIN;
	end else if Mass_MAX < it then begin
		it := Mass_MAX;
	end;

	ComponentMass := it;
end;

Function TrackMass( Part: GearPtr; Scale: Integer; Mode: Byte; AddThis: Boolean ): LongInt;
	{Calculate the mass of this list of gears, including all}
	{subcomponents.}
const
	Mass_MAX = 2147483647;
	Mass_MIN = -2147483648;
var
	it,W: Int64;
	t: Integer;
begin
	{Initialize the total Mass to 0.}
	it := 0;

	{Loop through all components.}
	while Part <> Nil do begin
		{We will only add the mass of components which are}
		{in the same scale as the master gear.}
		if Part^.Scale >= Scale then begin
			W := ComponentMass(Part);

			{Increase mass for overscale gears.}
			if Part^.Scale > Scale then begin
				for t := 1 to Part^.Scale - Scale do W := W * 5;
			end;

			{Add the mass to the total.}
			if AddThis then it := it + W;
		end;

		{Check for subcomponents and invcomponents.}
		if Mode = GMMODE_AddAll then begin
			if Part^.SubCom <> Nil then it := it + TrackMass(Part^.SubCom,Scale,Mode,True);
			if Part^.InvCom <> Nil then it := it + TrackMass(Part^.InvCom,Scale,Mode,True);
		end else if Mode = GMMODE_Intrinsic then begin
			{ Calculate only the mass of pure SubComs. }
			if Part^.SubCom <> Nil then it := it + TrackMass(Part^.SubCom,Scale,Mode,True);
		end else begin
			{ Calculate only the mass of InvComs. }
			if Part^.SubCom <> Nil then it := it + TrackMass(Part^.SubCom,Scale,Mode,AddThis);
			if Part^.InvCom <> Nil then it := it + TrackMass(Part^.InvCom,Scale,Mode,True);
		end;

		{Go to the next part in the series.}
		Part := Part^.Next;
	end;

	{Return the value.}
	if it < Mass_MIN then begin
		it := Mass_MIN;
	end else if Mass_MAX < it then begin
		it := Mass_MAX;
	end;
	TrackMass := it;
end;

Function GearMass( Master: GearPtr ): LongInt;
	{Calculate the mass of MASTER, including all of its}
	{subcomponents.}
const
	Mass_MAX = 2147483647;
	Mass_MIN = -2147483648;
var
	tmp: Int64;
begin
	{The formula to work out the total mass of this gear}
	{is basic mass + SubCom mass + InvCom mass.}
	if ( Master = Nil ) or ( Master^.G < 0 ) then begin
		GearMass := 0;
	end else begin
		tmp := ComponentMass(Master);
		tmp := tmp + TrackMass(Master^.SubCom,Master^.Scale,GMMODE_AddAll,True);
		tmp := tmp + TrackMass(Master^.InvCom,Master^.Scale,GMMODE_AddAll,True);
		if tmp < Mass_MIN then begin
			tmp := Mass_MIN;
		end else if Mass_MAX < tmp then begin
			tmp := Mass_MAX;
		end;
		GearMass := tmp;
	end;
end;

Function IntrinsicMass( Master: GearPtr ): LongInt;
	{ Return the mass of MASTER and all its subcomponents. Do not }
	{ calculate the mass of inventory components. }
const
	Mass_MAX = 2147483647;
	Mass_MIN = -2147483648;
var
	tmp: Int64;
begin
	tmp := ComponentMass(Master);
	tmp := tmp + TrackMass(Master^.SubCom,Master^.Scale,GMMODE_Intrinsic,True);
	if tmp < Mass_MIN then begin
		tmp := Mass_MIN;
	end else if Mass_MAX < tmp then begin
		tmp := Mass_MAX;
	end;
	IntrinsicMass := tmp;
end;

Function EquipmentMass( Master: GearPtr ): LongInt;
	{ Return the mass of all inventory components of MASTER. Do not }
	{ include the mass of intrinsic components. }
const
	Mass_MAX = 2147483647;
	Mass_MIN = -2147483648;
var
	tmp: Int64;
begin
	tmp := TrackMass(Master^.SubCom,Master^.Scale,GMMODE_Equipment,False);
	tmp := tmp + TrackMass(Master^.InvCom,Master^.Scale,GMMODE_Equipment,True);
	if tmp < Mass_MIN then begin
		tmp := Mass_MIN;
	end else if Mass_MAX < tmp then begin
		tmp := Mass_MAX;
	end;
	EquipmentMass := tmp;
end;

Function MakeMassString( BaseMass: LongInt; Scale: Integer ): String;
	{ Given a mass value and a scale, create a string to express }
	{ said mass to the player. }
var
	msg: String;
	T: Integer;
begin
	if Scale >= 2 then begin
		for t := 3 to Scale do BaseMass := BaseMass * 5;
		msg := BStr( BaseMass div 2 ) + '.' + BStr( ( BaseMass mod 2 ) * 5 ) + 't';
	end else if Scale = 1 then begin
		msg := BStr( BaseMass div 10 ) + '.' + BStr( BaseMass mod 10 ) + 't';
	end else if Scale = 0 then begin
		msg := BStr( BaseMass div 2 ) + '.' + BStr( ( BaseMass mod 2 ) * 5 ) + 'kg';
	end else begin
		msg := BStr( BaseMass ) + '!';
	end;
	MakeMassString := Msg;
end;

Function MassString( Master: GearPtr ): String;
	{ Return a string describing how heavy this gear is, based upon its }
	{ scale. }
var
	BaseMass: LongInt;
begin
	BaseMass := GearMass( Master );
	MassString := MakeMassString( BaseMass , Master^.Scale );
end;

Function GearDepth( Part: GearPtr ): Integer;
	{ Calculate the depth of PART. If PART is a root level component, }
	{ depth is 0. }
var
	D: Integer;
begin
	{ Initialize D. }
	D := 0;

	{ Ascend up the structure to the root level. For each level }
	{ we have to go up, increase D by one. }
	while Part^.Parent <> Nil do begin
		Part := Part^.Parent;
		Inc( D );
	end;

	GearDepth := D;
end;

Function ComponentComplexity( Part: GearPtr ): Integer;
	{ Return the basic complexity value of this part, and only }
	{ this part. }
begin
	if ( Part = Nil ) or ( Part^.G < 0 ) then begin
		ComponentComplexity := 0;
	end else begin
		case Part^.G of
			GG_Module: ComponentComplexity := ModuleComplexity( Part );
			GG_Weapon: ComponentComplexity := WeaponComplexity( Part );
			GG_MoveSys: ComponentComplexity := Part^.V;
		else ComponentComplexity := 1;
		end;

		{ If the part is integral, and not a module, reduce complexity by 1 }
		{ down to a minimum value of 1. }
		if ( ComponentComplexity > 1 ) and ( Part^.G <> GG_Module ) and PartHasIntrinsic( Part , NAS_Integral ) then Dec( ComponentComplexity );
	end;
end;

Function SubComComplexity( Part: GearPtr ): Integer;
	{ Return the overall complexity of all of PART's subcomponents. }
var
	it: Integer;
	S: GearPtr;
begin
	it := 0;
	S := Part^.SubCom;
	while S <> Nil do begin
		if S^.Scale >= Part^.Scale then begin
			it := it + ComponentComplexity( S );
		end else begin
			Inc( it );
		end;
		S := S^.Next;
	end;
	SubComComplexity := it;
end;


Function IsLegalSlot( Slot, Equip: GearPtr ): Boolean;
	{ Check EQUIP to see if it can be installed as a sub-component }
	{ of SLOT. Return TRUE if it can, FALSE if it can't. }
	{ This procedure only checks to make sure the slot is legal; }
	{ it doesn't check whether the slot is already occupied or }
	{ anything else. }
begin
	if ( Slot = Nil ) or ( Equip = Nil ) then begin
		{ If either of the provided gears don't really exist, }
		{ this can't very well be a legal installation, can it? }
		IsLegalSlot := False;

	end else if Slot^.G < 0 then begin
		{ Virtal slots can hold anything. }
		IsLegalSlot := True;

	end else if IsMasterGear( Slot ) or ( Slot^.G = GG_MetaTerrain ) then begin
		{ The inventory components of MASTER gears can hold just }
		{ about anything, since they represent the "general }
		{ inventory" from most RPGs. The only restrictions have }
		{ to do with scale and weight. }
		if Equip^.Scale > Slot^.Scale then IsLegalSlot := False
		else if Equip^.G = GG_MetaTerrain then IsLegalSlot := False
		else IsLegalSlot := True;

	end else if AStringHasBString( SAttValue( Equip^.SA , 'TYPE' ) , 'CYBER' ) then begin
		{ Gears marked as "cyber" can only be internally mounted. }
		IsLegalSlot := False;

	end else if Slot^.G = GG_Holder then begin
		{ Call the ghholder unit InvChecker to see what it says. }
		IsLegalSlot := IsLegalHolderInv( Slot , Equip );

	end else if ( Slot^.G = GG_Weapon ) then begin
		IsLegalSlot := IsLegalWeaponInv( Slot , Equip );

	end else if Slot^.G = GG_Module then begin
		{ Call the ghmodule unit InvChecker to see what it says. }
		if Equip^.G = GG_ExArmor then begin
			IsLegalSlot := IsLegalModuleInv( Slot , Equip ) and ArmorFItsMaster( Equip , FindMaster( Slot ) );
		end else begin
			IsLegalSlot := IsLegalModuleInv( Slot , Equip );
		end;

	end else begin
		{ No other slots may hold equipment. }
		IsLegalSlot := False;
	end;
end;

Procedure CheckGearInv( Part: GearPtr );
	{ Check through a gear's Inv components, and delete any illegal }
	{ gears found. A gear is legal if it meets two requirements- }
	{ it must be legal according to the IsLegalSlot procedure above, }
	{ and it must be the only gear with a given G value installed at }
	{ this location. }
var
	LG,LG2: GearPtr;	{ Loop Gear }
	MG: GearPtr;		{ Multiplicity Gear }
	N: Integer;		{ A number. That's all. }
begin
	LG := Part^.InvCom;
	while LG <> Nil do begin
		{ We need to save the location of the next gear, }
		{ since LG itself might get deleted. }
		LG2 := LG^.Next;

		if not IsLegalSlot( Part , LG ) then begin
			{ LG failed the legality check. Delete it. }
			RemoveGear( Part^.InvCom , LG );
		end else if ( Part^.G <> GG_MetaTerrain ) and not IsMasterGear( Part ) then begin
			{ Perform the multiplicity test. }
			N := 0;
			MG := Part^.InvCom;
			while MG <> Nil do begin
				if MG^.G = LG^.G then Inc( N );
				MG := MG^.Next;
			end;
			{ There's more than one gear here. Get rid of it. }
			if N > 1 then RemoveGear( Part^.InvCom , LG );
		end;

		LG := LG2;
	end;
end;

Function IsLegalSubcom( Part, Equip: GearPtr ): Boolean;
	{ Check EQUIP and see if it can be a legal subcomponent of PART. }
	{ The first rule is that EQUIP must be of a scale less than or }
	{ equal to PART; the second rule is that it must meet whatever }
	{ conditions are set by PART's type. }
	{ Note that this procedure only checks the legality of installation; }
	{ it does not do a multiplicity test or anything else. }
begin
	if ( Part = Nil ) or ( Equip = Nil ) then begin
		{ If either of the provided gears don't really exist, }
		{ this can't very well be a legal installation, can it? }
		IsLegalSubcom := False;

	end else if Part^.G < 0 then begin
		{ Virtal slots can hold anything. }
		IsLegalSubcom := True;

	end else if Equip^.Scale > Part^.Scale then begin
		{ Can't mount a gear of larger scale than the part. }
		IsLegalSubcom := False;

	end else begin
		case Part^.G of
		GG_Mecha:	IsLegalSubcom := IsLegalMechaSubCom( Part, Equip );
		GG_Module:	IsLegalSubCom := IsLegalModuleSub( Part, Equip );
		GG_Character:	IsLegalSubCom := IsLegalCharSub( Part , Equip );
		GG_Cockpit:	IsLegalSubCom := IsLegalCPitSub( Part , Equip );
		GG_Shield:	IsLegalSubCom := IsLegalShieldSub( Part , Equip );
		GG_ExArmor:	IsLegalSubCom := IsLegalArmorSub( Part , Equip );
		GG_Weapon:	IsLegalSubCom := IsLegalWeaponSub( Part , Equip );
		GG_Prop:	IsLegalSubCom := True;
		GG_MetaTerrain:	IsLegalSubCom := True;
		GG_WeaponAddOn:	IsLegalSubCom := Equip^.G = GG_Weapon;

		else IsLegalSubcom := False
		end;
	end;
end;

Function MaximumInstancesAllowed( Slot: GearPtr; Equip_G,Equip_S: Integer ): Integer;
	{ Return the maximum number of (G,S) gears that can be }
	{ installed in SLOT, or 0 if as many as wanted can be installed. }
	{ Note that the results of this function are undefined if the }
	{ part cannot be legally installed in the slot in the first place. }
begin
	if Equip_G = GG_MoveSys then begin
		MaximumInstancesAllowed := 1;
	end else if Equip_G = GG_Support then begin
		MaximumInstancesAllowed := 1;
	end else if ( Equip_G = GG_Module ) and ( Equip_S = GS_Body ) then begin
		MaximumInstancesAllowed := 1;
	end else if Equip_G = GG_Ammo then begin
		MaximumInstancesAllowed := 1;
	end else if Equip_G = GG_Holder then begin
		if ( Slot^.G = GG_Module ) and ( Slot^.S = GS_Body ) then begin
			{ Body modules may have up to two mounting points. }
			MaximumInstancesAllowed := 2;
		end else begin
			{ All other locations may have only one holder of each type. }
			MaximumInstancesAllowed := 1;
		end;
	end else begin
		MaximumInstancesAllowed := 0;
	end;
end;

Function NumberOfMatches( Parent,Exclude: GearPtr; G,S: Integer ): Integer;
	{ Count up the number of gears present which match }
	{ the descriptors G, S. }
	{ Don't count part EXCLUDE. }
var
	N: Integer;
	PSC: GearPtr;	{ Part SubCom }
begin
	N := 0;
	PSC := Parent^.SubCom;
	while PSC <> Nil do begin
		if ( PSC^.G = G ) and ( PSC^.S = S ) and ( PSC <> Exclude ) then Inc( N );
		PSC := PSC^.Next;
	end;
	NumberOfMatches := N;
end;

Function MultiplicityCheck( Slot, Item: GearPtr ): Boolean;
	{ Certain gears may only be installed a set number of times. }
	{ For instance, an arm may only have one hand, etc... This }
	{ function centralizes the multiplicity check. Return TRUE if }
	{ ITEM can be installed in SLOT, or FALSE otherwise. }
var
	it: Boolean;
	N: Integer;
	CyberSlot: String;
	Function CyberMatches: Integer;
		{ Return the number of subcoms of SLOT which bear the same }
		{ cyberslot as ITEM, excluding ITEM itself. }
	var
		N: Integer;
		PSC: GearPtr;	{ Part SubCom }
	begin
		N := 0;
		PSC := Slot^.SubCom;
		CyberSlot := UpCase( CyberSlot );
		while PSC <> Nil do begin
			if ( UpCase( SAttValue( PSC^.SA , SATT_CyberSlot ) ) = CyberSlot ) and ( PSC <> Item ) then Inc( N );
			PSC := PSC^.Next;
		end;
		CyberMatches := N;
	end;
begin
	{ Start by assuming TRUE. }
	it := True;

	{ Check the MaximumInstancesAllowed. }
	N := MaximumInstancesAllowed( Slot , Item^.G , Item^.S );
	if N > 0 then begin
		it := ( NumberOfMatches( Slot , Item , Item^.G , Item^.S ) < N );
	end;

	{ Check Cyberslot. }
	if it then begin
		CyberSlot := SAttValue( Item^.SA , SATT_CyberSlot );
		if CyberSlot <> '' then begin
			it := CyberMatches = 0;
		end;
	end;

	{ Return the result. }
	MultiplicityCheck := it;
end;

Procedure CheckGearSubs( Part: GearPtr );
	{ Examine the subcomponents of this gear to make sure everything }
	{ is nice and legal. }
	{ First do a legality check for each subcom, then do a }
	{ multiplicity test if the subcom is a type which requires that. }
var
	LG,LG2: GearPtr;	{ Loop Gear }
begin
	LG := Part^.SubCom;
	while LG <> Nil do begin
		{ We need to save the location of the next gear, }
		{ since LG itself might get deleted. }
		LG2 := LG^.Next;

		if not IsLegalSubCom( Part , LG ) then begin
			{ LG failed the legality check. Delete it. }
			RemoveGear( Part^.SubCom , LG );
		end else begin

			{ *** MULTIPLICITY CHECK *** }
			if not MultiplicityCheck( Part , LG ) then begin
				RemoveGear( Part^.SubCom , LG );
			end;
		end;

		LG := LG2;
	end;
end;

Function CanBeInstalled( Part , Equip: GearPtr ): Boolean;
	{ Return TRUE if the part can be equipped, or FALSE }
	{ otherwise. }
var
	it: Boolean;
begin
	it := IsLegalSubCom( Part , Equip );

	if it then begin
		it := MultiplicityCheck( Part , Equip );

		if it and ( Equip^.G = GG_Module ) and ( Part^.G = GG_Mecha ) then begin
			it := FormXModule[ Part^.S , Equip^.S ];
		end;
	end;
	CanBeInstalled := it;
end;

Procedure CheckGearRange( Part: GearPtr );
	{ Check the G , S , V , Stat , SubCom , and InvCom values of }
	{ this gear to make sure everything is all nice and legal. }
begin
	if Part^.G = GG_Mecha then CheckMechaRange( Part )
	else if Part^.G = GG_Module then CheckModuleRange( Part )
	else if Part^.G = GG_Cockpit then CheckCPitRange( Part )
	else if Part^.G = GG_Weapon then CheckWeaponRange( Part )
	else if Part^.G = GG_Ammo then CheckAmmoRange( Part )
	else if Part^.G = GG_Holder then CheckHolderRange( Part )
	else if Part^.G = GG_MoveSys then CheckMoverRange( Part )
	else if Part^.G = GG_Sensor then CheckSensorRange( Part )
	else if Part^.G = GG_Electronics then CheckElecRange( Part )
	else if Part^.G = GG_Support then CheckSupportRange( Part )
	else if Part^.G = GG_Shield then CheckShieldRange( Part )
	else if Part^.G = GG_ExArmor then CheckArmorRange( Part )
	else if Part^.G = GG_Swag then CheckSwagRange( Part )
	else if Part^.G = GG_Prop then CheckPropRange( Part )
	else if Part^.G = GG_Usable then CheckUsableRange( Part )
	else if Part^.G = GG_RepairFuel then CheckRepairFuelRange( Part )
	else if Part^.G = GG_Consumable then CheckFoodRange( Part )
	else if Part^.G = GG_Modifier then CheckModifierRange( Part )
	else if Part^.G = GG_WeaponAddOn then CheckWeaponAddOnRange( Part );

	{ Next, check the children of this gear to make sure everything }
	{ there is all nice and legal. }
	{ Note that the children of the gear don't have to be checked }
	{ if this gear is one of the virtual types; see gears.pp for }
	{ more information about that. }
	if Part^.G >= 0 then begin
		CheckGearInv( Part );
		CheckGearSubs( Part );
	end;
end;

Function EquipGear( Slot , Part: GearPtr ): GearPtr;
	{ This procedure will attempt to place PART as an inventory }
	{ component of SLOT. It will return a gear to place in the }
	{ general inventory, which should usually be either the previously }
	{ equipped item or PART itself if installation here is illegal. }
	{ This function may return NIL. PRECONDITION: Part must be }
	{ properly delinked. }
var
	prev: GearPtr;	{ Previously Equipped Gear }
	IC: GearPtr;	{ Inv Com counter }
begin
	if ( Slot = Nil ) or ( Part = Nil ) then begin
		{ Can't equip PART into SLOT if one or both are }
		{ nonexistant. }
		EquipGear := Part;

	end else if IsLegalSlot( Slot , Part ) then begin
		{ An equipment slot can only store one item of any }
		{ given type, so check the SLOT to see if it already }
		{ has an item of PART's type equipped. }
		ic := Slot^.InvCom;
		prev := Nil;
		while ic <> Nil do begin
			if ic^.G = Part^.G then begin
				Prev := IC;
			end;
			ic := ic^.Next;
		end;

		{ Insert the new equipment, and delink the old. }
		InsertInvCom( Slot , Part );
		if Prev <> Nil then DelinkGear( Slot^.InvCom , Prev );

		{ Return a pointer to the previously equipped gear, }
		{ now delinked from SLOT. If there was no previously }
		{ equipped gear of course this will be NIL. }
		EquipGear := Prev;
	end else begin
		{ PART isn't a legal invcom, so return it as the }
		{ unequipped component. }
		EquipGear := Part;
	end;
end;

Function SeekGear( Master: GearPtr; G,S: Integer; CheckInv: Boolean ): GearPtr;
	{ Search through all the subcoms and invcoms of MASTER and }
	{ find a part which matches G,S. If more than one applicable }
	{ part is found, return the part with the highest V field... }
	{ Unless it's repairfuel, in which case return the one with the lowest V. }
	{ If no such part is found, return Nil. }
{ FUNCTIONS BLOCK }
	Function CompGears( P1,P2: GearPtr ): GearPtr;
		{ Given two gears, P1 and P2, return the gear with }
		{ the higest V field. }
	var
		it: GearPtr;
	begin
		it := Nil;
		if P1 = Nil then it := P2
		else if P2 = Nil then it := P1
		else if G = GG_RepairFuel then begin
			if P1^.V < P2^.V then it := P1
			else it := P2;
		end else begin
			if P1^.V > P2^.V then it := P1
			else it := P2;
		end;
		CompGears := it;
	end;

	Function SeekPartAlongTrack( P: GearPtr ): GearPtr;
		{ Search this line of sibling components for a part }
		{ which matches G , S. }
	var
		it: GearPtr;
	begin
		it := Nil;
		while P <> Nil do begin
			if ( P^.G = G ) and ( P^.S = S ) then begin
				it := CompGears( it , P );
			end;
			if P^.G <> GG_Cockpit then begin
				it := CompGears( SeekPartAlongTrack( P^.SubCom ) , it );
				if CheckInv then it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
			end;
			P := P^.Next;
		end;
		SeekPartAlongTrack := it;
	end;

begin
	if CheckInv then
		SeekGear := CompGears( SeekPartAlongTrack( Master^.InvCom ) , SeekPartAlongTrack( Master^.SubCom ) )
	else
		SeekGear := SeekPartAlongTrack( Master^.SubCom );
end;

Function SeekGear( Master: GearPtr; G,S: Integer ): GearPtr;
	{ Seek an active gear, automatically checking the inventory as }
	{ well as the subcomponents. }
begin
	SeekGear := SeekGear( Master , G , S , True );
end;

Function SeekCurrentLevelGear( Master: GearPtr; G,S: Integer ): GearPtr;
	{ Seek a gear which is along the specified path. }
var
	CLG: GearPtr;
begin
	CLG := Nil;
	while ( Master <> Nil ) and ( CLG = Nil ) do begin
		if ( Master^.G = G ) and ( Master^.S = S ) then CLG := Master;
		Master := Master^.Next;
	end;
	SeekCurrentLevelGear := CLG;
end;

Function GearEncumberance( Mek: GearPtr ): Integer;
	{ Return how many unscaled mass units this gear may carry without }
	{ incurring a penalty. }
var
	HM: Integer;
begin
	if Mek = Nil then begin
		GearEncumberance := 0;
	end else if Mek^.G = GG_Mecha then begin
		{ Encumberance value is basic MassPerMV + Size of mecha + bonus for heavy Actuator. }
		HM := CountActivePoints( Mek , GG_MoveSys , GS_HeavyActuator ) div Mek^.V;
		if HM > 2 then HM := 2;
		GearEncumberance := MassPerMV + Mek^.V + HM;
	end else if Mek^.G = GG_Character then begin
		{ Encumberance value is BODY stat + 3. }
		GearEncumberance := CStat( Mek , STAT_Body ) + 2 + CharaSkillRank( Mek , NAS_WeightLifting );
	end else begin
		GearEncumberance := 0;
	end;
end;

Function IntrinsicMVTVMod( Mek: GearPtr ): Integer;
    { Return the MV/TV modifier from intrinsic mass. }
const
	tmp_MAX = 32767;
	tmp_MIN = -32768;
var
	tmp: Int64;
begin
	tmp := -(Int64(IntrinsicMass( Mek )) div Int64(MassPerMV));
	if tmp < tmp_MIN then begin
		tmp := tmp_MIN;
	end else if tmp_MAX < tmp then begin
		tmp := tmp_MAX;
	end;
	IntrinsicMVTVMod := tmp;
end;

Function EquipmentMVTVMod( Mek: GearPtr ): Integer;
    { Return the MV/TV modifier from carried stuff. }
const
	tmp_MAX = 32767;
	tmp_MIN = -32768;
var
	EMass: LongInt;
	EV: Integer;
	tmp: Int64;
begin
	EV := GearEncumberance( Mek );
	if EV < 1 then EV := 1;
	EMass := EquipmentMass( Mek ) - EV;
	if EMass < 0 then EMass := 0;
	tmp := -( Int64(EMass) div Int64(EV) );
	if tmp < tmp_MIN then begin
		tmp := tmp_MIN;
	end else if tmp_MAX < tmp then begin
		tmp := tmp_MAX;
	end;
	EquipmentMVTVMod := tmp;
end;

Function BaseMVTVScore( Mek: GearPtr ): Integer;
	{ Calculate the basic MV/TV score, ignoring for the moment }
	{ such things as form, tarcomps, gyros, falafel, etc. }
const
	tmp_MAX = 32767;
	tmp_MIN = -32768;
var
	MV: Integer;
	CPit: GearPtr;
	tmp: Int64;
begin
	{ Basic MV/TV is determined by the gear's mass and it's equipment. }
	tmp := Int64(IntrinsicMVTVMod( Mek )) + Int64(EquipmentMVTVMod( Mek ));
	if tmp < tmp_MIN then begin
		MV := tmp_MIN;
	end else if tmp_MAX < tmp then begin
		MV := tmp_MAX;
	end else begin
		MV := tmp;
	end;

	{ Seek the cockpit. If it's located in the head, +1 to MV and TR. }
	CPit := SeekGear( Mek , GG_Cockpit , 0 , False );
	if CPit <> Nil then begin
		{ The head bonus only applies for those forms which are cleared }
		{ to use their heads. }
		if InGoodModule( CPit ) and ( FindModule( CPit )^.S = GS_Head ) then Inc( MV );
	end;

	BaseMVTVScore := MV;
end;


Function ManeuverCost( Mek: GearPtr ): Integer;
	{ Determine the MV cost multiplier for this mecha. }
	{ A high MV results in a high multiplier; an augmented MV }
	{ (by Gyros or other systems) increases that multiplier }
	{ considerably. }
var
	MC,BMV,MV,N: Integer;
	Gyro: GearPtr;
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	{ Find the basic maneuver value. }
	BMV := FormMVBonus[ Mek^.S ] + BaseMVTVScore( Mek );
	MV := BMV;

	{ Modify for the gyroscope. }
	Gyro := SeekGear( Mek , GG_Support , GS_Gyro , False );
	if Gyro <> Nil then MV := MV + Gyro^.V - 1;

	{ Up to this point, no modifiers should take MV above 0. }
	if MV > 0 then MV := 0;

	{ Calculate the basic Maneuver Cost, in percentage. }
	if MV > -6 then begin
		N := 6 + MV;
		MC := (N * N * 4 );
	end else MC := 0;

	ManeuverCost := MC;
end;

Function TargetingCost( Mek: GearPtr ): Integer;
	{ Determine the TR cost multiplier for this mecha. }
	{ A high TR results in a high multiplier; an augmented TR }
	{ (by TarComp or other systems) increases that multiplier }
	{ considerably. }
var
	TC,BTR,TR,N: Integer;
	TarCom: GearPtr;	{ Targeting Computer }
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	BTR := FormTRBonus[ Mek^.S ] + BaseMVTVScore( Mek );
	TR := BTR;

	{ Add the bonus for targeting computer, if applicable. }
	TarCom := SeekGear( Mek , GG_Sensor , GS_TarCom , False );
	if TarCom <> Nil then TR := TR + TarCom^.V;

	{ Up to this point, no modifiers should take TR above 0. }
	if TR > 0 then TR := 0;

	{ Calculate the basic Targeting Cost, in percentage. }
	if TR > -6 then begin
		N := 6 + TR;
		TC := (N * N * 3 ) - 2 * N;
	end else TC := 0;

	TargetingCost := TC;
end;


Function ComponentValue( Part: GearPtr ): Int64;
	{Calculate the scaled value of PART, ignoring for the}
	{moment its subcomponents.}
var
	it: Int64;
	t,n: Integer;
	MAV: Int64;
begin
	Case Part^.G of
		GG_Module:	it := 25 * Part^.V + 35 * Part^.Stat[ STAT_Armor ];
		GG_Weapon:	it := WeaponValue(Part);
		GG_Ammo:	it := AmmoValue(Part);
		GG_MoveSys:	it := MovesysValue(Part);
		GG_Holder:	it := 15;
		GG_ExArmor:	it := ArmorValue( Part );
		GG_Cockpit:	it := 25 * Part^.Stat[ STAT_Armor ];
		GG_Sensor:	it := SensorValue( Part );
		GG_Electronics:	it := ElecValue( Part );
		GG_Support:	it := SupportValue( Part );
		GG_Shield:	it := ShieldValue( Part );
		GG_Swag:	it := SwagValue( Part );
		GG_Usable:	it := UsableValue( Part );
		GG_RepairFuel:	it := Part^.V;
		GG_Consumable:	it := FoodValue( Part );
		GG_Modifier:	it := ModifierCost( Part );
		GG_WeaponAddOn:	it := WeaponAddOnCost( Part );

	{If a component type is not listed above, it has no value.}
	else it := 0
	end;

	{ Modify for mass adjustment. }
	MAV := NAttValue( PArt^.NA , NAG_GearOps , NAS_MassAdjust );

	{ If at scale 0, mass reduction is FAR more expensive. }
	if ( Part^.Scale = 0 ) and ( MAV < 0 ) then MAV := MAV * 5;
	if ( MAV > 0 ) and ( it > 0 ) then begin
		it := ( it * ( MassPerMV * 4 - MAV ) ) div ( MassPerMV * 4 );
		if it < 1 then it := 1;
	end else if MAV < 0 then begin
		it := it * ( MassPerMV + Abs( MAV )) div MassPerMV;
	end;

	{ Modify for material. }
	if NAttValue( Part^.NA , NAG_GearOps , NAS_Material ) = NAV_BioTech then begin
		if Part^.G = GG_Mecha then begin
			it := Part^.V * 250;
		end else begin
			it := ( it * 3 ) div 2;
		end;
	end;

	{ Modify for being overstuffed. }
	if not IsMasterGear( Part ) then begin
		N := ComponentComplexity( Part );
		T := SubComComplexity( Part );
		if ( N < T ) and ( T > 0 ) then begin
			it := ( it * ( 10 + T - N ) ) div 10;
		end;
	end;

	{ Modify for scale. }
	if ( it > 0 ) and ( Part^.Scale > 0 ) then begin
		for t := 1 to Part^.Scale do it := it * 5;
	end;

	{ Modify for intrinsics. }
	it := it + IntrinsicCost( Part );

	{ Modify for Fudge. }
	it := it + NAttValue( Part^.NA , NAG_GearOps , NAS_Fudge );

	ComponentValue := it;
end;

Function TrackValue( Part: GearPtr ): Int64;
	{Calculate the value of this list of gears, including all}
	{subcomponents.}
var
	it: Int64;
begin
	{Initialize the total Value to 0.}
	it := 0;

	{Loop through all components.}
	while Part <> Nil do begin
		it := it + ComponentValue(Part);

		{Check for subcomponents and invcomponents.}
		if Part^.SubCom <> Nil then it := it + TrackValue(Part^.SubCom);
		if Part^.InvCom <> Nil then it := it + TrackValue(Part^.InvCom);

		{Go to the next part in the series.}
		Part := Part^.Next;
	end;

	{Return the value.}
	TrackValue := it;
end;

Function BaseGearValue( Master: GearPtr ): Int64;
	{Calculate the value of MASTER, including all of its}
	{subcomponents.}
begin
	{The formula to work out the total value of this gear}
	{is basic value + SubCom value + InvCom value.}
	BaseGearValue := ComponentValue(Master) + TrackValue(Master^.SubCom) + TrackValue(Master^.InvCom);
end;

Function GearValue( Master: GearPtr ): LongInt;
	{ Calculate the value of this gear, adjusted for mecha stats. }
const
	V_MAX = 2147483647;
	V_MIN = -2147483648;
var
	it: Int64;	{ Using a larger container than the cost needs so as to catch }
	MV: LongInt;	{ overflow when doing calculations. }
begin
	it := BaseGearValue( Master );

	{ Mecha have a special on-top-of-everything cost modifier for }
	{ a high MV or TR. }
	if Master^.G = GG_Mecha then begin
		{ Cost increases by 20% for every point above -4 }
		MV := ManeuverCost( Master );
		it := ( it * ( 100 + MV ) ) div 100;

		{ The same rule applies for targeting. }
		MV := TargetingCost( Master );
		it := ( it * ( 100 + MV ) ) div 100;
	end;

	if (V_MAX < it) then begin
		GearValue := V_MAX;
	end else if (it < V_MIN) then begin
		GearValue := V_MIN;
	end else begin
		GearValue := it;
	end;
end;

function SeekGearByName( LList: GearPtr; Name: String ): GearPtr;
	{ Seek a gear with the provided name. If no such gear is }
	{ found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	while LList <> Nil do begin
		if UpCase( GearName( LList ) ) = Name then it := LList;
		if ( it = Nil ) then it := SeekGearByName( LList^.SubCom , Name );
		if ( it = Nil ) then it := SeekGearByName( LList^.InvCom , Name );
		LList := LList^.Next;
	end;
	SeekGearByName := it;
end;

function SeekGearByDesig( LList: GearPtr; Name: String ): GearPtr;
	{ Seek a gear with the provided designation. If no such gear is }
	{ found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	while LList <> Nil do begin
		if UpCase( SAttValue( LList^.SA , 'DESIG' ) ) = Name then it := LList;
		if ( it = Nil ) then it := SeekGearByDesig( LList^.SubCom , Name );
		if ( it = Nil ) then it := SeekGearByDesig( LList^.InvCom , Name );
		LList := LList^.Next;
	end;
	SeekGearByDesig := it;
end;

function SeekGearByIDTag( LList: GearPtr; G,S,V: LongInt ): GearPtr;
	{ Seek a gear which posesses a NAtt with the listed G,S,V score. }
	{ Normally this procedure will be used to find things based on }
	{ ID numbers like Personal/CID or Narrative/NID, but I guess you }
	{ could use it to find a part that's taken Damage/Struct/40 or }
	{ whatever. }
var
	it: GearPtr;
begin
	it := Nil;
	while LList <> Nil do begin
		if NAttValue( LList^.NA , G , S ) = V then it := LList;
		if ( it = Nil ) then it := SeekGearByIDTag( LList^.SubCom , G , S , V );
		if ( it = Nil ) then it := SeekGearByIDTag( LList^.InvCom , G , S , V );
		LList := LList^.Next;
	end;
	SeekGearByIDTag := it;
end;

function SeekGearByG( LList: GearPtr; G: Integer ): GearPtr;
	{ Seek a gear with the provided general type. }
	{ If no such gear is found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	while LList <> Nil do begin
		if LList^.G = G then it := LList;
		if ( it = Nil ) then it := SeekGearByG( LList^.SubCom , G );
		if ( it = Nil ) then it := SeekGearByG( LList^.InvCom , G );
		LList := LList^.Next;
	end;
	SeekGearByG := it;
end;

function SeekSubsByG( LList: GearPtr; G: Integer ): GearPtr;
	{ As above, but only check subcoms. }
	{ If no such gear is found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if LList^.G = G then it := LList;
		if ( it = Nil ) then it := SeekGearByG( LList^.SubCom , G );
		LList := LList^.Next;
	end;
	SeekSubsByG := it;
end;

function MaxIDTag( LList: GearPtr; G,S: Integer ): LongInt;
	{ Find the maximum NAtt value whose G and S descriptors match }
	{ those which have been provided. This function can be used to }
	{ find a new unique ID for a character or puzzle item added to an }
	{ existing campaign. }
var
	IT,N: LongInt;
begin
	it := 1;
	while LList <> Nil do begin
		{ Check this item. }
		N := NAttValue( LList^.NA , G , S );
		if N > IT then it := N;

		{ Check its children. }
		N := MaxIDTag( LList^.SubCom , G , S );
		if N > IT then it := N;
		N := MaxIDTag( LList^.InvCom , G , S );
		if N > IT then it := N;

		{ Move to the next item. }
		LList := LList^.Next;
	end;
	MaxIDTag := it;
end;

Function EncumberanceLevel( PC: GearPtr ): Integer;
	{ Return a value indicating this character's current }
	{ encumberance level. }
const
	ret_MAX = 32767;
var
	EMass: LongInt;
	EV: Integer;
	ret: LongInt;
begin
	EV := GearEncumberance( PC );
	if EV < 1 then EV := 1;
	EMass := EquipmentMass( PC ) - EV;

	{ Reduce the basic mass by the character's weight lifting skill. }
	if PC^.G = GG_Character then begin
		EMass := EMass - NAttValue( PC^.NA , NAG_Skill , NAS_WeightLifting );
	end;

	if EMass > 0 then begin
		ret := EMass div LongInt(EV);
		if ret_MAX < ret then begin
			EncumberanceLevel := ret_MAX;
		end else begin
			EncumberanceLevel := ret;
		end;
	end else begin
		EncumberanceLevel := 0;
	end;
end;

function CStat( PC: GearPtr; Stat: Integer ): Integer;
	{ Player character statistics may be improved or hindered }
	{ by any number of things- equipment, encumberance, status }
	{ effects, training, et cetera. }
const
	Hunger_Stat_Rank: Array [1..NumGEarStats] of Byte = (
		5, 3, 1, 4, 6, 7, 2, 0
	);
	Morale_Stat_Rank: Array [1..NumGEarStats] of Byte = (
		30, 20, 50, 40, 70, 10, 60, 80
	);
var
	it,SP,MP: Integer;
	MG: GearPtr;	{ Modifier Gears. }
	SFX: NAttPtr;	{ Status Effects. }
begin
	if ( PC = Nil ) or ( PC^.G <> GG_Character ) or ( Stat < 1 ) or ( Stat > NumGearStats ) then begin
		CStat := 0;
	end else begin
		it := PC^.Stat[ Stat ];

		{ SPEED and REFLEXES are penalized by encumberance. }
		if ( STAT = STAT_SPeed ) then begin
			it := it - EncumberanceLevel( PC );
		end else if ( STAT = STAT_Reflexes ) then begin
			it := it - ( EncumberanceLevel( PC ) div 2 );
		end;

		{ All stats are penalized by exhaustion. }
		SP := CharCurrentStamina( PC );
		MP := CharCurrentMental( PC );
		if ( SP = 0 ) and ( MP = 0 ) then begin
			it := it - 3;
		end else if ( SP = 0 ) or ( MP = 0 ) then begin
			it := it - 1;
		end;

		{ Hungry PCs get penalized. }
		MP := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts - NumGearStats;
		if MP > 0 then begin
			it := it - ( ( MP + Hunger_Stat_Rank[ STAT ] ) div NumGearStats );
		end;

		{ Demoralized PCs get penalized. }
		MP := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );
		if ( MP + Morale_Stat_Rank[ STAT ] ) > 100 then begin
			it := it - 1;
		end else if ( MP - Morale_Stat_Rank[ STAT ] ) < -100 then begin
			it := it + 1;
		end;

		{ Check for modifier gears. }
		MG := PC^.SubCom;
		while MG <> Nil do begin
			if ( MG^.G = GG_Modifier ) and ( MG^.S = GS_StatModifier ) then begin
				it := it + MG^.Stat[ STAT ];
			end;
			MG := MG^.Next;
		end;

		{ If there's another master, i.e. a mecha, add in the }
		{ modifiers from there as well. }
		if ( PC^.Parent <> Nil ) and ( FindMaster( PC^.Parent ) <> Nil ) then begin
			MG := FindMaster( PC^.Parent )^.SubCom;
			while MG <> Nil do begin
				if ( MG^.G = GG_Modifier ) and ( MG^.S = GS_StatModifier ) then begin
					it := it + MG^.Stat[ STAT ];
				end;
				MG := MG^.Next;
			end;
		end;

		{ Check status effects. }
		SFX := PC^.NA;
		while SFX <> Nil do begin
			if ( SFX^.G = NAG_StatusEffect ) and ( SFX^.S >= 1 ) and ( SFX^.S <= Num_Status_FX ) then begin
				it := it + SX_StatMod[ SFX^.S , Stat ];
			end;
			SFX := SFX^.Next;
		end;

		{ Stats never drop below 1. }
		if it < 1 then it := 1;

		CStat := it;
	end;
end;

Procedure WriteCGears( var F: Text; G: GearPtr );
	{ This procedure writes to file F a compacted list of gears. }
	{ Hopefully, it will be an efficient procedure, saving }
	{ only as much data as is needed. }
var
	Sam: GearPtr;	{ The sample gear, for comparing standard values. }
	msg: String;	{ A single line for the save file. }
	T: Integer;
	NA: NAttPtr;	{ Numeric Attribute pointer }
	SA: SAttPtr;	{ String Attribute pointer }
begin
	{ Allocate memory for our SAMple. }
	Sam := NewGear( Nil );

	while G <> Nil do begin
		{ Write the proceed value here. }
		{ Record G , S , V , and Scale. }
		msg := BStr( SaveFileContinue ) + ' ' + BStr( G^.G ) + ' ' + BStr( G^.S ) + ' ' + BStr( G^.V ) + ' ' + BStr( G^.Scale );
		writeln( F , msg );

		{ Compare the other gear values to an initialized Sam. }
		Sam^.G := G^.G;
		Sam^.S := G^.S;
		Sam^.V := G^.V;
		InitGear( Sam );

		{ Export a single line to record any stats this gear has }
		{ which differ from the default values. }
		msg := 'Stats ';
		for t := 1 to NumGearStats do begin
			if G^.Stat[T] <> Sam^.Stat[T] then begin
				msg := msg + BStr( T ) + ' ' + BStr( G^.Stat[T] ) + ' ';
			end;
		end;
		writeln( F , msg );

		{ Export Numeric Attributes }
		NA := G^.NA;
		while NA <> Nil do begin
			msg := BStr( SaveFileContinue ) + ' ' + BStr( NA^.G ) + ' ' + BStr( NA^.S ) + ' ' + BStr( NA^.V );
			writeln( F , msg );
			NA := NA^.Next;
		end;
		{ Write the sentinel line here. }
		writeln( F , SaveFileSentinel );

		{ Export String Attributes }
		SA := G^.SA;
		while SA <> Nil do begin
			{ Error check- only output valid string attributes. }
			if Pos('<',SA^.Info) > 0 then writeln( F , SA^.Info );
			SA := SA^.Next;
		end;
		{ Write the sentinel line here. }
		writeln( F , 'Z' );

		{ Export the subcomponents and invcomponents of this gear. }
		WriteCGears( F , G^.InvCom );
		WriteCGears( F , G^.SubCom );

		{ Move to the next gear in the list. }
		G := G^.Next;
	end;

	{ Write the sentinel line here. }
	writeln( F , SaveFileSentinel );

	{ Deallocate SAM. }
	DisposeGear( Sam );
end;

Function ReadCGears( var F: Text ): GearPtr;
	{ Read a series of gears which have been saved by the SaveGears }
	{ procedure. The 'C' means Compact. }

	Function ReadNumericAttributes( var it: NAttPtr ): NAttPtr;
		{ Read some numeric attributes from the file. }
	var
		N,G,S: Integer;
		V: LongInt;
		TheLine: String;
	begin
		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ Extract the action code. }
			N := ExtractValue( TheLine );

			{ If this action code implies that there's a gear }
			{ to load, get to work. }
			if N = SaveFileContinue then begin
				{ Read the specific values of this NAtt. }
				G := ExtractValue( TheLine );
				S := ExtractValue( TheLine );
				V := ExtractValue( TheLine );
				SetNAtt( it , G , S , V );
			end;
		until ( N = SaveFileSentinel ) or EoF( F );

		ReadNumericAttributes := it;
	end;

	Function ReadStringAttributes( var it: SAttPtr ): SAttPtr;
		{ Read some string attributes from the file. }
	var
		TheLine: String;
	begin
		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ If this is a valid string attribute, file it. }
			if Pos('<',TheLine) > 0 then begin
				SetSAtt( it , TheLine );
			end;
		until ( Pos('<',TheLine) = 0 ) or EoF( F );

		ReadStringAttributes := it;
	end;

	Function REALReadGears( Parent: GearPtr ): GearPtr;
		{ This is the workhorse procedure. It's the part that }
		{ actually does the reading from disk. }
	var
		it,Part: GearPtr;
		TheLine: String; { The info is read one text line at a time. }
		N,G,S,V,Scale: Integer;
	begin
		{ Initialize our gear list to NIL. }
		it := Nil;

		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ Error check- if we got a blank line, that's an error. }
			if TheLine = '' then Break;

			{ Extract the action code. }
			N := ExtractValue( TheLine );

			{ If this action code implies that there's a gear }
			{ to load, get to work. }
			if N = SaveFileContinue then begin
				{ Extract the remaining values from the line. }
				G := ExtractValue( TheLine );
				S := ExtractValue( TheLine );
				V := ExtractValue( TheLine );
				Scale := ExtractValue( TheLine );

				{ Add a new gear to the list, and initialize it. }
				Part := AddGear( it , Parent );
				Part^.G := G;
				Part^.S := S;
				Part^.V := V;

				InitGear( Part );

				{ Clear any numeric attributes that may }
				{ have been set by InitGear. }
				if Part^.NA <> Nil then DisposeNAtt( Part^.NA );

				{ Set SCALE to the stored value, since }
				{ INITGEAR probably set it to parent scale. }
				Part^.Scale := Scale;

				{ Read the stats line, and save it for now. }
				readln( F , TheLine );

				{ Remove the STATS tag }
				ExtractWord( TheLine );
				{ Keep processing until we run out of string. }
				while TheLine <> '' do begin
					{ Determine what stat to adjust. }
					G := ExtractValue( TheLine );
					V := ExtractValue( TheLine );
					{ If this is a legal stat, adjust it. Otherwise, ignore. }
					if ( G > 0 ) and ( G <= NumGearStats ) then begin
						Part^.Stat[G] := V;
					end;
				end;

				{ Read Numeric Attributes }
				ReadNumericAttributes( Part^.NA );

				{ Read String Attributes }
				ReadStringAttributes( Part^.SA );

				{ Read InvComs }
				Part^.InvCom := RealReadGears( Part );

				{ Read SubComs }
				Part^.SubCom := RealReadGears( Part );
			end;

		until ( N = SaveFileSentinel ) or EoF( F );

		RealReadGears := it;
	end;

begin
	{ Call the real procedure with a PARENT value of Nil. }
	ReadCGears := REALReadGears( Nil );
end;


Function IsExternalPart( Master,Part: GearPtr ): Boolean;
	{ Return TRUE if Part is an invcom or a descendant of an invcom. }
var
	IsXP: Boolean;
begin
	{ Assume FALSE until proven TRUE. }
	IsXP := False;
	while ( Part <> Nil ) and ( Part <> Master ) and not IsXP do begin
		if IsInvCom( Part ) then IsXP := True;
		Part := Part^.Parent;
	end;
	IsExternalPart := IsXP;
end;

end.
