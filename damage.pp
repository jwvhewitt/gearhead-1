unit damage;
	{This unit handles damage.}
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

uses gears,context,ghintrinsic;

Const
	NAG_Damage = 12;

	NAS_StrucDamage = 0;	{Structural Damage is what we would}
				{normally refer to as HP loss.}
	NAS_ArmorDamage = 1;	{As armor gets hit, it loses its}
				{protective ability.}
	NAS_OutOfAction = 2;	{ if OutOfAction <> 0 , this model is OutOfAction }
	NAS_Resurrections = 3;	{ Number of times the PC has cheated death. }

	{ *** HISTORY VARIABLES *** }
	DAMAGE_LastPartHit: GearPtr = Nil;
	DAMAGE_EjectRoll: Boolean = False;
	DAMAGE_EjectOK: Boolean = False;
	DAMAGE_PilotDied: Boolean = False;
	DAMAGE_DamageDone: LongInt = 0;
	DAMAGE_OverKill: LongInt = 0;
	DAMAGE_Iterations: Integer = 0;
	DAMAGE_AmmoExplosion: Boolean = False;

	Num_Perm_Injuries = 5;
	Perm_Injury_List: Array [1..Num_Perm_Injuries] of Byte = (
		21,22,23,24,25
	);
	Perm_Injury_Slot: Array [1..Num_Perm_Injuries] of String = (
		'EYES','SPINE','MUSCULATURE','SKELETON','HEART'
	);

Function WeaponBVSetting( Weapon: GearPtr ): Integer;

Function WeaponDC( Attacker: GearPtr ; AtOp: Integer ): Integer;


Function GearCurrentDamage(Part: GearPtr): LongInt;
Function GearCurrentArmor(Part: GearPtr): Integer;
Function PercentDamaged( Master: GearPtr ): Integer;
Function NotDestroyed(Part: GearPtr): Boolean;
Function Destroyed(Part: GearPtr): Boolean;
Function PartActive( Part: GearPtr ): Boolean;
Function RollDamage( DC , Scale: Integer ): Integer;
Function NumActiveGears(Part: GearPtr): Integer;
Function FindActiveGear(Part: GearPtr; N: Integer): GearPtr;

Function CountActivePoints(Master: GearPtr; G,S: Integer): Integer;
Function CountActiveParts(Master: GearPtr; G,S: Integer): Integer;
Function CountTotalParts(Master: GearPtr; G,S: Integer): Integer;

Function SeekActiveIntrinsic( Master: GearPtr; G,S: Integer ): GearPtr;
Function SeekNDPart( Master: GearPtr; G,S: Integer ): GearPtr;
Function OverloadCapacity( Mek: GearPtr ): Integer;
Function MechaManeuver( Mek: GearPtr ): Integer;
Function MechaTargeting( Mek: GearPtr ): Integer;
Function MechaSensorRating( Mek: GearPtr ): Integer;
Function MechaStealthRating( Mek: GearPtr ): Integer;

Function PCommRating( Master: GearPtr ): Integer;

Function LocateGoodAmmo( Weapon: GearPtr ): GearPtr;

Function WeaponAttackAttributes( Attacker: GearPtr ): String;
Function HasAttackAttribute( AtAt: String; N: Integer ): Boolean;
Function HasAreaEffect( AtAt: String ): Boolean;
Function HasAreaEffect( Attacker: GearPtr ): Boolean;
Function NonDamagingAttack( AtAt: String ): Boolean;
Function NoCalledShots( AtAt: String; AtOp: Integer ): Boolean;

Function AmmoRemaining( Weapon: GearPtr ): Integer;
Function ScaleRange( Rng,Scale: Integer ): Integer;
Function WeaponDescription( Weapon: GearPtr ): String;
Function ExtendedDescription( Part: GearPtr ): String;

Procedure ApplyPerminantInjury( PC: GearPtr );
Procedure ApplyCyberware( PC,Cyber: GearPtr );

implementation

uses i18nmsg,gearutil,ghchars,ghguard,ghmecha,ghmodule,ghmovers,ghsensor,
     ghsupport,ghswag,ghweapon,texutil,ui4gh;

const
	MVSensorPenalty = 1;
	MVGyroPenalty = 6;
	TRSensorPenalty = 5;

var
	Damage_Strings: SAttPtr;

Function WeaponBVSetting( Weapon: GearPtr ): Integer;
	{ Return the BV Setting used by this weapon. It should be }
	{ one of either Off, 1/2, 1/4, or Max. }
var
	BV: Integer;
begin
	if Weapon = Nil then Exit( BV_Off );

	BV := NAttValue( Weapon^.NA , NAG_Prefrences , NAS_DefAtOp );
	if BV = 0 then begin
		if Weapon^.G <> GG_Weapon then begin
			BV := BV_Off;
		end else if ( Weapon^.S = GS_Ballistic ) then begin
			BV := DefBallisticBV;
		end else if Weapon^.S = GS_BeamGun then begin
			BV := DefBeamGunBV;
		end else if Weapon^.S = GS_Missile then begin
			BV := DefMissileBV;
		end else begin
			BV := BV_Off;
		end;
	end;

	WeaponBVSetting := BV;
end;


Function WeaponDC( Attacker: GearPtr ; AtOp: Integer ): Integer;
	{ Calculate the amount of damage that this gear can do when used }
	{ in an attack. }
var
	D: Integer;
	Master: GearPtr;
	Procedure ApplyCCBonus;
		{ Apply the close combat bonus for weapons. }
	begin
		if Master <> Nil then begin
			if Master^.G = GG_Character then begin
				D := D + ( CStat( Master, STAT_Body ) - 10 ) div 2;

				{ Martial Arts attacks get a bonus based on skill level. }
				if Attacker^.G = GG_Module then begin
					D := D + ( NAttValue( Master^.NA , NAG_Skill , 9 ) - 1 ) div 2;
				end;

				if D < 1 then D := 1;
			end else if Master^.G = GG_Mecha then begin
				D := D + ( Master^.V - 1 ) div 2;

				{ Zoanoids get a CC damage bonus. Apply that here. }
				if Master^.S = GS_Zoanoid then begin
					D := D + ZoaDmgBonus;
				end;
			end;
		end;

	end;
begin
	{ Error check - make sure we have a valid weapon. }
	if Attacker = Nil then Exit( 0 );

	{ Locate the master of this gear. }
	Master := Attacker^.Parent;
	if Master <> Nil then begin
		while Master^.Parent <> Nil do Master := Master^.Parent;
	end;

	if Attacker^.G = GG_Weapon then begin
		D := Attacker^.V;

		{ Apply damage bonuses here. }
		if ( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee ) then begin
			ApplyCCBonus;
		end;

	end else if Attacker^.G = GG_Module then begin
		D := ModuleBaseDamage( Attacker ) div 2;
		if D < 1 then D := 1;
		ApplyCCBonus;

	end else if Attacker^.G = GG_Ammo then begin
		D := Attacker^.V;

	end else begin
		D := 0;
	end;

	{ Apply bonuses for weapon add-ons. }
	Master := Attacker^.InvCom;
	while Master <> Nil do begin
		if ( Master^.G = GG_WeaponAddOn ) and NotDestroyed( Master ) then begin
			D := D + Master^.V;
		end;
		Master := Master^.Next;
	end;

	WeaponDC := D;
end;


Function GearCurrentDamage(Part: GearPtr): LongInt;
	{Calculate the current remaining damage points for}
	{this gear.}
var
	it: LongInt;
begin
	it := GearMaxDamage(Part);
	if it > 0 then begin
		it := it - NAttValue(Part^.NA,NAG_Damage,NAS_StrucDamage);
		if it < 0 then it := 0;
	end;
	GearCurrentDamage := it;
end;

Function GearCurrentArmor(Part: GearPtr): Integer;
	{Calculate the current remaining armor PV for}
	{this gear.}
var
	it: Integer;
begin
	if ( Part <> Nil ) and ( Part^.G >= 0 ) then begin
		it := GearMaxArmor(Part);
		it := it - NAttValue( Part^.NA , NAG_Damage , NAS_ArmorDamage );
		if it < 0 then it := 0;
	end else begin
		it := 0;
	end;
	GearCurrentArmor := it;
end;

Function PercentDamaged( Master: GearPtr ): Integer;
	{ Add up the damage scores of every part on this mecha, and }
	{ return the percentage of undamaged mek. }
var
	MD,CD: LongInt;		{ Max Damage , Current Damage }

	procedure CheckPart( Part: GearPtr );
		{ Examine this part and its children for damage. }
	var
		D: Integer;
		SPart: GearPtr;
	begin
		D := GearMaxDamage( Part );
		if D > 0 then begin
			MD := MD + D;
			CD := CD + GearCurrentDamage( Part );
		end;

		{ Check sub components. }
		SPart := Part^.SubCom;
		while SPart <> Nil do begin
			CheckPart( SPart );
			SPart := SPart^.Next;
		end;

		{ Check inv components. }
		SPart := Part^.InvCom;
		while SPart <> Nil do begin
			CheckPart( SPart );
			SPart := SPart^.Next;
		end;
	end;
begin
	MD := 0;
	CD := 0;
	CheckPart( Master );

	{ Error check - don't divide by 0. }
	if MD < 1 then MD := 1;
	PercentDamaged := ( CD * 100 ) div MD;
end;

Function NotDestroyed(Part: GearPtr): Boolean;
	{Check this part and see whether or not it's been}
	{destroyed. For most parts, it isn't destroyed if it}
	{has any hits remaining. For parts whose HP = -1, the}
	{part counts as not destroyed if it has any not-destroyed}
	{subcomponents. For master gears, the not destroyed check}
	{might be a bit more complicated...}
var
	CD: Integer;
	it: Boolean;
begin
	if Part = Nil then begin
		{ Error Check - Undefined parts automatically count }
		{   as destroyed. }
		it := False;

	end else if Part^.G < 0 then begin
		{ Virtual types never count as destroyed. }
		it := True;

	end else if ( Part^.G = GG_Shield ) or ( Part^.G = GG_ExArmor ) then begin
		{ Armor type gears count as not destroyed if they have }
		{ any armor rating left. }
		CD := GearCurrentArmor(Part);
		it := CD > 0;

	end else if Part^.G = GG_Mecha then begin
		{In order for a mecha to count as not destroyed,}
		{its body + engine must have some hits remaining.}
		{Locate the body...}
		Part := Part^.SubCom;
		{ ASSERT: All level one subcomponents will be Modules. }
		while (Part <> Nil) and (Part^.S <> GS_Body) do begin
			Part := Part^.Next;
		end;

		{The nondestroyedness of the mecha depends upon the}
		{state of the body.}
		if Part = Nil then it := false
		else it := NotDestroyed(Part);

		{ If the body is ok, check the engine. }
		if it then begin
			Part := Part^.SubCom;
			while (Part <> Nil) and ((Part^.G <> GG_Support) or (Part^.S <> GS_Engine)) do begin
				Part := Part^.Next;
			end;

			{ The nondestroyedness of the mecha now depends }
			{ upon the state of the engine. }
			if Part = Nil then it := false
			else it := NotDestroyed(Part);
		end;

	end else if Part^.G = GG_Character then begin
		{In order for a character to count as not destroyed,}
		{its main gear must have some hits remaining,}
		{as well as any subcom bodies & heads.}
		it := GearCurrentDamage(Part) > 0;

		if it then begin
			{ Check all subcomponents. Bodies and heads must be intact. }
			Part := Part^.SubCom;
			while (Part <> Nil) do begin
				if Part^.G = GG_Module then begin
					if ( Part^.S = GS_Body ) or ( Part^.S = GS_Head ) then begin
						it := it and NotDestroyed( Part );
					end;
				end;
				Part := Part^.Next;
			end;
		end;

	end else begin

		{Calculate the current damage points of the gear.}
		CD := GearCurrentDamage(Part);

		if CD = -1 then begin
			{This gear is a pod or other storage type.}
			{It counts as not destroyed if it has any not}
			{destroyed children.}
			Part := Part^.SubCom;
			it := false;

			while Part <> Nil do begin
				it := it OR NotDestroyed(Part);
				Part := Part^.Next;
			end;
		end else if GearMaxDamage( Part ) = 0 then begin
			{ Parts with Max Damage = 0 can't be destroyed. }
			it := True;

		end else begin
			{This is a regular type gear with positive HP.}
			{Whether or not the gear is destroyed is based}
			{on whether or not it has HP left.}
			it := CD > 0;
		end;
	end;

	NotDestroyed := it;
end;

Function Destroyed(Part: GearPtr): Boolean;
	{ Some other procedures could use this one... }
begin
	Destroyed := Not NotDestroyed( Part );
end;

Function PartActive( Part: GearPtr ): Boolean;
	{ This function will check to see whether or not PART is }
	{ fully functioning. A part is "active" if it is not destroyed, }
	{ and if all of its parents up to root are also not destroyed. }
begin
	{ ERROR CHECK - make sure PART is a valid pointer. }
	if Part = Nil then Exit( False );

	if Part^.Parent = Nil then
		PartActive := NotDestroyed( PART )
	else
		PartActive := NotDestroyed( PART ) and PartActive( Part^.Parent );
end;

Function RollDamage( DC , Scale: Integer ): Integer;
	{ Roll random damage, then modify for scale. }
	{ DC is Damage Class, DP is Damage Points. }
var
	DP,T: Integer;
begin
	DP := 1;
	while DC > 5 do begin
		DP := DP + Random( 10 );
		DC := DC - 5;
	end;
	DP := DP + Random( DC * 2 );
	if Scale > 0 then DP := DP * 4;
	if Scale > 1 then begin
		for t := 2 to Scale do DP := DP * 5;
	end;
	RollDamage := DP;
end;

Function NumActiveGears(Part: GearPtr): Integer;
	{Calculate the number of active sibling components in}
	{the list of parts PART.}
var
	N: Integer;
begin
	N := 0;
	while Part <> Nil do begin
		if NotDestroyed(Part) then Inc(N);
		Part := Part^.Next;
	end;
	NumActiveGears := N;
end;

Function FindActiveGear(Part: GearPtr; N: Integer): GearPtr;
	{Given a list of gears PART, locate the Nth gear which}
	{is not destroyed. If no such gear exists, closest match.}
	{Return NIL if there are no nondestroyed gears in the list.}
var
	t: Integer;	{A counter}
	it: GearPtr;	{the gear that will be returned}
begin
	{Error check. If N is less than 1, we can't process the}
	{request. There is no gear before the first, after all...}
	if N < 1 then N := 1;

	{Initialize values.}
	t := 0;
	it := Nil;

	{Process the list.}
	while (t <> N) and (Part <> Nil) do begin
		if NotDestroyed(PART) then begin
			it := Part;
			Inc(T);
		end;
		Part := Part^.Next;
	end;

	FindActiveGear := it;
end;


Function CountUpSibs(Part: GearPtr; G,S,Scale: Integer): Integer;
	{Count up the number of "active points" in this line}
	{of sibling parts, recursing to find the number of APs}
	{in all child parts.}
var
	CD,MD,it: Integer;
begin
	{Initialize our count to 0.}
	it := 0;

	{Scan through all parts in the line.}
	while Part <> Nil do begin
		{Check to see if this part matches our description.}
		{We are only concerned about parts which have not}
		{yet been destroyed.}
		if NotDestroyed(Part) then begin
			if (Part^.G = G) and (Part^.S = S) and (Part^.Scale >= Scale) then begin
				{Calculate the max damage of this part.}
				MD := GearMaxDamage(Part);

				if MD > 0 then begin
					CD := GearCurrentDamage(Part);
					it := it + ( Part^.V * CD + MD - 1 ) div MD;
				end else begin
					it := it + 1;
				end;

			end;

			{Check the subcomponents.}
			if Part^.SubCom <> Nil then it := it + CountUpSibs(Part^.SubCom,G,S,Scale);
			if Part^.InvCom <> Nil then it := it + CountUpSibs(Part^.InvCom,G,S,Scale);

		end; { IF NOTDESTROYED }

		Part := Part^.Next;
	end;

	CountUpSibs := it;
end;

Function CountActivePoints(Master: GearPtr; G,S: Integer): Integer;
	{Count up the number of "active points" worth of components}
	{which may be described by G,S. In MZ, one frequenly has to}
	{count the number of spaces worth of legs/wheels/thrusters/etc.}
	{This is sorta the same thing- it counts up the number of}
	{hits, then divides that by the scaling factor, rounding up.}
begin
	CountActivePoints := CountUpSibs( Master^.SubCom , G , S , Master^.Scale );
end;

Function CountTheBits(Part: GearPtr; G,S,Scale: Integer): Integer;
	{Count up the number of nondestroyed parts which correspond}
	{to description G,S.}
var
	it: Integer;
begin
	{Initialize our count to 0.}
	it := 0;

	{Scan through all parts in the line.}
	while Part <> Nil do begin
		{Check to see if this part matches our description.}
		{We are only concerned about parts which have not}
		{yet been destroyed.}
		if NotDestroyed(Part) then begin
			if (Part^.G = G) and (Part^.S = S) and (Part^.Scale >= Scale) then Inc(it);

			{Check the subcomponents.}
			if Part^.SubCom <> Nil then it := it + CountTheBits(Part^.SubCom,G,S,Scale);
			if Part^.InvCom <> Nil then it := it + CountTheBits(Part^.InvCom,G,S,Scale);
		end;

		Part := Part^.Next;
	end;

	CountTheBits := it;
end;

Function CountActiveParts(Master: GearPtr; G,S: Integer): Integer;
	{Count the number of nondestroyed components which correspond}
	{to description G,S.}
begin
	CountActiveParts := CountTheBits( Master^.SubCom , G , S , Master^.Scale );
end;

Function CountTotalBits(Part: GearPtr; G,S,Scale: Integer): Integer;
	{Count up the number of parts which correspond}
	{to description G,S.}
var
	it: Integer;
begin
	{Initialize our count to 0.}
	it := 0;

	{Scan through all parts in the line.}
	while Part <> Nil do begin
		{Check to see if this part matches our description.}
		if (Part^.G = G) and (Part^.S = S) and (Part^.Scale >= Scale) then begin
			Inc(it);

			{Check the subcomponents.}
			if Part^.SubCom <> Nil then it := it + CountTotalBits(Part^.SubCom,G,S,Scale);
			if Part^.InvCom <> Nil then it := it + CountTotalBits(Part^.InvCom,G,S,Scale);
		end;

		Part := Part^.Next;
	end;

	CountTotalBits := it;
end;

Function CountTotalParts(Master: GearPtr; G,S: Integer): Integer;
	{Count the number of components which correspond}
	{to description G,S.}
begin
	CountTotalParts := CountTotalBits( Master^.SubCom , G , S , Master^.Scale );
end;

Function SeekActiveIntrinsic( Master: GearPtr; G,S: Integer ): GearPtr;
	{ Search through all the subcoms and equipment of MASTER and }
	{ find a part which matches G,S. If more than one applicable }
	{ part is found, return the part with the highest V field. }
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
		else begin
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
			if NotDestroyed( P ) then begin
				if ( P^.G = G ) and ( P^.S = S ) then begin
					it := CompGears( it , P );
				end;
				if ( GG_Cockpit = P^.G ) then begin
					{ Don't add parts beyond the cockpit barrier. }
					it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
				end else begin
					it := CompGears( SeekPartAlongTrack( P^.SubCom ) , it );
					it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
				end;
			end;
			P := P^.Next;
		end;
		SeekPartAlongTrack := it;
	end;

begin
	{ Note that this procedure does not check the general inventory. }
	SeekActiveIntrinsic := SeekPartAlongTrack( Master^.SubCom );
end;

Function SeekNDPart( Master: GearPtr; G,S: Integer ): GearPtr;
	{ Locate a component matching G,S. The component must be working, }
	{ but otherwise can be located anywhere in the PART tree. }
	{ This procedure doesn't even care about scale... We just want }
	{ the largest example of the part we're after. }
	Function CompGears( P1,P2: GearPtr ): GearPtr;
		{ Given two gears, P1 and P2, return the gear with }
		{ the higest V field. }
	var
		it: GearPtr;
	begin
		it := Nil;
		if P1 = Nil then it := P2
		else if P2 = Nil then it := P1
		else begin
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
			if NotDestroyed( P ) then begin
				if ( P^.G = G ) and ( P^.S = S ) then begin
					it := CompGears( it , P );
				end;
				it := CompGears( SeekPartAlongTrack( P^.SubCom ) , it );
				it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
			end;
			P := P^.Next;
		end;
		SeekPartAlongTrack := it;
	end;
	
begin
	SeekNDPart := CompGears( SeekPartAlongTrack( Master^.SubCom ) , SeekPartAlongTrack( Master^.InvCom ) );
end;

Function OverloadCapacity( Mek: GearPtr ): Integer;
	{ Return the amount of energy this mecha can safely drain without }
	{ suffering an overload penalty. }
begin
	OverloadCapacity := Mek^.V * 10;
end;

Function MechaManeuver( Mek: GearPtr ): Integer;
	{ Check out a mecha-type gear and determine its }
	{ maneuverability class, adjusted for damage. }
var
	MV,OL: Integer;
	Gyro: GearPtr;
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	MV := FormMVBonus[ Mek^.S ] + BaseMVTVScore( Mek );

	{ Modify for the gyroscope and sensor package. }
	if SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor ) = Nil then MV := MV - MVSensorPenalty;
	Gyro := SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro );
	if Gyro = Nil then MV := MV - MVGyroPenalty
	else MV := MV + Gyro^.V - 1;

	{ Add the penalty for engine overload. }
	OL := NAttValue( Mek^.NA , NAG_Condition , NAS_Overload ) - OverloadCapacity( Mek );
	if OL > 14 then begin
		MV := MV - ( ( OL - 5 ) div 10 );
	end;

	{ Up to this point, no modifiers should take MV above 0. }
	if MV > 0 then MV := 0;

	{ Biotech mecha get a +1 to MV and TR. }
	if NAttValue( Mek^.NA , NAG_GearOps , NAS_Material ) = NAV_BioTech then Inc( MV );

	MechaManeuver := MV;
end;

Function MechaTargeting( Mek: GearPtr ): Integer;
	{ Check out a mecha-type gear and determine its }
	{ targeting class, adjusted for damage. }
var
	TR,OL: Integer;
	TarCom: GearPtr;	{ Targeting Computer }
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	TR := FormTRBonus[ Mek^.S ] + BaseMVTVScore( Mek );

	TarCom := SeekActiveIntrinsic( Mek , GG_Sensor , GS_TarCom );
	if TarCom <> Nil then TR := TR + TarCom^.V;

	{ Modify for sensors, or lack thereof. }
	if SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor ) = Nil then TR := TR - TRSensorPenalty;

	{ Add the penalty for engine overload. }
	OL := NAttValue( Mek^.NA , NAG_Condition , NAS_Overload ) - OverloadCapacity( Mek );
	if OL > 9 then begin
		TR := TR - ( OL div 10 );
	end;

	{ Up to this point, no modifiers should take TR above 0. }
	if TR > 0 then TR := 0;

	{ Biotech mecha get a +1 to MV and TR. }
	if NAttValue( Mek^.NA , NAG_GearOps , NAS_Material ) = NAV_BioTech then Inc( TR );

	MechaTargeting := TR;
end;

Function MechaSensorRating( Mek: GearPtr ): Integer;
	{ Calculate the sensor rating for this mecha. }
var
	SR: Integer;
	Sens: GearPtr;
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	{ Locate the sensor package. }
	Sens := SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor );

	if Sens = Nil then SR := -8
	else begin
		SR := Sens^.V - 7;

		{ If the sensors are mounted in a Head module, +3 bonus. }
		{ This bonus only applies to forms which are allowed to }
		{ have heads- so, if you had a transforming battroid/tank, }
		{ the sensors would always work but the +3 bonus would only }
		{ apply in battroid form. }
		if InGoodModule( Sens ) then begin
			Sens := FindModule( Sens );
			if ( Sens <> Nil ) and ( Sens^.S = GS_Head ) then SR := SR + 3;
		end;
	end;

	MechaSensorRating := SR;
end;

Function MechaStealthRating( Mek: GearPtr ): Integer;
	{ Calculate the stealth rating for this mecha. This will be }
	{ the target number to beat when trying to spot the mecha. }
var
	SR: Integer;
begin
	if Mek = Nil then begin
		SR := 0;
	end else if Mek^.G = GG_Character then begin
		SR := 25 - Mek^.Stat[ STAT_Body ];
	end else if Mek^.G = GG_Mecha then begin
		SR := 16 - Mek^.V;
	end else SR := 12;
	if SR < 5 then SR := 5;
	MechaStealthRating := SR;
end;

Function PCommRating( Master: GearPtr ): Integer;
	{ Return the rating of the master's personal communications rating. }
var
	it: GearPtr;
begin
	it := SeekNDPart( Master , GG_Electronics , GS_PCS );
	if it = Nil then begin
		PCommRating := 0;
	end else begin
		PCommRating := it^.V;
	end;
end;

Function LocateGoodAmmo( Weapon: GearPtr ): GearPtr;
	{ Locate the first block of usable ammunition for the weapon listed. }
	{ In order to be usable, it must: Fail the NotGoodAmmo function, and }
	{ also it must not be destroyed. }
	{ If no good ammo exists, this function returns NIL. }
var
	Ammo,GAmmo: GearPtr;
begin
	Ammo := Weapon^.SubCom;
	GAmmo := Nil;
	while ( Ammo <> Nil ) and ( GAmmo = Nil ) do begin
		if NotDestroyed( Ammo ) and not (NotGoodAmmo(Weapon,Ammo)) then begin
			GAmmo := Ammo;
		end;
		ammo := ammo^.Next;
	end;
	LocateGoodAmmo := GAmmo;
end;

Function WeaponAttackAttributes( Attacker: GearPtr ): String;
	{ Return the attack type for this particular attack. }
var
	it: String;
	ammo: GearPtr;
begin
	{ Error check. }
	if Attacker = Nil then Exit( '' );

	{ Grab the TYPE SAtt from the weapon itself. }
	it := SAttValue( Attacker^.SA , 'TYPE' );

	{ If appropriate, grab the TYPE from its ammo as well. }
	if Attacker^.G = GG_Weapon then begin
		if ( Attacker^.S = GS_Ballistic ) or ( Attacker^.S = GS_Missile ) then begin
			Ammo := LocateGoodAmmo( Attacker );
			if Ammo <> Nil then begin
				it := SAttValue( Ammo^.SA , 'TYPE' ) + ' ' + it;
			end;
		end;
	end;

	{ Add the TYPE from the weapon add-ons. }
	Ammo := Attacker^.InvCom;
	while Ammo <> Nil do begin
		if ( Ammo^.G = GG_WeaponAddOn ) and NotDestroyed( Ammo ) then begin
			it := SAttValue( Ammo^.SA , 'TYPE' ) + ' ' + it;
		end;

		Ammo := Ammo^.Next;
	end;

	WeaponAttackAttributes := it;
end;

Function HasAttackAttribute( AtAt: String; N: Integer ): Boolean;
	{ Return TRUE if the listed attack attribute is posessed by }
	{ this weapon, or FALSE otherwise. }
begin
	if ( N < 1 ) or ( N > Num_Attack_Attributes ) then Exit( False );
	HasAttackAttribute := AStringHasBString( AtAt , AA_Name[ N ] );
end;

Function HasAreaEffect( AtAt: String ): Boolean;
	{ Return TRUE if the provided attack attributes will result }
	{ in an area effect attack, or FALSE otherwise. }
begin
	HasAreaEffect := AStringHasBString( ATAt , AA_Name[AA_BlastAttack] ) or AStringHasBString( ATAt , AA_Name[AA_LineAttack] ) or AStringHasBString( ATAt , AA_Name[AA_Scatter] );
end;

Function HasAreaEffect( Attacker: GearPtr ): Boolean;
	{ Return TRUE if the listed weapon is of an area effect type, }
	{ or FALSE otherwise. }
begin
	HasAreaEffect := HasAreaEffect( WeaponAttackAttributes( Attacker ) );
end;

Function NonDamagingAttack( AtAt: String ): Boolean;
	{ Return TRUE if the Attacker is a non-damaging attack. }
begin
	NonDamagingAttack := HasAttackAttribute( AtAt, AA_Smoke ) or HasAttackAttribute( AtAt , AA_Gas ) or HasAttackAttribute( AtAt , AA_Drone );
end;

Function NoCalledShots( AtAt: String; AtOp: Integer ): Boolean;
	{ Return TRUE if the weapon in question, using the requested }
	{ attack option value, is incapable of making a called shot. }
begin
	if ( AtOp > 0 ) or AStringHasBString( AtAt , AA_Name[AA_SwarmAttack] ) or AStringHasBString( AtAt , AA_Name[AA_Hyper] ) or HasAreaEffect( AtAt ) then begin
		NoCalledShots := True;
	end else begin
		NoCalledShots := False;
	end;
end;

Function AmmoRemaining( Weapon: GearPtr ): Integer;
	{ Determine how many shots this weapon has remaining. }
var
	Ammo: GearPtr;
begin
	{ Error Check- make sure this is actually a weapon. }
	if ( Weapon = Nil ) or ( Weapon^.G <> GG_Weapon ) then Exit( 0 );

	{ Find the ammo gear, if one exists. }
	Ammo := LocateGoodAmmo( Weapon );
	if Ammo = Nil then Exit( 0 );

	{ Return the number of shots left. }
	AmmoRemaining := Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent );
end;


Function ScaleRange( Rng,Scale: Integer ): Integer;
	{ Provide a universal range measurement. }
begin
	while Scale > 0 do begin
		Rng := Rng * 2;
		Dec( Scale );
	end;
	ScaleRange := Rng;
end;

Function BasicWeaponDesc( Weapon: GearPtr ): String;
	{Supply a default name for this particular weapon.}
begin
	{Convert the size of the weapon to a string.}
	if Weapon^.G = GG_Weapon then begin
		BasicWeaponDesc := DCName( WeaponDC( Weapon , 0 ) , Weapon^.Scale ) + ' ' + I18N_Name('DefaultWeaponName',DefaultWeaponName[Weapon^.S]);
	end else begin
		BasicWeaponDesc := DCName( WeaponDC( Weapon , 0 ) , Weapon^.Scale );
	end;
end;

Function WeaponDescription( Weapon: GearPtr ): String;
	{ Create a description for this weapon. }
var
	Master: GearPtr;
	desc,AA: String;
	T: Integer;
begin
	{ Take the default name for the weapon from the WeaponName }
	{ function in ghweapon. }
	desc := BasicWeaponDesc( Weapon );

	if Weapon^.G = GG_Weapon then begin
		Master := FindMaster( Weapon );
		if Master <> Nil then begin
			if Master^.Scale <> Weapon^.Scale then begin
				desc := desc + ' SF:' + BStr( Weapon^.Scale );
			end;
		end else if Weapon^.Scale > 0 then begin
			desc := desc + ' SF:' + BStr( Weapon^.Scale );
		end;

		AA := WeaponAttackAttributes( Weapon );

		if (Weapon^.S = GS_Ballistic) or (Weapon^.S = GS_BeamGun) or (Weapon^.S = GS_Missile) then begin
			T := ScaleRange( Weapon^.Stat[STAT_Range] , Weapon^.Scale );
			if HasAttackAttribute( AA , AA_LineAttack ) then begin
				desc := desc + ' RNG:' + BStr( T ) + '-' + BStr( T * 2 );
			end else begin
				desc := desc + ' RNG:' + BStr( T ) + '-' + BStr( T * 2 ) + '-' + BStr( T * 3 );
			end;
		end else if HasAttackAttribute( AA , AA_Extended ) then begin
			desc := desc + ' RNG:' + BStr( ScaleRange( 2 , Weapon^.Scale ) );
		end;

		if Weapon^.Stat[STAT_Accuracy] > -1 then begin
			desc := desc + ' ACC:+' + BStr( Weapon^.Stat[STAT_Accuracy] );
		end else begin
			desc := desc + ' ACC:' + BStr( Weapon^.Stat[STAT_Accuracy] );
		end;

		desc := desc + ' SPD:' + BStr( Weapon^.Stat[STAT_Recharge] );

		if (Weapon^.S = GS_Ballistic) or (Weapon^.S = GS_BeamGun) then begin
			if Weapon^.Stat[ STAT_BurstValue ] > 0 then desc := desc + ' BV:' + BStr( Weapon^.Stat[ STAT_BurstValue ] + 1 );
		end;

		if (Weapon^.S = GS_Ballistic) or (Weapon^.S = GS_Missile) then begin
			desc := desc + ' ' + BStr( AmmoRemaining( Weapon ) ) + '/' + BStr( Weapon^.Stat[ STAT_Magazine] ) + 'a';
		end;

		if HasAttackAttribute( AA , AA_Mystery ) then begin
			desc := desc + ' ???';
		end else begin
			if AA <> '' then begin
				desc := desc + ' ' + UpCase( AA );
			end;
		end;

	end else if Weapon^.G = GG_Ammo then begin
		AA := WeaponAttackAttributes( Weapon );

		if Weapon^.S = GS_Grenade then begin
			desc := desc + ' RNG:T';

			if Weapon^.Stat[ STAT_BurstValue ] > 0 then desc := desc + ' BV:' + BStr( Weapon^.Stat[ STAT_BurstValue ] + 1 );
		end;

		desc := desc + ' ' + BStr( Weapon^.Stat[STAT_AmmoPresent] - NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) + '/' + BStr( Weapon^.Stat[ STAT_AmmoPresent] ) + 'a';

		if HasAttackAttribute( AA , AA_Mystery ) then begin
			desc := desc + ' ???';
		end else begin
			if AA <> '' then begin
				desc := desc + ' ' + UpCase( AA );
			end;
		end;


	end;

	desc := desc + ' ARC:' + SAttValue( Damage_Strings , 'WEAPONINFO_ARC' + BStr( WeaponArc( Weapon ) ) );

	WeaponDescription := desc;
end;

Function WAODescription( Weapon: GearPtr ): String;
	{ Create a description for this weapon. }
var
	desc,AA: String;
begin
	{ Take the default name for the weapon from the WeaponName }
	{ function in ghweapon. }
	desc := SAttValue( Damage_Strings , 'WAO_' + BStr( Weapon^.S ) );

	if Weapon^.V <> 0 then desc := desc + ' DC:' + SgnStr( Weapon^.V );
	if Weapon^.Stat[ STAT_Range ] <> 0 then desc := desc + ' RNG:' + SgnStr( Weapon^.Stat[ STAT_Range ] );
	if Weapon^.Stat[ STAT_Accuracy ] <> 0 then desc := desc + ' ACC:' + SgnStr( Weapon^.Stat[ STAT_Accuracy ] );
	if Weapon^.Stat[ STAT_Recharge ] <> 0 then desc := desc + ' SPD:' + SgnStr( Weapon^.Stat[ STAT_Recharge ] );

	AA := WeaponAttackAttributes( Weapon );
	if HasAttackAttribute( AA , AA_Mystery ) then begin
		desc := desc + ' ???';
	end else if AA <> '' then begin
		desc := desc + ' ' + UpCase( AA );
	end;

	WAODescription := desc;
end;

Function PCSDescription( N: Integer ): String;
	{ Return a description of this PCS's capabilities. }
var
	it: String;
	T: Integer;
begin
	it := SAttValue( Damage_Strings , 'PCS_Fun1' );
	for t := 2 to N do begin
		it := it + SATtValue( Damage_Strings , 'PCS_Fun'+BStr( T ) );
	end;
	PCSDescription := it;
end;

Function MoveSysDescription( Part: GearPtr ): String;
	{ Return a description of the size/type of this movement }
	{ system. }
begin
	MoveSysDescription := SATtValue( Damage_Strings , 'MoveSys_Class' ) + ' ' + BStr( Part^.V ) + ' ' + MoveSysMan[ Part^.S ].Name;
end;

Function ModifierDescription( Part: GearPtr ): String;
	{ Return a description for this modifier gear. }
var
	it: String;
	T: Integer;
begin
	if Part^.S = GS_StatModifier then begin
		it := '';
		for t := 1 to NumGearStats do begin
			if Part^.Stat[ T ] <> 0 then begin
				if it <> '' then it := it + ', ';
				it := it + SgnStr( Part^.Stat[ T ] ) + ' ' + I18N_Name( 'StatName', StatName[ T ] );
			end;
		end;
	end else if Part^.S = GS_SkillModifier then begin
		if ( Part^.Stat[ STAT_SkillToModify ] >= 1 ) and ( Part^.Stat[ STAT_SkillToModify ] <= NumSkill ) then begin
			it := I18N_Name( 'SkillMan', SkillMan[ Part^.Stat[ STAT_SkillToModify ] ].Name );
		end else begin
			it := I18N_Name( 'SkillMan', 'Unknown Skill' );
		end;
		it := it + ' ' + SgnStr( Part^.Stat[ STAT_SkillModBonus ] );
	end;

	if Part^.V > 0 then begin
		if it <> '' then it := it + ', ';
		it := it + BStr( Part^.V ) + ' Trauma';
	end;
	if it <> '' then it := it + '.';
	ModifierDescription := it;
end;

Function ShieldDescription( Part: GearPtr ): String;
	{ Return a description of the size/type of this movement }
	{ system. }
begin
	ShieldDescription := SATtValue( Damage_Strings , 'Shield_Desc' ) + SgnStr( Part^.Stat[ STAT_ShieldBonus ] );
end;

Function UsableDescription( Part: GearPtr ): String;
	{ Return a description of the size/type of this movement }
	{ system. }
var
	msg: String;
begin
	msg := ReplaceHash( SATtValue( Damage_Strings , 'Usable_Desc' ) , BStr( Part^.Stat[ STAT_UseBonus ] ) );
	msg := ReplaceHash( msg , BStr( Part^.Stat[ STAT_UseRange ] ) );
	UsableDescription := msg;
end;

Function RepairFuelDescription( Part: GearPtr ): String;
	{ Return a description of the size/type of this movement }
	{ system. }
begin
	RepairFuelDescription := SkillMan[ Part^.S ].Name + ' ' + BStr( Part^.V ) + ' DP';
end;

Function IntrinsicsDescription( Part: GearPtr ): String;
	{ Return a list of all the intrinsics associated with this part. }
var
	T: Integer;
	it: String;
begin
	it := '';

	{ Start by adding the armor type, if appropriate. FM:not yet backported}
	{T := NAttValue( Part^.NA , NAG_GearOps , NAS_ArmorType );
	if T <> 0 then it := MsgString( 'ARMORTYPE_' + BStr( T ) );}

	{ We're only interested if the intrinsics are attached directly }
	{ to this part. }
	for t := 1 to NumIntrinsic do begin
		if NAttValue( Part^.NA , NAG_Intrinsic , T ) <> 0 then begin
			if it = '' then begin
				it := MsgString( 'INTRINSIC_' + BStr( T ) );
			end else begin
				it := it + ', ' + MsgString( 'INTRINSIC_' + BStr( T ) );
			end;
		end;
	end;

	IntrinsicsDescription := it;
end;

Function ExtendedDescription( Part: GearPtr ): String;
	{ Provide an extended description telling all about the }
	{ attributes of this particular item. }
var
	it,IntDesc: String;
	SC: GearPtr;
begin
	{ Error check first. }
	if Part = Nil then Exit( '' );

	{ Start examining the part. }
	it := '';
	if ( Part^.G = GG_Weapon ) then begin
		it := WeaponDescription( Part );
	end else if ( Part^.G = GG_Ammo ) then begin
		it := WeaponDescription( Part );
	end else if ( Part^.G = GG_Electronics ) and ( Part^.S = GS_PCS ) then begin
		it := PCSDescription( Part^.V );
	end else if Part^.G = GG_MoveSys then begin
		it := MoveSysDescription( Part );
	end else if Part^.G = GG_Modifier then begin
		it := ModifierDescription( Part );
	end else if Part^.G = GG_Usable then begin
		it := UsableDescription( Part );
    end else if Part^.G = GG_RepairFuel then begin
        it := RepairFuelDescription( Part );
	end else if Part^.G = GG_Shield then begin
		it := ShieldDescription( Part );

		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			it := it + ' ' + ExtendedDescription( SC );
			SC := SC^.Next;
		end;

	end else if Part^.G = GG_WeaponAddOn then begin
		it := WAODescription( Part );

		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			it := it + ' ' + ExtendedDescription( SC );
			SC := SC^.Next;
		end;

	end else if Part^.G = GG_Support then begin
		it := ReplaceHash( SAttValue( Damage_Strings , 'SupportDesc' ) , BStr( Part^.V ) );

	end else if Part^.G <> GG_Module then begin
		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			it := it + ' ' + ExtendedDescription( SC );
			SC := SC^.Next;
		end;
	end;

	IntDesc := IntrinsicsDescription( Part );
	if IntDesc <> '' then begin
		if it = '' then it := IntDesc
		else it := it + ', ' + IntDesc;
	end;
	
	ExtendedDescription := it;
end;

Procedure ApplyPerminantInjury( PC: GearPtr );
	{ The PC has been through a beating. Apply a perminant injury, and destroy }
	{ any relevant cyberware found. }
var
	Injury: Integer;
	SC,SC2: GearPtr;
begin
	Injury := Random( Num_Perm_Injuries ) + 1;
	SetNAtt( PC^.NA , NAG_StatusEffect , Perm_Injury_List[ Injury ] , -1 );

	SC := PC^.SubCom;
	while SC <> Nil do begin
		SC2 := SC^.Next;

		if UpCase( SAttValue( SC^.SA , SAtt_CyberSlot ) ) = Perm_Injury_Slot[ Injury ] then begin
			RemoveGear( PC^.SubCom , SC );
		end;

		SC := SC2;
	end;
end;

Procedure ApplyCyberware( PC,Cyber: GearPtr );
	{ A cybernetic item is being installed into the PC. This may heal a current }
	{ perminant injury. Yay! Check to see whether or not it will. }
var
	Slot: String;
	T: Integer;
begin
	Slot := UpCase( SAttValue( Cyber^.SA , SAtt_CyberSlot ) );
	for t := 1 to Num_Perm_Injuries do begin
		if Perm_Injury_Slot[ t ] = Slot then begin
			SetNAtt( PC^.NA , NAG_StatusEffect , Perm_Injury_List[ T ] , 0 );
		end;
	end;
end;

Function ListInfo( Part: GearPtr ): SAttPtr;
    { Create a list of strings telling all about this item. }
var
    MyInfo: SATtPtr;
begin
    MyInfo := Nil;

end;

initialization
	Damage_Strings := LoadStringList( Damage_Strings_File );

finalization
	DisposeSAtt( Damage_Strings );

end.
