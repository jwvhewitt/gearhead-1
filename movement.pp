unit movement;
	{ This is one of the primitives for GearHead. }
	{ The main purpose of this unit is to calculate the }
	{ movement rates of mecha, then return them as either }
	{ hexes per turn or clicks per hex. }

	{ *** GLOSSARY *** }
	{ Hex: One tile on the game map. }
	{ Decihex: 10 decihexes = 1 hex. A measurement I just made up to make the math nicer. }
	{ Round: One combat turn in a pen-and-paper mecha game. }
	{ Click: One time unit by the game clock. }
	{ Map Scale: Movement rates are based on the assumption that a unit will be }
	{  traveling on a game map designed for its scale. If an out of scale unit }
	{  is on the map, its movement rate will need to be adjusted. }
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

uses gears,ghmovers,ghmecha;

const
	NumMoveMode = 4;
	MM_Walk = 1;
	MM_Roll = 2;
	MM_Skim = 3;
	MM_Fly = 4;

	FormXMode: Array [0..NumForm-1,1..NumMoveMode] of boolean = (
	{	WALK	ROLL	SKIM	FLY	}
	(	True,	True,	True,	True	),	{Battroid}
	(	True,	False,	False,	True	),	{Zoanoid}
	(	False,	True,	True,	False	),	{GroundHugger}
	(	True,	False,	False,	True	),	{Arachnoid}
	(	False,	False,	False,	True	),	{AeroFighter}
	(	True,	False,	False,	True	),	{Ornithoid}
	(	True,	False,	True,	True	),	{GerWalk}
	(	False,	False,	True,	True	),	{HoverFighter}
	(	False,	True,	False,	False	)	{GroundCar}
	);

	FormSpeedLimit: Array [0..NumForm-1,1..NumMoveMode] of Integer = (
	{	WALK	ROLL	SKIM	FLY	}
	(	200,	100,	150,	150	),	{Battroid}
	(	200,	0,	0,	200	),	{Zoanoid}
	(	200,	150,	200,	0	),	{GroundHugger}
	(	200,	0,	0,	100	),	{Arachnoid}
	(	200,	0,	0,	300	),	{AeroFighter}
	(	200,	0,	0,	300	),	{Ornithoid}
	(	60,	0,	300,	250	),	{GerWalk}
	(	200,	0,	300,	250	),	{HoverFighter}
	(	200,	200,	0,	0	)	{GroundCar}
	);

	{ This next array correlates thrust points with movement systems. }
	MSysXMode: Array [1..NumMoveSys,3..NumMoveMode] of Integer = (
	{	SKIM	FLY	}
	(	0,	0	),	{ Wheels }
	(	0,	0	),	{ Tracks }
	(	75,	10	),	{ Hover Jets }
	(	0,	90	),	{ Flight Jets }
	(	80,	80	),	{ Arc Jets }
	(	7,	7	),	{ Overchargers }
	(	0,	0	),	{ Space Flight } //Not used yet...
	(	0,	0	)	{ Heavy Actuator }
	);

	MinWalkSpeed = 20;
	MinFlightSpeed = 150;	{ Minimum needed speed for true flight. }
				{ Slower than this, only jumping possible. }
	MinJumpSpeed = 30;	{ Minimum speed needed to jump. Slower }
				{ than this, and speed drops to 0. }
	ClicksPerRound = 60;	{ Used for calculating CPH move rate. }
	MinCPH = 2;		{ Fastest possible speed, in Clicks Per Hex. }

	SpeedLimit = 50;	{ Speeds higher than this get scaled down. }
	OCSpeedLimit = 20;	{ OverCharger bonuses higher than this get scaled down. }

	NAG_Action = -2;	{ These items describe the action state of the mecha.}
	NAS_MoveMode = 0;	{ Walking, Wheels, Hover, etc. }

	Jump_Recharge_Time = 100;

	Thrust_Per_Wing = 80;	{ Thrust per wing point for critters. }
	CharaThrustPerWing = 90;	{ Skim thrust per wing point. }

	Overcharge_Thrust = 125;

	MoveModeName: Array [ 1 .. NumMoveMode ] of string = (
		'Walk', 'Roll', 'Skim', 'Fly'
	);

	NAS_MoveAction = 1;	{ Stop, Cruise, Flank Speed, Turn }
	NAV_Stop = 0;
	NAV_NormSpeed = 1;
	NAV_FullSpeed = 2;
	NAV_TurnLeft = 3;
	NAV_TurnRight = 4;
	NAV_Reverse = 5;
	NAV_Hover = 6;

	NumMoveAction = 5;

	MoveActionName: Array [0..NumMoveAction] of String = (
		'Stop','Cruise Speed','Full Speed','Turn Left','Turn Right','Reverse'
	);

	NAS_MoveETA = 2;	{ Estimated Time of Arrival }
	NAS_MoveStart = 3;	{ Time when movement started }
	NAS_CallTime = 4;	{ Time when control procedure is called }
	NAS_TimeLimit = 5;	{ Time limit for jumping movement. }
	NAS_JumpRecharge = 6;

Function CountThrustPoints( Master: GearPtr; MM,Scale: Integer ): LongInt;

function NeededLegPoints( Mek: GearPtr ): Integer;
function NeededWheelPoints( Mek: GearPtr ): Integer;
function FlightThrust( Mek: GearPtr ): LongInt;

Function OverchargeBonus( Master: GearPtr ): LongInt;


function BaseMoveRate( Master: GearPtr ; MoveMode: Integer ): Integer;
function BaseMoveRate( Master: GearPtr ): Integer;
Function AdjustedMoveRate( Master: GearPtr; MoveMode, MoveOrder: Integer): Integer;
function Speedometer( Master: GearPtr ): Integer;
procedure GearUP( Mek: GearPtr );
function CPHMoveRate( Master: GearPtr ; MapScale: Integer ): Integer;
Function JumpTime( Master: GearPtr ): Integer;
Function MoveLegal( Mek: GEarPtr; MoveMode,MoveAction: Integer; COmTime: LongInt ): Boolean;
Function MoveLegal( Mek: GEarPtr; MoveAction: Integer; COmTime: LongInt ): Boolean;

Function HasAtLeastOneValidMovemode( Mek: GearPtr ): Boolean;
function MoveDesc( Master: GearPtr; mm: Integer ): String;


implementation

uses damage,gearutil,ghchars,ghmodule,ghsupport,texutil;

const
	ZoaWalkBonus = 20;	{ Bonus to walking movement for Zoanoid mecha. }

	TMWalkSpeed = 240;	{ Tripled Maximum Walking Speed }
	TMRollSpeed = 360;	{ Tripled Maximum Rolling Speed }

	CharWalkMultiplier = 4;
	CharRollMultiplier = 5;

Function CountThrustPoints( Master: GearPtr; MM,Scale: Integer ): LongInt;
	{ Count the number of thrust points for movemode MM that this }
	{ master gear has. }
var
	it: LongInt;
	Bitz: GearPtr;
begin
	{ Initialize the count to 0. }
	it := 0;

	{ Start looking for movement systems. }
	{ Only nondestroyed systems of an appropriate scale need }
	{ be checked. }
	if NotDestroyed( Master ) then begin
		{ If this gear is itself a movement system, add its }
		{ thrust points to the total. }
		if ( Master^.G = GG_MoveSys ) and ( Scale = Master^.Scale ) then begin
			it := it + MSysXMode[ Master^.S , MM ] * Master^.V;
		end;

		{ Check sub-components. }
		Bitz := Master^.SubCom;
		while Bitz <> Nil do begin
			it := it + CountThrustPoints( Bitz , MM , Scale );
			Bitz := Bitz^.Next;
		end;

		{ Check inventory components, unless MASTER is itself }
		{ a master gear (confusing I know) in which case its }
		{ inventory components will be the general inventory, }
		{ and we don't want movement systems from there to count }
		{ until they're equipped. }
		if not IsMasterGear( Master ) then begin
			Bitz := Master^.InvCom;
			while Bitz <> Nil do begin
				it := it + CountThrustPoints( Bitz , MM , Scale );
				Bitz := Bitz^.Next;
			end;
		end;
	end;

	CountThrustPoints := it;
end;

function NeededLegPoints( Mek: GearPtr ): Integer;
    { Return the number of leg points this gear needs. }
var
    it: Integer;
begin
    it := Mek^.V * 2 - 2;
    if it < 2 then it := 2;
    NeededLegPoints := it;
end;

function CalcWalk( Mek: GearPtr ): Integer;
	{ Calculate the base walking rate for this mecha. }
const
	ThrustPerHM = 25;
var
	mass: LongInt;
	spd: Integer;
	ActualLegPoints,MinLegPoints,NumLegs,MaxLegs,HM: Integer;
begin
	if Mek^.G = GG_Mecha then begin
		{ Find the mass of the mecha. This will give the basic }
		{ movement rate. }
		mass := GearMass( Mek );
		if mass < 20 then mass := 20;
		if (0 < ((TMWalkSpeed - mass) div 3)) then begin
			spd := (TMWalkSpeed - mass) div 3;
		end else begin
			spd := 0;
		end;

		if Mek^.S = GS_Zoanoid then spd := spd + ZoaWalkBonus;

		if spd < MinWalkSpeed then spd := MinWalkSpeed;

		{ This base movement rate may be reduced considerably if }
		{ the mek is damaged, or if it was just built with stubby }
		{ legs. Ideally, the number of leg points must be no less }
		{ than mecha Size * 2 - 2 }
		MinLegPoints := NeededLegPoints( Mek );

		ActualLegPoints := CountActivePoints( Mek , GG_Module , GS_Leg );
		if Mek^.S = GS_Zoanoid then begin
			{ Zoanoids count legs as arms. This may come in handy for transformers. }
			ActualLegPoints := ActualLegPoints + CountActivePoints( Mek , GG_Module , GS_Arm );
		end;

		{ Add a bonus for heavy Actuator. }
		HM := CountActivePoints( Mek , GG_MoveSys , GS_HeavyActuator ) * ThrustPerHM;
		if HM > Mass then begin
			spd := spd + ( HM * 10 ) div mass;
		end;

		if ActualLegPoints < MinLegPoints then begin
			spd := (spd * ActualLegPoints) div MinLegPoints;
			if spd < 1 then spd := 1;
		end;

		{If the number of legs has dropped below half+1,}
		{walking becomes impossible.}
		NumLegs := CountActiveParts(Mek , GG_Module , GS_Leg);
		MaxLegs := CountTotalParts(Mek , GG_Module , GS_Leg);
		if Mek^.S = GS_Zoanoid then begin
			NumLegs := NumLegs + CountActiveParts(Mek , GG_Module , GS_Arm);
			MaxLegs := MaxLegs + CountTotalParts(Mek , GG_Module , GS_Arm);
		end;
		if ( NumLegs * 2 ) < ( MaxLegs + 2 ) then spd := 0;

		{ Finally, check the gyroscope. Mecha can't walk without one. }
		if SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro ) = Nil then spd := 0;

	end else if Mek^.G = GG_Character then begin
		spd := CStat( Mek , STAT_Speed ) * CharWalkMultiplier;

		{ Reduce the walking speed if the character's legs have }
		{ been hurt. }
		MaxLegs := CountTotalParts(Mek , GG_Module , GS_Leg);
		if MaxLegs > 0 then begin
			NumLegs := CountActiveParts(Mek , GG_Module , GS_Leg);
			if ( NumLegs * 2 ) < ( MaxLegs + 2 ) then begin
				{ Unlike mecha, characters don't get entirely }
				{ immobilized by leg damage. It's assumed a }
				{ legless character can still drag itself to the }
				{ hospital using its arms, upper lip, etc. }
				spd := spd div 10;
			end else if NumLegs < MaxLegs then begin
				spd := (spd * NumLegs) div MaxLegs;
			end;

			if spd < MinWalkSpeed then spd := MinWalkSpeed;
		end;

	end else spd := 0;

	CalcWalk := spd;
end;

function NeededWheelPoints( Mek: GearPtr ): Integer;
    { Return the number of wheel points this gear needs. }
var
    it: Integer;
begin
    it := Mek^.V * 2 - 2;
    if it < 2 then it := 2;
    NeededWheelPoints := it;
end;


function CalcRoll( Mek: GearPtr ): Integer;
	{ Calculate the base ground movement rate for this mecha. }
var
	mass: LongInt;
	spd: Integer;
	ActualWheelPoints,MinWheelPoints: Integer;
begin
	{ Find the mass of the mecha. This will give the basic }
	{ movement rate. }
	if Mek^.G = GG_Mecha then begin
		mass := GearMass( Mek );
		if mass < 20 then mass := 20;
		if (0 < ((TMRollSpeed - mass) div 3)) then begin
			spd := (TMRollSpeed - mass) div 3;
		end else begin
			spd := 0;
		end;
		if spd < MinWalkSpeed then spd := MinWalkSpeed;

		if Mek^.S = GS_GroundCar then begin
			spd := ( spd * 3 ) div 2;
		end;

		MinWheelPoints := NeededWheelPoints( Mek );

	end else if Mek^.G = GG_Character then begin
		spd := CStat( Mek , STAT_Speed ) * CharRollMultiplier;

		MinWheelPoints := 10;

	end else begin
		Exit( 0 );

	end;

	ActualWheelPoints := CountActivePoints( Mek , GG_MoveSys , GS_Wheels ) + CountActivePoints( Mek , GG_MoveSys , GS_Tracks );

	if ActualWheelPoints = 0 then Exit(0);

	if ActualWheelPoints < MinWheelPoints then begin
		spd := (spd * ActualWheelPoints) div MinWheelPoints;
		if spd < 1 then spd := 1;
	end;

	CalcRoll := spd;
end;

function CalcSkim( Mek: GearPtr ): LongInt;
	{ Calculate the base hovering speed for this mecha. }
const
	spd_MAX = 2147483647;
var
	mass: Int64;
	thrust: Int64;
	spd: LongInt;
begin
	if Mek^.G = GG_Mecha then begin
		{ Calculate the mass... }
		mass := GearMass( Mek );
	end else begin
		mass := GearMass( Mek ) + 25;
	end;

	{ Calculate the number of thrust points. This is equal to }
	{ the number of active hover jets times the thrust per jet }
	{ constant. }
	thrust := CountThrustPoints( mek , MM_Skim , mek^.Scale );

	{ Characters (i.e. monsters) get skim points for having wings. }
	if Mek^.G = GG_Character then begin
		thrust := thrust + CountActivePoints( mek , GG_Module , GS_Wing ) * CharaThrustPerWing;
	end;

	if thrust >= mass then begin
		{ Speed is equal to Thrust divided by Mass. }
		{ Multiply by 10 since we want it expressed in }
		{ decihexes per round. }
		if (spd_MAX < ((thrust * 10) div mass)) then begin
			spd := spd_MAX;
		end else begin
			spd := (thrust * 10) div mass;
		end;

		{ Check the gyroscope. Lacking one will slow down the mek. }
		if ( SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro ) = Nil ) and ( Mek^.G = GG_Mecha ) then spd := spd div 2;

	end else begin
		{ This mecha doesn't have enough thrust to move at all. }
		spd := 0;
	end;

	CalcSkim := spd;
end;

function FlightThrust( Mek: GearPtr ): LongInt;
    { Calculate the number of thrust points this mecha has. }
var
    thrust,WingPoints: LongInt;
begin
	thrust := CountThrustPoints( mek , MM_Fly , mek^.Scale );

	{ Count the number of wing points present. }
	{ If there aren't enough, give a penalty to thrust. }
	WingPoints := CountActivePoints( Mek , GG_Module , GS_Wing );
	if WingPoints < MasterSize( mek ) then begin
		thrust := thrust div 2;
	end;

	{ If this is a character, wings alone provide thrust }
	{ points. This is mostly to make flying monsters work. }
	if mek^.G = GG_Character then begin
		thrust := thrust + WingPoints * Thrust_Per_Wing;

	end else if mek^.G = GG_Mecha then begin
		{ If this is a mecha, modify thrust points based }
		{ upon the type of mecha we're dealing with. }
		case mek^.S of
			GS_AeroFighter: if WingPoints > MasterSize( Mek ) then Thrust := Thrust * 2;
			GS_HoverFighter,GS_GerWalk: Thrust := ( Thrust * 5 ) div 4;
			GS_Ornithoid: begin
					if WingPoints > MasterSize( Mek ) then Thrust := ( Thrust * 3 ) div 2;
					Thrust := Thrust + WingPoints * Thrust_Per_Wing;
				end;

		end;
	end;

    FlightThrust := thrust;
end;

function CalcFly( Mek: GearPtr; TrueSpeed: Boolean ): LongInt;
	{ Calculate the base flight speed for this mecha. }
	{ Set TRUESPEED to TRUE if you want the actual speed of the }
	{ mecha, or to FALSE if you want its projected speed (needed }
	{ to calculate jumpjet time- see below. }
const
	spd_MAX = 2147483647;
var
	mass: Int64;
	thrust: Int64;
	spd: LongInt;
	WingPoints: Integer;
begin
	if Mek^.G = GG_Mecha then begin
		{ Calculate the mass... }
		mass := GearMass( Mek );
	end else begin
		mass := GearMass( Mek ) + 25;
	end;

	{ Calculate the number of thrust points. This is equal to }
	{ the number of active hover jets times the thrust per jet }
	{ constant. }
    thrust := FlightThrust( Mek );


	if thrust >= mass then begin
		{ Speed is equal to Thrust divided by Mass. }
		{ Multiply by 10 since we want it expressed in }
		{ decihexes per round. }
		if (spd_MAX < ((thrust * 10) div mass)) then begin
			spd := spd_MAX;
		end else begin
			spd := (thrust * 10) div mass;
		end;

		{ The speed will not drop below the minimum flight speed, }
		{ so long as it's above the minimum jump speed. }
		{ Jumping happens at MFS, it's just that the amount }
		{ of time you can spend in the air is lessened. }
		if ( Spd < MinJumpSpeed ) then Spd := 0
		else if ( spd < MinFlightSpeed ) and TrueSpeed then spd := MinFlightSpeed;

		{ Check the gyroscope. Lacking one will ground the mek. }
		if ( SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro ) = Nil ) and ( Mek^.G = GG_Mecha ) then spd := 0;

	end else begin
		{ This mecha doesn't have enough thrust to move at all. }
		spd := 0;
	end;

	CalcFly := spd;
end;

Function OverchargeBonus( Master: GearPtr ): LongInt;
	{ Overchargers add a bonus to a mek's FULLSPEED action. }
const
	it_MAX = 2147483647;
var
	mass: LongInt;
	thrust: LongInt;
	it: Int64;
	T,SF: Integer;
begin
	mass := GearMass( Master );
	thrust := CountActivePoints( Master , GG_MoveSys , GS_Overchargers );
	it := ( thrust * Overcharge_Thrust * 10 ) div mass;

	{ If the speed is too high, scale it back a bit. }
	for t := 1 to 10 do begin
		{ SF stands for Speed Factor. }
		SF := T * OCSpeedLimit;
		if it > SF then begin
			it := SF + ( ( it - SF ) div 2 );
		end;
	end;

	if (it_MAX < it) then begin
		it := it_MAX;
	end;

	OverchargeBonus := it;
end;

function BaseMoveRate( Master: GearPtr ; MoveMode: Integer ): Integer;
	{Check the master gear MASTER and determine how fast it can}
	{move using movement rate MOVEMODE. If the mecha is not}
	{capable of using this movemode, return 0.}
	{The movement rate is givin in decihexes per round.}
const
	it_MAX = 32767;
var
	it: LongInt;
	SF,t: Integer;
begin
	{Error check- make sure we have a valid master here.}
	if not IsMasterGear(Master) then Exit( 0 );
	if MoveMode = 0 then Exit( 0 );

	{Check to make sure the movemode is supported by the mecha's}
	{current form.}
	if Master^.G = GG_Mecha then begin
		if not FormXMode[Master^.S,MoveMode] then Exit(0);
	end;

	case MoveMode of
		MM_Walk:	it := CalcWalk( Master );
		MM_Roll:	it := CalcRoll( Master );
		MM_Skim:	it := CalcSkim( Master );
		MM_Fly:		it := CalcFly( Master , True );
		else it := 0;
	end;

	{ If the speed is too high, scale it back a bit. }
	for t := 1 to 10 do begin
		{ SF stands for Speed Factor. }
		SF := T * SpeedLimit;
		if it > SF then begin
			it := SF + ( ( it - SF ) div 2 );
		end;
	end;

	{ If the speed is higher than the mecha form speed limit, }
	{ reduce it a bit as well. }
	if Master^.G = GG_Mecha then begin
		if it > FormSpeedLimit[Master^.S,MoveMode] then begin
			it := FormSpeedLimit[Master^.S,MoveMode] + ( ( it - FormSpeedLimit[Master^.S,MoveMode] ) div 2 );
		end;
	end;

	if (it_MAX < it) then begin
		it := it_MAX;
	end;

	BaseMoveRate := it;
end;

function BaseMoveRate( Master: GearPtr ): Integer;
	{ Determine the basic movement rate for the mecha based upon its }
	{ current move mode. Do not adjust for actions. }
begin
	BaseMoveRate := BaseMoveRate( Master , NAttValue( Master^.NA , NAG_Action , NAS_MoveMode ) );
end;

function CalcMaxTurnRate( Mek: GearPtr ): Integer;
	{ Calculate the maximum possible turn rate for this mecha. }
	{ The actual turn rate will be limited by the mecha's actual }
	{ movement rate. }
var
	mass: LongInt;
	spd: Integer;
begin
	if Mek^.G = GG_Mecha then begin
		{ Find the mass of the mecha. This will give the basic }
		{ movement rate. }
		mass := GearMass( Mek );
		if mass < 20 then mass := 20;
		if (0 < ((TMWalkSpeed - mass) div 3)) then begin
			spd := (TMWalkSpeed - mass) div 3;
		end else begin
			spd := 0;
		end;

		if Mek^.S = GS_Zoanoid then spd := spd + ZoaWalkBonus;

		if spd < MinWalkSpeed then spd := MinWalkSpeed;

	end else if Mek^.G = GG_Character then begin
		spd := CStat( Mek , STAT_Speed ) * CharWalkMultiplier;
	end else spd := 0;
	CalcMaxTurnRate := spd;
end;

Function AdjustedMoveRate( Master: GearPtr; MoveMode, MoveOrder: Integer): Integer;
	{ Return the movement rate of this gear, adjusted for the }
	{ current movement action. }
var
	BMR,T,SF: Integer;
begin
	BMR := BaseMoveRate( Master , MoveMode );

	{ If turning, the mecha's speed will be limited by the }
	{ maximum turn rate. }
	if ( MoveOrder = NAV_TurnLeft ) or ( MoveOrder = NAV_TurnRight ) then begin
		T := CalcMaxTurnRate( Master );
		if T < BMR then BMR := T;
	end;

	{ If traveling at full speed, increase move rate for the }
	{ overchargers. }
	if MoveOrder = NAV_FullSpeed then begin
		BMR := BMR + OverchargeBonus( Master );
	end;

	{ Increase movement rate if the mecha is traveling at full speed.}
	if MoveOrder = NAV_FullSpeed then BMR := (BMR * 3) div 2;

	{ Turning is usually faster than moving straight ahead. }
	if ( MoveOrder = NAV_TurnLeft ) or ( MoveOrder = NAV_TurnRight ) then begin
		{ If the mecha is walking, turning is even faster }
		if MoveMode = MM_Walk then BMR := BMR * 8
		else BMR := BMR * 2;
	end;

	AdjustedMoveRate := BMR;
end;

function Speedometer( Master: GearPtr ): Integer;
	{ Determine the movement rate for the current move mode and }
	{ action. }
var
	MM,Order: Integer;
begin
	MM := NAttValue( Master^.NA , NAG_Action , NAS_MoveMode );
	Order := NAttValue( Master^.NA , NAG_Action , NAS_MoveAction );

	if ( Order = NAV_Stop ) or ( Order = NAV_Hover ) then begin
		Speedometer := 0;
	end else begin
		Speedometer := AdjustedMoveRate( Master , MM , Order );
	end;
end;

function MoveDesc( Master: GearPtr; mm: Integer ): String;
    { Return a text description of the model's move speed. }
var
    mspeed: Integer;
begin
    mspeed := AdjustedMoveRate( Master , MM , NAV_NormSpeed );
    if mspeed > 0 then begin
        if ( mm = MM_Fly ) and ( JumpTime( Master ) > 0 ) then begin
            MoveDesc := 'Jump: '+BStr(JumpTime( Master ))+'s';
        end else begin
            MoveDesc := MoveModeName[MM]+': '+BStr(mspeed);
        end;
    end else begin
        MoveDesc :=  MoveModeName[MM]+': NA';
    end;
end;

procedure GearUP( Mek: GearPtr );
	{ Set the mek's MoveMode attribute to the lowest }
	{ active movemode that this mek has. }
var
	T,MM: Integer;
begin
	MM := 0;
	for T := NumMoveMode downto 1 do begin
		if BaseMoveRate( Mek , T ) > 0 then MM := T;
	end;
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveMode , MM);
end;

function CPHMoveRate( Master: GearPtr ; MapScale: Integer ): Integer;
	{Determine the mecha's Clicks Per Hex movement rate.}
	{If this movemode is inactive, return a 0.}
	{Adjust it to deal with map scale.}
	{ *** NOTE: THIS PROCEDURE DOES NOT ADJUST FOR TERRAIN!!! *** }
var
	MoveMode,Spd,T,Order: Integer;
begin
	MoveMode := NAttValue( Master^.NA , NAG_Action , NAS_MoveMode );
	Order := NAttValue( Master^.NA , NAG_Action , NAS_MoveAction );
	Spd := AdjustedMoveRate( Master , MoveMode , Order );


	if Spd > 0 then begin
		{Convert from decihexes per round to clicks per hex.}
		Spd := ( ClicksPerRound * 10 ) div Spd;

		{As long as the mecha isn't turning, adjust time for scale.}
		if (Order <> NAV_TurnLeft) and (Order <> NAV_TurnRight) then begin
			if MapScale > Master^.Scale then begin
				for t := 1 to (MapScale - Master^.Scale) do begin
					spd := spd * 2;
				end;
			end else if MapScale < Master^.Scale then begin
				for t := 1 to (MapScale - Master^.Scale) do begin
					spd := spd div 2;
				end;
			end;
		end;

		if Spd < MinCPH then Spd := MinCPH;
	end;

	CPHMoveRate := Spd;
end;

Function JumpTime( Master: GearPtr ): Integer;
	{ Return the amount of time that this jumping mecha can stay }
	{ in the air. If the mecha is capable of true flight }
	{ return 0. If the mecha is not capable of either jumping or }
	{ flight, the return of this function is undefined, but just }
	{ between you and me it's gonna be 0. }
var
	it: Integer;
begin
	it := CalcFly( Master , False );

	{ Zoanoids and Arachnoids cannot fly, but they jump really well. }
	if ( Master^.G = GG_Mecha ) and (( Master^.S = GS_Zoanoid ) or ( Master^.S = GS_Arachnoid )) then begin
		it := ( it * 3 ) div 2;
	end else if it >= MinFlightSpeed then begin
		it := 0;
	end;

	JumpTime := ( it + 1 ) div 2;
end;

Function MoveLegal( Mek: GEarPtr; MoveMode,MoveAction: Integer; COmTime: LongInt ): Boolean;
	{ Return TRUE if the given action is legal for this mecha, }
	{ or FALSE if it isn't. }
var
	it: Boolean;
	CMA: Integer;
begin
	{ Assume TRUE unless this is one of the exceptions. }
	it := True;

	{ Find the current move action being used. }
	CMA := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );

	{ Reverse movement is only possible if walking or rolling. }
	if MoveAction = NAV_Reverse then begin
		it := ( MoveMode = MM_Walk ) or ( MoveMode = MM_Roll );
	end else if MoveMode = MM_Fly then begin
		if ( JumpTime( Mek ) > 0 ) then begin
			{ Jumping meks are forbidden from turning while airborne. }
			if ( MoveAction = NAV_TurnLeft ) or ( MoveAction = NAV_TurnRight ) then begin
				if CMA <> NAV_Stop then it := false;
			end else if ( MoveAction = NAV_FullSpeed ) or ( MoveAction = NAV_Hover ) then begin
				it := False;
			end else if ( MoveAction = NAV_NormSpeed ) and ( CMA <> NAV_NormSpeed ) then begin
				it := NAttValue( Mek^.NA , NAG_Action , NAS_JumpRecharge ) < ComTime;
			end;

		end else if ( MoveAction = NAV_Stop ) or ( MoveAction = NAV_Hover ) then begin
			{ Flying mecha can only stop if they are }
			{ capable of skimming. }
			it := BaseMoveRate( Mek , MM_Skim ) > 0;
		end;
	end else if MoveAction = NAV_Hover then begin
		{ Only flying mecha are capable of hovering, and even those might not }
		{ be able to do it... }
		it := False;
	end;

	MoveLegal := it;
end;

Function MoveLegal( Mek: GEarPtr; MoveAction: Integer; COmTime: LongInt ): Boolean;
	{ Return TRUE if the specified action is legal for the specified }
	{ movemode, or FALSE if it isn't. }
var
	MoveMode: Integer;
begin
	MoveMode := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	MoveLegal := MoveLegal( Mek , MoveMode , MoveAction , ComTime );
end;

Function HasAtLeastOneValidMovemode( Mek: GearPtr ): Boolean;
	{ Return TRUE if this mecha has some way of moving, or FALSE if it doesn't. }
var
	T: Integer;
	ItDoes: Boolean;
begin
	{ Assume FALSE, until we find a working movemode. }
	ItDoes := False;
	for t := 1 to NumMoveMode do begin
		if BaseMoveRate( Mek , T ) > 0 then ItDoes := True;
	end;
	HasAtLeastOneValidMovemode := ItDoes;
end;

end.
