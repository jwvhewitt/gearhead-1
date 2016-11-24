unit gheffect;
	{ This unit holds the definitions and cost-calculator for }
	{ effect strings. }
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

Const
	{ Three types of FX constants... 'T' constants define }
	{ Targets. 'E' constants define effects. 'V' constants }
	{ define values. } 
	FX_T_Self = 'SELF';

	FX_E_HealthUp = 'HP+';
	FX_E_StaminaUp = 'SP+';
	FX_E_MentalUp = 'MP+';

	FX_V_SkillRoll = 'SKROLL';
	FX_V_RollStep = 'ROLLSTEP';

	SATT_Effect = 'EFFECT';

implementation

Function EffectValue( Part: GearPtr ): LongInt;
	{ Calculate the cost of this special item effect. }
begin

end;

end.
