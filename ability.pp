unit ability;
	{ This unit handles character and mecha abilities. }
	{ Mostly, it's used for obtaining and rolling skill }
	{ totals and stuff. }
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

uses gears,ghsensor;

const
	XPA_AttackHit = 2;
	XPA_PerMOS = 3;
	XPA_DestroyMaster = 45;
	XPA_DestroyThing = 1;
	XPA_AvoidAttack = 3;
	XPA_GoodRepairJob = 4;
	XPA_GoodChat = 1;
	XPA_SK_Critical = 2;
	XPA_SK_Basic = 1;	{ XP for just using a combat skill. }
	XPA_SK_UseRepair = 3;

	CHAT_EXPERIENCE_TARGET = 20;

	REPAIR_CritFailure = -1;
	REPAIR_Failure = 0;
	REPAIR_Success = 1;

	{ Even the slowest people will react at this base speed. }
	Minimum_Initiative = 6;

	NumRepairSkills = 6;
	RepairSkillIndex: Array [1..NumRepairSkills] of Integer = (
		15,16,20,22,23,24
	);


	{ PERSONAL COMMUNICATION CAPABILITIES }
	PCC_Memo = GV_Memo;	{ Can view adventure memos }
	PCC_EMail = GV_EMail;	{ Can receive emails from NPCs }
	PCC_Comm = GV_Comm;	{ Can receive communications from NPCs }
	PCC_News = GV_News;	{ Can view internet global news }

	Direct_Skill_Learning: Boolean = False;

var
	ABILITY_MESSAGES: SAttPtr;


Function LocatePilot( Mecha: GearPtr ): GearPtr;
Function GearOperational( Mek: GearPtr ): Boolean;
Function GearActive( Mek: GearPtr ): Boolean;
function SkillValue( Master: GearPtr; Skill: Integer ): Integer;
function ReactionTime( Master: GearPtr ): Integer;
function PilotName( Part: GearPtr ): String;

Procedure DoleExperience( Mek: GearPtr; XPV: LongInt );
Procedure DoleExperience( Mek,Target: GearPtr; XPV: LongInt );
Procedure DoleExperienceFromTarget( Mek,Target: GearPtr; XPV: LongInt );
Function DoleSkillExperience( Mek: GearPtr; Skill,XPV: LongInt ): Boolean;

Function RepairSkillNeeded( Part: GearPtr ): Integer;
Function PitFix( Part,Fixer: GearPtr ): Integer;

procedure ExpandCharacter( PC: GearPtr );

Function MappingRange( Mek: GearPtr; Scale: Integer ): Integer;
Procedure AddMoraleDMG( PC: GearPtr; M: Integer );
Procedure AddReputation( PC: GearPtr; R,V: Integer );
Procedure AddStaminaDown( PC: GearPtr; Strain: Integer );
Procedure AddMentalDown( PC: GearPtr; Strain: Integer );

Function CurrentMental( PC: GearPtr ): Integer;
Function CurrentStamina( PC: GearPtr ): Integer;

Function MechaDescription( Mek: GearPtr ): String;
Function HasPCommCapability( PC: GearPtr; C: Integer ): Boolean;
Function HasTalent( PC: GearPtr; T: Integer ): Boolean;

Function LancematePoints( PC: GearPtr ): Integer;

Function SkillRank( PC: GearPtr; Skill: Integer ): Integer;
Function HasSkill( PC: GearPtr; Skill: Integer ): Boolean;

implementation

uses damage,gearutil,ghchars,ghholder,ghmecha,ghmodule,ghsupport,movement,
     rpgdice,texutil;

Function LocatePilot( Mecha: GearPtr ): GearPtr;
	{ Locate the pilot of this mecha. If no pilot may be found, }
	{ return Nil. }
var
	CPit, Pilot: GearPtr;	{ Pointers to the Cockpit and Pilot }
begin
	{ Error Check - make sure we have a valid mecha here. }
	if ( Mecha = Nil ) then Exit( Nil );
	if not IsMasterGear( Mecha ) then Mecha := FindMaster( Mecha );

	if Mecha = Nil then begin
		Pilot := Nil;

	end else if Mecha^.G = GG_Character then begin
		{ Just return this character, since we can't find a mecha. }
		Pilot := Mecha;

	end else begin
		{ This is probably a mecha. }
		{ Locate the cockpit. If no cockpit may be found, return Nil. }
		CPit := SeekGear( Mecha , GG_Cockpit , 0 , False );
		if CPit = Nil then Exit( Nil );

		{ Locate the pilot. }
		Pilot := CPit^.SubCom;
		while ( Pilot <> Nil ) and ( Pilot^.G <> GG_Character ) do begin
			Pilot := Pilot^.Next;
		end;
	end;

	LocatePilot := Pilot;
end;

Function GearOperational( Mek: GearPtr ): Boolean;
	{ A gear is operational if it is capable of action. }
	{ Mecha need a pilot in order to be operational. }
	{ Other gears are operational if they aren't destroyed. }
var
	MO: Boolean;	{ This func used to be called MekOperational, so MO }
begin
	{ Error Check }
	if ( Mek = Nil ) then begin
		MO := False
	end else if Mek^.G = GG_Mecha then begin
		MO := NotDestroyed( Mek ) and NotDestroyed( LocatePilot( Mek ) );
	end else MO := NotDestroyed( Mek );

	GearOperational := MO;
end;

Function GearActive( Mek: GearPtr ): Boolean;
	{ ACTIVE means that a given gear is capable of self-controlled action. }
	{ Generally only master gears may be active. }
begin
	if Mek = Nil then GearActive := False
	else if Mek^.G = GG_Prop then GearActive := False
	else if IsMasterGear( Mek ) then GearActive := GearOperational( Mek )
	else GearActive := False;
end;

function SkillValue( Master: GearPtr; Skill: Integer ): Integer;
	{ Find MASTER's skill roll value. This is the }
	{ skill rank + the attribute value + any modifiers }
	{ that might apply (maneuver class, etc). }
var
	C: GearPtr;	{Ptr to the controling character / skill bank.}
	SkRk,StRk: Integer;	{Skill Rank, Stat Rank. }
	SkMod,Morale: Integer;		{Skill Roll Modifier. }
	it: Integer;
begin
	{ Error check- make sure that we're actually dealing }
	{ with a master gear and not a ham sandwich or anything. }
	if ( Master = Nil ) then Exit( 0 );
	if ( Master^.G <> GG_Unit ) and Not IsMasterGear( Master ) then Exit( 0 );

	{ Error check- make sure we have a valid skill number. }
	if (Skill < 1) or (Skill > NumSkill) then Exit( 0 );

	{ Skill Roll Modifier starts out at 0. }
	SkMod := 0;

	if Master^.G = GG_Character then begin
		{ Since this is a character, just grab the needed }
		{ ranks from the gear's stats and attributes. }
		SkRk := CharaSkillRank( Master , Skill) + ModifiersSkillBonus( Master , Skill );
		StRk := CStat( Master , SkillMan[Skill].stat );

		{ If the skill isn't known at all, there's a penalty. }
		if ( SkRk < 1 ) and ( NAttValue( Master^.NA , NAG_Talent , NAS_JackOfAll ) = 0 ) then SkMod := -2;
		C := Master;

		{ If this is a combat skill, check for RAGE. }
		if ( Skill <= 10 ) and ( NAttValue( Master^.NA , NAG_Talent , NAS_Rage ) <> 0 ) then begin
			Morale := NAttValue( Master^.NA , NAG_Condition , NAS_MoraleDamage );
			if Morale > 0 then begin
				SkRk := SkRk + Morale div 20;
			end else if Morale < -20 then begin
				SkRk := SkRk - 2;
			end;
		end;

	end else if Master^.G = GG_Unit then begin
		SkRk := 0;
		C := Master^.SubCom;

		{ This is how unit skills work. Look through all the }
		{ characters in the unit. Take the highest skill value }
		{ among them. Other characters with high skill contribute }
		{ a SkMod of +1 per 5 points of skill. }
		while C <> Nil do begin
			if IsMasterGear( C ) then begin
				StRk := SkillValue( C , Skill );
				if StRk > SkRk then SkRk := StRk;
				if StRk >= 5 then SkMod := SkMod + ( StRk div 5 );
			end;
			C := C^.Next;
		end;

		{ Stat Rank, for the purpose of a unit, is meaningless. }
		{ Get rid of it. }
		StRk := 0;
		C := Master;
	end else begin
		{ As of this implementation, mecha are assumed to }
		{ have a single pilot. This will change at some }
		{ point in time, but for now just locate the cockpit. }
		C := LocatePilot( Master );
		if C = Nil then Exit( 0 );

		SkRk := SkillValue( C , Skill) + ModifiersSkillBonus( Master , Skill );
		StRk := 0;

		if SkillMan[Skill].MekSys = MS_Maneuver then begin
			SkMod := SkMod + MechaManeuver( Master );
		end else if SkillMan[Skill].MekSys = MS_Targeting then begin
			SkMod := SkMod + MechaTargeting( Master );
		end else if SkillMan[Skill].MekSys = MS_Sensor then begin
			SkMod := SkMod + MechaSensorRating( Master );
		end;
	end;

	{ The final value equals the Skill Rank plus }
	{ stat rank plus skill roll modifier. }
	it := ( ( StRk + 2 ) div 3 ) + SkRk + SkMod;
	if it < 1 then it := 1;

	{ Last minute check- if the character is dead, they don't get }
	{ to roll dice. }
	if ( Master^.G <> GG_Unit ) and Destroyed( C ) then it := 0;

	SkillValue := it;
end;


function ReactionTime( Master: GearPtr ): Integer;
	{ Determine the reaction time for this character/mecha. }
var
	I,RT: Integer;
begin
	{ Determine the Initiative skill value for this character. }
	I := SkillValue( Master , 12 ) + 1;
	if I < Minimum_Initiative then I := Minimum_Initiative;
	RT := ( ClicksPerRound * 3 ) div I;
	if RT > ClicksPerRound then RT := ClicksPerRound
	else if RT < 2 then RT := 2;
	ReactionTime := RT;
end;

function PilotName( Part: GearPtr ): String;
	{ Locate the name of the pilot of this thing; }
	{ provide the best substitute if no controller can be found. }
var
	M: GearPtr;
	name: String;
begin
	M := Part;
	if not IsMasterGear( Part ) then M := FindMaster( Part );

	if M = Nil then begin
		if Part = Nil then name := 'Nothing'
		else name := GearName( Part );

	end else if M^.G = GG_Mecha then begin
		Part := LocatePilot( M );
		if Part = Nil then name := GearName( M )
		else name := GearName( Part );

	end else begin
		name := GearName( M );
	end;

	PilotName := Name;
end;

Procedure DoleExperience( Mek: GearPtr; XPV: LongInt );
	{ Give XPV experience points to whoever is behind the wheel of }
	{ master unit Mek. }
var
	P: GearPtr;	{ The pilot, in theory. }
begin
	P := LocatePilot( Mek );
	if P <> Nil then begin
		AddNAtt( P^.NA , NAG_Experience , NAS_TotalXP , XPV );
		if XPV > Random(25) then AddMoraleDmg( P , -1 );
	end;
end;

Procedure DoleExperience( Mek,Target: GearPtr; XPV: LongInt );
	{ Give XPV experience points to whoever is behind the wheel of }
	{ master unit Mek. Scale the experience points by the relative }
	{ values of Mek and Target. }
var
	MPV,TPV,MonPV: LongInt;	{ Mek PV, Target PV }
	XP2: Int64;
begin
	MPV := GearValue( Mek );
	if MPV < 1 then MPV := 1;
	if Target <> Nil then begin
		TPV := GearValue( Target );

		{ Monsters might benefit from an upward-adjusted TPV based on }
		{ their difficulcy rating. }
		if ( Target^.G = GG_Character ) and ( Target^.V > 0 ) then begin
			MonPV := Target^.V * Target^.V * 150 - Target^.V * 100;
			if MonPV > TPV then TPV := MonPV;
		end;
		XP2 := ( XPV * TPV * ( Target^.Scale + 1 ) ) div MPV;
		XPV := XP2;
	end;
	if XPV < 1 then XPV := 1;
	DoleExperience( Mek , XPV );
end;

Procedure DoleExperienceFromTarget( Mek,Target: GearPtr; XPV: LongInt );
	{ Give some experience from this target. This experience comes from the }
	{ experience pool all monsters have. }
	Function TargetMaxXP: Integer;
	begin
		if Target^.G = GG_Mecha then begin
			TargetMaxXP := 10 * Target^.V;
		end else if Target^.G = GG_Character then begin
			if Target^.V > 0 then begin
				TargetMaxXP := 2 * Target^.V;
			end else begin
				TargetMaxXP := 5;
			end;
		end else begin
			TargetMaxXP := 1;
		end;
	end;
begin
	if ( Target <> Nil ) then begin

	end else begin
		DoleExperience( Mek , XPV );
	end;
end;

Function DoleSkillExperience( Mek: GearPtr; Skill,XPV: LongInt ): Boolean;
	{ Give XPV experience points to whoever is behind the wheel of }
	{ master unit Mek. Apply these XP directly to SKILL. }
	{ Return TRUE if this results in a skill increase, or FALSE if not. }
var
	P: GearPtr;	{ The pilot, in theory. }
	SkLvl: Integer;
	it: Boolean;
begin
	P := LocatePilot( Mek );
	it := False;	{ Assume FALSE unless shown otherwise. }
	if P <> Nil then begin
		AddNAtt( P^.NA , NAG_Experience , NAS_Skill_XP_Base + Skill , XPV );

		{ Check to see if enough skill-specific XPs have been earned to advance the skill. }
		SkLvl := NAttValue( P^.NA , NAG_Skill , Skill );
		if ( NATTValue( P^.NA , NAG_Experience , NAS_Skill_XP_Base + Skill ) >= SkillAdvCost( Nil , SkLvl ) ) and ( ( NAttValue( P^.NA , NAG_Skill , Skill ) > 0 ) or Direct_Skill_Learning ) then begin
			{ Set IT to true, advance the skill, and decrease the }
			{ number of skill-specific XPs the character has. }
			it := True;
			AddNAtt( P^.NA , NAG_Experience , NAS_Skill_XP_Base + Skill , -SkillAdvCost( Nil , SkLvl ) );
			AddNAtt( P^.NA , NAG_Skill , Skill , 1 );
		end;
	end;

	{ Return the boolean value. }
	DoleSkillExperience := it;
end;

Function RepairSkillNeeded( Part: GearPtr ): Integer;
	{ Return the code number of the skill which is needed to fix PART. }
	{ The repair skills are:   }
	{     15. Mecha Tech       }
	{     16. Medicine         }
	{     20. First Aid        }
	{     22. Bio Tech         }
	{     23. General Repair   }
	{     24. Cyber Tech       }
var
	Master: GearPtr;
	Material,Skill: Integer;
begin
	{ Start by finding the master and material for this part. }
	Master := FindMaster( Part );
	Material := NAttValue( Part^.NA , NAG_GearOps , NAS_Material );

	if Material = NAV_BioTech then begin
		Skill := 22;
	end else if ( Master = Nil ) or ( Master^.G = GG_Mecha ) then begin
		{ If it's made of MEAT, use biotech. }
		if Material = NAV_Meat then begin
			Skill := 22;

		{ If it's made of METAL, use Basic Repair for human-scale }
		{ items and Mecha Tech for large scale items. }
		end else begin
			if Part^.Scale = 0 then Skill := 23
			else Skill := 15;
		end;

	end else if Master^.G = GG_Character then begin
		if Material = NAV_Metal then begin
			{ If this is a SubCom and its parent is MEAT, use Cybertech. }
			{ Otherwise use Basic Repair. }
			if IsSubCom( Part ) and ( NAttValue( Part^.Parent^.NA , NAG_GearOps , NAS_Material ) = NAV_Meat ) then Skill := 24
			else begin
				if Part^.Scale = 0 then Skill := 23
				else Skill := 15;
			end;

		end else begin
			{ If this is an inventory part, use BioTech. }
			{ If the part has been destroyed, this requires }
			{ the Medicine skill. Otherwise First Aid will do. }
			if IsInvCom( Part ) then Skill := 22
			else if Destroyed( Part ) then Skill := 16
			else Skill := 20;
		end;

	end else begin
		{ Apparently we don't know what this is, so }
		{ we'll just use MECHA TECH on it. }
		Skill := 15;
	end;

	RepairSkillNeeded := Skill;
end;

Function PitFix( Part,Fixer: GearPtr ): Integer;
	{ An attempt is being made to fix PART. }
var
	AD,SD: LongInt;		{ Armor Damage, Struct Damage }
	Cash,Cost: LongInt;
	Skill,SkRoll,MOS,AMOS: Integer;
begin
	AD := NAttValue( Part^.NA , NAG_Damage , NAS_ArmorDamage );
	SD := NAttValue( Part^.NA , NAG_Damage , NAS_StrucDamage );
	Cash := NAttValue( Fixer^.NA , NAG_Experience , NAS_Credits );
	MOS := 10;

	{ The exact skill to be used depends upon PART's parent }
	{ and type. }
	Skill := RepairSkillNeeded( Part );

	{ Find the value for the skill. }
	Skill := SkillValue( Fixer , Skill );

	if SD > 0 then begin
		{ If a roll to repair Structural Damage is not successful, }
		{ it may result in greater damage being done. }
		SkRoll := RollStep( Skill );
		MOS := SkRoll div 5 - 2;
		Cost := SD;

		{ Attempt to buy off failure. }
		if MOS > 6 then MOS := 6
		else if MOS < 1 then begin
			while ( MOS < 1 ) and ( Cash > 0 ) do begin
				Cash := Cash - Cost;
				Inc( MOS );
			end;
		end;

		if MOS > 0 then begin
			SetNAtt( Part^.NA , NAG_Damage , NAS_StrucDamage , 0 );
			if MOS > 1 then Cost := ( Cost * ( 6 - MOS ) ) div 5;
			Cash := Cash - Cost;
		end else if MOS < 0 then begin
			{ A critical failure results in more damage being done. }
			if NotDestroyed( Part ) then AddNAtt( Part^.NA , NAG_Damage , NAS_StrucDamage , Abs( MOS ) * SD );
		end;
	end;

	if AD > 0 then begin
		{ Armor damage costs money to repair, but if the roll }
		{ is critically failed there's no extra bad thing. It }
		{ just doesn't get done. }
		SkRoll := RollStep( Skill );
		AMOS := SkRoll div 5 - 2;
		Cost := AD div 3;

		{ Attempt to buy off failure. }
		if AMOS > 5 then AMOS := 5
		else if AMOS < 1 then begin
			while ( AMOS < 1 ) and ( Cash > 0 ) do begin
				Cash := Cash - Cost;
				Inc( AMOS );
			end;
		end;

		if AMOS > 0 then begin
			SetNAtt( Part^.NA , NAG_Damage , NAS_ArmorDamage , 0 );
			if AMOS > 1 then Cost := ( Cost * ( 6 - MOS ) ) div 5;
			Cash := Cash - Cost;
		end;
	end;

	if Cash < 0 then Cash := 0;
	SetNAtt( Fixer^.NA , NAG_Experience , NAS_Credits , Cash );

	PitFix := MOS;
end;

procedure ExpandCharacter( PC: GearPtr );
	{ Create a body for a currently disembodied character gear. }
var
	M,H: GearPtr;	{ Module , Hand }
{ PROCEDURES BLOCK }
	Procedure InsertLimb( N: Integer );
	begin
		M := AddGear( PC^.SubCom , PC );
		M^.G := GG_Module;
		M^.S := N;
		M^.V := MasterSize( M );
		InitGear( M );
	end;
begin
	if PC^.SubCom = Nil then begin
		InsertLimb( GS_Head );
		InsertLimb( GS_Body );
		H := AddGear( M^.InvCom , M );
		H^.G := GG_ExArmor;
		H^.S := GS_Body;
		SetSAtt( H^.SA , 'NAME <' + SATtValue( ABILITY_MESSAGES , 'EXPAND_Clothes' ) + '>' );
		InitGear( H );

		InsertLimb( GS_Arm );
		SetSAtt( M^.SA , 'NAME <' + SATtValue( ABILITY_MESSAGES , 'EXPAND_RightArm' ) + '>' );
		H := AddGear( M^.SubCom , M );
		H^.G := GG_Holder;
		H^.S := GS_Hand;
		SetSAtt( H^.SA , 'NAME <' + SATtValue( ABILITY_MESSAGES , 'EXPAND_RightHand' ) + '>' );
		InitGear( H );

		InsertLimb( GS_Arm );
		SetSAtt( M^.SA , 'NAME <' + SATtValue( ABILITY_MESSAGES , 'EXPAND_LeftArm' ) + '>' );
		H := AddGear( M^.SubCom , M );
		H^.G := GG_Holder;
		H^.S := GS_Hand;
		SetSAtt( H^.SA , 'NAME <' + SATtValue( ABILITY_MESSAGES , 'EXPAND_LeftHand' ) + '>' );
		InitGear( H );

		InsertLimb( GS_Leg );
		SetSAtt( M^.SA , 'NAME <' + SATtValue( ABILITY_MESSAGES , 'EXPAND_RightLeg' ) + '>' );
		InsertLimb( GS_Leg );
		SetSAtt( M^.SA , 'NAME <' + SATtValue( ABILITY_MESSAGES , 'EXPAND_LeftLeg' ) + '>' );
	end;
end;

Function MappingRange( Mek: GearPtr; Scale: Integer ): Integer;
	{ Determine how far this mek can see new map tiles. }
	{ This is determined by two things- first, the mek's sensor }
	{ rating, and secondly the pilot's Perception stat. }
var
	Sensor,Pilot: GearPtr;
	it,t: Integer;
begin
	it := 0;

	Sensor := SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor );
	if Sensor <> Nil then begin
		it := it + Sensor^.V;
	end;

	Pilot := LocatePilot( Mek );
	if Pilot <> Nil then begin
		it := it + ( Pilot^.Stat[ STAT_Perception ] div 3 );
	end;

	{ Adjust the mapping range for scale. }
	if Mek^.Scale > Scale then begin
		for t := ( Scale + 1 ) to Mek^.Scale do it := it * 2;
	end else if Mek^.Scale < ( Scale + 1 ) then begin
		for t := 1 to ( Scale - Mek^.Scale - 1 ) do it := it div 2;
		if it < 1 then it := 1;
	end;

	MappingRange := it;
end;

Procedure AddMoraleDMG( PC: GearPtr; M: Integer );
	{ Add some morale to the PC, keeping it withing the normal }
	{ range of +100 (miserable) to -100 (ecstatic). }
var
	CL: Integer;	{ Current Level }
begin
	if PC^.G <> GG_Character then PC := LocatePilot( PC );

	if ( PC <> Nil ) and ( PC^.G = GG_Character ) then begin
		CL := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );

		{ If it's positive morale damage and CL is negative, }
		{ make a RESISTANCE roll to avoid losing mood. }
		if ( M > 1 ) and ( CL < 0 ) then begin
			if RollStep( SkillValue( PC , 36 ) ) < ( M + 1 ) then begin
				CL := CL div 2;
			end;
		end;

		if Abs( CL + M ) > 100 then begin
			SetNATt( PC^.NA , NAG_Condition , NAS_MoraleDamage , 100 * Sgn( CL ) );
		end else begin
			SetNATt( PC^.NA , NAG_Condition , NAS_MoraleDamage , CL + M );
		end;
	end;
end;

Procedure AddReputation( PC: GearPtr; R,V: Integer );
	{ Add a certain amount to reputation R, keeping in mind that }
	{ the allowable range is -100..+100. }
var
	CL: Integer;	{ Current Level }
begin
	if PC^.G <> GG_Character then PC := LocatePilot( PC );

	if ( PC <> Nil ) and ( PC^.G = GG_Character ) then begin
		CL := NAttValue( PC^.NA , NAG_CHarDescription , -R );

		{ Increasing a favored reputation improves morale, }
		{ while decreasing a reputation abuses it. }
		if R = -NAS_Renowned then begin
			{ Gaining renown always improves mood, losing it always }
			{ abuses mood. }
			if V > 0 then begin
				AddMoraleDmg( PC , -MORALE_RepSmall );
			end else if V < 0 then begin
				AddMoraleDmg( PC , MORALE_RepSmall );
			end;
		end else if Sgn( CL ) = Sgn( V ) then begin
			if Abs( V ) = 1 then begin
				AddMoraleDmg( PC , -MORALE_RepSmall );
			end else begin
				AddMoraleDmg( PC , -MORALE_RepBig );
			end;
		end else if Sgn( CL ) = -Sgn( V ) then begin
			if Abs( V ) = 1 then begin
				AddMoraleDmg( PC , MORALE_RepSmall );
			end else begin
				AddMoraleDmg( PC , MORALE_RepBig );
			end;
		end;

		{ Any act of major villainy or comission of crimes }
		{ (greater than a -1 change)  will completely wipe }
		{ out any heroic or lawful reputation that }
		{ this character may have had. }
		if ( R <= 2 ) and ( V < -1 ) and ( CL > 0 ) then begin
			CL := 0;
		end;

		if Abs( CL + V ) > 100 then begin
			SetNATt( PC^.NA , NAG_CharDescription , -R , 100 * Sgn( CL ) );
		end else begin
			SetNATt( PC^.NA , NAG_CharDescription , -R , CL + V );
		end;
	end;
end;

Procedure AddStaminaDown( PC: GearPtr; Strain: Integer );
	{ Apply stamina drain to the PC. }
begin
	{ Begin with a battery of error checks. }
	if ( PC <> Nil ) and ( Strain > 0 ) then begin
		if PC^.G <> GG_Character then PC := LocatePilot( PC );
		if ( PC <> Nil ) then begin
			if ( CharCurrentStamina( PC ) > 0 ) then begin
				AddNAtt( PC^.NA , NAG_Condition , NAS_StaminaDown , Strain );

				{ Using SP trains athletics. }
				DoleSkillExperience( PC , 26 , Strain );
			end else begin
				AddMoraleDmg( PC , Strain );
			end;
		end;
	end;
end;

Procedure AddMentalDown( PC: GearPtr; Strain: Integer );
	{ Apply mental drain to the PC. }
begin
	{ Begin with a battery of error checks. }
	if ( PC <> Nil ) and ( Strain > 0 ) then begin
		if PC^.G <> GG_Character then PC := LocatePilot( PC );
		if ( PC <> Nil ) then begin
			if ( CharCurrentMental( PC ) > 0 ) then begin
				AddNAtt( PC^.NA , NAG_Condition , NAS_MentalDown , Strain );

				{ Using MP trains concentration. }
				DoleSkillExperience( PC , 30 , Strain );
			end else begin
				AddMoraleDMG( PC , Strain );
			end;
		end;
	end;
end;

Function CurrentMental( PC: GearPtr ): Integer;
	{ Return how many mental points this character currently has. }
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		CurrentMental := CharCurrentMental( PC );
	end else begin
		CurrentMental := 0;
	end;
end;

Function CurrentStamina( PC: GearPtr ): Integer;
	{ Return how many stamina points this character currently has. }
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		CurrentStamina := CharCurrentStamina( PC );
	end else begin
		CurrentStamina := 0;
	end;
end;

Function MechaDescription( Mek: GearPtr ): String;
	{ Return a text description of this mecha's technical points. }
var
	it,i2: String;
	MM,MMS: Integer;
	CanMove: Boolean;
	Engine: GearPtr;
begin
	if Mek^.G <> GG_Mecha then Exit( 'NOT A MECHA!' );

	it := MassString( Mek ) + ' ' + FormName[Mek^.S];
	it := it + ' ' + 'MV:' + SgnStr(MechaManeuver(Mek));
	it := it + ' ' + 'TR:' + SgnStr(MechaTargeting(Mek));
	it := it + ' ' + 'SE:' + SgnStr(MechaSensorRating(Mek));

	MM := CountActiveParts( Mek , GG_Holder , GS_Hand );
	if MM > 0 then begin
		it := it + ' ' + SAttValue( ABILITY_MESSAGES , 'MEKDESC_Hands' ) + ':' + BStr( MM );
	end;

	MM := CountActiveParts( Mek , GG_Holder , GS_Mount );
	if MM > 0 then begin
		it := it + ' ' + SAttValue( ABILITY_MESSAGES , 'MEKDESC_Mounts' ) + ':' + BStr( MM );
	end;

	CanMove := False;
	for MM := 1 to NumMoveMode do begin
		MMS := BaseMoveRate( Mek , MM );
		if MMS > 0 then begin
			CanMove := True;

			{ Add a description for this movemode. }
			if MM = MM_Fly then begin
				{ Check to see whether the mecha can }
				{ fly or just jump. }
				if JumpTime( Mek ) = 0 then begin
					it := it + ' ' + MoveModeName[ MM ] + ':' + BStr( MMS );
				end else begin
					it := it + ' ' + SAttValue( ABILITY_MESSAGES , 'MEKDESC_Jump' ) + ':' + BStr( JumpTime( Mek ) ) + 's';
				end;
			end else begin
				it := it + ' ' + MoveModeName[ MM ] + ':' + BStr( MMS );
			end;
		end;
	end;

	Engine := SeekGear( Mek , GG_Support , GS_Engine );
	if Engine <> Nil then begin
		i2 := SAttValue( ABILITY_MESSAGES , 'MEKDESC_ENGINE' + Bstr( Engine^.Stat[ STAT_EngineSubtype ] ) );
		if i2 <> '' then it := it + ' ' + i2;
	end;

	{ Add warnings for different conditions. }
	if not CanMove then begin
		it := it + ' ' + SAttValue( ABILITY_MESSAGES , 'MEKDESC_Immobile' );
	end;
	if Destroyed( Mek ) then begin
		it := it + ' ' + SAttValue( ABILITY_MESSAGES , 'MEKDESC_Destroyed' );
	end;
	if SeekGear(mek,GG_CockPit,0) = Nil then begin
		it := it + ' ' + SAttValue( ABILITY_MESSAGES , 'MEKDESC_NoCockpit' );
	end;

	MechaDescription := it;
end;

Function HasPCommCapability( PC: GearPtr; C: Integer ): Boolean;
	{ Return TRUE if the listed PC has the requested Personal }
	{ Communications Capability. }
begin
	HasPCommCapability := PCommRating( PC ) >= C;
end;

Function HasTalent( PC: GearPtr; T: Integer ): Boolean;
	{ Return TRUE if PC has the listed talent, FALSE otherwise. }
begin
	PC := LocatePilot( PC );
	HasTalent := ( PC <> Nil ) and ( NAttValue( PC^.NA , NAG_Talent , T ) <> 0 );
end;

Function LancematePoints( PC: GearPtr ): Integer;
	{ Return however many lancemates the PC can have. }
	{ A human lancemate who can pilot a mecha costs 2 points; a pet costs 1 point. }
	{ How to tell which from which? Human lancemates have CIDs; pets don't. }
begin
	PC := LocatePilot( PC );
	if PC = Nil then Exit( 0 );
	LancematePoints := ( PC^.Stat[ STAT_Charm ] + NAttValue( PC^.NA , NAG_Skill , NAS_Leadership ) + ( NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned ) div 10 ) ) div 4;
end;

Function SkillRank( PC: GearPtr; Skill: Integer ): Integer;
	{ Return the PC's rank in this skill. }
var
	it: Integer;
begin
	{ Make sure we're dealing with the real PC here. }
	PC := LocatePilot( PC );
	SkillRank := CharaSkillRank( PC , Skill );
end;

Function HasSkill( PC: GearPtr; Skill: Integer ): Boolean;
	{ Return TRUE if the PC has the listed skill, or FALSE otherwise. }
begin
	{ Make sure we're dealing with the real PC here. }
	PC := LocatePilot( PC );

	if PC <> Nil then begin
		HasSkill := ( NAttValue( PC^.NA , NAG_Skill , Skill ) > 0 ) or HasTalent( PC , NAS_JackOfAll );
	end else begin
		HasSkill := False;
	end;
end;

initialization
	ABILITY_MESSAGES := LoadStringList( Ability_Message_File );

finalization
	DisposeSAtt( ABILITY_MESSAGES );

end.
