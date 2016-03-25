unit services;
	{ This is an offshoot of the ArenaTalk/ArenaScript interaction }
	{ stuff. It's supposed to handle shops & other cash transactions }
	{ for the GearHead RPG engine. }
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
	num_standard_schemes = 5;
	standard_lot_colors: Array [0..num_standard_schemes-1] of string = (
	'152 172 183 199 188 162 200   0 200', 	{ Coral, Gull Grey, Purple }
	' 80  80  85 130 144 114 200 200   0',	{ Dark Grey, Battleship Grey, Yellow }
	' 66 121 179 210 215  80 205  25   0',	{ Default player colors }
	'201 205 229  49  91 161   0 200   0',	{ Aero Blue, Azure, Green }
	'240 240 240 208  34  51  50  50 150'	{ White, Red Goes Fasta, Blue }
	);
Function Random_Mecha_Colors: String;
Procedure PurchaseGear( GB: GameBoardPtr; PC,NPC,Part: GearPtr );
Procedure OpenShop( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
Procedure OpenSchool( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
Procedure ExpressDelivery( GB: GameBoardPtr; PC,NPC: GearPtr );
Procedure ShuttleService( GB: GameBoardPtr; PC,NPC: GearPtr );
Procedure OpenShuttle( GB: GameBoardPtr; PC,NPC: GearPtr );


implementation

{$IFDEF SDLMODE}
uses ability,arenacfe,backpack,damage,gearutil,ghchars,ghmodule,ghparser,
     ghswag,ghweapon,interact,menugear,rpgdice,skilluse,texutil,sdlgfx,
     sdlinfo,sdlmap,sdlmenus,ui4gh,ghprop;
{$ELSE}
uses ability,arenacfe,backpack,damage,gearutil,ghchars,ghmodule,ghparser,
     ghswag,ghweapon,interact,menugear,rpgdice,skilluse,texutil,congfx,
     coninfo,conmap,conmenus,context,ui4gh,ghprop;
{$ENDIF}

Const
	CredsPerDP = 1;		{ Cost to repair 1DP of damage. }
	MaxShopItems = 21;	{ Maximum number of items in a shop. }

{$IFDEF SDLMODE}
var
	SERV_GB: GameBoardPtr;
	SERV_PC,SERV_CUSTOMER,SERV_NPC,SERV_Info: GearPtr;
    SERV_Menu: RPGMenuPtr;
{$ENDIF}

Function ScalePrice( PC,NPC: GearPtr; Price: Int64 ): LongInt;
	{ Modify the price listed based upon the PC's shopping skill. }
var
	ShopRk,ShopTr,R: Integer;		{ ShopRank and ShopTarget }
begin
	{ Determine the Shopping skill rank of the buyer. }
	ShopRk := SkillValue( PC , 21 );

	{ Determine the shopping target number, which should be the EGO }
	{ stat of the storekeeper. }
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then ShopTr := 10
	else begin
		{ Target is based on both the Ego of the shopkeeper }
		{ and also on the relationship with the PC. }
		ShopTr := NPC^.Stat[ STAT_Ego ];
		R := ReactionScore( Nil , PC , NPC );
		if R > 0 then begin
			ShopTr := ShopTr - ( R div 5 );
		end else if R < 0 then begin
			{ It's much harder to haggle if the shopkeep }
			{ doesn't like you. }
			ShopTr := ShopTr + Abs( R ) div 2;
		end;
	end;

	{ If ShopRk beats ShopTr, lower the asking price. }
	if ShopRk > ShopTr then begin
		{ Every point of shopping skill that the unit has }
		{ gives a 2% discount to whatever is being purchased. }
		ShopRk := ( ShopRk - ShopTr ) * 2;
		if ShopRk > 50 then ShopRk := 50;

		Price := ( Price * (100 - ShopRk ) ) div 100;
	end;
	if Price < 1 then Price := 1;

	ScalePrice := Price;
end;

Function PurchasePrice( PC,NPC,Item: GearPtr ): LongInt;
	{ Determine the purchase price of ITEM as being sold by NPC }
	{ to PC. }
begin
	{ Scale the base cost for the item. }
	PurchasePrice := ScalePrice( PC , NPC , GearValue( Item ) );
end;

Procedure ShoppingXP( PC , Part: GearPtr );
	{ The PC has just purchased PART. Give some XP to the PC's shopping }
	{ skill, then print a message if appropriate. }
var
	Price: LongInt;
begin
	{ Find the price of the gear. This must be positive or it'll }
	{ crash the logarithm function. }
	Price := GearValue( Part );
	if Price < 1 then Price := 1;
	if DoleSkillExperience( PC , 21 , Round( Ln( Price ) ) + 1 ) then begin
		DialogMsg( MsgString( 'SHOPPING_SkillAdvance' ) );
	end;
end;

{$IFDEF SDLMODE}
Procedure JustGBRedraw;
    { Just redraw the map. }
begin
    SDLCombatDisplay( SERV_GB );
end;

Procedure ServiceRedraw;
	{ Redraw the screen for whatever service is going to go on. }
begin
	SDLCombatDisplay( SERV_GB );
	SetupInteractDisplay( TeamColor( SERV_GB , SERV_NPC ) );
	DisplayInteractStatus( SERV_GB , SERV_NPC , CHAT_React , CHAT_Endurance );
	if SERV_Info <> Nil then begin
{		DisplayGearInfo( SERV_Info , SERV_GB );}
		CMessage( SAttValue( SERV_Info^.SA , 'DESC' ) , ZONE_Menu.GetRect() , MenuItem );
	end;
	CMessage( '$' + BStr( NAttValue( SERV_PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_Clock , InfoHilight );
	GameMsg( CHAT_Message , ZONE_InteractMsg.GetRect() , InfoHiLight );
end;

Procedure BasicServiceRedraw;
    { Redraw the services interface without any of the bells and whistles. }
begin
	SDLCombatDisplay( SERV_GB );
    InfoBox( ZONE_ShopTop.GetRect() );
    InfoBox( ZONE_ShopBottom.GetRect() );
    InfoBox( ZONE_ShopInfo.GetRect() );
    InfoBox( ZONE_ShopCash.GetRect() );
    DrawPortrait( SERV_GB, SERV_NPC, ZONE_ShopNPCPortrait.GetRect(), False );
    DrawPortrait( SERV_GB, SERV_Customer, ZONE_ShopPCPortrait.GetRect(), False );
	CMessage( GearName(SERV_NPC) , ZONE_ShopNPCName.GetRect() , InfoHilight );
	CMessage( GearName(SERV_Customer) , ZONE_ShopPCName.GetRect() , InfoHilight );
	CMessage( '$' + BStr( NAttValue( SERV_PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_ShopCash.GetRect() , InfoHilight );
	GameMsg( CHAT_Message , ZONE_ShopText.GetRect() , InfoHiLight );
end;

Procedure BrowseListRedraw;
    { Redraw the services interface and show the longform info for a list item. }
var
    Part: GearPtr;
begin
    BasicServiceRedraw();
	if ( SERV_Menu <> Nil ) and ( SERV_Info <> Nil ) then begin
		Part := RetrieveGearSib( SERV_Info , CurrentMenuItemValue( SERV_Menu ) );
		if Part <> Nil then begin
        	LongformGearInfo( Part , SERV_GB, ZONE_ShopInfo );
		end;
	end;
end;

Procedure BrowseTreeRedraw;
    { Redraw the services interface and show the longform info for a gear. }
var
    Part: GearPtr;
begin
    BasicServiceRedraw();
	if ( SERV_Menu <> Nil ) and ( SERV_Info <> Nil ) then begin
		Part := LocateGearByNumber( SERV_Info , CurrentMenuItemValue( SERV_Menu ) );
		if Part <> Nil then begin
        	LongformGearInfo( Part , SERV_GB, ZONE_ShopInfo );
		end;
	end;
end;

Procedure FocusOnOneRedraw;
    { Redraw the services interface and show the longform info for a list item. }
begin
    BasicServiceRedraw();
	if ( SERV_Info <> Nil ) then begin
    	LongformGearInfo( SERV_Info , SERV_GB, ZONE_ShopInfo );
	end;
end;


{$ENDIF}

procedure BuyAmmoClips( GB: GameBoardPtr; PC,NPC,Weapon: GearPtr );
	{ Allow spare clips to be purchased for this weapon. }
var
	AmmoList: GearPtr;
	Procedure AddAmmoToList( Proto: GearPtr );
		{ Create a clone of this ammunition and add it to the list. }
	var
		A,ATmp,AVar,VarList: GearPtr;
	begin
		A := CloneGear( Proto );
		AppendGear( AmmoList , A );
	end;
	Procedure LookForAmmo( LList: GearPtr );
		{ Search along this linked list looking for ammo. If you find }
		{ any, copy it and add it to the list. Then, add any ammo varieties }
		{ allowed by the shopkeeper's skill level and tolerance. }
	begin
		while LList <> Nil do begin
			if LList^.G = GG_Ammo then begin
				AddAmmoToList( LList );
			end;

			LookForAmmo( LList^.SubCom );
			LList := LList^.Next;
		end;
	end;
var
	ShopMenu: RPGMenuPtr;
	Ammo: GearPtr;
	N: Integer;
	Cost: LongInt;
begin
	{ Step One: Create the list of ammo. }
	AmmoList := Nil;
	LookForAmmo( Weapon^.SubCom );

	{ Step Two: Create the shopping menu. }
    {$IFDEF SDLMODE}
	ShopMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
    {$ELSE}
	ShopMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
    {$ENDIF}

	N := 1;
	Ammo := AmmoList;
	while Ammo <> Nil do begin
		AddRPGMenuItem( ShopMenu , GearName( Ammo ) + ' ($' + BStr( PurchasePrice( PC , NPC , Ammo ) ) + ')' , N );

		Inc( N );
		Ammo := Ammo^.Next;
	end;
	RPMSortAlpha( ShopMenu );
	AlphaKeyMenu( ShopMenu );
	AddRPGMenuItem( ShopMenu , MsgString( 'EXIT' ) , -1 );

	{ Step Three: Keep shopping until the PC selects exit. }
	repeat
{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
        SERV_Info := AmmoList;
        SERV_Menu := ShopMenu;
		N := SelectMenu( ShopMenu , @BrowseListRedraw );
{$ELSE}
		N := SelectMenu( ShopMenu );
{$ENDIF}

		if N > 0 then begin
			Ammo := RetrieveGearSib( AmmoList , N );
			Cost := PurchasePrice( PC , NPC , Ammo );

			if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
				{ Copy the gear, then stick it in inventory. }
				Ammo := CloneGear( Ammo );

				GivePartToPC( GB , Ammo , PC );

				{ Reduce the buyer's cash by the cost of the gear. }
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );

{$IFDEF SDLMODE}
				CHAT_Message := MsgString( 'BUYREPLY' + BStr( Random( 4 ) + 1 ) );
{$ELSE}
				GameMsg( MsgString( 'BUYREPLY' + BStr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHilight );
{$ENDIF}
				DialogMSG( ReplaceHash( MsgString( 'BUY_YOUHAVEBOUGHT' ) , GearName( Ammo ) ) );

				{ Give some XP to the PC's SHOPPING skill. }
				ShoppingXP( PC , Ammo );
			end else begin
				{ Not enough cash to buy... }
				DialogMSG( ReplaceHash( MsgString( 'BUY_CANTAFFORD' ) , GearName( Ammo ) ) );
{$IFDEF SDLMODE}
				Chat_Message := MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) );
{$ELSE}
				GameMsg( MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}

			end;
		end;

	until N = -1;

	{ Upon exiting, dispose of the ammo list. }
	DisposeRPGMenu( ShopMenu );
	DisposeGear( AmmoList );
end;

procedure PurchaseGear( GB: GameBoardPtr; PC,NPC,Part: GearPtr );
	{ The unit may or may not want to buy PART. }
	{ Show the price of this gear, and ask whether or not the }
	{ player wants to make this purchase. }
var
	YNMenu: RPGMenuPtr;
	Cost: LongInt;
	N: Integer;
	msg: String;
begin
	Cost := PurchasePrice( PC , NPC , Part );

    {$IFDEF SDLMODE}
	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
    {$ELSE}
	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
    {$ENDIF}
	AddRPGMenuItem( YNMenu , 'Buy ' + GearName( Part ) + ' ($' + BStr( Cost ) + ')' , 1 );
	if ( Part^.G = GG_Mecha ) then 	AddRPGMenuItem( YNMenu , 'View Tech Stats' , 3 );
	if ( Part^.SubCom <> Nil ) or ( Part^.InvCom <> Nil ) then AddRPGMenuItem( YNMenu , MsgString( 'SERVICES_BrowseParts' ) , 2 );
	if ( SeekSubsByG( Part^.SubCom , GG_Ammo ) <> Nil ) and ( Part^.Scale = 0 ) then AddRPGMenuItem( YNMenu , MsgString( 'SERVICES_BuyClips' ) , 4 );
	AddRPGMenuItem( YNMenu , 'Search Again' , -1 );

	msg := MSgString( 'BuyPROMPT' + Bstr( Random( 4 ) + 1 ) );
	msg := ReplaceHash( msg , GearName( Part ) );
	msg := ReplaceHash( msg , BStr( Cost ) );

{$IFDEF SDLMODE}
	CHAT_Message := Msg;
{$ELSE}
	GameMsg( msg , ZONE_InteractMsg , InfoHilight );
{$ENDIF}

	repeat
{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
		SERV_Info := Part;
		N := SelectMenu( YNMenu , @FocusOnOneRedraw );
{$ELSE}
		DisplayGearInfo( Part );
		CMessage( '$' + BStr( NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_Clock , InfoHilight );
		N := SelectMenu( YNMenu );
{$ENDIF}
		if N = 1 then begin
			if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
				{ Copy the gear, then stick it in inventory. }
				Part := CloneGear( Part );

				GivePartToPC( GB , Part , PC );

				{ Reduce the buyer's cash by the cost of the gear. }
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );

{$IFDEF SDLMODE}
				CHAT_Message := MsgString( 'BUYREPLY' + BStr( Random( 4 ) + 1 ) );
{$ELSE}
				GameMsg( MsgString( 'BUYREPLY' + BStr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHilight );
{$ENDIF}

				DialogMSG( ReplaceHash( MsgString( 'BUY_YOUHAVEBOUGHT' ) , GearName( Part ) ) );

				{ Give some XP to the PC's SHOPPING skill. }
				ShoppingXP( PC , Part );
			end else begin
				{ Not enough cash to buy... }
				DialogMSG( ReplaceHash( MsgString( 'BUY_CANTAFFORD' ) , GearName( Part ) ) );
{$IFDEF SDLMODE}
				CHAT_Message := MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) );
{$ELSE}
				GameMsg( MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHilight );
{$ENDIF}
			end;
		end else if N = 2 then begin
{$IFDEF SDLMODE}
			MechaPartBrowser( Part , @JustGBRedraw );
{$ELSE}
			MechaPartBrowser( Part );
{$ENDIF}
		end else if N = 3 then begin
{$IFDEF SDLMODE}
			CHAT_Message := MechaDescription( Part );
{$ELSE}
			GameMsg( MechaDescription( Part ) , ZONE_MEnu , InfoGreen );
			EndOfGameMoreKey;
{$ENDIF}
			N := 2;
		end else if N = 4 then begin

			BuyAmmoClips( GB, PC, NPC, Part )

		end else if N = -1 then begin
{$IFDEF SDLMODE}
			CHAT_Message := MsgString( 'BUYCANCEL' + BStr( Random( 4 ) + 1 ) );
{$ELSE}
			GameMsg( MsgString( 'BUYCANCEL' + BStr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHilight );
{$ENDIF}
		end;
	until N <> 2;

	DisposeRPGMenu( YNMenu );
end;

Function SellGear( var LList,Part: GearPtr; PC,NPC: GearPtr ): Boolean;
	{ The unit may or may not want to sell PART. }
	{ Show the price of this gear, and ask whether or not the }
	{ player wants to make this sale. }
    { NOTE: SERV_GB must be set before this proc is called!!! }
var
	YNMenu: RPGMenuPtr;
	Cost: Int64;
	R,ShopRk,ShopTr: Integer;
	N: Integer;
	WasStolen: Boolean;
	msg: String;
begin
	{ First - check to see whether or not the item is stolen. }
	{ Most shopkeepers won't buy stolen goods. The PC has to locate }
	{ a fence for illicit transactions. }
	WasStolen := AStringHasBString( SAttValue( Part^.SA , 'TYPE' ) , 'STOLEN' ) and ( NPC <> Nil ) and ( NPC^.G = GG_Character );
	if WasStolen then begin
		N := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful );
		Cost := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Heroic );
		if Cost > 0 then N := N + Cost;
		if N >= 0 then begin
			{ This shopkeeper won't buy stolen items. }
{$IFDEF SDLMODE}
			CHAT_Message := MsgString( 'SERVICES_StolenResponse' );
{$ELSE}
			GameMsg( MsgString( 'SERVICES_StolenResponse' ) , ZONE_InteractMsg , EnemyRed );
{$ENDIF}
			DialogMsg( MsgString( 'SERVICES_StolenDesc' ) );

			{ If the shopkeeper doesn't already hate the PC, }
			{ then the PC's reputation and relation scores }
			{ may both get damaged. }
			if ( PC <> Nil ) and ( NAttValue( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_PErsonal , NAS_CID ) ) >= -20 ) then begin
				AddReputation( PC , 2 , -1 );
				if N > Random( 200 ) then AddReputation( PC , 6 , -1 );
				AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_PErsonal , NAS_CID ) , -( Random( 6 ) + 1 ) );
			end;

			Exit( False );
		end;
	end;

	Cost := BaseGearValue( Part );
	if Destroyed( Part ) then Cost := Cost div 3;

	{ Determine shopping rank. }
	ShopRk := SkillValue( PC , 21 );

	{ Determine shopping target. }
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then ShopTr := 10
	else begin
		{ Target is based on both the Ego of the shopkeeper }
		{ and also on the relationship with the PC. }
		ShopTr := NPC^.Stat[ STAT_Ego ];
		R := ReactionScore( Nil , PC , NPC );
		if R > 0 then begin
			ShopTr := ShopTr - ( R div 5 );
		end else if R < 0 then begin
			{ It's much harder to haggle if the shopkeep }
			{ doesn't like you. }
			ShopTr := ShopTr + Abs( R ) div 2;
		end;
	end;

	{ Every point of shopping skill that the unit has }
	{ gives a 1% bonus to the money gained. }
	ShopRk := ShopRk - ShopTR;
	if ShopRk > 40 then ShopRk := 40
	else if ShopRk < 0 then ShopRk := 0;

	Cost := ( Cost * (20 + ShopRk ) ) div 100;
	if Cost < 1 then Cost := 1;

    {$IFDEF SDLMODE}
	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
    {$ELSE}
	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
    {$ENDIF}
	AddRPGMenuItem( YNMenu , 'Sell ' + GearName( Part ) + ' ($' + BStr( Cost ) + ')' , 1 );
	AddRPGMenuItem( YNMenu , 'Maybe later' , -1 );

	{ Query the menu - Sell it or not? }
	msg := MSgString( 'SELLPROMPT' + Bstr( Random( 4 ) + 1 ) );
	msg := ReplaceHash( msg , BStr( Cost ) );
	msg := ReplaceHash( msg , GearName( Part ) );
{$IFDEF SDLMODE}
    SERV_PC := PC;
    SERV_Customer := PC;
    SERV_NPC := NPC;
	SERV_Info := Part;
	CHAT_Message := Msg;
	N := SelectMenu( YNMenu , @FocusOnOneRedraw );
{$ELSE}
	GameMsg( msg , ZONE_InteractMsg , InfoHilight );
	N := SelectMenu( YNMenu );
{$ENDIF}
	if N = 1 then begin
		{ Increase the buyer's cash by the price of the gear. }
		AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cost );

{$IFDEF SDLMODE}
		CHAT_Message := MSgString( 'SELLREPLY' + Bstr( Random( 4 ) + 1 ) );
{$ELSE}
		GameMsg( MSgString( 'SELLREPLY' + Bstr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHilight );
{$ENDIF}

		msg := MSgString( 'SELL_YOUHAVESOLD' );
		msg := ReplaceHash( msg , GearName( Part ) );
		msg := ReplaceHash( msg , BStr( Cost ) );
		DialogMSG( msg );

		{ Give some XP to the PC's SHOPPING skill. }
		ShoppingXP( PC , Part );

		{ If the item was stolen, trash the PC's reputation here. }
		if WasStolen then begin
			AddReputation( PC , 2 , -5 );
		end;

		RemoveGear( LList , Part );
	end else begin
{$IFDEF SDLMODE}
		CHAT_Message := MSgString( 'SELLCANCEL' + Bstr( Random( 4 ) + 1 ) );
{$ELSE}
		GameMsg( MSgString( 'SELLCANCEL' + Bstr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHilight );
{$ENDIF}
	end;

	DisposeRPGMenu( YNMenu );

	SellGear := N = 1;
end;



Function RepairMasterCost( Master: GearPtr; Skill: Integer ): LongInt;
	{ Return the expected cost of repairing every component of }
	{ MASTER which can be handled using SKILL. }
var
	it: LongInt;
begin
	it := TotalRepairableDamage( Master , SKill ) * CredsPerDP;

	{ Since parts that could be helped by First Aid heal by themselves }
	{ usually, the cost to treat injuries using the First Aid skill is }
	{ substantially reduced. }
	if ( Skill = 20 ) and ( it > 0 ) then begin
		it := it div 2;
		if it < 1 then it := 1;
	end;

	RepairMasterCost := it;
end;

Function RepairAllCost( GB: GameBoardPtr; Skill: Integer ): LongInt;
	{ Determine the cost of repairing every item belonging to Team 1. }
var
	Part: GearPtr;
	Cost: longInt;
begin
	{ Initialize values. }
	Part := GB^.Meks;
	Cost := 0;

	{ Browse through each gear on the board, adding the cost to repair }
	{ each Team 1 mek or character. }
	while Part <> Nil do begin
		if ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
			{ Only repair mecha which have pilots assigned!!! }
			{ If the PC had to patch up all that salvage every time... Brr... }
			if ( Part^.G <> GG_Mecha ) or ( SAttValue( Part^.SA , 'PILOT' ) <> '' ) then begin
				Cost := Cost + RepairMasterCost( Part , Skill );
			end;
		end;

		Part := Part^.Next;
	end;

	RepairAllCost := Cost;
end;

Procedure DoRepairMaster( GB: GameBoardPtr; Master,Repairer: GearPtr; Skill: Integer );
	{ Remove the damage counters from every component of MASTER which }
	{ can be affected using the provided SKILL. }
var
	TRD: LongInt;
begin
	{ Repair this part, if appropriate. }
	TRD := TotalRepairableDamage( Master , SKill );
	ApplyRepairPoints( Master , Skill , TRD );

	{ Wait an amount of time, depending on the repairer's skill }
	{ level. }
	QuickTime( GB , AP_Minute + RollStep( 12 ) - SkillValue( Repairer , SKill ) );
end;

Procedure DoRepairAll( GB: GameBoardPtr; NPC: GearPtr; Skill: Integer );
	{ Repair every item belonging to Team 1. }
var
	Part: GearPtr;
begin
	{ Initialize values. }
	Part := GB^.Meks;

	{ Browse through each gear on the board, repairing }
	{ each Team 1 mek or character. }
	while Part <> Nil do begin
		if ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
			{ Only repair mecha which have pilots assigned!!! }
			{ If the PC had to patch up all that salvage every time... Brr... }
			if ( Part^.G <> GG_Mecha ) or ( SAttValue( Part^.SA , 'PILOT' ) <> '' ) then begin
				DoRepairMaster( GB , Part , NPC , Skill );
			end;
		end;

		Part := Part^.Next;
	end;
end;

Procedure RepairAllFrontEnd( GB: GameBoardPtr; PC, NPC: GearPtr; Skill: Integer );
	{ Run the REPAIR ALL procedure, and charge the PC for the work done. }
	{ If the PC doesn't have enough money to repair everything roll to }
	{ see if the NPC will do this work for free. }
const
	NumRepairSayings = 5;
var
	msg: String;
	Cost,Cash: LongInt;
	R: Integer;
begin
	{ Determine the cost of repairing everything, and also }
	{ the amount of cash the PC has. }
	Cost := ScalePrice( PC , NPC , RepairAllCost( GB , Skill ) );
	Cash := NAttValue( PC^.NA, NAG_Experience , NAS_Credits );
	R := ReactionScore( Nil , PC , NPC );
	msg := '';

	{ See whether or not the PC will be charged for this repair. }
	{ If the NPC likes the PC well enough, the service will be free. }
	if ( Random( 150 ) + 10 ) < R then begin
		{ The NPC will do the PC a favor, and do this one for free. }
		msg := MsgString( 'SERVICES_RAFree' );
		Cost := 0;
	end else if ( Cash < Cost ) and ( R > ( 10 + NPC^.Stat[ STAT_Ego ] ) ) then begin
		msg := MsgString( 'SERVICES_RACantPay' );
		AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) , -Random( 10 ) );
		Cost := 0;
	end;

	if Cost < Cash then begin
		DoRepairAll( GB , NPC , Skill );
		AddNAtt( PC^.NA, NAG_Experience , NAS_Credits , -Cost );
		if msg = '' then msg := MsgString( 'SERVICES_RADoRA' + BStr( Random( NumRepairSayings ) + 1 ) );
	end else begin
		msg := MsgString( 'SERVICES_RALousyBum' );
	end;

{$IFDEF SDLMODE}
	CHAT_Message := msg;
{$ELSE}
	GameMsg( msg , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
end;

Procedure RepairOneFrontEnd( GB: GameBoardPtr; Part, PC, NPC: GearPtr; Skill: Integer );
	{ Run the REPAIR MASTER procedure, and charge the PC for the work done. }
	{ If the PC doesn't have enough money to repair everything roll to }
	{ see if the NPC will do this work for free. }
const
	NumRepairSayings = 5;
var
	Cost,Cash: LongInt;
	R: Integer;
begin
	{ Determine the cost of repairing everything, and also }
	{ the amount of cash the PC has. }
	Cost := ScalePrice( PC , NPC , RepairMasterCost( PArt , Skill ) );
	Cash := NAttValue( PC^.NA, NAG_Experience , NAS_Credits );
	R := ReactionScore( Nil , PC , NPC );

	{ See whether or not the PC will be charged for this repair. }
	{ If the NPC likes the PC well enough, the service will be free. }
	if ( Random( 90 ) + 10 ) < R then begin
		{ The NPC will do the PC a favor, and do this one for free. }
{$IFDEF SDLMODE}
        CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_RAFree' );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_RAFree' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
		Cost := 0;
	end else if ( Cash < Cost ) and ( R > 10 ) then begin
{$IFDEF SDLMODE}
        CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_RACantPay' );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_RACantPay' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
		AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) , -Random( 5 ) );
		Cost := 0;
	end;

	if Cost < Cash then begin
		DoRepairMaster( GB , Part , NPC , Skill );
		AddNAtt( PC^.NA, NAG_Experience , NAS_Credits , -Cost );
{$IFDEF SDLMODE}
		CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_RADoRA' + BStr( Random( NumRepairSayings ) + 1 ) );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_RADoRA' + BStr( Random( NumRepairSayings ) + 1 ) ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end else begin
{$IFDEF SDLMODE}
        CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_RALousyBum' );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_RALousyBum' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end;
end;

Function ReloadMagazineCost( Mag: GearPtr ): LongInt;
	{ Calculate the cost of reloading this magazine. }
var
	Spent: Integer;
	it: LongInt;
begin
	it := 0;
	if Mag^.G = GG_Ammo then begin
		Spent := NAttValue( Mag^.NA , NAG_WeaponModifier , NAS_AmmoSpent );
		if Spent > 0 then begin
			it := ( BaseAmmoValue( Mag ) * Spent ) div Mag^.Stat[ STAT_AmmoPresent ];
			if it < 1 then it := 1;
		end;
	end;

	if it > 0 then begin
		{ Reduce the reload cost by a factor of 5- apparently, magazines are really expensive. }
		it := it div 5;
		if it < 1 then it := 1;
	end;

	ReloadMagazineCost := it;
end;

Function ReloadMasterCost( M: GearPtr ): LongInt;
	{ Return the cost of refilling all magazines held by M. }
var
	Part: GearPtr;
	it: LongInt;
begin
	it := ReloadMagazineCost( M );

	Part := M^.SubCom;
	while Part <> Nil do begin
		it := it + ReloadMasterCost( Part );
		Part := Part^.Next;
	end;

	Part := M^.InvCom;
	while Part <> Nil do begin
		it := it + ReloadMasterCost( Part );
		Part := Part^.Next;
	end;

	ReloadMasterCost := it;
end;

Procedure DoReloadMaster( M: GearPtr );
	{ Clear all ammo usage by M. }
var
	Part: GearPtr;
begin
	{ If this is an ammunition gear, set the number of shots fired to 0. }
	if M^.G = GG_Ammo then SetNAtt( M^.NA , NAG_WeaponModifier , NAS_AmmoSpent , 0 );

	{ Check SubComs and InvComs. }
	Part := M^.SubCom;
	while Part <> Nil do begin
		DoReloadMaster( Part );
		Part := Part^.Next;
	end;
	Part := M^.InvCom;
	while Part <> Nil do begin
		DoReloadMaster( Part );
		Part := Part^.Next;
	end;
end;

Function ReloadCharsCost( GB: GameBoardPtr; PC,NPC: GearPtr ): LongInt;
	{ Calculate the cost of reloading every PC's ammunition. }
var
	it: LongInt;
	Part: GearPtr;
begin
	it := 0;
	Part := GB^.Meks;
	while Part <> Nil do begin
		if ( ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) ) and ( Part^.G = GG_Character ) then begin
			it := it + ReloadMasterCost( Part );
		end;
		Part := Part^.Next;
	end;

	{ SCale the price for the PC's shopping skill. }
	if it > 0 then it := ScalePrice( PC , NPC , it );

	ReloadCharsCost := it;
end;

Procedure DoReloadChars( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ Calculate the cost of reloading every PC's ammunition. }
var
	COst: LongInt;
	Part: GearPtr;
begin
	Cost := ReloadCharsCost( GB , PC , NPC );
	if Cost <= NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) then begin
		Part := GB^.Meks;
		while Part <> Nil do begin
			if ( ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) ) and ( Part^.G = GG_Character ) then begin
				DoReloadMaster( Part );
			end;
			Part := Part^.Next;
		end;

		{ Print the message. }
{$IFDEF SDLMODE}
		CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_ReloadChars' );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_ReloadChars' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end else begin
		{ Player can't afford the reload. }
{$IFDEF SDLMODE}
		CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_RALousyBum' );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_RALousyBum' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end;
end;

Function ReloadMechaCost( GB: GameBoardPtr; PC,NPC: GearPtr ): LongInt;
	{ Calculate the cost of reloading every mek's ammunition. }
var
	it: LongInt;
	Part: GearPtr;
begin
	it := 0;
	Part := GB^.Meks;
	while Part <> Nil do begin
		if ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( Part^.G = GG_Mecha ) then begin
			it := it + ReloadMasterCost( Part );
		end;
		Part := Part^.Next;
	end;

	{ SCale the price for the PC's shopping skill. }
	if it > 0 then it := ScalePrice( PC , NPC , it );

	ReloadMechaCost := it;
end;

Procedure DoReloadMecha( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ Calculate the cost of reloading every PC's ammunition. }
var
	COst: LongInt;
	Part: GearPtr;
begin
	Cost := ReloadMechaCost( GB , PC , NPC );
	if Cost <= NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) then begin
		Part := GB^.Meks;
		while Part <> Nil do begin
			if ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( Part^.G = GG_Mecha ) then begin
				DoReloadMaster( Part );
			end;
			Part := Part^.Next;
		end;

		{ Print the message. }
{$IFDEF SDLMODE}
		CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_ReloadMeks' );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_ReloadMeks' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end else begin
		{ Player can't afford the reload. }
{$IFDEF SDLMODE}
		CHAT_Message := SAttValue( TEXT_MESSAGES , 'SERVICES_RALousyBum' );
{$ELSE}
		GameMsg( SAttValue( TEXT_MESSAGES , 'SERVICES_RALousyBum' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end;
end;

Function NotGoodWares( I , NPC: GearPtr; Stuff: String ): Boolean;
	{ Return TRUE if this item is inappropriate for NPC's shop, }
	{ FALSE if it is. An item is appropriate if: }
	{ - its G value may be found in STUFF. }
	{ - its unscaled value doesn't exceed the shopkeep's rating. }
var
	NGW: Boolean;
	N: Integer;
	Cost: LongInt;
begin
	{ Begin by assuming TRUE. }
	NGW := True;

	{ Search through STUFF to see if Item's general type is listed. }
	while Stuff <> '' do begin
		N := ExtractValue( Stuff );
		if I^.G = N then NGW := False;
	end;

	if not NGW then begin
		{ Determine the unscaled cost of this item. }
		Cost := GearValue( I );
		N := I^.Scale;
		while N > 0 do begin
			Dec( N );
			Cost := Cost div 5;
		end;

		{ Determine the Log base 2 of the item... this will be }
		{ the target number to decide whether or not the shopkeep }
		{ might have this item. }
		N := 0;
		while Cost > 2 do begin
			Inc( N );
			Cost := Cost div 2;
		end;

		if RollStep( SkillValue( NPC , 21 ) ) < N then NGW := True;

	end;

	NotGoodWares := NGW;
end;

Procedure AddAmmo( var Wares: GearPtr; Part: GearPtr );
	{ Browse through PART. If you find any guns or missile launchers, }
	{ clone its ammunition & add it to WARES. }
var
	A,A2: GearPtr;
begin
	while Part <> Nil do begin
		{ Spare magazines shouldn't be as common as the weapons }
		{ themselves, so only add ammo for this weapon on a }
		{ random chance. }
		if ( Part^.G = GG_Weapon ) and ( Random( 3 ) = 1 ) then begin
			if ( Part^.S = GS_Ballistic ) or ( Part^.S = GS_Missile ) then begin
				A := Part^.SubCom;
				while A <> nil do begin
					if A^.G = GG_Ammo then begin
						{ Clone this gear, and stick it in the list. }
						A2 := CloneGear( A );
						A2^.Next := Wares;
						Wares := A2;
					end;
					A := A^.Next;
				end;
			end;
		end;

		{ Recursively check sub-components. }
		AddAmmo( Wares , Part^.SubCom );
		AddAmmo( Wares , Part^.InvCom );

		Part := Part^.Next;
	end;
end;

Function Random_Mecha_Colors: String;
	{ Return some random colors for this mecha. }
begin
{$IFDEF SDLMODE}
	if Random( 3 ) = 1 then begin
		random_mecha_colors := standard_lot_colors[ random( num_standard_schemes ) ];
	end else begin
		random_mecha_colors := RandomColorString( CS_PrimaryMecha ) + ' ' + RandomColorString( CS_SecondaryMecha ) + ' ' + RandomColorString( CS_Detailing );
	end;
{$ELSE}
	random_mecha_colors := standard_lot_colors[ random( num_standard_schemes ) ];
{$ENDIF}
end;

Procedure AddSomeMeks( var Wares: GearPtr );
	{ WARES is the inventory list of a shop. Let's add ~10 mecha files }
	{ to the list. }
var
	Mek: GearPtr;
	ShopList,MekFile: SAttPtr;
	N: Integer;
begin
	ShopList := CreateFileList( Design_Directory + Default_Search_Pattern );

	{ From the list of filenames, pick a number of them at random. }
	N := 20;
	while ( N > 0 ) and ( ShopList <> Nil ) do begin
		MekFile := SelectRandomSAtt( ShopList );

		{ Load this file }
		Mek := LoadSingleMecha( MekFile^.Info , Design_Directory );

		{ Remove this SAtt from the list, so we don't load it twice. }
		RemoveSAtt( ShopList , MekFile );

		{ Attach the loaded mek to the end of WARES. }
		if ( Mek <> Nil ) and ( Mek^.G = GG_Mecha ) then begin
			LastGear( Mek )^.Next := Wares;
			Wares := Mek;
		end else begin
			DisposeGear( Mek );
		end;
	end;

	{ Get rid of the shopping list. }
	DisposeSAtt( ShopList );
end;

Procedure AddMekExtras( var Wares: GearPtr );
	{ Add mecha accessories from the MEK_EQUIPMENT file. }
var
	F: Text;
	MEX,Item,T: GearPtr;
begin
	{ Read the basic items list, then filter it for appropriate }
	{ wares afterwards. }
	Assign( F , Mek_Equipment_File );
	Reset( F );
	MEX := ReadGear( F );
	Close( F );

	T := MEX;
	while T <> Nil do begin
		{ On a random chance, add this item to the wares list. }
		if Random( 7 ) = 1 then begin
			Item := CloneGear( T );
			Item^.Next := Wares;
			Wares := Item;
		end;
		T := T^.Next;
	end;

	{ Get rid of the extras list. }
	DisposeGear( Mex );
end;


Function CreateWaresList( GB: GameBoardPtr; NPC: GearPtr; Stuff: String ): GearPtr;
	{ Fabricate the list of items this NPC has for sale. }
	Procedure InitShopItem( I: GearPtr );
		{ Certain items may need some initialization. }
	var
		mecha_colors: String;
	begin
		if I^.G = GG_Mecha then begin
			{ To start with, determine this merchant's lot color. This is the color all }
			{ the mecha in the sales lot are painted. Check to see if he has a color stored. }
			{ Otherwise pick a color scheme at random and save it. }
			mecha_colors := SAttValue( NPC^.SA , 'mecha_colors' );
			if mecha_colors = '' then begin
				mecha_colors := Random_Mecha_Colors;
				SetSAtt( NPC^.SA , 'mecha_colors <' + mecha_colors + '>' );
			end;
			SetSAtt( I^.SA , 'sdl_colors <' + mecha_colors + '>' );
		end;
	end;
var
	Wares,I,I2: GearPtr;	{ List of items for sale. }
	F: Text;
	NPCSeed,NPCRestock: LongInt;
begin
	{ Set the random seed to something less than random... }
	NPCSeed := NAttValue( NPC^.NA , NAG_PErsonal , NAS_RandSeed );
	NPCRestock := NAttValue( NPC^.NA , NAG_PErsonal , NAS_RestockTime );
	if NPCSeed = 0 then begin
		NPCSeed := Random( 100000 ) + 1;
		NPCRestock := Random( 86400 ) + 1;
		SetNAtt( NPC^.NA , NAG_PErsonal , NAS_RandSeed , NPCSeed );
		SetNAtt( NPC^.NA , NAG_PErsonal , NAS_RestockTime , NPCRestock );
	end;
	RandSeed := ( ( GB^.ComTime + NPCRestock ) div 86400 ) + NPCSeed;

	{ Read the basic items list, then filter it for appropriate }
	{ wares afterwards. }
	Assign( F , PC_Equipment_File );
	Reset( F );
	Wares := ReadGear( F );
	Close( F );

	{ Pass Two - Add extra ammo clips for all projectile and }
	{ missile weapons. }
	AddAmmo( Wares , Wares );

	{ If this is a mecha shop, also load some mecha files. }
	if AStringHasBString( Stuff , 'MECHA' ) then begin
		AddSomeMeks( Wares );
	end;

	{ If this shop has mecha extras, also load that file. }
	if AStringHasBString( Stuff , 'MEXTRA' ) then begin
		AddMekExtras( Wares );
	end;


	{ Do filtering here. }
	I := Wares;
	while I <> Nil do begin
		I2 := I^.Next;

		{ If this isn't a good item for this shop, remove it. }
		{ Otherwise increment the item counter. }
		if NotGoodWares( I , NPC , Stuff ) then begin
			RemoveGear( Wares , I );
		end else begin
		{A bit of overkill as the current InitShopItem only touch mechas}
			InitShopItem( I );
		end;

		I := I2;
	end;

	{ If N is too large for this shopkeeper, remove a number of items }
	{ from the inventory. }
	while NumSiblingGears( Wares ) > MaxShopItems do begin
		I := SelectRandomGear( Wares );
		RemoveGear( Wares , I );
	end;

	{ Re-randomize the random seed. }
	Randomize;

	{ Return the list we've created. }
	CreateWaresList := Wares;
end;

Procedure BrowseWares( GB: GameBoardPtr; PC,NPC: GearPtr; Wares: GearPtr );
	{ Take a look through the items this NPC has for sale. }
	{ First, construct the shop list. Then, browse each item, }
	{ potentially buying whichever one strikes your fancy. }
var
	RPM: RPGMenuPtr;	{ Buying menu. }
	I: GearPtr;
	N: Integer;
	msg: String;
begin

	{ Create the browsing menu. }
    {$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
    {$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
	AttachMenuDesc( RPM , ZONE_Menu );
    {$ENDIF}
	I := Wares;
	N := 1;
	while I <> Nil do begin
		msg := FullGearName( I );

		{ Add extra information, depending upon item type. }
        {$IFNDEF SDLMODE}
		if I^.G = GG_Weapon then begin
			msg := msg + '  (DC:' + BStr( ScaleDC( I^.V , I^.Scale ) ) + ')';
		end else if ( I^.G = GG_ExArmor ) or ( I^.G = GG_Shield ) then begin
			msg := msg + '  [AC:' + BStr( GearMaxArmor( I ) ) + ']';
		end else if I^.G = GG_Consumable then begin
			msg := msg + '  (' + BStr( I^.Stat[ STAT_FoodQuantity ] ) + ')';
		end;
        {$ENDIF}

		{ Add extra information, depending upon item scale. }
		if ( I^.G <> GG_Mecha ) and ( I^.Scale > 0 ) then begin
			msg := msg + '(SF' + BStr( I^.Scale ) + ')';
		end;

		{ Pad the message. }
{$IFDEF SDLMODE}
		while TextLength( GAME_FONT , ( msg + ' $' + BStr( PurchasePrice( PC , NPC , I ) ) ) ) < ( ZONE_ShopMenu.W - 5 ) do msg := msg + ' ';
{$ELSE}
		while Length( msg ) < ( ScreenZone[ ZONE_InteractMenu , 3 ] - ScreenZone[ ZONE_InteractMenu , 1 ] - 12 ) do msg := msg + ' ';
{$ENDIF}

		{ Add it to the menu. }
		AddRPGMenuItem( RPM , msg + ' $' + BStr( PurchasePrice( PC , NPC , I ) ) , N , SAttValue( I^.SA , 'DESC' ) );
		Inc( N );
		I := I^.Next;
	end;
	RPMSortAlpha( RPM );

	{ Error check - if for some reason we are left with a blank }
	{ menu, better leave this procedure. }
	if RPM^.NumItem < 1 then begin
		DisposeRPGMenu( RPM );
		Exit;
	end;

	RPM^.Mode := RPMNoCleanup;

	Repeat
		{ Display the trading stats. }

{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
        SERV_Info := Wares;
        SERV_Menu := RPM;
		N := SelectMenu( RPM , @BrowseListRedraw );
{$ELSE}
		DisplayGearInfo( PC );
		CMessage( '$' + BStr( NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_Clock , InfoHilight );
		N := SelectMenu( RPM );
{$ENDIF}

		if N > 0 then begin
			PurchaseGear( GB , PC , NPC , RetrieveGearSib( Wares , N ) );
		end;

	until N = -1;

	DisposeRPGMenu( RPM );
end;

Function CreateMechaMenu( GB: GameBoardPtr ): RPGMenuPtr;
	{ Create a menu listing all the Team1 meks on the board. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	Mek: GearPtr;
	msg: String;
begin
	{ Allocate a menu. }
    {$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
    {$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
    {$ENDIF}

	{ Add each mek to the board. }
	N := 1;
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		{ If this gear is a mecha, and it belongs to the PC, }
		{ add it to the menu. }
		if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and not GearActive( Mek ) then begin
			msg := FullGearName( Mek );
			AddRPGMenuItem( RPM , msg , N );
		end;

		Inc( N );
		Mek := Mek^.Next;
	end;

	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MsgString( 'SERVICES_Exit' ) , -1 );

	CreateMechaMenu := RPM;
end;

Procedure SellStuff( GB: GameBoardPtr; PCInv,PCChar,NPC: GearPtr );
	{ The player wants to sell some items to this NPC. }
	{ PCInv points to the team-1 gear whose inventory is to be sold. }
	{ PCChar points to the actual player character. }
var
	RPM: RPGMenuPtr;
	MI,N: Integer;
	Part : GearPtr;
begin
	MI := 1;
	repeat
		{ Create the menu. }
        {$IFDEF SDLMODE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
        {$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
		RPM^.Mode := RPMNoCleanup;
        {$ENDIF}
		AttachMenuDesc( RPM , ZONE_Menu );
		BuildInventoryMenu( RPM , PCInv );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Exit' ) , -1 );

		SetItemByPosition( RPM , MI );

		{ Get a choice from the menu, then record the current item }
		{ number. }
{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PCChar;
        SERV_Customer := PCChar;
        SERV_NPC := NPC;
        SERV_Info := PCInv;
        SERV_Menu := RPM;
		N := SelectMenu( RPM , @BrowseListRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		MI := RPM^.SelectItem;

		{ Dispose of the menu. }
		DisposeRPGMenu( RPM );

		{ If N is positive, prompt to sell that item. }
		if N > -1 then begin
			Part := LocateGearByNumber( PCInv , N );
			SellGear( Part^.Parent^.InvCom , Part , PCChar , NPC );
		end;

	until N = -1;
end;


Procedure ThisMechaWasSelected( GB: GameBoardPtr; MekNum: Integer; PC,NPC: GearPtr );
	{ Do all the standard shopping options with this mecha. }
	{ IMPORTANT: A mecha can only be sold if it's not currently on the map! }
	{ Otherwise, the PC could potentially sell himself if in the cockpit... }
var
	RPM: RPGMenuPtr;
	Mek: GearPtr;
	N: Integer;
begin
	{ Find the mecha. }
	Mek := RetrieveGearSib( GB^.Meks , MekNum );
    {$IFNDEF SDLMODE}
	DisplayGearInfo( Mek );
    {$ENDIF}

	repeat
		{ Create the menu. }
        {$IFDEF SDLMODE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
        {$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
        {$ENDIF}

		{ Add options, depending on the mek. }
		if not OnTheMap( Mek ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_Sell' ) + GearName( Mek ) , 1 );
		if TotalRepairableDamage( Mek , 15 ) > 0 then AddRPGMenuItem( RPM , MsgString( 'SERVICES_OSRSP1' ) + ' [$' + BStr( RepairMasterCost( Mek , 15 ) ) + ']' , 2 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_SellMekInv' ) , 4 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_BrowseParts' ) , 3 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Exit' ) , -1 );

{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
		SERV_Info := Mek;
		N := SelectMenu( RPM , @FocusOnOneRedraw );
{$ELSE}
		DisplayGearInfo( Mek );
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N = 1 then begin
			{ Sell the mecha. }
			if SellGear( GB^.Meks , Mek , PC , NPC ) then N := -1;

		end else if N = 2 then begin
			{ Repair the mecha. }
			RepairOneFrontEnd( GB , Mek , PC , NPC , 15 );

		end else if N = 3 then begin
			{ Use the parts browser. }
{$IFDEF SDLMODE}
			MechaPartBrowser( Mek , @JustGBRedraw );
{$ELSE}
			MechaPartBrowser( Mek );
{$ENDIF}

		end else if N = 4 then begin
			{ Sell items. }
			SellStuff( GB , Mek , PC , NPC );

		end;

	until N = -1;
end;

Procedure BrowseMecha( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The Player is going to take a look through his mecha list, maybe }
	{ sell some of them, maybe repair some of them... }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	repeat
		{ Create the browsing menu. }
		RPM := CreateMechaMenu( GB );

		{ Select an item from the menu, then get rid of the menu. }
{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
        SERV_Info := GB^.Meks;
        SERV_Menu := RPM;
		N := SelectMenu( RPM , @BrowseListRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		{ If a mecha was selected, take a look at it. }
		if N > 0 then begin
			ThisMechaWasSelected( GB , N , PC , NPC );
		end;
	until N = -1;
end;

Procedure InstallCyberware( GB: GameBoardPtr; PC , NPC: GearPtr );
	{ The NPC will attempt to install cyberware into the PC. }
	{ - The PC will select which item to install. }
	{ - If appropriate, the PC will select where to install. }
	{ - NPC will make rolls to reduce trauma rating of part. }
	{ - Time will be advanced by 6 hours. }
	{ - Part will be transferred and installed. }
	const
		RT_Average = 2;
		RT_Good = 3;
		RT_Bad = 1;

	Procedure ClearCyberSlot( Slot,Item: GearPtr );
		{ Clear any items currently using ITEM's CyberSlot }
		{ from Slot's list of subcomponents. }
	var
		SC,SC2: GearPtr;
		CyberSlot: String;
	begin
		CyberSlot := UpCase( SAttValue( Item^.SA , SAtt_CyberSlot ) );
		if CyberSlot <> '' then begin
			SC := Slot^.SubCom;
			while SC <> Nil do begin
				SC2 := SC^.Next;

				if UpCase( SAttValue( SC^.SA , SAtt_CyberSlot ) ) = CyberSlot then begin
					RemoveGear( Slot^.SubCom , SC );
				end;

				SC := SC2;
			end;
		end;
	end;

	Function ReduceTrauma( Item: GearPtr ): Integer;
		{ As part of the deal, the cyberdoc will attempt to }
		{ lower the trauma cost of this item. }
	var
		T,SkRoll,V0: Integer;
	begin
		{ Only modifier gears have trauma values, and not even }
		{ all of those... better make sure. }
		if ( Item^.G = GG_Modifier ) and ( Item^.V > 0 ) then begin
			{ Initial trauma will be affected by the PC's }
			{ psychological predisposition. }
			T := NAttValue( PC^.NA , NAG_CharDescription , NAS_Pragmatic );
			if T > 0 then begin
				Item^.V := Item^.V * ( 400 - T ) div 400;
			end else if T < 0 then begin
				{ Spiritual characters are more heavily }
				{ traumatized by cyberware. }
				Item^.V := Item^.V + ( Abs( T ) div 2 );
			end;

			{ The NPC gets three rolls to reduce the trauma. }
			V0 := Item^.V;
			SkRoll := 0;
			for t := 1 to 3 do begin
				SkRoll := SkRoll + RollStep( SkillValue( NPC , 24 ) );
			end;
			if SkRoll > Item^.V then begin
				Item^.V := Item^.V - ( SkRoll - Item^.V );
				if Item^.V < 1 then Item^.V := 1;
			end;

			if Item^.V = 1 then begin
				ReduceTrauma := RT_Good;
			end else if Item^.V < ( V0 div 2 ) then begin
				ReduceTrauma := RT_Average;
			end else begin
				ReduceTrauma := RT_Bad;
			end;

		end else begin
			ReduceTrauma := RT_Average;
		end;
	end;

var
	RPM: RPGMenuPtr;
	N: Integer;
	Item,Slot: GearPtr;

	Procedure CreateCyberMenu;
		{ Check through PC's inventory, adding items which bear }
		{ the "CYBER" tag to the menu. }
	var
		Part: GearPtr;
        N: Integer;
	begin
		Part := LocatePilot( PC )^.InvCom;
        N := 1;
		while Part <> Nil do begin
			if AStringHasBString( SAttValue( Part^.SA , 'TYPE' ) , 'CYBER' ) then begin
				AddRPGMenuItem( RPM , GearName( Part ) , N );
			end;
            Inc( N );
			Part := Part^.Next;
		end;
	end;

	Function WillingToPay: Boolean;
		{ The name is a bit misleading. This function checks to }
		{ see if the PC can pay, then if the PC agrees to the }
		{ price will then take his money. }
	var
		Cost: LongInt;
	begin
		Cost := SkillAdvCost( Nil , NAttValue( NPC^.NA , NAG_Skill , 24 ) ) * 2;
        {$IFDEF SDLMODE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
        {$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
        {$ENDIF}
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Cyber_Pay_Yes' ) , 1 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Cyber_Pay_No' ) , -1 );

{$IFDEF SDLMODE}
		CHAT_Message := ReplaceHash( MsgString( 'SERVICES_Cyber_Pay' ) , BStr( Cost ) );
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
		SERV_Info := Item;
		N := SelectMenu( RPM , @FocusOnOneRedraw );
{$ELSE}
		GameMsg( ReplaceHash( MsgString( 'SERVICES_Cyber_Pay' ) , BStr( Cost ) ) , ZONE_InteractMsg , InfoHiLight );
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N = 1 then begin
			if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );
				WillingToPay := True;
			end else begin
				WillingToPay := False;
			end;
		end else begin
			WillingToPay := False;
		end;
	end;

	Procedure PerformInstallation;
		{ Actually stick the part into the PC. }
	var
		Result: Integer;
	begin
        {$IFDEF SDLMODE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
        {$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
        {$ENDIF}
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Cyber_WaitPrompt' ) , -1 );
		ClearCyberSlot( Slot , Item );
		DelinkGear( Item^.Parent^.InvCom , Item );
		Result := ReduceTrauma( Item );
		InsertSubCom( Slot , Item );
		if GB <> Nil then QuickTime( GB , 3600 * 2 );
		AddStaminaDown( PC , Random( 8 ) + Random( 8 ) + Random( 8 ) + 3 );
		AddMentalDown( PC , Random( 8 ) + Random( 8 ) + Random( 8 ) + 3 );
		AddReputation( PC , 7 , 3 );
		ApplyCyberware( LocatePilot( PC ) , Item );
{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
		SERV_Info := Item;
		CHAT_Message := MsgString( 'SERVICES_Cyber_Wait' );
		N := SelectMenu( RPM , @FocusOnOneRedraw );
		DisposeRPGMenu( RPM );
		CHAT_Message := MsgString( 'SERVICES_Cyber_Done' + BStr( Result ) );
{$ELSE}
		GameMsg( MsgString( 'SERVICES_Cyber_Wait' ) , ZONE_InteractMsg , InfoHiLight );
		N := SelectMenu( RPM );
		DisposeRPGMenu( RPM );
		DisplayGearInfo( PC );
		GameMsg( MsgString( 'SERVICES_Cyber_Done' + BStr( Result ) ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
		DialogMsg( ReplaceHash( MsgString( 'SERVICES_Cyber_Confirmation' ) , GearName( Item ) ) );
	end;
begin
    {$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
    {$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
    {$ENDIF}
	CreateCyberMenu;

	if RPM^.NumItem > 0 then begin
{$IFDEF SDLMODE}
        SERV_GB := GB;
        SERV_PC := PC;
        SERV_Customer := PC;
        SERV_NPC := NPC;
        SERV_Info := PC^.InvCom;
        SERV_Menu := RPM;
		CHAT_Message := MsgString( 'SERVICES_Cyber_SelectPart' );
		N := SelectMenu( RPM , @BrowseListRedraw );
{$ELSE}
		GameMsg( MsgString( 'SERVICES_Cyber_SelectPart' ) , ZONE_InteractMsg , InfoHiLight );
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N > 0 then begin
			Item := RetrieveGearSib( PC^.InvCom , N );
			if Item <> Nil then begin
                {$IFDEF SDLMODE}
				RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
                {$ELSE}
				RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
                {$ENDIF}
				BuildSubMenu( RPM , PC , Item , False );
				if RPM^.NumItem = 1 then begin
					Slot := LocateGearByNumber( PC , RPM^.FirstItem^.Value );
				end else if RPM^.NumItem > 1 then begin
{$IFDEF SDLMODE}
                    SERV_GB := GB;
                    SERV_PC := PC;
                    SERV_Customer := PC;
                    SERV_NPC := NPC;
		            SERV_Info := Item;
					CHAT_Message := MsgString( 'SERVICES_Cyber_SelectSlot' );
					N := SelectMenu( RPM , @FocusOnOneRedraw );
{$ELSE}
					GameMsg( MsgString( 'SERVICES_Cyber_SelectSlot' ) , ZONE_InteractMsg , InfoHiLight );
					N := SelectMenu( RPM );
{$ENDIF}
					if N > 0 then begin
						Slot := LocateGearByNumber( PC , N );
					end else begin
						Slot := Nil;
					end;
				end else begin
					Slot := Nil;
				end;
				DisposeRPGMenu( RPM );

				if Slot <> Nil then begin
					if WillingToPay then begin
						PerformInstallation;
					end else begin
{$IFDEF SDLMODE}
						CHAT_Message := MsgString( 'SERVICES_Cyber_Cancel' );
{$ELSE}
						GameMsg( MsgString( 'SERVICES_Cyber_Cancel' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
					end;
				end else begin
{$IFDEF SDLMODE}
					CHAT_Message := MsgString( 'SERVICES_Cyber_Cancel' );
{$ELSE}
					GameMsg( MsgString( 'SERVICES_Cyber_Cancel' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
				end;

			end;
		end else begin
{$IFDEF SDLMODE}
			CHAT_Message := MsgString( 'SERVICES_Cyber_Cancel' );
{$ELSE}
			GameMsg( MsgString( 'SERVICES_Cyber_Cancel' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
		end;

	end else begin
{$IFDEF SDLMODE}
		CHAT_Message := MsgString( 'SERVICES_Cyber_NoPart' );
{$ELSE}
		GameMsg( MsgString( 'SERVICES_Cyber_NoPart' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
		DisposeRPGMenu( RPM );
	end;
end;

Procedure OpenShop( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
	{ Let the shopping commence! This procedure is called when }
	{ a conversation leads to a transaction... This is the top }
	{ level of the shopping menu, and should offer the following }
	{ choices: }
	{  - Browse Wares }
	{  - Repair All / Treat Injuries (depening on NPC skills) }
	{  - Reload All (if this is a weapon shop) }
	{  - Take a look at this... (to sell/repair/reload items in Inv) }
var
	RPM: RPGMenuPtr;
	Wares: GearPtr;
	N: Integer;
	Cost: LongInt;
begin
{$IFNDEF SDLMODE}
	ClrZone( ZONE_Menu );
{$ENDIF}

	{ Generate the list of stuff in the store. }
	Wares := CreateWaresList( GB , NPC , Stuff );

	repeat
		{ Start by allocating the menu. }
		{ This menu will use the same dimensions as the interaction }
		{ menu, since it branches from there. }
        {$IFDEF SDLMODE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	    SERV_GB := GB;
	    SERV_NPC := NPC;
	    SERV_PC := PC;
	    SERV_Customer := PC;
        {$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
        {$ENDIF}

		{ Add the basic options. }
		if Wares <> Nil then AddRPGMenuItem( RPM , 'Browse Wares' , 0 );

		{ Add options for each of the repair skills. }
		{ The repair skills are:   }
		{     15. Mecha Tech       }
		{     16. Medicine         }
		{     20. First Aid        }
		{     22. Bio Tech         }
		{     23. General Repair   }
		{     24. Cyber Tech       }
		for N := 1 to NumRepairSkills do begin
			{ A shopkeeper can only repair items for which he has the }
			{ required skills. }
			if NAttValue( NPC^.NA , NAG_Skill , RepairSkillIndex[N] ) > 0 then begin
				Cost := RepairAllCost( GB , RepairSkillIndex[N] );
				if Cost > 0 then begin
					AddRPGMenuItem( RPM , SAttValue( TEXT_MESSAGES , 'SERVICES_OSRSP' + BStr( N ) ) + ' [$' + BStr( ScalePrice( PC , NPC , Cost ) ) + ']' , N );
				end;
			end;
		end;

		{ If the shopkeeper knows Basic Repair, allow Reload Chars. }
		{ If the shopkeeper knows Mecha Repair, allow reload mecha. }
		if ( ReloadCharsCost( GB , PC , NPC ) > 0 ) and ( NAttValue( NPC^.NA , NAG_Skill , 23 ) > 0 ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ReloadCharsPrompt' ) + ' [$' + BStr( ReloadCharsCost( GB , PC , NPC ) ) + ']' , -4 );
		if ( ReloadMechaCost( GB , PC , NPC ) > 0 ) and ( NAttValue( NPC^.NA , NAG_Skill , NAS_MechaRepair ) > 0 ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ReloadMeksPrompt' ) + ' [$' + BStr( ReloadMechaCost( GB , PC , NPC ) ) + ']' , -3 );

		if AStringHasBString( Stuff, 'DELIVERY' ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ExpressDelivery' ) , -8 );

		{ If the shopkeeper knows Cybertech, allow the implantation }
		{ of modules. }
		if ( NAttValue( NPC^.NA , NAG_Skill , 24 ) > 0 ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_CybInstall' ) , -7 );

		AddRPGMenuItem( RPM , MsgString( 'SERVICES_SellStuff' ) , -5 );

        { Allow selling mecha if this is a mecha shop or a mechanic. }
		if AStringHasBString( Stuff, 'MECHA' ) or (NAttValue( NPC^.NA,NAG_Skill,NAS_MechaRepair) > 0) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_MechaService' ) , -2 );

		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Inventory' ) , -6 );

		AddRPGMenuItem( RPM , 'Exit Shop' , -1 );

		{ Display the trading stats. }
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @BasicServiceRedraw );
{$ELSE}
		DisplayGearInfo( PC );
		CMessage( '$' + BStr( NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_Clock , InfoHilight );
		{ Get a menu selection. }
		N := SelectMenu( RPM );
{$ENDIF}

		DisposeRPGMenu( RPM );

		if N > 0 then begin
			RepairAllFrontEnd( GB , PC , NPC , RepairSkillIndex[ N ] );
		end else if N = 0 then begin
			BrowseWares( GB, PC , NPC , Wares );
		end else if N = -2 then begin
			BrowseMecha( GB , PC , NPC );
		end else if N = -3 then begin
			DoReloadMecha( GB , PC , NPC );
		end else if N = -4 then begin
			DoReloadChars( GB , PC , NPC );
		end else if N = -5 then begin
			SellStuff( GB , PC , PC , NPC );
		end else if N = -6 then begin
			BackpackMenu( GB , PC , True );

{$IFNDEF SDLMODE}
			ClrZone( ZONE_InteractMsg );

			DisplayInteractStatus( GB , NPC , ReactionScore( GB^.Scene , PC , NPC ) , 1 );
{$ENDIF}

		end else if N = -7 then begin
			InstallCyberware( GB , PC , NPC );
		end else if N = -8 then begin
			ExpressDelivery( GB , PC , NPC );
		end;

	until N = -1;

	{ Restore the display. }
    {$IFNDEF SDLMODE}
	DisplayGearInfo( NPC , GB );
	DisplayGearInfo( PC , GB , ZONE_Menu );
    {$ENDIF}

	DisposeGear( Wares );
end;

Procedure OpenSchool( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
	{ Let the teaching commence! I was thinking, at first, of }
	{ including skill training as a sub-bit of the shopping procedure, }
	{ but abandoned this since I'd like a bit more control over }
	{ the process. }
	{ The going rate for training is $100 = 1XP. }
	{ This rate is not affected by Shopping skill, though a good }
	{ reaction score with the teacher can increase the number of XP }
	{ gained. }
const
	XPStep: Array [1..40] of Integer = (
		1,2,3,4,5, 6,7,8,9,10,
		12,15,20,25,50, 75,100,150,200,250,
		500,750,1000,1500,2000, 2500,3000,3500,4000,4500,
		5000,6000,7000,8000,9000, 10000,12500,15000,20000,25000
	);
	Knowledge_First_Bonus = 14;
	Knowledge_First_Penalty = 8;
	CostFactor = 250;
var
	SkillMenu,CostMenu: RPGMenuPtr;
	Skill,N: Integer;
	Cash: LongInt;
	DSLTemp: Boolean;
begin
{$IFDEF SDLMODE}
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;
{$ELSE}
	ClrZone( ZONE_Menu );
{$ENDIF}

	{ When using a school, can always learn directly. }
	DSLTemp := Direct_Skill_Learning;
	Direct_Skill_Learning := True;

	{ Step One: Create the skills menu. }
	SkillMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );

	while Stuff <> '' do begin
		N := ExtractValue( Stuff );
		if ( N >= 1 ) and ( N <= NumSkill ) then begin
			AddRPGMenuItem( SkillMenu , SkillMan[ N ].Name , N );
		end;
	end;
	RPMSortAlpha( SkillMenu );
	AddRPGMenuItem( SkillMenu , MsgString( 'SCHOOL_Exit' ) , -1 );

	repeat
		{ Display the trading stats. }
{$IFNDEF SDLMODE}
		DisplayGearInfo( PC );
		CMessage( '$' + BStr( NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_Clock , InfoHilight );
{$ENDIF}

		{ Get a selection from the menu. }
{$IFDEF SDLMODE}
		Skill := SelectMenu( SkillMenu , @ServiceRedraw );
{$ELSE}
		Skill := SelectMenu( SkillMenu );
{$ENDIF}

		{ If a skill was chosen, do the training. }
		if ( Skill >= 1 ) and ( Skill <= NumSkill ) then begin
			{ Create the CostMenu, and see how much the }
			{ player wants to spend. }
			CostMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
			Cash := NAttValue( PC^.NA , NAG_Experience , NAS_Credits );

			{ Add menu entries for each of the cost values }
			{ that the PC can afford. }
			for N := 1 to 40 do begin
				if XPStep[ N ] * CostFactor <= Cash then begin
					AddRPGMenuItem( CostMenu , '$' + BStr( XPStep[ N ] * CostFactor ) , N );
				end;
			end;

			{ Add the exit option, so that we'll never have }
			{ an empty menu. }
			AddRPGMenuItem( CostMenu , MsgString( 'SCHOOL_ExitCostSelector' ) , -1 );

{$IFDEF SDLMODE}
			Chat_Message := MsgString( 'SCHOOL_HowMuch' );
			N := SelectMenu( CostMenu , @ServiceRedraw );
{$ELSE}
			GameMsg( MsgString( 'SCHOOL_HowMuch' ) , ZONE_InteractMsg , InfoHiLight );
			N := SelectMenu( CostMenu );
{$ENDIF}
			DisposeRPGMenu( CostMenu );

			{ If CANCEL wasn't selected, take away the cash }
			{ and give the PC some experience. }
			if N <> -1 then begin
{$IFDEF SDLMODE}
				CHAT_Message := MsgString( 'SCHOOL_TeachingInProgress' );
{$ELSE}
				GameMsg( MsgString( 'SCHOOL_TeachingInProgress' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -( XPStep[ N ] * CostFactor ) );

				{ Calculate the number of XPs earned. }
				Cash := ( XPStep[ N ] * ( 400 + ReactionScore( GB^.Scene , PC , NPC ) ) ) div 400;

				{ Add bonus for high Knowledge stat, }
				{ or penalty for low Knowledge stat. }
				if CStat( PC , STAT_Knowledge ) >= Knowledge_First_Bonus then begin
					Cash := ( Cash * ( 100 + ( CStat( PC , STAT_Knowledge ) - Knowledge_First_Bonus + 1 ) * 5 ) ) div 100;
				end else if CStat( PC , STAT_Knowledge ) <= Knowledge_First_Penalty then begin
					Cash := ( Cash * ( 100 - ( Knowledge_First_Penalty - CStat( PC , STAT_Knowledge ) + 1 ) * 10 ) ) div 100;
					if Cash < 1 then Cash := 1;
				end;

				if DoleSkillExperience( PC , Skill , Cash ) then begin
					DialogMsg( MsgString( 'SCHOOL_Learn' + BStr( Random( 5 ) + 1 ) ) );
				end;

				{ Training takes time. }
				while N > 0 do begin
					QuickTime( GB , 100 + Random( 100 ) );
					Dec( N );
				end;
			end;
		end;
	until Skill = -1;

	{ Restore the Direct_Skill_Learning setting. }
	Direct_Skill_Learning := DSLTemp;

	DisposeRPGMenu( SkillMenu );
end;

Procedure FillExpressMenu( GB: GameBoardPtr; RPM: RPGMenuPtr );
	{ Fill the menu with all the meks that the PC has in places }
	{ other than the current scene. This procedure assumes that }
var
	Adv,Scene,Mek: GearPtr;
begin
	{ Error check - we need an adventure for this to work. }
	if GB^.Scene = Nil then Exit;

	Adv := FindRoot( GB^.Scene );
	Scene := Adv^.SubCom;

	while Scene <> Nil do begin
		{ If this isn't the current scene, search it for bits. }
		if Scene <> GB^.Scene then begin
			Mek := Scene^.InvCom;

			while Mek <> Nil do begin
				if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
					AddRPGMenuItem( RPM , FullGearName( Mek ) + ' (' + GearName( Scene ) + ')' , FindGearIndex( Adv , Mek ) );
				end;
				Mek := Mek^.Next;
			end;
		end;

		Scene := Scene^.Next;
	end;
end;

Function DeliveryCost( Mek: GearPtr ): LongInt;
	{ Return the cost to deliver this mecha from one location }
	{ to the next. Cost is determined by mass. }
var
	C,T: LongInt;
begin
	{ Base value is the mass of the mek. }
	C := GearMass( Mek );

	{ This gets multiplied upwards as the mass of the mecha increases. }
	for t := 1 to Mek^.Scale do C := C * 5;

	{ Return the finished cost. }
	DeliveryCost := C;
end;

Procedure ExpressDelivery( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The PC needs some mecha delivered from out of town. }
	{ Better search the entire adventure and find every mecha }
	{ belonging to the PC. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	Mek: GearPtr;
	Cost: LongInt;
begin
{$IFDEF SDLMODE}
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;
    SERV_Customer := PC;
    SERV_Info := FindRoot( GB^.Scene );
{$ELSE}
	ClrZone( ZONE_Menu );
{$ENDIF}

	repeat
        {$IFDEF SDLMODE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
        {$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
        {$ENDIF}
		FillExpressMenu( GB , RPM );
		RPMSortAlpha( RPM );
		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @BrowseTreeRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			Mek := LocateGearByNumber( FindRoot( GB^.Scene ) , N );
			if Mek <> Nil then begin
				Cost := ScalePrice( PC , NPC , DeliveryCost( Mek ) );
				RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
				AddRPGMenuItem( RPM , ReplaceHash( MsgString( 'SERVICES_MoveYes' ) , GearName( Mek ) ) , 1 );
				AddRPGMenuItem( RPM , MsgString( 'SERVICES_MoveNo' ) ,  -1 );

{$IFDEF SDLMODE}
                SERV_Info := Mek;
				Chat_Message := ReplaceHash( MsgString( 'SERVICES_MovePrompt' + BStr( Random( 3 ) + 1 ) ) , BStr( Cost ) );
				N := SelectMenu( RPM , @FocusOnOneRedraw );
{$ELSE}
				GameMsg( ReplaceHash( MsgString( 'SERVICES_MovePrompt' + BStr( Random( 3 ) + 1 ) ) , BStr( Cost ) ) , ZONE_InteractMsg , InfoHiLight );
				N := SelectMenu( RPM );
{$ENDIF}
				DisposeRPGMenu( RPM );
				if N = 1 then begin
					{ The PC wants to move this mecha. }
					if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
						AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );
						DelinkGear( Mek^.Parent^.InvCom , Mek );
						DeployMek( GB , Mek , False );
{$IFDEF SDLMODE}
						Chat_Message := MsgString( 'SERVICES_MoveDone' + BStr( Random( 3 ) + 1 ) );
{$ELSE}
						GameMsg( MsgString( 'SERVICES_MoveDone' + BStr( Random( 3 ) + 1 ) ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
					end else begin
{$IFDEF SDLMODE}
						Chat_Message := MsgString( 'SERVICES_MoveNoCash' );
{$ELSE}
						GameMsg( MsgString( 'SERVICES_MoveNoCash' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
					end;
				end;
				N := 0;
			end;
		end;

	until N = -1;
end;

Procedure ShuttleService( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The PC will be able to travel to a number of different cities. }
	function FindLocalGate( World: GearPtr; SceneID: Integer ): GearPtr;
		{ This is a nice simple non-recursive list search, }
		{ since the gate should be at root level. }
	var
		Part,TheGate: GearPtr;
	begin
		Part := World^.InvCom;
		TheGate := Nil;
		while ( Part <> Nil ) and ( TheGate = Nil ) do begin
			if ( Part^.G = GG_MetaTerrain ) and ( Part^.Stat[ STAT_Destination ] = SceneID ) then begin
				TheGate := Part;
			end;
			Part := Part^.Next;
		end;
		FindLocalGate := TheGate;
	end;
	Function WorldMapRange( World: GearPtr; X0,Y0,X1,Y1: Integer ): Integer;
	begin
		WorldMapRange := Range( X0 , Y0 , X1 , Y1 );
	end;
	Function TravelCost( World,Entrance: GearPtr; X0 , Y0: Integer ): LongInt;
		{ Calculate the travel cost from the original location to the }
		{ destination city. }
	var
		X1,Y1: Integer;
	begin
		if Entrance = Nil then begin
			TravelCost := 50000;
		end else begin
			{ Determine the X,Y coords of the destination on the world map. }
			{ If the map is a wrapping-type map, maybe modify for the shortest }
			{ possible distance. }
			X1 := NAttValue( Entrance^.NA , NAG_Location , NAS_X );
			Y1 := NAttValue( Entrance^.NA , NAG_Location , NAS_Y );
			TravelCost := Range( X1 , Y1 , X0 , Y0 ) * 5 + 25;
		end;
	end;
const
	MaxShuttleRange = 15;
var
	World,City,Fac,Entrance: GearPtr;
	X0,Y0,X1,Y1,N,Cost: LongInt;
	RPM: RPGMenuPtr;
begin
{$IFDEF SDLMODE}
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;
{$ELSE}
	ClrZone( ZONE_Menu );
{$ENDIF}

	{ Create a shopping list of the available scenes. These must not be }
	{ enemies of the current scene, must be located on the same world, }
	{ must be within a certain range, and must have "DESTINATION" in their }
	{ TYPE string attribute. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
	AttachMenuDesc( RPM , ZONE_InteractMsg );
    { KLUDGE: Assume that the world map is Scene 1. This is bad, I know, but }
    { given that the game is umpteen years old and no alternate campaigns have }
    { been made for the engine, it should do just fine. Programmers of later }
    { generations, I leave this problem to you. }
	World := FindActualScene( GB , 1 );
	Fac := SeekFaction( GB^.Scene , GetFactionID( GB^.Scene ) );

	Entrance := FindLocalGate( World , GB^.Scene^.S );
	if Entrance <> Nil then begin
		X0 := NAttValue( Entrance^.NA , NAG_Location , NAS_X );
		Y0 := NAttValue( Entrance^.NA , NAG_Location , NAS_Y );
	end else begin
		X0 := 1;
		Y0 := 1;
	end;

	Entrance := World^.InvCom;
    while Entrance <> Nil do begin
        if ( Entrance^.G = GG_MetaTerrain ) and ( Entrance^.Stat[ STAT_Destination ] <> 0 ) then begin
			X1 := NAttValue( Entrance^.NA , NAG_Location , NAS_X );
			Y1 := NAttValue( Entrance^.NA , NAG_Location , NAS_Y );
            City := FindActualScene( GB, Entrance^.Stat[ STAT_Destination ] );
            if (City <> Nil) and ( City <> GB^.Scene ) and ( ( Fac = Nil ) or ( NAttValue( Fac^.NA , NAG_FactionScore , GetFactionID( City ) ) >= 0 ) ) then begin
			{ Do the range check. }
			    if AStringHasBString( SAttValue( City^.SA , 'TYPE' ) , 'DESTINATION' ) and (range(X0,y0,x1,y1) <= MaxShuttleRange) then begin
				    AddRPGMenuItem( RPM , GearName( City ) + ' ($' + BStr( TravelCost( World, Entrance , X0 , Y0 ) ) + ')' , City^.S , SAttValue( City^.SA , 'DESC' ) );
			    end;
		    end;

        end;
        Entrance := Entrance^.Next;
    end;

	{ Sort the menu. }
	RPMSortAlpha( RPM );
	AlphaKeyMenu( RPM );

	{ Add the cancel option. }
	AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

	repeat
		{ Perform the menu selection. }
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @ServiceRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}

		{ If a destination was selected, see if it's possible to go there, deduct the PC's }
		{ money, etc. }
		if N > -1 then begin
			Entrance := FindLocalGate( World , N );
			Cost := TravelCost( World , Entrance , X0 , Y0 );
			if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
				GB^.QuitTheGame := True;
				GB^.ReturnCode := N;
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );
				QuickTime( GB , Cost * 120 );
			end else begin
				{ Not enough cash to buy... }
{$IFDEF SDLMODE}
				Chat_Message := MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) );
{$ELSE}
				GameMsg( MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
			end;

		end;
	until GB^.QuitTheGame or ( N = -1 );

	DisposeRPGMenu( RPM );

end;

Procedure OpenShuttle( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ Allow express delivery and shuttle service. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
{$IFDEF SDLMODE}
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;
	SERV_Info := PC;
{$ELSE}
	ClrZone( ZONE_Menu );
{$ENDIF}

	repeat
		{ Start by allocating the menu. }
		{ This menu will use the same dimensions as the interaction }
		{ menu, since it branches from there. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );

		AddRPGMenuItem( RPM , MsgString( 'SERVICES_ShuttleService' ) , 1 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_ExpressDelivery' ) , -8 );

		AddRPGMenuItem( RPM , MsgString( 'SERVICES_SellStuff' ) , -5 );
		AddRPGMenuItem( RPM , 'Exit Shop' , -1 );

{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @ServiceRedraw );
{$ELSE}
		DisplayGearInfo( PC );
		CMessage( '$' + BStr( NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_Clock , InfoHilight );
		{ Get a menu selection. }
		N := SelectMenu( RPM );
{$ENDIF}

		DisposeRPGMenu( RPM );

		if N = -8 then begin
			ExpressDelivery( GB , PC , NPC );
		end else if N = 1 then begin
			ShuttleService( GB , PC , NPC );
            if gb^.QuitTheGame then N := -1;
		end;

	until N = -1;

	{ Restore the display. }
    {$IFNDEF SDLMODE}
	DisplayGearInfo( NPC , GB );
	DisplayGearInfo( PC , GB , ZONE_Menu );
    {$ENDIF}
end;


{$IFDEF SDLMODE}
initialization
	SERV_GB := Nil;
	SERV_NPC := Nil;
{$ENDIF}

end.
