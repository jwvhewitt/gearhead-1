unit ArenaCFE;
	{ The Arena Combat Front End. }

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

Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon: GearPtr; X,Y,Z,AtOp: Integer );
Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon,Target: GearPtr; AtOp: Integer );
Procedure EffectFrontEnd( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );
Procedure StatusEffectCheck( GB: GameBoardPtr );


Procedure RandomExplosion( GB: GameBoardPtr );

Procedure AdvanceGameClock( GB: GameBoardPtr; DoStatus: Boolean );
Procedure QuickTime( GB: GameBoardPtr; Time: LongInt );


implementation

{$IFDEF SDLMODE}
uses ability,damage,effects,gearutil,ghchars,ghweapon,rpgdice,texutil,
     sdlinfo,sdlmap,sdlgfx;
{$ELSE}
uses ability,damage,effects,gearutil,ghchars,ghweapon,rpgdice,texutil,
     coninfo,conmap,context;
{$ENDIF}

Function DisplayAnnouncements( N: Integer ): Boolean;
	{ Display all the announcements stored for sequence slice N. }
	{ Return TRUE if an announcement was found, or FALSE otherwise. }
var
	L: String;
	A: SAttPtr;
	MessageFound: Boolean;
begin
	A := ATTACK_History;
	MessageFound := False;

	L := 'ANNOUNCE_' + BStr( N ) + '_';

	while A <> Nil do begin
		if HeadMatchesString( L , A^.Info ) then begin
			MessageFound := True;
			DialogMsg( RetrieveAString( A^.Info ) );
		end;
		A := A^.Next;
	end;

	DisplayAnnouncements := MessageFound;
end;

Procedure Display_Effect_History( GB: GameBoardPtr );
	{ Display all the messages stored by the attack routines and show all the }
	{ animations requested. }
var
	N: Integer;
	NoAnnounce,NoAnim: Boolean;
begin
	N := 0;

	{ Just keep going until we reach an iteration at which there are no more animations and }
	{ no more announcements to display. That's how we know that we're finished. }
	repeat
		NoAnnounce := Not DisplayAnnouncements( N );
		NoAnim := Not DisplayEffectAnimations( GB , N );

		Inc( N );
	until NoAnnounce and NoAnim;
end;

Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon: GearPtr; X,Y,Z,AtOp: Integer );
	{ This is a front end for the ATTACKER procedures. It calls those }
	{ procedures, and also informs the player of what's going on }
	{ both textually (description) and visually (graphics). }
var
	EMek: GearPtr;	{ Enemy Meks }
begin
	{ In SDL mode, do an update of the map before doing the attack, so that }
	{ every model will appear in its correct position. }
	{$IFDEF SDLMODE}
	DisplayMap( GB );
	{$ENDIF}

	{ Firing weapons automatically gives away one's position. }
	{ THIS CODE SHOULD BE MOVED INTO THE EFFECTS.PP PROCEDURE!!! }
	{ It's only still here since 0.601 is a bugfix release. Let's see }
	{ how long this comment remains in the code... :) }
	EMek := GB^.Meks;
	while EMek <> Nil do begin
		if AreEnemies( GB , EMek , Attacker ) and not MekCanSeeTarget( GB , EMek , Attacker ) then begin
			RevealMek( GB , Attacker , EMek );
		end;
		EMek := Emek^.Next;
	end;

	{ Actually do the attack. }
	DoAttack(GB,Weapon,Nil,X,Y,Z,AtOp,0);

	{ Report the effect of the attack. }
	Display_Effect_History( GB );

	{ AT the end, redisplay the map. }
	DisplayMap( GB );
end;

Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon,Target: GearPtr; AtOp: Integer );
	{ This is a front end for the ATTACKER procedures. It calls those }
	{ procedures, and also informs the player of what's going on }
	{ both textually (description) and visually (graphics). }
var
	EMek: GearPtr;	{ Enemy Meks }
begin
	DisplayGearInfo( Target , gb );

	{ In SDL mode, do an update of the map before doing the attack, so that }
	{ every model will appear in its correct position. }
	{$IFDEF SDLMODE}
	DisplayMap( GB );
	{$ENDIF}

	{ Firing weapons automatically gives away one's position. }
	{ THIS CODE SHOULD BE MOVED INTO THE EFFECTS.PP PROCEDURE!!! }
	{ It's only still here since 0.601 is a bugfix release. Let's see }
	{ how long this comment remains in the code... :) }
	EMek := GB^.Meks;
	while EMek <> Nil do begin
		if AreEnemies( GB , EMek , Attacker ) and not MekCanSeeTarget( GB , EMek , Attacker ) then begin
			RevealMek( GB , Attacker , EMek );
		end;
		EMek := Emek^.Next;
	end;

	{ Actually do the attack. }
	DoAttack(GB,Weapon,Target,0,0,0,AtOp,0);

	{ Report the effect of the attack. }
	Display_Effect_History( GB );
	DisplayGearInfo( Target , GB );

	{ AT the end, redisplay the map. }
	DisplayMap( GB );
end;

Procedure EffectFrontEnd( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );
	{ An effect string has just been triggered. Call the effect handler, }
	{ then display the outcome for the user. }
begin
	HandleEffectString( GB , Target , FX_String , FX_Desc );
	Display_Effect_History( GB );
end;

Procedure RandomExplosion( GB: GameBoardPtr );
	{ Stick a random explosion somewhere on the map. This procedure is used by the }
	{ BOMB ASL command. }
var
	X,Y: Integer;
begin
	{ In SDL mode, do an update of the map before doing the attack, so that }
	{ every model will appear in its correct position. }
	{$IFDEF SDLMODE}
	DisplayMap( GB );
	{$ENDIF}

	X := Random( XMax ) + 1;
	Y := Random( YMax ) + 1;
	Explosion( GB , X , Y , 5 , 8 );

	{ Report the effect of the attack. }
	Display_Effect_History( GB );
end;

Procedure StatusEffectCheck( GB: GameBoardPtr );
	{ Check all status effects, removing those which have expired }
	{ and performing effects for those which haven't. }
	{ This will also deal with a mecha's OVERLOAD condition, since }
	{ I want the count decremented every 3 minutes or so and it }
	{ would be inefficient to loop through the list twice. }
var
	M: GearPtr;
	FX,FX2: NAttPtr;
begin
	M := GB^.Meks;
	while M <> Nil do begin
		if GearActive( M ) then begin
			FX := M^.NA;
			while FX <> Nil do begin
				FX2 := FX^.Next;
				if ( FX^.G = NAG_StatusEffect ) then begin
					if SX_Effect_String[ FX^.S ] <> '' then begin
						EffectFrontEnd( GB , M , SX_Effect_String[ FX^.S ] , MSgString( 'Status_FXDesc' + BStr( FX^.S ) ) );
					end;

					if ( FX^.V > 0 ) and ( SX_ResistTarget[ FX^.S ] = -1 ) then begin
						{ Set rate of diminishment }
						if Random( 2 ) = 1 then Dec( FX^.V );
						if FX^.V = 0 then SetNAtt( M^.NA , NAG_StatusEffect , FX^.S , 0 );
					end else if ( FX^.V > 0 ) and ( RollStep( SkillValue( M , NAS_Resistance ) ) > SX_ResistTarget[ FX^.S ] ) then begin
						{ Diminishment determined by RESISTANCE }
						Dec( FX^.V );
						if FX^.V = 0 then SetNAtt( M^.NA , NAG_StatusEffect , FX^.S , 0 );
					end;
				end;
				FX := FX2;
			end;
		end;

		M := M^.Next;
	end;
end;

Procedure CyberneticsCheck( PC: GearPtr );
	{ Update the cybernetic trauma score for the PC. }
const
	Num_Disfunction = 12;
	Dis_Index: Array [1..Num_Disfunction] of Byte = (
		6,7,8,9,10, 11,12,13,14,15, 16,17
	);
	Dis_Cost: Array [1..Num_Disfunction] of Byte = (
		30,35,45,50,55, 60,65,70,80,85, 90,95
	);
var
	TT: Integer;	{ Trauma Target; the PC must beat this target }
		{ with a cybernetics roll in order to avoid disfunction. }
	SC: GearPtr;	{ Sub-Components of PC; looking for cyberware. }
	N: Integer;	{ Number of implants. }
	D: Integer;	{ Disfunction # }
begin
	{ To start with, add up all the trauma points the PC has. }
	TT := 0;
	N := 0;
	SC := PC^.SubCom;
	while SC <> Nil do begin
		if ( SC^.G = GG_Modifier ) then begin
			if SC^.V > 0 then TT := TT + SC^.V + 9;
			Inc( N );
		end;
		SC := SC^.Next;
	end;


	{ If there is any trauma, the PC must make a skill roll against it. }
	if TT > 0 then begin
		{ The current total is gonna be a bit high for a target }
		{ roll... reduce it and add 3. }
		TT := ( TT div 5 ) + 3;

		{ If the PC has the EXTROPIAN talent, and fewer implants than one-third }
		{ skill rank, there's no chance of disfunction. }
		{ Even if there are more implants, he'll get a bonus to the disfunction roll. }
		if HasTalent( PC , NAS_Extropian ) then begin
			D := NAttValue( PC^.NA , NAG_Skill , 24 );
			if ( N * 3 ) < D then begin
				Exit;
			end else begin
				TT := TT - D;
			end;
		end;

		{ If the skill roll fails, add trauma. }
		if RollStep( SkillValue( PC , 24 ) ) < TT then begin
			if HasTalent( PC , NAS_CyberPsycho ) and ( CurrentMental( PC ) > ( Random( 10 ) + 1 ) ) then begin
				AddNAtt( PC^.NA , NAG_Condition , NAS_MentalDown , 1 );
				AddMoraleDmg( PC , 2 );
			end else begin
				AddNAtt( PC^.NA , NAG_Condition , NAS_CyberTrauma , 1 );
			end;

			{ If the PC has enough trauma points to consider }
			{ getting a disfunction, deal with that now. }
			if NAttValue( PC^.NA , NAG_Condition , NAS_CyberTrauma ) > 72 then begin
				{ Select a disfunction at random. The PC might }
				{ get this if he doesn't already have it and }
				{ if it's cheap enough. }
				D := Random( Num_Disfunction ) + 1;
				if ( NAttValue( PC^.NA , NAG_StatusEffect , Dis_Index[ D ] ) = 0 ) and ( Random( NAttValue( PC^.NA , NAG_Condition , NAS_CyberTrauma ) ) > Dis_Cost[ D ] ) then begin
					SetNAtt( PC^.NA , NAG_StatusEffect , Dis_Index[ D ] , -1 );
					SetNAtt( PC^.NA , NAG_Condition , NAS_CyberTrauma , NAttValue( PC^.NA , NAG_Condition , NAS_CyberTrauma ) div 2 );
					DialogMsg( ReplaceHash( MsgString( 'Disfunction_' + BStr( D ) ) , GearName( PC ) ) );
				end;
			end;
		end;
	end;
end;

Procedure RegenerationCheck( MList: GearPtr );
	{ Go through MList and all siblings and all children. Any gears }
	{ found which are of type MEAT will recover one point of damage, }
	{ if damaged. }
const
	STAMINA_CHANCE = 30;	{ Determines speed of Stamina/Mental recovery. }
var
	MAT,Drain,Recovery,N,Morale: Integer;
	PCTeam,CanRegen: Boolean;
begin
	while MList <> Nil do begin
		PCTeam := ( NAttValue( MList^.NA , NAG_Location , NAS_Team ) = 1 ) and ( MList^.G = GG_Character );
		if PCTeam then Morale := NAttValue( MList^.NA , NAG_Condition , NAS_MoraleDamage );

		CanRegen := NAttValue( MList^.NA , NAG_StatusEffect , NAS_Anemia ) = 0;

		{ Whether or not a gear can regenerate is determined }
		{ by its material. }
		MAT := NAttValue( MList^.NA , NAG_GearOps , NAS_Material );
		if ( MAT < 0 ) or ( MAT > NumMaterial ) then MAT := 0;

		if MAT_Regenerate[ MAT ] and NotDestroyed( MList ) and CanRegen then begin
			{ If there's any HP damage, regenerate a point. }
			if ( NAttValue( MList^.NA , NAG_Damage , NAS_StrucDamage ) > 0 ) and ( Random( 200 ) < GearMaxDamage( MList ) ) then begin
				AddNAtt( MList^.NA , NAG_Damage , NAS_StrucDamage , -1 );
				if PCTeam then AddMoraleDmg( MList , MORALE_HPRegen );
			end;

			{ Natural armor heals *MUCH* more slowly than normal HP damage. }
			if ( NAttValue( MList^.NA , NAG_Damage , NAS_ArmorDamage ) > 0 ) and ( Random( 500 ) < GearMaxArmor( MList ) ) then begin
				AddNAtt( MList^.NA , NAG_Damage , NAS_ArmorDamage , -1 );
				if PCTeam then AddMoraleDmg( MList , MORALE_HPRegen );
			end;
		end;

		{ Also attempt to regenerate SP and MP here. }
		if MList^.G = GG_Character then begin
			Drain := NAttValue( MList^.NA , NAG_Condition , NAS_StaminaDown );
			if ( Drain > 0 ) and CanRegen then begin
				Recovery := 0;
				N := CharStamina( MList );
				if N > STAMINA_CHANCE then begin
					Recovery := N div STAMINA_CHANCE;
					N := N mod STAMINA_CHANCE;
				end;
				if Random( STAMINA_CHANCE ) <= N then Inc( Recovery );
				if Recovery > Drain then Recovery := Drain;
				AddNAtt( MList^.NA , NAG_Condition , NAS_StaminaDown , -Recovery );
				if PCTeam and ( Random( 8 ) = 1 ) then AddMoraleDmg( MList , 1 );
			end;

			Drain := NAttValue( MList^.NA , NAG_Condition , NAS_MentalDown );
			if ( Drain > 0 ) and CanRegen then begin
				Recovery := 0;
				N := CharMental( MList );
				if N > STAMINA_CHANCE then begin
					Recovery := N div STAMINA_CHANCE;
					N := N mod STAMINA_CHANCE;
				end;
				if Random( STAMINA_CHANCE ) <= N then Inc( Recovery );
				if Recovery > Drain then Recovery := Drain;
				AddNAtt( MList^.NA , NAG_Condition , NAS_MentalDown , -Recovery );
				if PCTeam and ( Random( 8 ) = 1 ) then AddMoraleDmg( MList , 1 );
			end;

			{ Characters also get hungry... }
			if PCTeam then begin
				AddNAtt( MList^.NA , NAG_Condition , NAS_Hunger , 1 );
				if NAttValue( MList^.NA , NAG_Condition , NAS_Hunger ) > Hunger_Penalty_Starts then begin
					DialogMsg( ReplaceHash( MsgString( 'REGEN_Hunger' ) , GearName( MList ) ) );
				end;

				{ Check for the cyber-disfunctions Depression, }
				{ Rejection, and Irrational ANger here. }
				if NAttValue( MList^.NA , NAG_StatusEffect , NAS_Rejection ) <> 0 then begin
					{ A character suffering REJECTION earns one extra trauma point per regen check. }
					AddNAtt( MList^.NA , NAG_Condition , NAS_CyberTrauma , 1 );
				end;
				if NAttValue( MList^.NA , NAG_StatusEffect , NAS_Depression ) <> 0 then begin
					{ A depressed character always loses morale. }
					AddMoraleDmg( MList , 1 );
				end;
				if NAttValue( MList^.NA , NAG_StatusEffect , NAS_Anger ) <> 0 then begin
					{ An angry character might pick up Villainous reputation. }
					if Random( 50 ) = 1 then AddReputation( MList , 1 , -1 );
				end;

				{ If nothing happened this regen check to make }
				{ the PC feel worse, morale moves one point }
				{ closer to zero. }
				if ( Random( 2 ) = 1 ) and ( Morale = NAttValue( MList^.NA , NAG_Condition , NAS_MoraleDamage ) ) then begin
					if Morale > 0 then begin
						AddNAtt( MList^.NA , NAG_Condition , NAS_MoraleDamage , -1 );
					end else if Morale < 0 then begin
						AddNAtt( MList^.NA , NAG_Condition , NAS_MoraleDamage , 1 );
					end;
				end;

				{ Check the PC's cyberware... }
				CyberneticsCheck( MList );
			end;
		end;

		{ Check the children - InvCom and SubCom. }
		RegenerationCheck( MList^.InvCom );
		RegenerationCheck( MList^.SubCom );

		{ Move to the next sibling. }
		MList := MList^.Next;
	end;
end;

Procedure ReduceOverload( GB: GameBoardPtr );
	{ Mecha lose one point of power overload every 10 seconds. }
var
	M: GearPtr;
begin
	M := GB^.Meks;
	while M <> Nil do begin
		{ Decrease OVERLOAD by 1 every 10 seconds }
		if ( M^.G = GG_Mecha ) and ( NAttValue( M^.NA , NAG_Condition , NAS_Overload ) > 0 ) then begin
			AddNAtt( M^.NA , NAG_Condition , NAS_Overload , -1 );
		end;
		M := M^.Next;
	end;
end;

Procedure AdvanceGameClock( GB: GameBoardPtr; DoStatus: Boolean );
	{ Increment the game clock and do any checks that need to be }
	{ done. }
begin
	Inc( GB^.ComTime );

	if ( GB^.Comtime mod AP_5Minutes ) = 0 then SetTrigger( GB , TRIGGER_FiveMinutes );
	if ( GB^.Comtime mod AP_HalfHour ) = 0 then SetTrigger( GB , TRIGGER_HalfHour );
	if ( GB^.Comtime mod AP_Hour ) = 0 then SetTrigger( GB , TRIGGER_Hour );
	if ( GB^.Comtime mod AP_Quarter ) = 0 then SetTrigger( GB , TRIGGER_Quarter );

	{ Mecha regenerate OVERLOAD every 10 seconds. }
	if ( GB^.ComTime mod 10 ) = 0 then begin
		ReduceOverload( GB );
	end;

	{ Once every 10 minutes, living gears regenerate. }
	if ( GB^.ComTime mod AP_10minutes ) = 0 then begin
		RegenerationCheck( GB^.Meks );
	end;

	{ Once every 3 minutes, update the status effects. }
    { Status effects will not take place during quicktime fast-forwards, }
    { when the player has no ability to react to them. This shall be known as }
    { the Cynjin Memorial Patch. }
	if (( GB^.ComTime mod AP_3minutes ) = 97) and DoStatus then StatusEffectCheck( GB );

end;

Procedure QuickTime( GB: GameBoardPtr; Time: LongInt );
	{ Advance time quickly by the specified amount. }
begin
	while Time > 0 do begin
		Dec( Time );
		AdvanceGameClock( GB, False );
	end;
	UpdateCombatDisplay( GB );
end;


end.
