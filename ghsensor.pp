unit ghsensor;
	{ This unit covers sensors and electronics. }
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

	{ *** SENSOR FORMAT *** }
	{ G = GG_Sensor }
	{ S = Sensor Type }
	{ V = Sensor Rating / Sensor Function (depending on type) }

	{ *** ELECTRONICS FORMAT *** }
	{ G = GG_Electronics }
	{ S = Electronics Type }
	{ V = Electronics Rating / Function }

const
	NumSensorType = 3;
	GS_MainSensor = 1;
	GS_TarCom = 2;
	GS_ECM = 3;

	NumElectronicsType = 1;
	GS_PCS = 1;	{ Personal Communications System }
	GV_Memo = 1;	{ Can view adventure memos }
	GV_Email = 2;	{ Can view email messages }
	GV_Comm = 3;	{ Can receive communications from NPCs }
	GV_News = 5;	{ Can view internet global news }


Function SensorBaseDamage( Part: GearPtr ): Integer;
Function SensorName( Part: GearPtr ): String;
Function SensorBaseMass( Part: GearPtr ): Integer;
Function SensorValue( Part: GearPtr ): LongInt;

Procedure CheckSensorRange( Part: GearPtr );

Function ElecBaseDamage( Part: GearPtr ): Integer;
Function ElecName( Part: GearPtr ): String;
Function ElecBaseMass( Part: GearPtr ): Integer;
Function ElecValue( Part: GearPtr ): LongInt;

Procedure CheckElecRange( Part: GearPtr );


implementation

uses texutil;

Function SensorBaseDamage( Part: GearPtr ): Integer;
	{ Return the amount of damage this sensor can withstand. }
begin
	if Part^.S = GS_MainSensor then begin
		{ Higer grade sensors are more succeptable to damage. }
		SensorBaseDamage := 60 - ( 5 * Part^.V );
	end else begin
		SensorBaseDamage := 25;
	end;
end;

Function SensorName( Part: GearPtr ): String;
	{ Return a name for this particular sensor. }
begin
	if Part^.S = GS_MainSensor then begin
		SensorName := 'Class ' + BStr( Part^.V ) + ' Sensor';
	end else if Part^.S = GS_ECM then begin
		SensorName := 'Class ' + BStr( Part^.V ) + ' ECM Suite';
	end else begin
		SensorName := 'Class ' + BStr( Part^.V ) + ' Targeting Computer';
	end;
end;

Function SensorBaseMass( Part: GearPtr ): Integer;
	{ Return the amount of damage this sensor can withstand. }
begin
	{ As with most other components, the weight of a sensor is }
	{ equal to the amount of damage it can withstand. }
	SensorBaseMass := SensorBaseDamage( Part );
end;

Function SensorValue( Part: GearPtr ): LongInt;
	{ Calculate the base cost of this sensor type. }
begin
	if Part^.S = GS_MainSensor then begin
		SensorValue := Part^.V * Part^.V * 50 + 50;
	end else if Part^.S = GS_TarCom then begin
		SensorValue := Part^.V * Part^.V * 125;
	end else if Part^.S = GS_ECM then begin
		SensorValue := Part^.V * Part^.V * Part^.V * 500 - Part^.V * Part^.V * 350;
	end else SensorValue := 0;
end;

Procedure CheckSensorRange( Part: GearPtr );
	{ Examine this sensor to make sure everything is legal. }
begin
	{ Check S - Sensor Type }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > NumSensorType then Part^.S := 1;

	{ Check V - Sensor Rating / Sensor Function }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 10 then Part^.V := 10;

	{ Check Scale - Sensors are always SF:0 }
	if Part^.Scale <> 0 then Part^.Scale := 0;

	{ Check Stats - No Stats Defined. }

end;

Function ElecBaseDamage( Part: GearPtr ): Integer;
	{ Return the base damage score of this electronic device. }
begin
	ElecBaseDamage := 1;
end;

Function ElecName( Part: GearPtr ): String;
	{ Return the default name for this electronic device. }
begin
	ElecName := 'Electronic Device';
end;

Function ElecBaseMass( Part: GearPtr ): Integer;
	{ Return the basic mass score for this electronic device. }
begin
	ElecBaseMass := Part^.V;
end;

Function ElecValue( Part: GearPtr ): LongInt;
	{ Return the value score for this electronic device. }
begin
	ElecValue := Part^.V * Part^.V * Part^.V * 5 + Part^.V * 10 + 15;
end;

Procedure CheckElecRange( Part: GearPtr );
	{ Examine this device to make sure everything is legal. }
begin
	{ Check S - Electronics Type }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > NumElectronicsType then Part^.S := 1;

	{ Check V - Sensor Rating / Sensor Function }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 10 then Part^.V := 10;

	{ Check Stats - No Stats Defined. }

end;


end.
