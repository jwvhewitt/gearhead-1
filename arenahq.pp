unit ArenaHQ;

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

const
	NAV_StartingCash = 250000;	{ This is how much money a unit starts with. }


Procedure CreateNewUnit;
Procedure LoadUnit;
Procedure StartRPGCampaign;

Procedure DesignDirBrowser;

implementation

{$IFDEF SDLMODE}
uses ability,arenaplay,damage,gears,gearutil,ghchars,ghparser,
     locale,navigate,pcaction,randchar,randmaps,texutil,wmonster,
     sdlinfo,sdlgfx,sdlmap,sdlmenus,ui4gh;
{$ELSE}
uses ability,arenaplay,damage,gears,gearutil,ghchars,ghparser,
     locale,navigate,pcaction,randchar,randmaps,texutil,wmonster,
     coninfo,congfx,conmap,conmenus,context,ui4gh;
{$ENDIF}

Procedure SaveUnit( U: GearPtr );
	{ Save this unit to disk, in the "SaveGame" directory. }
var
	FName: String;		{ Filename for the character. }
	F: Text;		{ The file to write to. }
begin
	FName := Save_Unit_Base + GearName(U) + Default_File_Ending;
	Assign( F , FName );
	Rewrite( F );
	WriteCGears( F , U );
	Close( F );
end;

Function FindMechasPilot( U , Mek: GearPtr ): GearPtr;
	{ Search unit U to locate whatever pilot is assigned to mecha Mek. }
	{ If no such pilot is found, clear Mek's PILOT attribute and }
	{ return Nil. }
var
	pc,mpc: GearPtr;
	name: String;
begin
	{ Begin by finding the pilot's name. }
	name := SAttValue( Mek^.SA , 'pilot' );

	{ Search through the unit's Sub looking for a character of }
	{ this name. }
	pc := U^.SubCom;
	mpc := Nil;
	while ( pc <> Nil ) and ( mpc = Nil ) do begin
		if pc^.G = GG_Character then begin
			if GearName( PC ) = name then mpc := pc;
		end;
		pc := pc^.Next;
	end;

	{ If the required pilot could not be found, }
	{ delete this mecha's PILOT attribute. }
	if mpc = Nil then begin
		SetSAtt( Mek^.SA , 'pilot <>' );
	end;

	FindMechasPilot := mpc;
end;

Function CreateHQPilotMenu( U: GearPtr ): RPGMenuPtr;
	{ Allocate and fill out a menu containing all the pilots }
	{ which belong to this unit. }
var
	RPM: RPGMenuPtr;
	P: GearPtr;
	N: Integer;
	msg: String;
begin
{$IFNDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_HQPilots );
{$ENDIF}
	{ Add an entry for each pilot. }
	P := U^.SubCom;
	N := 1;
	while P <> Nil do begin
		msg := GearName( P );
		if FindPilotsMecha( U^.InvCom , P ) <> Nil then msg := msg + ' +';
		AddRPGMenuItem( RPM , msg , N );
		Inc( N );
		P := P^.Next;
	end;

	{ Return the finished menu. }
	CreateHQPilotMenu := RPM;
end;

Function CreateHQMechaMenu( U: GearPtr ): RPGMenuPtr;
	{ Allocate and fill out a menu containing all the pilots }
	{ which belong to this unit. }
var
	RPM: RPGMenuPtr;
	P,Pilot: GearPtr;
	N: Integer;
	msg: String;
begin
{$IFNDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_HQMecha );
{$ENDIF}
	{ Add an entry for each mek. }
	P := U^.InvCom;
	N := 1;
	while P <> Nil do begin
		{ Only add mechas to the menu - not items or salvage. }
		if P^.G = GG_Mecha then begin
			msg := GearName( P );
			Pilot := FindMechasPilot( U , P );
			if Pilot <> Nil then msg := msg + ' (' + GearName( Pilot ) + ')';
			AddRPGMenuItem( RPM , msg , N );
		end;
		Inc( N );
		P := P^.Next;
	end;

	{ Return the finished menu. }
	CreateHQMechaMenu := RPM;
end;

Procedure UpdateHQDisplay( U: GearPtr );
	{ Redraw the pilot and mecha lists. }
var
	DSM: RPGMenuPtr;	{ Display Menu }
begin
	DSM := CreateHQPilotMenu( U );
{$IFDEF SDLMODE}
	if DSM^.NumItem > 0 then DisplayMenu( DSM , Nil )
{$ELSE}
	if DSM^.NumItem > 0 then DisplayMenu( DSM )
{$ENDIF}
	else ClrZone(ZONE_HQPilots);
	DisposeRPGMenu( DSM );

	DSM := CreateHQMechaMenu( U );
{$IFDEF SDLMODE}
	if DSM^.NumItem > 0 then DisplayMenu( DSM , Nil )
{$ELSE}
	if DSM^.NumItem > 0 then DisplayMenu( DSM )
{$ENDIF}
	else ClrZone(ZONE_HQMecha);
	DisposeRPGMenu( DSM );

	{ Display how many credits the unit has. }
	ClrZone( ZONE_Clock );
	CMessage( '$' + BStr( NAttValue( U^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_Clock , PlayerBlue );
end;

procedure PurchaseGear( U,Part: GearPtr );
	{ The unit may or may not want to buy PART. }
	{ Show the price of this gear, and ask whether or not the }
	{ player wants to make this purchase. }
var
	YNMenu: RPGMenuPtr;
	Cost, ShopRk: LongInt;
begin
	Cost := GearValue( Part );
	ShopRk := SkillValue( U , 21 );

	if ShopRk > 10 then begin
		{ Every point of shopping skill that the unit has over 10 }
		{ gives a 2% discount to whatever is being purchased. }
		ShopRk := ( ShopRk - 10 ) * 2;
		if ShopRk > 40 then ShopRk := 40;

		Cost := ( Cost * (100 - ShopRk ) ) div 100;
	end;
	if Cost < 1 then Cost := 1;

	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AddRPGMenuItem( YNMenu , 'Buy ' + GearName( Part ) + ' ($' + BStr( Cost ) + ')' , 1 );
	AddRPGMenuItem( YNMenu , 'Search Again' , -1 );

{$IFDEF SDLMODE}
	if SelectMenu( YNMenu , Nil ) = 1 then begin
{$ELSE}
	CMessage( 'COST: ' + BStr( Cost ) , ZONE_Menu1 , InfoHilight );
	if SelectMenu( YNMenu ) = 1 then begin
{$ENDIF}
		if NAttValue( U^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
			{ Copy the gear, then stick it in inventory. }
			Part := CloneGear( Part );
			InsertInvCom( U , Part );

			{ Reduce the buyer's cash by the cost of the gear. }
			AddNAtt( U^.NA , NAG_Experience , NAS_Credits , -Cost );

			{ Update the display. }
			UpdateHQDisplay( U );

			DialogMSG( 'You have purchased ' + GearName( Part ) + '.' );
		end else begin
			{ Not enough cash to buy... }
			DialogMSG( 'You don''t have enough money to buy ' + GearName( Part ) + '.' );
		end;

	end;

	DisposeRPGMenu( YNMenu );
end;

procedure SellGear( U,Part: GearPtr );
	{ The unit may or may not want to sell PART. }
	{ Shothe price of this gear, and ask whether or not the }
	{ player wants to make this purchase. }
var
	YNMenu: RPGMenuPtr;
	Cost, ShopRk: LongInt;
begin
	Cost := ( GearValue( Part ) * PercentDamaged( Part ) ) div 100;
	if Destroyed( Part ) then Cost := Cost div 3;
	ShopRk := SkillValue( U , 21 );

	if ShopRk > 10 then begin
		{ Every point of shopping skill that the unit has }
		{ gives a 1% bonus to the money gained. }
		if ShopRk > 40 then ShopRk := 40;

		Cost := ( Cost * (20 + ShopRk ) ) div 100;
	end;
	if Cost < 1 then Cost := 1;

	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AddRPGMenuItem( YNMenu , 'Sell ' + GearName( Part ) + ' ($' + BStr( Cost ) + ')' , 1 );
	AddRPGMenuItem( YNMenu , 'Search Again' , -1 );

{$IFDEF SDLMODE}
	if SelectMenu( YNMenu , Nil ) = 1 then begin
{$ELSE}
	CMessage( 'VALUE: ' + BStr( Cost ) , ZONE_Menu1 , InfoHilight );
	if SelectMenu( YNMenu ) = 1 then begin
{$ENDIF}
		{ Increase the buyer's cash by the price of the gear. }
		AddNAtt( U^.NA , NAG_Experience , NAS_Credits , Cost );

		{ Update the display. }
		UpdateHQDisplay( U );

		DialogMSG( 'You have sold ' + GearName( Part ) + ' for $' + BStr( Cost ) + '.' );

		RemoveGear( Part^.Parent^.InvCom , Part );
	end;

	DisposeRPGMenu( YNMenu );
end;

Function RecurseFix( U,Part: GearPtr ): Integer;
	{ Recurse through the bits of the PART, looking for broken }
	{ things. }
var
	SPart: GearPtr;
	Roll,LowRoll: Integer;
begin
	LowRoll := PitFix( Part , U );

	SPart := Part^.SubCom;
	while SPart <> Nil do begin
		Roll := RecurseFix( U , SPart );
		if Roll < LowRoll then LowRoll := Roll;
		SPart := SPart^.Next;
	end;

	SPart := Part^.InvCom;
	while SPart <> Nil do begin
		Roll := RecurseFix( U , SPart );
		if Roll < LowRoll then LowRoll := Roll;
		SPart := SPart^.Next;
	end;

	RecurseFix := LowRoll;
end;

Procedure FixEntireUnit( U: GearPtr );
	{ Attempt to repair everything in the unit. }
var
	Part: GearPtr;
	C0,C1: LongInt;		{ Cash at start. }
	R,LowRoll: Integer;	{ The worst repair result generated. }
begin
	C0 := NAttValue( U^.NA , NAG_Experience , NAS_Credits );
	LowRoll := 10;

	{ Administer medical treatment to all characters. }
	Part := U^.SubCom;
	while Part <> Nil do begin
		R := RecurseFix( U , Part );
		if R < LowRoll then LowRoll := R;
		Part := Part^.Next;
	end;

	{ Administer repair to all assigned mecha. }
	Part := U^.InvCom;
	while Part <> Nil do begin
		if ( Part^.G = GG_Mecha ) and ( FindMechasPilot( U , Part ) <> Nil ) then begin
			R := RecurseFix( U , Part );
			if R < LowRoll then LowRoll := R;
		end;
		Part := Part^.Next;
	end;

	C1 := NAttValue( U^.NA , NAG_Experience , NAS_Credits );
	if C1 < C0 then begin
		DialogMSG( 'Recovery from the combat cost $' + BStr( C0 - C1 ) + '.' );
	end;
	if LowRoll < 1 then begin
		DialogMSG( 'There have been some problems...' );
	end;
end;

Procedure FixSingleGear( U,Mek: GearPtr );
	{ Attempt to repair everything in the unit. }
var
	C0,C1: LongInt;		{ Cash at start. }
	Roll: Integer;
begin
	C0 := NAttValue( U^.NA , NAG_Experience , NAS_Credits );

	Roll := RecurseFix( U , Mek );

    {$IFNDEF SDLMODE}
	DisplayGearInfo( Mek );
    {$ENDIF}

	C1 := NAttValue( U^.NA , NAG_Experience , NAS_Credits );
	if C1 < C0 then begin
		DialogMSG( 'Restoring ' + GearName( Mek ) + ' cost $' + BStr( C0 - C1 ) + '.' );
	end;
	if Roll < 1 then begin
		DialogMSG( 'There have been some problems...' );
	end;
end;

procedure AddPilotToUnit( U: GearPtr );
	{ Browse the disk for a character file. If one is selected, }
	{ display the character's stats and ask whether or not to hire }
	{ this character. If hired, add the character to the unit, }
	{ save the game, then delete the character's individual file. }
var
	PC,Temp: GearPtr;
	PCMenu,YNMenu: RPGMenuPtr;
	F: Text;
	FName: String;
begin
	{ Create the YNMenu here. It'll be the same throughout the }
	{ hiring process. }
	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	AddRPGMenuItem( YNMenu , 'Hire Character' , 1 );
	AddRPGMenuItem( YNMenu , 'Search Again' , -1 );

	DialogMSG('Select character file.');

	{ Keep querying for characters until cancel is selected. }
	repeat
		{ Create the PC menu. }
		PCMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
		BuildFileMenu( PCMenu , Save_Character_Base + Default_Search_Pattern );
		RPMSortAlpha( PCMenu );
		AddRPGMenuItem( PCMenu , '  Exit' , -1 );

		{ Select a file, then dispose of the menu. }
		{ Don't need to worry about the menu being empty because }
		{ of the EXIT item. }
{$IFDEF SDLMODE}
		FName := SelectFile( PCMenu , Nil );
{$ELSE}
		FName := SelectFile( PCMenu );
{$ENDIF}
		DisposeRPGMenu( PCMenu );

		{ If a file was selected, load it and see if the player }
		{ wants to keep it. }
		if FName <> '' then begin
			{ Load the character file. }
			Assign( F , Save_Game_Directory + FName );
			reset(F);
			PC := ReadCGears(F);
			Close(F);

			{ ERROR CHECK - make sure the file that was loaded }
			{ is in fact a valid, singular character. }
			if ( PC <> Nil ) then begin
				{ Display the character's stats. }

				{ Ask the player what to do with this character. }
{$IFDEF SDLMODE}
				if SelectMenu( YNMenu , Nil ) = 1 then begin
{$ELSE}
				DisplayGearInfo( PC );
				if SelectMenu( YNMenu ) = 1 then begin
{$ENDIF}
					{ Add the character to the unit. }
					while PC <> Nil do begin
						Temp := PC;
						DelinkGear( PC , Temp );

						if Temp^.G = GG_Character then begin
							InsertSubCom( U , Temp );
						end else begin
							InsertInvCom( U , Temp );
						end;
					end;

					{ Saving the game is done before deleting }
					{ the character file so that if there's a }
					{ problem in saving, at least the original }
					{ character file will be intact. }
					SaveUnit( U );
					Assign( F , Save_Game_Directory + FName );
					Erase(F);

					UpdateHQDisplay( U );
				end else begin
					{ Just get rid of the character. }
					DisposeGear( PC );
				end;
				ClrZone( ZONE_Info );

			end else begin
				{ PC isn't a valid character. Get rid of it. }
				DialogMSG( 'ERROR - Corrupt save file.' );
				DisposeGear( PC );
			end;
		end;
	until FName = '';

	{ Get rid of the Yes/No menu. }
	DisposeRPGMenu( YNMenu );
end;

Function SelectOneGear( List: GearPtr ): GearPtr;
	{ Choose one of the sibling gears from LIST. }
var
	BrowseMenu: RPGMenuPtr;
	Part: GearPtr;
	N: Integer;
	msg: String;
begin
	{ Create the menu. }
	BrowseMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );

	{ Add each of the gears to the menu. }
	Part := List;
	N := 1;
	while Part <> Nil do begin
		msg := SAttValue( Part^.SA , 'desig' );
		if msg <> '' then msg := msg + ' ' + GearName( Part )
		else msg := GearName( Part );
		AddRPGMenuItem( BrowseMenu , msg , N );
		Inc( N );
		Part := Part^.Next;
	end;
	RPMSortAlpha( BrowseMenu );
	AddRPGMenuItem( BrowseMenu , '  Cancel' , -1 );

	{ Select a gear. }
{$IFDEF SDLMODE}
	N := SelectMenu( BrowseMenu, Nil );
{$ELSE}
	N := SelectMenu( BrowseMenu );
{$ENDIF}
	DisposeRPGMenu( BrowseMenu );
	SelectOneGear := RetrieveGearSib( List , N );
end;

procedure BuyMechsForUnit( U: GearPtr );
	{ Create a list of mecha which are within this unit's price }
	{ range, then allow the user to browse the list and maybe }
	{ purchase some. }
var
	MekMenu: RPGMenuPtr;
	fname: String;
	m1,mek: GearPtr;	{ The start of the mecha file, }
			{ and the mek being considered for purchase. }
	F: Text;
begin
	{ Create the mecha menu. }
	MekMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( MekMenu , Design_Directory + Default_Search_Pattern );
	RPMSortAlpha( MekMenu );
	AddRPGMenuItem( MekMenu , '  Exit' , -1 );

	DialogMSG( 'Select design file.' );

	repeat
		{ Prompt the user for a file selection. }
{$IFDEF SDLMODE}
		fname := SelectFile( MekMenu , Nil );
{$ELSE}
		fname := SelectFile( MekMenu );
{$ENDIF}

		if fname <> '' then begin
			{ Load this design file, then allow the player }
			{ to select any of the gears it contains. }
			Assign(F, Design_Directory + fname );
			reset(F);
			m1 := ReadGear(F);
			Close(F);

			{ Error check- make sure something was actually loaded. }
			if ( m1 <> Nil ) then begin
				{ If there were multiple designs in this file, }
				{ allow the player to browse through them. }
				{ If there was only one design, leap straight to it. }
				if M1^.Next = Nil then Mek := M1
				else Mek := SelectOneGear( M1 );

				{ Check to make sure that Mek isn't Nil. }
				if Mek <> Nil then begin
                    {$IFNDEF SDLMODE}
					DisplayGearInfo( Mek );
                    {$ENDIF}

					PurchaseGear( U , Mek );

					{ Update the display. }
					UpdateHQDisplay( U );
				end;

				DisposeGear( m1 );
			end else begin
				DialogMsg( 'ERROR - Corrupt design file.' );
			end;
		end;
	until fname = '';

	{ Get rid of dynamic resources. }
	DisposeRPGMenu( MekMenu );
end;

procedure ExamineUnitMecha( U: GearPtr );
	{ Allow the player to browse through the unit's mechas; }
	{ selecting a mecha will bring up its info display and }
	{ a sub-menu allowing the mek to be repaired, sold, or }
	{ assigned to a pilot. }
	Procedure GetPilotForMek( M: GearPtr );
		{ Select a pilot for this mecha, then associate the two. }
	var
		PMenu: RPGMenuPtr;
		N: Integer;
	begin
{$IFNDEF SDLMODE}
		CMessage( 'SELECT CHARACTER' , ZONE_Menu1 , InfoHilight );
		DialogMSG( 'Select a pilot for ' + GearName( M ) + '.' );
{$ENDIF}
		PMenu := CreateHQPilotMenu( U );
		if PMenu^.NumItem > 0 then begin
{$IFDEF SDLMODE}
			N := SelectMenu( PMenu , Nil );
{$ELSE}
			N := SelectMenu( PMenu );
{$ENDIF}
			if N <> -1 then begin
				AssociatePilotMek( U^.InvCom , RetrieveGearSib( U^.SubCom , N ) , M );
			end;
		end;
		DisposeRPGMenu( PMenu );

		{ Update the display. }
		UpdateHQDisplay( U );
	end;
var
	MekMenu,OpMenu: RPGMenuPtr;
	Mek: GearPtr;
	MN,N: Integer;
begin
	{ Create the needed menus. }
	MekMenu := CreateHQMechaMenu( U );
	OpMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AddRPGMenuItem( OpMenu , 'Assign Pilot' , 1 );
	AddRPGMenuItem( OpMenu , 'Sell this Mecha' , -2 );
	AddRPGMenuItem( OpMenu , 'Repair Mecha' , 3 );	
	AddRPGMenuItem( OpMenu , 'Exit' , -1 );

	{ Error check- this unit better have some meks purchased already. }
	if MekMenu^.NumItem > 0 then begin
		MN := 1;
		repeat
{$IFNDEF SDLMODE}
			CMessage( 'SELECT  MECHA  TO  EXAMINE' , ZONE_Menu1 , MenuSelect );
			DrawZoneBorder( ZONE_Menu2 , PlayerBlue );
{$ENDIF}

			{ MN stands for Mek Number. }
			SetItemByValue( MekMenu , MN );
{$IFDEF SDLMODE}
			MN := SelectMenu( MekMenu , Nil );
{$ELSE}
			MN := SelectMenu( MekMenu );
{$ENDIF}

			{ If a mek was selected, go to the options menu. }
			if MN <> -1 then begin
				{ Find out what mek the player selected, }
				{ and display its info. }
				Mek := RetrieveGearSib( U^.InvCom , MN );
{$IFNDEF SDLMODE}
				DisplayGearInfo( Mek );

				{ Restore the display. }
				UpdateHQDisplay( U );
{$ENDIF}
				{ Bring up the options menu. }
				SetItemByValue( OpMenu , 1 );
				repeat
{$IFDEF SDLMODE}
					N := SelectMenu( OpMenu , Nil );
{$ELSE}
					ClrZone( ZONE_Menu1 );
					CMessage( GearName( Mek ) , ZONE_Menu1 , InfoHilight );
					N := SelectMenu( OpMenu );
{$ENDIF}
					if N = 1 then GetPilotForMek( Mek )
					else if N = -2 then SellGear( U , Mek )
					else if N = 3 then FixSingleGear( U , Mek );
				until N < 0;

				{ Refresh the mecha menu. }
				DisposeRPGMenu( MekMenu );
				MekMenu := CreateHQMechaMenu( U );

			end;

		until ( MN = -1 ) or ( MekMenu^.NumItem = 0 );

		{ Restore the display. }
		UpdateHQDisplay( U );
	end else begin
		DialogMSG( 'Your unit does not currently have any meks.' );
	end;

	{ Free dynamic resources. }
	DisposeRPGMenu( MekMenu );
	DisposeRPGMenu( OpMenu );
end;

procedure ExamineUnitPilots( U: GearPtr );
	{ Allow the player to browse through the unit's characters; }
	{ selecting a char will bring up its info display and a }
	{ sub-menu allowing the pilot to be removed from the unit, }
	{ treated for injuries / status conditions, assigned a mecha }
	{ to use in combat, or trained. }
	Procedure GetMekForPilot( P: GearPtr );
		{ Select a pilot for this mecha, then associate the two. }
	var
		MekMenu: RPGMenuPtr;
		N: Integer;
	begin
{$IFNDEF SDLMODE}
		CMessage( 'SELECT MECHA' , ZONE_Menu1 , InfoHilight );
		DialogMSG( 'Select a mecha for ' + GearName( P ) + '.' );
{$ENDIF}
		MekMenu := CreateHQMechaMenu( U );
		if MekMenu^.NumItem > 0 then begin
{$IFDEF SDLMODE}
			N := SelectMenu( MekMenu , Nil );
{$ELSE}
			N := SelectMenu( MekMenu );
{$ENDIF}
			if N <> -1 then begin
				AssociatePilotMek( U^.InvCom , P , RetrieveGearSib( U^.InvCom , N ) );
			end;
		end;
		DisposeRPGMenu( MekMenu );

		{ Update the display. }
		UpdateHQDisplay( U );
	end;

	Procedure QuitUnit( PC: GearPtr );
		{ This character wants to quit. Make it so. }
	begin
		DelinkGear( U^.SubCom , PC );
		SaveChar( PC );
		SaveUnit( U );
		DisposeGear( PC );
	end;

	Procedure ViewBiography( PC: GearPtr );
		{ Display the biography text which was generated for }
		{ this character. }
	var
		msg: String;
	begin
		msg := SAttValue( PC^.SA , 'Bio1' );
{$IFNDEF SDLMODE}
		CMessage( 'BIOGRAPHY' , ZONE_Menu1 , InfoHilight );
		GameMsg( msg , ZONE_Menu2 , InfoGreen );
{$ENDIF}
		{ Wait for a keypress before exiting. }
		RPGKey;
	end;
var
	PCMenu,OpMenu: RPGMenuPtr;
	PC: GearPtr;
	PN,N: Integer;
begin
	{ Create the needed menus. }
	PCMenu := CreateHQPilotMenu( U );
	OpMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AddRPGMenuItem( OpMenu , 'View Biography' , 3 );
	AddRPGMenuItem( OpMenu , 'Assign Mecha for Pilot' , 1 );
	AddRPGMenuItem( OpMenu , 'Do Training' , 2 );
	AddRPGMenuItem( OpMenu , 'Quit This Team' , -2 );
	AddRPGMenuItem( OpMenu , 'Exit' , -1 );

	{ Error check- this unit better have some chars hired already. }
	if PCMenu^.NumItem > 0 then begin
		PN := 1;
		repeat
{$IFNDEF SDLMODE}
			CMessage( 'SELECT  CHARACTER  TO  EXAMINE' , ZONE_Menu1 , MenuSelect );
			DrawZoneBorder( ZONE_Menu2 , PlayerBlue );
{$ENDIF}

			{ PN stands for PC Number. }
			SetItemByValue( PCMenu , PN );
{$IFDEF SDLMODE}
			PN := SelectMenu( PCMenu , Nil );
{$ELSE}
			PN := SelectMenu( PCMenu );
{$ENDIF}

			{ If a char was selected, go to the options menu. }
			if PN <> -1 then begin
				{ Find out what PC the player selected, }
				{ and display its info. }
				PC := RetrieveGearSib( U^.SubCom , PN );
{$IFNDEF SDLMODE}
				DisplayGearInfo( PC );

				{ Restore the display. }
				UpdateHQDisplay( U );
				ClrZone( ZONE_Menu1 );
{$ENDIF}

				{ Bring up the options menu. }
				SetItemByValue( OpMenu , 3 );
				repeat
{$IFDEF SDLMODE}
					N := SelectMenu( OpMenu , Nil );
{$ELSE}
					CMessage( GearName( PC ) , ZONE_Menu1 , InfoHilight );
					N := SelectMenu( OpMenu );
{$ENDIF}
					Case N of
						-2: QuitUnit( PC );
						1: GetMekForPilot( PC );
						2: DoTraining( Nil , PC );
						3: ViewBiography( PC );
					end;
				until N < 0;

				{ Refresh the pilots menu. }
				DisposeRPGMenu( PCMenu );
				PCMenu := CreateHQPilotMenu( U );

			end;

		until ( PN = -1 ) or ( PCMenu^.NumItem = 0 );

		{ Restore the display. }
		UpdateHQDisplay( U );
	end else begin
		DialogMSG( 'Your unit does not currently have any characters.' );
	end;

	{ Free dynamic resources. }
	DisposeRPGMenu( PCMenu );
	DisposeRPGMenu( OpMenu );
end;

procedure EnterCombat( HQCamp: CampaignPtr );
	{ This is the HQ combat wrapper. Prompt for mission difficulcy, }
	{ then select the Meks/Pilots who will be doing the mission. }
	{ Extract meks/pilots from the unit. }
	{ Deploy them on the map. }
	{ Select enemy forces based upon difficulcy level selected. }
	{ Call the combat procedure. }
	{ Disassemble the gameboard meks list. }
	{ Strip all location, scenario, weaponinfo NAtts. }
	{ Decide the fate of all characters and mechs; delete dead chars. }
	{ Insert surviving PCs and salvage into the unit. }
	{ Deallocate NPCs and wasted meks. }
	{ Save the game. }
var
	ECM: RPGMenuPtr;	{ Enter Combat Menu }
	Diff: Integer;		{ Difficulcy Level }
	Outcome: Integer;	{ Who won the battle? }
	Mek: GearPtr;		{ Mecha Pointer of Many Uses }
	Pilot: GearPtr;
	MList: GearPtr;		{ The list of meks which will take part }
	N: Integer;		{ A menu input code }
	msg: String;
	TPV: LongInt;
	SA: SAttPtr;
	XPV: Integer;
begin
	{ Create the difficulcy selector menu. }
	ECM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
{$IFNDEF SDLMODE}
	CMessage( 'SELECT DIFFICULCY LEVEL' , ZONE_Menu1 , InfoGreen );
{$ENDIF}
	AddRPGMenuItem( ECM , 'Easy' , 1 );
	AddRPGMenuItem( ECM , 'Regular' , 3 );
	AddRPGMenuItem( ECM , 'Hard' , 6 );
	AddRPGMenuItem( ECM , 'Suicidal' , 10 );

	{ Input the difficulcy level, and dispose of the menu right away. }
{$IFDEF SDLMODE}
	Diff := SelectMenu( ECM , Nil );
{$ELSE}
	Diff := SelectMenu( ECM );
{$ENDIF}
	DisposeRPGMenu( ECM );
{$IFNDEF SDLMODE}
	ClrZone( ZONE_Menu1 );
{$ENDIF}

	{ If the selection was not cancelled, continue with the procedure. }
	if Diff = -1 then exit;

	{ Select the list of mechas to use on this mission. }
{$IFNDEF SDLMODE}
	CMessage( 'SELECT MECHA' , ZONE_Menu1 , InfoGreen );
{$ENDIF}
	MList := Nil;
	repeat
		{ Create the mecha menu. This has to be re-created with }
		{ each iteration, since there are mecha which will be }
		{ extracted from the primary list. }
		ECM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
		Mek := HQCamp^.Source^.InvCom;
		N := 1;
		while Mek <> Nil do begin
			if ( Mek^.G = GG_Mecha ) and ( FindMechasPilot( HQCamp^.Source , Mek ) <> Nil ) then begin
				msg := GearName( Mek ) + ' (' + GearName( FindMechasPilot( HQCamp^.Source , Mek ) ) + ')';
				AddRPGMenuItem( ECM , msg , N );
			end;
			Mek := Mek^.Next;
			Inc( N );
		end;

		{ Get input from the menu, if there are any mechas left. }
		if ECM^.NumItem > 0 then begin
{$IFDEF SDLMODE}
			N := SelectMenu( ECM , Nil );
{$ELSE}
			N := SelectMenu( ECM );
{$ENDIF}
			if N > -1 then begin
				Mek := RetrieveGearSib( HQCamp^.Source^.InvCom , N );
				DelinkGear( HQCamp^.Source^.InvCom , Mek );
				Mek^.Next := MList;
				MList := Mek;
			end;
		end else N := -1;

		DisposeRPGMenu( ECM );
	until N = -1;

	{ If no mechas were selected for the mission, exit. }
	if MList = Nil then exit;

	{ Generate a random scenario. }
	HQCamp^.GB := RandomMap( Nil );

	{ Deploy the chosen mechas, along with their pilots, into the }
	{ scenario. }
	TPV := 0;
	while MList <> Nil do begin
		Mek := MList;
		MList := MList^.Next;
		Mek^.Next := Nil;

		TPV := TPV + GearValue( Mek );
		Pilot := FindMechasPilot( HQCamp^.Source , Mek );
		DelinkGear( HQCamp^.Source^.SubCom , Pilot );
		DeployMek( HQCamp^.GB , Mek , Pilot , NAV_DefPlayerTeam );
	end;

	{ Add a number of random enemies to the scenario. }
	{ Generate a shopping list of mecha found in the Design/ drawer. }
	{ Meks with Point Values larger than the value provided will be }
	{ filtered out. }
	SA := GenerateMechaList( TPV div 2 );

	{ Determine how many points of mecha to buy. This is determined by the }
	{ point value of the player meks (TPV) and the difficulcy level }
	{ selected (Diff). Yes, I'm reassigning TPV to now represent the enemy }
	{ point value... bad programming style. }
	TPV := ( TPV * Diff ) div 2;

	{ Call the SelectEnemyForces procedure from ArenaPlay. This will }
	{ choose mecha designs from the list generated & give pilots to them. }
	SelectEnemyForces( HQCamp^.GB , SA , TPV );

	{ Get rid of the mecha shopping list, since we don't need it any more. }
	DisposeSAtt( SA );

	{ Call the combat procedure. }
	Outcome := CombatMain( HQCamp );
	rpgkey;

	{ Determine the base number of XPs to give survivors. }
	if Outcome > 0 then XPV := 20 + ( Diff * 5 )
	else if Outcome = 0 then XPV := 0
	else XPV := 7 + ( Diff * 3 );

	{ Disassemble the gameboard's mecha list, sticking all the player }
	{ meks and characters back into their proper slots. }
	MList := HQCamp^.GB^.Meks;
	HQCamp^.GB^.Meks := Nil;

	{ Process each mek in turn. }
	{ While sorting through all the meks and pilots that took part }
	{ in this battle, also give out experience to the player's characters. }
	while MList <> Nil do begin
		Mek := MList;
		DelinkGear( MList , Mek );

		if Mek^.G = GG_Mecha then begin
			if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				repeat
					Pilot := ExtractPilot( Mek );
					if Pilot <> Nil then begin

						if NotDestroyed( Pilot ) then begin
							StripNAtt( Pilot , -1 );
							StripNAtt( Pilot , -2 );
							StripNAtt( Pilot , -3 );
							StripNAtt( Pilot , -5 );
							StripNAtt( Pilot , NAG_EpisodeData );
							InsertSubCom( HQCamp^.Source , Pilot );

							{ Give XP for successful mission. }
							if NotDestroyed( Mek ) then begin
								DoleExperience( Pilot , XPV );
							end else begin
								DoleExperience( Pilot , XPV div 2 );
							end;
						end else begin
							{ The pilot died. Perform a decent burial/deallocation. }
							DisposeGear( Pilot );

							{ Set PILOT to be equal to MEK, since we don't want the loop to exit right now. }
							Pilot := Mek;
						end;
					end;
				until Pilot = Nil;

				if Destroyed( Mek ) and ( Outcome < 1 ) then begin
					{ If the mek was destroyed, and the player didn't win the game, }
					{ this mek is captured and lost. }
					DisposeGear( Mek );
				end else if NotDestroyed( Mek ) or ( PercentDamaged( Mek ) > 50 ) then begin
					StripNAtt( Mek , -1 );
					StripNAtt( Mek , -2 );
					StripNAtt( Mek , -3 );
					StripNAtt( Mek , -5 );
					StripNAtt( Mek , NAG_EpisodeData );

					InsertInvCom( HQCamp^.Source , Mek );
				end else begin
					DisposeGear( Mek );
				end;
			end else if Outcome = 1 then begin
				{ The player won the game, so he may take }
				{ this mecha as salvage. }
				if OnTheMap( Mek ) and (( PercentDamaged( Mek ) > 75 ) or NotDestroyed( Mek ) ) then begin
					{ Remove the enemy pilot, of course. }
					repeat
						Pilot := ExtractPilot( Mek );
						if Pilot <> Nil then begin
							DisposeGear( Pilot );
							{ Set PILOT to be equal to MEK, since we don't want the loop to exit right now. }
							Pilot := Mek;
						end;
					until Pilot = Nil;

					StripNAtt( Mek , -1 );
					StripNAtt( Mek , -2 );
					StripNAtt( Mek , -3 );
					StripNAtt( Mek , -5 );
					StripNAtt( Mek , NAG_EpisodeData );

					InsertInvCom( HQCamp^.Source , Mek );
				end else DisposeGear( Mek );
			end else DisposeGear( Mek );

		end else if Mek^.G = GG_Character then begin
			if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				if NotDestroyed( Mek ) then begin
					StripNAtt( Mek , -1 );
					StripNAtt( Mek , -2 );
					StripNAtt( Mek , -3 );
					StripNAtt( Mek , -5 );
					StripNAtt( Mek , NAG_EpisodeData );
					InsertSubCom( HQCamp^.Source , Mek );

					{ Give experience, which is reduced if the pilot had to eject. }
					DoleExperience( Mek , XPV div 2 );
				end else DisposeGear( Mek );

			end else DisposeGear( Mek );
		end else begin
			DisposeGear( Mek );
		end;
	end;

	{ Now that the meks are out, dispose of the scenario itself. }
	DisposeMap( HQCamp^.GB );

	{ Pay the unit for their actions. }
	if Outcome > 0 then TPV := TPV div 50
	else if Outcome = 0 then TPV := 0
	else TPV := TPV div 150;
	AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , TPV );

	{ Save the game, and update the display. }
	SaveUnit( HQCamp^.Source );

	{ Repair all meks and treat all wounded pilots. }
	SetupHQDisplay;
	DialogMSG( 'You earned $' + BStr(TPV) + ' for this mission.' );
	FixEntireUnit( HQCamp^.Source );
end;

procedure HQMain( HQCamp: CampaignPtr );
	{ This is the central headquarters procedure. From here }
	{ everything else can be branched to. }
var
	RPM: RPGMenuPtr;
	n: Integer;
begin
	{ Create the HQ Menu }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	AddRPGMenuItem( RPM , 'Examine Characters' , 5 );
	AddRPGMenuItem( RPM , 'Examine Mecha' , 1 );
	AddRPGMenuItem( RPM , 'Purchase Hardware' , 2 );
	AddRPGMenuItem( RPM , 'Hire Character' , 3 );
	AddRPGMenuItem( RPM , 'Create New Character' , 4 );
	AddRPGMenuItem( RPM , 'Enter Combat' , 6 );
	AddRPGMenuItem( RPM , 'Exit to Main' , 0 );
	RPM^.mode := RPMNoCancel;

	{ Set up the display. }
	SetupHQDisplay;

	{ Keep processing until an EXIT is encountered. }
	repeat
		UpdateHQDisplay( HQCamp^.Source );
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , Nil );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}

		case N of
			5: ExamineUnitPilots( HQCamp^.Source );
			1: ExamineUnitMecha( HQCamp^.Source );
			2: BuyMechsForUnit( HQCamp^.Source );
			3: AddPilotToUnit( HQCamp^.Source );
			4: GenerateNewPC;
			6: EnterCombat( HQCamp );
			0: SaveUnit( HQCamp^.Source );
		end;
	until N <= 0;

	{ Free all dynamic resources. }
	DisposeRPGMenu( RPM );
	DisposeCampaign( HQCamp );
end;

Procedure CreateNewUnit;
	{ Start a new unit from scratch. Give it however much starting }
	{ cash and head on up to the HQMain procedure. }
var
	HQCamp: CampaignPtr;
	Name: String;
begin
	HQCamp := NewCampaign;
	HQCamp^.Source := NewGear( Nil );
	HQCamp^.Source^.G := GG_Unit;
	Name := 'New Unit';
	SetNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , NAV_StartingCash );

{$IFDEF SDLMODE}
	Name := GetStringFromUser( 'enter a name for your new unit' , Nil );
{$ELSE}
	Name := GetStringFromUser( 'enter a name for your new unit' );
{$ENDIF}
	if Name <> '' then begin
		SetSAtt( HQCamp^.Source^.SA , 'name <'+name+'>');
		SaveUnit( HQCamp^.Source );
		HQMain( HQCamp );

	end else DisposeCampaign( HQCamp );
end;

Procedure LoadUnit;
	{ Select a previously saved unit from the menu. If no unit is }
	{ found, jump to the CreateNewUnit procedure above. }
var
	RPM: RPGMenuPtr;
	uname: String;		{ Unit Name }
	HQCamp: CampaignPtr;
	F: Text;		{ A File }
begin
	{ Create a menu listing all the units in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( RPM , Save_Unit_Base + Default_Search_Pattern );

	{ If any units are found, allow the player to load one. }
	{ Otherwise, go straight to the NEW UNIT procedure. }
	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select unit file to load.');
{$IFDEF SDLMODE}
		uname := SelectFile( RPM , Nil );
{$ELSE}
		uname := SelectFile( RPM );
{$ENDIF}
		if uname <> '' then begin
			HQCamp := NewCampaign;
			Assign(F, Save_Game_Directory + uname );
			reset(F);
			HQCamp^.Source := ReadCGears(F);
			Close(F);
			HQMain( HQCamp );
		end;
	end else CreateNewUnit;

	DisposeRPGMenu( RPM );
end;

Procedure EnterCampaign( PC: GearPtr );
	{ Actually start this character in a campaign. }
var
	RPM: RPGMenuPtr;
	uname: String;
	TCamp: CampaignPtr;
	Part: GearPtr;
	F: Text;
begin
	{ Allocate the campaign structure, and load the adventure }
	{ from disk. }
	TCamp := NewCampaign;
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( RPM , Adventure_File_Base + Default_Search_Pattern );

	if RPM^.NumItem > 1 then begin
		RPMSortAlpha( RPM );
		DialogMsg( MsgString( 'SelectCampaignFile' ) );

{$IFDEF SDLMODE}
		uname := SelectFile( RPM , Nil );
{$ELSE}
		uname := SelectFile( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );
	end else if RPM^.NumItem = 1 then begin
		uname := RPM^.FirstItem^.msg;
	end else begin
		uname := '';
	end;

	if uname <> '' then begin
		Assign( F , Series_Directory + uname );
		Reset( F );
		TCamp^.Source := ReadGear( F );
		Close( F );
	end;

	if ( PC <> Nil ) and ( TCamp^.Source <> Nil ) then begin
		Part := PC;
		while Part <> Nil do begin
			if ( Part^.G = GG_Character ) and ( Part^.SubCom = Nil ) then begin
				ExpandCharacter( Part );
			end;
			Part := Part^.Next;
		end;

		Navigator( TCamp , TCamp^.Source^.SubCom , PC );
	end;

	DisposeCampaign( TCamp );
	DisposeGear( PC );
end;

Procedure StartRPGCampaign;
	{ Load & run the teaser adventure. }
var
	RPM: RPGMenuPtr;
	uname: String;
	PC: GearPtr;
	F: Text;
begin
	PC := Nil;

	{ Create a menu listing all the units in the SaveGame directory. }
{$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_TitleScreenMenu );
{$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
{$ENDIF}
	BuildFileMenu( RPM , Save_Character_Base + Default_Search_Pattern );

	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		AddRPGMenuItem( RPM , MsgString( 'STARTRPG_NewChar' ) , -2 );
		DialogMSG('Select character file.');
{$IFDEF SDLMODE}
		uname := SelectFile( RPM , Nil );
{$ELSE}
		uname := SelectFile( RPM );
{$ENDIF}
		if uname = MsgString( 'STARTRPG_NewChar' ) then begin
			EnterCampaign( CharacterCreator );
		end else if uname <> '' then begin
			Assign(F, Save_Game_Directory + uname );
			reset(F);
			PC := ReadCGears(F);
			Close(F);

			{ Erase character upon entry. }
			Assign( F , Save_Game_Directory + uName );
			Erase(F);

			EnterCampaign( PC );
		end;

	end else begin
		{ The menu was empty... make a new PC! }
		EnterCampaign( CharacterCreator );

	end;

	DisposeRPGMenu( RPM );
end;

Procedure ViewMechaDesign( Part: GearPtr );
	{ Take a look at an individual mecha. }
var
	A: Char;
	msg: String;
begin
{$IFDEF SDLMODE}
	msg := SAttValue( Part^.SA , 'DESC' );
	if ( msg <> '' ) or ( Part^.G <> GG_Mecha ) then begin
		repeat
			RedrawOpening;
			CMessage( msg , ZONE_Menu.GetRect() , InfoGreen );
			GHFlip;
			A := RPGKey;
		until ( A = ' ' ) or ( A = #27 ) or ( A = RPK_MouseButton );
	end;
	msg := MechaDescription( Part );
	if Part^.G = GG_Mecha then begin
		repeat
			RedrawOpening;
			CMessage( msg , ZONE_Menu.GetRect() , InfoGreen );
			GHFlip;
			A := RPGKey;
		until ( A = ' ' ) or ( A = #27 ) or ( A = RPK_MouseButton );
	end;
{$ELSE}
	DisplayGearInfo( Part );
	msg := SAttValue( Part^.SA , 'DESC' );
	if ( msg <> '' ) or ( Part^.G <> GG_Mecha ) then begin
		GameMsg( msg , ZONE_Menu , InfoGreen );
		EndOfGameMoreKey;
	end;
	if Part^.G = GG_Mecha then begin
		GameMsg( MechaDescription( Part ) , ZONE_Menu , InfoGreen );
		EndOfGameMoreKey;
	end;
	ClrZone( ZONE_Menu );
	ClrZone( ZONE_Info );
{$ENDIF}
end;

Procedure BrowseDesignFile( List: GearPtr );
	{ Choose one of the sibling gears from LIST and display its properties. }
	{ NOTE: This procedure must be called from the DesignDirBrowser, which must }
	{ be called directly from the arena opening menu, so that the OpeningDisplay }
	{ procedure is properly initialized. }
var
	BrowseMenu: RPGMenuPtr;
	Part: GearPtr;
	N: Integer;
begin
	{ Create the menu. }
	BrowseMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );

	{ Add each of the gears to the menu. }
	Part := List;
	N := 1;
	while Part <> Nil do begin
		AddRPGMenuItem( BrowseMenu , FullGearName( Part ) , N );
		Inc( N );
		Part := Part^.Next;
	end;
	RPMSortAlpha( BrowseMenu );
	AddRPGMenuItem( BrowseMenu , '  Cancel' , -1 );

	repeat
		{ Select a gear. }
{$IFDEF SDLMODE}
		N := SelectMenu( BrowseMenu, @RedrawOpening );
{$ELSE}
		N := SelectMenu( BrowseMenu );
{$ENDIF}
		if N > -1 then begin
			Part := RetrieveGearSib( List , N );
			ViewMechaDesign( Part );
		end;
	until N = -1;

	DisposeRPGMenu( BrowseMenu );
end;


Procedure DesignDirBrowser;
	{ Browse the mecha files on disk. }
	{ NOTE: This procedure must be called from the Arena opening menu, so that }
	{ the RedrawOpening procedure is properly initialized. }
var
	MekMenu: RPGMenuPtr;
	fname: String;
	part: GearPtr;
begin
	MekMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( MekMenu , Design_Directory + Default_Search_Pattern );
	RPMSortAlpha( MekMenu );
	AddRPGMenuItem( MekMenu , '  Exit' , -1 );

	repeat
{$IFDEF SDLMODE}
		fname := SelectFile( MekMenu , @RedrawOpening );
{$ELSE}
		fname := SelectFile( MekMenu );
{$ENDIF}

		if fname <> '' then begin
			part := LoadFile( fname , Design_Directory );
			if Part <> Nil then begin
				if Part^.Next = Nil then begin
					{ Only one mecha in this file. Just view it. }
					ViewMechaDesign( Part );
				end else begin
					{ Multiple mecha in this file. Better write another }
					{ procedure... }
					BrowseDesignFile( Part );
				end;
				DisposeGear( Part );
			end;
		end;
	until fname = '';
	DisposeRPGMenu( MekMenu );
end;


end.
