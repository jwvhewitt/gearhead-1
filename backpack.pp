unit backpack;
	{ This unit handles both the inventory display and the }
	{ FieldHQ interface, which uses many of the same things. }
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

{$IFDEF SDLMODE}
uses gears,locale,sdlgfx,ui4gh;
{$ELSE}
uses gears,locale;
{$ENDIF}

const
	TRIGGER_GetItem = 'GET';

{$IFDEF SDLMODE}
Procedure SelectColors( M: GearPtr; Redrawer: RedrawProcedureType );
Procedure SelectSprite( M: GearPtr; Redrawer: RedrawProcedureType );
{$ENDIF}

Function LanceMateMenuName( M: GearPtr ): String;
Function FindNextPC( GB: GameBoardPtr; CurrentPC: GearPtr ): GearPtr;
Function FindPrevPC( GB: GameBoardPtr; CurrentPC: GearPtr ): GearPtr;


Procedure GivePartToPC( GB: GameBoardPtr; Part, PC: GearPtr );

Function SelectRobotParts( GB: GameBoardPtr; PC: GearPtr ): GearPtr;

Procedure DoFieldRepair( GB: GameBoardPtr; PC , Item: GearPtr; Skill: Integer );

Function Handless( Mek: GearPtr ): Boolean;
Function ShakeDown( GB: GameBoardPtr; Part: GearPtr; X,Y: Integer ): LongInt;
Procedure PCGetItem( GB: GameBoardPtr; PC: GearPtr );
Procedure StartContinuousUseItem( GB: GameBoardPtr; TruePC , Item: GearPtr );

Procedure FHQ_SelectMechaForPilot( GB: GameBoardPtr; NPC: GearPtr );
Procedure LancemateBackpack( GB: GameBoardPtr; PC,NPC: GearPtr );
Procedure BackpackMenu( GB: GameBoardPtr; PC: GearPtr; StartWithInv: Boolean );

{$IFDEF SDLMODE}
Procedure MechaPartBrowser( Mek: GearPtr; RDP: RedrawProcedureType );
{$ELSE}
Procedure MechaPartBrowser( Mek: GearPtr );
{$ENDIF}

Procedure FHQ_ThisWargearWasSelected( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr );


implementation

{$IFDEF SDLMODE}
uses ability,action,arenacfe,arenascript,damage,gearutil,ghchars,ghholder,
     ghmodule,ghprop,ghswag,interact,menugear,rpgdice,skilluse,texutil,
     sdlinfo,sdlmap,sdlmenus,ghweapon,colormenu;
{$ELSE}
uses ability,action,arenacfe,arenascript,damage,gearutil,ghchars,ghholder,
     ghmodule,ghprop,ghswag,interact,menugear,rpgdice,skilluse,texutil,
     congfx,coninfo,conmap,conmenus,context,ghweapon;
{$ENDIF}

var
	ForceQuit: Boolean;
	EqpRPM,InvRPM: RPGMenuPtr;
{$IFDEF SDLMODE}
	InfoGear: GearPtr;	{ Gear to appear in the INFO menu. }

	BP_Source: GearPtr;	{ Gear whose inventory is being examined. }
    BP_Focus: GearPtr;  { Gear which is being focused on for FocusOnOneItemRedraw }
	BP_SeekSibs: Boolean;	{ TRUE if the menu lists sibling gears; FALSE if it lists child gears. }
	BP_ActiveMenu: RPGMenuPtr;	{ The active menu. Used to determine the gear to show info about. }
    BPRD_Caption: String;

	InfoGB: GameBoardPtr;
	MPB_Redraw: RedrawProcedureType;
	MPB_Gear: GearPtr;

Procedure PlainRedraw;
	{ Miscellaneous menu redraw procedure. }
begin
	if InfoGB <> Nil then SDLCombatDisplay( InfoGB );
	{if InfoGear <> Nil then DisplayGearInfo( InfoGear , InfoGB );}
end;

Procedure EqpRedraw;
	{ Show Inventory, select Equipment. }
var
    N: Integer;
    Part: GearPtr;
begin
	SDLCombatDisplay( InfoGB );
	DrawBPBorder;
	DisplayMenu( InvRPM , Nil );
    DrawBackpackHeader( BP_Source );
	GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BPInstructions.GetRect() , MenuItem );
	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		N := CurrentMenuItemValue( BP_ActiveMenu );
		if N > 0 then begin
			if BP_SeekSibs then Part := RetrieveGearSib( BP_Source , N )
			else Part := LocateGearByNumber( BP_Source , N );
			if Part <> Nil then begin
            	LongformGearInfo( Part , InfoGB, ZONE_BPInfo );
			end;
		end;
	end;
end;

Procedure InvRedraw;
	{ Show Equipment, select Inventory. }
var
    N: Integer;
    Part: GearPtr;
begin
	SDLCombatDisplay( InfoGB );
	DrawBPBorder;
	DisplayMenu( EqpRPM , Nil );
    DrawBackpackHeader( BP_Source );
	GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BPInstructions.GetRect() , MenuItem );
	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		N := CurrentMenuItemValue( BP_ActiveMenu );
		if N > 0 then begin
			if BP_SeekSibs then Part := RetrieveGearSib( BP_Source , N )
			else Part := LocateGearByNumber( BP_Source , N );
			if Part <> Nil then begin
            	LongformGearInfo( Part , InfoGB, ZONE_BPInfo );
			end;
		end;
	end;
end;

Procedure FocusOnOneItemRedraw;
	{ Miscellaneous menu redraw procedure. The Eqp display will be shown; }
	{ the INV display won't be. }
begin
	if InfoGB <> Nil then SDLCombatDisplay( InfoGB );
	DrawBPBorder;
	LongformGearInfo( BP_Focus , InfoGB, ZONE_BPInfo );
    DrawBackpackHeader( BP_Source );
	if EqpRPM <> Nil then begin
		DisplayMenu( EqpRPM , Nil );
		GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BPInstructions.GetRect() , MenuItem );
	end;
end;

Procedure FHQWargearRedraw;
	{ Do a redraw for the Field HQ. }
var
	Part: GearPtr;
begin
	if InfoGB <> Nil then SDLCombatDisplay( InfoGB );
    if BPRD_CAPTION <> '' then begin
    	InfoBox( ZONE_FHQTitle.GetRect() );
        CMessage( BPRD_CAPTION , ZONE_FHQTitle.GetRect() , InfoHilight );
    end;
    InfoBox( ZONE_FHQMenu.GetRect() );
    InfoBox( ZONE_FHQInfo.GetRect() );
	LongformGearInfo( InfoGear , InfoGB, ZONE_FHQInfo );
end;



Procedure TradeItemRedraw;
	{ Miscellaneous menu redraw procedure. The Eqp display will be shown; }
	{ the INV display won't be. }
begin
	if InfoGB <> Nil then SDLCombatDisplay( InfoGB );
	DrawBPBorder;
	if InfoGear <> Nil then 	LongformGearInfo( InfoGear , InfoGB, ZONE_BPInfo );
	if EqpRPM <> Nil then begin
		DisplayMenu( EqpRPM , Nil );
		GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BPInstructions.GetRect() , MenuItem );
	end;
end;

Procedure RobotPartRedraw;
	{ Redraw procedure for the robot part selector. }
begin
	if InfoGB <> Nil then SDLCombatDisplay( InfoGB );
	DrawBPBorder;
	{if InfoGear <> Nil then DisplayGearInfo( InfoGear , InfoGB );}
	GameMsg( MsgString( 'SELECT_ROBOT_PARTS' ) , ZONE_EqpMenu.GetRect() , MenuItem );
end;

Procedure SelectColors( M: GearPtr; Redrawer: RedrawProcedureType );
	{ The player wants to change the colors for this part. Make it so. }
	{ Use the colormenu unit, backported from GH2. }
var
    mysprite,startpal,mypal: String;
begin
{$IFDEF SDLMODE}
    startpal := SAttValue( m^.SA, 'SDL_COLORS' );
	if M^.G = GG_Character then begin
        mypal := SelectColorPalette( colormenu_mode_character, SAttValue( m^.SA, 'SDL_PORTRAIT' ), startpal, 100, 150, 0, Redrawer );
	end else begin
        mypal := SelectColorPalette( colormenu_mode_mecha, SAttValue( m^.SA, 'SDL_SPRITE' ), startpal, 64, 64, 8, Redrawer );
    end;
    SetSAtt( M^.SA, 'SDL_COLORS <' + mypal + '>' );
{$ENDIF}
end;


Procedure SelectSprite( M: GearPtr; Redrawer: RedrawProcedureType );
	{ The player wants to change the colors for sprite for this character. }
	{ The menu will be placed in the Menu area; assume the redrawer will }
	{ show whatever changes are made here. }
var
	RPM: RPGMenuPtr;
	fname: String;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	if NAttValue( M^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Female then begin
		BuildFileMenu( RPM , Graphics_Directory + 'cha_f_*.*' );
	end else begin
		BuildFileMenu( RPM , Graphics_Directory + 'cha_m_*.*' );
	end;
	AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

	fname := SelectFile( RPM , Redrawer );

	if fname <> '' then begin
		SetSAtt( M^.SA , 'SDL_SPRITE <' + fname + '>' );
	end;

	DisposeRPGMenu( RPM );
end;

{$ENDIF}


Function LanceMateMenuName( M: GearPtr ): String;
var
	msg,pilot: string;
begin
	msg := FullGearName( M );

	if M^.G = GG_Mecha then begin
		pilot := SAttValue( M^.SA , 'PILOT' );
		if pilot <> '' then msg := msg + ' (' + pilot + ')';
	end;

	LanceMateMenuName := msg;
end;

Function FindNextPC( GB: GameBoardPtr; CurrentPC: GearPtr ): GearPtr;
    { Locate the next player character on the gameboard. }
    Function IsPC( PC: GearPtr ): Boolean;
        { Return True if this is a PC, or False otherwise. }
    begin
        IsPC := IsMasterGear( PC ) and GearActive(PC) and ((NAttValue( PC^.NA , NAG_Location, NAS_Team ) = NAV_DefPlayerTeam) or (NAttValue( PC^.NA , NAG_Location, NAS_Team ) = NAV_LancemateTeam));
    end;
var
    PC,NextPC,FirstPC: GearPtr;
    FoundStart: Boolean;
begin
    NextPC := Nil;
    FirstPC := Nil;
    FoundStart := CurrentPC = Nil;

    PC := GB^.Meks;
    while ( PC <> Nil ) and ( NextPC = Nil ) do begin
        if IsPC(PC) then begin
            if FirstPC = Nil then FirstPC := PC;
            if FoundStart and (NextPC = Nil) then NextPC := PC;
            if PC = CurrentPC then FoundStart := True;
        end;
        PC := PC^.Next;
    end;
	if NextPC = Nil then begin
		if FirstPC = Nil then FindNextPC := CurrentPC
		else FindNextPC := FirstPC;
	end else FindNextPC := NextPC;
end;

Function FindPrevPC( GB: GameBoardPtr; CurrentPC: GearPtr ): GearPtr;
    { Locate the previous player character on the gameboard. }
    Function IsPC( PC: GearPtr ): Boolean;
        { Return True if this is a PC, or False otherwise. }
    begin
        IsPC := IsMasterGear( PC ) and GearActive(PC) and ((NAttValue( PC^.NA , NAG_Location, NAS_Team ) = NAV_DefPlayerTeam) or (NAttValue( PC^.NA , NAG_Location, NAS_Team ) = NAV_LancemateTeam));
    end;
var
    PC,PrevPC,LastPC: GearPtr;
    FoundStart: Boolean;
begin
    PrevPC := Nil;
    LastPC := Nil;
    FoundStart := CurrentPC = Nil;

    PC := GB^.Meks;
    while ( PC <> Nil ) and not FoundStart do begin
        if IsPC(PC) then begin
            PrevPC := LastPC;
            if PC <> CurrentPC then LastPC := PC
            else if PrevPC <> Nil then FoundStart := True;
        end;
        PC := PC^.Next;
    end;
	if not FoundStart then begin
		if LastPC = Nil then FindPrevPC := CurrentPC
		else FindPrevPC := LastPC;
	end else FindPrevPC := PrevPC;
end;


Function SelectRobotParts( GB: GameBoardPtr; PC: GearPtr ): GearPtr;
	{ Select up to 10 parts to build a robot with. }
	{ Delink them from the INVENTORY and return them as a list. }
var
	Ingredients,Part,P2: GearPtr;
	RPM: RPGMenuPtr;
	N: Integer;
begin
{$IFNDEF SDLMODE}
	DrawBPBorder;
	GameMsg( MsgString( 'SELECT_ROBOT_PARTS' ) , ZONE_EqpMenu , MenuItem );
{$ELSE}
	InfoGB := GB;
	InfoGear := PC;
{$ENDIF}
	Ingredients := Nil;
	repeat
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
		RPM^.Mode := RPMNoCleanup;

		Part := PC^.InvCom;
		N := 1;
		while Part <> Nil do begin
			if ( Part^.G = GG_Weapon ) or ( Part^.G = GG_Shield ) or ( Part^.G = GG_ExArmor ) or ( Part^.G = GG_Sensor ) or ( Part^.G = GG_Electronics ) then begin
				AddRPGMenuItem( RPM , GearName( Part ) , N );
			end else if ( Part^.G = GG_RepairFuel ) and ( ( Part^.S = 15 ) or ( Part^.S = 23 ) ) then begin
				AddRPGMenuItem( RPM , GearName( Part ) , N );
			end;
			Part := Part^.Next;
			Inc( N );
		end;
		RPMSortAlpha( RPM );
		AlphaKeyMenu( RPM );
		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @RobotPartRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			Part := RetrieveGearSib( PC^.InvCom , N );
			DelinkGear( PC^.InvCom , Part );
			while Part^.InvCom <> Nil do begin
				P2 := Part^.InvCom;
				DelinkGear( Part^.InvCom , P2 );
				InsertInvCom( PC , P2 );
			end;
			AppendGear( Ingredients , Part );
		end;

	until ( NumSiblingGears( Ingredients ) > 9 ) or ( N = -1 );

	SelectRobotParts := Ingredients;
end;


Procedure AddRepairOptions( RPM: RPGMenuPtr; PC,Item: GearPtr );
	{ Check the object in question, then add options to the }
	{ provided menu if the item is in need of repairs which the }
	{ PC can provide. Repair items will be numbered 100 + RSN }
var
	N: Integer;
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		for N := 1 to NumRepairSkills do begin
			{ The repair option will only be added to the menu if: }
			{ - The PC has the required skill. }
			{ - The item is in need of repair (using this skill). }
			if ( NAttValue( PC^.NA , NAG_Skill , RepairSkillIndex[N] ) > 0 ) and ( TotalRepairableDamage( Item , RepairSkillIndex[N] ) > 0 ) then begin
				AddRPGMenuItem( RPM , MsgString( 'BACKPACK_Repair' ) + SkillMan[ RepairSkillIndex[N] ].Name , 100 + N );
			end;
		end;
	end;
end;

Procedure DoFieldRepair( GB: GameBoardPtr; PC , Item: GearPtr; Skill: Integer );
	{ The PC is going to use one of the repair skills. Call the }
	{ standard procedure, then print output. }
var
	msg: String;
	N: LongInt;
	RepairFuel,RMaster: GearPtr;
begin
	{ Error check - if no repair is needed, display an appropraite }
	{ response. }
	if TotalRepairableDamage( Item , Skill ) < 1 then begin
		DialogMsg( MsgString( 'PCREPAIR_NoDamageDone' ) );
		Exit;
	end;

	{ Locate the "repair fuel". }
	RepairFuel := SeekGear( PC , GG_RepairFuel , Skill );
	if RepairFuel = Nil then begin
		DialogMsg( MsgString( 'PCREPAIR_NoRepairFuel' ) );
		Exit;
	end;

	{ Locate the root item. If this is a character, and the repair attempt }
	{ fails, and the master is destroyed, that's a bad thing. }
	RMaster := FindRoot( Item );

	N := UseRepairSkill( GB , PC , Item , Skill );
	msg := ReplaceHash( MsgString( 'PCREPAIR_UseSkill' + BStr( Skill ) ) , GearName( Item ) );

	{ Inform the user of the success. }
	if ( RMaster^.G = GG_Character ) and Destroyed( RMaster ) then begin
		AddNAtt( RMaster^.NA , NAG_Damage , NAS_StrucDamage , 30 );
		msg := msg + ReplaceHash( MsgString( 'PCREPAIR_DEAD' ) , GearName( RMaster ) );
	end else if N > 0 then begin
		msg := msg + BStr( N ) + MsgString( 'PCREPAIR_Success' + BStr( Skill ) );
	end else begin
		msg := msg + MsgString( 'PCREPAIR_Failure' + BStr( Skill ) );
	end;

	DialogMsg( msg );

	{ Deplete the fuel. }
	RepairFuel^.V := RepairFuel^.V - N;
	if RepairFuel^.V < 1 then begin
		DialogMsg( ReplaceHash( MsgString( 'PCREPAIR_FuelUsedUp' ) , GearName( RepairFuel ) ) );
		if IsSubCom( RepairFuel ) then begin
			RemoveGear( RepairFuel^.Parent^.SubCom , RepairFuel );
		end else if IsInvCom( RepairFuel ) then begin
			RemoveGear( RepairFuel^.Parent^.InvCom , RepairFuel );
		end;
	end;
end;

Function ShakeDown( GB: GameBoardPtr; Part: GearPtr; X,Y: Integer ): LongInt;
	{ This is the workhorse for this function. It does the }
	{ dirty work of separating inventory from (former) owner. }
var
	cash: LongInt;
	SPart: GearPtr;		{ Sub-Part }
begin
	{ Start by removing the cash from this part. }
	cash := NAttValue( Part^.NA , NAG_Experience , NAS_Credits );
	SetNAtt( Part^.NA , NAG_Experience , NAS_Credits , 0 );
	SetNAtt( Part^.NA , NAG_EpisodeData , NAS_Ransacked , 1 );

	{ Remove all InvComs, and place them on the map. }
	While Part^.InvCom <> Nil do begin
		SPart := Part^.InvCom;
		DelinkGear( Part^.InvCom , SPart );
		{ If this invcom isn't destroyed, put it on the }
		{ ground for the PC to pick up. Otherwise delete it. }
		if NotDestroyed( SPart ) then begin
			SetNAtt( SPart^.NA , NAG_Location , NAS_X , X );
			SetNAtt( SPart^.NA , NAG_Location , NAS_Y , Y );
			SPart^.Next := GB^.Meks;
			GB^.Meks := SPart;
		end else begin
			DisposeGear( SPart );
		end;
	end;

	{ Shake down this gear's subcoms. }
	SPart := Part^.SubCOm;
	while SPart <> Nil do begin
		if SPart^.G <> GG_Cockpit then cash := cash + ShakeDown( GB , SPart , X , Y );
		SPart := SPart^.Next;
	end;

	ShakeDown := Cash;
end;


Function Ransack( GB: GameBoardPtr; X,Y: Integer ): LongInt;
	{ Yay! Loot and pillage! This function has two purposes: }
	{ first, it separates all Inventory gears from any non-operational }
	{ masters standing in this tile. Secondly, it collects the }
	{ money from all those non-operational masters and returns the }
	{ total amount as the function result. }
var
	it: LongInt;
	Mek: GearPtr;
begin
	it := 0;

	Mek := GB^.Meks;

	while Mek <> Nil do begin
		{ If this is a broken-down master, check to see if it's }
		{ one we want to pillage. }
		if IsMasterGear( Mek ) and not GearOperational( Mek ) then begin
			{ We will ransack this gear if it's in the correct location. }
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Y ) = Y ) then begin
				it := it + ShakeDown( GB , Mek , X , Y );
			end;
		end else if ( Mek^.G = GG_MetaTerrain ) and ( ( Mek^.Stat[ STAT_Lock ] = 0 ) or Destroyed( Mek ) ) then begin
			{ Metaterrain gets ransacked if it's unlocked, }
			{ or wrecked. }
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Y ) = Y ) then begin
				it := it + ShakeDown( GB , Mek , X , Y );
			end;
		end;
		Mek := Mek^.Next;
	end;

	Ransack := it;
end;

Function Handless( Mek: GearPtr ): Boolean;
	{ Return TRUE if Mek either has no hands or can't use its hands }
	{ at the moment (say, because it's transformed into tank mode). }
	{ Return TRUE if Mek has hands and they are in perfect working order. }
var
	Hand: GearPtr;
begin
	Hand := SeekActiveIntrinsic( Mek , GG_Holder , GS_Hand );
	if Hand = Nil then Handless := True
	else Handless := not InGoodModule( Hand );
end;

{$IFDEF SDLMODE}
	Procedure GetItemRedraw;
	begin
		SDLCombatDisplay( InfoGB );
		{DisplayGearInfo( InfoGear , InfoGB );}
	end;
{$ENDIF}

Function SelectVisibleItem( GB: GameBoardPtr; PC: GearPtr; X,Y: Integer ): GearPtr;
	{ Attempt to select a visible item from gameboard tile X,Y. }
	{ If more than one item is present, prompt the user for which one }
	{ to pick up. }
var
	N,T: Integer;
	RPM: RPGMenuPtr;
begin
	{ First count the number of items in this spot. }
	N := NumVisibleItemsAtSpot( GB , X , Y );

	{ If it's just 0 or 1, then our job is simple... }
	if N = 0 then begin
		SelectVisibleItem := Nil;
	end else if N = 1 then begin
		SelectVisibleItem := FindVisibleItemAtSpot( GB , X , Y );

	{ If it's more than one, better create a menu and let the user }
	{ pick one. }
	end else if N > 1 then begin
		DialogMsg( MsgString( 'GET_WHICH_ITEM?' ) );
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
		for t := 1 to N do begin
			AddRPGMenuItem( RPM , GearName( GetVisibleItemAtSpot( GB , X , Y , T ) ) , T );
		end;
{$IFDEF SDLMODE}
		InfoGear := PC;
		InfoGB := GB;
		N := SelectMenu( RPM , @GetItemRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );
		if N > -1 then begin
			SelectVisibleItem := GetVisibleItemAtSpot( GB , X , Y , N );
		end else begin
			SelectVisibleItem := Nil;
		end;
	end;
end;

Procedure PCGetItem( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will attempt to pick up something lying on the ground. }
var
	Cash,NID: LongInt;
	P: Point;
	item: GearPtr;
begin
	if Handless( PC ) then begin
		{ Start by checking something that other RPGs would }
		{ just assume- does the PC have any hands? }
		DialogMsg( 'You need hands in order to use this command.' );

	end else begin
		P := GearCurrentLocation( PC );

		{ Before attempting to get an item, ransack whatever }
		{ fallen enemies lie in this spot. }
		Cash := Ransack( GB , P.X , P.Y );

		{ Perform an immediate vision check- without it, items }
		{ freed by the Ransack procedure above will remain unseen. }
		VisionCheck( GB , PC );

		Item := SelectVisibleItem( GB , PC , P.X , P.Y );

		if Item <> Nil then begin
			if IsLegalSlot( PC , Item ) then begin
				DelinkGear( GB^.Meks , Item );

				{ Clear the item's location values. }
				StripNAtt( Item , NAG_Location );

				InsertInvCom( PC , Item );
				{ Clear the home, to prevent wandering items. }
				SetSAtt( Item^.SA , 'HOME <>' );
				DialogMsg( ReplaceHash( MsgString( 'YOU_GET_?' ) , GearName( Item ) ) );

				NID := NAttValue( Item^.NA , NAG_Narrative , NAS_NID );
				if NID <> 0 then SetTrigger( GB , TRIGGER_GetItem + BStr( NID ) );
			end else if Cash = 0 then begin
				DialogMsg( ReplaceHash( MsgString( 'CANT_GET_?' ) , GearName( Item ) ) );
			end;
		end else if Cash = 0 then begin
			DialogMSG( 'No item found.' );
		end;

		if Cash > 0 then begin
			DialogMsg( ReplaceHash( MsgString( 'YouFind$' ) , BStr( Cash ) ) );
			AddNAtt( LocatePilot( PC )^.NA , NAG_Experience , NAS_Credits , Cash );
		end;

		{ Picking up an item takes time. }
		WaitAMinute( GB , PC , ReactionTime( PC ) );
	end;
end;

Procedure CreateInvMenu( PC: GearPtr );
	{ Allocate the Inventory menu and fill it up with the PC's inventory. }
begin
	if InvRPM <> Nil then DisposeRPGMenu( InvRPM );
	InvRPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	InvRPM^.Mode := RPMNoCleanup;
	BuildInventoryMenu( InvRPM , PC );
    {$IFNDEF SDLMODE}
	AttachMenuDesc( InvRPM , ZONE_Menu2 );
    {$ENDIF}
	RPMSortAlpha( InvRPM );

	{ If the menu is empty, add a message saying so. }
	If InvRPM^.NumItem < 1 then AddRPGMenuItem( InvRPM , '[no inventory items]' , -1 )
	else AlphaKeyMenu( InvRPM );

	{ Add the menu keys. }
	AddRPGMenuKey(InvRPM,'/',-2);
{$IFDEF SDLMODE}
	AddRPGMenuKey( InvRPM , RPK_Right ,  -3 );
	AddRPGMenuKey( InvRPM , RPK_Left , -4 );
{$ELSE}
	AddRPGMenuKey( InvRPM , KeyMap[ KMC_East ].KCode , -3 );
	AddRPGMenuKey( InvRPM , KeyMap[ KMC_West ].KCode , -4 );
{$ENDIF}
end;

Procedure CreateEqpMenu( PC: GearPtr );
	{ Allocate the equipment menu and fill it up with the PC's gear. }
begin
	if EqpRPM <> Nil then DisposeRPGMenu( EqpRPM );
	EqpRPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_EqpMenu );
	EqpRPM^.Mode := RPMNoCleanup;
    {$IFNDEF SDLMODE}
	AttachMenuDesc( EqpRPM , ZONE_Menu2 );
    {$ENDIF}
	BuildEquipmentMenu( EqpRPM , PC );

	{ If the menu is empty, add a message saying so. }
	If EqpRPM^.NumItem < 1 then AddRPGMenuItem( EqpRPM , '[no equipped items]' , -1 );

	{ Add the menu keys. }
	AddRPGMenuKey(EqpRPM,'/',-2);
{$IFDEF SDLMODE}
	AddRPGMenuKey( EqpRPM , RPK_Right ,  -3 );
	AddRPGMenuKey( EqpRPM , RPK_Left , -4 );
{$ELSE}
	AddRPGMenuKey( EqpRPM , KeyMap[ KMC_East ].KCode , -3 );
	AddRPGMenuKey( EqpRPM , KeyMap[ KMC_West ].KCode , -4 );
{$ENDIF}
end;

Procedure UpdateBackpack( PC: GearPtr );
	{ Redo all the menus, and display them on the screen. }
begin
	CreateInvMenu( PC );
	CreateEqpMenu( PC );
{$IFNDEF SDLMODE}
	DisplayMenu( InvRPM );
	DisplayMenu( EqpRPM );
{$ENDIF}
end;

Procedure GivePartToPC( GB: GameBoardPtr; Part, PC: GearPtr );
	{ Give the specified part to the PC. If the part cannot be }
	{ held by the PC, store it so that it can be recovered using }
	{ the FieldHQ Wargear Explorer. }
var
	team: Integer;
begin
	if ( PC <> Nil ) and IsLegalSlot( PC , Part ) then begin
		InsertInvCom( PC , Part );
	end else begin
		{ If the PC can't carry this equipment, }
		{ stick it off the map. }
		team := NattValue( PC^.NA , NAG_Location , NAS_Team );
		if team = NAV_LancemateTeam then team := NAV_DefPlayerTeam;
		SetNAtt( Part^.NA , NAG_Location , NAS_Team , team );
		DeployMek( GB , Part , False );
	end;
end;

Procedure UnequipItem( GB: GameBoardPtr; PC , Item: GearPtr );
	{ Delink ITEM from its parent, and stick it in the general inventory... }
	{ If possible. Otherwise drop it. }
begin
	{ First, delink Item from its parent. }
	DelinkGear( Item^.Parent^.InvCom , Item );
	{ HOW'D YA LIKE THEM CARROT DOTS, EH!?!? }

	{ Next, link ITEM into the general inventory. }
	GivePartToPC( GB , Item , PC );

	{ Unequipping takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure UnequipFrontend( GB: GameBoardPtr; PC , Item: GearPtr );
	{ Simply unequip the provided item. }
	{ PRECOND: PC and ITEM had better be correct, dagnabbit... }
begin
	DialogMsg( 'You unequip ' + GearName( Item ) + '.' );
	UnequipItem( GB , PC , Item );
end;


Function CanBeExtracted( Item: GearPtr ): Boolean;
	{ Return TRUE if the listed part can be extracted from a mecha, }
	{ or FALSE if it cannot normally be extracted. }
begin
	if ( Item^.G = GG_Support ) or ( Item^.G = GG_Cockpit ) or IsMasterGear( Item ) or ( Item^.Parent = Nil ) or ( Item^.Parent^.Scale = 0 ) or ( Item^.G = GG_Modifier ) then begin
		CanBeExtracted := False;
	end else if ( Item^.G = GG_Module ) and ( Item^.S = GS_Body ) then begin
		CanBeExtracted := False;
	end else begin
		CanBeExtracted := True;
	end;
end;

Function ExtractItem( GB: GameBoardPtr; TruePC , PC: GearPtr; var Item: GearPtr ): Boolean;
	{ Delink ITEM from its parent, and stick it in the general inventory. }
	{ Note that pulling a gear out of its mecha may well wreck it }
	{ beyond any repair! Therefore, after this call, ITEM might no }
	{ longer exist... i.e. it may equal NIL. }
var
	it: Boolean;
	SkTarget,SkRoll,WreckTarget: Integer;
begin
	{ First, calculate the skill target. }
	SkTarget := 2 + ComponentComplexity( Item );
	if Item^.G = GG_Module then begin
		WreckTarget := SkTarget + 8 - Item^.V;
	end else if Item^.Scale < Item^.Parent^.Scale then begin
		WreckTarget := SkTarget + 5;
	end else begin
		WreckTarget := SkTarget + 10 - UnscaledMaxDamage( Item );
	end;
	if WreckTarget < SkTarget then WreckTarget := SkTarget + 1;

	SkRoll := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , 31 ) );

	DoleSkillExperience( TruePC , 31 , 1 );
	AddMentalDown( TruePC , 1 );
	WaitAMinute( GB , TruePC , ReactionTime( TruePC ) * 5 );

	if SkRoll > WreckTarget then begin
		{ First, delink Item from its parent. }
		DelinkGear( Item^.Parent^.SubCom , Item );

		{ Stick the part in the general inventory, if legal. }
		GivePartToPC( GB , Item , PC );

		DoleSkillExperience( TruePC , 31 , 2 );
		DoleExperience( TruePC , 1 );
		it := True;

	end else if SkRoll > SkTarget then begin
		RemoveGear( Item^.Parent^.SubCom , Item );
		Item := Nil;
		it := True;

	end else begin
		it := False;
	end;

	ExtractItem := it;
end;

Procedure ExtractFrontend( GB: GameBoardPtr; TruePC , PC , Item: GearPtr );
	{ Simply remove the provided item. }
	{ PRECOND: PC and ITEM had better be correct, dagnabbit... }
var
	name: String;
begin
	name := GearName( Item );
	if GearActive( PC ) then begin
		DialogMsg( MsgString( 'EXTRACT_NOTACTIVE' ) );
	end else if ExtractItem( GB , TruePC , PC , Item ) then begin
		if Item = Nil then begin
			DialogMsg( ReplaceHash( MsgString( 'EXTRACT_WRECK' ) , name ) );
		end else begin
			DialogMsg( ReplaceHash( MsgString( 'EXTRACT_OK' ) , name ) );
		end;
	end else begin
		DialogMsg( ReplaceHash( MsgString( 'EXTRACT_FAIL' ) , name ) );
	end;
end;


Procedure EquipItem( GB: GameBoardPtr; PC , Slot , Item: GearPtr );
	{ This is the real equipping procedure. Stuff ITEM into SLOT. }
	{ As noted in TheRules.txt, any nonmaster gear can only have one }
	{ item of any particular "G" type equipped at a time. So, if }
	{ SLOT already has equipment of type ITEM^.G, unequip that and }
	{ stuff it into PC's general inventory. }
var
	I2,I3: GearPtr;
begin
	{ First, check for already equipped items. }
	I2 := Slot^.InvCom;
	while I2 <> Nil do begin
		I3 := I2^.Next;		{ This next step might delink I2, so... }
		if I2^.G = Item^.G then begin
			UnequipItem( GB , PC , I2 );
		end;
		I2 := I3;
	end;

	{ Next, delink Item from PC. }
	DelinkGear( PC^.InvCom , Item );

	{ Next, link ITEM into SLOT. }
	InsertInvCom( Slot , Item );

	{ Equipping an item takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure EquipItemFrontend( GB: GameBoardPtr; PC , Item: GearPtr );
	{ Assign ITEM to a legal equipment slot. Move it from the }
	{ general inventory into its new home. }
var
	EI_Menu: RPGMenuPtr;
	N: Integer;
begin
	{ Build the slot selection menu. }
	EI_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	BuildSlotMenu( EI_Menu , PC , Item );
	if EI_Menu^.NumItem < 1 then AddRPGMenuItem( EI_Menu , '[cannot equip ' + GearName( Item ) + ']' , -1 );

	{ Select a slot for the item to go into. }
{$IFDEF SDLMODE}
    BP_Source := PC;
    BP_Focus := Item;
	N := SelectMenu( EI_Menu , @FocusOnOneItemRedraw);
{$ELSE}
	N := SelectMenu( EI_Menu );
{$ENDIF}
	DisposeRPGMenu( EI_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		DialogMsg( 'You equip ' + GearName( Item ) + '.' );
		EquipItem( GB , PC , LocateGearByNumber( PC , N ) , Item );
	end;
end;

Function InstallItem( GB: GameBoardPtr; TruePC , Slot: GearPtr; var Item: GearPtr ): Boolean;
	{ Attempt the skill rolls needed to install ITEM into the }
	{ requested slot. }
var
	SlotCom,ItemCom,UsedCom: Integer;
	SkTarget,WreckTarget,SkRoll: Integer;
begin
	{ Error Check - no circular references! }
	if ( FindGearIndex( Item , Slot ) <> -1 ) then Exit( False );

	{ Also, can't engineer things when you're exhausted. }
	if CurrentMental( TruePC ) < 1 then Exit( False );

	{ Can't install into a personal-scale slot. }
	if Slot^.Scale = 0 then Exit( False );

	SlotCom := ComponentComplexity( Slot );
	ItemCom := ComponentComplexity( Item );
	UsedCom := SubComComplexity( Slot );

	case Item^.G of
		GG_Weapon,GG_MoveSys: SkTarget := 10;
		GG_Module: SkTarget := 15;
		GG_Sensor: SkTarget := 30;
		GG_Modifier: SkTarget := 25;
	else SkTarget := 20;
	end;
	if Item^.Scale < Slot^.Scale then SkTarget := SkTarget div 2;

	{ The WreckTarget is the target number that must be beat }
	{ in order to avoid accidentally destroying the part... }
	if ( Item^.G = GG_Module ) then begin
		WreckTarget := 8 - Item^.V;
	end else if ( UnscaledMaxDamage( Item ) < 1 ) or ( Item^.Scale < Slot^.Scale ) then begin
		WreckTarget := 7;
	end else begin
		WreckTarget := 10 - UnscaledMaxDamage( Item );
	end;
	if WreckTarget < 3 then WreckTarget := 3;

	{ If the SLOT is going to be overstuffed, better raise the }
	{ number of successes and the target number drastically. }
	if ( ( ItemCom + UsedCom ) > SlotCom ) and ( Not IsMasterGear( Slot ) ) then begin
		SkTarget := SkTarget + ItemCom + UsedCom - SlotCom + 5;
	end;

	WaitAMinute( GB , TruePC , ReactionTime( TruePC ) * 5 );

	SkRoll := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , 31 ) );
	if SkRoll > SkTarget then begin
		{ Install the item. }
		DoleSkillExperience( TruePC , 31 , 5 );
		DoleExperience( TruePC , 10 );
		DelinkGear( Item^.Parent^.InvCom , Item );
		InsertSubCom( Slot , Item );
	end else if SkRoll < WreckTarget then begin
		RemoveGear( Item^.Parent^.InvCom , Item );
		Item := Nil;
	end;

	AddMentalDown( TruePC , 1 );
	DoleSkillExperience( TruePC , 31 , 1 );

	InstallItem := SkRoll > SkTarget;
end;

Procedure InstallFrontend( GB: GameBoardPtr; TruePC , PC , Item: GearPtr );
	{ Assign ITEM to a legal equipment slot. Move it from the }
	{ general inventory into its new home. }
var
	EI_Menu: RPGMenuPtr;
	N: Integer;
	name: String;
begin
	{ Error check- can't install into an active master. }
	if GearActive( PC ) then begin
		DialogMsg( MsgString( 'INSTALL_NOTACTIVE' ) );
		Exit;
	end;

	{ Build the slot selection menu. }
	EI_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	BuildSubMenu( EI_Menu , PC , Item , True );
	if EI_Menu^.NumItem < 1 then AddRPGMenuItem( EI_Menu , '[cannot install ' + GearName( Item ) + ']' , -1 );

	{ Select a slot for the item to go into. }
	DialogMsg( GearName( Item ) + ' cmx:' + BStr( ComponentComplexity( Item ) ) + '. ' + MsgSTring( 'BACKPACK_InstallInfo' ) );
{$IFDEF SDLMODE}
    BP_Source := PC;
    BP_Focus := Item;
	N := SelectMenu( EI_Menu , @FocusOnOneItemRedraw);
{$ELSE}
	N := SelectMenu( EI_Menu );
{$ENDIF}
	DisposeRPGMenu( EI_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		{ Store the name here, since the item might get destroyed }
		{ during the installation process. }
		name := GearName( Item );
		if InstallItem( GB , TruePC , LocateGearByNumber( PC , N ) , Item ) then begin
			DialogMsg( ReplaceHash( MsgString( 'INSTALL_OK' ) , name ) );
		end else begin
			if Item = Nil then begin
				DialogMsg( ReplaceHash( MsgString( 'INSTALL_WRECK' ) , name ) );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'INSTALL_FAIL' ) , name ) );
			end;
		end;
	end;
end;

Procedure InstallAmmo( GB: GameBoardPtr; PC , Gun , Ammo: GearPtr );
	{ Place the ammunition gear into the gun. }
var
	A,A2: GearPtr;
begin
	{ To start with, unload any ammo currently in the gun. }
	A := Gun^.SubCom;
	while A <> Nil do begin
		A2 := A^.Next;

		if A^.G = GG_Ammo then begin
			DelinkGear( Gun^.SubCom , A );
			InsertInvCom( PC , A );
		end;

		A := A2;
	end;

	{ Delink the magazine from wherever it currently resides. }
	if IsInvCom( Ammo ) then begin
		DelinkGear( Ammo^.Parent^.InvCom , Ammo );
	end else if IsSubCom( Ammo ) then begin
		DelinkGear( Ammo^.Parent^.SubCom , Ammo );
	end;

	{ Stick the new magazine into the gun. }
	InsertSubCom( Gun , Ammo );

	{ Loading a gun takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure InstallAmmoFrontend( GB: GameBoardPtr; PC , Item: GearPtr );
	{ Assign ITEM to a legal projectile weapon. Move it from the }
	{ general inventory into its new home. }
var
	IA_Menu: RPGMenuPtr;
	Gun: GearPtr;
	N: Integer;
begin
	{ Build the slot selection menu. }
	IA_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	BuildSubMenu( IA_Menu , PC , Item , False );
	if IA_Menu^.NumItem < 1 then AddRPGMenuItem( IA_Menu , '[no weapon for ' + GearName( Item ) + ']' , -1 );

	{ Select a slot for the item to go into. }
{$IFDEF SDLMODE}
    BP_Source := PC;
    BP_Focus := Item;
	N := SelectMenu( IA_Menu , @FocusOnOneItemRedraw);
{$ELSE}
	N := SelectMenu( IA_Menu );
{$ENDIF}
	DisposeRPGMenu( IA_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		Gun := LocateGearByNumber( PC , N );
		DialogMsg( 'You load ' + GearName( Item ) + ' into ' + GearName( Gun ) + '.' );
		InstallAmmo( GB , PC , Gun , Item );
	end;
end;


Procedure DropFrontEnd( PC , Item: GearPtr );
	{ How to drop an item: Make sure PC is a root-level gear. }
	{ Delink ITEM from its current location. }
	{ Copy PC's location variables to ITEM. }
	{ Install ITEM as the next sibling of PC. }
begin
	{ Make sure PC is at root level... }
	PC := FindRoot( PC );

	{ Delink ITEM from its parent... }
	DelinkGear( Item^.Parent^.InvCom , Item );

	{ Copy the location variables to ITEM... }
	SetNAtt( Item^.NA , NAG_Location , NAS_X , NAttValue( PC^.NA , NAG_Location , NAS_X ) );
	SetNAtt( Item^.NA , NAG_Location , NAS_Y , NAttValue( PC^.NA , NAG_Location , NAS_Y ) );
	if not OnTheMap( PC ) then SetNAtt( Item^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );

	{ Install ITEM as PC's sibling... }
	Item^.Next := PC^.Next;
	PC^.Next := Item;

	{ Do display stuff. }
	DialogMsg( 'You drop ' + GearName( Item ) + '.' );
end;

Procedure TradeFrontend( GB: GameBoardPtr; PC , Item, LList: GearPtr );
	{ Assign ITEM to a different master. Move it from the }
	{ general inventory of PC into its new home. }
const
    Unsafe_Transfer_Range = 10;
var
	TI_Menu: RPGMenuPtr;
	M: GearPtr;
	Team,N: Integer;
	X,Y: Integer;

	Function Transferable_To ( Dest: GearPtr ) : Boolean;
	var
		DTeam, DX, DY : Integer;
	begin
		If Dest = PC then Exit(False);

		{ Team check.  This could probably be simplified --
		  How could the source Master's team be other than
		  DefPlayer or Lancemate anyway? }
  		DTeam := NAttValue( Dest^.NA , NAG_Location , NAS_Team );
		if DTeam = NAV_LancemateTeam then DTeam := NAV_DefPlayerTeam;
		if DTeam <> Team then Exit(False);
		
		if X = 0 then Exit(True); {safe area case}

		{we're now in the unsafe area case, check for adjacency}
		DX := NAttValue( Dest^.NA, NAG_Location, NAS_X);
		DY := NAttValue( Dest^.NA, NAG_Location, NAS_Y);
		if not OnTheMap(DX,DY) then Exit(False); {cannot transfer to offmap stuff}

		Transferable_To := ( Range(X,Y,DX,DY) <= Unsafe_Transfer_Range );
	end;
begin
	if IsSafeArea( GB ) then begin
		X := 0;
		Y := 0;
	end else begin
		DialogMsg( MsgString( 'TRANSFER_UNSAFE' ) );
		X := NAttValue(PC^.NA, NAG_Location, NAS_X);
		Y := NAttValue(PC^.NA, NAG_Location, NAS_Y);
	end;

	{ Build the slot selection menu. }
	TI_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	N := 1;
	M := LList;
	Team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
	if Team = NAV_LancemateTeam then Team := NAV_DefPlayerTeam;

	{ This menu should contain all the masters from LList which }
	{ belong to Team 1. }
	while M <> Nil do begin
		if IsMasterGear( M ) and Transferable_To(M) then
			AddRPGMenuItem( TI_Menu , GearName( M ) , N );
		M := M^.Next;
		Inc( N );
	end;
	AlphaKeyMenu( TI_Menu );

	if TI_Menu^.NumItem < 1 then AddRPGMenuItem( TI_Menu , '[cannot trade ' + GearName( Item ) + ']' , -1 );

	{ Select a slot for the item to go into. }
{$IFDEF SDLMODE}
	N := SelectMenu( TI_Menu , @TradeItemRedraw);
{$ELSE}
	N := SelectMenu( TI_Menu );
{$ENDIF}
	DisposeRPGMenu( TI_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		M := RetrieveGearSib( LList , N );
		if IsLegalSlot( M , Item ) then begin
			DelinkGear( Item^.Parent^.InvCom , Item );
			InsertInvCom( M , Item );
			DialogMsg( MsgString( 'BACKPACK_ItemTraded' ) );
		end else begin
			DialogMsg( MsgString( 'BACKPACK_NotTraded' ) );
		end;
	end;
end;

Procedure FHQ_AssociatePilotMek( PC , M , LList: GearPtr );
	{ Associate the mecha with the pilot. }
begin
	AssociatePilotMek( LList , PC , M );
	DialogMsg( ReplaceHash( MsgString( 'FHQ_AssociatePM' ) , GearName( PC ) ) );
end;

Procedure FHQ_SelectPilotForMecha( GB: GameBoardPtr; Mek: GearPtr );
	{ Select a pilot for the mecha in question. }
	{ Pilots must be characters- they must either belong to the default }
	{ player team or, if they're lancemates, they must have a CID. }
	{ This is to prevent the PC from dominating some sewer rats and }
	{ training them to be pilots. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	M: GearPtr;
begin
	{ Create the menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	M := GB^.Meks;
	N := 1;
	while M <> Nil do begin
		if M^.G = GG_Character then begin
			if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) <> 0 ) then begin
				AddRPGMenuItem( RPM , GearName( M ) , N );
			end else if NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				AddRPGMenuItem( RPM , GearName( M ) , N );
			end;
		end;
		M := M^.Next;
		Inc( N );
	end;
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MSgString( 'EXIT' ) , -1 );

	{ Get a selection from the menu. }
{$IFDEF SDLMODE}
	n := SelectMenu( RPM , @PlainRedraw );
{$ELSE}
	n := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );

	if N > 0 then begin
		M := RetrieveGearSib( GB^.Meks , N );
		FHQ_AssociatePilotMek( M , Mek , GB^.Meks );
	end;
end;

Procedure FHQ_SelectMechaForPilot( GB: GameBoardPtr; NPC: GearPtr );
	{ Select a pilot for the mecha in question. }
	{ Pilots must be characters- they must either belong to the default }
	{ player team or, if they're lancemates, they must have a CID. }
	{ This is to prevent the PC from dominating some sewer rats and }
	{ training them to be pilots. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	M: GearPtr;
begin
{$IFDEF SDLMODE}
	INFOGear := NPC;
	INFOGB := GB;
{$ENDIF}

	{ Error check- only characters can pilot mecha! Pets can't. }
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) then begin
		DialogMsg( ReplaceHash( MsgString( 'FHQ_SMFP_NoPets' ) , GearName( NPC ) ) );
		Exit;
	end;

	{ Create the menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	M := GB^.Meks;
	N := 1;
	while M <> Nil do begin
		if ( M^.G = GG_Mecha ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then begin
			AddRPGMenuItem( RPM , GearName( M ) , N );
		end;
		M := M^.Next;
		Inc( N );
	end;
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MSgString( 'EXIT' ) , -1 );

	{ Get a selection from the menu. }
{$IFDEF SDLMODE}
	n := SelectMenu( RPM , @PlainRedraw );
{$ELSE}
	n := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );

	if N > 0 then begin
		M := RetrieveGearSib( GB^.Meks , N );
		FHQ_AssociatePilotMek( NPC , M , GB^.Meks );
	end;
end;

Procedure StartContinuousUseItem( GB: GameBoardPtr; TruePC , Item: GearPtr );
	{ The PC wants to use this item. Give it a try. }
var
	N: Integer;
begin
	{ Find the item's index number. If the item cannot be found }
	{ on the TRUEPC, then this item cannot be used. }
	N := FindGearIndex( TruePC , Item );
	if N > 0 then begin
		WaitAMinute( GB , TruePC , 1 );
		SetNAtt( TruePC^.NA , NAG_Location , NAS_SmartAction , NAV_UseItem );
		SetNAtt( TruePC^.NA , NAG_Location , NAS_SmartWeapon , N );
		SetNAtt( TruePC^.NA , NAG_Location , NAS_SmartCount , 3 );

		{ When an item is used in this way, exit the menu. }
		ForceQuit := True;
	end else begin
		DialogMsg( MsgString( 'BACKPACK_CantUse' ) );
	end;
end;

Procedure UseScriptItem( GB: GameBoardPtr; TruePC, Item: GearPtr; T: String );
	{ This item has a script effect. Exit the backpack and use it. }
begin
	if SAttValue( Item^.SA , T ) <> '' then begin
		{ Announce the intention. }
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_Script_' + T ) , GearName( Item ) ) );

		{ Using items takes time... }
		WaitAMinute( GB , TruePC , ReactionTime( TruePC ) );

		{ ...and also exits the backpack. }
		ForceQuit := True;
        {$IFNDEF SDLMODE}
		GFCombatDisplay( GB );
        {$ENDIF}

		{ Finally, trigger the script. }
		TriggerGearScript( GB , Item , T );
	end else begin
		{ Announce the lack of a valid script. }
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_CannotUseScript' ) , GearName( Item ) ) );
	end;
end;

Procedure UseSkillOnItem( GB: GameBoardPtr; TruePC, Item: GearPtr );
	{ The PC will have the option to use a CLUE-type skill on this }
	{ item, maybe to gain some new information, activate an effect, }
	{ or whatever else. }
var
	SkMenu: RPGMenuPtr;
	T: Integer;
	msg: String;
begin
	SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );

	{ Add the usable skills. }
	for t := 1 to NumSkill do begin
		{ In order to be usable, it must be a CLUE type skill, }
		{ and the PC must have ranks in it. }
		if ( SkillMan[ T ].Usage = USAGE_Clue ) and ( TeamHasSkill( GB , NAV_DefPlayerTeam , T ) or HasTalent( TruePC , NAS_JackOfAll ) ) then begin
			msg := ReplaceHash( MsgString( 'BACKPACK_ClueSkillPrompt' ) , SkillMan[ T ].Name );
			msg := ReplaceHash( msg , GearName( Item ) );
			AddRPGMenuItem( SkMenu , msg , T );
		end;
	end;
	RPMSortAlpha( SkMenu );
	AddRPGMenuItem( SkMenu , MsgSTring( 'BACKPACK_CancelSkillUse' ) , -1 );

{$IFDEF SDLMODE}
	InfoGB := GB;
    BP_Source := TruePC;
    BP_Focus := Item;
	T := SelectMenu( SkMenu , @FocusOnOneItemRedraw);
{$ELSE}
	T := SelectMenu( SkMenu );
{$ENDIF}
	DisposeRPGMenu( SkMenu );

	if T <> -1 then begin
		UseScriptItem( GB , TruePC , Item , 'CLUE' + BStr( T ) );
	end;
end;

Procedure EatItem( GB: GameBoardPtr; TruePC , Item: GearPtr );
	{ The PC wants to eat this item. Give it a try. }
var
	effect: String;
begin
	TruePC := LocatePilot( TruePC );

	if TruePC = Nil then begin
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_CantBeEaten' ) , GearName( Item ) ) );

	end else if ( NAttValue( TruePC^.NA , NAG_Condition , NAS_Hunger ) > ( Item^.V div 2 ) ) or ( Item^.V = 0 ) then begin
		{ Show a message. }
		DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'BACKPACK_YouAreEating' ) , GearName( TruePC ) ) , GearName( Item ) ) );

		{ Eating takes time... }
		WaitAMinute( GB , TruePC , ReactionTime( TruePC ) * GearMass( Item ) + 1 );

		{ ...and also exits the backpack. }
		ForceQuit := True;

		{ Locate the PC's Character record, then adjust hunger values. }
		AddNAtt( TruePC^.NA , NAG_Condition , NAS_Hunger , -Item^.V );
		AddMoraleDmg( TruePC , -( Item^.Stat[ STAT_MoraleBoost ] * FOOD_MORALE_FACTOR ) );

		{ Invoke the item's effect, if any. }
		effect := SAttValue( Item^.SA , 'EFFECT' );
		if effect <> '' then begin
            {$IFNDEF SDLMODE}
			GFCombatDisplay( GB );
            {$ENDIF}
			EffectFrontEnd( GB , TruePC , effect , '' );
		end;

		{ Destroy the item, if appropriate. }
		Dec( Item^.Stat[ STAT_FoodQuantity ] );
		if Item^.Stat[ STAT_FoodQuantity ] < 1 then begin
			if IsInvCom( Item ) then begin
				RemoveGEar( Item^.Parent^.InvCom , Item );
			end else if IsSubCom( Item ) then begin
				RemoveGEar( Item^.Parent^.SubCom , Item );
			end;
		end;
	end else begin
		DialogMsg( MsgString( 'BACKPACK_NotHungry' ) );
	end;
end;


Procedure ThisItemWasSelected( GB: GameBoardPtr; var LList: GearPtr; TruePC , PC , Item: GearPtr );
	{ TruePC is the primary character, who may be doing repairs }
	{  and stuff. }
	{ PC is the current master being examined, which may well be }
	{  a mecha belonging to the TruePC rather than the TruePC itself. }
	{ LList is a list of mecha and other things which may or may not }
	{  belong to the same team as TruePC et al. }
	{ Item is the piece of wargear currently being examined. }
var
	TIWS_Menu: RPGMenuPtr;
	N: Integer;
begin
	TIWS_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );

	if Item^.G = GG_Usable then AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_UseItem' ) , GearName( Item ) ) , -9 );
	if Item^.G = GG_Consumable then AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_EatItem' ) , GearName( Item ) ) , -10 );

	if SATtValue( Item^.SA , 'USE' ) <> '' then AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_UseItemScript' ) , GearName( Item ) ) , -11 );

	if Item^.G = GG_Ammo then AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_LoadAmmo' ) , -5 );
	if IsInvCom( Item ) then begin
		if Item^.Parent = PC then begin
			AddRPGMenuItem( TIWS_Menu , 'Equip ' + GearName( Item ) , -2 );
			if ( FindMaster( Item ) <> Nil ) and ( FindMaster( Item )^.G = GG_Mecha ) then begin
				AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_Install' ) + GearName( Item ) , -8 );
			end;
		end else begin
			AddRPGMenuItem( TIWS_Menu , 'Unequip ' + GearName( Item ) , -3 );
		end;
		if ( LList <> Nil ) and ( GB <> Nil ) then AddRPGMenuItem ( TIWS_Menu , MsgString( 'BACKPACK_TradeItem' ) , -6 );
		AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_DropItem' ) , -4 );
	end else if ( FindMaster( Item ) <> Nil ) and ( FindMaster( Item )^.G = GG_Mecha ) and CanBeExtracted( Item ) then begin
		AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_Remove' ) + GearName( Item ) , -7 );
	end;
	AddRepairOptions( TIWS_Menu , TruePC , Item );

	if ( Item^.G = GG_Weapon ) or ( ( Item^.G = GG_Ammo ) and ( Item^.S = GS_Grenade ) ) then begin
		if NAttValue( Item^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) = 0 then begin
			AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_EngageSafety' ) , -12 );
		end else begin
			AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_DisengageSafety' ) , -12 );
		end;
	end;

	AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_UseSkillOnItem' ) , 1 );
	AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_ExitTIWS' ) , -1 );

	repeat
{$IFDEF SDLMODE}
		BP_Focus := Item;
        BP_Source := PC;
		InfoGB := GB;
		N := SelectMenu( TIWS_Menu , @FocusOnOneItemRedraw );
{$ELSE}
		DisplayGearInfo( Item );
		N := SelectMenu( TIWS_Menu );
{$ENDIF}
		if N > 100 then begin
			DoFieldRepair( GB , TruePC , Item , RepairSkillIndex[N-100] );
		end else begin
			case N of
				1: UseSkillOnItem( GB , TruePC , Item );
				-2: EquipItemFrontend( GB , PC , Item );
				-3: UnequipFrontEnd( GB , PC , Item );
				-4: DropFrontEnd( PC , Item );
				-5: InstallAmmoFrontEnd( GB , PC , Item );
				-6: TradeFrontEnd( GB , PC, Item , LList );
				-7: ExtractFrontEnd( GB , TruePC , PC , Item );
				-8: InstallFrontEnd( GB , TruePC , PC , Item );
				-9: StartContinuousUseItem( GB , TruePC , Item );
				-10: EatItem( GB , PC , Item );
				-11: UseScriptItem( GB , TruePC , Item , 'USE' );
				-12: SetNAtt( Item^.NA , NAG_WeaponModifier , NAS_SafetySwitch , 1 - NAttValue( Item^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) );
			end;
		end;
	until ( N < 0 ) or ForceQuit;

	DisposeRPGMenu( TIWS_Menu );
end;

Function DoInvMenu( GB: GameBoardPtr; var LList: GearPtr; var PC,M: GearPtr ): Boolean;
	{ Return TRUE if the user selected Quit. }
var
	N: Integer;
begin
	Repeat
{$IFDEF SDLMODE}
		InfoGear := M;
		InfoGB := GB;
        BP_ActiveMenu := InvRPM;
		BP_SeekSibs := False;
        BP_Source := M;
		N := SelectMenu( INVRPM , @InvRedraw);
{$ELSE}
		N := SelectMenu( InvRPM );
{$ENDIF}

		{ If an item was selected, pass it along to the appropriate }
		{ procedure. }
		if N > 0 then begin
			ThisItemWasSelected( GB , LList , PC , M , LocateGearByNumber( M , N ) );
			{ Restore the display. }
			UpdateBackpack( M );
            {$IFNDEF SDLMODE}
			DisplayGearInfo( M );
            {$ENDIF}
        end else if N = -3 then begin
            M := FindNextPC( GB, M );
            N := 0;
			{ Restore the display. }
			UpdateBackpack( M );
            {$IFNDEF SDLMODE}
			DisplayGearInfo( M );
            {$ENDIF}
        end else if N = -4 then begin
            M := FindPrevPC( GB, M );
            N := 0;
			{ Restore the display. }
			UpdateBackpack( M );
            {$IFNDEF SDLMODE}
			DisplayGearInfo( M );
            {$ENDIF}
		end;
	until ( N < 0 ) or ForceQuit;

{$IFNDEF SDLMODE}
	DisplayMenu( InvRPM );
{$ENDIF}

	DoInvMenu := N=-1;
end;

Function DoEqpMenu( GB: GameBoardPtr; var LList: GearPtr; var PC,M: GearPtr ): Boolean;
	{ Return TRUE if the user selected Quit. }
var
	N: Integer;
begin
	Repeat
{$IFDEF SDLMODE}
		InfoGear := M;
		InfoGB := GB;
        BP_ActiveMenu := EqpRPM;
		BP_SeekSibs := False;
        BP_Source := M;
		N := SelectMenu( EqpRPM , @EqpRedraw);
{$ELSE}
		N := SelectMenu( EqpRPM );
{$ENDIF}

		{ If an item was selected, pass it along to the appropriate }
		{ procedure. }
		if N > 0 then begin
			ThisItemWasSelected( GB , LList , PC , M , LocateGearByNumber( M , N ) );
			{ Restore the display. }
			UpdateBackpack( M );
            {$IFNDEF SDLMODE}
			DisplayGearInfo( M );
            {$ENDIF}
        end else if N = -3 then begin
            M := FindNextPC( GB, M );
            N := 0;
			{ Restore the display. }
			UpdateBackpack( M );
            {$IFNDEF SDLMODE}
			DisplayGearInfo( M );
            {$ENDIF}
        end else if N = -4 then begin
            M := FindPrevPC( GB, M );
            N := 0;
			{ Restore the display. }
			UpdateBackpack( M );
            {$IFNDEF SDLMODE}
			DisplayGearInfo( M );
            {$ENDIF}
		end;
	until ( N < 0 ) or ForceQuit;

{$IFNDEF SDLMODE}
	DisplayMenu( EqpRPM );
{$ENDIF}

	DoEqpMenu := N=-1;
end;


Procedure RealBackpack( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr; StartWithInv: Boolean );
	{ This is the backpack routine which should allow the player to go }
	{ through all the stuff in his/her inventory, equip items, drop them, }
	{ reload weapons, and whatnot. It is based roughly upon the procedures }
	{ from DeadCold. }
var
	QuitBP: Boolean;
begin
	{ Set up the display. }
    {$IFNDEF SDLMODE}
	DrawBPBorder;
    {$ENDIF}
	ForceQuit := False;

	{ Initialize menus to NIL, then create them. }
	InvRPM := Nil;
	EqpRPM := Nil;
	UpdateBackpack( M );

	repeat
{$IFNDEF SDLMODE}
		GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_Menu , MenuItem );
{$ENDIF}
		if StartWithInv then begin
			QuitBP := DoInvMenu( GB , LList , PC , M );
		end else begin
			QuitBP := DoEqpMenu( GB , LList , PC , M );
		end;

		{ If we have not been ordered to exit the loop, we must }
		{ have been ordered to switch menus. }
		StartWithInv := Not StartWithInv;
	until QuitBP or ForceQuit;

	DisposeRPGMenu( InvRPM );
	DisposeRPGMenu( EqpRPM );
end;

Procedure LancemateBackpack( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ This is a header for the REALBACKPACK function. }
begin
	RealBackPack( GB , GB^.Meks , PC , NPC , True );
end;

Procedure BackpackMenu( GB: GameBoardPtr; PC: GearPtr; StartWithInv: Boolean );
	{ This is a header for the REALBACKPACK function. }
begin
	RealBackPack( GB , GB^.Meks , PC , PC , StartWithInv );
end;

{$IFDEF SDLMODE}
	Procedure MPERedraw;
		{ Show Inventory, select Equipment. }
	begin
		SDLCombatDisplay( InfoGB );
		DrawBPBorder;
		GameMsg( FullGearName( INFOGear ) + ' '  + MechaDescription( InfoGear) , ZONE_EqpMenu.GetRect() , InfoGreen );
		{DisplayGearInfo( InfoGear );}
	end;
{$ENDIF}

Procedure MechaPartEditor( GB: GameBoardPtr; var LList: GearPtr; PC,Mek: GearPtr );
	{ This procedure may be used to browse through all the various }
	{ bits of a mecha and examine each one individually. }
var
	RPM: RPGMenuPtr;
	N,I: Integer;
begin
	{ Set up the display. }
	DrawBPBorder;
	I := 0;

	Repeat
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
		BuildGearMenu( RPM , Mek );
		if I > 0 then SetItemByPosition( RPM , I );
		AddRPGMenuItem( RPM , 'Exit Editor' , -1 );

{$IFNDEF SDLMODE}
		GameMsg( FullGearName( Mek ) + ' '  + MechaDescription( Mek ) , ZONE_EqpMenu , InfoGreen );
		DisplayGearInfo( Mek );
{$ENDIF}
{$IFDEF SDLMODE}
		InfoGear := Mek;
		InfoGB := GB;
		N := SelectMenu( RPM , @MPERedraw);
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		I := RPM^.SelectItem;
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			ThisItemWasSelected( GB , LList , PC , Mek , LocateGearByNumber( Mek , N ) );
		end;
	until N = -1;

end;

{$IFDEF SDLMODE}
Procedure PartBrowserRedraw;
	{ Redraw the screen for the part browser. }
begin
	if MPB_Redraw <> Nil then MPB_Redraw;
	{if MPB_Gear <> Nil then DisplayGearInfo( MPB_Gear );}
end;

Procedure MechaPartBrowser( Mek: GearPtr; RDP: RedrawProcedureType );
{$ELSE}
Procedure MechaPartBrowser( Mek: GearPtr );
{$ENDIF}
	{ This procedure may be used to browse through all the various }
	{ bits of a mecha and examine each one individually. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
{$IFDEF SDLMODE}
	MPB_Redraw := RDP;
	MPB_Gear := Mek;
{$ENDIF}

	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildGearMenu( RPM , Mek );
	AddRPGMenuItem( RPM , 'Exit Browser' , -1 );


	Repeat
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @PartBrowserRedraw );
{$ELSE}
		DisplayGearInfo( Mek );
		N := SelectMenu( RPM );
{$ENDIF}

		if N > -1 then begin
{$IFDEF SDLMODE}
			MPB_Gear := LocateGearByNumber( Mek , N );
{$ELSE}
			DisplayGearInfo( LocateGearByNumber( Mek , N ) );
			EndOFGameMoreKey;
{$ENDIF}
		end;
	until N = -1;
	DisposeRPGMenu( RPM );
end;

{$IFDEF SDLMODE}
	Procedure FHQRedraw;
	begin
		if InfoGB <> Nil then SDLCombatDisplay( InfoGB );
		{DisplayGearInfo( InfoGear );}
	end;
{$ENDIF}

Procedure FHQ_Transfer( var LList: GearPtr; PC,Item: GearPtr );
	{ An item has been selected. Allow it to be transferred to }
	{ one of the team's master gears. }
var
	RPM: RPGMenuPtr;
	M: GearPtr;
	N,Team: Integer;
begin
	{ Show the item's stats. }
    {$IFNDEF SDLMODE}
	DisplayGearInfo( Item );
    {$ENDIF}

	{ Create the menu. }
	RPM := CreateRPGMenu( MenuItem, MenuSelect, ZONE_Menu );
	M := LList;
	N := 1;
	Team := NAttValue( PC^.NA , NAG_LOcation , NAS_Team );
	while M <> Nil do begin
		if ( ( NAttValue( M^.NA , NAG_LOcation , NAS_Team ) = Team ) or ( NAttValue( M^.NA , NAG_LOcation , NAS_Team ) = NAV_LancemateTeam ) ) and IsMasterGear( M ) and IsLegalSlot( M , Item ) then begin
			AddRPGMenuItem( RPM , GearName( M ) , N );
		end;

		M := M^.Next;
		Inc( N );
	end;

	{ Sort the menu, then add an exit option. }
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MsgString( 'FHQ_ReturnToMain' ) , -1 );

	{ Get a menu selection, then exit the menu. }
	DialogMSG( MsgString( 'FHQ_SelectDestination' ) );
{$IFDEF SDLMODE}
	InfoGear := Item;
	N := SelectMenu( RPM , @FHQRedraw );
{$ELSE}
	N := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );

	if N > -1 then begin
		M := RetrieveGearSib( LList , N );
		DelinkGear( LList , Item );
		InsertInvCom( M , Item );
		DialogMSG( MsgString( 'FHQ_ItemMoved' ) );
	end else begin
		DialogMSG( MsgString( 'Cancelled' ) );
	end;
end;

Procedure Rename_Mecha( GB: GameBoardPtr; NPC: GearPtr );
	{ Enter a new name for NPC. }
var
	name: String;
begin
{$IFDEF SDLMODE}
	name := GetStringFromUser( ReplaceHash( MsgString( 'FHQ_Rename_Prompt' ) , GearName( NPC ) ) , @FHQRedraw );
{$ELSE}
	name := GetStringFromUser( ReplaceHash( MsgString( 'FHQ_Rename_Prompt' ) , GearName( NPC ) ) );
	GFCombatDisplay( GB );
{$ENDIF}
	if name <> '' then SetSAtt( NPC^.SA , 'name <' + name + '>' );
end;

Procedure FHQ_ThisWargearWasSelected( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr );
	{ A mecha has been selected by the PC from the FHQ main menu. }
	{ Offer up all the different choices of things the PC can }
	{ do with mecha - select pilot, repair, check inventory, etc. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	repeat
		{ Show the mecha's stats. }
        {$IFNDEF SDLMODE}
		DisplayGearInfo( M );
        {$ENDIF}

		{ Create the FHQ menu. }
		RPM := CreateRPGMenu( MenuItem, MenuSelect, ZONE_Menu );
		RPM^.Mode := RPMNoCleanup;

		if IsMasterGear( M ) then begin
			if IsSafeArea( GB ) or OnTheMap( M ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_GoBackpack' ) , 1 );
		end else if IsSafeArea( GB ) then begin
			AddRPGMenuItem( RPM , MsgString( 'FHQ_Transfer' ) , -3 );
		end;

		if IsSafeArea( GB ) then AddRepairOptions( RPM , PC , M );

		if M^.G = GG_Mecha then begin
			AddRPGMenuItem( RPM , MsgString( 'FHQ_SelectMecha' ) , 2 );
			AddRPGMenuItem( RPM , MsgString( 'FHQ_Rename' ) , 6 );
		end;
		if IsSafeArea( GB ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_PartEditor' ) , 4 );

{$IFDEF SDLMODE}
		if M^.G = GG_Mecha then AddRPGMenuItem( RPM , MsgString( 'FHQ_EditColor' ) , 5 );
{$ENDIF}

		AddRPGMenuItem( RPM , MsgString( 'FHQ_ReturnToMain' ) , -1 );

		{ Get a selection from the menu, then dispose of it. }
{$IFDEF SDLMODE}
		InfoGB := GB;
		infoGear := M;
		N := SelectMenu( RPM , @FHQRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N > 100 then begin
			{ A repair option must have been selected. }
			DoFieldRepair( GB , PC , M , RepairSkillIndex[N-100] );

		end else begin
			case N of
				1: RealBackpack( GB , LList , PC , M , False );
				2: FHQ_SelectPilotForMecha( GB , M );
				-3: FHQ_Transfer( LList , PC , M );
				4: MechaPartEditor( GB , LList , PC , M );
{$IFDEF SDLMODE}
				5: SelectColors( M , @FHQRedraw );
{$ENDIF}
				6: Rename_Mecha( GB , M );
			end;

		end;

	until N < 0;
{$IFDEF SDLMODE}
	CleanSpriteList;
{$ELSE}
	GFCombatDisplay( GB );
{$ENDIF}
end;


end.
