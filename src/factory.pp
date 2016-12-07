unit factory;
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

uses texutil,gears,gearutil,context,congfx,coninfo,conmenus,menugear;


Procedure CreateNewMecha;

implementation

uses ghmecha,ghmodule,ghsupport;

const
	FMI_SetName = 1;
	FMI_SetDesig = 2;
	FMI_AddPart = 3;
	FMI_SaveDesign = 6;
	FMI_Cancel = 7;

Function SelectMechaForm: Integer;
	{ Select a mecha form. }
	Function FormMenuItem( T: Integer ): String;
	var
		msg: String;
	begin
		msg := FormName[ T ];
		while Length( msg ) < 15 do msg := msg + ' ';
		FormMenuItem := msg + '  [ ' + SgnStr( FormMVBonus[ T ] ) + ' MV / '  + SgnStr( FormTRBonus[ T ] ) + ' TR ]';
	end;
var
	RPM: RPGMenuPtr;
	T: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Factory_Parts );
	AttachMenuDesc( RPM , ZONE_Info );
	GameMsg( MsgString( 'FACTORY_SelectForm' ) , ZONE_Factory_Caption , MenuSelect  );

	{ Add one menu item for each available form. }
	for t := 0 to (NumForm-1) do begin
		AddRPGMenuItem( RPM , FormMenuItem( T ) , T , MsgString( 'FACTORY_Form' + BStr( T ) ) );
	end;

	T := SelectMenu( RPM );
	DisposeRPGMenu( RPM );
	ClrZone( ZONE_Factory_Caption );
	SelectMechaForm := T;
end;

Function SelectMechaSize: Integer;
	{ Select a mecha size. }
var
	RPM: RPGMenuPtr;
	T: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Factory_Parts );
	GameMsg( MsgString( 'FACTORY_SelectSize' ) , ZONE_Factory_Caption , MenuSelect );

	{ Add one menu item for each available form. }
	for t := 1 to 10 do begin
		AddRPGMenuItem( RPM , MsgString( 'FACTORY_Size' + BStr( T ) ) , T );
	end;

	T := SelectMenu( RPM );
	DisposeRPGMenu( RPM );
	ClrZone( ZONE_Factory_Caption );
	SelectMechaSize := T;
end;

Procedure SetMechaSAtt( Mek: GearPtr; label: String );
	{ Set a string attribute for this mecha... usually either NAME }
	{ or DESIG. }
var
	info: String;
begin
	info := GetStringFromUser( ReplaceHash( MsgString( 'FACTORY_GetSAtt' ) , label ) );
	if info <> '' then SetSATt( Mek^.SA , label + ' <' + info + '>' );
end;

Function SelectPartToAdd( Mek: GearPtr ): GearPtr;
	{ Select a part to add to this mecha. Return a pointer to the }
	{ new part, which must then be linked into the mecha somewhere. }
begin
	{ First, decide whether to add a weapon, module, movesys, or }
	{ sensor. }

	{ Depending on what kind of gear was selected, decide on a specific }
	{ gear to return. }

end;

Procedure AddPartToMecha( Mek: GearPtr );
	{ Add a part to this mecha. }
var
	Part: GearPtr;
begin
	Part := SelectPartToAdd( Mek );

end;

Procedure EditMecha( Mek: GearPtr );
	{ This part is going to be edited. Print up a menu and }
	{ prompt for choices. The menu items will be dependant upon }
	{ the item's type. }
var
	PartMenu,ControlMenu: RPGMenuPtr;
	A: Integer;	{ Action }
begin
	PartMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Factory_Parts );
	BuildGearMenu( PartMenu , Mek );
	DisplayGearInfo( Mek );
	DisplayMenu( PartMenu );
	DisposeRPGMenu( PartMenu );

	ControlMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	AddRPGMenuItem( ControlMenu , MsgString( 'FACTORY_SetName' ) , FMI_SetName );
	AddRPGMenuItem( ControlMenu , MsgString( 'FACTORY_SetDesignation' ) , FMI_SetDesig );
	AddRPGMenuItem( ControlMenu , MsgString( 'FACTORY_AddPart' ) , FMI_AddPart );

	repeat
		BuildGearMenu( PartMenu , Mek );
		DisplayGearInfo( Mek );
		DisplayMenu( PartMenu );
		DisposeRPGMenu( PartMenu );

		A := SelectMenu( ControlMenu );

		Case A of
			FMI_SetName:	SetMechaSAtt( Mek , 'NAME' );
			FMI_SetDesig:	SetMechaSAtt( Mek , 'DESIG' );
			FMI_AddPart:	AddPartToMecha( Mek );
		end;
	until A = -1;
end;

Procedure CreateNewMecha;
	{ This function will allow the player to design a brand new mecha, }
	{ then return a pointer to the resultant gear. }
var
	M_Form,M_Size: Integer;
	Mek,Body,Part: GearPtr;
begin
	SetupFactoryDisplay;

	{ Step One - Select a form. }
	M_Form := SelectMechaForm;
	if M_Form = -1 then Exit;

	{ Step Two - Select mecha size. }
	M_Size := SelectMechaSize;
	if M_Size = -1 then Exit;

	{ Create a blank mecha form with nothing but a body, engine, }
	{ gyro and cockpit. }
	Mek := NewGear( Nil );
	Mek^.G := GG_Mecha;
	Mek^.S := M_Form;
	Mek^.V := M_Size;
	InitGear( Mek );

	Body := AddGear( Mek^.SubCom , Mek );
	Body^.G := GG_Module;
	Body^.S := GS_Body;
	Body^.V := M_Size;
	InitGear( Body );

	Part := AddGear( Body^.SubCom , Body );
	Part^.G := GG_Support;
	Part^.S := GS_Engine;
	Part^.V := M_Size;
	InitGear( Part );

	Part := AddGear( Body^.SubCom , Body );
	Part^.G := GG_Support;
	Part^.S := GS_Gyro;
	Part^.V := 1;
	InitGear( Part );

	Part := AddGear( Body^.SubCom , Body );
	Part^.G := GG_Cockpit;
	InitGear( Part );


	{ Keep editing the parts until the user selects either "CANCEL" }
	{ or "SAVE". }
	EditMecha( Mek );
	DisposeGear( Mek );
end;

end.
