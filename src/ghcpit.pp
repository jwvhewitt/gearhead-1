unit ghcpit;
	{Defines stuff associated with Cockpit gears.}
	{May be normal cockpits, passenger compartments,}
	{submecha storage, or whatever else you want.}
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

	{ G = GG_Cockpit }
	{ V = Cockpit Style }
	{ STAT 1 = Armor Rating }
	{ STAT 2 = Passenger Scale }

Function CockpitBaseMass( CPit: GearPtr ): Integer;
Procedure CheckCPitRange( CPit: GearPtr );
Function IsLegalCPitSub( Part, Equip: GearPtr ): Boolean;


implementation

Function CockpitBaseMass( CPit: GearPtr ): Integer;
	{Cockpits usually have no weight... unless they're}
	{armored. In that case, the weight of the cockpit}
	{equals the armor rating assigned to it.}
begin
	CockpitBaseMass := CPit^.Stat[1];
end;

Procedure CheckCPitRange( CPit: GearPtr );
	{ Examine the values of all the cockpit's stats and make sure }
	{ everything is nice and legal. }
var
	T: Integer;
	Master,S,S2: GearPtr;
begin
	{ Check S - Currently Undefined }
	CPit^.S := 0;

	{ Check V - Cockpit Type; Currently Undefined }
	CPit^.V := 0;

	{ Check Stats }
	{ Stat 1 - Armor }
	if CPit^.Stat[1] < 0 then CPit^.Stat[1] := 0
	else if CPit^.Stat[1] > 2 then CPit^.Stat[1] := 2;

	{ Stat 2 - Pilot Scale }
	{ The scale of the piot must be less than the scale of }
	{ the cockpit. }
	if CPit^.Stat[2] >= CPit^.Scale then CPit^.Stat[2] := CPit^.Scale - 1;

	for t := 3 to NumGearStats do CPit^.Stat[ T ] := 0;
end;

Function IsLegalCPitSub( Part, Equip: GearPtr ): Boolean;
	{ Return TRUE if the specified EQUIP may be legally installed }
	{ in PART, FALSE if it can't be. }
begin
	if ( Equip^.G = GG_Character ) and ( Equip^.Scale = Part^.Stat[2] ) then IsLegalCPitSub := True
	else IsLegalCPitSub := False;
end;

end.
