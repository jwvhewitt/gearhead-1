unit ghholder;
	{ This unit defines hands and weapon mounts. }
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

	{ *** HOLDER FORMAT *** }
	{ G = GG_Holder }
	{ S = Holder Type }
	{ V = Undefined }


const
	GS_Hand = 0;
	GS_Mount = 1;

function HolderName( Part: GearPtr ): String;
Procedure CheckHolderRange( Part: GearPtr );
Function IsLegalHolderInv( Slot, Equip: GearPtr ): Boolean;


implementation

function HolderName( Part: GearPtr ): String;
	{ Return a default name for this part type. }
begin
	if Part^.S = GS_Hand then
		HolderName := 'Hand'
	else if Part^.S = GS_Mount then
		HolderName := 'Mounting Point';
end;

Procedure CheckHolderRange( Part: GearPtr );
	{ Examine everything about this part and make sure the values }
	{ fall within the acceptable range. }
var
	T: Integer;
begin
	{ Check S - Holder Type }
	if Part^.S < 0 then Part^.S := 1
	else if Part^.S > ( 1 ) then Part^.S := 1;

	{ Check V - Undefined }
	Part^.V := 1;

	{ Check Stats - No Stats are defined. }
	for t := 1 to NumGearStats do Part^.Stat[ T ] := 0;

end;

Function IsLegalHolderInv( Slot, Equip: GearPtr ): Boolean;
	{ Check EQUIP to see if it can be stored in SLOT. }
	{ INPUTS: Slot and Equip must both be properly allocated gears. }
	{ Mounting Points may mount weapons, movesys. }
	{ Hands may hold weapons, sensors. }
var
	it: Boolean;
begin
	if Slot^.S = GS_Hand then begin
		Case Equip^.G of
			GG_Weapon:	it := true;
			else it := False;
		end;
	end else begin
		Case Equip^.G of
			GG_Weapon:	it := true;
			GG_MoveSys:	it := true;
			else it := False;
		end;
	end;

	{ If the item is of a different scale than the holder, }
	{ it can't be held. }
	if Equip^.Scale <> Slot^.Scale then it := False;

	IsLegalHolderInv := it;
end;


end.
