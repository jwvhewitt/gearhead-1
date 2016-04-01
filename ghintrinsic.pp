unit ghintrinsic;

	{ Intrinsics are flags that can be attached to any object. They increase }
	{ the cost of that object by a finite amount. }
{
	GearHead2, a roguelike mecha CRPG
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
{$LONGSTRINGS ON}

interface

uses gears;

const
	NAG_Intrinsic = 18;

	NumIntrinsic = 7;
	NAS_Memo = 1;
	NAS_Email = 2;
	NAS_News = 3;
	NAS_Phone = 4;
	NAS_EnviroSealed = 5;
	NAS_Integral = 6;
	NAS_Personadex = 7;

	Intrinsic_Value: Array [1..NumIntrinsic] of Integer = (
		200, 300, 400, 500, 100,
		0, 250
	);


Function IntrinsicCost( Item: GearPtr ): LongInt;
Function PartHasIntrinsic( Part: GearPtr; I: Integer ): Boolean;

implementation

Function IntrinsicCost( Item: GearPtr ): LongInt;
	{ Determine the cost of all the intrinsics attached to this item. }
var
	Total: longInt;
	I: NAttPtr;
begin
	Total := 0;
	I := Item^.NA;
	while I <> Nil do begin
		if ( I^.G = NAG_Intrinsic ) and ( I^.S >= 1 ) and ( I^.S <= NumIntrinsic ) then begin
			total := total + Intrinsic_Value[ I^.S ];
		end;
		I := I^.Next;
	end;
	IntrinsicCost := Total;
end;

Function PartHasIntrinsic( Part: GearPtr; I: Integer ): Boolean;
	{ Return TRUE if Part has this intrinsic, or FALSE otherwise. }
begin
	if Part = Nil then begin
		PartHasIntrinsic := False;
	{end else if Part^.G = GG_Software then begin
		{ Software that comes loaded with an intrinsic only functions }
		{ when it's been installed on a computer. }
		PartHasIntrinsic := ( Part^.Parent <> Nil ) and ( Part^.Parent^.G = GG_Computer ) and ( NAttValue( Part^.NA , NAG_Intrinsic , I ) <> 0 );}
	end else begin
		PartHasIntrinsic := ( NAttValue( Part^.NA , NAG_Intrinsic , I ) <> 0 );
	end;
end;

end.
