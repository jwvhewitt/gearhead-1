unit SkillUse;
	{ This unit should cover the usage of skills for the RPG game. }
	{ Actually, it doesn't cover the usage of all skills- most of }
	{ them get implemented in other places (combat skills in the }
	{ attacker unit, conversation skills in the interact unit, etc). }
	{ This unit covers those skills which pretty well need their }
	{ own interface/code... repair skills, picking pockets, etc. }
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

uses gears,locale;

const
	Repair_Mental_Strain = 1;
	Repair_Max_Tries = 5;

	Performance_Range = 9;
	Performance_Base_Cash = -50;

	TRIGGER_Applause = 'APPLAUSE';

	Num_Robot_Skill = 11;
	Robot_Skill: Array [1..Num_Robot_Skill] of Byte = (
		11,12,15,16,18,
		20,23,25,29,31,32
	);

Function TotalRepairableDamage( Target: GearPtr; Skill: Integer ): LongInt;
Procedure ApplyRepairPoints( Target: GearPtr; Skill: Integer; var RP: LongInt );
Function UseRepairSkill( GB: GameBoardPtr; PC,Target: GearPtr; Skill: Integer ): LongInt;

Function SeekBestInstrument( PC: GearPtr ): GearPtr;
Function UsePerformance( GB: GameBoardPtr; PC,Instrument: GearPtr ): LongInt;

Function UseRobotics( GB: GameBoardPtr; PC,Ingredients: GearPtr ): GearPtr;

implementation

{$IFDEF SDLMODE}
uses ability,action,damage,gearutil,ghchars,ghholder,ghmodule,ghmovers,ghswag,
     ghweapon,movement,interact,rpgdice,texutil,sdlgfx;
{$ELSE}
uses ability,action,damage,gearutil,ghchars,ghholder,ghmodule,ghmovers,ghswag,
     ghweapon,movement,interact,rpgdice,texutil;
{$ENDIF}

Function TotalRepairableDamage( Target: GearPtr; Skill: Integer ): LongInt;
	{ Search through TARGET, and calculate how much damage it has }
	{ that can be repaired using SKILL. }
var
	Part: GearPtr;
	AD,SD,TCom,SCom,it: LongInt;
	T: Integer;
begin
	{ Normally damage must be positive I know, but I just had a bug }
	{ which resulted in negative damage. This prevented the rest of }
	{ the damage to a mek/character from being repaired. So, taking }
	{ absolute value should fix all the mess & prevent it from }
	{ happening again. }
	SD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_StrucDamage ) );
	AD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_ArmorDamage ) );
	it := 0;

	{ If this part is damaged, and if the needed repair skill is }
	{ the skill we're looking for, add the damage to the total. }
	if RepairSkillNeeded( Target ) = Skill then begin
		it := AD + SD;

		{ Modify for complexity. }
		if not IsMasterGear( Target ) then begin
			TCom := ComponentComplexity( Target );
			SCom := SubComComplexity( Target );
			if SCom > TCom then begin
				it := ( it * SCom ) div TCom;
			end;
		end;
	end;

	{ Check for status effects. }
	for t := 1 to Num_Status_FX do begin
		if ( SX_RepSkill[t] = Skill ) and ( NAttValue( Target^.NA , NAG_StatusEffect , T ) <> 0 ) then begin
			it := it + SX_RepCost[ T ];
		end;
	end;

	{ Check the sub-components for damage. }
	Part := Target^.SubCom;
	while Part <> Nil do begin
		it := it + TotalRepairableDamage( Part , Skill );
		Part := Part^.Next;
	end;

	{ Check the inv-components for damage. }
	Part := Target^.InvCom;
	while Part <> Nil do begin
		it := it + TotalRepairableDamage( Part , Skill );
		Part := Part^.Next;
	end;

	TotalRepairableDamage := it;
end;

Procedure ApplyRepairPoints( Target: GearPtr; Skill: Integer; var RP: LongInt );
	{ Search through TARGET, and restore DPs to parts }
	{ that can be repaired using SKILL. }
const
	tmp_MAX = 2147483647;
var
	Part: GearPtr;
	SD,AD,TCom,SCom,ARP,RPNeeded: LongInt;
	T: Integer;
	tmp: Int64;
begin
	{ Only examine TARGET for damage if it's of a type that can be }
	{ repaired using SKILL. }
	if RepairSkillNeeded( Target ) = Skill then begin
		{ Calculate structural damage and armor damage. }
		SD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_StrucDamage ) );
		if ( SD > 0 ) and ( RP > 0 ) then begin
			{ Modify for complexity. }
			ARP := RP;
			RPNeeded := SD;

			if not IsMasterGear( Target ) then begin
				TCom := ComponentComplexity( Target );
				SCom := SubComComplexity( Target );
				if SCom > TCom then begin
					tmp := ( Int64(RPNeeded) * Int64(SCom) ) div TCom;
					if tmp < 0 then begin
						RPNeeded := 0;
					end else if tmp_MAX < tmp then begin
						RPNeeded := tmp_MAX;
					end else begin
						RPNeeded := tmp;
					end;
					tmp := ( Int64(ARP) * Int64(TCom) ) div SCom;
					if tmp < 1 then begin
						ARP := 1;
					end else if tmp_MAX < tmp then begin
						ARP := tmp_MAX;
					end else begin
						ARP := tmp;
					end;
				end;
			end;

			SD := SD - ARP;
			RP := RP - RPNeeded;
			if SD < 0 then SD := 0;
			SetNAtt( Target^.NA , NAG_Damage , NAS_StrucDamage , SD );
		end;

		AD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_ArmorDamage ) );
		if ( AD > 0 ) and ( RP > 0 ) then begin
			{ Modify for complexity. }
			ARP := RP;
			RPNeeded := AD;

			if not IsMasterGear( Target ) then begin
				TCom := ComponentComplexity( Target );
				SCom := SubComComplexity( Target );
				if SCom > TCom then begin
					tmp := ( Int64(RPNeeded) * Int64(SCom) ) div TCom;
					if tmp < 0 then begin
						RPNeeded := 0;
					end else if tmp_MAX < tmp then begin
						RPNeeded := tmp_MAX;
					end else begin
						RPNeeded := tmp;
					end;
					tmp := ( Int64(ARP) * Int64(TCom) ) div SCom;
					if tmp < 1 then begin
						ARP := 1;
					end else if tmp_MAX < tmp then begin
						ARP := tmp_MAX;
					end else begin
						ARP := tmp;
					end;
				end;
			end;

			AD := AD - ARP;
			RP := RP - RPNeeded;
			if AD < 0 then AD := 0;
			SetNAtt( Target^.NA , NAG_Damage , NAS_ArmorDamage , AD );
		end;
	end;

	{ Check for status effects. }
	for t := 1 to Num_Status_FX do begin
		if ( SX_RepSkill[t] = Skill ) and ( NAttValue( Target^.NA , NAG_StatusEffect , T ) <> 0 ) then begin
			if RP >= SX_RepCost[ t ] then begin
				RP := RP - SX_RepCost[ t ];
				SetNAtt( Target^.NA , NAG_StatusEffect , T , 0 );
			end;
		end;
	end;

	{ Check the sub-components for damage. }
	Part := Target^.SubCom;
	while ( Part <> Nil ) and ( RP > 0 ) do begin
		ApplyRepairPoints( Part , Skill , RP );
		Part := Part^.Next;
	end;

	{ Check the inv-components for damage. }
	Part := Target^.InvCom;
	while ( Part <> Nil ) and ( RP > 0 ) do begin
		ApplyRepairPoints( Part , Skill , RP );
		Part := Part^.Next;
	end;
end;

Function UseRepairSkill( GB: GameBoardPtr; PC,Target: GearPtr; Skill: Integer ): LongInt;
	{ The PC wants to use the requested repair SKILL on TARGET. }
	{ Roll to see how many DPs will be restored, apply these DPs }
	{ to the TARGET, then reduce PC's MPs. }
	Function Repair_Skill_Target: Integer;
		{ Return a good skill target for repair skills. }
		{ This will be decreased as TARGET's scale increases. }
	var
		RST: Integer;
	begin
		if Target^.Scale = 0 then begin
			if Skill = 16 then begin
				RST := 10;
			end else begin
				RST := 5;
			end;
		end else if Target^.Scale = 1 then begin
			RST := 3;
		end else begin
			RST := 1;
		end;
		if Destroyed( Target ) then RST := RST + 10;
		Repair_Skill_Target := RST;
	end;
var
	tries,SkRk,RP,MaxRP,Leftover: LongInt;
	DP,DP0,TotalRepaired: LongInt;
begin
	{ Depending upon how much damage the target has, the PC can make }
	{ several repair attempts. }
	PC := LocatePilot( PC );
	if PC = Nil then Exit( 0 );

	if GB <> Nil then begin
		if not MoveLegal( FindRoot( PC ) , NAV_Stop , GB^.ComTime ) then Exit( 0 );
	end;

	tries := 0;
	DP := TotalRepairableDamage( Target , Skill );
	DP0 := DP;
	MaxRP := ( SkillRank( PC , Skill ) * ( Target^.Scale + 1 ) ) + 1;
	SkRk := SkillValue( PC , SKill );

	TotalRepaired := 0;

	Leftover := 0;
	while ( tries < Repair_Max_Tries ) and ( DP > 0 ) and ( CurrentMental( PC ) > 0 ) do begin
		RP := RollStep( SkRk ) - Repair_Skill_Target;
		if RP > MaxRP then begin
			RP := MaxRP;
			DoleSkillExperience( PC , Skill , XPA_SK_UseRepair );
		end;
		if RP > 0 then begin
			RP := RP + Leftover;
			TotalRepaired := TotalRepaired + RP;
			DP := DP - RP;
			ApplyRepairPoints( Target , Skill , RP );

			Leftover := RP;

			DoleExperience( PC , XPA_GoodRepairJob );
		end else begin
			Leftover := 0;
		end;

		DoleSkillExperience( PC , Skill , XPA_SK_UseRepair );
		AddMentalDown( PC , Repair_Mental_Strain );
		Inc( Tries );
	end;

	{ Advance time by the required amount. }
	if HasTalent( PC , NAS_CombatMedic ) and (( Skill = 20 ) or ( Skill = 16 )) and ( not IsSafeArea( GB ) ) then begin
		WaitAMinute( GB , PC , ( ReactionTime( PC ) * Tries div 3 ) + 1 );
		AddStaminaDown( PC , Tries div 2 );
	end else begin
		WaitAMinute( GB , PC , ReactionTime( PC ) * Tries );
	end;

	UseRepairSkill := DP0 - TotalRepairableDamage( Target, Skill );
end;

Function SeekBestInstrument( PC: GearPtr ): GearPtr;
	{ Check the PC's inventory for the best instrument to use. }
var
	Item,Best: GearPtr;
begin
	Best := Nil;
	Item := PC^.InvCom;
	while Item <> Nil do begin
		if ( Item^.G = GG_Usable ) and ( Item^.S = GS_Instrument ) and NotDestroyed( Item ) then begin
			if Best = Nil then Best := Item
			else if Item^.Stat[ STAT_UseBonus ] > Best^.Stat[ STAT_UseBonus ] then Best := Item;
		end;
		Item := Item^.Next;
	end;
	SeekBestInstrument := Best;
end;

Function UsePerformance( GB: GameBoardPtr; PC,Instrument: GearPtr ): LongInt;
	{ The PC is about to use a performance skill. }
	{ As a result, the following things may happen: }
	{ - Earn money through tips. }
	{ - Set "APPLAUSE" triggers for positive reactions. }
	{ - Modify Morale up or down. }
	{ - Earn skill experience for performance. }
	{ - Lose Mental and Stamina from the act of playing. }
	{ Return -1 for a bad performance, 0 for a mediocre performance, }
	{ and a positive number if the PC made any tips. }
var
	Perf: Integer;		{ Modified performance ranking. }
	SkRoll,Target: Integer;	{ Skill roll target }
	N: Integer;		{ Number of successes }
	Cash: LongInt;
	M: GearPtr;
begin
	{ Determine the performance skill, and modify for instrument. }
	Perf := SkillValue( PC , NAS_Performance ) + Instrument^.Stat[ STAT_UseBonus ];

	{ Reduce stamina and mental now. }
	{ Performing is both mentally and physically exhausting. }
	if Random( 2 ) = 1 then begin
		AddStaminaDown( PC , 1 );
	end else begin
		AddMentalDown( PC , 1 );
	end;
	if ( CurrentMental( PC ) > 0 ) and ( CurrentStamina( PC ) > 0 ) then begin
		{ Give out some skill experience, as long as the PC is }
		{ not yet exhausted. }
		DoleSkillExperience( PC , NAS_Performance , 1 );
	end;

	{ Check through the audience. For the purpose of this game, }
	{ the audience counts as every nonhostile NPC within [UseRange] tiles. }
	N := 0;
	Cash := 0;

	{ Modify N for a low reputation. }
	if NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned ) < 1 then Dec( N );

	M := GB^.Meks;
	while M <> Nil do begin
		{ If M is a character, not the PC, and is active, }
		{ and is not hostile towards the PC, and is in range, }
		{ check its reaction to the performance. }
		if ( M^.G = GG_Character ) and ( M <> PC ) and ( Range( GB , M , PC ) <= Instrument^.Stat[ STAT_UseRange ] ) and GearActive( M ) and ( not AreEnemies( GB , M , PC ) ) then begin
			{ Calculate the target number. }
			Target := ( CStat( M , STAT_Ego ) * 3 div 2 ) + NAttValue( M^.NA , NAG_Personal , NAS_PerformancePenalty );
			if Target < 10 then Target := 10;

			SkRoll := RollStep( Perf );
			if SkRoll > Target then begin
				Inc( N );
				if Random( 2 ) = 1 then AddNAtt( M^.NA , NAG_Personal , NAS_PerformancePenalty , 1 );
				if SkRoll > ( Target * 2 ) then Inc( N );
				if ( CurrentMental( PC ) > 0 ) and ( CurrentStamina( PC ) > 0 ) then begin
					DoleSkillExperience( PC , NAS_Performance , 1 );
					DoleExperience( PC , 1 );
				end;
				SetTrigger( GB , TRIGGER_Applause );
			end else if ( SkRoll + PersonalityCompatability( PC , M ) - 5 ) < 0 then begin
				Dec( N );
			end;
		end;

		M := M^.Next;
	end;

	{ If the PC earned any money from busking, add that here. }
	if ( N >= 2 ) then begin
		DoleExperience( PC , N div 2 );
		Dec( N );
		if ( CurrentMental( PC ) > 0 ) and ( CurrentStamina( PC ) > 0 ) then begin
			if N > NAttValue( PC^.NA , NAG_Skill , NAS_Performance ) then N := NAttValue( PC^.NA , NAG_Skill , NAS_Performance );
			Cash := SkillAdvCost( Nil , N ) div 10;
			AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );
		end;

	end else if ( N < 0 ) then begin
		{ The PC did pretty badly. }
		AddMoraleDmg( PC , Rollstep( 1 ) );
		Cash := -1;
	end;

	UsePerformance := Cash;
end;

Function RandomRobotName: String;
	{ Generate random St*r-W*rs sounding robot name. }
const
	NumLetter = 30;
	Letters: Array [1..NumLetter] of char = (
	'A','B','C','D','E', 'F','G','H','I','J',
	'K','L','M','N','O', 'P','Q','R','S','T',
	'U','V','W','X','Y', 'Z','C','P','D','R'
	);
	Function AlphaNum: String;
		{ Generate a random sequence of letters and numbers. }
	var
		msg: String;
	begin
		msg := Letters[ Random( NumLetter ) + 1 ];
		if Random( 2 ) = 1 then msg := msg + Letters[ Random( NumLetter ) + 1 ];
		if Random( 2 ) = 1 then msg := msg + BStr( Random( 10 ) )
		else msg := BStr( Random( 10 ) ) + msg;
		if Random( 10 ) = 1 then msg := msg + BStr( Random( 10 ) )
		else if Random( 9 ) = 1 then msg := BStr( Random( 10 ) ) + msg
		else if Random( 8 ) = 1 then msg := msg + Letters[ Random( NumLetter ) + 1 ]
		else if Random( 8 ) = 1 then msg := Letters[ Random( NumLetter ) + 1 ] + msg;
		AlphaNum := msg;
	end;
	Function JustNum: String;
		{ Return a random sequence of numbers. }
	begin
		JustNum := BStr( Random( 499 ) + Random( 489 ) + 10 );
	end;
var
	name: String;
begin
	name := AlphaNum;
	repeat
		if Random( 2 ) = 1 then begin
			name := name + '-' + AlphaNum;
		end else begin
			name := name + '-' + JustNum;
		end;
	until ( Length( name ) > 10 ) or ( Random( 2 ) = 1 );
	RandomRobotName := name;
end;

Function UseRobotics( GB: GameBoardPtr; PC,Ingredients: GearPtr ): GearPtr;
	{ Given the above list of ingredients, the PC will try to construct a robot. }
	{ Here are the rules: }
	{ - Ingredients provide build points. }
	{ - BODY of the robot to be determined by the total amount of build points. }
	{ - PERCEPTION, CRAFT, KNOWLEDGE determined by PC's Robotics skill roll. }
	{ - SPEED, REFLEXES determined by skill roll, reduced by BODY. }
	{ - CHARM is 1, unless robot gains self-awareness. }
	{ - All robots get a body. }
	{ - If self-aware, give the robot a humanoid body }
	{ - Roll for movement type: Wheels, Tracks, Legs-4, Legs-2, Hover, Flight }
	{ - Add movement modules: STORAGE, LEGS, or WINGS }
	{ - Add combat modules: ARM, TURRET, HEAD, TAIL }
	{ Wow, this is really complicated. I might have second thoughts about }
	{ adding a GENE BLENDER for the BioTech skill later on... }
	{ This function returns the robot, or NIL if construction failed. }
	{ The calling procedure should place the robot on the map or dispose of it. }
const
	BP_MAX = 2147483647;
	BP_MIN = -2147483648;
	Stat_MAX = 32767;
var
	Robot,Part,Part2: GearPtr;
	BP: LongInt;
	BP_tmp: Int64;
	SkRk,T,BaseSkill,Sensor,Electronic,Armor,Skill: Integer;
	Viable,Good: Boolean;

	Procedure InstallLimb( N,Size: Integer );
		{ Install a limb into the robot. }
	var
		M,H: GearPtr;
	begin
		M := AddGear( Robot^.SubCom , Robot );
		if Size < 1 then Size := 1;
		M^.G := GG_Module;
		M^.S := N;
		M^.V := Size;
		InitGear( M );
		M^.Stat[ STAT_Armor ] := Size;
		if N = GS_Arm then begin
			if RollStep( SkRk ) > 5 then begin
				H := AddGear( M^.SubCom , M );
				H^.G := GG_Holder;
				H^.S := GS_Hand;
				InitGear( H );
			end;

		end else if N = GS_Wing then begin
			H := AddGear( M^.SubCom , M );
			H^.G := GG_MoveSys;
			H^.S := GS_FlightJets;
			H^.V := M^.V * 2;
			InitGear( H );

			if RollStep( SkRk ) > 16 then begin
				H := AddGear( M^.SubCom , M );
				H^.G := GG_Holder;
				H^.S := GS_Mount;
				InitGear( H );
				SetSAtt( H^.SA , 'NAME <' + GearName( M ) + ' ' + GearName( H ) + '>' );
			end;

		end else if N = GS_Storage then begin
			H := AddGear( M^.SubCom , M );
			H^.G := GG_MoveSys;
			H^.S := GS_Tracks;
			H^.V := M^.V;
			InitGear( H );


		end else if N <> GS_Body then begin
			if RollStep( SkRk ) >= 12 then begin
				H := AddGear( M^.SubCom , M );
				H^.G := GG_Holder;
				H^.S := GS_Mount;
				InitGear( H );
				SetSAtt( H^.SA , 'NAME <' + GearName( M ) + ' ' + GearName( H ) + '>' );
			end;
		end;
	end;

begin
	{ PC must have some energy to do this. }
	if CurrentMental( PC ) < 1 then begin
		DisposeGear( Ingredients );
		Exit( Nil );
	end;

	{ Add the stamina decrease here. }
	AddMentalDown( PC , 10 );

	{ Start with allocating the robot's base gear. }
	Robot := NewGear( Nil );
	Robot^.G := GG_Character;
	InitGear( Robot );
	SetNAtt( Robot^.NA , NAG_GearOps , NAS_Material , NAV_Metal );
	SetSAtt( Robot^.SA , 'TYPE <ROBOT>' );
	SetSAtt( Robot^.SA , 'JOB <ROBOT>' );
	SetSAtt( Robot^.SA , 'NAME <' + RandomRobotName + '>' );
	SetNAtt( Robot^.NA , NAG_CharDescription , NAS_DAge , -19 );
	SetSAtt( Robot^.SA , 'ROGUECHAR <R>' );
    SetNAtt( Robot^.NA, NAG_CharDescription, NAS_Gender, NAV_Undefined );
    SetNAtt( Robot^.NA, NAG_CharDescription, NAS_Sentience, NAV_IsMonster );
    {$IFDEF SDLMODE}
    SetSAtt( Robot^.SA, 'SDL_COLORS <' + RandomColorString(CS_Clothing) + ' ' + RandomColorString(CS_PrimaryMecha) + ' ' + RandomColorString(CS_Detailing) + '>' );
    {$ELSE}
	SetSAtt( Robot^.SA , 'SDL_COLORS <80 80 85 170 155 230 6 42 120>' );
    {$ENDIF}

	{ Determine the PC's ROBOTICS skill. }
	{ The skill rank is penalized by 10 here since it will be given a bonus }
	{ by the robot build points later; in most cases the two will cancel out. }
	SkRk := TeamSkill( GB , NAV_DefPlayerTeam , 38 ) - 10;
	PC := LocatePilot( PC );
	BaseSkill := NAttValue( PC^.NA , NAG_Skill , 38 );

	{ Give some experience. }
	DoleSkillExperience( PC , 38 , NumSiblingGears( Ingredients ) );
	DoleExperience( PC , 5 );

	{ Count the BPs provided by the ingredient list. }
	BP := 0;
	Part := Ingredients;
	while Part <> Nil do begin
		if Part^.G = GG_RepairFuel then begin
			BP := BP + Part^.V;
		end else begin
			BP_tmp := BP;
			BP_tmp := BP_tmp + GearMaxDamage( Part ) * 5;
			BP_tmp := BP_tmp + GearMaxArmor( Part ) * 3;
			BP_tmp := BP_tmp + GearMass( Part );
			if BP_tmp < BP_MIN then begin
				BP_tmp := BP_MIN;
			end else if BP_MAX < BP_tmp then begin
				BP_tmp := BP_MAX;
			end;
			BP := BP_tmp;
		end;
		Part := Part^.Next;
	end;

	{ Use the BP total to calculate the robot's BODY stat. }
	if (Stat_MAX < (BP div 25)) then begin
		Robot^.Stat[ STAT_Body ] := Stat_MAX;
	end else begin
		Robot^.Stat[ STAT_Body ] := BP div 25;
	end;
	if Robot^.Stat[ STAT_Body ] < 1 then Robot^.Stat[ STAT_Body ] := 1
	else if Robot^.Stat[ STAT_Body ] > 25 then Robot^.Stat[ STAT_Body ] := 25;

	{ Build Points also make constructing the robot easier. }
	while BP > 0 do begin
		BP := BP div 2;
		Inc( SkRk );
	end;

	{ Roll for the other stats. }
	{ REFLEXES and SPEED }
	Robot^.Stat[ STAT_Reflexes ] := RollStep( SkRk ) - 7 - ( Robot^.Stat[ STAT_Body ] div 4 );
	Robot^.Stat[ STAT_Speed ] := RollStep( SkRk ) - 5 - ( Robot^.Stat[ STAT_Body ] div 2 );

	{ PERCEPTION, CRAFT, KNOWLEDGE }
	Robot^.Stat[ STAT_Perception ] := RollStep( SkRk ) - 10;
	Robot^.Stat[ STAT_Craft ] := RollStep( SkRk ) - 7;
	Robot^.Stat[ STAT_Knowledge ] := RollStep( SkRk ) - 7;
	Robot^.Stat[ STAT_Ego ] := RollStep( SkRk ) - 10;

	{ Make sure nothing has gone below 0. }
	{ If all the stats are above 10, maybe make robot self-aware. }
	Viable := True;
	Good := True;
	for t := 1 to 7 do begin
		if Robot^.Stat[ t ] > ( BaseSkill * 2 + 1 ) then Robot^.Stat[ t ] := ( BaseSkill * 2 + 1 );
		if Robot^.Stat[ t ] < 1 then begin
			if CurrentMental( PC ) >= Abs( Robot^.Stat[ t ] * 2 ) then begin
				AddMentalDown( PC , Abs( Robot^.Stat[ t ] ) * 2 );
				Robot^.Stat[ t ] := 1 + Random( 3 );
			end else begin
				Viable := False;
			end;
		end;
		if Robot^.Stat[ t ] < 10 then begin
			Good := False;
		end;
	end;

	{ Self-aware robots may have CIDs. Other robots may not. }
	if Good then begin
		Robot^.Stat[ STAT_Charm ] := RollStep( SkRk ) - 10;
		if Robot^.Stat[ STAT_Charm ] > 10 then begin
			{ This robot has become self-aware!!! }
			{ Give it a CID, a gender, and it likes the PC. }
			SetNAtt( Robot^.NA , NAG_Personal , NAS_CID , NewCID( GB , FindRoot( GB^.Scene ) ) );
			SetNAtt( Robot^.NA , NAG_CharDescription , NAS_Gender , Random( 3 ) );
            SetNAtt( Robot^.NA, NAG_CharDescription, NAS_Sentience, NAV_IsCharacter );
			AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( Robot^.NA , NAG_Personal , NAS_CID ) , 50 );

			{ Give the PC some extra XP for a job well done. }
			DoleSkillExperience( PC , 38 , 50 );
			DoleExperience( PC , 100 );
		end else begin
			Robot^.Stat[ STAT_Charm ] := 1;
			Good := False;
		end;
	end else begin
		Robot^.Stat[ STAT_Charm ] := 1;
	end;

	{ Finally, if the robot is viable, give it a body. }
	{ Otherwise it gets nothing. }
	if Viable then begin
		{ First, our robot needs a body. Self-aware robots get humanoid bodies. }
		{ Other robots get random bodies. }
		if Good then begin
			ExpandCharacter( Robot );
		end else begin
			InstallLimb( GS_Body , MasterSize( Robot ) );
			if RollStep( SkRk ) > 20 then begin
				InstallLimb( GS_Wing , MasterSize( Robot ) );
				InstallLimb( GS_Wing , MasterSize( Robot ) );
			end else if RollStep( SkRk ) > 10 then begin
				if Random( 5 ) = 1 then begin
					for t := 1 to 3 do InstallLimb( GS_Leg , MasterSize( Robot ) - 1 );
				end else if Random( 3 ) = 1 then begin
					for t := 1 to 2 do InstallLimb( GS_Leg , MasterSize( Robot ) );
				end else begin
					for t := 1 to 4 do InstallLimb( GS_Leg , MasterSize( Robot ) - 1 );
				end;
			end else begin
				for t := 1 to 2 do InstallLimb( GS_Storage , MasterSize( Robot ) );
			end;
			SetSAtt( Robot^.SA , 'SDL_SPRITE <monster_drone.png>' );
		end;

		{ Give our robot some skills. }
		for t := 6 to 10 do if Random( 5 ) <> 1 then SetNAtt( Robot^.NA , NAG_Skill , T , Random( BaseSkill ) );
		SetNAtt( Robot^.NA , NAG_Skill , NAS_WeightLifting , 10 );
		SetNAtt( Robot^.NA , NAG_Skill , 26 , 5 );
		SetNAtt( Robot^.NA , NAG_Skill , 30 , 5 );

		{ The base skill level determines how many perks this robot }
		{ will get. Start by installing weapons and other ingredients. }
		Part := Ingredients;
		Sensor := 0;
		Electronic := 0;
		Armor := 0;
		while Part <> Nil do begin
			Part2 := Part^.Next;
			if ( Part^.G = GG_Weapon ) and ( RollStep( SkRk ) > Part^.V ) and ( BaseSkill > 0 ) then begin
				DelinkGear( Ingredients , Part );
				InsertSubCom( SelectRandomGear( Robot^.SubCom ) , Part );
				Dec( BaseSkill );
			end else if ( Part^.G = GG_Sensor ) and ( Part^.V > Sensor ) then begin
				Sensor := Part^.V;
			end else if ( Part^.G = GG_Electronics ) and ( Part^.V > Electronic ) then begin
				Electronic := Part^.V;
			end else if ( Part^.G = GG_ExArmor ) and ( Part^.V > Armor ) then begin
				Armor := Part^.V;
			end;

			Part := Part2;
		end;

		Robot^.Stat[ STAT_Perception ] := Robot^.Stat[ STAT_Perception ] + ( Sensor div 2 );
		Robot^.Stat[ STAT_Knowledge ] := Robot^.Stat[ STAT_Knowledge ] + ( Electronic div 2 );
		AddNAtt( Robot^.NA , NAG_Skill , 13 , Armor );

		{ Each of the following perks costs two skill points, so }
		{ halve the BaseSkill value. }
		BaseSkill := BaseSkill div 2;
		for t := 1 to BaseSkill do begin
			if Random( 3 ) = 1 then begin
				{ Add a module. }
				if Random( 2 ) = 1 then InstallLimb( GS_Arm , MasterSize( Robot ) )
				else if Random( 5 ) = 2 then InstallLimb( GS_Head , MasterSize( Robot ) )
				else if Random( 5 ) = 2 then InstallLimb( GS_Tail , MasterSize( Robot ) )
				else InstallLimb( GS_Turret , MasterSize( Robot ) );
			end else if Random( 5 ) = 1 then begin
				{ Add a specialist skill, maybe. }
				Skill := Robot_Skill[ Random( Num_Robot_Skill ) + 1 ];
				AddNAtt( Robot^.NA , NAG_Skill , Skill , Random( BaseSkill ) + 1 );
			end else begin
				{ Improve a stat. }
				Inc( Robot^.Stat[ Random( 7 ) + 1 ] );
			end;
		end;

		{ Give some XP for a successful robot. }
		DoleSkillExperience( PC , 38 , 10 );
		DoleExperience( PC , 50 );

	end else begin
		{ The construction attempt has failed. }
		DisposeGear( Robot );
	end;

	{ Advance time by the required amount. }
	WaitAMinute( GB , PC , ReactionTime( PC ) * 10 );

	DisposeGear( Ingredients );
	UseRobotics := Robot;
end;


end.
