unit effects;
	{ previosly attacker.pp }
	{ This unit handles attack, defense, and spells in GearHead. }
	{ Spells? What is this, a FRPG? Well, that's just how I usually }
	{ describe "special effects" such as healing, status changes, etc. }
	{ Eventually it may also describe psi powers and whatnot. }

	{ This unit does not concern itself with UI, so requesting }
	{ attacks and informing the user of their outcome }
	{ has to be done elsewhere. The EFFECTS_History variable }
	{ points to a list of SATTs describing the last processed }
	{ effect in full. It's up to the calling procedure to pass }
	{ this info on the user. }


	{ I've been prettying up this unit for the eventual introduction }
	{ of effects other than attacking. Getting rid of useless global }
	{ history variables, combining code when appropriate, removing }
	{ dependancy upon direct properties of gears... Still a long way }
	{ to go before this unit can be called "elegant", but at least }
	{ it's worlds better than pcaction.pp... }

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
	MOSMeasure = 5;	{ One Measure Of Success is gained for beating }
			{ the opponent's defense roll by this many points. }

	PenaltyPerDepth = 5;	{ Penalty for making called shots, per distance from root level. }
	PenaltyPerScale = 4;
	ClicksPerPenalty = 20;	{ For every 20dpr of a target's speed, there's a -1 modifier. }
	StopPenalty = 3;	{ Stopped mecha are easier to hit. }
	ImmobilePenalty = 15;	{ Broken down mecha are even easier. }

	StopBonus = 3;		{ It's easier to aim if you're standing still. }
	RunPenalty = 3;		{ It's harder to aim if you're traveling at full speed. }

	Parry_Bonus = 3;	{ Bonus to parrying an attack. }

	UnderwaterAttackPenalty = 3;	{ It's harder to aim if you're underwater. }

	Non_Weapon_MOS_Penalty = 2;	{ Non-weapons are less effective against armor. }
					{ This mostly applies to modules. }

	FlyingPenalty = 3;	{ Penalty for firing at an airborne unit without AntiAir weapon. }
	HighGroundBonus = 1;	{ Bonus for firing at a target lower than self. }

	CritHitMinTar = 25;	{ Minimum target number for Spot Weakness rolls. }
	LongRangePenalty = 3;
	ShortRangeBonus = 2;

	Has_Minimum_Range = 6;	{ Weapons with a range greater than this have a minimum useful range. }
			{ Attacks against targets within this minimum range happen at a penalty. }

	{ Animation directions are stored in the history list. }
	{ An animation direction may require some additional information, }
	{ as detailed below. }
	SAtt_Anim_Direction = 'ANIM_';
	
	GS_Shot = 1;		{ X1 Y1 Z1  X2 Y2 Z2 }
	GS_DamagingHit = 2;	{ X Y Z }
	GS_ArmorDefHit = 3;	{ X Y Z }
	GS_Parry = 4;		{ X Y Z }
	GS_Dodge = 5;		{ X Y Z }
	GS_Backlash = 6;	{ X Y Z }
	GS_AreaAttack = 7;	{ X Y Z }

	{ Maximum length of line when adding list of destroyed parts. }
	Damage_List_Text_Length = 170;

	FX_DoDamage = 0;
	FX_CauseStatusFX = 1;
	FX_DoHealing = 2;
	FX_Overload = 3;


var
	{ The variables in this unit hold values which may then be }
	{ examined by any calling procedures to determine the outcome }
	{ of the attack. }
	ATTACK_AttackRoll,ATTACK_HiDefRoll: Integer;
	ATTACK_Error,ATTACK_ItHit,ATTACK_Dodge,ATTACK_Parry,ATTACK_Resist: Boolean;
	ATTACK_DamageDone: Integer;
	ATTACK_MOS: Integer;	{ Attack Margin Of Success }
	ATTACK_NumberOfHits: Integer;
	ATTACK_AttSkillRank,ATTACK_DefSkillRank: Integer;
	ATTACK_AttackerDamage: Integer;

	ATTACK_History: SAttPtr;


Function ReadyToFire( GB: GameBoardPtr; User,Weapon: GearPtr ): Boolean;

Function ArcCheck( X0,Y0,D0,X1,Y1,A: Integer ): Boolean;
Function ArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y: Integer ): Boolean;
Function ArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;
Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y,Z: Integer ): Boolean;
Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;

Function AttackSkillNeeded( Attacker: GearPtr ): Integer;
Function CalcTotalModifiers( gb: GameBoardPtr; Attacker,Target: GearPtr; AtOp: Integer; AtAt: String ): Integer;

Procedure DestroyTerrain( GB: GameBoardPtr; X,Y: Integer );

Function BlastRadius( GB: GameBoardPtr; Attacker: GearPtr; AList: String ): Integer;

Procedure Explosion( GB: GameBoardPtr; X0,Y0,DC,R: Integer );

Procedure DoAttack( GB: GameBoardPtr; Attacker,Target: GearPtr; X,Y,Z,AtOp,AMod: Integer);

Procedure HandleEffectString( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );


implementation

uses ability,action,damage,gearutil,ghchars,ghmodule,ghguard,ghparser,
     ghprop,ghsensor,ghsupport,ghweapon,movement,rpgdice,skilluse,texutil,
	ghholder;

Type
	AttackFlags = Record
		CantCallShot: Boolean;
		CanDodge,CanBlock,CanParry,CanResist,CanIntercept,CanECM: Boolean;
		AtAt: String;
	end;

	EffectRequest = Record
		FXName: String;
		FXType: Integer;
		Originator,Weapon,Target: GearPtr;
		TX,TY: Integer;
		FXDice,FXOption,FXSkill,FXMod: Integer;
		AF: AttackFlags;
		FXDesc: String;
	end;

var
	EFFECTS_Event_Order: Integer;

	ATTACK_AMaster: GearPtr;
	ATTACK_TMaster,ATTACK_TPilot: GearPtr;

	ATTACK_TMasterOK: Boolean;		{ TRUE if master OK at start. }
	ATTACK_TPilotOK: Boolean;		{ TRUE if pilot OK at start. }
	ATTACK_TMasterMove: Boolean;		{ TRUE if master mobile at start. }

	FX_Messages: SAttPtr;

	Stencil: Array [ 1..XMax , 1..YMax ] of Boolean;


Procedure RecordAnnouncement( msg: String );
	{ Record an announcememnt in the history list. }
begin
	AddSAtt( ATTACK_History , 'ANNOUNCE_' + BStr( EFFECTS_Event_Order ) + '_' , msg );
end;

Procedure Add_Shot_Precisely( GB: GameBoardPtr; X0,Y0,Z0,X1,Y1,Z1: Integer );
	{ Add a shot animation to the history list. }
var
	msg: String;
begin
	msg := BStr( GS_Shot ) + ' ' + BStr( X0 ) + ' ' + BStr( Y0 ) + ' ' + BStr( Z0 );
	msg := msg + ' ' + BStr( X1 ) + ' ' + BStr( Y1 ) + ' ' + BStr( Z1 );

	AddSAtt( ATTACK_History , SAtt_Anim_Direction + BStr( EFFECTS_Event_Order ) + '_' , msg );
end;

Procedure Add_Shot_Animation( GB: GameBoardPtr; Attacker , Target: GearPtr );
	{ Add a shot animation to the history list. }
var
	P0,P1: Point;
begin
	Attacker := FindRoot( Attacker );
	Target := FindRoot( Target );

	P0 := GearCurrentLocation( Attacker );
	P0.Z := MekAltitude( GB , FindRoot( Attacker ) );

	P1 := GearCurrentLocation( Target );
	P1.Z := MekAltitude( GB , FindRoot( Target ) );

	Add_Shot_Precisely( GB , P0.X , P0.Y , P0.Z , P1.X , P1.Y , P1.Z );
end;

Procedure Add_Point_Animation( X,Y,Z: Integer; CMD: Integer );
	{ Add a shot animation to the history list. }
var
	msg: String;
begin
	msg := BStr( cmd ) + ' ' + BStr( X ) + ' ' + BStr( Y ) + ' ' + BStr( Z );

	AddSAtt( ATTACK_History , SAtt_Anim_Direction + BStr( EFFECTS_Event_Order ) + '_' , msg );
end;

Procedure Add_Mek_Animation( GB: GameBoardPtr; Target: GearPtr; CMD: Integer );
	{ Add a shot animation to the history list. }
var
	P: Point;
begin
	{ Find the location of the target, and just pass that on to }
	{ the point animation procedure above. }
	Target := FindRoot( Target );
	P := GearCurrentLocation( Target );
	Add_Point_Animation( P.X , P.Y , MekAltitude( GB , Target ) , CMD );
end;


Procedure ClearAttackHistory;
	{ Get rid of any history variables leftover from previous attacks. }
begin
	DisposeSAtt( ATTACK_History );
	EFFECTS_Event_Order := 0;
end;


Procedure INDICATE_Latest_Attack( GB: GameBoardPtr );
	{ Take all the stuff from the attack history values, and store it in the history }
	{ list. }
var
	msg: String;
	DP: SAttPtr;
begin
	{ Msg always starts with the target's name. }
	msg := PilotName( ATTACK_TMaster );

	{ If a part can't take damage, don't record a damage announcement. }
	if GearMaxDamage( ATTACK_TMAster ) = 0 then begin
		Exit;
	end else if ATTACK_Error then msg := msg + 'Error!'
	else if ATTACK_ItHit then begin
		if ATTACK_MOS > 3 then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_CritHit' );

		end else begin
			msg := msg + SAttValue( FX_Messages , 'CFE_NormHit' );
		end;

		{ indicate number of hits, if appropriate. }
		if ATTACK_NumberOfHits > 1 then begin
			msg := msg + BStr( ATTACK_NumberOfHits ) + SAttValue( FX_Messages , 'CFE_MultiHit' );
		end;

		{ indicate damage done. }
		if ATTACK_DamageDone > 0 then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_Damage1' ) + BStr( ATTACK_DamageDone ) + SAttValue( FX_Messages , 'CFE_Damage2' );

			msg := msg + '.';

			{ Add the list of destroyed parts now. }
			DP := Destroyed_Parts_List;
			while ( DP <> Nil ) and ( Length( msg ) < Damage_List_Text_Length ) do begin
				msg := msg + ' ' + DP^.Info + SAttValue( FX_Messages , 'CFE_Destroyed' );
				DP := DP^.Next;
			end;
		end else begin
			msg := msg + SAttValue( FX_Messages , 'CFE_NoDamage' );
		end;


	end else if ATTACK_Parry then begin
		if ( ATTACK_AttSkillRank + 1 + Random( 8 ) ) < ATTACK_DefSkillRank then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_EasyParry' );

		end else if ( ATTACK_AttSkillRank - 1 - Random( 8 ) ) > ATTACK_DefSkillRank then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_HardParry' );

		end else begin
			msg := msg + SAttValue( FX_Messages , 'CFE_Parry' );
		end;

	end else if ATTACK_Resist then begin
		if ( ATTACK_AttSkillRank + 1 + Random( 8 ) ) < ATTACK_DefSkillRank then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_EasyResist' );

		end else if ( ATTACK_AttSkillRank - 1 - Random( 8 ) ) > ATTACK_DefSkillRank then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_HardResist' );

		end else begin
			msg := msg + SAttValue( FX_Messages , 'CFE_Resist' );
		end;

	end else begin
		if ( ATTACK_AttSkillRank + 1 + Random( 8 ) ) < ATTACK_DefSkillRank then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_EasyEvade' );

		end else if ( ATTACK_AttSkillRank - 1 - Random( 8 ) ) > ATTACK_DefSkillRank then begin
			msg := msg + SAttValue( FX_Messages , 'CFE_HardEvade' );

		end else begin
			msg := msg + SAttValue( FX_Messages , 'CFE_Evade' );
		end;
	end;

	if ATTACK_TMasterOK and Destroyed(ATTACK_TMaster) then msg := msg + ' ' + GearName( ATTACK_TMaster ) + ' is destroyed!';

	{ Gotta check that the attack hit, since if the DAMAGE procedure }
	{ wasn't called the history variables might be holding leftover }
	{ information. }
	if ATTACK_TPilotOK and ATTACK_ItHit then begin
		if DAMAGE_EjectRoll then begin
			if DAMAGE_PilotDied then msg := msg + ' ' + GearName( ATTACK_TPilot ) + ' didn''t eject in time!'
			else if DAMAGE_EjectOK then msg := msg + ' ' + GearName( ATTACK_TPilot ) + ' ejected!';
		end else if Destroyed(ATTACK_TPilot) then msg := msg + ' ' + GearName( ATTACK_TPilot ) + ' died!';
	end;

	RecordAnnouncement( msg );

	{ Add the correct animation. }
	if ATTACK_Parry or ATTACK_Resist then begin
		Add_Mek_Animation( GB , ATTACK_TMaster , GS_Parry );
	end else if ATTACK_ItHit then begin
		if ( ATTACK_DamageDone > 0 ) then begin
			Add_Mek_Animation( GB , ATTACK_TMaster , GS_DamagingHit );
		end else begin
			Add_Mek_Animation( GB , ATTACK_TMaster , GS_ArmorDefHit );
		end;
	end else begin
		Add_Mek_Animation( GB , ATTACK_TMaster , GS_Dodge );
	end;
	if ATTACK_AttackerDamage > 0 then begin
		Add_Mek_Animation( GB , ATTACK_AMaster , GS_Backlash );
	end;
end;

Procedure INDICATE_Attack_Effect( GB: GameBoardPtr; EffectDesc: String );
	{ Indicate effect stuff here. }
var
	msg: String;
	DP: SAttPtr;
begin
	{ Miscellaneous effect only reported if target suffered damage. }
	if GearMaxDamage( ATTACK_TMAster ) = 0 then begin
		Exit;
	end else if ATTACK_ItHit and ( ATTACK_DamageDone > 0 ) then begin
		{ Msg always starts with the target's name. }
		msg := ReplaceHash( EffectDesc , PilotName( ATTACK_TMaster ) );
		msg := ReplaceHash( msg , BStr( ATTACK_DamageDone ) );

		{ Add the list of destroyed parts now. }
		DP := Destroyed_Parts_List;
		while ( DP <> Nil ) and ( Length( msg ) < Damage_List_Text_Length ) do begin
			msg := msg + ' ' + DP^.Info + SAttValue( FX_Messages , 'CFE_Destroyed' );
			DP := DP^.Next;
		end;

		if ATTACK_TMasterOK and Destroyed(ATTACK_TMaster) then msg := msg + ' ' + GearName( ATTACK_TMaster ) + ' is destroyed!';

		if ATTACK_TPilotOK then begin
			if DAMAGE_EjectRoll then begin
				if DAMAGE_PilotDied then msg := msg + ' ' + GearName( ATTACK_TPilot ) + ' didn''t eject in time!'
				else if DAMAGE_EjectOK then msg := msg + ' ' + GearName( ATTACK_TPilot ) + ' ejected!';
			end else if Destroyed(ATTACK_TPilot) then msg := msg + ' ' + GearName( ATTACK_TPilot ) + ' died!';
		end;

		RecordAnnouncement( msg );

		Add_Mek_Animation( GB , ATTACK_TMaster , GS_DamagingHit );
	end;
	if ATTACK_AttackerDamage > 0 then begin
		Add_Mek_Animation( GB , ATTACK_AMaster , GS_Backlash );
	end;
end;

Function InGeneralInventory( Part: GearPtr ): Boolean;
	{ If in the general inventory, it may be thrown. }
begin
	InGeneralInventory := IsInvCom( Part ) and ( Part^.Parent = FindMaster( Part ) );
end;

Function MustBeThrown( GB: GameBoardPtr; Master, Weapon: GearPtr; TX,TY: Integer ): Boolean;
	{ Return TRUE if WEAPON must be thrown in order to hit TARGET. }
	{ Return FALSE if WEAPON could be used normally, i.e. not thrown. }
	{ A weapon will only be thrown if it could not be used against }
	{ the target otherwise- this is because throwing a weapon is a }
	{ pain in the arse. You've got to go pick it up afterwards. }
begin
	if Weapon^.G = GG_Ammo then begin
		{ If you're attacking with ammo, that better be a grenade. }
		MustBeThrown := True;
	end else if InGeneralInventory( Weapon ) then begin
		{ If this weapon is in the general inventory, it must }
		{ have been thrown. }
		MustBeThrown := True;
	end else begin
		{ If the attack range is greater than the regular weapon }
		{ range, then the weapon must have been thrown. }
		MustBeThrown := ( ThrowingRange( GB , Master , Weapon ) > 0 ) and OnTheMap( TX , TY ) and ( Range( Master , TX , TY ) > WeaponRange( GB , Weapon ) );
	end;
end;

Function ReadyToFire( GB: GameBoardPtr; User,Weapon: GearPtr ): Boolean;
	{ Return TRUE if the gear in question is ready to perform an attack, }
	{ or FALSE if it is currently unable to do so. }
	{ Check to make sure that... }
	{     1) ATTACKER is a functional part. }
	{     2) ATTACKER is a part that can be used in attack. }
	{     3) ATTACKER has sufficient ammunition to attack. }
	{     4) COMTIME is greater or equal to the RECHARGE time. }
	{     5) ATTACKER is mounted in a usable limb. }
	{     6) ATTACKER's MASTER is the same as ATTACKER's ROOT. }
var
	AttackOK: Boolean;
begin
	{ This first check will return false if Weapon is nil, so I won't check here. }
	{ Throwable weapons don't have to be in a good module- they can }
	{ be in the general inventory. }
	{ v0.909 - Added check for safety switch. }
	if ( Weapon <> Nil ) and ( User <> Nil ) and ( ThrowingRange( GB, USer, Weapon ) > 0 ) then begin
		AttackOK := PartActive( Weapon ) and ( NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) = 0 );
	end else begin
		AttackOK := PartActive( Weapon ) and InGoodModule( Weapon ) and ( NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) = 0 );
	end;

	if AttackOK then begin
		{ Applicability Check }
		if ( Weapon^.G = GG_Weapon ) then begin
			{ Normally, all weapons may be used to attack. Duh. }
			{ However, ballistic and missile weapons can't attack }
			{ if they have no ammo left. }
			if ( Weapon^.S = GS_Ballistic ) or ( Weapon^.S = GS_Missile ) then begin
				if LocateGoodAmmo( Weapon ) = Nil then AttackOK := False;
			end;

		end else if Weapon^.G = GG_Module then begin
			{ Only Arms, Legs, and Tails may be used. }
			if ( Weapon^.S <> GS_Arm ) and ( Weapon^.S <> GS_Leg ) and ( Weapon^.S <> GS_Tail ) then begin
				AttackOK := False;
			end;

		end else if Weapon^.G = GG_Ammo then begin
			if Weapon^.S <> GS_Grenade then AttackOK := False;
			if not InGeneralInventory( Weapon ) then AttackOK := False;

		end else begin
			{ No other parts may be used to attack. So, }
			{ set AttackOK to False. }
			AttackOK := False;

		end;

		{ ComTime Check }
		if NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_Recharge ) > GB^.ComTime then AttackOK := False;

		{ If yer piloting a mecha can't punch the other guy yourself Check }
		if FindMaster( Weapon ) <> FindRoot( Weapon ) then AttackOK := False;
	end;

	ReadyToFire := AttackOK;
end;

Function ArcCheck( X0,Y0,D0,X1,Y1,A: Integer ): Boolean;
	{ CHeck that point X1,Y1 falls within Arc A as relative to }
	{ point X0,Y0 with direction D0. }
var
	OK: Boolean;
begin
	if A = ARC_360 then OK := True
	else if A = ARC_F90 then begin
		if CheckArc( X0 , Y0 , X1 , Y1 , D0 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 7 ) mod 8 ) then OK := True
		else OK := False;
	end else begin
		{ ASSERT -> A is ARC_F180 }
		if CheckArc( X0 , Y0 , X1 , Y1 , D0 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 7 ) mod 8 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 1 ) mod 8 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 6 ) mod 8 ) then OK := True
		else OK := False;
	end;

	ArcCheck := OK;
end;

Function ArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y: Integer ): Boolean;
	{ Return TRUE if the target is in an appropriate fire arc for }
	{ WEAPON, or FALSE otherwise. }
var
	X0 , Y0 , D: Integer;	{ Position of the firer. }
	A: Integer;	{ Range and Arc of the attack. }
begin
	if ( Master = Nil ) or ( Weapon = Nil ) then Exit( False );

	if Master^.Parent <> Nil then Master := FindRoot( Master );

	X0 := NAttValue( Master^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( Master^.NA , NAG_Location , NAS_Y );

	D := NAttValue( Master^.NA , NAG_Location , NAS_D );
	A := WeaponArc( Weapon );

	{ Now check Range and Arc. }
	ArcCheck := ArcCheck( X0 , Y0 , D , X , Y , A );
end;

Function ArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;
	{ Return TRUE if the target is in an appropriate fire arc for }
	{ WEAPON, or FALSE otherwise. }
var
	X0 , Y0 , D , X , Y: Integer;	{ Position of the firer. }
	A: Integer;	{ Range and Arc of the attack. }
begin
	if ( Target = Nil ) or ( Master = Nil ) or ( Weapon = Nil ) then Exit( False );

	if Target^.Parent <> Nil then Target := FindRoot( Target );
	if Master^.Parent <> Nil then Master := FindRoot( Master );

	X := NAttValue( Target^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Target^.NA , NAG_Location , NAS_Y );
	X0 := NAttValue( Master^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( Master^.NA , NAG_Location , NAS_Y );

	D := NAttValue( Master^.NA , NAG_Location , NAS_D );
	A := WeaponArc( Weapon );

	{ Now check Range and Arc. }
	ArcCheck := ArcCheck( X0 , Y0 , D , X , Y , A );
end;

Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y,Z: Integer ): Boolean;
	{ Check the range, arc, and cover between the listed gear and the listed tile. }
	{ Returns true if the shot can take place, false otherwise. }
var
	X0,Y0,D,A: Integer;
	rng: Integer;	{ Range and Arc of the attack. }
	OK: Boolean;
begin
	{ Calculate Range and Arc. }
	rng := WeaponRange( GB , Weapon );

	X0 := NAttValue( Master^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( Master^.NA , NAG_Location , NAS_Y );
	D := NAttValue( Master^.NA , NAG_Location , NAS_D );
	A := WeaponArc( Weapon );

	OK := ArcCheck( X0 , Y0 , D , X , Y , A );

	{ If out of range, no shot is possible. }
	if OK and ( Range( Master , X , Y ) > rng ) then begin
		{ OK is false, unless the target is within throwing range. }
		OK := ThrowingRange( GB , Master , Weapon ) >= Range( Master , X , Y );
	end;

	{ If Line of Sight is blocked, no shot is possible. }
	if OK and ( CalcObscurement( X0 , Y0 , MekALtitude( GB , Master ) , X , Y , Z , gb ) = -1 ) then OK := False;

	RangeArcCheck := OK;
end;

Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;
	{ Check the range, arc, and cover between the listed gear and the listed tile. }
	{ Returns true if the shot can take place, false otherwise. }
var
	X , Y: Integer;	{ Position of the firer. }
begin
	{ Determine initial values for all the stuff. }
	if Target = Nil then Exit( False );
	if Target^.Parent <> Nil then Target := FindRoot( Target );
	X := NAttValue( Target^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Target^.NA , NAG_Location , NAS_Y );

	RangeArcCheck := RangeArcCheck( GB , Master , Weapon , X , Y , MekALtitude( GB , Target ) );
end;

Function RechargeTime( Attacker: GearPtr; AtOp: Integer ): Integer;
	{ Return the modified recharge time for this weapon. }
var
	WAO: GearPtr;
	it: Integer;
begin
	if Attacker^.G = GG_Weapon then begin
		it := Attacker^.Stat[STAT_Recharge];
	end else begin
		it := 2;
	end;

	{ Modify for weapon token. }
	WAO := Attacker^.InvCom;
	while WAO <> Nil do begin
		if ( WAO^.G = GG_WeaponAddOn ) and NotDestroyed( WAO ) then begin
			it := it + WAO^.Stat[ STAT_Recharge ];
		end;
		WAO := WAO^.Next;
	end;

	if ( Attacker^.G = GG_Weapon ) and ( Attacker^.S = GS_BeamGun ) and ( AtOp > 0 ) then begin
		{ Beamguns which use rapid fire take MUCH longer to recharge than normal. }
		RechargeTime := 2 * ClicksPerRound div it;
	end else begin
		RechargeTime := ClicksPerRound div it;
	end;
end;

Function ClearAttack( GB: GameBoardPtr; Attacker: GearPtr ; var AtOp: Integer ): Boolean;
	{ This function sets up the weapon for performing an attack. }
	{ It reduces ammo count by an appropriate amount. }
	{ It sets the RECHARGE attribute. }
	{ Return TRUE if everything is okay, FALSE if there's some reason }
	{ why this attack can't take place. }
	{ Note that this function does not do a range check. }
var
	AttackOK: Boolean;
	Ammo: GearPtr;
begin
	{ First, make sure that this attack can even take place. }
	{ Check to make sure that ATTACKER is active. }
	AttackOK := ReadyToFire( GB , FindRoot( Attacker ) , Attacker );

	if AttackOK and ( Attacker^.G = GG_Weapon ) then begin

		{ Do an ammunition check for projectile weapons and missiles. }
		if ( Attacker^.S = GS_Missile ) or (( Attacker^.S = GS_Ballistic ) and ( Attacker^.Stat[STAT_Magazine] > 0 )) then begin
			{ Locate the ammo to be used. }
			Ammo := LocateGoodAmmo( Attacker );

			if Ammo <> Nil then begin
				{ Reduce the ammo count by an appropriate amount. }

				{ AtOp is the number of missiles being fired. }
				{ If this goes over the number of missiles present, correct that problem. }
				if ( AtOp > 0 ) then begin
					if ( Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) < (AtOp + 1) then begin
						AtOp := ( Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) - 1;
					end;
				end;

				{ Do the actual ammo count thing here. }
				AddNAtt( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent , AtOp + 1 );

			end else begin
				{ This weapon has no ammo. The attack cannot proceed. }
				AttackOK := False;

			end;
		end;

	end else if Attacker^.G = GG_Ammo then begin
		{ Grenades don't get a choice what AtOp they use. }
		AtOp := Attacker^.Stat[ STAT_BurstValue ];
	end;

	{ Set the recharge time now. }
	if AttackOK then begin
		SetNAtt( Attacker^.NA , NAG_WeaponModifier , NAS_Recharge , GB^.ComTime + RechargeTime( Attacker , AtOp ) );
	end;

	ClearAttack := AttackOK;
end;

Function AttackSkillNeeded( Attacker: GearPtr ): Integer;
	{ Return the index number of the skill used to attack with this }
	{ particular weapon. }
var
	ASkill: Integer;
	AMaster: GearPtr;
begin
	{ The skills for human-scale and mecha-scale are set up in }
	{ the same order, with the mecha skills being 1 to 5 and the }
	{ personal skills being 6 to 10. So, just find the skill number }
	{ based on ATTACKER's type, then add +5 if the master is a }
	{ character instead of a mecha. }


	if Attacker^.G = GG_Weapon then begin
		if ( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee ) then begin
			{ Use armed combat/weapons skill. }
			ASkill := 3;
		end else if ( Attacker^.S = GS_Ballistic ) or ( Attacker^.S = GS_BeamGun ) then begin
			{ Use gunnery/small arms if DC is 10 or less, }
			{ use artillery/heavy if DC is 11 or greater. }
			if Attacker^.V <= 10 then begin
				ASkill := 1;
			end else begin
				ASkill := 2;
			end;
		end else begin
			{ Must be a missile launcher- use heavy/artillery skill. }
			ASkill := 2;
		end;

	end else if Attacker^.G = GG_Ammo then begin
		{ Grenades use Heavy Weapons/Artillery skill by }
		{ default, but may redefine this freely. I did so }
		{ to allow the creation of shurikens, cans of mace, }
		{ and other derivitaves from the grenade code. }
		ASkill := Attacker^.Stat[ STAT_GrenadeSkill ];

	end else begin
		{ Not a weapon- use Fighting/Martial Arts. }
		ASkill := 4;
	end;

	{ If the master is a character, add +5 to the skill index. }
	AMaster := FindMaster( Attacker );
	if ( AMaster <> Nil ) and ( AMaster^.G = GG_Character ) then begin
		ASkill := ASkill + 5;
	end;

	{ Return the value we found. }
	AttackSkillNeeded := ASkill;
end;

Function AttemptShieldBlock(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Attempt to block an attack using a shield. Return the defense }
	{ roll result, or 0 if no shield could be found. }
var
	DefGear: GearPtr;
	DefSkill,DefRoll: Integer;

	Procedure SeekShield( Part: GearPtr );
		{ Seek a shield which is capable of parrying an attack. }
	begin
		while ( Part <> Nil ) do begin
			if NotDestroyed( Part ) then begin
				if ( Part^.G = GG_Shield ) and InGoodModule( Part ) then begin
					if ( NAttValue( Part^.NA , NAG_WeaponModifier , NAS_Recharge ) <= GB^.ComTime ) and ( ( Attacker = Nil ) or ( Part^.Scale >= Attacker^.Scale ) ) then begin
						if DefGear = Nil then DefGear := Part;
					end;
				end;
				if ( Part^.SubCom <> Nil ) then SeekShield( Part^.SubCom );
				if ( Part^.InvCom <> Nil ) then SeekShield( Part^.InvCom );
			end;
			Part := Part^.Next;
		end;
	end;
begin
	{ Try to find a shield. }
	DefGear := Nil;
	DefRoll := 0;
	SeekShield( TMaster^.SubCom );

	{ If a shield is found, proceed with the defense roll... }
	if DefGear <> Nil then begin
		{ Find the appropriate skill value. }
		if TMaster^.G = GG_Mecha then begin
			{ For mecha, this will be Mecha Fighting }
			DefSkill := 4;
		end else begin
			{ For characters, this will be Armed Combat }
			DefSkill := 8;
		end;

		ATTACK_DefSkillRank := SkillValue( TMaster , DefSkill );

		{ Set the recharge time for the shield. }
		SetNAtt( DefGear^.NA , NAG_WeaponModifier , NAS_Recharge , GB^.ComTime + ( ClicksPerRound div 3 ) );

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , DefSkill , XPA_SK_Basic );

		{ Make the skill roll + Shield Bonus }
		DefRoll := RollStep( ATTACK_DefSkillRank ) + DefGear^.Stat[ STAT_ShieldBonus ];

		{ If the parry was successful, there will be some after-effects. }
		if DefRoll >= SkRoll then begin
			{ The shield is going to take damage from the hit, whether it was an }
			{ energy shield or a beam shield- but beam shields only take damage }
			{ from energy weapons. }
			if ATtacker <> Nil then begin
				if DefGear^.S = GS_EnergyShield then begin
					if CanDamageBeamShield( Attacker ) then begin
						DamageGear( GB , DefGear , Attacker , Attacker^.V , 0 , 1 , '' );
					end;
				end else begin
					{ Physical shields take damage from everything. }
					DamageGear( GB , DefGear , Attacker , Attacker^.V , 0 , 1 , '' );
				end;

				{ An energy shield will do damage back to any CC weapon that hits it. }
				if ( DefGear^.S = GS_EnergyShield ) then begin
					if ( Attacker^.G = GG_Module ) or ( Attacker^.S = GS_Melee ) then begin
						ATTACK_AttackerDamage := ATTACK_AttackerDamage + DamageGear( GB , Attacker , DefGear , DefGear^.V , 0 , 1 , '' );
					end;
				end;
			end;

		end;
	end;

	AttemptShieldBlock := DefRoll;
end;

Function AttemptParry(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Try to parry this attack, if it is in fact parryable. }
var
	DefGear: GearPtr;
	DefSkill,DefRoll: Integer;
	Procedure SeekParryWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of parrying an attack. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Weapon ) and (( Part^.S = GS_Melee ) or ( Part^.S = GS_EMelee )) then begin
				if ReadyToFire( GB , Nil , Part ) and InGoodModule( Part ) and ( ( Attacker = Nil ) or ( Part^.Scale >= Attacker^.Scale ) ) then begin
					if DefGear = Nil then DefGear := Part
					else if Part^.Stat[STAT_Accuracy] > DefGear^.Stat[STAT_Accuracy] then DefGear := Part;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekParryWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekParryWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;

begin
	DefRoll := 0;

	{ Search for a usable CC weapon. }
	DefGear := Nil;
	SeekParryWeapon( TMaster^.SubCom );

	{ If one was found, do the parry attempt. }
	if DefGear <> Nil then begin
		{ Make an attack roll to parry. }
		DefSkill := AttackSkillNeeded( DefGear );

		ATTACK_DefSkillRank := SkillValue( TMaster , DefSkill );

		DefRoll := RollStep( ATTACK_DefSkillRank + Parry_Bonus ) + DefGear^.Stat[ STAT_Accuracy ];

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , DefSkill , XPA_SK_Basic );

		{ If the parry was successful, there will be some after-effects. }
		if DefRoll >= SkRoll then begin
			{ After a succeful parry, weapon is "tapped". }
			DefSkill := 0;
			ClearAttack( GB , DefGear , DefSkill );

			{ If the parrying weapon is not an energy weapon, }
			{ it will take damage from the parrying attempt. }
			if Attacker <> Nil then begin
				if ( DefGear^.S <> GS_EMelee ) then begin
					if ( Attacker^.G = GG_Weapon ) and ( Attacker^.S = GS_EMelee ) then begin
						DamageGear( GB , DefGear , Attacker , Attacker^.V , 0 , 1 , '' );
					end else begin
						DamageGear( GB , DefGear , Attacker , 1 , 0 , 1 , '' );
					end;

				{ If the parrying weapon is an energy weapon, then }
				{ the attacker's weapon is going to take damage unless }
				{ it too is an energy weapon. }
				end else if ( Attacker^.G <> GG_Weapon ) or ( Attacker^.S <> GS_Emelee ) then begin
					ATTACK_AttackerDamage := ATTACK_AttackerDamage + DamageGear( GB , Attacker , DefGear , DefGear^.V , 0 , 1 , '' );
				end;
			end;
		end;
	end;

	{ Return the resultant defense roll. }
	AttemptParry := DefRoll;
end;

Function AttemptIntercept(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Try to intercept this attack. }
var
	DefGear: GearPtr;
	DefSkill,DefRoll: Integer;
	Procedure SeekInterceptWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of intercepting an attack. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Weapon ) and HasAttackAttribute( WeaponAttackAttributes( Part ) , AA_Intercept ) then begin
				if ReadyToFire( GB , Nil , Part ) and InGoodModule( Part ) and ( ( Attacker = Nil ) or ( Part^.Scale >= Attacker^.Scale ) ) then begin
					if DefGear = Nil then DefGear := Part
					else if Part^.Stat[STAT_Accuracy] > DefGear^.Stat[STAT_Accuracy] then DefGear := Part;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekInterceptWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekInterceptWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;

begin
	DefRoll := 0;

	{ Search for a usable CC weapon. }
	DefGear := Nil;
	SeekInterceptWeapon( TMaster^.SubCom );

	{ If one was found, do the parry attempt. }
	if DefGear <> Nil then begin
		{ Make an attack roll to parry. }
		DefSkill := AttackSkillNeeded( DefGear );

		ATTACK_DefSkillRank := SkillValue( TMaster , DefSkill );

		DefRoll := RollStep( ATTACK_DefSkillRank + DefGear^.V ) + DefGear^.Stat[ STAT_Accuracy ] + DefGear^.Stat[ STAT_BurstValue ];

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , DefSkill , XPA_SK_Basic );

		{ If the parry was successful, there will be some after-effects. }
		if DefRoll >= SkRoll then begin
			{ After a succeful parry, weapon is "tapped". }
			ClearAttack( GB , DefGear , DefSkill );
		end;
	end;

	{ Return the resultant defense roll. }
	AttemptIntercept := DefRoll;
end;

Function AttemptEWBlock(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Try to stop this attack using Electronic Counter-Measures. }
var
	DefGear: GearPtr;
	DefRoll: Integer;
begin
	DefRoll := 0;

	{ Search for a usable CC weapon. }
	DefGear := SeekActiveIntrinsic( TMaster , GG_Sensor , GS_ECM );

	{ If one was found, do the parry attempt. }
	if DefGear <> Nil then begin
		{ Make an attack roll to block. }
		ATTACK_DefSkillRank := SkillValue( TMaster , 17 );

		DefRoll := RollStep( ATTACK_DefSkillRank + DefGear^.V - 5 );

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , 17 , XPA_SK_Basic );
	end;

	{ Return the resultant defense roll. }
	AttemptEWBlock := DefRoll;
end;

Function AttemptResist(GB: GameBoardPtr; TMaster: GearPtr ): Integer;
	{ Attempt to resist damage using either the RESISTANCE or }
	{ ELECTRONIC WARFARE skills, depending upon whether the target }
	{ is a character or a mecha. }
begin
	if TMaster^.G = GG_MEcha then begin
		{ Mecha use ELECTRONIC WARFARE. }
		ATTACK_DefSkillRank := SkillValue( TMaster , 17 );
		DoleSkillExperience( TMaster , 17 , XPA_SK_Basic );
	end else begin
		{ Characters use RESISTANCE. }
		ATTACK_DefSkillRank := SkillValue( TMaster , 36 );
		DoleSkillExperience( TMaster , 36 , XPA_SK_Basic );
	end;

	{ Return the resultant defense roll. }
	AttemptResist := RollStep( ATTACK_DefSkillRank );
end;

Function AttemptDefenses( GB: GameBoardPtr; TMaster,Attacker: GearPtr; SkRoll: Integer; AF: AttackFlags ): Integer;
	{ The target has just been attacked. Roll any appropriate }
	{ defenses. Return the highest defense roll. }
var
	DefRoll,HiDefRoll: Integer;
begin
	{ First, check to see if this attack will be ineffective. }
	if HasAttackAttribute( AF.AtAt , AA_NoMetal ) and ( NAttValue( TMaster^.NA , NAG_GearOps , NAS_Material ) = NAV_Metal ) then begin
		ATTACK_Dodge := True;
		Exit( 256 );
	end;

	{ All attacks get a dodge attempt. }
	{ Make the dodge roll, then dole appropriate experience. }
	HiDefRoll := 0;
	ATTACK_Dodge := False;
	ATTACK_Parry := False;
	ATTACK_Resist := False;
	if AF.CanDodge then begin
		if TMaster^.G = GG_MEcha then begin
			{ Mecha use Mecha Piloting. }
			ATTACK_DefSkillRank := SkillValue( TMaster , 5 );
			DoleSkillExperience( TMaster , 5 , XPA_SK_Basic );

			{ Adjust the dodge skill value for talents. }
			if ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveMode ) = MM_Walk ) and HasTalent( TMaster , NAS_SureFooted ) then begin
				ATTACK_DefSkillRank := ATTACK_DefSkillRank + 2;
			end else if ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveMode ) = MM_Fly ) and HasTalent( TMaster , NAS_BornToFly ) then begin
				ATTACK_DefSkillRank := ATTACK_DefSkillRank + 3;
			end else if ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveMode ) = MM_Roll ) and HasTalent( TMaster , NAS_RoadHog ) then begin
				ATTACK_DefSkillRank := ATTACK_DefSkillRank + 2;
			end;
		end else begin
			{ Characters use Dodge. }
			ATTACK_DefSkillRank := SkillValue( TMaster , 10 );
			DoleSkillExperience( TMaster , 10 , XPA_SK_Basic );
		end;
		HiDefRoll := RollStep( ATTACK_DefSkillRank );
		ATTACK_Dodge := HiDefRoll >= SkRoll;
	end;

	{ Attempt ECM defense. }
	if AF.CanECM and ( HiDefRoll < SkRoll ) then begin
		DefRoll := AttemptEWBlock( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > HiDefRoll then begin
			HiDefRoll := DefRoll;
			ATTACK_Dodge := HiDefRoll >= SkRoll;
		end;
	end;

	{ Attempt physical shield parry, if charged. }
	if AF.CanBlock and ( HiDefRoll < SkRoll ) then begin
		DefRoll := AttemptShieldBlock( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > HiDefRoll then begin
			HiDefRoll := DefRoll;
			ATTACK_Parry := HiDefRoll >= SkRoll;
		end;
	end;

	{ Attempt anti-missile intercept. }
	if AF.CanIntercept and ( HiDefRoll < SkRoll ) then begin
		DefRoll := AttemptIntercept( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > HiDefRoll then begin
			HiDefRoll := DefRoll;
			ATTACK_Parry := HiDefRoll >= SkRoll;
		end;
	end;

	{ If a close combat attack, attempt a parry with any active }
	{ CC weapon. }
	if AF.CanParry and ( HiDefRoll < SkRoll ) then begin
		DefRoll := AttemptParry( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > HiDefRoll then begin
			HiDefRoll := DefRoll;
			ATTACK_Parry := HiDefRoll >= SkRoll;
		end;
	end;

	{ If resistable, try to resist. }
	if AF.CanResist and ( HiDefRoll < SkRoll ) then begin
		DefRoll := AttemptResist( GB , TMaster );
		if DefRoll > HiDefRoll then begin
			HiDefRoll := DefRoll;
			ATTACK_Resist := HiDefRoll >= SkRoll;
		end;
	end;

	{ Attempt HapKiDo block. }
	{ Can only do this if it's a character being attacked, the }
	{ talent is know, the character isn't tired... }
	if AF.CanBlock and ( HiDefRoll < SkRoll ) and ( TMaster^.G = GG_CHaracter ) and HasTalent( TMaster , NAS_HapKiDo ) and ( CharCurrentStamina( TMaster ) > 0 ) then begin
		ATTACK_DefSkillRank := SkillValue( TMaster , 9 );
		DefRoll := RollStep( ATTACK_DefSkillRank );
		AddStaminaDown( TMaster , 1 );
		if DefRoll > HiDefRoll then begin
			HiDefRoll := DefRoll;
			ATTACK_Parry := HiDefRoll >= SkRoll;
		end;
	end;

	{ Attempt Stunt Driving dodge. }
	{ Can only do this if it's a mecha being attacked, the }
	{ talent is know, and they're moving at full speed, and the }
	{ pilot has stamina points left... }
	if AF.CanDodge and ( HiDefRoll < SkRoll ) and ( TMaster^.G = GG_Mecha ) and HasTalent( TMaster , NAS_StuntDriving ) and ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveAction ) = NAV_FullSpeed ) and ( CurrentStamina( TMaster ) > 0 ) then begin
		ATTACK_DefSkillRank := SkillValue( TMaster , 5 );
		DefRoll := RollStep( ATTACK_DefSkillRank );
		AddStaminaDown( TMaster , 1 );
		if DefRoll > HiDefRoll then begin
			HiDefRoll := DefRoll;
			ATTACK_Dodge := HiDefRoll >= SkRoll;
		end;
	end;


	{ If defense was successful, may drain a point of stamina. }
	{ If the defense wasn't successful, no point adding insult }
	{ to injury. }
	if ( HiDefRoll > SkRoll ) and ( Random( 3 ) = 1 ) then begin
		AddStaminaDown( TMaster , 1 );
	end;

	{ Return the highest rolled value. The ATTACK_HiDefRoll variable is set }
	{ in the calling procedure. }
	AttemptDefenses := HiDefRoll;
end;

Function Firing_Weight( Weapon: GearPtr; AtOp: Integer ): Integer;
	{ Return the firing weight of this weapon operating at the given AtOp. }
var
	bfw: Integer;
begin
	bfw := GearMass( Weapon );
	{ Melee weapons count as larger than they actually are. }
	if ( Weapon^.G = GG_Weapon ) and (( Weapon^.S = GS_Melee ) or ( Weapon^.S = GS_EMelee )) then begin
		bfw := bfw * 2;
	{ Rapid fire also increases the firing weight. }
	{ Missile launchers don't get a penalty for burst firing; probably recoilless. }
	end else if ( AtOp > 0 ) and not (( Weapon^.G = GG_Weapon ) and ( Weapon^.S = GS_Missile )) then begin
		bfw := bfw + ( AtOp * 3 ) div 2;
	end;
	Firing_Weight := bfw;
end;

Function Firing_Weight_Limit( User: GearPtr ): Integer;
	{ Return the maximum firing weight this user can handle. }
begin
	if User^.G = GG_Mecha then begin
		Firing_Weight_Limit := User^.V * 2 + 2;
	end else if User^.G = GG_Character then begin
		Firing_Weight_Limit := CStat( User , STAT_Body );
	end else begin
		Firing_Weight_Limit := 100;
	end;
end;

Function CalcTotalModifiers( gb: GameBoardPtr; Attacker,Target: GearPtr; AtOp: Integer; AtAt: String ): Integer;
	{ Calculate the total modifiers to this attack roll. }
var
	SkRoll,Spd,ZA,ZT: Integer;
	AMaster,TMaster,AModule,AShield: GearPtr;
	Function NotIntegralWeapon( Part: GearPtr ): Boolean;
		{ Return TRUE if part is an invcom or the descendant of an invcom. }
	begin
		NotIntegralWeapon := IsExternalPart( AMaster , Part );
	end;
	Function WeaponWeightModifier: Integer;
		{ Return the targeting modifier caused by the weight of this weapon. }
		Function HasFreeHand( LList: GearPtr ): Boolean;
			{ Return TRUE if you can find a hand of equal scale to AMaster }
			{ along this linked list, or FALSE otherwise. }
		var
			HandFound: Boolean;
		begin
			HandFound := False;
			while ( LList <> Nil ) and ( not HandFound ) do begin
				if ( LList^.G = GG_Holder ) and ( LList^.S = GS_Hand ) and ( LList^.Scale >= AMaster^.Scale ) and ( LList^.InvCom = Nil ) then begin
					HandFound := True;
				end else begin
					HandFound := HasFreeHand( LList^.SubCom );
				end;
				LList := LList^.Next;
			end;
			HasFreeHand := HandFound;
		end;
	var
		W,L: Integer;
		Weapon_Module: GearPtr;
	begin
		W := Firing_Weight( Attacker , AtOp ) * ( Attacker^.Scale + 1 );
		L := Firing_Weight_Limit( AMaster ) * ( AMaster^.Scale + 1 );
		Weapon_Module := FindModule( Attacker );
		if ( Weapon_Module <> Nil ) and ( Weapon_Module^.S = GS_Body ) then L := L * 2;
		if HasFreeHand( AMaster^.SubCom ) then L := L * 3;
		if W > L then begin
			WeaponWeightModifier := -5 - ( ( W - L ) div ( AMaster^.Scale + 1 ) ) div 2;
		end else begin
			WeaponWeightModifier := 0;
		end;
	end;
begin
	SkRoll := 0;
	AMaster := FindRoot( Attacker );
	TMaster := FindRoot( Target );

	{ Add the weapon accuracy, and possibly Attack Options. }
	if Attacker^.G = GG_Weapon then begin
		SkRoll := SkRoll + Attacker^.Stat[STAT_Accuracy];

		{ Add a modifier for any weapon add-ons that might be attached. }
		{ I'll use the AShield var for this instead of declaring a new variable... }
		AShield := Attacker^.InvCom;
		while AShield <> Nil do begin
			if ( AShield^.G = GG_WeaponAddOn ) and NotDestroyed( AShield ) then begin
				SkRoll := SkRoll + AShield^.Stat[STAT_Accuracy];
			end;
			AShield := AShield^.Next;
		end;

		{ Missiles use sensor rating instead of targeting rating. }
		if ( Attacker^.S = GS_Missile ) and ( AMaster^.G = GG_Mecha ) then begin
			SkRoll := SkRoll - MechaTargeting( AMaster ) + MechaSensorRating( AMaster );
		end;

		if ( Attacker^.S = GS_Ballistic ) or ( Attacker^.S = GS_BeamGun ) or ( Attacker^.S = GS_Missile ) then begin
			if AtOp > 0 then begin
				if AtOp < 10 then SkRoll := SkRoll + ( AtOp div 2 )
				else SkRoll := SkRoll + 5;
			end;
		end;

	end else begin
		{ Modules and other non-weapon attacking parts suffer }
		{ a -2 to their hot rolls. }
		SkRoll := SkRoll - 2;
	end;

	{ Modify the attack roll for overheavy weapons. }
	if NotIntegralWeapon( Attacker ) then begin
		SkRoll := SkRoll + WeaponWeightModifier;
	end;

	{ Modify the attack roll for wielded shields. }
	AModule := FindModule( Attacker );
	if AModule <> Nil then begin
		AShield := SeekGearByG( AModule^.InvCom , GG_Shield );
		if ( AShield <> Nil ) and ( AShield <> Attacker^.Parent ) then begin
			SkRoll := SkRoll - 5 - AShield^.Stat[ STAT_ShieldBonus ];
		end;
	end;

	{ Modify the attack score for scale and target depth. }
	{ Depth refers to the subcomponent level that TARGET is at... }
	if not HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
		if Attacker^.Scale <> Target^.Scale then begin
			SkRoll := SkRoll - ( Attacker^.Scale - Target^.Scale ) * PenaltyPerScale;
		end;
		SkRoll := SkRoll - GearDepth( Target ) * PenaltyPerDepth;
	end;

	{ Modify the attack roll for target and attacker movement. }
	{ The modifier from the attacker is based on MoveAction, }
	{ while the modifier for the defender is based upon actual speed. }
	Spd := NAttValue( AMaster^.NA , NAG_Action , NAS_MoveAction );
	if Spd = NAV_Stop then SkRoll := SkRoll + StopBonus
	else if Spd = NAV_FullSpeed then SkRoll := SkRoll - RunPenalty;

	Spd := CalcRelativeSpeed( TMaster , GB );
	if Spd > 0 then begin
		{ Convert the speed from ClicksPerHex to HexPerRound }
		Spd := ( ClicksPerRound * 10 ) div Spd;
		SkRoll := SkRoll - ( Spd div ClicksPerPenalty );
	end else begin
		if BaseMoveRate( TMaster ) > 0 then SkRoll := SkRoll + StopPenalty
		else SkRoll := SkRoll + ImmobilePenalty;
	end;

	{ Modify for attack attributes. }
	if HasAttackAttribute( AtAt , AA_STRAIN ) and ( AMaster <> Nil ) and ( CurrentStamina( AMaster ) < 1 ) then SkRoll := SkRoll - 10;
	if HasAttackAttribute( AtAt , AA_COMPLEX ) and ( AMaster <> Nil ) and ( CurrentMental( AMaster ) < 1 ) then SkRoll := SkRoll - 10;

	{ Do the modifiers that only count if both meks are on the game board. }
	if OnTheMap( AMaster ) and OnTheMap( TMaster ) then begin
		if not HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
			{ Adjust the attack roll for obscurement between attacker & target. }
			{ Yeah, I'm reusing the SPD variable for cover. Big deal. }
			Spd := CalcObscurement( AMaster , TMaster , GB );
			if Spd > 0 then begin
				SkRoll := SkRoll - Spd;
			end;
		end;

		{ If the firer is underwater, this will be a more difficult shot. }
		if MekAltitude( gb , AMaster ) < 0 then SkRoll := SkRoll - UnderwaterAttackPenalty;

		{ Add range modifier. }
		{ Still using the SPD variable for all these other uses... }
		SPD := Range( gb , AMaster , TMaster );
		if ( SPD > 1 ) and ( Attacker^.G = GG_Weapon ) and ( Attacker^.Stat[ STAT_Range ] <> 0 ) then begin
			{ Apply penalty for within minumum range }
			if ( Attacker^.Stat[STAT_Range] > HAS_MINIMUM_RANGE ) and ( Spd <= ( Attacker^.Stat[STAT_Range] div 2 ) ) then begin
				{ For every square inside minimum range, there's a -1 attack penalty. Sound familiar? }
				SkRoll := SkRoll - ( Attacker^.Stat[STAT_Range] div 2 ) + Spd - 1;

			end else if SPD <= Attacker^.Stat[STAT_Range] then SkRoll := SkRoll + ShortRangeBonus
			else if SPD > Attacker^.Stat[STAT_Range] * 2 then SkRoll := SkRoll - LongRangePenalty;
		end;

		{ Add altitude modifier. Attacking an airborne mecha is more difficult, }
		{ unless the ANTIAIR attribute is had. If the attacker is higher than the }
		{ defender there's a slight bonus there as well. }
		ZA := MekAltitude( GB , AMaster );
		ZT := MekAltitude( GB , TMaster );
		if ( ZT = 5 ) and ( ZA <> 5 ) and not HasAttackAttribute( AtAt , AA_AntiAir ) then SkRoll := SkRoll - FlyingPenalty;
		if ZA > ZT then SkRoll := SkRoll + HighGroundBonus;
	end;

	CalcTotalModifiers := SkRoll;
end;

Procedure DestroyTerrain( GB: GameBoardPtr; X,Y: Integer );
	{ Destroy the terrain in this spot. Pretty simple actually. }
var
	Smoke: GearPtr;
begin
	{ Start with an error check... }
	if not OnTheMap( X , Y ) then Exit;

	{ If this terrain has a DESTROYED type set, change the tile. }
	if TerrMan[ GB^.map[X,Y].terr ].Destroyed <> 0 then GB^.map[X,Y].terr := TerrMan[ GB^.map[X,Y].terr ].Destroyed;

	{ If terrain is destroyed, it will probably cause smoke and maybe fire. }
	if Random( 2 ) = 1 then begin
		Smoke := LoadNewSTC( 'SMOKE-1' );
		if Smoke <> Nil then begin
			Smoke^.Scale := GB^.Scale;
			AppendGear( GB^.Meks , Smoke );
			Smoke^.Stat[ STAT_CloudDuration ] := RollStep( 5 );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_X , X );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_Y , Y );
		end;
	end;
	if ( Random( 3 ) = 1 ) and TerrMan[ GB^.map[X,Y].terr ].Flammable then begin
		Smoke := LoadNewSTC( 'FIRE-1' );
		if Smoke <> Nil then begin
			Smoke^.Scale := GB^.Scale;
			AppendGear( GB^.Meks , Smoke );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_X , X );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_Y , Y );
		end;
		SetTrigger( GB , 'FIRE!' );
	end;
end;

Procedure SceneryChewing( GB: GameBoardPtr; X,Y,DC: Integer; Accident: Boolean; AtAt: String );
	{ Tile X,Y has been hit. Try and damage it. }
	{ Set ACCIDENT to TRUE if the tile is not the primary target of }
	{ the attack, FALSE if it is. }
begin
	{ Start with an error check... }
	if not OnTheMap( X , Y ) then Exit;

	if HasAttackAttribute( AtAt , AA_Brutal ) then begin
		DC := DC * 2;
	end;
	if HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
		DC := DC + Random( DC + 1 );
	end;

	{ Modify for accidental damage. If not intentionally trying }
	{ to cause terrain damage, it becomes far less likely to happen. }
	if ( DC > 0 ) and Accident then DC := Random( DC );

	if ( DC > 0 ) and ( Random( DC ) >= TerrMan[ GB^.map[X,Y].terr ].DMG ) and ( TerrMan[ GB^.map[X,Y].terr ].DMG > 0 ) then begin
		{ Demolish the scenery... unless there's an error in the definitions. }
		if ( TerrMan[ GB^.map[X,Y].terr ].Destroyed > 0 ) and ( TerrMan[ GB^.map[X,Y].terr ].Destroyed <= NumTerr ) then begin
			DestroyTerrain( GB , X , Y );
		end;
	end;
end;

Procedure ProcessStatusEffect( GB: GameBoardPtr; var EReq: EffectRequest );
	{ Stick a status effect on the target, unless it resists. }
var
	TMaster: GearPtr;
	AttackRoll,DefRoll: Integer;
begin
	{ Can only process this effect if we have a target and a valid }
	{ status effect to process. }
	TMaster := FindRoot( EReq.Target );

	if GearActive( TMaster ) and ( EReq.FXOption >= 1 ) and ( EReq.FXOption <= Num_Status_FX ) then begin
		{ If a weapon is defined, it must be of a scale at least as great as the target. }
		if ( EReq.Weapon <> Nil ) and ( EReq.Weapon^.Scale < TMaster^.Scale ) then Exit;

		if SX_Vunerability[ EReq.FXOption , NAttValue( TMaster^.NA , NAG_GearOps , NAS_Material ) ] then begin
			AttackRoll := RollStep( EReq.FXSkill );
			DefRoll := AttemptDefenses( GB , EReq.Target , EReq.Weapon , AttackRoll , EReq.AF );
			if AttackRoll > DefRoll then begin
				AddNAtt( TMaster^.NA , NAG_StatusEffect , EReq.FXOption , EReq.FXDice );
				RecordAnnouncement( ReplaceHash( SAttValue( FX_Messages , 'Status_Announce' + BStr( EReq.FXOption ) ) , GearName( TMaster ) ) );
			end;
		end;
	end;
end;

Procedure ProcessHealingEffect( GB: GameBoardPtr; var EReq: EffectRequest );
	{ Do healing on target. }
var
	TMaster: GearPtr;
	RepairRoll,D0,D1: LongInt;
	msg: String;
begin
	{ Can only process this effect if we have a target. }
	TMaster := FindRoot( EReq.Target );
	if ( TMaster <> Nil ) then begin
		{ Record how much repairable damage we started with... }
		D0 := TotalRepairableDamage( TMaster , EReq.FXOption );

		{ Do some repairs. }
		RepairRoll := RollStep( EReq.FXDice ) + EReq.FXMod;
		ApplyRepairPoints( TMaster , EReq.FXOption , RepairRoll );

		{ Find out how much repairable damage we have now... }
		D1 := TotalRepairableDamage( TMaster , EReq.FXOption );

		{ Record the announcement, if any healing done. }
		if ( D0 - D1 ) > 0 then begin
			msg := ReplaceHash( SAttValue( FX_Messages , 'Healing_Announce' ) , GearName( TMaster ) );
			msg := ReplaceHash( msg , BStr( D0 - D1 ) );
			RecordAnnouncement( msg );
		end;
	end;
end;

Procedure ProcessOverloadEffect( GB: GameBoardPtr; var EReq: EffectRequest );
	{ Apply overload to the target, unless it resists. }
var
	TMaster: GearPtr;
	AttackRoll,DefRoll: Integer;
begin
	{ Can only process this effect if we have a target and a valid }
	{ status effect to process. }
	TMaster := FindRoot( EReq.Target );
	if GearActive( TMaster ) and ( TMaster^.G = GG_Mecha ) then begin
		AttackRoll := RollStep( EReq.FXSkill );
		DefRoll := AttemptDefenses( GB , EReq.Target , EReq.Weapon , AttackRoll , EReq.AF );
		if AttackRoll > DefRoll then begin
			AddNAtt( TMaster^.NA , NAG_Condition , NAS_Overload , EReq.FXDice + Random( EReq.FXDice ) + ( ( AttackRoll - DefRoll ) div 3 )  + 5 );
			RecordAnnouncement( ReplaceHash( SAttValue( FX_Messages , 'Status_Overload' ) , GearName( TMaster ) ) );
		end else begin
			AddNAtt( TMaster^.NA , NAG_Condition , NAS_Overload , Random( EReq.FXDice ) + 2 );
		end;
	end;
end;

Procedure ProcessAttackEffect( GB: GameBoardPtr; AReq: EffectRequest );
	{ Process a general attack effect against TARGET. }
var
	CritHit,CritTar: Integer;
	TargetOK: Boolean;
	HiDefRoll: Integer;
	T: Integer;
begin
	{ Initialize values. }
	ATTACK_TPilot := LocatePilot( AReq.Target );
	if ( ATTACK_TPilot = Nil ) or Destroyed( ATTACK_TPilot ) then ATTACK_TPilotOK := False
	else ATTACK_TPilotOK := True;

	if Areq.AF.CantCallShot then begin
		{ Can't aim for a subcomponent. }
		AReq.Target := FindRoot( AReq.Target );
	end;

	ATTACK_AMaster := FindRoot( AReq.Originator );
	ATTACK_TMaster := FindRoot( Areq.Target );

	ATTACK_Error := False;

	{ See whether or not the gear is already destroyed, then }
	{ whether or not it is already immobilized. }
	if ( ATTACK_TMaster = Nil ) or Destroyed( ATTACK_TMaster ) then ATTACK_TMasterOK := False
	{ If the master is a character type, set TMasterOK to false, so it }
	{ doesn't go printing a 'Josh is destroyed! Josh is killed!' message. }
	else if ATTACK_TMaster = ATTACK_TPilot then ATTACK_TMasterOK := False
	else ATTACK_TMasterOK := True;
	ATTACK_TMasterMove := BaseMoveRate( ATTACK_TMaster ) > 0;

	ATTACK_AttackerDamage := 0;

	ATTACK_AttSkillRank := AReq.FXSkill;

	{ Record whether or not the target is operational at the start of the attack. }
	TargetOK := GearOperational( AReq.Target );

	ATTACK_AttackRoll := RollStep( AReq.FXSkill ) + AReq.FXMod;

	{ Start attempting TMaster's defenses against the attack. Use all }
	{ appropriate defenses. }
	ATTACK_HiDefRoll := AttemptDefenses( GB , ATTACK_TMaster , AReq.Weapon , ATTACK_AttackRoll , AReq.AF );

	{ *********************************************** }
	{ *** DETERMINE WHETHER A HIT WAS MADE OR NOT *** }
	{ *********************************************** }
	{ Normally just beating the attack roll means that the defender }
	{ got away, but with area effect attacks it's not so easy. }
	if HasAreaEffect( AReq.AF.AtAt ) then begin
		{ For every time the defense roll beat the attack roll, }
		{ the damage of the attack is reduced by half. }
		if ATTACK_AttackRoll < 1 then ATTACK_AttackRoll := 1;
		HiDefRoll := ATTACK_HiDefRoll;
		while HiDefRoll > ATTACK_AttackRoll do begin
			HiDefRoll := HiDefRoll div 2;
			AReq.FXDice := AReq.FXDice div 2;
		end;
		ATTACK_ItHit := AReq.FXDice > 0;
		ATTACK_Dodge := Not ATTACK_ItHit;
	end else begin
		ATTACK_ItHit := ATTACK_HiDefRoll < ATTACK_AttackRoll;
	end;

	{ ******************************************** }
	{ *** PERFORM RESULTS OF SUCCESSFUL ATTACK *** }
	{ ******************************************** }
	{ If the attack made it through all of TMaster's defenses, }
	{ actually do the damage. }
	if ATTACK_ItHit then begin
		if AReq.Originator <> Nil then begin
			{ The attack hit. Give the attacker his 2 XP for hitting. }
			DoleExperienceFromTarget( ATTACK_AMaster , ATTACK_TMaster , XPA_AttackHit );

			{ If this was a difficult shot, give extra XP. }
			if ( AReq.FXSkill + AReq.FXMod ) < 5 then begin
				DoleExperienceFromTarget( ATTACK_AMaster , ATTACK_TMaster , ( 7 - AReq.FXSkill - AReq.FXMod ) div 2 );
			end;
		end;


		{ Calculate the Measure of Success and the number of hits. }
		{ Measure of Success applies only against masters. When }
		{ attacking an inanimate object, it's assumed that finesse }
		{ plays a very minor role, unless the attacker is a GATECRASHER. }
		if IsMasterGear( AReq.Target ) and ( AReq.Target^.G <> GG_Prop ) then begin
			ATTACK_MOS := ( ATTACK_AttackRoll - ATTACK_HiDefRoll ) div MOSMeasure;
		end else if HasTalent( AReq.Originator , NAS_GateCrasher ) then begin
			ATTACK_MOS := 2;
		end else begin
			ATTACK_MOS := 0;
		end;
		ATTACK_NumberOfHits := 1 + AReq.FXOption;


		{ At this point in time, before MOS gets modified for }
		{ specific weapon systems, dole the MOS XP. }
		if ( AReq.Originator <> Nil ) and ( ATTACK_MOS > 0 ) and NotDestroyed( AReq.Target ) then begin
			DoleExperienceFromTarget( AReq.Originator , ATTACK_TMaster , ATTACK_MOS * XPA_PerMOS );
			if AReq.Weapon <> Nil then DoleSkillExperience( AReq.Originator , AttackSkillNeeded( AReq.Weapon ) , XPA_SK_Critical );
		end;

		{ Perform modifications which only count if }
		{ we have a pointer to the weapon. }
		if ( AReq.Weapon <> Nil ) then begin
			{ Modify number of hits by weapon type and AtAt. }
			if AReq.Weapon^.G = GG_Weapon then begin
				if ( AReq.Weapon^.S = GS_Ballistic ) or ( AReq.Weapon^.S = GS_BeamGun ) or ( AReq.Weapon^.S = GS_Missile ) then begin
					if AReq.FXOption > 0 then begin
						ATTACK_NumberOfHits := ATTACK_AttackRoll - ATTACK_HiDefRoll;
						if AReq.FXOption > 9 then begin
							if ATTACK_NumberOfHits > 10 then ATTACK_NumberOfHits := 10;
							ATTACK_NumberOfHits := ( ( AReq.FXOption + 1 ) * ATTACK_NumberOfHits ) div 10;
						end else begin
							if ATTACK_NumberOfHits > (AReq.FXOption + 1) then ATTACK_NumberOfHits := AReq.FXOption + 1;
						end;
					end;
				end else if ( AReq.Weapon^.S = GS_Melee ) then begin
					{ Close combat weapons can trade a high MOS for multiple hits. }
					if ATTACK_MOS > 6 then begin
						ATTACK_NumberOfHits := ATTACK_NumberOfHits + ATTACK_MOS - 6;
						ATTACK_MOS := 6;
					end;
					while ( ATTACK_MOS > 0 ) and ( Random(5) = 1 ) do begin
						Inc( ATTACK_NumberOfHits );
						Dec( ATTACK_MOS );
					end;
				end else if ( AReq.Weapon^.S = GS_EMelee ) then begin
					{ Close combat weapons can trade a high MOS for multiple hits. }
					while ( ATTACK_MOS > 0 ) and ( Random(6) = 1 ) do begin
						Inc( ATTACK_NumberOfHits );
						Dec( ATTACK_MOS );
					end;
				end;
			end else if AReq.Weapon^.G = GG_Module then begin
				{ Fighting attacks have a higher chance of scoring }
				{ multiple hits on a good roll. }
				if ATTACK_MOS > 6 then begin
					ATTACK_NumberOfHits := ATTACK_NumberOfHits + ATTACK_MOS - 6;
					ATTACK_MOS := 6;
				end;
				while ( ATTACK_MOS > 2 ) and ( Random(4) <> 1 ) do begin
					Inc( ATTACK_NumberOfHits );
					Dec( ATTACK_MOS );
				end;

				{ Modify the MOS for KungFu. }
				{ This will be modified again later for being a nonweapon... }
				if HasTalent( ATTACK_AMaster , NAS_KungFu ) then ATTACK_MOS := ATTACK_MOS + Non_Weapon_MOS_Penalty + 1;
			end;
	
			{ Modify MOS and DC for non-weapons and EMWs. }
			if AReq.Weapon^.G <> GG_Weapon then begin
				ATTACK_MOS := ATTACK_MOS - Non_Weapon_MOS_Penalty;
				if ATTACK_MOS < 0 then begin
					AReq.FXDice := AReq.FXDice + ATTACK_MOS;
					if AReq.FXDice < 1 then AReq.FXDice := 1;
				end;

			end else if ( AReq.Weapon^.G = GG_Weapon ) and ( AReq.Weapon^.S = GS_EMelee ) then begin
				ATTACK_MOS := ATTACK_MOS + 2;
			end;
			if HasAttackAttribute( AReq.AF.AtAt , AA_ArmorPiercing ) then ATTACK_MOS := ATTACK_MOS + 2
			else if HasAttackAttribute( AReq.AF.AtAt , AA_ArmorIgnore ) then ATTACK_MOS := ATTACK_MOS + 12;
		end;

		{ If called shots are illegal right now, reduce MOS }
		{ by 2 to represent the general lack of precision. }
		if AReq.AF.CantCallShot then begin
			ATTACK_MOS := ATTACK_MOS - 2;

		end else if AReq.Originator <> Nil then begin
			{ Modify MOS for Critical Hit skill. }
			{ Use variable SPD to represent the critical hit target # }
			CritHit := RollStep( SkillValue( AReq.Originator , 18 ));
			CritTar := ATTACK_HiDefRoll;

			{ If the high defense roll was lower than the Critical }
			{ Hit Minimum Target number, raise it. }
			if CritTar < CritHitMinTar then CritTar := CritHitMinTar;
			if CritHit > CritTar then begin
				{ Note that the MOSMeasure is doubled for Critical Hit skill use, since this is kinda like bonus MOS. }
				{ Also note that this bonus does apply to non-master targets. }
				ATTACK_MOS := ATTACK_MOS + ( ( CritHit - CritTar ) div MOSMeasure ) + 1;
			end;

			{ If the originator has Spot Weakness skill, modify damage for that. }
			if HasSkill( AReq.Originator , 18 ) then begin
				if HasTalent( AReq.Originator , NAS_Sniper ) then begin
					AReq.FXDice := AReq.FXDice + SkillRank( AReq.Originator , 18 );
				end else begin
					AReq.FXDice := AReq.FXDice + ( SkillRank( AReq.Originator , 18 ) div 2 );
				end;
			end;

			{ Modify MOS for miscellaneous other talents. }
			{ ANATOMIST talent - +1 MOS vs Meat targets }
			if HasTalent( AReq.Originator , NAS_Anatomist ) and ( NAttValue( AReq.Target^.NA , NAG_GearOps , NAS_Material ) = NAV_Meat ) then begin
				ATTACK_MOS := ATTACK_MOS + 1;
			end;
		end;

		{ Modify MOS for the "HARD AS NAILS", "HULL DOWN" talents. }
		if ( ATTACK_TMaster^.G = GG_Character ) and HasTalent( ATTACK_TMaster , NAS_HardAsNails ) then ATTACK_MOS := ATTACK_MOS - 2;
		if (ATTACK_TMaster^.G = GG_Mecha) and HasTalent(ATTACK_TMaster,NAS_HullDown) and ((NAttValue(ATTACK_TMaster^.NA,NAG_Action,NAS_MoveMode)= MM_WALK) or (NAttValue(ATTACK_TMaster^.NA,NAG_Action,NAS_MoveMode)=MM_ROLL)) then ATTACK_MOS := ATTACK_MOS - 3;

		ATTACK_DamageDone := DamageGear( GB , AReq.Target , AReq.Weapon , AReq.FXDice , ATTACK_MOS , ATTACK_NumberOfHits , AReq.AF.AtAt );

		{ If, at the beginning of this attack, the target was }
		{ functioning, check to see if the attacker gets extra }
		{ experience for taking the target out. }
		if ( AReq.Originator <> Nil ) and TargetOK then begin
			if AReq.Target^.G = GG_Mecha then begin
				if not GearOperational( AReq.Target ) then DoleExperience( AReq.Originator , AReq.Target , XPA_DestroyMaster );
			end else if IsMasterGear( AReq.Target ) then begin
				if Destroyed( AReq.Target ) then DoleExperience( AReq.Originator , AReq.Target , XPA_DestroyMaster );
			end else begin
				{ Destroying a non-master gear only gives 1 XP. }
				if Destroyed( AReq.Target ) then DoleExperience( AReq.Originator , XPA_DestroyThing );
			end;
		end;

	end else begin
		{ The attack missed. Set Damage to 0, and give 2XP to the }
		{ target for having avoided the attack. }
		ATTACK_DamageDone := 0;
		DoleExperienceFromTarget( ATTACK_TMaster , ATTACK_AMaster , XPA_AvoidAttack );
	end;

	{ Store the results of this attack. }
	if AReq.FXDesc = '' then begin
		INDICATE_Latest_Attack( GB );
	end else begin
		INDICATE_Attack_Effect( GB , AReq.FXDesc );
	end;

	{ Cause status effects as appropriate. }
	if ATTACK_ItHit then begin
		{ Set the skill value for ancilliary effects. }
		{ If the attacker is a mecha, use EW skill. Otherwise leave }
		{ the same skill value as was used in the attack. }
		if ( ATTACK_AMaster <> Nil ) and ( ATTACK_AMaster^.G = GG_Mecha ) then begin
			AReq.FXSkill := SkillValue( ATTACK_AMaster , 17 );
		end;

		{ If this weapon causes overload, do that now. }
		If HasAttackAttribute( AReq.AF.AtAt , AA_Overload ) then begin
			AReq.FXType := FX_Overload;
			AReq.AF.CanDodge := False;
			AReq.AF.CanParry := False;
			AReq.AF.CanBlock := False;
			AReq.AF.CanIntercept := False;
			AReq.AF.CanECM := False;
			AReq.AF.CanResist := True;
			ProcessOverloadEffect( GB , AReq );
		end;

		AReq.FXType := FX_CauseStatusFX;
		AReq.FXDice := 1;
		AReq.AF.CanDodge := False;
		AReq.AF.CanParry := False;
		AReq.AF.CanBlock := False;
		AReq.AF.CanIntercept := False;
		AReq.AF.CanECM := False;
		AReq.AF.CanResist := True;

		{ Check each status effect in order. }
		for T := 1 to Num_Status_FX do begin
			AReq.FXOption := T;
			if AStringHasBString( AReq.AF.AtAt , SX_Name[ AReq.FXOption ] ) then ProcessStatusEffect( GB , AReq );
		end;
	end;

	{ Chew the scenery. }
	if ( AReq.Weapon = Nil ) or ( AReq.Weapon^.Scale >= GB^.Scale ) then begin
		SceneryChewing( GB, AReq.TX,AReq.TY,AReq.FXDice, Not ATTACK_ItHit , AReq.AF.AtAt );
	end;

	{ If the mek's move mode has been disabled, it will crash here. }
	if ATTACK_TMasterMove and (BaseMoveRate( ATTACK_TMaster ) = 0) then begin
		Crash( GB , ATTACK_TMaster );
		AddSAtt( ATTACK_History , 'ANNOUNCE_' + BStr( EFFECTS_Event_Order + 1 ) + '_' , PilotName( ATTACK_TMaster ) + ' has crashed!' );
	end;
end;

Procedure InvokeEffect( GB: GameBoardPtr; var EReq: EffectRequest );
	{ Check the effect type, then do something appropriate based }
	{ upon that. }
begin
	Case EReq.FXType of
		FX_DoDamage:	ProcessAttackEffect( GB , Ereq );
		FX_CauseStatusFX:	ProcessStatusEffect( GB , EReq );
		FX_DoHealing:	ProcessHealingEffect( GB , EReq );
		FX_Overload: 	ProcessOverloadEffect( GB , EReq );
	end;
end;

Procedure FunkyMartialArts( var AReq: EffectRequest );
	{ This attack may well get some special bonuses. }
const
	NumFMABase = 10;
	Num_Funky_Things = 10;
	FT_Cost: Array [1..Num_Funky_Things] of Byte = (
		2, 2, 3, 5, 3,
		3, 4, 2, 1, 3
	);
	FT_AA: Array [1..Num_Funky_Things] of String[15] = (
	'','','SCATTER','HYPER','ARMORPIERCING',
	'BRUTAL','STONE','HAYWIRE','STUN',''
	);
	FT_Heroic = 1;
	FT_Zen = 2;
	FT_Snake = 10;
var
	SkRk,TP: Integer;
	Adjective,Noun: SAttPtr;
	msg,C: String;
	Function CanGetFunkyThing( N: Integer ): Boolean;
		{ Return TRUE if the attacker can do this funky thing, based on }
		{ Technique Points and whatever else, or FALSE if he can't. }
	begin
		if FT_Cost[ N ] <= TP then begin
			if N = FT_Heroic then begin
				{ Can only perform a heroic attack if heroic. }
				CanGetFunkyThing := NAttValue( AReq.Originator^.NA , NAG_CharDescription , NAS_Heroic ) > 10;
			end else if N = FT_Zen then begin
				{ Can only perform a mystic attack if spiritual. }
				CanGetFunkyThing := NAttValue( AReq.Originator^.NA , NAG_CharDescription , NAS_Pragmatic ) < -10;
			end else begin
				{ Nothing else has any special requirements. }
				CanGetFunkyThing := True;
			end;
		end else begin
			{ If not enough points, can't do this thing. }
			CanGetFunkyThing := False;
		end;
	end;
	Procedure ApplyFunkyThing( N: Integer );
		{ Apply the funky thing to the attack request; reduce the total number }
		{ of technique points; store a noun and an adjective to describe this }
		{ attack. }
	begin
		TP := TP - FT_Cost[ N ];
		AReq.AF.AtAt := AReq.AF.AtAt + ' ' + FT_AA[ N ];
		if Random( 2 ) = 1 then StoreSAtt( Adjective , SAttValue( FX_Messages , 'FMAFT_A' + BStr( N ) ) )
		else StoreSAtt( Noun , SAttValue( FX_Messages , 'FMAFT_N' + BStr( N ) ) );

		{ Add bonuses for special things here. }
		if N = FT_Heroic then begin
			{ A heroic attack increases damage done based on the character's heroism. }
			AReq.FXDice := AReq.FXDice + ( NAttValue( AReq.Originator^.NA , NAG_CharDescription , NAS_Heroic ) div 5 );
		end else if N = FT_Zen then begin
			{ A zen attack increases accuracy based on the character's spirituality. }
			AReq.FXSkill := AReq.FXSkill + ( Abs( NAttValue( AReq.Originator^.NA , NAG_CharDescription , NAS_Pragmatic ) ) div 10 );
		end else if N = FT_Snake then begin
			AReq.AF.CanParry := False;
			AReq.AF.CanBlock := False;
		end;
	end;
begin
	{ First, make sure we have an originator, and that it's a character. }
	if ( AReq.Originator = Nil ) or ( AReq.Originator^.G <> GG_Character ) then exit;

	{ The attacker must have a martial arts skill of at least 5 to benefit. }
	SkRk := NAttValue( AReq.Originator^.NA , NAG_Skill , 9 ) - 4;
	if SkRk < 1 then Exit;

	{ TP is Technique Points. }
	TP := 0;

	{ The number of technique points is determined semi-randomly from the skill rank. }
	while SkRk > 0 do begin
		if SkRk < 2 then begin
			if Random( 2 ) < SkRk then Inc( TP );
		end else if Random( 3 ) <> 1 then Inc( TP );
		SkRk := SkRk - 2;
	end;

	if CurrentMental( AReq.Originator ) > ( 10 + Random( 20 ) ) then begin
		inc( TP );
		AddMentalDown( AReq.Originator , 1 );
	end;

	{ If any technique points were gained, put them to good use here. }
	{ Technique points can buy attack improvements: attack attributes, various bonuses, }
	{  status effects... }
	if TP > 0 then begin
		{ Initialize the variables needed for our attack name generator. }
		Adjective := Nil;
		Noun := Nil;
		if ( AReq.Weapon^.S = GS_Arm ) and ( Random( 5 ) <> 1 ) then begin
			Msg := SATtValue( FX_Messages , 'FMA_Name_Punch_' + BStr( Random( NumFMABase ) + 1 ) );
		end else if ( AReq.Weapon^.S = GS_Leg ) and ( Random( 5 ) <> 1 ) then begin
			Msg := SATtValue( FX_Messages , 'FMA_Name_Kick_' + BStr( Random( NumFMABase ) + 1 ) );
		end else begin
			Msg := SATtValue( FX_Messages , 'FMA_Name_Misc_' + BStr( Random( NumFMABase ) + 1 ) );
		end;

		while TP > 0 do begin
			SkRk := Random( Num_Funky_Things ) + 1;
			if CanGetFunkyThing( SkRk ) then begin
				ApplyFunkyThing( SkRk );
			end else begin
				{ If the thing chosen can't be gotten, just give a bonus }
				{ to damage. }
				Inc( AReq.FXDice );
				Dec( TP );
			end;
		end;

		AReq.FXName := '';
		while msg <> '' do begin
			C := ExtractWord( msg );
			if C = '%A' then begin
				if Adjective <> Nil then begin
					AReq.FXName := AReq.FXName + ' ' + SelectRandomSAtt( Adjective )^.Info;
				end else begin
					AReq.FXName := AReq.FXName + ' ' + SAttValue( FX_Messages , 'FMAFT_MISCA' + BStr( Random( 5 ) + 1 ) );
				end;
			end else if C = '%N' then begin
				if Noun <> Nil then begin
					AReq.FXName := AReq.FXName + ' ' + SelectRandomSAtt( Noun )^.Info;
				end else begin
					AReq.FXName := AReq.FXName + ' ' + SAttValue( FX_Messages , 'FMAFT_MISCN' + BStr( Random( 5 ) + 1 ) );
				end;
			end else begin
				AReq.FXName := AReq.FXName + ' ' + C;
			end;
		end;

		DisposeSAtt( Adjective );
		DisposeSAtt( Noun );

	end;
end;

Function FillAttackRequest( GB: GameBoardPtr; Attacker,Target: GearPtr; AtOp,AMod: Integer; AtAt: String; Accident: Boolean ): EffectRequest;
	{ Fill out the attack request based on the information provided. }
var
	AttackSkill: Integer;
	AReq: EffectRequest;
begin
	{ Fill out the effect request. }
	AReq.FXName := GearName( Attacker );
	AReq.FXType := FX_DoDamage;
	AReq.Target := Target;
	AReq.Originator := FindRoot( Attacker );
	AReq.Weapon := Attacker;
	AReq.AF.CantCallShot := NoCalledShots( AtAt , AtOp );
	AReq.AF.CanDodge := True;
	AReq.AF.CanBlock := not HasAttackAttribute( AtAt , AA_Flail );
	if Attacker <> Nil then begin
		AReq.AF.CanParry := ( ( Attacker^.G <> GG_Weapon ) or ( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee ) ) and not HasAttackAttribute( AtAt , AA_Flail );
		AReq.AF.CanIntercept := ( Attacker^.G = GG_Weapon ) and ( Attacker^.S = GS_Missile );
		AReq.AF.CanECM := ( Attacker^.G = GG_Weapon ) and (( Attacker^.S = GS_Ballistic) or ( Attacker^.S = GS_BeamGun ) or ( Attacker^.S = GS_Missile ));
	end;
	AReq.AF.CanResist := False;
	AReq.AF.AtAt := AtAt;
	if Target <> Nil then begin
		AReq.TX := NAttValue( FindRoot( Target )^.NA , NAG_Location , NAS_X );
		AReq.TY := NAttValue( FindRoot( Target )^.NA , NAG_Location , NAS_Y );
		AReq.FXMod := CalcTotalModifiers( gb , Attacker , Target , AtOp , AtAt ) + AMod;
	end else begin
		AReq.FXMod := AMod;
	end;
	AReq.FXDice := WeaponDC( Attacker , AtOp );

	AttackSkill := AttackSkillNeeded( Attacker );
	AReq.FXSkill := SkillValue( AReq.Originator , AttackSkill );

	AReq.FXOption := AtOp;
	AReq.FXDesc := '';

	{ If this is a martial arts attack, some extra stuff is going to go on now. }
	if ( AttackSkill = 9 ) then begin
		FunkyMartialArts( AReq );
	end;

	{ Add the surprise attack bonuses. }
	if ( Areq.Originator <> Nil ) and ( Target <> Nil ) and not MekCanSeeTarget( GB , FindRoot( Target ) , AReq.Originator ) then begin
		if HasTalent( Areq.Originator , NAS_Ninjitsu ) then begin
			AReq.FXMod := AReq.FXMod + MOSMeasure * 2;
			AReq.FXDice := AReq.FXDice * 3 div 2;
		end else begin
			AReq.FXMod := AReq.FXMod + MOSMeasure;
			AReq.FXDice := AReq.FXDice * 5 div 4;
		end;
	end;

	FillAttackRequest := AReq;
end;

Procedure AttackSingleTarget( GB: GameBoardPtr; Attacker,Target: GearPtr; AtOp,AMod: Integer; AtAt: String; Accident: Boolean );
	{ This procedure will attack a single target. }
	{ ACCIDENT is true if the attacker isn't really trying to hit }
	{  the target, such as when a friendly unit accidentally gets }
	{  in the way of an attack. }
var
	AReq: EffectRequest;
begin
	{ Error check. }
	if ( Attacker = Nil ) or ( Target = Nil ) then begin
		ATTACK_Error := True;
		exit;
	end;

	AReq := FillAttackRequest( GB,Attacker,Target,AtOp,AMod,AtAt,Accident );

	{ Give a meager skill experience bonus. }
	DoleSkillExperience( AReq.Originator , AttackSkillNeeded( Attacker ) , XPA_SK_Basic );

	{ Call the attack processor. }
	ProcessAttackEffect( GB , AReq );
end;

Procedure DoDirectFireAttack( GB: GameBoardPtr; Attacker,Target: GearPtr; X,Y,Z,AtOp,AMod: Integer; AtAt: String );
	{ Perform a direct fire attack. Direct fire is the basic attack type. }
var
	msg: String;
	X0,Y0,Z0: Integer;
	AReq: EffectRequest;
begin
	{ If an initial shot animation is required, add that now. }
	X0 := NAttValue( FindMaster( Attacker )^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( FindMaster( Attacker )^.NA , NAG_Location , NAS_Y );
	Z0 := MekALtitude( GB , FindRoot( Attacker ) );
	Add_Shot_Precisely( GB , X0 , Y0 , Z0 , X , Y , Z );

	AReq := FillAttackRequest( GB,Attacker,Target,AtOp,AMod,AtAt,False );

	{ Actually perform the attack. }
	if Target <> Nil then begin
		msg := PilotName( FindMaster( Attacker ) ) + ' attacks ' + PilotName( FindMaster( Target ) )+' with ' + AReq.FXName + '.';
		RecordAnnouncement( msg );
		Inc( EFFECTS_Event_Order );
		{ Give a meager skill experience bonus. }
		DoleSkillExperience( AReq.Originator , AttackSkillNeeded( Attacker ) , XPA_SK_Basic );
		ProcessAttackEffect( GB , AReq );
	end else if Attacker^.Scale >= GB^.Scale then begin
		msg := PilotName( FindMaster( Attacker ) ) + ' fires ' + GearName( Attacker ) + '.';
		RecordAnnouncement( msg );
		Inc( EFFECTS_Event_Order );
		Add_Point_Animation( X , Y , Z , GS_DamagingHit );
		SceneryChewing( GB , X , Y , WeaponDC( Attacker , AtOp ) + 2 , False , AtAt );
	end;
end;

Function MekIsTargetInRadius( GB: GameBoardPtr; Mek,Attacker,Weapon,Spotter: GearPtr; X,Y,R: Integer ): Boolean;
	{ Used by the NumTargetsInRadius and FindTargetInRadius functions. }
	{ Returns TRUE is Mek is an enemy of ATTACKER, is visible by }
	{ SPOTTER, and is within the prescribed screen area. }
begin
	Spotter := FindRoot( SPotter );
	MekIsTargetInRadius := AreEnemies( GB , Attacker , Mek ) and MekCanSeeTarget( GB , Spotter , Mek ) and RangeArcCheck( GB , Attacker , Weapon , Mek ) and ( Range( Mek , X , Y ) <= R ) and GearOperational( Mek );
end;

Function NumTargetsInRadius( GB: GameBoardPtr; Attacker,Weapon,Spotter: GearPtr; X,Y,R: Integer ): Integer;
	{ Determine the number of targets within the radius which can be }
	{ seen by SPOTTER and are enemies of ATTACKER. }
var
	N: Integer;
	M: GearPtr;
begin
	N := 0;
	M := GB^.Meks;
	while M <> Nil do begin
		if MekIsTargetInRadius( GB, M, Attacker, Weapon, Spotter, X, Y, R ) then Inc( N );
		M := M^.Next;
	end;
	NumTargetsInRadius := N;
end;

Function SwarmRadius( GB: GameBoardPtr; Attacker: GearPtr ): Integer;
	{ Return the radius at which this weapon swarms. Default value }
	{ is one-half the regular short range. }
begin
	if Attacker^.G = GG_Ammo then begin
		{ Thrown weapons have an effectively infinite swarm }
		{ spread. Why? Because I want shurikens to be cool. }
		SwarmRadius := 5;
	end else begin
		SwarmRadius := ( WeaponRange( GB , Attacker ) + 5 ) div 6;
	end;
end;

Procedure DoSwarmAttack( GB: GameBoardPtr; Attacker: GearPtr; X,Y,AtOp,AMod: Integer; AtAt: String );
	{ Perform a swarm attack. This attack will target the primary }
	{ target and also others within range. }
var
	msg: String;
	Mek: GearPtr;
	N,T,AtOp2,R: Integer;
begin
	msg := PilotName( FindMaster( Attacker ) ) + ' fires ' + GearName( Attacker ) + '.';
	RecordAnnouncement( msg );

	R := SwarmRadius( GB , Attacker );
	N := NumTargetsInRadius( GB , FindRoot( Attacker ) , Attacker , FindRoot( Attacker ) , X , Y , R );

	if N > 0 then begin
		Mek := GB^.Meks;
		T := 1;
		while Mek <> Nil do begin
			AtOp2 := ( AtOp + 1 ) div N;
			if T <= ( ( AtOp + 1 ) mod N ) then Inc( AtOp2 );

			if MekIsTargetInRadius( GB, Mek, FindRoot( Attacker ) , Attacker, FindRoot( Attacker ), X, Y, R ) and ( AtOp2 > 0 ) then begin
				Add_Shot_Animation( GB , Attacker , Mek );
				Inc( EFFECTS_Event_Order );
				AttackSingleTarget( GB , Attacker , Mek , AtOp2 - 1 , AMod , AtAt , False );
				Dec( EFFECTS_Event_Order );
				Inc( T );
			end;

			mek := Mek^.Next;
		end;
	end;

	Inc( EFFECTS_Event_Order );
end;

Function BlastRadius( GB: GameBoardPtr; Attacker: GearPtr; AList: String ): Integer;
	{ Return the blast radius of this weapon. }
var
	AA: String;
	R,T: Integer;
begin
	{ Initialize radius to 0. }
	R := 0;

	{ Move through the string looking for the BLAST attribute. }
	{ The radius should be right after it. }
	while ( AList <> '' ) and ( R = 0 ) do begin
		AA := UpCase( ExtractWord( AList ) );
		if AA = AA_Name[ AA_BlastAttack ] then R := ExtractValue( AList );
	end;

	if Attacker^.Scale > GB^.Scale then begin
		for t := 1 to ( Attacker^.Scale - GB^.Scale ) do r := r * 2;
	end else begin
		{ The weapon scale must be smaller then the }
		{ game board scale. }
		for t := 1 to ( GB^.Scale - Attacker^.Scale ) do r := r div 2;
	end;


	{ Error check on the blast radius's range. }
	if R < 1 then R := 1
	else if R > Max_Blast_Rating then R := Max_Blast_Rating;

	{ Return the result. }
	BlastRadius := R;
end;

Procedure ClearStencil;
	{ Clear the stencil, i.e. show no squares covered by effects. }
var
	X,Y: Integer;
begin
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			Stencil[ X , Y ] := False;
		end;
	end;
end;

Procedure DrawBlastEffect( GB: GameBoardPtr; X0,Y0,Z0,RNG: Integer );
	{ Calculate all the squares targeted by a blast effect centered }
	{ upon X0,Y0 with radius RNG. Store the results of the calculation }
	{ in the STENCIL array. }
const
	DBA_True = 1;
	DBA_False = -1;
	DBA_Maybe = 0;
var
	temp: Array [ -Max_Blast_Rating..Max_Blast_Rating , -Max_Blast_Rating..Max_Blast_Rating ] of integer;
	x,y: Integer;

	Procedure CheckLine(XT,YT: Integer);
	var
		t: Integer;	{A counter, and a terrain type.}
		Wall: Boolean;	{Have we hit a wall yet?}
		p: Point;
	begin
		{Check every point on the line from the origin to XT,YT,}
		{recording the results in the Temp array.}

		{ The variable WALL represents a boundary that cannot be }
		{ blasted through. }
		Wall := false;

		for t := 1 to rng do begin
			{Locate the next point on the line.}
			p := SolveLine(0,0,XT,YT,t);

			{Determine the terrain of this tile.}
			if OnTheMap( p.X + X0 , p.Y + Y0 ) then begin
				{If we have already encountered a wall, mark this square as UPV_False}
				if Wall then temp[p.x,p.y] := DBA_False;

				Case temp[p.x,p.y] of
					DBA_False: Break; {This LoS is blocked. No use searching any further.}
					DBA_Maybe: begin  {We will mark this one as true, but check for a wall later.}
						temp[p.x,p.y] := DBA_True;
						end;
					{If we got a DBA_True, we just skip merrily along without doing anything.}
				end;

				{If this current square is a wall,}
				{or if we have too much obscurement to see,}
				{set Wall to true.}
				if TileBlocksLOS( GB , p.X + X0 , p.Y + Y0 , Z0 ) then Wall := True;
			end;
		end;
	end;

begin
	{ Start by updating the shadow map. This is needed for the }
	{ TILEBLOCKSLOS function. }
	UpdateShadowMap( GB );

	{ Also clear the stencil. }
	ClearStencil;

	{ Error check. }
	if not OnTheMap( X0 , Y0 ) then exit;

	{Set every square in the temp array to Maybe.}
	for x := -Max_Blast_Rating to Max_Blast_Rating do begin
		for y := -Max_Blast_Rating to Max_Blast_Rating do begin
			temp[x,y] := DBA_Maybe;
		end;
	end;

	{Set the origin to True.}
	temp[0,0] := DBA_True;

	{ If the origin blocks the blast, it will be the only tile }
	{ affected. }
	if not TileBlocksLOS( GB , X0 , Y0 , Z0 ) then begin
		{Check the 4 cardinal directions}
		CheckLine( 0,  rng );
		CheckLine( 0, -rng );
		CheckLine(  rng, 0 );
		CheckLine( -rng, 0 );

		{Check the 4 diagonal directions}
		CheckLine(rng,rng);
		CheckLine(rng,-rng);
		CheckLine(-rng,rng);
		CheckLine(-rng,-rng);

		For X := -rng + 1 to -1 do begin
			Checkline(X,-rng);
			CheckLine(X,rng);
		end;

		For X := rng -1 downto 1 do begin
			Checkline(X,-rng);
			CheckLine(X,rng);
		end;


		For Y := -rng + 1 to -1 do begin
			Checkline(rng,Y);
			CheckLine(-rng,Y);
		end;

		For Y := rng - 1 downto 1 do begin
			CheckLine(rng,Y);
			CheckLine(-rng,Y);
		end;
	end;

	{ Copy over the TEMP array into the STENCIL array. }
	for x := -Max_Blast_Rating to Max_Blast_Rating do begin
		for y := -Max_Blast_Rating to Max_Blast_Rating do begin
			if OnTheMap( X0 + X , Y0 + Y ) and ( temp[ X , Y ] = DBA_True ) and ( Range( 0 , 0 , X , Y ) <= rng ) then begin
				Stencil[ X0 + X , Y0 + Y ] := True;
			end;
		end;
	end;
end;

Procedure DoBlastAttack( GB: GameBoardPtr; Attacker: GearPtr; X0,Y0,AtOp,AMod: Integer; AtAt: String );
	{ Do a blast radius attack. }
	{ Please note that this procedure is pretty much the LOS code }
	{ ripped from DeadCold with the attack stubs sloppily patched in. }
var
	X,Y,Rng,N,TT: Integer;
	AP,OP: Point;
	msg: String;
	Mek: GearPtr;
begin
	{ First, check for deviation of the shot. }
	AP := GearCurrentLocation( Attacker );
	AP.Z := MekAltitude( GB , FindRoot( Attacker ) );
	OP.X := X0;
	OP.Y := Y0;
	OP.Z := MekAltitude( GB , FindRoot( Attacker ) );

	{ If the attacker isn't exact enough,  move the shot around. }
	rng := Range( AP.X , AP.Y , OP.X , OP.Y );
	if ( rng > 2 ) and ( RollStep( SkillValue( FindRoot( Attacker ) , AttackSkillNeeded( Attacker ) ) ) < rng ) then begin
		OP.X := OP.X + Random( 3 ) - Random( 3 );
		OP.Y := OP.Y + Random( 3 ) - Random( 3 );
	end;

	{ Start by making the initial display. }
	msg := PilotName( FindMaster( Attacker ) ) + ' fires ' + GearName( Attacker ) + '.';
	RecordAnnouncement( msg );
	Add_Shot_Precisely( GB , AP.X , AP.Y , AP.Z , OP.X , OP.Y , OP.Z );
	Inc( EFFECTS_Event_Order );

	{ Calculate the range. }
	rng := BlastRadius( GB , ATtacker , AtAt );

	{ Generate the blast stencil. }
	DrawBlastEffect( GB , OP.X , OP.Y , OP.Z , Rng );

	{ Check the created LOS array, and perform the attack in the }
	{ requested squares. }
	for x := 1 to XMax do begin
		for y := 1 to YMax do begin
			if stencil[x,y] then begin
				{ This tile gets attacked. }
				N := NumGearsXY( GB , X , Y );
				if N > 0 then begin
					for tt := 1 to N do begin
						Mek := FindGearXY( GB , X , Y , TT );
						if not Destroyed( Mek ) then AttackSingleTarget( GB , Attacker , Mek , AtOp , AMod , AtAt , False );
					end;
				end else begin
					SceneryChewing( GB, X, Y, WeaponDC( Attacker , AtOp ), False, AtAt );
				end;

				Add_Point_Animation( X, Y, OP.Z, GS_AreaAttack );
			end;
		end; { FOR Y }
	end; { FOR X }
end;

Procedure Explosion( GB: GameBoardPtr; X0,Y0,DC,R: Integer );
	{ Make an explosion using the given coordinates, damage, and radius. }
var
	N,TT,X,Y: Integer;
	AReq: EffectRequest;
begin
	ClearAttackHistory;
	{ Fill out the effect request. }
	AReq.FXType := FX_DoDamage;
	AReq.Target := Nil;
	AReq.Originator := Nil;
	AReq.Weapon := Nil;
	AReq.AF.CantCallShot := True;
	AReq.AF.CanDodge := True;
	AReq.AF.CanBlock := True;
	AReq.AF.CanParry := False;
	AReq.AF.CanResist := False;
	AReq.AF.CanIntercept := False;
	AReq.AF.CanECM := False;
	AReq.FXDice := DC;
	AReq.FXSkill := 10;
	AReq.FXMod := 0;
	AReq.FXOption := 0;
	AReq.AF.CantCallShot := True;
	AReq.AF.CanDodge := True;
	AReq.AF.CanBlock := True;
	AReq.AF.CanParry := False;
	AReq.AF.CanIntercept := False;
	AReq.AF.CanECM := False;
	AReq.AF.AtAt := 'BLAST';
	AReq.FXDesc := '';

	{ Generate the blast stencil. }
	DrawBlastEffect( GB , X0 , Y0 , TerrMan[GB^.Map[X0,Y0].terr].altitude , R );

	{ Check the created LOS array, and perform the attack in the }
	{ requested squares. }
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			if stencil[X,Y] then begin
				{ This tile gets attacked. }
				N := NumGearsXY( GB , X , Y );
				if N > 0 then begin
				        AReq.Tx := X;
 				        AReq.Ty := Y;

					for tt := 1 to N do begin
						AReq.Target := FindGearXY( GB , X , Y , TT );
						if not Destroyed( AReq.Target ) then ProcessAttackEffect( GB, AReq );
					end;
				end;

				SceneryChewing( GB, X, Y,AReq.FXDice, True , AReq.AF.AtAt );

				Add_Point_Animation( X,  Y, TerrMan[GB^.Map[X,Y].terr].altitude, GS_AreaAttack );
			end;
		end; { FOR Y }
	end; { FOR X }
end;

Procedure DoLineAttack( GB: GameBoardPtr; Attacker: GearPtr; X,Y,Z,AtOp,AMod: Integer; AtAt: String );
	{ This procedure will do a line attack. Such an attack starts at }
	{ firer's position and attacks every target along its line of }
	{ fire. }
var
	msg: String;
	P1,P2,P: point;
	Rng,T,N,TT: Integer;
	Mek: GearPtr;
begin
	msg := PilotName( FindMaster( Attacker ) ) + ' fires ' + GearName( Attacker ) + '.';
	RecordAnnouncement( msg );
	Inc( EFFECTS_Event_Order );

	P1 := GearCurrentLocation( Attacker );
	P1.Z := MekAltitude( GB , Attacker );
	P2.X := X;
	P2.Y := Y;
	P2.Z := Z;

	p.Z := P1.Z;

	{ Total range for the line attack is equal to 2/3 the regular }
	{ weapon range, but WeaponRange knows this. }
	rng := WeaponRange( GB , Attacker );
	T := 0;

	{ Move through each square in the range until either we are blocked }
	{ or until we have reached the maximum range. }
	{ Start by updating the shadow map. This is needed for the }
	{ TILEBLOCKSLOS function. }
	UpdateShadowMap( GB );

	while ( T < rng ) do begin
		Inc( T );
		P := SolveLine( P1.X , P1.Y , P1.Z , P2.X , P2.Y , P2.Z , T );
		if OnTheMap( P.X , P.Y ) then begin
			N := NumGearsXY( GB , P.X , P.Y );
			if N > 0 then begin
				for tt := 1 to N do begin
					Mek := FindGearXY( GB , P.X , P.Y , TT );
					if ( MekAltitude( GB , Mek ) = P.Z ) and NotDestroyed( Mek ) then AttackSingleTarget( GB , Attacker , Mek , AtOp , AMod , AtAt , False );
				end;
			end;

			Add_Point_Animation( P.X, P.Y, P.Z, GS_AreaAttack );
			if TileBlocksLOS( GB , P.X , P.Y , P.Z ) then T := rng;
		end;
	end;

	Inc( EFFECTS_Event_Order );
end;

Procedure DoSTCAttack( GB: GameBoardPtr; Attacker: GearPtr; X,Y,AtOp,AMod: Integer; AtAt: String );
	{ Perform a non-damaging STC attack. }
	{ Instead of doing damage, this attack will produce a number of STC items on the gameboard. }
var
	msg: String;
	Proto,P: GearPtr;
	X2,Y2,N,T,AtOp2,R: Integer;
	AP,OP: Point;
	SRS: NAttPtr;	{ Side Reaction Score. }
begin
	msg := PilotName( FindMaster( Attacker ) ) + ' fires ' + GearName( Attacker ) + '.';
	RecordAnnouncement( msg );

	ClearStencil;

	AP := GearCurrentLocation( Attacker );
	AP.Z := MekAltitude( GB , FindRoot( Attacker ) );
	OP.X := X;
	OP.Y := Y;
	OP.Z := MekAltitude( GB , FindRoot( Attacker ) );

	{ Depending on what other attack attributes this weapon has, fill the stencil. }
	if AtOp > 0 then begin
		Stencil[ X , Y ] := True;
		Add_Shot_Precisely( GB , AP.X , AP.Y , AP.Z , OP.X , OP.Y , OP.Z );

		for t := 1 to AtOp do begin
			X2 := X + Random( 4 ) - Random( 4 );
			Y2 := Y + Random( 4 ) - Random( 4 );
			if OnTheMap( X2 , Y2 ) then begin
				Stencil[ X2 , Y2 ] := True;
				Add_Shot_Precisely( GB , AP.X , AP.Y , AP.Z , OP.X , OP.Y , OP.Z );
			end;
		end;
	end else if HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
		{ Calculate the range. }
		r := BlastRadius( GB , ATtacker , AtAt );

		{ Generate the blast stencil. }
		DrawBlastEffect( GB , X , Y , MekAltitude( GB , FindRoot( Attacker ) ) , R );

		Add_Shot_Precisely( GB , AP.X , AP.Y , AP.Z , OP.X , OP.Y , OP.Z );
	end else if HasAttackAttribute( AtAt , AA_LineAttack ) then begin
		T := 0;
		r := ( WeaponRange( GB , Attacker ) * 2 ) div 3;
		while ( T < r ) do begin
			Inc( T );
			OP := SolveLine( AP.X , AP.Y , AP.Z , X , Y , AP.Z , T );
			if OnTheMap( OP.X , OP.Y ) then begin
				Stencil[ OP.X , OP.Y ] := True;
				Add_Point_Animation( OP.X, OP.Y, OP.Z, GS_AreaAttack );
				if TileBlocksLOS( GB , OP.X , OP.Y , OP.Z ) then T := r;
			end;
		end;

	end else begin
		Stencil[ X , Y ] := True;
		Add_Shot_Precisely( GB , AP.X , AP.Y , AP.Z , OP.X , OP.Y , OP.Z );
	end;

	{ Next, actually add the items. }
	if HasAttackAttribute( AtAt , AA_Smoke ) then begin
		Proto := LoadNewSTC( 'SMOKE-1' );
		Proto^.Stat[ STAT_CloudDuration ] := Attacker^.V * 5;
		Proto^.Scale := Attacker^.Scale;
	end else if HasAttackAttribute( AtAt , AA_Gas ) then begin
		Proto := LoadNewSTC( 'GAS-1' );
		Proto^.Stat[ STAT_CloudDuration ] := Attacker^.V * 5;
		Proto^.Scale := Attacker^.Scale;
	end else if HasAttackAttribute( AtAt , AA_Drone ) then begin
		{ Step one- decide on the team for our drones! }
		R := NAttValue( FindRoot( ATtacker )^.NA , NAG_Location , NAS_Team );
		if ( R = NAV_DefPlayerTeam ) or ( R = NAV_LancemateTeam ) then begin
			T := -1;
		end else begin
			T := R;
		end;

		{ Finally, load and initialize the drone itself. }
		Proto := LoadNewSTC( 'DRONE-1' );
		Rescale( Proto , Attacker^.Scale );
		SetNAtt( Proto^.NA , NAG_Skill , 6 , Attacker^.V div 2 );
		SetNAtt( Proto^.NA , NAG_Skill , 10 , ( Attacker^.V + 1 ) div 2 );
		SetNAtt( Proto^.NA , NAG_Location , NAS_Team , T );
		GearUp( Proto );
	end else Exit;

	{ Error check }
	if Proto = Nil then Exit;

	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			if Stencil[ X , Y ] then begin
				P := CloneGear( Proto );
				SetNAtt( P^.NA , NAG_Location , NAS_X , X );
				SetNAtt( P^.NA , NAG_Location , NAS_Y , Y );
				SetNAtt( P^.NA , NAG_Location , NAS_D , Random( 8 ) );
				AppendGear( GB^.Meks , P );
				SetNAtt( P^.NA , NAG_EpisodeData, NAS_UID, MaxIdTag( GB^.Meks , NAG_EpisodeData, NAS_UID ) + 1 );
			end;
		end;
	end;

	DisposeGear( Proto );
	Inc( EFFECTS_Event_Order );
end;


Procedure PostAttackCleanup( GB: GameBoardPtr; Attacker: GearPtr; TX,TY,TZ: Integer );
	{ Deal with whatever needs to be dealt with. }
var
	Master,Engine: GearPtr;
	P: Point;
	OverLoad,T: Integer;
begin
	Master := FindRoot( Attacker );
	P.X := TX;
	P.Y := TY;

	{ If MASTER is a mecha, deal with OVERLOAD here. }
	if ( Master <> Nil ) and ( Master^.G = GG_Mecha ) and ( Attacker^.G = GG_Weapon ) then begin
		if ( Attacker^.S = GS_EMelee ) or ( Attacker^.S = GS_BeamGun ) then begin
			OverLoad := Attacker^.V + Attacker^.Stat[ STAT_BurstValue ];
			if HasAttackAttribute( WeaponAttackAttributes( Attacker ) , AA_Hyper ) then OverLoad := OverLoad * 3;
			if HasAreaEffect( Attacker ) then OverLoad := OverLoad * 2;
			if Master^.Scale > Attacker^.Scale then for t := 1 to ( Master^.Scale - Attacker^.Scale ) do Overload := Overload div 4;
			Engine := SeekGear( Master , GG_Support , GS_Engine );
			if ( Engine <> Nil ) and ( Engine^.Stat[ STAT_EngineSubType ] = EST_HighOutput ) then Overload := Overload div 2;
			OverLoad := OverLoad  - Master^.V;
			if OverLoad < 1 then OverLoad := 1;
			AddNAtt( Master^.NA , NAG_Condition , NAS_Overload , OverLoad );
		end;
	end;

	if HasAttackAttribute( WeaponAttackAttributes( Attacker ) , AA_STRAIN ) and ( Master <> Nil ) then AddStaminaDown( Master , 10 );
	if HasAttackAttribute( WeaponAttackAttributes( Attacker ) , AA_COMPLEX ) and ( Master <> Nil ) then AddMentalDown( Master , 10 );

	{ If the weapon was thrown, deal with that here. }
	if MustBeThrown( GB , Master , Attacker , P.X , P.Y ) then begin
		if Attacker^.G = GG_Ammo then begin
			{ Lower the ammo count. }
			AddNAtt( Attacker^.NA , NAG_WeaponModifier , NAS_AmmoSpent , 1 );
			if ( Attacker^.Stat[STAT_AmmoPresent] - NAttValue( Attacker^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) < 1 then begin
				if IsInvCom( Attacker ) then begin
					RemoveGear( Attacker^.Parent^.InvCom , Attacker );
				end else if IsSubCom( Attacker ) then begin
					RemoveGear( Attacker^.Parent^.SubCom , Attacker );
				end;
			end;

		end else if not HasAttackAttribute( WeaponAttackAttributes( Attacker ) , AA_Returning ) then begin
			if IsInvCom( Attacker ) then begin
				DelinkGear( Attacker^.Parent^.InvCom , Attacker );
				AppendGear( GB^.Meks , Attacker );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_X , P.X );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Y , P.Y );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Team , NAttValue( Master^.NA , NAG_Location , NAS_Team ) );

			end else if IsSubCom( Attacker ) then begin
				DelinkGear( Attacker^.Parent^.SubCom , Attacker );
				AppendGear( GB^.Meks , Attacker );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_X , P.X );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Y , P.Y );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Team , NAttValue( Master^.NA , NAG_Location , NAS_Team ) );

			end;
		end else begin
			Inc( EFFECTS_Event_Order );
			Add_Shot_Precisely( GB , TX , TY , TZ , NAttValue( Master^.NA , NAG_Location , NAS_X ) , NAttValue( Master^.NA , NAG_Location , NAS_Y ) , MekALtitude( GB , Master ) );
		end;

	end;
end;


Procedure DoAttack( GB: GameBoardPtr; Attacker,Target: GearPtr; X,Y,Z,AtOp,AMod: Integer);
	{ ATTACKER is attacking TARGET. }
	{ Attacker points to the exact gear which is doing the attack- }
	{ generally, either a weapon or a module. Target will usually be }
	{ a root level gear, unless the attacker is making a called shot. }
	{ ATOP: Attack Options. }
	{ AMod: Attack Modifier. }
var
	AtAt: String;
	Master: GearPtr;
begin
	ClearAttackHistory;

	{ Attack attributes must be determined before the attack is cleared, }
	{ since if the attack uses the last bullet in a projectile/missile }
	{ weapon's magazine then the ammo AtAt's won't be properly recognized. }
	AtAt := WeaponAttackAttributes( Attacker );

	{ Clear the weapon for usage. }
	if ClearAttack( GB , Attacker , AtOp ) then begin
		if Target <> Nil then begin
			X := NAttValue( FindRoot( Target )^.NA , NAG_LOcation , NAS_X );
			Y := NAttValue( FindRoot( Target )^.NA , NAG_LOcation , NAS_Y );
			Z := MekAltitude( GB , FindRoot( Target ) );
		end;

		if NonDamagingAttack( AtAt ) then begin
			DoSTCAttack( GB , Attacker , X , Y , AtOp , AMod , AtAt );
		end else if HasAttackAttribute( AtAt , AA_SwarmAttack ) then begin
			DoSwarmAttack( GB , Attacker , X , Y , AtOp , AMod , AtAt );
		end else if HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
			DoBlastAttack( GB , Attacker , X , Y , AtOp , AMod , AtAt );
		end else if HasAttackAttribute( AtAt , AA_LineAttack ) then begin
			DoLineAttack( GB , Attacker , X , Y , Z , AtOp , AMod , AtAt );
		end else begin
			DoDirectFireAttack( GB , Attacker , Target , X , Y , Z , AtOp , AMod , AtAt );
		end;

		Master := FindRoot( Attacker );
		if Master <> Nil then begin
			{ Set the calltime for the next attack. }
			SetNAtt( Master^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ReactionTime( Master ) );

			{ Update the alleigances of everyone involved. }
			if Target <> Nil then DeclarationOfHostilities( GB , NAttValue( Master^.NA , NAG_Location , NAS_Team ) , NAttValue( FindRoot( Target )^.NA , NAG_Location , NAS_Team ) );
		end;

		{ Perform cleanup duties. }
		PostAttackCleanup( GB , Attacker , X , Y , Z );
	end else begin
		ATTACK_Error := True;
	end;
end;

Procedure HandleEffectString( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );
	{ An effect has been triggered. Do the required operations, then }
	{ store the effects in the effect list. }
var
	EReq: EffectRequest;
begin
	ClearAttackHistory;

	EReq.FXType := ExtractValue( FX_String );
	EReq.Originator := Nil;
	EReq.Weapon := Nil;
	EReq.Target := Target;
	EReq.TX := NAttValue( FindRoot( Target )^.NA , NAG_Location , NAS_X );
	EReq.TY := NAttValue( FindRoot( Target )^.NA , NAG_Location , NAS_Y );
	EReq.FXDice := ExtractValue( FX_String );
	EReq.FXOption := ExtractValue( FX_String );
	EReq.FXSkill := ExtractValue( FX_String );
	EReq.FXMod := 0;
	EReq.AF.CantCallShot := AStringHasBString( FX_String , 'CANTCALLSHOT' );
	EReq.AF.CanDodge := AStringHasBString( FX_String , 'CanDodge' );
	EReq.AF.CanBlock := AStringHasBString( FX_String , 'CanBlock' );
	EReq.AF.CanParry := AStringHasBString( FX_String , 'CanParry' );
	EReq.AF.CanResist := AStringHasBString( FX_String , 'CanResist' );
	EReq.AF.CanIntercept := AStringHasBString( FX_String , 'CanIntercept' );
	EReq.AF.CanECM := AStringHasBString( FX_String , 'CanECM' );
	EReq.AF.AtAt := FX_String;
	EReq.FXDesc := FX_Desc;

	InvokeEffect( GB , EReq );
end;


initialization
	{ Set the history list to 0, for now. }
	ATTACK_History := Nil;
	EFFECTS_Event_Order := 0;

	FX_Messages := LoadStringList( Effects_Message_File );

finalization
	DisposeSAtt( FX_Messages );
	DisposeSAtt( ATTACK_History );

end.
