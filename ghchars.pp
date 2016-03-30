unit ghchars;
	{This unit handles the constants, functions, and}
	{attributes associated with Character gears.}
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
	{ ******************************** }
	{ ***  CHARACTER  DEFINITIONS  *** }
	{ ******************************** }
	{ G = GG_Character }
	{ S = Undefined    }
	{ V = Threat Rating (used for wandering monsters and other encounters) }

uses gears;

Type
	SkillDesc = Record
		Name: String;
		Stat: Byte;
		MekSys: Byte;	{ Is this skill affected by a mecha stat modifier? }
		Usage: Byte;	{ How is this skill used? }
	end;

Const
	STAT_Reflexes	= 1;
	STAT_Body	= 2;
	STAT_Speed	= 3;
	STAT_Perception	= 4;
	STAT_Craft	= 5;
	STAT_Ego	= 6;
	STAT_Knowledge	= 7;
	STAT_Charm	= 8;

	NAG_StatImprovementLevel = 11;	{ Counts how many times a stat has been }
					{ improved through experience. }

	StatName: Array [1..NumGearStats] of String = (
		'Reflexes','Body','Speed','Perception',
		'Craft','Ego','Knowledge','Charm'
	);

	{ This is the normal maximum stat value in character creation. }
	NormalMaxStatValue = 14;

	{ Here are the Mecha System definitions for skills. }
	MS_Maneuver = 1;
	MS_Targeting = 2;
	MS_Sensor = 3;

	NAG_Skill = 1;
	{ S = Skill Name }
	{ V = Skill Rank }

	NAS_FreeSkillPoints = -1;
	NAS_FreeStatPoints = -2;


	NAG_CharDescription = 3;

	NAS_Gender = 0;
	NAV_Male = 0;
	NAV_Female = 1;
    NAV_Nonbinary = 2;
    NAV_Undefined = 3;

	GenderName: Array[0..1] of String = ( 'Male' , 'Female' );

	NAS_DAge = 1;	{ CharDescription/Delta age - Offset from 20. }

	NAS_CharType = 2;	{ Character type - PC or NPC. }
	NAV_CTPrimary = 0;	{ default value }
	NAV_CTLancemate = 1;	{ lancemate }

	{ CharDescription / Personality Traits }
	Num_Personality_Traits = 7;
	NAS_Heroic = -1;	{ CharDescription/ Heroic <-> Villanous }
	NAS_Lawful = -2;	{ CharDescription/ Lawful <-> Chaotic }
	NAS_Sociable = -3;	{ CharDescription/ Assertive <-> Shy }
	NAS_Easygoing = -4;	{ CharDescription/ Easygoing <-> Passionate }
	NAS_Cheerful = -5;	{ CharDescription/ Cheerful <-> Melancholy }
	NAS_Renowned = -6;	{ CharDescription/ Renowned <-> Hopeless }
	NAS_Pragmatic = -7;	{ CharDescription/ Pragmatic <-> Spiritual }


	PTraitName: Array [1..Num_Personality_Traits,1..2] of String = (
	(	'Heroic','Villainous'		),
	(	'Lawful','Chaotic'		),
	(	'Sociable','Shy'		),
	(	'Easygoing','Passionate'	),
	(	'Cheerful','Melancholy'		),
	(	'Renowned','Wangtta'		),
	(	'Pragmatic','Spiritual'		)
	);

	NAG_Experience = 4;

	NAS_TotalXP = 0;
	NAS_SpentXP = 1;
	NAS_Credits = 2;
	NAS_FacXP = 3;
	NAS_FacLevel = 4;
	NAS_Skill_XP_Base = 100;	{ For skill-specific XP awards. }
					{ S = 100 + Skill Index }

	NAG_Condition = 9;
	NAS_StaminaDown = 0;
	NAS_MentalDown = 1;
	NAS_Hunger = 2;
	NAS_MoraleDamage = 3;
	{ Overload affects mecha rather than characters, but it's }
	{ a condition so it's grouped in with these. }
	NAS_Overload = 4;
	NAS_CyberTrauma = 5;


	MORALE_HPRegen = 5;
	MORALE_RepSmall = 10;
	MORALE_RepBig = 30;

	FOOD_MORALE_FACTOR = 15;

	{ Hunger penalty is calibrated to start roughly twelve hours }
	{ after your last meal. }
	Hunger_Penalty_Starts = 70;

	{For now, all skills will be hardcoded into the game binary.}
	{At some point in time I may have them defined in an}
	{external text file, but since the application of these}
	{skills have to be hard coded I don't see why the data}
	{for them shouldn't be as well.}
	NumSkill = 41;

	USAGE_Repair = 1;
	USAGE_Clue = 2;
	USAGE_Performance = 3;	{ Gets its own type, since it's unique. }
	USAGE_Robotics = 4;	{ Ditto. }
	USAGE_DominateAnimal = 5;	{ Yet another unique skill. }
	USAGE_PickPockets = 6;		{ The same. }

	SkillMan: Array [1..NumSkill] of SkillDesc = (
		(	name: 'Mecha Gunnery';
			stat: STAT_Reflexes;
			meksys: MS_Targeting;
			Usage: 0			),
		(	name: 'Mecha Artillery';
			stat: STAT_Perception;
			meksys: MS_Targeting;
			Usage: 0			),
		(	name: 'Mecha Weapons';
			stat: STAT_Reflexes;
			meksys: MS_Maneuver;
			Usage: 0;			),
		(	name: 'Mecha Fighting';
			stat: STAT_Speed;
			meksys: MS_Maneuver;
			Usage: 0;			),
		(	name: 'Mecha Piloting';
			stat: STAT_Reflexes;
			meksys: MS_Maneuver;
			Usage: 0;			),

		(	name: 'Small Arms';
			stat: STAT_Reflexes;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Heavy Weapons';
			stat: STAT_Perception;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Armed Combat';
			stat: STAT_Reflexes;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Martial Arts';
			stat: STAT_Body;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Dodge';
			stat: STAT_Speed;
			meksys: 0;
			Usage: 0;			),

		(	name: 'Awareness';
			stat: STAT_Perception;
			meksys: MS_Sensor;
			Usage: 0;			),
		(	name: 'Initiative';
			stat: STAT_Speed;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Vitality';
			stat: STAT_Body;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Survival';
			stat: STAT_Craft;
			meksys: 0;
			Usage: USAGE_Clue;		),
		(	name: 'Mecha Repair';
			stat: STAT_Craft;
			meksys: 0;
			Usage: USAGE_Repair;		),

		(	name: 'Medicine';
			stat: STAT_Knowledge;
			meksys: 0;
			Usage: USAGE_Repair;		),
		(	name: 'Electronic Warfare';
			stat: STAT_Craft;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Spot Weakness';
			stat: STAT_Craft;
			meksys: MS_Sensor;
			Usage: 0;			),
		(	name: 'Conversation';
			stat: STAT_Charm;
			meksys: 0;
			Usage: 0;			),
		(	name: 'First Aid';
			stat: STAT_Craft;
			meksys: 0;
			Usage: USAGE_Repair;		),

		{ Skills 21 - 25 }
		(	name: 'Shopping';
			stat: STAT_Charm;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Bio Technology';
			stat: STAT_Knowledge;
			meksys: 0;
			Usage: USAGE_Repair;		),
		(	name: 'General Repair';
			stat: STAT_Craft;
			meksys: 0;
			Usage: USAGE_Repair;		),
		(	name: 'Cybertech';
			stat: STAT_Ego;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Stealth';
			stat: STAT_Speed;
			meksys: MS_Maneuver;
			Usage: 0;			),

		{ Skills 26 - 30 }
		(	name: 'Athletics';
			stat: STAT_Body;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Flirtation';
			stat: STAT_Charm;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Intimidation';
			stat: STAT_Ego;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Science';
			stat: STAT_Knowledge;
			meksys: 0;
			Usage: USAGE_Clue;		),
		(	name: 'Concentration';
			stat: STAT_Ego;
			meksys: 0;
			Usage: 0;			),

		{ Skills 31 - 35 }
		(	name: 'Mecha Engineering';
			stat: STAT_Knowledge;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Code Breaking';
			stat: STAT_Craft;
			meksys: 0;
			Usage: USAGE_Clue;		),
		(	name: 'Weight Lifting';
			stat: STAT_Body;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Mysticism';
			stat: STAT_Ego;
			meksys: 0;
			Usage: USAGE_Clue;		),
		(	name: 'Performance';
			stat: STAT_Charm;
			meksys: 0;
			Usage: USAGE_Performance;	),

		{ Skills 36 - 40 }
		(	name: 'Resistance';
			stat: STAT_Ego;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Investigation';
			stat: STAT_Perception;
			meksys: 0;
			Usage: USAGE_Clue;		),
		(	name: 'Robotics';
			stat: STAT_Knowledge;
			meksys: 0;
			Usage: USAGE_Robotics;		),
		(	name: 'Leadership';
			stat: STAT_Charm;
			meksys: 0;
			Usage: 0;			),
		(	name: 'Dominate Animal';
			stat: STAT_Ego;
			meksys: 0;
			Usage: USAGE_DominateAnimal;	),

		{ Skills 41 - 45 }
		(	name: 'Pick Pockets';
			stat: STAT_Craft;
			meksys: 0;
			Usage: USAGE_PickPockets;	)


	);

    NAS_Awareness = 11;
    NAS_Initiative = 12;
    NAS_Vitality = 13;
    NAS_MechaRepair = 15;
    NAS_ElectronicWarfare = 17;
    NAS_SpotWeakness = 18;
    NAS_Stealth = 25;
	NAS_WeightLifting = 33;
	NAS_Performance = 35;
	NAS_Resistance = 36;
	NAS_Investigation = 37;
	NAS_Leadership = 39;
	NAS_PickPockets = 41;

	NAG_Talent = 16;
	NumTalent = 28;

	NAS_StrengthOfFaith = 1;
	NAS_BodyBuilder = 2;
	NAS_ScientificMethod = 3;
	NAS_Presence = 4;
	NAS_KungFu = 5;
	NAS_HapKiDo = 6;
	NAS_Anatomist = 7;
	NAS_HardAsNails = 8;
	NAS_StuntDriving = 9;
	NAS_Savant = 10;
	NAS_Bishounen = 11;
	NAS_Diplomatic = 12;
	NAS_BornToFly = 13;
	NAS_SureFooted = 14;
	NAS_RoadHog = 15;
	NAS_Scavenger = 16;
	NAS_Idealist = 17;
	NAS_BusinessSense = 18;
	NAS_AnimalTrainer = 19;
	NAS_JackOfAll = 20;
	NAS_CombatMedic = 21;
	NAS_Rage = 22;
	NAS_Ninjitsu = 23;
	NAS_HullDown = 24;
	NAS_GateCrasher = 25;
	NAS_Extropian = 26;
	NAS_CyberPsycho = 27;
	NAS_Sniper = 28;

	{ Talent pre-requisites are described as follows: The first }
	{ coordinate lists the skill (if positive) or stat (if negative) }
	{ needed to gain the talent. The second coordinate lists the }
	{ minimum value required. If either coordinate is zero, this }
	{ talent has no pre-requisites. }
	{ NEW: Personality traits may be specified as -8 + Trait Number }
	TALENT_PreReq: Array [1..NumTalent,1..2] of Integer = (
	( 34 , 5 ) , ( 33 , 5 ) , ( 29 , 5 ) , ( 35 , 5 ), ( 9 , 5 ),
	( 9 , 5 ) , ( 16 , 5 ) , ( 36 , 5 ) , ( -3 , 15 ) , ( 0 , 0 ),
	( -8 , 15 ) , ( -6 , 15 ) , ( 5 , 5 ) , ( 5 , 5 ) , ( 5 , 5 ),
	( 15 , 5 ), ( 0 , 0 ), ( 21 , 5 ), ( 40 , 5 ), (-STAT_Craft,15),
	( 20 , 5 ), ( -13 , -25 ), ( 25 , 5 ), ( 17 , 5 ), ( -12 , -25 ),
	( 24 , 5 ), ( -2 , 15 ), ( 18 , 5 )
	);


Procedure InitChar(Part: GearPtr);
Function CharBaseDamage( PC: GearPtr; CBod: Integer ): Integer;
Function CharStamina( PC: GearPtr ): Integer;
Function CharMental( PC: GearPtr ): Integer;
Function CharCurrentStamina( PC: GearPtr ): Integer;
Function CharCurrentMental( PC: GearPtr ): Integer;

Function RandomName: String;
procedure RollStats( PC: GearPtr; Pts: Integer);
function RandomPilot( StatPoints , SkillRank: Integer ): GearPtr;
function RandomSoldier( StatPoints , SkillRank: Integer ): GearPtr;

Function NumberOfSkills( PC: GearPtr ): Integer;
Function NumberOfSkillSlots( PC: GearPtr ): Integer;
Function TooManySkillsPenalty( PC: GearPtr; N: Integer ): Integer;
Function SkillAdvCost( PC: GearPtr; CurrentLevel: Integer ): LongInt;

function IsLegalCharSub( SPC, Part: GearPtr ): Boolean;

Function PersonalityTraitDesc( Trait,Level: Integer ): String;
Function NPCTraitDesc( NPC: GearPtr ): String;

Function CanLearnTalent( PC: GearPtr; T: Integer ): Boolean;
Function NumFreeTalents( PC: GearPtr ): Integer;
Procedure ApplyTalent( PC: GearPtr; T: Integer );

implementation

uses texutil;

Procedure InitChar(Part: GearPtr);
	{PART is a newly created Character record.}
	{Initialize its stuff.}
begin
	{Default scale for a PC is 0.}
	Part^.Scale := 0;

	{ Default material for a PC is "meat". }
	SetNAtt( Part^.NA , NAG_GearOps , NAS_Material , NAV_Meat );
end;

Function CharBaseDamage( PC: GearPtr; CBod: Integer ): Integer;
	{Calculate the number of general HPs that a character}
	{can take.}
var
	HP: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);
	HP := ( CBod + 5 ) div 2;

	{ Add the Vitality skill. }
	HP := HP + NAttValue( PC^.NA , NAG_Skill , 13 );

	CharBaseDamage := HP;
end;

Function CharStamina( PC: GearPtr ): Integer;
	{Calculate the number of stamina points that a character has.}
var
	SP: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);

	{ basic stamina rating is equal to the average between BODY and EGO. }
	SP := ( PC^.Stat[ STAT_Body ] + PC^.Stat[ STAT_Ego ] + 5 ) div 2;

	{ Add the Athletics skill. }
	SP := SP + NAttValue( PC^.NA , NAG_Skill , 26 ) * 3;

	CharStamina := SP;
end;

Function CharMental( PC: GearPtr ): Integer;
	{Calculate the number of mental points that a character has.}
var
	MP: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);

	{ basic mental rating is equal to the average between }
	{ KNOWLEDGE and EGO. }
	MP := ( PC^.Stat[ STAT_Knowledge ] + PC^.Stat[ STAT_Ego ] + 5 ) div 2;

	{ Add the Concentration skill. }
	MP := MP + NAttValue( PC^.NA , NAG_Skill , 30 ) * 3;

	CharMental := MP;
end;

Function CharCurrentStamina( PC: GearPtr ): Integer;
	{ Return the current stamina value for this character. }
var
	it: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);

	it := CharStamina( PC ) - NAttValue( PC^.NA , NAG_Condition , NAS_StaminaDown );
	if it < 0 then it := 0;
	CharCurrentStamina := it;
end;

Function CharCurrentMental( PC: GearPtr ): Integer;
	{ Return the current mental value for this character. }
var
	it: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);

	it := CharMental( PC ) - NAttValue( PC^.NA , NAG_Condition , NAS_MentalDown );
	if it < 0 then it := 0;
	CharCurrentMental := it;
end;


Function RandomName: String;
	{Generate a random name for a character.}
Const
	NumSyllables = 120;
	SyllableList: Array [1..NumSyllables] of String [5] = (
		'Jo','Sep','Hew','It','Seo','Eun','Suk','Ki','Kang','Cho',
		'Ai','Bo','Ca','Des','El','Fas','Gun','Ho','Ia','Jes',
		'Kep','Lor','Mo','Nor','Ox','Pir','Qu','Ra','Sun','Ter',
		'Ub','Ba','Tyb','War','Bac','Yan','Zee','Es','Vis','Jang',
		'Vic','Tor','Et','Te','Ni','Mo','Bil','Con','Ly','Dam',
		'Cha','Ro','The','Bes','Ne','Ko','Kun','Ran','Ma','No',
		'Ten','Do','To','Me','Ja','Son','Love','Joy','Ken','Iki',
		'Han','Lu','Ke','Sky','Wal','Jen','Fer','Le','Ia','Chu',
		'Tek','Ubu','Roi','Har','Old','Pin','Ter','Red','Ex','Al',
		'Alt','Rod','Mia','How','Phi','Aft','Aus','Tin','Her','Ge',
		'Hawk','Eye','Ger','Ru','Od','Jin','Un','Hyo','Leo','Star',
		'Buck','Ers','Rog','Eva','Ova','Oni','Ami','Ga','Cyn','Mai'

	);

	NumVowels = 6;
	VowelList: Array [1..NumVowels] of String [2] = (
		'A','E','I','O','U','Y'
	);

	NumConsonants = 21;
	ConsonantList: Array [1..NumConsonants] of String [2] = (
		'B','C','D','F','G','H','J','K','L','M','N',
		'P','Q','R','S','T','V','W','X','Y','Z'
	);

	Function Syl: String;
	begin
		if Random(16) = 3 then
			Syl := VowelList[Random(NumVowels)+1]
		else if Random(20) = 2 then begin
			if Random(3) = 1 then
				Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] )
			else if Random(2) = 1 then
				Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] )
			else if Random(2) = 1 then
				Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] + ConsonantList[Random(NumConsonants)+1] )
			else
				Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] + VowelList[Random(NumVowels)+1] );
		end else
			Syl := SyllableList[Random(NumSyllables)+1];
	end;
var
	it: String;
begin
	{A basic name is two syllables stuck together.}
	if Random(100) <> 5 then
		it := Syl + LowerCase(Syl)
	else
		it := Syl;

	{Uncommon names may have 3 syllables.}
	if ( Random(8) > Length(it) ) then
		it := it + LowerCase(Syl)
	else if Random(30) = 1 then
		it := it + LowerCase(Syl);

	{Short names may have a second part. This isn't common.}
	if (Length(it) < 9) and (Random(16) = 7) then begin
		it := it + ' ' + Syl;
		if Random(3) <> 1 then it := it + LowerCase(Syl);
	end;

	{ Random chance of random anime designation. }
	if Random(1000) = 123 then it := it + ' - ' + ConsonantList[Random(21)+1];

	RandomName := it;
end;

procedure RollStats( PC: GearPtr; Pts: Integer);
	{ Randomly allocate PTS points to all of the character's }
	{ stats.  Advancing stats past maximum }
	{ rank takes two stat points per rank instead of one. }
	{ Hopefully, this will be clear once you read the implementation... }
var
	T: Integer;	{ A loop counter. }
	STemp: Array [1..NumGearStats] of Integer;
	{ I always name my loop counters T, in honor of the C64. }
begin
	{ Error Check - Is this a character!? }
	if ( PC = Nil ) or ( PC^.G <> GG_Character ) then Exit;

	{ Set all stat values to minimum. }
	if Pts >= NumGearStats then begin
		for t := 1 to NumGearStats do begin
			STemp[T] := 1;
		end;
		Pts := Pts - NumGearStats;
	end else begin
		for t := 1 to NumGearStats do begin
			STemp[T] := 0;
		end;
	end;

	{ Keep processing until we run out of stat points to allocate. }
	while Pts > 0 do begin
		{ T will now point to the stat slot to improve. }
		T := Random( NumGearStats ) + 1;

		{ If the stat selected is under the max value, }
		{ improve it. If it is at or above the max value, }
		{ there's a one in three chance of improving it. }
		if ( STemp[T] + PC^.Stat[ T ] ) < NormalMaxStatValue then begin
			Inc( STemp[T] );
			Dec( Pts );

		end else if Random(2) = 1 then begin
			Inc( STemp[T] );
			Pts := Pts - 2;

		end;
	end;

	{ Add the STemp values to the stat baseline. }
	for t := 1 to NumGearStats do PC^.Stat[t] := PC^.Stat[t] + STemp[t];
end;

function RandomPilot( StatPoints , SkillRank: Integer ): GearPtr;
	{ Create a totally random mecha pilot, presumably so that }
	{ the PC pilots will have someone to thwack. }
const
	NumNPCPilotSpecialties = 5;
	PS: Array [1..NumNPCPilotSpecialties] of Byte = (
		10,12,17,18,25
	);
var
	NPC: GearPtr;
	T: Integer;
begin
	{ Generate record. }
	NPC := NewGear( Nil );
	if NPC = Nil then Exit( Nil );
	InitChar( NPC );
	NPC^.G := GG_Character;

	{ Roll some stats for this character. }	
	RollStats( NPC , StatPoints );

	{ Set all mecha skills to equal SkillRank. }
	for t := 1 to 5 do begin
		SetNAtt( NPC^.NA , NAG_Skill , T , SkillRank );
	end;
	{ Add a specialty. }
	SetNAtt( NPC^.NA , NAG_Skill , PS[ Random( NumNPCPilotSpecialties ) + 1 ] , SkillRank );

	{ Generate a random name for the character. }
	SetSAtt( NPC^.SA , 'Name <'+RandomName+'>');

	{ Return a pointer to the character record. }
	RandomPilot := NPC;
end;

function RandomSoldier( StatPoints , SkillRank: Integer ): GearPtr;
	{ Create a totally random fighter, presumably so that }
	{ the PC fighters will have someone to thwack. }
var
	NPC: GearPtr;
	T: Integer;
begin
	{ Generate record. }
	NPC := NewGear( Nil );
	if NPC = Nil then Exit( Nil );
	InitChar( NPC );
	NPC^.G := GG_Character;

	{ Roll some stats for this character. }	
	RollStats( NPC , StatPoints );

	{ Set all mecha skills to equal SkillRank. }
	for t := 6 to 10 do begin
		SetNAtt( NPC^.NA , NAG_Skill , T , SkillRank );
	end;

	{ Generate a random name for the character. }
	SetSAtt( NPC^.SA , 'Name <'+RandomName+'>');

	{ Return a pointer to the character record. }
	RandomSoldier := NPC;
end;

Function NumberOfSkills( PC: GearPtr ): Integer;
	{ Return the number of skills this PC knows. }
var
	T,N: Integer;
begin
	N := 0;
	for t := 1 to NumSkill do begin
		if NAttValue( PC^.NA , NAG_Skill , T ) > 0 then Inc( N );
	end;
	NumberOfSkills := N;
end;

Function NumberOfSkillSlots( PC: GearPtr ): Integer;
	{ Return the number of skill slots this PC has. }
var
	N: Integer;
begin
	N := ( ( PC^.STat[ STAT_Knowledge ] * 6 ) div  5 + 5 );
	if NAttValue( PC^.NA , NAG_Talent , NAS_Savant ) <> 0 then N := N + 5;
	NumberOfSkillSlots := N;
end;

Function TooManySkillsPenalty( PC: GearPtr; N: Integer ): Integer;
	{ Return the % XP penalty that this character will suffer. }
begin
	N := N - NumberOfSkillSlots( PC );
	N := N * 10 - 5;
	if N < 0 then N := 0;
	TooManySkillsPenalty := N;
end;

Function SkillAdvCost( PC: GearPtr; CurrentLevel: Integer ): LongInt;
	{ Return the cost, in XP points, to improve this skill by }
	{ one level. }
const
	chart: Array [1..15] of LongInt = (
		100,100,200,300,400,
		500,800,1300,2100,3400,
		5500,8900,14400,23300,37700
	);
	SAC_MAX = 2147483647;
	SAC_MIN = -2147483648;
var
	SAC,N: LongInt;
	tmp: Int64;
begin
	{ The chart lists skill costs according to desired level, }
	{ not current level. So, modify things a bit. }
	Inc( CurrentLevel );

	{ Range check - after level 15, it all costs the same. }
	if CurrentLevel < 1 then CurrentLevel := 1;
	if CurrentLevel <= 15 then begin
		{ Base level advance cost is found in the chart. }
		SAC := chart[ CurrentLevel ];
	end else begin
		{ Base level advance cost is found in the chart. }
		SAC := chart[ 15 ] * ( ( CurrentLevel - 15 ) * ( CurrentLevel - 15 ) + 1 );
	end;

	{ May be adjusted upwards if PC has too many skills... }
	if ( PC <> Nil ) and ( PC^.G = GG_Character ) then begin
		N := TooManySkillsPenalty( PC , NumberOfSkills( PC ) );
		if N > 0 then begin
			tmp := Int64(SAC) * Int64( 100 + N );
			tmp := tmp div 100;
			if (SAC_MAX < tmp) then begin
				SAC := SAC_MAX;
			end else if (tmp < SAC_MIN) then begin
				SAC := SAC_MIN;
			end else begin
				SAC := tmp;
			end;
		end;
	end;

	SkillAdvCost := SAC;
end;

function IsLegalCharSub( SPC, Part: GearPtr ): Boolean;
	{ Return TRUE if the specified part can be a subcomponent of }
	{ SPC, false if it can't be. }
begin
	if ( Part^.G = GG_Module ) then IsLegalCharSub := True
	else if ( Part^.G = GG_Modifier ) then IsLegalCharSub := AStringHasBString( SAttValue( Part^.SA , 'TYPE' ) , 'CHARA' )
	else IsLegalCharSub := False;
end;

Function PersonalityTraitDesc( Trait,Level: Integer ): String;
	{ Return a string which describes the nature & intensity of this }
	{ personality trait. }
var
	msg: String;
begin
	if ( Level = 0 ) or ( Trait < 1 ) or ( Trait > Num_Personality_Traits ) then msg := ''
	else begin
		if Level > 0 then begin
			msg := PTraitName[ Trait , 1 ];
		end else begin
			msg := PTraitName[ Trait , 2 ];
		end;

		if Abs( Level ) < 25 then msg := 'Slightly ' + msg
		else if Abs( Level ) >= 75 then msg := 'Extremely ' + msg
		else if Abs( Level ) >= 50 then msg := 'Very ' + msg;
	end;
	PersonalityTraitDesc := msg;
end;

Function NPCTraitDesc( NPC: GearPtr ): String;
	{ Describe this NPC's characteristics. This function is used }
	{ for selecting characters for plots & stuff. }
	{ - Age ( Young < 20yo , Old > 40yo ) }
	{ - Gender ( Male, Female ) }
	{ - Personality Traits }
	{ - Exceptional Stats }
	{ - Job }
var
	it: String;
	T,V: Integer;
begin
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then begin
		NPCTraitDesc := '';
	end else begin
		it := 'SEX:' + GenderName[ NATtValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) ];

		T := NATtValue( NPC^.NA , NAG_CharDescription , NAS_Dage );
		if T < 0 then begin
			it := it + ' young';
		end else if T >= 20 then begin
			it := it + ' old';
		end;

		{ Add descriptors for character traits. }
		for t := 1 to Num_Personality_Traits do begin
			V := NAttValue( NPC^.NA , NAG_CHarDescription , -T );
			if V >= 10 then begin
				it := it + ' ' + PTraitName[ T , 1 ];
			end else if V <= -10 then begin
				it := it + ' ' + PTraitName[ T , 2 ];
			end;
		end;

		{ Add the job description. }
		it := it + ' ' + SAttValue( NPC^.SA , 'JOB' );

		{ Add a note if this NPC has a mecha. }
		if SATTValue( NPC^.SA , 'MECHA' ) <> '' then begin
			it := it + ' HASMECHA';
		end;

		{ Add descriptors for high stats. }
		for t := 1 to 8 do begin
			if NPC^.Stat[ T ] > 13 then it := it + ' ' + StatName[ T ];
		end;

		NPCTraitDesc := it;
	end;
end;

Function CanLearnTalent( PC: GearPtr; T: Integer ): Boolean;
	{ Return TRUE if the PC can learn this talent, or FALSE otherwise. }
begin
	{ The talent must be within the legal range in order to be }
	{ learned. }
	if ( T < 1 ) or ( T > NumTalent ) then begin
		CanLearnTalent := False;

	{ The PC can't learn the same talent twice. }
	end else if NAttValue( PC^.NA , NAG_Talent , T ) <> 0 then begin
		CanLearnTalent := False;

	end else if ( Talent_PreReq[ T , 1 ] = 0 ) or ( Talent_PreReq[ T , 2 ] = 0 ) then begin
		CanLearnTalent := True;

	end else if ( Talent_PreReq[ T , 1 ] > 0 ) then begin
		CanLearnTalent := NAttValue( PC^.NA , NAG_Skill , Talent_PreReq[ T , 1 ] ) >= Talent_PreReq[ T , 2 ];

	end else if ( Talent_PreReq[ T , 1 ] < -8 ) then begin
		if Talent_PreReq[ T , 2 ] < 0 then begin
			CanLearnTalent := NAttValue( PC^.NA , NAG_CharDescription , Talent_PreReq[ T , 1 ] + 8 ) <= Talent_PreReq[ T , 2 ];
		end else begin
			CanLearnTalent := NAttValue( PC^.NA , NAG_CharDescription , Talent_PreReq[ T , 1 ] + 8 ) >= Talent_PreReq[ T , 2 ];
		end;

	end else begin
		CanLearnTalent := PC^.Stat[ Abs( Talent_PreReq[ T , 1 ] ) ] >= Talent_PreReq[ T , 2 ];

	end;
end;

Function NumFreeTalents( PC: GearPtr ): Integer;
	{ Return the number of talents the PC can learn. }
var
	TP: NAttPtr;
	N: Integer;
	XP: LongInt;
begin
	{ Start by counting the number of talents the PC currently has. }
	TP := PC^.NA;
	N := 0;
	while TP <> Nil do begin
		if TP^.G = NAG_Talent then Inc( N );
		TP := TP^.Next;
	end;

	{ Subtract this from the total number of talents the PC can get, }
	{ based on Experience. }
	XP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP );
	if XP > 100000 then N := 5 - N
	else if XP > 60000 then N := 4 - N
	else if XP > 30000 then N := 3 - N
	else if XP > 10000 then N := 2 - N
	else N := 1 - N;

	NumFreeTalents := N;
end;

Procedure ApplyIdealism( PC: GearPtr );
	{ Apply a +1 modifier to three random stats. }
var
	T,T2,S: Integer;
	StatDeck: Array [1..NumGearStats] of Integer;
begin
	{ Start by shuffling the statdeck. }
	for t := 1 to NumGearStats do StatDeck[ t ] := T;
	for t := 1 to NumGearStats do begin
		S := Random( NumGearStats ) + 1;
		T2 := StatDeck[ t ];
		StatDeck[ t ] := StatDeck[ S ];
		StatDeck[ S ] := T2;
	end;

	{ Select the first three stats off the top of the deck. }
	for t := 1 to 3 do Inc( PC^.Stat[ StatDeck[ T ] ] );
end;

Procedure ApplyTalent( PC: GearPtr; T: Integer );
	{ Apply the listed talent to the PC, invoking any special effects }
	{ if needed. }
begin
	{ Start with an error check. }
	if ( T < 1 ) or ( T > NumTalent ) then Exit;

	{ Record the talent. }
	SetNAtt( PC^.NA , NAG_Talent , T , 1 );

	{ Depending on the talent, do various effects. }
	Case T of
		NAS_StrengthOfFaith:
			PC^.Stat[ STAT_Ego ] := PC^.Stat[ STAT_Ego ] + 2;
		NAS_BodyBuilder:
			PC^.Stat[ STAT_Body ] := PC^.Stat[ STAT_Body ] + 2;
		NAS_ScientificMethod:
			PC^.Stat[ STAT_Knowledge ] := PC^.Stat[ STAT_Knowledge ] + 2;
		NAS_Presence:
			PC^.Stat[ STAT_Charm ] := PC^.Stat[ STAT_Charm ] + 2;
		NAS_Idealist:
			ApplyIdealism( PC );
	end;
end;


end.
