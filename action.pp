unit action;

	{ This is the *ACTION* unit! It handles two kinds of action- }
	{ gears moving across the gameboard, and gears taking damage + }
	{ potentially blowing up. This might seem like two strange things }
	{ to combine in a single unit, but believe me it makes sense. }

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
	TRIGGER_NumberOfUnits = 'NU';
	TRIGGER_UnitEliminated2 = 'TD';
	TRIGGER_NPCEliminated = 'UTD';
	TRIGGER_TeamMovement = 'TM';

	{ *** ENACT MOVEMENT RESULTS *** }
	EMR_Blocked = -2;
	EMR_Crash = -1;

var
	Destroyed_Parts_List: SAttPtr;


Function DamageGear( gb: GameBoardPtr; Part,Weapon: GearPtr; DMG,MOS,N: Integer; const AtAt: String ): LongInt;
Function DamageGear( gb: GameBoardPtr; Part: GearPtr; DMG: Integer): LongInt;
procedure Crash( gb: GameBoardPtr; Mek: GearPtr );

Procedure PrepAction( GB: GameBoardPtr; Mek: GearPtr; Action: Integer );
Function EnactMovement( GB: GameBoardPtr; Mek: GearPtr ): Integer;

Function TeamPV( MList: GearPtr; Team: Integer ): LongInt;
Function TeamTV( MList: GearPtr; Team: Integer ): LongInt;

Procedure WaitAMinute( GB: GameBoardPtr; Mek: GearPtr; D: Integer );


implementation

uses ability,damage,gearutil,ghchars,ghmodule,ghweapon,interact,movement,rpgdice,texutil;

const
	EjectDamage = 10;	{ The damage step to roll during an ejection attempt. }

	MissileConcussion = 3;
	MeleeConcussion = 3;
	ModuleConcussion = 7;

	DamagePilotChance = 75;		{ % chance to damage pilot by concussion. }
	DamageInventoryChance = 25;	{ % chance to damage inventory gears by concussion. }



Function TakeDamage( GB: GameBoardPtr; Part: GearPtr; DMG: LongInt ): Boolean;
	{ Store the listed amount of damage in PART. Return TRUE if part }
	{ was operational at the start & is still operational, FALSE otherwise. }
	{ The main reason for having this procedure is to record triggers }
	{ when something is destroyed. }
var
	Ok_At_Start: Boolean;
	GoUp: GearPtr;	{ A counter that will be used to check all of PART's parents. }
	Team: Integer;
begin
	Ok_At_Start := GearOperational( Part );

	AddNAtt(Part^.NA,NAG_Damage,NAS_StrucDamage,DMG);

	{ If PART was destroyed by this damage, there may be triggers that }
	{ need generating. Get to work. }
	if Ok_At_Start and ( not GearOperational( Part ) ) then begin

		{ PART and all of its parents up to root need to be }
		{ checked for triggers. }
		GoUp := Part;
		while GoUp <> Nil do begin
			{ If GoUp is destroyed, and it has a UID, generate }
			{ a TD* trigger. }
			if ( NAttValue( GoUp^.NA , NAG_EpisodeData , NAS_UID ) <> 0 ) and ( Not GearOperational( GoUp ) ) then begin
				SetTrigger( GB , TRIGGER_UnitEliminated2 + BStr( NAttValue( GoUp^.NA , NAG_EpisodeData , NAS_UID ) ) );
			end;

			{ If GoUp is destroyed and it had a CID, generate }
			{ a UTD* trigger. }
			if ( NAttValue( GoUp^.NA , NAG_Personal , NAS_CID ) <> 0 ) and ( Not GearOperational( GoUp ) ) then begin
				SetTrigger( GB , TRIGGER_NPCEliminated + BStr( NAttValue( GoUp^.NA , NAG_Personal , NAS_CID ) ) );
			end;

			{ If this is a root level gear, generate a NU* trigger. }
			if ( GoUp^.Parent = Nil ) and IsMasterGear( GoUp ) then begin
				Team := NAttValue( GoUp^.NA , NAG_Location , NAS_Team );
				SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
			end;

			{ Move up one more level. }
			GoUp := GoUp^.Parent;
		end;

		{ Add this gear to the list of destroyed parts. }
		{ Only do this for non-master gears which aren't at }
		{ root level. }
		if ( Part^.Parent <> Nil ) and not IsMasterGear( Part ) then StoreSAtt( Destroyed_Parts_List , GearName( Part ) );

	end else if OK_At_Start and ( Part^.G = GG_Character ) then begin
		{ Taking damage trains vitality... }
		{ As long as the character survives, that is. }
		DoleSkillExperience( Part , 13 , DMG * 2 );

		{ It also causes the afflicted to feel worse for wear. }
		AddMoraleDmg( Part , DMG );
	end;

	TakeDamage := Ok_At_Start and NotDestroyed( Part );
end;

Procedure EjectionCheck( gb: GameBoardPtr; Part: GearPtr );
	{ The parent has just been destroyed. Check to see whether or not }
	{ there is a pilot inside of it, then roll to escape or be blasted }
	{ to bits. }
	{ ASSERT: PART is a subcomponent of its parent. }
var
	P2: GearPtr;
	Master: GearPtr;
	ERoll,EMod,Team: Integer;
begin
	{ To start with, find the team for this unit, since we might not be }
	{ able to after the pilot ejects. }
	if Part <> Nil then Team := NAttValue( FindRoot( Part )^.NA , NAG_Location , NAS_Team );

	while ( Part <> Nil ) do begin
		P2 := Part^.Next;

		if NotDestroyed( Part ) then begin
			if Part^.G = GG_Character then begin
				{ This character must either eject or die. }
				{ Actually, eject, suffer damage, or die. }
				DAMAGE_EjectRoll := True;
				EMod := 5;

				{ First, determine what sort of module the pilot }
				{ is in. HEAD = +3 bonus to eject. }
				Master := Part^.Parent;
				while ( Master <> Nil ) and ( Master^.G <> GG_Module ) do begin
					Master := Master^.Parent;
				end;
				if Master <> Nil then begin
					{ We've found the module the cockpit is in. }
					if Master^.S = GS_Head then EMod := EMod - 3;
				end else begin
					{ We can't find a module, all the way back to root. }
					{ Try to handle things gracefully... }
					Master := Part^.Parent;
				end;

				{ Find the root-level master of this part. }
				while Master^.Parent <> Nil do begin
					Master := Master^.Parent;
				end;

				{ Do the Skill Roll - SPEED + DODGE SKILL }
				ERoll := RollStep( ( ( Part^.Stat[STAT_Speed] + 1 ) div 2 ) + NAttValue( Part^.NA , NAG_Skill , 10 ) );
				if ERoll < ( EMod * 2 ) then begin
					{ The character will eject, but takes some damage. }
					TakeDamage( GB , Part , RollStep(EjectDamage) );
				end;

				if ERoll > EMod then begin
					{ Delink the chaacter, then attach as a sibling of the master gear. }
					DelinkGear( Part^.Parent^.SubCom , Part );
					Part^.Next := Master^.Next;
					Master^.Next := Part;

					DAMAGE_EjectOK := True;

				end else begin
					{ The character has not managed to eject successfully. }
					{ He's toast. }
					TakeDamage( GB , Part , GearMaxDamage( Part ) );

				end;

				if Destroyed( Part ) then begin
					DAMAGE_PilotDied := True;
				end;


				{ If an ejection has occurred, or the pilot has died trying, }
				{ better set a NUMBER OF UNITS trigger. }
				SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
			end else begin
				{ Check the sub components for characters. }
				EjectionCheck( GB , Part^.SubCom );
			end;
		end;

		Part := P2;
	end;
end;

Procedure AmmoExplosion( Part: GearPtr );
	{ How should an ammo explosion work? Well, roll damage for the }
	{ ammo and add it to the OVERKILL history variable. }
var
	NumShots: Integer;
	M: GearPtr;
begin
	{ Only installed ammo can explode. This may seem silly, and it }
	{ probably is, but otherwise carrying replacement clips is }
	{ asking for certain death. }
	if not IsSubCom( Part ) then exit;

	{ First calculate the number of shots in the magazine. }
	{ If it is empty, no ammo explosion will take place. }
	NumShots := Part^.Stat[ STAT_AmmoPresent ] - NAttValue( Part^.NA , NAG_WeaponModifier , NAS_AmmoSpent );
	if NumShots > 0 then begin
		DAMAGE_AmmoExplosion := True;
		M := FindModule( Part );
		if ( M = Nil ) or ( M^.S <> GS_Storage ) then begin
			DAMAGE_OverKill := DAMAGE_OverKill + RollDamage( Part^.V + NumShots , Part^.Scale );
		end;
	end;
end;

Procedure ApplyDamage( gb: GameBoardPtr; Part: GearPtr; DMG: LongInt);
	{ Add to the damage total of this part, }
	{ then check for special effects such as eject rolls, ammo }
	{ explosions, and whatever else has been implemented. }
var
	OK_at_Start: Boolean;	{ Was the part OK before damage was applied? }
	M: GearPtr;
begin
	{ERROR CHECK - If we are attempting to damage a storage}
	{module or other -1HP type, don't do anything.}

	if GearMaxDamage(Part) > 0  then begin
		OK_At_Start := NotDestroyed( Part );

		{ Calculate overkill. }
		if GearCurrentDamage( Part ) < DMG then begin
			{ Damage dealt to storage modules doesn't carry through to }
			{ overkill. The module can be blown off without affecting }
			{ the structural integrity of the whole. }
			M := FindModule( Part );
			if ( M = Nil ) or ( M^.S <> GS_Storage ) then begin
				DAMAGE_OverKill := DAMAGE_OverKill + DMG - GearCurrentDamage( Part );
			end;
			DMG := GearCurrentDamage( Part );
		end;

		TakeDamage( GB , Part , DMG );
		DAMAGE_LastPartHit := Part;

		if OK_At_Start and Destroyed( Part ) then begin
			{ The part started out OK, but it's been }
			{ destroyed. Check for special effects. }
			if (Part^.G = GG_Module ) or ( Part^.G = GG_Cockpit ) then begin
				EjectionCheck( GB , Part^.SubCom );
			end else if Part^.G = GG_Ammo then begin
				AmmoExplosion( Part );
			end;
		end;
	end;
end;

Procedure StagedPenetration(Part: GearPtr; var DMG: Longint; var MOS, Scale: Integer; AtAt: String);
	{This procedure applies armor damage to Part.}
	{ Variables DMG and MOS will be affected by this procedure. }
var
	XA,PMaster: GearPtr;
	MAP: Integer; {The maximum number of armor points to lose.}
	AAP: Integer; {The actual number that will be lost.}
	Armor: LongInt; { Initial armor value of the part. }
begin
	{ First, check InvComponents for external armor. }
	if ( Part <> Nil ) and ( not IsMasterGear( Part ) ) then begin
		XA := Part^.InvCom;
		while ( XA <> Nil ) do begin
			if XA^.G = GG_ExArmor then StagedPenetration( XA , Dmg , MOS , Scale , AtAt );
			XA := XA^.Next;
		end;
	end;

	{ Locate the master of this part, which we'll need in order }
	{ to check status conditions. }
	PMaster := FindMaster( Part );

	{ Only do armor damage to parts which have armor. }
	if GearMaxArmor( Part ) > 0 then begin
		Armor := GearCurrentArmor( Part );

		{ Reduce armor protection if the target is rusty. }
		if HasStatus( PMaster , NAS_Rust ) then ARMOR := ARMOR div 2;

		{ Next, apply damage to the armor itself. }
		{ Calculate the maximum armor damage possible. }
		{ This is determined by the scale of the attack. }
		MAP := 2;
		if Scale > 0 then for AAP := 1 to Scale do MAP := MAP * 5;

		{ If the part is MetaTerrain, the maximum armor }
		{ penetration may well be reduced. If an attack can't }
		{ get through the armor, it can't do any damage at all. }
		{ This is to prevent the PC from knocking down doors with }
		{ a lot of low-power attacks. }
		if ( Part^.G = GG_MetaTerrain ) and ( DMG < Armor ) then begin
			MAP := 0;
		end;

		{ Decide upon actual armor damage. }
		{ This will be MUCH greater if the target is rusty. }
		if HasStatus( PMaster , NAS_Rust ) then begin
			AAP := DMG div 2;
		end else begin
			AAP := Random( DMG div 2 + 1 );
			if AAP > MAP then AAP := MAP;
		end;

		{ BRUTAL attacks double their armor penetration. }
		if HasAttackAttribute( AtAt , AA_Brutal ) then begin
			AAP := AAP * 2;
			if AAP < 3 then AAP := 3;
		end;

		{ Record the current armor value, then record the armor damage. }
		if AAP > GearCurrentArmor( Part ) then AAP := GearCurrentArmor( Part );
		AddNAtt(Part^.NA,NAG_Damage,NAS_ArmorDamage,AAP);

	end else begin
		{ It's possible that this part has no armor at all. }
		{ Cover that possibility here. }
		Armor := 0;
	end;

	{ Adjust armor for MOS, then reduce MOS. }
	if ( MOS > 0 ) and ( Armor > 0 ) then begin
		if MOS < 4 then Armor := ( Armor * ( 4 - MOS ) ) div 4
		else Armor := 0;
		MOS := MOS - 4;
	end;

	{ Reduce the DMG variable by the current armor level. }
	DMG := DMG - Armor;
	if DMG < 0 then DMG := 0;
end;

Function SelectRandomModule( LList: GearPtr ): GearPtr;
	{ Select a module from LList at random. If no module is found, }
	{ return NIL. }
var
	M: GearPtr;
	N: Integer;
begin
	{ First, count the number of modules present. }
	N := 0;
	M := LList;
	while M <> Nil do begin
		if M^.G = GG_Module then Inc( N );
		M := M^.Next;
	end;

	{ Next, select one of the modules randomly. }
	if N > 0 then begin
		N := Random( N );
		M := LList;
		while ( M <> Nil ) and ( N > -1 ) do begin
			if M^.G = GG_Module then Dec( N );
			if N <> -1 then M := M^.Next;
		end;
	end;

	SelectRandomModule := M;
end;


Function REALDamageGear( gb: GameBoardPtr; Part: GearPtr; DMG: LongInt; MOS,Scale: Integer; const AtAt: String ): LongInt;
	{This is where the REAL damage process starts.}
var
	XA: GearPtr;
	N: Integer;
begin
	{ Increment the ITERATIONS value. }
	Inc( DAMAGE_Iterations );
	{ Do all damage thingies, unless we want to ignore damage. }
	if Not HasAttackAttribute( AtAt, AA_ArmorIgnore ) then begin
		{ If this is the first iteration, reduce the amount of damage done }
		{ by all armor values up to root level. This is so aimed shots at }
		{ sensors/etc won't ignore the armor of the module they're located in. }
		{ Note that only sub components get upwards armor protection- }
		{ externally mounted inv components don't. }
		if ( DAMAGE_Iterations = 1 ) and IsSubCom( Part ) then begin
			XA := Part^.Parent;
			while XA <> Nil do begin
				StagedPenetration( XA , DMG , MOS , Scale , AtAt );
				XA := XA^.Parent;
			end;
		end;

		{ If this is a character, apply staged penetration randomly }
		{ to the armor of one limb. }
		if ( Part^.G = GG_Character ) then begin
			XA := SelectRandomModule( Part^.SubCom );
			if XA <> Nil then StagedPenetration( XA , dmg , MOS , Scale , ATAt );
		end;

		{Reduce the amount of damage by the armor rating of}
		{this gear, and do damage to the armor.}
		StagedPenetration( Part , dmg , MOS , Scale , AtAt );
	end;

	if DMG > 0 then begin
		{If the damage made it through the armor, apply it to}
		{whatever's on the inside.}

		{ Increase damage by excess margin of success. }
		if ( MOS > 0 ) and ( GearMaxDamage(Part) <> -1 ) then begin
			{ Each extra point of MOS will increase damage }
			{ by 20%. }
			DMG := ( DMG * ( 5 + MOS ) ) div 5;
			MOS := 0;
		end;

		{Depending upon what the part we are damaging is, we}
		{might apply damage here or pass it on to a subcomponent.}
		N := NumActiveGears(Part^.SubCom);

		if N > 0 then begin
			{There are subcomponents. Either damage this}
			{part directly, or pass damage on to a subcom.}
			if (GearMaxDamage(Part) = -1) or ( Random(100) = 23 ) then begin
				{Damage a subcomponent. Time for recursion.}
				DMG := REALDamageGear( gb , FindActiveGear(Part^.SubCom,Random(N)+1), DMG , MOS , Scale , AtAt );

			end else if (Random(3) = 1) then begin
				{ Apply half the damage to this component, }
				{ and half the damage to its children. }
				ApplyDamage( gb , Part,DMG div 2);

				{ Recalculate the number of active subcomponents, as it may have changed. }
				N := NumActiveGears(Part^.SubCom);
				if N > 0 then begin
					DMG := ( DMG div 2 ) + REALDamageGear( gb , FindActiveGear(Part^.SubCom,Random(N)+1), (DMG+1) div 2 , MOS , Scale , ATAt );
				end else begin
					{ Apply all damage against this part. }
					ApplyDamage( gb , Part , ( DMG + 1 ) div 2 );
				end;

			end else begin
				ApplyDamage( gb , Part,DMG);
			end;

		end else begin
			{There are no subcomponents. Damage this}
			{module directly.}
			ApplyDamage( gb , Part , DMG );
		end;

	end else if DMG < 0 then begin
		{ We don't want this procedure reporting Damage less than }
		{ zero, because that's silly. }
		DMG := 0;
	end;

	REALDamageGear := DMG;
end;

Function ConcussionDamageAmount( Part , Weapon: GearPtr; Dmg , Scale: Integer ): Integer;
	{ Determine the amount of concussive damage this attack could }
	{ potentially apply to the soft bits of the mecha. }
var
	it,MS: Integer;
begin
	{ Base concussion chance is equal to the damage class of }
	{ the weapon. }
	it := Dmg; 

	{ Missiles and Melee Weapons do more concussion than normal. }
	if ( Weapon <> Nil ) then begin
		if Weapon^.G = GG_Weapon then begin
			if ( Weapon^.S = GS_Missile ) then begin
				it := it + MissileConcussion;
			end else if ( Weapon^.S = GS_Melee ) then begin
				it := it + MeleeConcussion;
			end;
		end else if Weapon^.G = GG_Module then begin
			it := it + ModuleConcussion;
		end;
	end;

	{ If the weapon scale is greater than the target scale, }
	{ more concussion is done. }
	if Scale > Part^.Scale then it := it * ( Scale - Part^.Scale + 1 )
	else if Scale < Part^.Scale then it := it div ( Part^.Scale - Scale + 3 );

	{ Determine the master size of the target. }
	MS := MasterSize( Part );
	if MS < 1 then MS := 1;

	ConcussionDamageAmount := it div MS;
end;

Function ApplyConcussion( GB: GameBoardPtr; Part: GearPtr; CDC: Integer; AutoDamage: Boolean ): Integer;
	{ Concussion damage is force from the impact which is passed }
	{ on to the soft parts of a mecha- i.e. its pilot. It can also }
	{ be passed on to inventory items, since these are outside }
	{ of the armor's protection. }
	{ Return the amount of damage done. }
	Function ACNow: Integer;
		{ Apply the concussion damage to PART now. }
		{ Return the amount of damage done. }
	var
		D: Integer;
	begin
		D := Random( CDC + 1 );
		if ( D > 0 ) and NotDestroyed( Part ) then ApplyDamage( GB , Part , D );
		ACNow := D;
	end;
var
	P2: GearPtr;
	Total: Integer;
begin
	{ Initialize TOTAL to 0. }
	Total := 0;

	{ If this part is succeptable to concussion damage, }
	{ apply the damage. }
	if ( Part^.G = GG_Character ) and ( Part^.Parent <> Nil ) and ( Random( 100 ) < DamagePilotChance ) then begin
		Total := Total + ACNow;
	end else if AutoDamage and ( Random( 100 ) < DamageInventoryChance ) then begin
		Total := Total + ACNow;
	end;

	{ Check all sub- and inv- components of this part. }
	{ Automatically damage the inventory components. }
	P2 := Part^.SubCom;
	while P2 <> Nil do begin
		Total := Total + ApplyConcussion( GB , P2 , CDC , False );
		P2 := P2^.Next;
	end;
	P2 := Part^.InvCom;
	while P2 <> Nil do begin
		Total := Total + ApplyConcussion( GB , P2 , CDC , True );
		P2 := P2^.Next;
	end;

	ApplyConcussion := Total;
end;

Function DamageGear( gb: GameBoardPtr; Part,Weapon: GearPtr; DMG,MOS,N: Integer; const AtAt: String ): LongInt;
	{ This is a dummy procedure used to first initialize all the }
	{ history variables, then to call the REAL procedure. }
	{ Since the actual damage procedure recurses, this setup }
	{ procedure is used to set everything up first. }
var
	P2: GearPtr;
	Total,T,Scale: LongInt;
begin
	{ Initialize History Variables. }
	DAMAGE_LastPartHit := Nil;
	DAMAGE_EjectRoll := False;
	DAMAGE_EjectOK := False;
	DAMAGE_PilotDied := False;
	DAMAGE_DamageDone := 0;
	DAMAGE_OverKill := 0;
	DAMAGE_Iterations := 0;
	DAMAGE_AmmoExplosion := False;
	DisposeSAtt( Destroyed_Parts_List );

	{ Make sure at least one hit will be caused. }
	if N < 1 then N := 1;

	{ Reset total damage done to 0. }
	Total := 0;

	{ Determine the scale of the attack - this info is needed for }
	{ rolling damage. If no weapon was used, this was probably a }
	{ crash or other self-inflicted injury. Use the target's own }
	{ scale against it. }
	if Weapon = Nil then Scale := Part^.Scale
	else begin
		Scale := Weapon^.Scale;

		{ Area effect weapons deal scatter damage. }
		if HasAreaEffect( AtAt ) and ( Part^.G <> GG_MetaTerrain ) and ( Part^.G <> GG_Prop ) then begin
			N := N * DMG;
			DMG := 1;
		end;
	end;

	{ Call the REAL procedure. }
	if ( Weapon <> Nil ) and HasAttackAttribute( AtAt , AA_Hyper ) then begin
		{ If the root part has a damage score, it gets hit. }
		if ( GearMaxDamage(Part) > -1 ) then begin
			for T := 1 to N do begin
				Total := Total + REALDamageGear( gb , Part , RollDamage(DMG,Scale) , MOS , Scale , AtAt );
			end;
		end;

		{ Each subcomponent then gets hit individually. }
		for T := 1 to N do begin
			P2 := Part^.SubCom;
			while P2 <> Nil do begin
				Total := Total + REALDamageGear( gb , P2 , RollDamage(DMG,Scale) , MOS , Scale , AtAt );
				P2 := P2^.Next;
			end;
		end;

	end else begin
		{ Normal damage. }
		for T := 1 to N do begin
			Total := Total + REALDamageGear( gb , Part , RollDamage(DMG,Scale) , MOS , Scale , AtAt );
		end;
	end;

	{ Do concussion damage as appropriate. }
	T := ConcussionDamageAmount( Part , Weapon , Dmg , Scale );
	if ( T > 0 ) then Total := Total + ApplyConcussion( GB , Part , T , False );

	{ Do overkill damage to the root torso. }
	if DAMAGE_OverKill > 0 then begin
		Part := FindRoot( Part );
		if ( Part^.G = GG_Mecha ) and ( Part^.SubCom <> Nil ) then begin
			Part := Part^.SubCom;
			while ( Part <> Nil ) and ( Part^.S <> GS_Body ) do Part := Part^.Next;
			if Part <> Nil then begin
				Total := Total + REALDamageGear( gb , Part , DAMAGE_OverKill , MOS , Scale , '' );
			end;
		end;
	end;

	DAMAGE_DamageDone := Total;
	DamageGear := Total;
end;

Function DamageGear( gb: GameBoardPtr; Part: GearPtr; DMG: Integer): LongInt;
	{ Apply damage without a Margin Of Success. }
begin
	DamageGear := DamageGear( gb , Part , Nil , DMG , 0 , 1 , '' );
end;

procedure Crash( gb: GameBoardPtr; Mek: GearPtr );
	{ This mek has just become incapable of moving. Crash it. }
var
	MM,MA,DMG,N: Integer;	{ Move Mode and Move Action }
	MT: LongInt;
begin
	{ Make sure we have the root gear. }
	Mek := FindRoot( Mek );

	{ Determine both the move mode and the move action for this mek. }
	MM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	MA := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );

	{ Pass on appropriate info to the damage procedure. }
	{ The amount of damage done and the number of hits depends upon }
	{ the move mode and move action. }
	if ( MM > 0 ) and ( MM <= NumMoveMode ) then begin
		{ The movemode this mek has is legal. }
		Case MM of
			MM_Walk: DMG := 1;
			MM_Roll: DMG := 1;
			MM_Skim: DMG := 2;
			MM_Fly: DMG := 5;
			else DMG := 1;
		end;
	end else begin
		{ The movemode this mek has isn't legal. }
		DMG := 1;
	end;

	if MA = NAV_FullSpeed then N := 5
	else if MA = NAV_NormSpeed then N := 3
	else N := 2;

	DamageGear( gb , Mek , Nil , DMG , 0 , N , '' );

	MT := NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA );

	SetNAtt( Mek^.NA, NAG_Action , NAS_MoveAction , NAV_Stop );
	SetNAtt( Mek^.NA, NAG_Action , NAS_TimeLimit , 0 );
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , MT + 1000 );
	SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , MT + ClicksPerRound );

end;

Procedure DoActionSetup( GB: GameBoardPtr; Mek: GearPtr; Action: Integer );
	{ Perpare all of the mek's data structures for the action }
	{ being undertaken. }
begin
	if ( Action = NAV_Stop ) or ( Action = NAV_Hover ) or ( CPHMoveRate( Mek , GB^.Scale ) = 0 ) then begin
		if NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction ) = NAV_Stop then begin
			{ The mek is already stopped. Wait one round before calling again. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ( ClicksPerRound div 5 ) );

		end else begin
			{ The mek is currently moving but it wants to stop. }
			if ( Action <> NAV_Stop ) and ( Action <> NAV_Hover ) then Action := NAV_Stop;
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveAction , Action );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + 1 );
		end;

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end else if ( Action = NAV_NormSpeed ) or ( Action = NAV_Reverse ) then begin
		{ Move foreword. }
		if NAttValue( Mek^.NA , NAG_Action, NAS_MoveAction ) <> Action then begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , Action );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CalcMoveTime( Mek , GB ) + GB^.ComTime + 1 );
		end else begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA ) + 1 );
		end;

		{ If jumping, set the jump time limit. }
		if ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = MM_Fly ) and ( JumpTime( Mek ) > 0 ) then begin
			{ If this jump is just starting, set the time limit and recharge time now. }
			if NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit ) = 0 then begin
				SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , GB^.ComTime + JumpTime( Mek ) );
				SetNAtt( Mek^.NA , NAG_Action , NAS_JumpRecharge , GB^.ComTime + Jump_Recharge_Time );
			end;
		end else begin
			{ Reset the jumping time limit. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );
		end;

	end else if Action = NAV_FullSpeed then begin
		{ Move foreword, quickly. }
		if NAttValue( Mek^.NA , NAG_Action, NAS_MoveAction ) <> NAV_FullSpeed then begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , NAV_FullSpeed );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CalcMoveTime( Mek , GB ) + GB^.ComTime + 1 );
		end else begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA ) + 1 );
		end;

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end else if Action = NAV_TurnLeft then begin
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , NAV_TurnLeft );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CalcMoveTime( Mek , GB ) + GB^.ComTime );

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end else if Action = NAV_TurnRight then begin
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , NAV_TurnRight );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CalcMoveTime( Mek , GB ) + GB^.ComTime );

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end;
end;

Procedure PrepAction( GB: GameBoardPtr; Mek: GearPtr; Action: Integer );
	{ Given an action, prepare all of the mek's values for it. }
begin
	if MoveLegal( Mek , Action , GB^.ComTime ) or ( BaseMoveRate( Mek ) = 0 ) then begin
		DoActionSetup( GB , Mek , Action );
	end else begin
		if Action = NAV_Stop then begin
			if MoveLegal( Mek , NAV_NormSpeed , GB^.ComTime ) then begin
				DoActionSetup( GB , Mek , NAV_NormSpeed );
			end else begin
				Crash( GB , Mek );
			end;
		end else begin
			if MoveLegal( Mek , NAV_Stop , GB^.ComTime ) then begin
				DoActionSetup( GB , Mek , NAV_Stop );
			end else begin
				Crash( GB , Mek );
			end;
		end;
	end;
end;

Procedure DoMoveTile( Mek: GearPtr; GB: GameBoardPtr );
	{ This mek is about to move foreword. Process the movement. }
	{ Also, check for other meks in the target hex, and do a }
	{ charge if necessary. }
	{ If the mek moves off the map, it has fled the game. }
var
	P: Point;
begin
	{ Find out the gear's destination. }
	P := GearDestination( Mek );

	{ Set the mek's position to its new value. }
	SetNAtt( Mek^.NA , NAG_Location , NAS_X , P.X );
	SetNAtt( Mek^.NA , NAG_Location , NAS_Y , P.Y );

	{ If moving at top speed, set stamina drain. }
	if ( Mek^.G = GG_Character ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction ) = NAV_FullSpeed ) then begin
		AddStaminaDown( Mek , 1 );
	end;

	{ Set ETA for next move, and call the action selector. }
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , GB^.ComTime + CalcMoveTime( Mek , GB ) );
	SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + 1 );
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
end;

Procedure DoTurn( Mek: GearPtr; GB: GameBoardPtr );
	{ The mek is turning. Make it so, Mister Laforge. }
var
	cmd: Integer;	{The exact command issued.}
	D: Integer;	{The direction of the mek.}
begin
	{ Determine whether the mek is turning left or right. }
	cmd := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );

	{ Determine the direction the mek is currently facing. }
	D := NAttValue( Mek^.NA , NAG_Location , NAS_D );

	if cmd = NAV_TurnLeft then begin
		D := D - 1;
		if D < 0 then D := 7;
	end else begin
		D := D + 1;
		if D > 7 then D := 0;
	end;

	{ Set the direction to the modified value. }
	SetNAtt( Mek^.NA , NAG_Location , NAS_D , D );

	{ Set the mek's movement to Stop, and call the action selector. }
	if MoveLegal( Mek , NAV_Hover , GB^.ComTime ) then begin
		PrepAction( GB , Mek , NAV_Hover );
	end else begin
		PrepAction( GB , Mek , NAV_Stop );
	end;
end;

Function CrashTarget( Alt0,Alt1,Order: Integer ): Integer;
	{ Return the target number to avoid a crash if a mecha is }
	{ traveling from Alt0 to Alt1 with movement order Order. }
var
	it: Integer;
begin
	if Alt0 <= ( Alt1 + 1 ) then begin
		it := 7;
	end else begin
		it := ( Alt0 - ALt1 - 1 ) * 8 + 4;
	end;
	if Order <> NAV_FullSpeed then it := it - 5;
	CrashTarget := it;
end;

Function EnactMovement( GB: GameBoardPtr; Mek: GearPtr ): Integer;
	{ The time has come for this mech to move. }
	{ This procedure checks to see what kind of movement is }
	{ taking place, decides whether the move should be }
	{ cancelled or delayed due to systems damage, then branches }
	{ to the appropriate procedures. }
	{ It returns 1 if the move was successful and the display }
	{ should be updated, 0 if no event took place, and -1 if }
	{ the mek in question crashed or was otherwise damaged. }
var
	ETA,Spd,StartTime,Order,Alt0,ALt1,SkRoll: LongInt;
	NeedRedraw: Integer;
begin
	{ Note that this call to MoveThatMek might result in }
	{ no movement at all. It could be a wait call- an ETA }
	{ is set even if the mek's movemode is Inactive, or its }
	{ order is Stop. }

	NeedRedraw := 0;

	{ Locate all the important values for this mek. }
	ETA := NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA );
	StartTime := NAttValue( Mek^.NA , NAG_Action , NAS_MoveStart );
	Order := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );
	Spd := CalcMoveTime( Mek , GB );

	if Order = NAV_Stop then begin
		{ The mek isn't going anywhere. This is a wait call. }
		{ Set the ETA to not call this procedure again for 1000 clicks. }

		{ The mek might not have an activated move mode for whatever reason. }
		if NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = 0 then GearUp( Mek );

		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , ETA + 1000 );

	end else if ( NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit ) > 0 ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit ) < GB^.ComTime ) then begin
		{ If the mek was jumping and overshot the time limit, }
		{ make it crash now. }
		if NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = MM_Fly then begin
			Crash( GB , Mek );
			NeedRedraw := EMR_Crash;
		end else begin
			{ If the time limit was overshot but the mek isn't }
			{ jumping, clear it now. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );
		end;

	end else if MoveBlocked( Mek , GB ) then begin
		{ If the mecha is capable of stopping in time, then }
		{ stop. Otherwise it will crash into the obstacle. }
		if MoveLegal( Mek , NAV_Stop , GB^.ComTime ) then begin
			NeedRedraw := EMR_Blocked;
			PrepAction( GB , Mek , NAV_Stop );
		end else begin
			Crash( GB , Mek );
			NeedRedraw := EMR_Crash;
		end;

	end else if Spd = 0 then begin
		{ Movement mode has been disabled, or the mek }
		{ is blocked. In any case, this could be crash material. }
		Crash( GB , Mek );
		NeedRedraw := EMR_Crash;

	end else if ( Mek^.G = GG_Character ) and ( Order = NAV_FullSpeed ) and ( CharCurrentStamina( Mek ) <= 0 ) then begin
		PrepAction( GB , Mek , NAV_NormSpeed );

	end else if (StartTime + Spd) <= ETA then begin
		{ Everything is proceeding according to schedule. }
		{ Actually process the movement. }

		{ Store the initial altitude, to see if the mecha will }
		{ require a piloting check to avoid crashing at the end. }
		Alt0 := MekAltitude( GB , Mek );

		case Order of
			NAV_NormSpeed,NAV_FullSpeed,NAV_Reverse:
				begin
				DoMoveTile( Mek , GB );
				SetTrigger( GB , TRIGGER_TeamMovement + BStr( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) ) );
				end;
			NAV_TurnLeft,NAV_TurnRight:
				DoTurn( Mek , GB );
		end;

		Alt1 := MekAltitude( GB , Mek );

		if ( Alt1 < ( Alt0 - 1 ) ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) <> MM_Fly ) then begin
			if Mek^.G = GG_Mecha then begin
				SkRoll := RollStep( SkillValue( Mek , 5 ) );
			end else begin
				SkRoll := RollStep( SkillValue( Mek , 10 ) );
			end;
			if SkRoll < CrashTarget( Alt0 , Alt1 , Order ) then begin
				Crash( GB , Mek );
				NeedRedraw := EMR_Crash;
			end else begin
				NeedRedraw := 1;
			end;
		end else begin
			NeedRedraw := 1;
		end;

	end else begin
		{ The mek has been delayed by damage, but not }
		{ immobilized. Set new ETA. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , StartTime + Spd );
	end;

	EnactMovement := NeedRedraw;
end;

Function TeamPV( MList: GearPtr; Team: Integer ): LongInt;
	{ Calculate the total point value of active models belonging }
	{ to TEAM which are present on the map. }
const
	it_MAX = 2147483647;
var
	it: Int64;
begin
	it := 0;

	while MList <> Nil do begin
		if GearActive( MList ) and ( NAttValue( MList^.NA , NAG_Location , NAS_TEam ) = Team ) then begin
			it := it + GearValue( MList );
			if it_MAX < it then begin
				it := it_MAX;
			end;
		end;
		MList := MList^.Next;
	end;

	TeamPV := it;
end;

Function TeamTV( MList: GearPtr; Team: Integer ): LongInt;
	{ Calculate the total threat value of active models belonging }
	{ to TEAM which are present on the map. }
	{ Generally, only characters have threat values. }
var
	it: LongInt;
begin
	it := 0;

	while MList <> Nil do begin
		if GearActive( MList ) and ( MList^.G = GG_Character ) and ( NAttValue( MList^.NA , NAG_Location , NAS_TEam ) = Team ) then begin
			it := it + MList^.V;
		end;
		MList := MList^.Next;
	end;

	TeamTV := it;
end;

Procedure WaitAMinute( GB: GameBoardPtr; Mek: GearPtr; D: Integer );
	{ Force MEK to wait a short time, stopped if possible. }
var
	NextCall: LongInt;
begin
	Mek := FindRoot( Mek );
	NextCall := NAttValue( Mek^.NA , NAG_Action , NAS_CallTime );
	if ( GB <> Nil ) and ( NextCall < GB^.ComTime ) then NextCall := GB^.ComTime;
	NextCall := NextCall + D;
	if GB <> Nil then begin
		PrepAction( GB , Mek , NAV_Stop );
	end;
	SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , NextCall );
end;

initialization
	Destroyed_Parts_List := Nil;

finalization
	DisposeSAtt( Destroyed_Parts_List );

end.
