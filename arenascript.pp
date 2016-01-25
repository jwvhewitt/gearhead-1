unit arenascript;
	{ This unit holds the scripting language for GearHead. }
	{ It's pretty similar to the scripts developed for DeadCold. }
	{ Basically, certain game events will add a trigger to the }
	{ list. In the main combat procedure, if there are any pending }
	{ triggers, they will be checked against the events list to }
	{ see if anything happens. }

	{ Both the triggers and the event scripts will be stored as }
	{ normal string attributes. }

	{ This unit also handles conversations with NPCs, since those }
	{ are written using the scripting language and may use any }
	{ commands available there + a few special commands. }

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
uses gears,locale,sdlmenus,sdl;
{$ELSE}
uses gears,locale,conmenus;
{$ENDIF}

const
	NAG_ScriptVar = 0;
	Max_Plots_Per_Story = 5;

var
	{ This gear pointer will be created if a dynamic scene is requested. }
	SCRIPT_DynamicEncounter: GearPtr;

	{ **************************************** }
	{ ***  INTERACTION  GLOBAL  VARIABLES  *** }
	{ **************************************** }
	{ These variables hold information that may be needed anywhere }
	{ while interaction is taking place, but are undefined if }
	{ interaction is not taking place. }
	{ IntMenu should let procedures know whether or not interaction }
	{ is currently happening or not- if IntMenu <> Nil, we're in the }
	{ middle of a conversation and all other interaction variables }
	{ should have good values. }
	IntMenu: RPGMenuPtr;	{ Interaction Menu }
	I_PC,I_NPC: GearPtr;	{ Pointers to the PC & NPC Chara gears }
	I_Endurance: Integer;	{ How much of the PC's crap the NPC is }
		{ willing to take. When it reaches 0, the NPC says goodbye. }
	I_Rumors: SAttPtr;	{ List of rumors. }

	Grabbed_Gear: GearPtr;	{ This gear can be acted upon by }
				{ generic commands. }

	lancemate_tactics_persona: GearPtr;	{ Persona for setting lancemate tactics. }


{$IFDEF SDLMODE}
Procedure MechaSelectionMenu( GB: GameBoardPtr; LList,PC: GearPtr; Z: TSDL_Rect );
{$ELSE}
Procedure MechaSelectionMenu( LList,PC: GearPtr; Z: Integer );
{$ENDIF}
Procedure BrowseMemoType( GB: GameBoardPtr; Tag: String );

Function Calculate_Threat_Points( Level,Percent: Integer ): LongInt;

Function ScriptValue( var Event: String; GB: GameBoardPtr; Scene: GearPtr ): LongInt;

Function AS_GetString( Source: GearPtr; Key: String ): String;
Function ScriptMessage( msg_label: String; GB: GameBoardPtr; Source: GearPtr ): String;

Procedure InvokeEvent( Event: String; GB: GameBoardPtr; Source: GearPtr; var Trigger: String );

Procedure AddLancemate( GB: GameBoardPtr; NPC: GearPtr );
Procedure RemoveLancemate( GB: GameBoardPtr; NPC: GearPtr );

Procedure HandleInteract( GB: GameBoardPtr; PC,NPC,Interact: GearPtr );
Function TriggerGearScript( GB: GameBoardPtr; Source: GearPtr; var Trigger: String ): Boolean;
Function CheckTriggerAlongPath( var T: String; GB: GameBoardPtr; Plot: GearPtr; CheckAll: Boolean ): Boolean;
Procedure HandleTriggers( GB: GameBoardPtr );


implementation

{$IFDEF SDLMODE}
uses action,arenacfe,ability,damage,gearutil,ghchars,ghparser,ghmodule,
     ghprop,ghweapon,grabgear,interact,menugear,playwright,rpgdice,
     services,texutil,ui4gh,wmonster,sdlgfx,sdlinfo,sdlmap,backpack;
{$ELSE}
uses action,arenacfe,ability,damage,gearutil,ghchars,ghparser,ghmodule,
     ghprop,ghweapon,grabgear,interact,menugear,playwright,rpgdice,backpack,
     services,texutil,ui4gh,wmonster,congfx,coninfo,conmap,context;
{$ENDIF}

const
	CMD_Chat = -2;
	CMD_Join = -3;
	CMD_Quit = -4;
	Debug_On: Boolean = False;

var
	script_macros,value_macros: SAttPtr;
{$IFDEF SDLMODE}
	ASRD_InfoGear: GearPtr;
	ASRD_GameBoard: GameBoardPtr;
	ASRD_MemoMessage: String;


Procedure ArenaScriptReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if ASRD_GameBoard <> Nil then QuickCombatDisplay( ASRD_GameBoard );
	DisplayGearInfo( ASRD_InfoGear , ASRD_GameBoard );
end;

Procedure MemoPageReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if ASRD_GameBoard <> Nil then QuickCombatDisplay( ASRD_GameBoard );
	DisplayGearInfo( ASRD_InfoGear , ASRD_GameBoard );
	SetupMemoDisplay;
	NFGameMsg( ASRD_MemoMessage , ZONE_MemoText , InfoGreen );
end;
{$ENDIF}

{$IFDEF SDLMODE}
Procedure MechaSelectionMenu( GB: GameBoardPtr; LList,PC: GearPtr; Z: TSDL_Rect );
{$ELSE}
Procedure MechaSelectionMenu( LList,PC: GearPtr; Z: Integer );
{$ENDIF}
	{ Create a menu by which the player can select a mecha to use. }
var
	RPM: RPGMenuPtr;
	msg: String;
	M: GearPtr;
	N: Integer;
begin
	{ Step one - Create the menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , Z );
	RPM^.Mode := RPMNoCancel;
	M := LList;
	N := 1;
	while M <> Nil do begin
		if ( M^.G = GG_Mecha ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then begin
			msg := FullGearName( M );
			AddRPGMenuItem( RPM , msg , N );
		end;

		Inc( N );
		M := M^.Next;
	end;

	if RPM^.NumItem <> 0 then begin
{$IFDEF SDLMODE}
		ASRD_GameBoard := GB;
		ASRD_InfoGear := PC;
		N := SelectMenu( RPM , @ArenaScriptReDraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		if N <> -1 then begin
			{ Find the gear that was selected, and set its }
			{ pilot attribute. }
			M := RetrieveGearSib( LList , N );
			AssociatePilotMek( LList , PC , M );

			{ Print an informative message for the user. }
			DialogMsg( MsgString( 'SELECTMECHA_RESULT1' ) + GearName( M ) + MsgString( 'SELECTMECHA_RESULT2' ) );
		end;

	end else begin
		DialogMsg( MsgString( 'SELECTMECHA_NoMeks' ) );
	end;

	DisposeRPGMenu( RPM );
end;

Procedure BrowseMemoType( GB: GameBoardPtr; Tag: String );
	{ Create a list, then browse the memos based upon this }
	{ TAG type. Possible options are MEMO, NEWS, and EMAIL. }
var
	MemoList,M: SAttPtr;

	Procedure CreateMemoList( Part: GearPtr; Tag: String );
		{ Look through all gears in the structure recursively, }
		{ looking for MEMO string attributes to store in our list. }
	var
		msg: String;
	begin
		while Part <> Nil do begin
			msg := SAttValue( Part^.SA , Tag );
			if msg <> '' then StoreSAtt( MemoList , msg );
			CreateMemoList( Part^.SubCom , Tag );
			CreateMemoList( Part^.InvCom , Tag );
			Part := Part^.Next;
		end;
	end;

	Procedure BrowseList;
		{ Actually browse the created list. }
	var
		RPM: RPGMenuPtr;
		N,D: Integer;
	begin
		if MemoList <> Nil then begin
			SetupMemoDisplay;
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
			AddRPGMenuItem( RPM , MsgString( 'MEMO_Next' ) , 1 );
			AddRPGMenuItem( RPM , MsgString( 'MEMO_Prev' ) , 2 );
			AddRPGMenuKey( RPM , KeyMap[ KMC_East ].KCode , 1 );
			AddRPGMenuKey( RPM , KeyMap[ KMC_West ].KCode , 2 );
			AlphaKeyMenu( RPM );
			RPM^.Mode := RPMNoCleanup;
			N := 1;

			repeat
				M := RetrieveSAtt( MemoList , N );
{$IFDEF SDLMODE}
				ASRD_InfoGear := Nil;
				ASRD_GameBoard := GB;
				ASRD_MemoMessage := M^.Info;
				D := SelectMenu( RPM , @MemoPageRedraw );
{$ELSE}
				GameMsg( M^.Info , ZONE_MemoText , InfoGreen );
				D := SelectMenu( RPM );
{$ENDIF}

				if D = 1 then begin
					N := N + 1;
					if N > NumSAtts( MemoList ) then N := 1;
				end else if D = 2 then begin
					N := N - 1;
					if N < 1 then N := NumSAtts( MemoList );
				end;
			until D = -1;

			DisposeSAtt( MemoList );
			DisposeRPGMenu( RPM );
		end;

	end;
begin
	{ Error check first - we need the GB and the scene for this. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;
	MemoList := Nil;
	CreateMemoList( FindRoot( GB^.Scene ) , Tag );
	if MemoList = Nil then StoreSAtt( MemoList , ReplaceHash( MsgString( 'MEMO_None' ) , LowerCase( Tag ) ) );
	BrowseList;
end;

Function YesNoMenu( GB: GameBoardPtr; Prompt,YesMsg,NoMsg: String ): Boolean;
	{ This will open up a small window in the middle of the map }
	{ display, then prompt the user for a choice. }
	{ Return TRUE if the "yes" option was selected, or FALSE if }
	{ the "no" option was selected. }
	{ This function performs no screen cleanup. }
var
	rpm: RPGMenuPtr;
	N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_YesNoMenu );
	AddRPGMenuItem( RPM , YesMsg , 1 );
	AddRPGMenuItem( RPM , NoMsg , -1 );
	RPM^.Mode := RPMNoCancel;

{$IFDEF SDLMODE}
	ASRD_InfoGear := Nil;
	ASRD_GameBoard := GB;
	ASRD_MemoMessage := Prompt;
	N := SelectMenu( RPM , @MemoPageRedraw );
{$ELSE}
	SetupYesNoDisplay;
	GameMsg( Prompt , ZONE_YesNoPrompt , InfoGreen );
	N := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );

	{ Do cleanup before branching. }
	DisplayMap( GB );

	YesNoMenu := N <> -1;
end;

Function SceneName( GB: GameBoardPtr; ID: Integer ): String;
	{ Find the name of the scene with the given ID. If no such }
	{ scene can be found, return a value that should let the player }
	{ know an error has been commited. }
var
	Part: GearPtr;
begin
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then begin
		SceneName := 'XXX';
	end else begin
		{ Look for the scene along the subcomponents of the }
		{ adventure. This is to make sure we don't accidentally }
		{ pick a dynamic scene with the right ID. }
		Part := FindActualScene( GB , ID );
		SceneName := GearName( Part );
	end;
end;

Function FindRandomMekID( GB: GameBoardPtr; Team: Integer ): LongInt;
	{ Locate a random mek belonging to TEAM. }
var
	NumMeks,N,T,MID: Integer;
	Mek: GearPtr;
begin
	{ Start out by finding out how many meks belong to this team }
	{ anyways. }
	NumMeks := NumOperationalMasters( GB , Team );
	MID := 0;

	{ If there are actually members on this team, select one randomly. }
	if NumMeks > 0 then begin
		{ Decide what mek to take, and initialize the }
		{ search variables. }
		N := Random( NumMeks ) + 1;
		T := 0;
		Mek := GB^.Meks;

		while Mek <> Nil do begin
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) and GearOperational( Mek ) then begin
				Inc( T );
				if T = N then MID := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID );
			end;
			Mek := Mek^.Next;
		end;
	end;

	FindRandomMekID := MID;
end;

Function FindRandomPilotID( GB: GameBoardPtr; Team: Integer ): LongInt;
	{ Locate a random pilot belonging to TEAM. }
var
	NumMeks,N,T,MID: Integer;
	Mek,P: GearPtr;
begin
	{ Start out by finding out how many meks belong to this team }
	{ anyways. }
	NumMeks := NumOperationalMasters( GB , Team );
	MID := 0;

	{ If there are actually members on this team, select one randomly. }
	if NumMeks > 0 then begin
		{ Decide what mek to take, and initialize the }
		{ search variables. }
		N := Random( NumMeks ) + 1;
		T := 0;
		Mek := GB^.Meks;

		while Mek <> Nil do begin
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) and GearOperational( Mek ) then begin
				Inc( T );
				if T = N then begin
					P := LocatePilot( Mek );
					if P <> Nil then MID := NAttValue( P^.NA , NAG_EpisodeData , NAS_UID );
				end;
			end;
			Mek := Mek^.Next;
		end;
	end;

	FindRandomPilotID := MID;
end;

Function FindRootUID( GB: GameBoardPtr; ID: LongInt ): LongInt;
	{ Find the ID of the root of the specified gear. }
var
	Part: GearPtr;
begin
	{ First, find the part being pointed to. }
	Part := LocateMekByUID( GB , ID );

	{ Locate its root. }
	if Part <> Nil then begin
		Part := FindRoot( Part );

		{ Return the root's UID. }
		FindRootUID := NAttValue( Part^.NA , NAG_EpisodeData , NAS_UID );

	{ If there was an error locating the part, return 0. }
	end else FindRootUID := 0;
end;

Function FindFacMem( ID: Integer; GB: GameBoardPtr; Scene: GearPtr ): Integer;
	{ This function will return how many NPCs belong to the }
	{ specified faction. }
	Function WorkHorse( Part: GearPtr ): Integer;
		{ This is the function which does all the real work. }
	var
		it: Integer;
	begin
		it := 0;
		while Part <> Nil do begin
			if ( Part^.G = GG_Character ) and ( NAttValue( Part^.NA , NAG_Personal , NAS_FactionID ) = ID ) then begin
				Inc( It );
			end;
			if Part^.SubCom <> Nil then it := it + WorkHorse( Part^.SubCom );
			if Part^.InvCom <> Nil then it := it + WorkHorse( Part^.InvCom );
			Part := Part^.Next;
		end;
		WorkHorse := it;
	end;
begin
	Scene := FindRoot( Scene );
	FindFacMem := WorkHorse( Scene ) + WorkHorse( GB^.Meks );
end;

Function FindFacScene( ID: Integer; Scene: GearPtr ): Integer;
	{ This function will return how many Scenes belong to the }
	{ specified faction. }
	Function WorkHorse( Part: GearPtr ): Integer;
		{ This is the function which does all the real work. }
	var
		it: Integer;
	begin
		it := 0;
		while Part <> Nil do begin
			if ( Part^.G = GG_Scene ) and ( NAttValue( Part^.NA , NAG_Personal , NAS_FactionID ) = ID ) then begin
				Inc( It );
			end;
			if Part^.SubCom <> Nil then it := it + WorkHorse( Part^.SubCom );
			if Part^.InvCom <> Nil then it := it + WorkHorse( Part^.InvCom );
			Part := Part^.Next;
		end;
		WorkHorse := it;
	end;
begin
	Scene := FindRoot( Scene );
	FindFacScene := WorkHorse( Scene );
end;

Function NumPCMeks( GB: GameBoardPtr ): Integer;
	{ Return the number of mecha belonging to team 1. }
	{ It doesn't matter if they're on the board or not, nor whether or }
	{ not they are destroyed. }
var
	M: GearPtr;
	N: Integer;
begin
	N := 0;
	if GB <> Nil then begin
		M := GB^.Meks;
		while M <> Nil do begin
			{ If this is a mecha, and it belongs to team 1, }
			{ increment the counter. }
			if ( M^.G = GG_Mecha ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then Inc( N );
			M := M^.Next;
		end;
	end;
	NumPCMeks := N;
end;

Function FindPCScale( GB: GameBoardPtr ): Integer;
	{ Return the scale of the PC. Generally this will be 0 if the }
	{ PC is on foot, 1 or 2 if the PC is in a mecha, unless the PC }
	{ is a storm giant or a zentradi in which case anything goes. }
var
	PC: GearPtr;
begin
	PC := GG_LocatePC( GB );
	if PC <> Nil then begin
		FindPCScale := FindRoot( PC )^.Scale;
	end else begin
		FindPCScale := 0;
	end;
end;

Function FindHostileFactions( GB: GameBoardPtr; Source: GearPtr ): Integer;
	{ COunt the number of hostile factions present in this adventure. }
	{ A hostile faction is defined as one which has the MILITARY type, }
	{ which isn't INACTIVE, and which has ACTIVE MILITARY enemies. }
	Function IsMilitaryFaction( Fac: GearPtr ): Boolean;
		{ The faction is MILITARY if it says so in its TYPE string. }
	begin
		IsMilitaryFaction := AStringHasBString( SAttValue( Fac^.SA , 'TYPE' ) , 'MILITARY' );
	end;

	Function MeetsTheRequirements( Fac: GearPtr ): Boolean;
		{ Return TRUE if the provided faction meets all the }
		{ requirements listed above, or FALSE otherwise. }
	var
		it: Boolean;
		F2: GearPtr;
		NA: NAttPtr;
		Enemies: Integer;
	begin
		it := IsMilitaryFaction( Fac ) and not FactionIsInactive( Fac );
		if it then begin
			{ Check through each of the faction's relations }
			{ to see if it has any active, military enemies. }
			NA := Fac^.NA;
			Enemies := 0;

			while NA <> Nil do begin
				{ If this numeric attribute is a faction score, }
				{ and it's an enemy, check the state of that enemy. }
				if ( NA^.G = NAG_FactionScore ) and ( NA^.V < 0 ) then begin
					F2 := GG_LocateFaction( NA^.S , GB , Source );

					if F2 <> Nil then begin
						if IsMilitaryFaction( F2 ) and not FactionIsInactive( F2 ) then Inc( Enemies );
					end;
				end;

				NA := NA^.Next;
			end;

			{ If there are no active, military enemies then }
			{ this faction doesn't count as currently hostile. }
			if Enemies = 0 then it := False;
		end;
		MeetsTheRequirements := it;
	end;
	Function CheckAlongPath( Part: GearPtr ): Integer;
		{ Check along this path of sibling gears, counting up }
		{ all the factions that meet our requirements. }
	var
		it: Integer;
	begin
		{ Initialize count to 0. }
		it := 0;

		while Part <> Nil do begin
			if ( Part^.G = GG_Faction ) and MeetsTheRequirements( Part ) then inc( it );

			it := it + CheckAlongPath( Part^.SubCom );
			it := it + CheckAlongPath( Part^.InvCom );

			Part := Part^.Next;
		end;
		CheckAlongPath := it;
	end;
begin
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		FindHostileFactions := CheckAlongPath( FindRoot( GB^.Scene ) );
	end else begin
		FindHostileFactions := CheckAlongPath( FindRoot( Source ) );
	end;
end;

Function Calculate_Threat_Points( Level,Percent: Integer ): LongInt;
	{ Calculate an appropriate threat value, based upon the modified }
	{ encounter level ( usually PCRep + d50 ) and the % scale factor. }
var
	it: LongInt;
begin
	if Level < 0 then Level := 0
	else if Level > 300 then Level := 300;

	{ For low level encounters, use a linear equation. }
	if Level < 42 then begin
		it := 50 + Level * 125;
	{ Higher on, switch to the quadratic. }
	{ This equation provides similar values to the standard values }
	{ previously used in the combat encounters. }
	end else begin
		it := 25 * Level * Level - 1850 * Level + 39000;
	end;

	{ Modify for the percent requested. }
	it := it * Percent;

	Calculate_Threat_Points := it;
end;

Function Calculate_Reward_Value( GB: GameBoardPtr; ThreatLevel,Percent: LongInt ): LongInt;
	{ Return an appropriate reward value, based on the listed }
	{ threat level and percent scale. }
var
	RV: LongInt;
	PC: GearPtr;
begin
	{ Calculate the base reward value. }
	RV := ThreatLevel div 100 * Percent div 100;

	{ Modify this for the PC's talents. }
	if GB <> Nil then begin
		PC := GG_LocatePC( GB );
		if HasTalent( PC , NAS_BusinessSense ) then RV := ( RV * 5 ) div 4;
	end;

	Calculate_Reward_Value := RV;
end;

Procedure InitiateMacro( var Event: String; ProtoMacro: String );
	{ Initialize the provided macro, and stick it to the head of }
	{ event. To initialize just go through it word by word, replacing }
	{ all question marks with words taken from EVENT. }
	function NeededParameters( cmd: String ): Integer;
		{ Return the number of parameters needed by this function. }
	const
		NumStandardFunctions = 15;
		StdFunName: Array [1..NumStandardFunctions] of string = (
			'-', 'GNATT', 'GSTAT', 'FACMEM', 'FACSCENE',
			'SKROLL', 'THREAT', 'REWARD', 'ESCENE', 'RANGE',
			'FXPNEEDED','WMTHREAT','*','MAPTILE','PCSKILLVAL'
		);
		StdFunParam: Array [1..NumStandardFunctions] of byte = (
			1,2,1,1,1,1,2,2,1,2,
			1,1,2,2,1
		);
	var
		it,T: Integer;
		Mac: String;
	begin
		it := 0;
		CMD := UpCase( CMD );
		{ If a hardwired function, look up the number of parameters }
		{ from the above list. }
		for t := 1 to NumStandardFunctions do begin 
			if CMD = StdFunName[ t ] then it := StdFunParam[ t ];
		end;

		{ If a macro function, derive the number of parameters }
		{ from the number of ?s in the macro. }
		if it = 0 then begin
			Mac := SAttValue( Value_Macros , Cmd );
			if Mac <> '' then begin
				for t := 1 to Length( Mac ) do begin
					if Mac[ T ] = '?' then Inc( it );
				end;
			end;
		end;
		NeededParameters := it;
	end;
	function  GetSwapText: String;
		{ Grab the swap text from EVENT. If it's a function }
		{ that we just grabbed, better grab the parameters as }
		{ well. Oh, bother... }
	var
		it,cmd: String;
		N: Integer;
	begin
		{ Grab the beginning of the swap text. }
		it := ExtractWord( Event );

		{ Check to see if it's a function. Get rid of the - first }
		{ since it'll screw up our check. }
		cmd := it;
		if ( Length( cmd ) > 1 ) and ( cmd[1] = '-' ) then DeleteFirstChar( cmd );
		N := NeededParameters( cmd );
		While N > 0 do begin
			it := it + ' ' + GetSwapText();
			Dec( N );
		end;
		GetSwapText := it;
	end;
var
	Cmd,NewMacro,LastWord: String;
begin
	NewMacro := '';
	LastWord := '';

	while ProtoMacro <> '' do begin
		cmd := ExtractWord( ProtoMacro );
		if cmd = '?' then begin
			LastWord := GetSwapText;
			cmd := LastWord;
		end else if cmd = '!' then begin
			cmd := LastWord;
		end;
		NewMacro := NewMacro + ' ' + cmd;
	end;

	Event := NewMacro + ' ' + Event;
end;

Function SV_Range( GB: GameBoardPtr; UID1,UID2: LongInt ): Integer;
	{ Locate the two gears pointed to by the UIDs, then calculate }
	{ the range between them. If one or both are NIL, or if one or }
	{ both are off the map, return 0. }
var
	M1,M2: GearPtr;
begin
	{ Error check. }
	if GB = Nil then Exit( 0 );

	M1 := LocateMekByUID( GB , UID1 );
	M2 := LocateMekByUID( GB , UID2 );

	if ( M1 <> Nil ) and OnTheMap( M1 ) and ( M2 <> Nil ) and OnTheMap( M2 ) then begin
		SV_Range := Range( GB , M1 , M2 );
	end else begin
		SV_Range := 0;
	end;
end;

Function SV_PCSkillVal( GB: GameBoardPtr; Skill: Integer ): Integer;
	{ Return the PC's base skill value. This used to be easy until those }
	{ stupid lancemates came along... Check all PCs and lancemates, and }
	{ return the highest value. }
var
	M,PC: GearPtr;
	HiSkill,T: Integer;
begin
	{ Error check. }
	if GB = Nil then Exit( 0 );

	M := GB^.Meks;
	HiSkill := 0;
	while M <> Nil do begin
		T := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if GearActive( M ) and ( ( T = NAV_DefPlayerTeam ) or ( T = NAV_LancemateTeam ) ) then begin
			PC := LocatePilot( M );
			if PC <> Nil then begin
				T := NAttValue( PC^.NA , NAG_Skill , SKill );
				if T > HiSkill then HiSkill := T;
			end;
		end;

		M := M^.Next;
	end;

	SV_PCSkillVal := HiSkill;
end;

Function ScriptValue( var Event: String; GB: GameBoardPtr; Scene: GearPtr ): LongInt;
	{ Normally, numerical values will be stored as constants. }
	{ Sometimes we may want to do algebra, or use the result of }
	{ scenario variables as the parameters for commands. That's }
	{ what this function is for. }
var
	Old_Grabbed_Gear,PC: GearPtr;
	VCode,VC2: LongInt;
	SV: LongInt;
	SMsg,S2: String;
begin
	{ Save the grabbed gear, to restore it later. }
	Old_Grabbed_Gear := Grabbed_Gear;

	SMsg := UpCase(ExtractWord( Event ));
	SV := 0;

	{ If the first character is one of the value commands, }
	{ process the string as appropriate. }
	if SAttValue( Value_Macros , SMsg ) <> '' then begin
		{ Install the macro, then re-call this procedure to get }
		{ the results. }
		InitiateMacro( Event , SAttValue( Value_Macros , SMsg ) );
		SV := ScriptValue( Event , gb , scene );

	end else if ( SMsg = 'GNATT' ) then begin
		{ Get a Numeric Attribute from the currently grabbed gear. }
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		if Grabbed_Gear <> Nil then begin
			SV := NAttValue( Grabbed_Gear^.NA , VCode , VC2 );
		end;

	end else if ( SMsg = 'GSTAT' ) then begin
		{ Get a Numeric Attribute from the currently grabbed gear. }
		VCode := ScriptValue( Event , GB , Scene );
		if ( Grabbed_Gear <> Nil ) then begin
			if ( VCode >= 1 ) and ( VCode <= NumGearStats ) then begin
				SV := Grabbed_Gear^.Stat[ VCode ];
			end;
		end;

	end else if ( SMsg = 'FXPNEEDED' ) then begin
		{ Return how many faction XP points needed for next level. }
		VCode := ScriptValue( Event , GB , Scene );
		SV := ( VCode + 1 ) * 5;

	end else if ( SMsg = 'MAPTILE' ) then begin
		{ Return how many faction XP points needed for next level. }
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		if ( GB <> Nil ) and OnTheMap( VCode , VC2 ) then begin
			SV := GB^.Map[ VCode , VC2 ].terr;
		end else begin
			SV := 0;
		end;

	end else if Attempt_Gear_Grab( SMsg , Event , GB , Scene ) then begin
		{ The correct Grabbed_Gear was set by the above call, }
		{ so just recurse to find the value we want. Am I looming }
		{ closer to functional programming or something? }
		SV := ScriptValue( Event , gb , scene );

	end else if ( SMsg = 'COMTIME' ) then begin
		{ Return the current combat time. }
		if ( GB <> Nil ) then begin
			SV := GB^.ComTime;
		end;

	end else if ( SMsg = 'NEXTDAY' ) then begin
		{ Return the start of the next day. }
		if ( GB <> Nil ) then begin
			SV := GB^.ComTime + 86400 - GB^.ComTime mod 86400;
		end;

	end else if ( SMsg = 'PCSKILLVAL' ) then begin
		{ Return the PC team's highest skill value. }
		VCode := ScriptValue( Event , GB , Scene );
		SV := SV_PCSkillVal( GB , VCode );

	end else if ( SMsg = 'SCENEID' ) then begin
		{ Return the current scene's unique ID. }
		{ Only do this if we're in the real scene! Return 0 for }
		{ a temporary or otherwise fake scene. }
		if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and IsSubCom( GB^.Scene ) then begin
			SV := GB^.Scene^.S;
		end;

	end else if ( SMsg = 'FACMEM' ) then begin
		{ Return the number of members of the requested faction. }
		if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
			VCode := ScriptValue( Event , GB , Scene );
			SV := FindFacMem( VCode , GB , GB^.Scene );
		end;

	end else if ( SMsg = 'FACSCENE' ) then begin
		{ Return the number of scenes controlled by this faction. }
		if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
			VCode := ScriptValue( Event , GB , Scene );
			SV := FindFacScene( VCode , GB^.Scene );
		end;

	end else if ( SMsg = 'HOSTILEFACTIONS' ) then begin
		{ Return the number of hostile factions in play. }
		if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
			SV := FindHostileFactions( GB , Scene );
		end;

	end else if ( SMsg = 'REACT' ) then begin
		{ Return the current reaction score between PC & NPC. }
		if ( IntMenu <> Nil ) then begin
			if GB = Nil then begin
				SV := ReactionScore( Nil , I_PC , I_NPC );
			end else begin
				SV := ReactionScore( GB^.Scene , I_PC , I_NPC );
			end;
		end;

	end else if ( SMsg = 'SKROLL' ) then begin
		{ Return a skill roll from the PC. }
		VCode := ScriptValue( Event , GB , Scene );
		if ( VCode >= 1 ) and ( VCode <= NumSkill ) then begin
			SV := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , VCode ) );
		end else SV := 0;
		PC := GG_LocatePC( GB );
		if PC <> Nil then DoleSkillExperience( PC , VCode , 5 );

	end else if SMsg = 'PCMEKS' then begin
		SV := NumPCMeks( GB );

	end else if ( SMsg = 'THREAT' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := Calculate_Threat_Points( VCode , VC2 );

	end else if ( SMsg = '*' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := VCode * VC2;

	end else if ( SMsg = 'WMTHREAT' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		if VCode < 4 then VCOde := 4;
		SV := VCode div 2;

	end else if ( SMsg = 'REWARD' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := Calculate_Reward_Value( GB , VCode , VC2 );

	end else if ( SMsg = 'RANGE' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := SV_Range( GB , VCode , VC2 );

	end else if SMsg = 'PCSCALE' then begin
		SV := FindPCScale( GB );

	end else if ( SMsg = 'ESCENE' ) then begin
		{ Find out what element to find the scene for. }
		if ( Scene <> Nil ) then begin
			VCode := ExtractValue( Event );

			{ Find out what plot we're dealing with. }
			Scene := PlotMaster( Scene );

			if ( Scene <> Nil ) and ( VCode >= 1 ) and ( VCode <= NumGearStats ) then begin
				SV := ElementLocation( FindRoot( Scene ) , Scene , VCode , GB );
			end;
		end;

	end else if ( SMsg[1] = 'D' ) then begin
		{ Roll a die, return the result. }
		DeleteFirstChar( SMsg );
		Event := SMsg + ' ' + Event;
		VCode := ScriptValue( Event , GB , Scene );;
		if VCode < 1 then VCode := 1;
		SV := Random( VCode ) + 1;

	{ As a last resort, see if the first character shows up in the }
	{ scripts file. If so, use that. }
	end else if SAttValue( Value_Macros , SMsg[1] ) <> '' then begin
		{ Install the macro, then re-call this procedure to get }
		{ the results. }
		S2 := SMsg[ 1 ];
		DeleteFirstChar( SMsg );
		Event := SMsg + ' ' + Event;
		InitiateMacro( Event , SAttValue( Value_Macros , S2 ) );
		SV := ScriptValue( Event , gb , scene );

	end else if ( SMsg[1] = '?' ) and ( gb <> Nil ) then begin
		{ Return a randomly picked gear from the game board. }
		DeleteFirstChar( SMsg );
		if UpCase(SMsg[1]) = 'M' then begin
			DeleteFirstChar( SMsg );
			SV := FindRandomMekID( GB , ScriptValue( SMsg , gb , scene ) );
		end else begin
			DeleteFirstChar( SMsg );
			SV := FindRandomPilotID( GB , ScriptValue( SMsg , gb , scene ) );
		end;

	end else if ( SMsg[1] = 'T' ) and ( gb <> Nil ) then begin
		{ Return the number of gears on the provided team. }
		DeleteFirstChar( SMsg );
		VCode := ExtractValue( SMsg );
		SV := NumActiveMasters( GB , VCode );

	end else if ( SMsg[1] = '@' ) and ( gb <> Nil ) then begin
		{ Return the root gear of the gear indicated by the }
		{ rest of this expression. Return 0 if there's an error. }
		DeleteFirstChar( SMsg );
		VCode := ScriptValue( SMsg , gb , scene );
		if VCode <> 0 then SV := FindRootUID( GB , VCode )
		else SV := 0;


	end else if SMsg[1] = '-' then begin
		{ We want the negative of the value to follow. }
		DeleteFirstChar( SMsg );
		event := SMsg + ' ' + event;
		SV := -ScriptValue( event , gb , scene );

	end else begin
		{ No command was given, so this must be a constant value. }
		S2 := SMsg;
		SV := ExtractValue( SMsg );

		if ( SV = 0 ) and ( S2 <> '' ) and ( S2 <> '0' ) then begin
			DialogMsg( 'WARNING: Script value ' + S2  + ' in ' + GearName( Scene ) );
			DialogMsg( 'CONTEXT: ' + event );
		end;
	end;

	{ Restore the grabbed gear before exiting. }
	Grabbed_Gear := Old_Grabbed_Gear;

	ScriptValue := SV;
end;

Function AS_GetString( Source: GearPtr; Key: String ): String;
	{ Check the SOURCE for a SAtt with the provided KEY. }
	{ If none can be found, search the default list for SOURCE's type. }
	{ Normally, getting a string attribute could be handled simply by the }
	{ SAttValue function. But, I had some trouble with my doors getting so }
	{ #$#@%! huge, so I decided to write the function as a space-saver. }
var
	msg: String;
begin
	if Source <> Nil then begin
		msg := SAttValue( Source^.SA , Key );
		if ( msg = '' ) and ( Source^.G = GG_MetaTerrain ) and ( Source^.S >= 1 ) and ( Source^.S <= NumBasicMetaTerrain ) then begin
			msg := SAttValue( Meta_Terrain_Scripts[ Source^.S ] , Key );
		end;
	end else begin
		msg := '';
	end;
	AS_GetString := msg;
end;

Procedure AS_SetExit( GB: GameBoardPtr; RC: Integer );
	{ Several things need to be done when exiting the map. }
	{ This procedure should centralize most of them. }
begin
	{ Only process this request if we haven't already set an exit. }
	if ( GB <> Nil ) and ( not GB^.QuitTheGame ) then begin
		GB^.QuitTheGame := True;
		GB^.ReturnCode := RC;
		if GB^.Scene <> Nil then begin
			SCRIPT_Gate_To_Seek := GB^.Scene^.S;
		end;
	end;
end;

Procedure ProcessExit( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ An exit command has been received. }
begin
	AS_SetExit( GB , ScriptValue( Event , GB , Source ) );
end;

Procedure ProcessReturn( GB: GameBoardPtr );
	{ An exit command has been received. }
begin
	{ RETURN should only function if called from a dynamic scene... }
	{ anything else could be disasterous. }
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and IsInvCom( GB^.Scene ) then begin
		if GB^.Scene^.S <> 0 then begin
			AS_SetExit( GB , GB^.Scene^.S );
			GB^.Scene^.S := 0;
		end else if not GB^.QuitTheGame then begin
			{ If the current scene = 0, and we received }
			{ a QuitTheGame order, chances are that this }
			{ is an erronious "bounced" request. }
			AS_SetExit( GB , 0 );
		end;
	end;
end;

Function FactionRankName( GB: GameBoardPtr; Source: GearPtr; FID,FRank: Integer ): String;
	{ Return the generic name of rank FRank from faction FID. }
var
	F: GearPtr;
	it: String;
begin
	{ First find the faction. }
	F := GG_LocateFaction( FID , GB , Source );

	{ Do range checking on the FRank score obtained. }
	if FRank < 0 then FRank := 0
	else if FRank > 8 then FRank := 8;

	{ If no faction was found, return the default rank title. }
	if F = Nil then begin
		it := MSgString( 'FacRank_' + BStr( FRank ) );
	end else begin
		{ First check the faction for a name there. }
		{ If the faction has no name set, use the default. }
		it := SAttValue( F^.SA , 'FacRank_' + BStr( FRank ) );
		if it = '' then it := MSgString( 'FacRank_' + BStr( FRank ) );
	end;

	FactionRankName := it;
end;

Function PCRankName( GB: GameBoardPtr; Source: GearPtr ): String;
	{ Return the name of the PC's rank with the PC's faction. }
	{ if the PC has no rank, return the basic string. }
var
	FID: Integer;
	A,F: GearPtr;
begin
	{ The PC's faction ID is located in the adventure gear, so }
	{ locate that first. }
	A := GG_LocateAdventure( GB , Source );
	if A <> Nil then begin
		{ The faction rank score is located in the faction itself. }
		{ So now, let's locate that. }
		FID := NAttValue( A^.NA , NAG_Personal , NAS_FactionID );
		F := GG_LocateFaction( FID , GB , Source );
		if F <> Nil then begin
			{ Call the general Faction Rank function. }
			PCRankName := FactionRankName( GB , Source , FID , NAttValue( F^.NA , NAG_Experience , NAS_FacLevel ) );
		end else begin
			{ No faction found. Return the default value. }
			PCRankName := MsgSTring( 'FACRANK_0' );
		end;
	end else begin
		{ Adventure not found. Return default "peon". }
		PCRankName := MsgSTring( 'FACRANK_0' );
	end;
end;

Procedure FormatMessageString( var msg: String; gb: GameBoardPtr; Scene: GearPtr );
	{ There are a number of formatting commands which may be used }
	{ in an arenascript message string. }
var
	S0,S1,w: String;
	ID,ID2: LongInt;
	Part: GearPtr;
begin
	S0 := msg;
	S1 := '';

	while S0 <> '' do begin
		w := ExtractWord( S0 );

		if UpCase( W ) = '\MEK' then begin
			{ Insert the name of a specified gear. }
			ID := ScriptValue( S0 , GB , Scene );
			Part := LocateMekByUID( GB , ID );
			if Part <> Nil then begin
				W := GearName( Part );
			end else begin
				W := 'ERROR!!!';
			end;

		end else if UpCase( W ) = '\PILOT' then begin
			{ Insert the name of a specified gear. }
			ID := ScriptValue( S0 , GB , Scene );
			Part := LocateMekByUID( GB , ID );
			if Part <> Nil then begin
				W := PilotName( Part );
			end else begin
				W := 'ERROR!!!';
			end;

		end else if UpCase( W ) = '\ELEMENT' then begin
			{ Insert the name of a specified plot element. }
			ID := ScriptValue( S0 , GB , Scene );
			Part := PlotMaster( Scene );
			if Part <> Nil then begin
				W := ElementName( FindRoot( Scene ) , Part , ID , GB );
			end;

		end else if UpCase( W ) = '\NARRATIVE' then begin
			{ Insert the name of a specified plot element. }
			ID := ScriptValue( S0 , GB , Scene );
			Part := StoryMaster( Scene );
			if Part <> Nil then begin
				W := ElementName( FindRoot( Scene ) , Part , ID , GB );
			end;

		end else if UpCase( W ) = '\PERSONA' then begin
			{ Insert the name of a specified persona. }
			ID := ScriptValue( S0 , GB , Scene );
			Part := GG_LocateNPC( ID , GB , Scene );
			W := GEarName( Part );

		end else if UpCase( W ) = '\SCENE' then begin
			{ Insert the name of a specified scene. }
			ID := ScriptValue( S0 , GB , Scene );
			W := SceneName( GB , ID );

		end else if UpCase( W ) = '\VAL' then begin
			{ Insert the value of a specified variable. }
			ID := ScriptValue( S0 , GB , Scene );
			W := BStr( ID );

		end else if UpCase( W ) = '\PC' then begin
			{ The name of the PC. }
			W := GearName( LocatePilot( GG_LocatePC( GB ) ) );

		end else if UpCase( W ) = '\OPR' then begin
			{ Object Pronoun }
			ID := ScriptValue( S0 , GB , Scene );
			Part := GG_LocateNPC( ID , GB , Scene );
			if Part <> Nil then begin
				W := MsgString( 'OPR_' + BStr( NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) ) );
			end else begin
				W := 'it';
			end;

		end else if UpCase( W ) = '\SPR' then begin
			{ Object Pronoun }
			ID := ScriptValue( S0 , GB , Scene );
			Part := GG_LocateNPC( ID , GB , Scene );
			if Part <> Nil then begin
				W := MsgString( 'SPR_' + BStr( NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) ) );
			end else begin
				W := 'it';
			end;

		end else if UpCase( W ) = '\PPR' then begin
			{ Object Pronoun }
			ID := ScriptValue( S0 , GB , Scene );
			Part := GG_LocateNPC( ID , GB , Scene );
			if Part <> Nil then begin
				W := MsgString( 'PPR_' + BStr( NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) ) );
			end else begin
				W := 'its';
			end;

		end else if UpCase( W ) = '\RANK' then begin
			{ The faction rank of the PC. }
			W := PCRankName( GB , Scene );

		end else if UpCase( W ) = '\FACRANK' then begin
			{ A generic faction rank, not nessecarilt belonging }
			{ to the PC. }
			ID := ScriptValue( S0 , GB , Scene );
			ID2 := ScriptValue( S0 , GB , Scene );

			W := FactionRankName( GB , Scene , ID , ID2 );

		end else if UpCase( W ) = '\DATE' then begin
			ID := ScriptValue( S0 , GB , Scene );

			W := TimeString( ID );
		end;

		if IsPunctuation( W[1] ) or ( S1[Length(S1)] = '$' ) or ( S1[Length(S1)] = '@' ) then begin
			S1 := S1 + W;
		end else begin
			S1 := S1 + ' ' + W;
		end;

	end;

	msg := S1;
end;

Function ConditionAccepted( Event: String; gb: GameBoardPtr; Source: GearPtr ): Boolean;
	{ Run a conditional script. }
	{ If it returns 'ACCEPT', this function returns true. }
var
	T: String;	{ The trigger to be used. }
begin
	{ Error check - an empty condition is always true. }
	if Event = '' then Exit( True );

	{ Generate the trigger. }
	T := 'null';

	{ Execute the provided event. }
	InvokeEvent( Event , GB , Source , T );

	{ If the trigger was changed, that counts as a success. }
	ConditionAccepted := T = 'ACCEPT';
end;

Function ScriptMessage( msg_label: String; GB: GameBoardPtr; Source: GearPtr ): String;
	{ Retrieve and format a message from the source. }
var
	N,T: Integer;
	C,msg: String;
	MList,M: SAttPtr;
begin
	{ Create the list of possible strings. }
	MList := Nil;
	C := AS_GetString( Source , 'C' + msg_label );

	{ The master condition must be accepted in order to continue. }
	if ConditionAccepted( C , GB , Source ) and ( Source <> Nil ) then begin
		msg := AS_GetString( Source , msg_label );
		if msg <> '' then StoreSAtt( MList , msg );

		msg := msg_label + '_';
		N := NumHeadMatches( msg , Source^.SA );
		for t := 1 to N do begin
			M := FindHeadMatch( msg , Source^.SA , T);
			C := SAttValue( Source^.SA , 'C' + RetrieveAPreamble( M^.info ) );
			if ConditionAccepted( C , GB , Source ) then begin
				StoreSAtt( MList , RetrieveAString( M^.Info ) );
			end;
		end;
	end;

	{ If any messages were found, pick one. }
	if MList <> Nil then begin
		msg := SelectRandomSAtt( MList )^.Info;
		DisposeSAtt( MList );
		FormatMessageString( msg , gb , source );
	end else begin
		msg := '';
	end;

	ScriptMessage := Msg;
end;

Function GetTheMessage( head: String; idnum: Integer; GB: GameBoardPtr; Scene: GearPtr ): String;
	{ Just call the SCRIPTMESSAGE with the correct label. }
begin
	GetTheMessage := ScriptMessage( head + BStr( idnum ) , GB , Scene );
end;

Procedure ProcessPrint( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then print the specified message. }
var
	msg: String;
	id: Integer;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg', id , GB , Scene );
	if msg <> '' then DialogMsg( msg );
end;

Procedure ProcessAlert( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then print the specified message. }
var
	id: Integer;
	msg: String;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg', id , GB , Scene );
	if msg <> '' then begin
		YesNoMenu( GB , msg , '' , '' );
		GFCombatDisplay( GB );
	end;
end;

Procedure ProcessMemo( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	id: Integer;
	msg: String;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg', id , GB , Scene );
	if ( Scene <> Nil ) then SetSAtt( Scene^.SA , 'MEMO <' + msg + '>' );
end;

Procedure ProcessHistory( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	id: Integer;
	msg: String;
	Adv: GearPtr;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg' , id , GB , Scene );
	Adv := GG_LocateAdventure( GB , Scene );
	if ( msg <> '' ) and ( Adv <> Nil ) then AddSAtt( Adv^.SA , 'HISTORY' , msg );
end;

Procedure ProcessVictory( GB: GameBoardPtr );
	{ Sum up the entire campaign in a list of SAtts, then print to }
	{ a file. }
const
	InvStr = '+';
	SubStr = '>';
var
	VList,SA: SAttPtr;
	PC,Fac,Adv: GearPtr;
	T,V: LongInt;
	msg,fname: String;
	Procedure CheckAlongPath( Part: GearPtr; TabPos,Prefix: String );
		{ CHeck along the path specified, adding info to }
		{ the victory list. }
	var
		msg: String;
	begin
		while Part <> Nil do begin
			if ( Part^.G <> GG_AbsolutelyNothing ) then begin
				StoreSAtt( VList , tabpos + prefix + GearName( Part ) );
				msg := ExtendedDescription( Part );
				if msg <> '' then StoreSAtt( VList , tabpos + ' ' + msg );
			end;
			if Part^.G <> GG_Cockpit then begin
				CheckAlongPath( Part^.InvCom , TabPos + '  ' , InvStr );
				CheckAlongPath( Part^.SubCom , TabPos + '  ' , SubStr );
			end;
			Part := Part^.Next;
		end;
	end;{CheckAlongPath}
begin
	{ Initialize our list to NIL. }
	VList := Nil;

	DialogMsg( MsgString( 'HISTORY_AnnounceVictory' ) );
	EndOfGameMoreKey;

	{ Locate the PC, add PC-specific information. }
	PC := LocatePilot( GG_LocatePC( GB ) );
	if PC <> Nil then begin
		{ Store the  name. }
		fname := GearName( PC );
		StoreSAtt( VList , fname );
		StoreSAtt( VList , JobAgeGenderDesc( PC ) );
		StoreSAtt( VList , TimeString( GB^.ComTime ) );
		StoreSAtt( VList , ' ' );


		{ Store the stats. }
		for t := 1 to 8 do begin
			msg := StatName[ t ];
			while Length( msg ) < 20 do msg := msg + ' ';
			msg := msg + BStr( PC^.Stat[ T ] );
			V := ( PC^.Stat[ T ] + 2 ) div 3;
			if V > 7 then V := 7;
			msg := msg + '  (' + MsgString( 'STATRANK' + BStr( V ) ) + ')';
			StoreSAtt( VList , msg );
		end;
		StoreSAtt( VList , ' ' );

		{ Add info on the PC's XP and credits. }
		msg := MsgString( 'INFO_XP' );
		V := NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP );
		msg := msg + ' ' + BStr( V );
		StoreSAtt( VList , msg );

		msg := MsgString( 'INFO_XPLeft' );
		V := V - NAttVAlue( PC^.NA , NAG_Experience , NAS_SpentXP );
		msg := msg + ' ' + BStr( V );
		StoreSAtt( VList , msg );

		msg := MsgString( 'INFO_Credits' );
		V := NAttVAlue( PC^.NA , NAG_Experience , NAS_Credits );
		msg := msg + ' ' + BStr( V );
		StoreSAtt( VList , msg );

		{ Store the faction and rank. }
		Fac := GG_LocateFaction( NAttValue( PC^.NA , NAG_Personal , NAS_FactionID ) , GB , Nil );
		if Fac <> Nil then begin
			msg := ReplaceHash( MsgString( 'HISTORY_FACTION' ) , PCRankName( GB , Nil ) );
			msg := ReplaceHash( msg , GearName( Fac ) );
			StoreSAtt( VList , msg );
			StoreSAtt( VList , ' ' );
		end;

		{ Store the personality traits. }
		for t := 1 to Num_Personality_Traits do begin
			V := NATtValue( PC^.NA , NAG_CharDescription , -T );
			if V <> 0 then begin
				Msg := ReplaceHash( MsgString( 'HISTORY_Traits' ) , PersonalityTraitDesc( T , V ) );
				Msg := ReplaceHash( msg , BStr( Abs( V ) ) );
				StoreSAtt( VList , msg );
			end;
		end;
		StoreSAtt( VList , ' ' );

		{ Store the talents. }
		V := 0;
		for t := 1 to NumTalent do begin
			if HasTalent( PC , T ) then begin
				msg := MsgString( 'TALENT' + BStr( T ) );
				StoreSAtt( VList , msg );
				msg := '  ' + MsgString( 'TALENTDESC' + BStr( T ) );
				StoreSAtt( VList , msg );
				inc( V );
			end;
		end;
		if V > 0 then StoreSAtt( VList , ' ' );

		{ Store the skill ranks. }
		for t := 1 to NumSkill do begin
			V := NATtValue( PC^.NA , NAG_Skill , T );
			if V > 0 then begin
				Msg := ReplaceHash( MsgString( 'HISTORY_Skills' ) , SkillMan[ T ].Name );
				Msg := ReplaceHash( msg , BStr( V ) );
				Msg := ReplaceHash( msg , BStr( SkillValue( PC , T ) ) );
				StoreSAtt( VList , msg );
			end;
		end;
		StoreSAtt( VList , ' ' );

		{ Store info on the PC's body and equipment. }
		CheckAlongPath( PC^.InvCom , '  ' , '+' );
		CheckAlongPath( PC^.SubCom , '  ' , '>' );
		StoreSAtt( VList , ' ' );

	end else begin
		{ No PC found, so filename will be "out.txt". }
		fname := 'out';
	end;

	Adv := FindRoot( GB^.Scene );
	if Adv <> Nil then begin
		{ Once the PC wins, unlock the adventure. }
		Adv^.S := 1;
		SA := Adv^.SA;
		while SA <> Nil do begin
			if UpCase( Copy( SA^.Info , 1 , 7 ) ) = 'HISTORY' then begin
				StoreSAtt( VList , RetrieveAString( SA^.Info ) );
			end;
			SA := SA^.Next;

		end;
	end;

	{ Add info on the PC's mechas. }
	PC := GB^.Meks;
	while PC <> Nil do begin
		if ( NAttValue( PC^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( PC^.G = GG_Mecha ) then begin
			StoreSAtt( VList , FullGearName( PC ) );

			CheckAlongPath( PC^.InvCom , '  ' , '+' );
			CheckAlongPath( PC^.SubCom , '  ' , '>' );

			StoreSAtt( VList , ' ' );
		end;
		PC := PC^.Next;
	end;

	SaveStringList( FName + '.txt' , VList );
	MoreText( VList , 1 );
	DisposeSAtt( VList );
	GFCombatDisplay( GB );
end;

Procedure ProcessNews( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	msg: String;
	id: Integer;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg' , id , GB , Scene );
	if ( msg <> '' ) and ( Scene <> Nil ) then SetSAtt( Scene^.SA , 'NEWS <' + msg + '>' );
end;

Procedure ProcessEMail( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	msg: String;
	PC: GearPtr;
	id: Integer;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg' , id , GB , Scene );
	if ( msg <> '' ) and ( Scene <> Nil ) then SetSAtt( Scene^.SA , 'EMAIL <' + msg + '>' );
	PC := GG_LocatePC( GB );
	if ( PC <> Nil ) and HasPCommCapability( PC , PCC_EMail ) then DialogMsg( MsgString( 'AS_EMail' ) );
end;

Procedure ProcessValueMessage( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then print the specified message. }
var
	msg: String;
	V: LongInt;
begin
	{ FInd the message we're supposed to print. }
	msg := ExtractWord( Event );
	msg := MsgString( msg );

	{ Find the value to insert. }
	V := ScriptValue( Event , GB , Scene );

	{ Insert the value. }
	msg := ReplaceHash( msg , BStr( V ) );

	if msg <> '' then DialogMsg( msg );
end;

Procedure ProcessSay( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Locate and then print the specified message. }
var
	id: Integer;
	msg: String;
begin
	{ Error check- if not in a conversation, call the PRINT }
	{ routine instead. }
	if IntMenu = Nil then begin
		ProcessPrint( Event , GB , Source );
		Exit;
	end;

	id := ScriptValue( Event , GB , Source );
	msg := getTheMessage( 'msg' , id , GB , Source );
	if msg <> '' then begin
{$IFDEF SDLMODE}
		NFGameMsg( msg , ZONE_InteractMsg , InfoHiLight );
		CHAT_Message := msg;
{$ELSE}
		GameMsg( msg , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end;
end;

Procedure ProcessAddChat( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Add a new item to the IntMenu. }
var
	N: Integer;
	Msg: String;
begin
	{ Error check - this command can only work if the IntMenu is }
	{ already allocated. }
	if ( IntMenu <> Nil ) and ( Source <> Nil ) then begin
		{ First, determine the prompt number. }
		N := ScriptValue( Event , GB , Source );

		msg := getthemessage( 'PROMPT' , N , GB , Source );
		DeleteWhiteSpace( msg );
		if Msg <> '' then begin
			AddRPGMenuItem( IntMenu , Msg , N );
			RPMSortAlpha( IntMenu );
		end;
	end;
end;

Procedure ProcessSayAnything;
	{ Print a random message in the interact message area. }
begin
{$IFDEF SDLMODE}
	CHAT_Message := IdleChatter;
{$ELSE}
	GameMsg( IdleChatter , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
end;

Procedure ProcessGSetNAtt( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to assign a value to one of the scene }
	{ variables. }
var
	G,S: Integer;
	V: LongInt;
begin
	{ Find the variable ID number and the value to assign. }
	G := ScriptValue( event , GB , scene );
	S := ScriptValue( event , GB , scene );
	V := ScriptValue( event , GB , scene );
	if Debug_On then dialogmsg( 'GAddNAtt: ' + GearName( Grabbed_Gear ) + ' ' + BStr( G ) + '/' + BStr( S ) + '/' + BStr( V ) );

	if Grabbed_Gear <> Nil then SetNAtt( Grabbed_Gear^.NA , G , S , V );
end;

Procedure ProcessGAddNAtt( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to add a value to one of the scene }
	{ variables. }
var
	G,S: Integer;
	V: LongInt;
begin
	{ Find the variable ID number and the value to assign. }
	G := ScriptValue( event , GB , scene );
	S := ScriptValue( event , GB , scene );
	V := ScriptValue( event , GB , scene );
	if Debug_On then dialogmsg( 'GAddNAtt: ' + GearName( Grabbed_Gear ) + ' ' + BStr( G ) + '/' + BStr( S ) + '/' + BStr( V ) );

	if Grabbed_Gear <> Nil then AddNAtt( Grabbed_Gear^.NA , G , S , V );
end;

Procedure ProcessGSetStat( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to add a value to one of the scene }
	{ variables. }
var
	Slot,Value: Integer;
begin
	{ Find the variable ID number and the value to assign. }
	Slot := ScriptValue( event , GB , scene );
	Value := ScriptValue( event , GB , scene );

	if Grabbed_Gear <> Nil then Grabbed_Gear^.Stat[ Slot ] := Value;
end;

Procedure ProcessGAddStat( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to add a value to one of the scene }
	{ variables. }
var
	Slot,Value: Integer;
begin
	{ Find the variable ID number and the value to assign. }
	Slot := ScriptValue( event , GB , scene );
	Value := ScriptValue( event , GB , scene );

	if Grabbed_Gear <> Nil then Grabbed_Gear^.Stat[ Slot ] := Grabbed_Gear^.Stat[ Slot ] + Value;
end;

Procedure ProcessGSetSAtt( var Event: String; Source: GearPtr );
	{ Store a string attribute in the grabbed gear. }
var
	Key,Info: String;
begin
	Key := ExtractWord( Event );
	Info := ExtractWord( Event );
	if Source <> Nil then Info := AS_GetString( Source , Info );
	if Grabbed_Gear <> Nil then SetSAtt( Grabbed_Gear^.SA , Key + ' <' + Info + '>' );
end;

Procedure IfSuccess( var Event: String );
	{ An IF call has generated a "TRUE" result. Just get rid of }
	{ any ELSE clause that the event string might still be holding. }
var
	cmd: String;
begin
	{ Extract the next word from the script. }
	cmd := ExtractWord( Event );

	{ If the next word is ELSE, we have to also extract the label. }
	{ If the next word isn't ELSE, better re-assemble the line... }
	if UpCase( cmd ) = 'ELSE' then ExtractWord( Event )
	else Event := cmd + ' ' + Event;
end;

Procedure IfFailure( var Event: String; Scene: GearPtr );
	{ An IF call has generated a "FALSE" result. See if there's }
	{ a defined ELSE clause, and try to load the next line. }
var
	cmd: String;
begin
	{ Extract the next word from the script. }
	cmd := ExtractWord( Event );

	if UpCase( cmd ) = 'ELSE' then begin
		{ There's an else clause. Attempt to jump to the }
		{ specified script line. }
		cmd := ExtractWord( Event );
		Event := AS_GetString( Scene , CMD );

	end else begin
		{ There's no ELSE clause. Just cease execution of this }
		{ line by setting it to an empty string. }
		Event := '';
	end;
end;

Procedure ProcessIfGInPlay( var Event: String; Source: GearPtr );
	{ Return true if the Grabbed_Gear is on the map and operational. }
	{ Return false otherwise. }
begin
	if ( Grabbed_Gear <> Nil ) and OnTheMap( Grabbed_Gear ) and GearOperational( Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfGOK( var Event: String; Source: GearPtr );
	{ If the grabbed gear is OK, count as true. If it is destroyed, }
	{ or if it can't be found, count as false. }
begin
	if ( Grabbed_Gear <> Nil ) and NotDestroyed( Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGSexy( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear is sexy to the PC, count as true. If it is not, }
	{ or if it can't be found, count as false. }
var
	PC: GearPtr;
begin
	PC := GG_LOcatePC( GB );
	if ( Grabbed_Gear <> Nil ) and ( PC <> Nil ) and IsSexy( PC , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGArchEnemy( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear is an enemy of the PC, or belongs to a faction that's }
	{ an enemy of the PC, count as true. }
var
	Adv: GearPtr;
begin
	Adv := GG_LOcateAdventure( GB , Source );
	if ( Grabbed_Gear <> Nil ) and ( Adv <> Nil ) and IsArchEnemy( Adv , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGArchAlly( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear is an ally of the PC, or belongs to a faction that's }
	{ an ally of the PC, count as true. }
var
	Adv: GearPtr;
begin
	Adv := GG_LOcateAdventure( GB , Source );
	if ( Grabbed_Gear <> Nil ) and ( Adv <> Nil ) and IsArchAlly( Adv , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfFaction( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Check to see if the requested faction is active or not. }
var
	FID: Integer;
	Fac: GearPtr;
begin
	{ Locate the requested Faction ID, and from there locate }
	{ the faction gear itself. }
	FID := ScriptValue( Event , GB , Source );
	Fac := GG_LocateFaction( FID , GB , Source );

	{ If the faction was found, see whether or not it's active. }
	if Fac <> Nil then begin
		if FactionIsInactive( Fac ) then IfFailure( Event , Source )
		else IfSuccess( Event );

	{ If said faction cannot be found, it counts as a failure. }
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfStoryless( var Event: String; Source: GearPtr );
	{ Return true if the SOURCE has no story linked. }
	{ Return false otherwise. }
var
	story: GearPtr;
begin
	if Source <> Nil then begin
		story := Source^.InvCom;
		while ( story <> Nil ) and ( story^.G <> GG_Story ) do story := story^.Next;

		if Story = Nil then begin
			IfSuccess( Event );
		end else begin
			IfFailure( Event , Source );
		end;
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfEqual( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If they are equal, that's a success. }
var
	a,b: LongInt;
begin
	{ Determine the two values. }
	A := ScriptValue( Event , gb , Source );
	B := ScriptValue( Event , gb , Source );

	if A = B then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfNotEqual( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If they are not equal, that's a success. }
var
	a,b: LongInt;
begin
	{ Determine the two values. }
	A := ScriptValue( Event , gb , Source );
	B := ScriptValue( Event , gb , Source );

	if A <> B then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfGreater( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If A > B, that's a success. }
var
	a,b: LongInt;
begin
	{ Determine the two values. }
	A := ScriptValue( Event , gb , Source );
	B := ScriptValue( Event , gb , Source );

	if A > B then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfKeyItem( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Process TRUE if the specified key item is in the posession of the PC. }
	{ We'll define this as being in the posession of any member of team }
	{ one... Process FALSE if it isn't. }
var
	NID: Integer;
	FoundTheItem: Boolean;
	PC: GearPtr;
begin
	{ Start by assuming FALSE, then go looking for it. }
	FoundTheItem := False;

	{ Find out what Key Item we're looking for. }
	NID := ScriptValue( Event , GB , Source );

	if ( GB <> Nil ) and ( NID <> 0 ) then begin
		{ Search through every gear on the map. }
		PC := GB^.Meks;

		while PC <> Nil do begin
			{ If this gear belongs to the player team, check it }
			{ for the wanted item. }
			if NAttValue( PC^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				{ Set FOUNDTHEITEM to TRUE if the specified key item }
				{ is the PC gear itself, if it's in the subcoms of the PC, }
				{ or if it's somewhere in the inventory of the PC. }
				if NAttValue( PC^.NA , NAG_Narrative , NAS_NID ) = NID then FoundTheItem := True
				else if SeekGearByIDTag( PC^.SubCom , NAG_Narrative , NAS_NID , NID ) <> Nil then FoundTheItem := True
				else if SeekGearByIDTag( PC^.InvCom , NAG_Narrative , NAS_NID , NID ) <> Nil then FoundTheItem := True;
			end;

			{ Move to the next gear to check. }
			PC := PC^.Next;
		end;
	end;

	{ Finally, do something appropriate depending upon whether or not }
	{ the item was found. }
	if FoundTheItem then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfYesNo( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If they are equal, that's a success. }
var
	Desc,YesPrompt,NoPrompt: String;
	it: Boolean;
	ID: Integer;
begin
	{ Find all the needed messages. }
	id := ScriptValue( Event , GB , Source );
	Desc := GetTheMessage( 'msg' , id , GB , Source );
	id := ScriptValue( Event , GB , Source );
	YesPrompt := GetTheMessage( 'msg' , id , GB , Source );
	id := ScriptValue( Event , GB , Source );
	NoPrompt := GetTheMessage( 'msg' , id , GB , Source );

	it := YesNoMenu( GB , Desc , YesPrompt , NoPrompt );

	if it then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfScene( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return TRUE if the current scene matches the provided }
	{ description, or FALSE otherwise. }
var
	Desc: String;
begin
	Desc := ExtractWord( Event );
	if Source <> Nil then Desc := AS_GetString( Source , Desc );

	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and PartMatchesCriteria( SceneDesc( GB^.Scene ) , Desc ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfNoObjections( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Run a trigger through the narrative gears. }
	{ If none of them BLOCK it, then count the result as TRUE. }
var
	T: String;	{ The trigger to be used. }
	Adv: GearPtr;
begin
	{ Generate the trigger, which is in the same format as for COMPOSE. }
	{ It's a trigger label plus a numeric value. }
	T := ExtractWord( Event );
	T := T + BStr( ScriptValue( Event, GB, Source ) );

	{ Check the trigger along the adventure's invcoms, }
	{ where all the narrative components should be located. }
	Adv := GG_LocateAdventure( GB , Source );
	if Adv <> Nil then begin
		CheckTriggerAlongPath( T, GB, Adv^.InvCom , False );
	end;

	{ If the trigger wasn't blocked, that counts as a success. }
	if T <> '' then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessTeamOrders( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ This procedure is used to assign a behavior type to }
	{ every master unit on the designated team. }
const
	OrderParams: Array [0..NumAITypes] of Byte = (
		0,2,1,0,0,1
	);
var
	Team: Integer;
	OrderName: String;
	T,OrderCode: Integer;
	Mek: GearPtr;
	P: Array [1..2] of Integer;
begin
	{ Record the team number. }
	Team := ScriptValue( Event , gb , Source );

	{ Figure out what order we're supposed to be assigning. }
	OrderName := UpCase( ExtractWord( Event ) );
	OrderCode := -1;
	for t := 0 to NumAITypes do begin
		if OrderName = AI_Type_Label[ t ] then OrderCode := T;
	end;

	{ If a valid order was received, process it. }
	if OrderCode > -1 then begin
		for t := 1 to OrderParams[ OrderCode ] do P[T] := ScriptValue( Event , gb , Source );

		{ Go through each of the meks and, if they are part }
		{ of the specified team, assign the specified order. }
		Mek := gb^.Meks;
		while Mek <> Nil do begin
			if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team then begin
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , OrderCode );

				{ DEFAULT BEHAVIOR- If number of params = 1, assume it to be a mek ID. }
				{ If number of params = 2, assume it to be a map location. }
				if OrderParams[ OrderCode ] = 1 then begin
					SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ATarget , P[1] );
				end else if OrderParams[ OrderCode ] = 2 then begin
					SetNAtt( Mek^.NA , NAG_Location , NAS_GX , P[1] );
					SetNAtt( Mek^.NA , NAG_Location , NAS_GY , P[2] );
				end;
			end;
			Mek := Mek^.Next;
		end;
	end;
end;

Procedure ProcessCompose( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new item is going to be added to the scene list. }
var
	Trigger,Ev2: String;
	P: Integer;
begin
	if Source = Nil then exit;

	{ Extract the values we need. }
	Trigger := ExtractWord( Event );
	P := ScriptValue( Event , GB , Source );
	Ev2 := AS_GetString( Source , ExtractWord( Event ) );

	StoreSAtt( Source^.SA , Trigger + BStr( P ) + ' <' + Ev2 + '>' );
end;

Procedure ProcessNewChat;
	{ Reset the dialog menu with the standard options. }
begin
	{ Error check - make sure the interaction menu is active. }
	if IntMenu = Nil then begin
		Exit;

	{ If there are any menu items currently in the list, get rid }
	{ of them. }
	end else if IntMenu^.FirstItem <> Nil then begin
		ClearMenu( IntMenu );
	end;

	AddRPGMenuItem( IntMenu , '[Chat]' , CMD_Chat );
	AddRPGMenuItem( IntMenu , '[Goodbye]' , -1 );
	if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Relationship , 0 ) > 0 ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , '[Join]' , CMD_Join );
	if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , '[Quit Lance]' , CMD_Quit );
	RPMSortAlpha( IntMenu );
end;

Procedure ProcessEndChat;
	{ End this conversation by clearing the menu. }
begin
	{ Error check - make sure the interaction menu is active. }
	if IntMenu = Nil then begin
		Exit;
	end else begin
		ClearMenu( IntMenu );
	end;
end;

Procedure ProcessGoto( var Event: String; Source: GearPtr );
	{ Attempt to jump to a different line of the script. }
	{ If no line label is provided, or if the label can't be }
	{ found, this procedure sets EVENT to an empty string. }
var
	destination: String;
begin
	{ Error check- if there's no defined source, we can't very }
	{ well jump to another line, can we? }
	if Source = Nil then begin
		Event := '';
		Exit;
	end;

	destination := ExtractWord( Event );
	if destination <> '' then begin
		{ Change the event script to the requested line. }
		Event := AS_GetString( Source , destination );
	end else begin
		{ No label was provided. Just return a blank line. }
		Event := '';
	end;
end;

Procedure ProcessSeekTerr( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Assign a value to SCRIPT_Terrain_To_Seek. }
var
	Terrain: Integer;
begin
	Terrain := ScriptValue( event , GB , Source );
	SCRIPT_Terrain_To_Seek := Terrain;
end;

Procedure ProcessShop( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Retrieve the WARES line, then pass it all on to the OpenShop }
	{ procedure. }
var
	Wares: String;
begin
	{ Retrieve the WARES string. }
	Wares := ExtractWord( Event );
	if Wares <> '' then begin
		{ Change the event script to the requested line. }
		Wares := AS_GetString( Source , Wares );
	end;

	{ Pass all info on to the OPENSHOP procedure. }
	OpenShop( GB , I_PC , I_NPC , Wares );
end;

Procedure ProcessSchool( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Retrieve the WARES line, then pass it all on to the OpenSchool }
	{ procedure. }
var
	Wares: String;
begin
	{ Retrieve the WARES string. }
	Wares := ExtractWord( Event );
	if Wares <> '' then begin
		{ Change the event script to the requested line. }
		Wares := AS_GetString( Source , Wares );
	end;

	{ Pass all info on to the OPENSHOP procedure. }
	OpenSchool( GB , I_PC , I_NPC , Wares );
end;

Procedure ProcessExpressDelivery( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Call the ExpressDelivery procedure. }
begin
	{ Pass all info on to the ExpressDelivery procedure. }
	ExpressDelivery( GB , I_PC , I_NPC );
end;

Procedure ProcessAdvancePlot( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ This particular plot is over- mark it for deletion. }
	{ First, though, check to see if there are any subcomponents that }
	{ need to be moved around. }
var
	N: Integer;
begin
	{ Determine which sub-plot to advance to. }
	N := ScriptValue( event , GB , Source );

	{ If we have a valid SOURCE, attempt to advance the plot. }
	if ( Source <> Nil ) then begin
		{ It's possible that our SOURCE is a PERSONA rather than }
		{ a PLOT, so if SOURCE isn't a PLOT move to its parent. }
		Source := PlotMaster( Source );
		if ( Source <> Nil ) and ( Source^.G = GG_Plot ) then AdvancePlot( GB , Source^.Parent , Source , N );
	end;
end;

Procedure CleanUpStoryPlots( GB: GameBoardPtr; Story: GearPtr );
	{ Give a CLEANUP trigger to all the story plots, then move the }
	{ plots which survive to the adventure invcoms. }
var
	T: String;
	Part,P2,Adv: GearPtr;
begin
	{ Send a CLEANUP trigger to the invcoms. }
	{ This should erase all the plots that want to be erased, }
	{ and leave all the plots which want to be moved. }
	T := 'CLEANUP';
	CheckTriggerAlongPath( T , GB , Story^.InvCom , False );

	{ Check whatever is left over. }
	Part := Story^.InvCom;
	Adv := GG_LocateAdventure( GB , STory );
	while Part <> Nil do begin
		P2 := Part^.Next;

		if Part^.G = GG_Plot then begin
			DelinkGear( Story^.InvCom , Part );
			if Adv <> Nil then begin
				InsertInvCom( Adv , Part );
			end else begin
				DisposeGear( Part );
			end;
		end;

		Part := P2;
	end;
end;

Procedure ProcessEndStory( GB: GameBoardPtr; Source: GearPtr );
	{ This particular story is over- mark it for deletion. }
	{ First, though, pass a CLEANUP trigger to any subcomponents that }
	{ may need to be cleaned up. }
begin
	Source := StoryMaster( Source );
	if ( Source <> Nil ) and ( Source^.G = GG_Story ) then begin
		CleanupStoryPlots( GB , Source );

		{ Mark the story for deletion. }
		Source^.G := GG_AbsolutelyNothing;
	end;
end;

Procedure ProcessPurgeStory( GB: GameBoardPtr; Source: GearPtr );
	{ Eliminate all plots from this story. }
begin
	{ If we have a valid SOURCE, check the invcoms. }
	if ( Source <> Nil ) and ( Source^.G = GG_Story ) then begin
		{ Send a CLEANUP trigger to the invcoms, }
		{ then move the survivors to the Adventure. }
		CleanupStoryPlots( GB , Source );
	end;
end;

Procedure ProcessTReputation( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Something has happened to affect the PC's reputation. }
	{ Record the change. }
var
	T,R,V: Integer;
begin
	{ Error check - this procedure only works if GB is defined. }
	if ( GB = Nil ) then Exit;

	T := ScriptValue( Event , GB , Source );
	R := ScriptValue( Event , GB , Source );
	V := ScriptValue( Event , GB , Source );

	SetTeamReputation( GB , T , R , V );
end;

Procedure ProcessMechaPrize( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ The player has just won a mecha. Cool! }
var
	FName: String;
	MList,Mek,PC: GearPtr;
begin
	{ ERROR CHECK - We need the gameboard to exist!!! }
	if GB = Nil then Exit;

	{ First, find the file name of the mecha file to look for. }
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
	end else begin
		FName := '';
	end;

	MList := LoadGearPattern( FName , Design_Directory );

	{ Next confirm that something was loaded. }
	if MList <> Nil then begin
		{ Something was loaded. Yay! Pick one of the gears }
		{ at random, clone it, stick it on the game board, }
		{ and get rid of the list we loaded. }
		Mek := CloneGear( SelectRandomGear( MList ) );
		DisposeGear( MList );

		SetNAtt( Mek^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
		DeployMek( GB , Mek , False );
		PC := GG_LocatePC( GB );
		if FindPilotsMecha( GB^.Meks , PC ) = Nil then AssociatePilotMek( GB^.Meks , PC , Mek );
	end;

end;

Procedure ProcessDeleteGG( GB: GameBoardPtr; var Source: GearPtr );
	{ Delete the grabbed gear. }
	{ Only physical gears can be deleted in this way. }
begin
	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) then begin
		{ Make sure we aren't currently using the grabbed gear. }
		if ( IntMenu <> Nil ) and ( I_NPC = Grabbed_Gear ) then begin
			ProcessEndChat;
			I_NPC := Nil;
		end;
		if Source = Grabbed_Gear then begin
			Source := Nil;
		end;

		{ Delete the gear, if it can be found. }
		if IsSubCom( Grabbed_Gear ) then begin
			RemoveGear( Grabbed_Gear^.Parent^.SubCom , Grabbed_Gear );

		end else if IsInvCom( Grabbed_Gear ) then begin
			RemoveGear( Grabbed_Gear^.Parent^.InvCom , Grabbed_Gear );

		end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Grabbed_Gear) then begin
			RemoveGear( GB^.Meks , Grabbed_Gear );

		end;
	end;
end;

Procedure ProcessMoveGG( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Move the grabbed gear to the specified scene. }
	{ Only physical gears can be moved in this way. }
	{ If the specified scene is 0, the gear will be "frozen" isntead. }
var
	SID: Integer;	{ Scene ID. }
	Scene: GearPtr;
	P: Point;
begin
	{ Check to make sure we have a valid gear to move. }
	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) then begin
		{ Attach useful scene-specific information to this gear. }
		if IsMasterGear( Grabbed_Gear ) and ( SAttValue( Grabbed_Gear^.SA , 'TEAMDATA' ) = '' ) then begin
			SetSATt( Grabbed_Gear^.SA , 'TEAMDATA <PASS>' );
		end;

		{ Delink the gear, if it can be found. }
		if IsSubCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.SubCom , Grabbed_Gear );
		end else if IsInvCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.InvCom , Grabbed_Gear );
		end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Grabbed_Gear) then begin
			P := GearCurrentLocation( Grabbed_Gear );
			DelinkGear( GB^.Meks , Grabbed_Gear );
			if IntMenu = Nil then RedrawTile( GB , P.X , P.Y );
		end;
		StripNAtt( Grabbed_Gear , NAG_Location );
		StripNAtt( Grabbed_Gear , NAG_Damage );
		StripNAtt( Grabbed_Gear , NAG_WeaponModifier );
		StripNAtt( Grabbed_Gear , NAG_Condition );
		StripNAtt( Grabbed_Gear , NAG_StatusEffect );

		{ Find the new scene to stick our gear into. }
		SID := ScriptValue( Event , GB , Source );
		if SID > 0 then begin
			Scene := FindActualScene( GB , SID );
		end else begin
			Scene := GG_LocateAdventure( GB , Source );
		end;
		InsertInvCom( Scene , Grabbed_Gear );

		{ Clear the item's ORIGINAL HOME value. }
		SetNAtt( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome , 0 );


		{ If inserting a character, better choose a team. }
		if ( Scene^.G = GG_Scene ) and IsMasterGear( Grabbed_Gear ) then begin
			ChooseTeam( Grabbed_Gear , Scene );
		end;
	end;
end;

Procedure ProcessDeployGG( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Move the grabbed gear to the current scene. }
	{ Only physical gears can be moved in this way. }
var
	Team: Integer;
	Scene: GearPtr;
	P: Point;
begin
	{ Check to make sure we have a valid gear to move. }
	if ( Grabbed_Gear <> Nil ) and ( GB <> Nil ) and ( Grabbed_Gear^.G >= 0 ) then begin
		{ Attach useful scene-specific information to this gear. }
		if IsMasterGear( Grabbed_Gear ) and ( SAttValue( Grabbed_Gear^.SA , 'TEAMDATA' ) = '' ) then begin
			SetSATt( Grabbed_Gear^.SA , 'TEAMDATA <PASS>' );
		end;

		{ Set the item's ORIGINAL HOME value. }
		if (( GB^.Scene = Nil ) or IsInvCom( GB^.Scene )) and ( NAttValue( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 ) then begin
			SetNAtt( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome , FindGearScene( Grabbed_Gear , GB ) );
		end;

		{ Delink the gear, if it can be found. }
		if IsSubCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.SubCom , Grabbed_Gear );
		end else if IsInvCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.InvCom , Grabbed_Gear );
		end else if IsFoundAlongTrack( GB^.Meks , Grabbed_Gear) then begin
			P := GearCurrentLocation( Grabbed_Gear );
			DelinkGear( GB^.Meks , Grabbed_Gear );
			if ( IntMenu = Nil ) and OnTheMap( P.X , P.Y ) then RedrawTile( GB , P.X , P.Y );
		end;
		StripNAtt( Grabbed_Gear , NAG_Location );
		StripNAtt( Grabbed_Gear , NAG_Damage );
		StripNAtt( Grabbed_Gear , NAG_WeaponModifier );
		StripNAtt( Grabbed_Gear , NAG_Condition );
		StripNAtt( Grabbed_Gear , NAG_StatusEffect );

		{ Find the new team for our gear. }
		Team := ScriptValue( Event , GB , Source );
		SetNAtt( Grabbed_Gear^.NA , NAG_Location , NAS_Team , Team );

		{ Stick it on the map, and maybe do a redraw. }
		DeployMek( GB , Grabbed_Gear , True );
		P := GearCurrentLocation( Grabbed_Gear );
		if ( IntMenu = Nil ) and OnTheMap( P.X , P.Y ) then RedrawTile( GB , P.X , P.Y );
	end;
end;

Procedure ProcessDynaGG( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Move the grabbed gear to the dynamic scene. }
	{ Only physical gears can be moved in this way. }
	{ If the specified scene is 0, the gear will be "frozen" isntead. }
var
	TID: Integer;	{ Scene ID, Team ID. }
	Scene: GearPtr;
	P: Point;
begin
	{ Check to make sure we have a valid gear to move. }
	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) and ( SCRIPT_DynamicEncounter <> Nil ) then begin
		{ Attach useful scene-specific information to this gear. }
		if IsMasterGear( Grabbed_Gear ) and ( NAttValue( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 ) then begin
			Scene := FindActualScene( GB , FindGearScene( Grabbed_Gear , GB ) );

			TID := NAttValue( Grabbed_Gear^.NA , NAG_Location , NAS_Team );
			if SCene <> Nil then begin
				{ Record team description. }
				SetSATt( Grabbed_Gear^.SA , 'TEAMDATA <' + TeamDescription( Scene, LocateTeam( Scene , TID ) ) + '>' );

				{ Record the item's orginal home, if not already done. }
				SetNAtt( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome , Scene^.S );
			end else begin
				SetNAtt( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
			end;
		end else begin
			Scene := Nil;
			if NAttValue( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 then SetNAtt( Grabbed_Gear^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
		end;


		{ Delink the gear, if it can be found. }
		if IsSubCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.SubCom , Grabbed_Gear );
		end else if IsInvCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.InvCom , Grabbed_Gear );
		end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Grabbed_Gear) then begin
			P := GearCurrentLocation( Grabbed_Gear );
			DelinkGear( GB^.Meks , Grabbed_Gear );
			if IntMenu = Nil then RedrawTile( GB , P.X , P.Y );
		end;
		StripNAtt( Grabbed_Gear , NAG_Location );
		StripNAtt( Grabbed_Gear , NAG_Damage );
		StripNAtt( Grabbed_Gear , NAG_WeaponModifier );
		StripNAtt( Grabbed_Gear , NAG_Condition );
		StripNAtt( Grabbed_Gear , NAG_StatusEffect );

		{ Find out which team to stick the NPC in. }
		TID := ScriptValue( Event , GB , Source );

		{ Perform the insertion. }
		InsertNPCIntoDynamicScene( Grabbed_Gear , SCRIPT_DynamicEncounter , TID );

	end;
end;

Procedure ProcessGiveGG( GB: GameBoardPtr );
	{ Give the grabbed gear to the PC. }
	{ Only physical gears can be moved in this way. }
var
	DelinkOK: Boolean;
	PC: GearPtr;
begin
	PC := GG_LocatePC( GB );

	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) and (( PC = Nil ) or ( FindGearIndex( Grabbed_Gear , PC ) < 0 )) then begin

		{ Delink the gear, if it can be found. }
		if IsSubCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.SubCom , Grabbed_Gear );
			DelinkOK := True;
		end else if IsInvCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.InvCom , Grabbed_Gear );
			DelinkOK := True;
		end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Grabbed_Gear) then begin
			DelinkGear( GB^.Meks , Grabbed_Gear );
			DelinkOK := True;
		end else begin
			DelinkOK := False;
		end;

		if DelinkOK then begin
			GivePartToPC( GB , Grabbed_Gear , PC );
		end;
	end;
end;

Procedure ProcessGNewPart( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Stick an item from the standard items list on the gameboard, }
	{ then make GRABBED_GEAR point to it. }
	{ This function will first look in the STC file, then the Monster }
	{ file, then the NPC file. }
var
	IName: String;
begin
	{ First determine the item's designation. }
	IName := ExtractWord( Event );
	if Source <> Nil then begin
		IName := AS_GetString( Source , IName );
	end;

	{ As long as we have a GB, try to stick the item there. }
	if GB <> Nil then begin
		Grabbed_Gear := LoadNewSTC( IName );
		if Grabbed_Gear = Nil then Grabbed_Gear := LoadNewMonster( IName );
		if Grabbed_Gear = Nil then Grabbed_Gear := LoadNewNPC( IName );

		{ If we found something, stick it on the map. }
		if Grabbed_Gear <> Nil then begin
			{ Clear the designation. }
			SetSAtt( Grabbed_Gear^.SA , 'DESIG <>' );

			{ Deploy the item. }
			DeployMek( GB , Grabbed_Gear , False );
		end;

		{ Any further processing must be done by other commands. }
	end;
end;

Procedure ProcessSetSceneFaction( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ This procedure will take over a scene in the name of a given }
	{ faction. }
const
	New_Home_Type1 = 'Town !M ';
	New_Home_Type2 = 'Town !M 0';
	Garrison_Team_Type = 'TEAMDATA <ally sd>';

	Procedure RemoveToSafeHome( Part,OScene: GearPtr; var LList: GearPtr );
		{ PART needs to be extracted from its current scene and }
		{ moved to a new scene. If no good scene can be found, }
		{ then delete PART. }
	var
		FID: Integer;
		Adv,Scene: GearPtr;
	begin
		{ Delink the NPC from its current location. }
		DelinkGear( LList , Part );

		{ Find the adventure. }
		Adv := FindRoot( GB^.Scene );

		{ Find its current faction number, and try to find a }
		{ scene to send it to. }
		FID := NAttValue( Part^.NA , NAG_Personal , NAS_FactionID );
		Scene := SearchForScene( Adv , Nil , GB , New_Home_Type1 + BStr( FID ) );
		if Scene = Nil then begin
			Scene := SearchForScene( Adv , Nil , GB , New_Home_Type2 );
		end;

		{ If a scene was found, move the NPC there. }
		{ Otherwise delete the NPC. }
		if Scene <> Nil then begin
			SetSATt( Part^.SA , 'TEAMDATA <' + TeamDescription( OScene, LocateTeam( OScene , NAttValue( PART^.NA , NAG_Location , NAS_Team ) ) ) + '>' );

			{ Strip the location data from the character. }
			StripNAtt( Part , NAG_Location );

			{ Move the NPC to the adventure's INV. }
			InsertInvCom( Scene , Part );
			ChooseTeam( Part , Scene );

		end else begin
			DisposeGear( Part );
		end;
	end;

	Procedure ScanForDisposessed( OScene: GearPtr; var LList: GearPtr; NFID: Integer );
		{ Check the list provided for members of an ousted faction. }
		{ Remove those members to safe towns elsewhere, or delete }
		{ them if no safe havens could be found. }
	var
		Part,P2: GearPtr;
		PFID: Integer;
	begin
		Part := LList;
		while Part <> Nil do begin
			P2 := Part^.Next;

			{ If this is a character, and isn't the player }
			{ character, it may need to be relocated. }
			if ( Part^.G = GG_Character ) and ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) <> NAV_DefPlayerTeam ) and ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin

				PFID := NAttValue( Part^.NA , NAG_Personal , NAS_FactionID );
				if ( PFID <> 0 ) and ( PFID <> NFID ) then begin
					{ This character has to be removed from the scene. }
					RemoveToSafeHome( Part , OScene , LList );
				end;
			end else begin
				if Part^.SubCom <> Nil then ScanForDisposessed( OScene , Part^.SubCom , NFID );
				if Part^.InvCom <> Nil then ScanForDisposessed( OScene , Part^.InvCom , NFID );
			end;

			Part := P2;
		end;
	end;

	Procedure AddNewGarrison( SID,FID: Integer );
		{ Add a new garrison to the town. }
	var
		Adv,NPC: GearPtr;
		T: Integer;
	begin
		{ Find the adventure. }
		Adv := FindRoot( GB^.Scene );

		for t := 1 to 3 do begin
			NPC := LoadNewNPC( 'Mecha Pilot' );
			if NPC <> Nil then begin
				SetNAtt( NPC^.NA , NAG_Personal , NAS_CID , NewCID( GB , Adv ) );

				SetSATt( NPC^.SA , 'LOCATIONS <' + BStr( SID ) + '>' );
				SetSATt( NPC^.SA , Garrison_Team_Type );
				SetNAtt( NPC^.NA , NAG_Personal , NAS_FactionID , FID );

				{ Move the NPC to the adventure's INV. }
				InsertInvCom( Adv , NPC );
			end;
		end;
	end;

var
	SID,FID: Integer;
	Scene: GearPtr;

begin
	{ Find the Scene ID and Faction ID. }
	SID := ScriptValue( event , GB , Source );
	FID := ScriptValue( event , GB , Source );

	{ Locate the scene to change the faction of. }
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then  begin
		Scene := FindActualScene( GB  , SID );

		if Scene <> Nil then begin
			{ Step One - Set the new FACTION ID. }
			SetNAtt( Scene^.NA , NAG_Personal , NAS_FactionID , FID );

			{ Step Two - Remove all members of other factions, }
			{ moving them to friendlier territories. }
			ScanForDisposessed( Scene , Scene^.InvCom , FID );
			if GB^.Scene = Scene then ScanForDisposessed( Scene , GB^.Meks , FID );

			{ Step Three - Add 3 new faction members to the }
			{ scene. This is the new garrison. }
			AddNewGarrison( SID , FID );
		end;
	end;
end;

Procedure ProcessDeleteFaction( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ The requested FACTION is about to be taken out of the game. }
	{ The gear for the faction isn't deleted (we may need it for }
	{ rumors & stuff & possible recovery) but all characters and }
	{ locations belonging to the faction get their FacID cleared. }
	{ Also, an "INACTIVE" tag is added to the faction's TYPE SAtt. }
	Procedure DFWorkHorse( Part: GearPtr; FID: Integer );
		{ Travel through PART and all of its siblings and children, }
		{ enacting the deletion of FID all the way along. }
	var
		t: String;
	begin
		while Part <> Nil do begin
			if Part^.G = GG_Faction then begin
				{ This part won't have a FID stored, but may }
				{ be the part  we're deleting. }
				if Part^.S = FID then begin
					{ This faction is the faction we're deleting! }
					T := SATtValue( Part^.SA , 'TYPE' );
					if not AStringHasBString( T , 'INACTIVE' ) then SetSAtt( Part^.SA , 'TYPE <' + T + ' INACTIVE>' );
				end;
			end else begin
				if NAttValue( Part^.NA , NAG_Personal , NAS_FactionID ) = FID then begin
					{ Set this part's FACTION ID to zero. }
					SetNAtt( Part^.NA , NAG_Personal , NAS_FactionID , 0 );

					if Part^.G = GG_Character then begin
						AddReputation( Part , 6 , -30 );
					end;
				end;
			end;

			{ Check the sub and inv components. }
			DFWorkHorse( Part^.SubCom , FID );
			DFWorkHorse( Part^.InvCom , FID );

			{ Move to the next part. }
			Part := Part^.Next;
		end;
	end;
var
	FID: Integer;
	Part: GearPtr;
begin
	{ First determine what faction we're supposed to be deleting. }
	FID := ScriptValue( Event , GB , Source );

	{ Locate the root adventure gear next. }
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Part := FindRoot( GB^.Scene );
	end else begin
		Part := FindRoot( Source );
	end;

	{ If the adventure was found, continue on with the deletion }
	{ of this faction. }
	if ( Part <> Nil ) and ( Part^.G = GG_Adventure ) then begin
		DFWorkHorse( Part , FID );
	end;
end;

Procedure BuildGenericEncounter( GB: GameBoardPtr; Scale: Integer );
	{ Create a SCENE gear, then do everything except stock it with }
	{ enemies. }
var
	Team: GearPtr;
begin
	{ First, if for some reason there's already a dynamic encounter in }
	{ place, get rid of it. }
	if SCRIPT_DynamicEncounter <> Nil then DisposeGear( SCRIPT_DynamicEncounter );

	{ Allocate a new dynamic encounter, then fill in the blanks. }
	SCRIPT_DynamicEncounter := NewGear( Nil );
	SCRIPT_DynamicEncounter^.G := GG_Scene;
	SCRIPT_DynamicEncounter^.Stat[ STAT_MapGenerator ] := 1;
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		{ Copy over the important stuff. }
		SCRIPT_DynamicEncounter^.S := GB^.Scene^.S;

		{ Copy the Faction ID of the original scene in order to prevent }
		{ erroneous readings from SCENEFACTION. I don't really like this }
		{ solution to the problem since it's a bit hackish, but at least }
		{ it's more expandable than the alternatives. }
		SetNAtt( SCRIPT_DynamicEncounter^.NA , NAG_Personal , NAS_FactionID , NAttValue( GB^.Scene^.NA , NAG_Personal , NAS_FactionID ) );
	end;

	SCRIPT_DynamicEncounter^.V := Scale;

	{ Add a TEAM gear for each of the player and the enemy teams. }
	{ We need to do this so that we'll have some control over the placement }
	{ of the player and the enemies. }
	Team := AddGear( SCRIPT_DynamicEncounter^.SubCom , SCRIPT_DynamicEncounter );
	Team^.G := GG_Team;
	Team^.S := NAV_DefPlayerTeam;
	SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefEnemyTeam , NAV_AreEnemies );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_X , XMax div 5 );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_Y , YMax div 2 );

	Team := AddGear( SCRIPT_DynamicEncounter^.SubCom , SCRIPT_DynamicEncounter );
	Team^.G := GG_Team;
	Team^.S := NAV_DefEnemyTeam;
	SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreEnemies );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_X , ( XMax * 4 ) div 5 );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_Y , YMax div 2 );


	{ Set the exit values in the game board. }
	if GB <> Nil then begin
		AS_SetExit( GB , 0 );

		{ Advance the game clock by one hour. }
		QuickTime( GB , AP_HalfHour + RollStep( 35 ) * 5 );
	end;
end;

Procedure ProcessNewD( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Create a new scene for a dynamic encounter to take place on. }
var
	Scale: Integer;
begin
 	Scale := ScriptValue( Event , GB , Source );
	BuildGenericEncounter( GB , Scale );
end;

Procedure ProcessLoadD( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A random encounter has been called for. Yay! Fill out the details }
	{ in SCENE_DynamicEncounter, then set the GB's exit code. }
var
	FName: String;
begin
	{ First, if for some reason there's already a dynamic encounter in }
	{ place, get rid of it. }
	if SCRIPT_DynamicEncounter <> Nil then DisposeGear( SCRIPT_DynamicEncounter );

	{ First, find the file name of the scene file to look for. }
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
	end else begin
		FName := '';
	end;

	{ Secondly, confirm the file name. }
	if FName <> '' then begin
		SCRIPT_DynamicEncounter := LoadGearPattern( FName , Series_Directory );

		if ( SCRIPT_DynamicEncounter <> Nil ) and ( SCRIPT_DynamicEncounter^.G = GG_Scene ) then begin
			{ Fill in the ID number to be used by RETURN. }
			if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
				SCRIPT_DynamicEncounter^.S := GB^.Scene^.S;

				{ Copy the Faction ID of the original scene in order to prevent }
				{ erroneous readings from SCENEFACTION. I don't really like this }
				{ solution to the problem since it's a bit hackish, but at least }
				{ it's more expandable than the alternatives. }
				SetNAtt( SCRIPT_DynamicEncounter^.NA , NAG_Personal , NAS_FactionID , NAttValue( GB^.Scene^.NA , NAG_Personal , NAS_FactionID ) );

			end;

			{ Set the exit values in the game board. }
			if GB <> Nil then begin
				AS_SetExit( GB , 0 );

				{ Advance the game clock by one hour. }
				QuickTime( GB , AP_HalfHour + RollStep( 35 ) * 5 );
			end;

		end else begin
			DisposeGear( SCRIPT_DynamicEncounter );

		end;
	end;

end; { ProcessLoadD }

Procedure ProcessTStockD( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Fill SCRIPT_DynamicEncounter with enemies. }
var
	TID,UPV: LongInt;
begin
	{ Find out the team, and how many enemies to add. }
	TID := ScriptValue( Event , GB , Source );
 	UPV := ScriptValue( Event , GB , Source );

	{ Error check - Make sure we have a dynamic encounter to stock! }
	if SCRIPT_DynamicEncounter <> Nil then begin
		{ Stick enemies in the scene. }
		StockSceneWithEnemies( SCRIPT_DynamicEncounter , UPV , TID );
	end;
end; { ProcessTStockD }

Procedure ProcessWMecha( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Fill SCRIPT_DynamicEncounter with enemies. }
var
	TID,UPV: LongInt;
	SList: SAttPtr;	{ Shopping list. }
	MList,Mek: GearPtr;
begin
	{ Find out the team, and how many enemies to add. }
	TID := ScriptValue( Event , GB , Source );
 	UPV := ScriptValue( Event , GB , Source );

	if GB <> Nil then begin
		{ Generate the list of mecha. }
		SList := GenerateMechaList( UPV div 2 );

		{ Generate the mecha list. }
		MList := PurchaseForces( SList , UPV );

		{ Get rid of the shopping list. }
		DisposeSAtt( SList );

		{ Deploy the mecha on the map. }
		while MList <> Nil do begin
			{ Delink the first gear from the list. }
			Mek := MList;
			DelinkGear( MList , Mek );

			{ Set its team to the requested value. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_Team , TID );

			{ Place it on the map. }
			DeployMek( GB , Mek , True );
		end;
	end;
end; { ProcessWMecha }

Procedure ProcessTMStockD( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Fill SCRIPT_DynamicEncounter with enemies. }
var
	TID,UPV: LongInt;
	MDesc: String;
begin
	{ Find out the team, and how many enemies to add. }
 	TID := ScriptValue( Event , GB , Source );
 	UPV := ScriptValue( Event , GB , Source );

	{ This UPV is roughly equal to the PC's reputation score, give or take a }
	{ little bit. Convert it to a usable value. }
	if UPV < 5 then UPV := 5;
	UPV := ( UPV * UPV div 250 ) + UPV div 5;

	MDesc := ExtractWord( Event );
	if Source <> Nil then begin
		MDesc := AS_GetString( Source , MDesc );
	end;

	{ Error check - Make sure we have a dynamic encounter to stock! }
	if SCRIPT_DynamicEncounter <> Nil then begin
		{ Stick enemies in the scene. }
		StockSceneWithMonsters( SCRIPT_DynamicEncounter , UPV , TID , MDesc );
	end;
end; { ProcessTMStockD }


Procedure ProcessEncounter( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ This procedure may add one of the global NPCs to the list, }
	{ either as an enemy of or an ally of the PC. }
	{ The HOOK is the conversation gear which will be placed for }
	{ the enemy/ally in the target scene. }
var
	ADV,PC: GearPtr;
	EChance,AChance: Integer;
	MainDesc: String;
begin
	{ Error check - make sure everything is defined first. }
	if ( SCRIPT_DynamicEncounter = Nil ) or ( GB = Nil ) or ( GB^.Scene = Nil ) or ( Source = Nil ) then exit;

	{ Locate the root adventure gear and the player character. }
	ADV := FindRoot( GB^.Scene );
	if ( ADV = Nil ) or ( ADV^.G <> GG_Adventure ) then exit;
	PC := GG_LocatePC( GB );

	{ Get the EChance, AChance, and MainDesc. }
	EChance := ScriptValue( event , GB , Source );
	AChance := ScriptValue( event , GB , Source );
	MainDesc := AS_GetString( Source , ExtractWord( Event ) );
	FormatMessageString( MainDesc , gb , source );

	{ Check randomly to see whether or not to add an ally. }
	if Random( 100 ) < AChance then begin
		AddArchAllyToScene( Adv , SCRIPT_DynamicEncounter , PC );
	end;

	{ Check randomly to see whether or not to add an enemy. }
	if Random( 100 ) < EChance then begin
		AddArchEnemyToScene( Adv , SCRIPT_DynamicEncounter , PC , MainDesc );
	end;


end; { ProcessEncounter }

Function NumberOfPlots( Part: GearPtr ): Integer;
	{ Check the number of plots this PART has loaded. }
var
	P: GearPtr;
	N: Integer;
begin
	P := Part^.InvCom;
	N := 0;

	while P <> Nil do begin
		if P^.G = GG_Plot then Inc( N );
		P := P^.Next;
	end;

	NumberOfPlots := N;
end;

Procedure ProcessStoryLine( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new story arc is about to be loaded. }
	{ This may be an invcomponent of an existing story (the source), }
	{ or it may be a global arc which is to be inserted as an invcom }
	{ of the adventure. Once loaded, global arcs are treated like }
	{ regular plots. }
var
	FName: String;
	Adv,Arc: GearPtr;
	LoadOK: Boolean;
begin
	FName := ExtractWord( Event );

	{ Error check - We need the ADVENTURE gear for this!!! }
	Adv := FindRoot( GB^.Scene );
	if ( Adv = Nil ) or ( Adv^.G <> GG_Adventure ) then Exit;

	if ( Source <> Nil ) and ( Source^.G = GG_Story ) and ( NumberOfPlots( Source ) >= Max_Plots_Per_Story ) then begin
		{ Can't load a new plot at this time. }
		IfFailure( Event , Source );

	end else if ( Source <> Nil ) and ( Source^.G = GG_Story ) and ( NumberOfPlots( Source ) >= Max_Plots_Per_Adventure ) then begin
		{ Can't load a new plot at this time. }
		IfFailure( Event , Source );

	end else begin
		{ First, find the file name of the plot file to look for. }
		if Source <> Nil then begin
			FName := AS_GetString( Source , FName );
		end else begin
			FName := '';
		end;

		{ Secondly, confirm the file name. }
		Arc := LoadGearPattern( FName , Series_Directory );

		if Arc <> Nil then begin
			{ Insert the arc, calling IfSuccess or IfFailure. }
			if Source^.G = GG_Story then begin
				LoadOK := InsertStoryArc( Source , Arc , GB );
			end else begin
				LoadOK := InsertGlobalArc( Adv , Arc , GB );
			end;

			if LoadOK then begin
				IfSuccess( Event );
			end else begin
				IfFailure( Event , Source );
			end;

		end else begin
			{ File was not loaded successfully. }
			IfFailure( Event , Source );
		end;
	end;
end;

Procedure ProcessBatchLoadPlot( var Trigger,Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A number of story arcs are about to be loaded. }
var
	FName: String;
	Adv,Arc: GearPtr;
	N,T: Integer;
begin
	{ Error check - We need the ADVENTURE gear for this!!! }
	Adv := FindRoot( GB^.Scene );
	if ( Adv = Nil ) or ( Adv^.G <> GG_Adventure ) or ( Source = Nil ) then Exit;

	{ First, find the plot pattern to look for. }
	FName := ExtractWord( Event );
	FName := AS_GetString( Source , FName );

	{ Next, find out how many plots to load. }
	N := ScriptValue( Event , GB , Source );

	{ Final error check- based on the config options, maybe exit. }
	if Load_Plots_At_Start and ( UpCase( Trigger ) <> 'START' ) then exit
	else if ( not Load_Plots_At_Start ) and ( UpCase( Trigger ) = 'START' ) then exit;

	for t := 1 to N do begin
		{ Secondly, confirm the file name. }
		Arc := LoadGearPattern( FName , Series_Directory );

		if Arc <> Nil then begin
			{ Insert the arc, calling IfSuccess or IfFailure. }
			if ( Source^.G = GG_Story ) and ( NumberOfPlots( Source ) <= Max_Plots_Per_Story ) then begin
				InsertStoryArc( Source , Arc , GB );
			end else if ( NumberOfPlots( Adv ) <= Max_Plots_Per_Adventure ) then begin
				InsertGlobalArc( Adv , Arc , GB );
			end else begin
				DisposeGear( Arc );
				break;
			end;
		end;
	end;
end;

Procedure ProcessXRanPlot( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ This will load a new plot for the story based upon the story }
	{ "extra random" descriptors. }
var
	FName: String;
	Arc: GearPtr;
	LoadOK: Boolean;
	Enemy,Mystery,BadThing: Integer;
begin
	{ Error check- this command only works from a story. }
	if ( Source = Nil ) or ( Source^.G <> GG_Story ) then begin
		{ Can't load a new Extra-Random plot from this source. }
		IfFailure( Event , Source );

	end else begin
		{ First, find the file name of the plot file to look for. }
		FName := ExtractWord( Event );
		if Source <> Nil then begin
			FName := AS_GetString( Source , FName );
		end else begin
			FName := '';
		end;

		{ Secondly, confirm the file name. }
		Enemy := NAttValue( Source^.NA , NAG_Narrative , NAS_XREnemy );
		Mystery := NAttValue( Source^.NA , NAG_Narrative , NAS_XRMystery );
		BadThing := NAttValue( Source^.NA , NAG_Narrative , NAS_XRBadThing );

		Arc := LoadXRanPlot( FName , Series_Directory , Enemy , Mystery , BadThing );

		{ Finally insert the plot. }
		if Arc <> Nil then begin
			{ Insert the arc, calling IfSuccess or IfFailure. }
			LoadOK := InsertStoryArc( Source , Arc , GB );

			if LoadOK then begin
				IfSuccess( Event );
			end else begin
				IfFailure( Event , Source );
			end;

		end else begin
			{ File was not loaded successfully. }
			IfFailure( Event , Source );
		end;
	end;
end;

Function AS_StoryInsertion( GB: GameBoardPtr; Source: GearPtr; FName: String ): Boolean;
	{ Attempt to load and initialize the requested story. }
var
	Adv,Story: GearPtr;
begin
	Story := LoadGearPattern( FName , Series_Directory );

	if Story <> Nil then begin
		{ Sub in the first element, if needed. }
		if Source^.G = GG_Faction then begin
			Story^.Stat[ 1 ] := Source^.S;
			SetSAtt( Story^.SA , 'ELEMENT1 <F>' );
			Adv := Source;
		end else if Source^.G = GG_Scene then begin
			Story^.Stat[ 1 ] := Source^.S;
			SetSAtt( Story^.SA , 'ELEMENT1 <S>' );
			Adv := GG_LocateAdventure( GB , Source );
		end else if Source^.G = GG_Story then begin
			Adv := Source;
		end else begin
			Adv := GG_LocateAdventure( GB , Source );
		end;

		if InsertStory( Adv , Story , GB ) then begin
			AS_StoryInsertion := True;
		end else begin
			AS_StoryInsertion := False;
		end;

	end else begin
		{ File was not loaded successfully. }
		AS_StoryInsertion := False;
	end;
end;

Procedure ProcessStartStory( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new story gear is about to be loaded. }
var
	FName: String;
begin
	{ First, find the file name of the plot file to look for. }
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
	end else begin
		FName := '';
	end;

	{ Call the above procedure to see if it works or not. }
	if AS_StoryInsertion( GB , Source , FName ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessGlobalStoryPattern( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A bunch of stories will be loaded at once. }
	{ This command takes two arguments: First, the description for the scene to which }
	{ the stories will be loaded; Second, a search pattern for the story files. }
	{ Stories will continually be added until either stories or scenes run out, }
	{ with no duplication of either. }
var
	FName,SceneDesc: String;
	Adv,Scene: GearPtr;
	FList,SceneList,TempSceneList,F,S,TS: SAttPtr;
	SceneNum,N: Integer;
begin
	{ First, find the scene description and the file pattern. }
	SceneDesc := ExtractWord( Event );
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
		SceneDesc := AS_GetString( Source , SceneDesc );
	end else begin
		FName := '';
		SceneDesc := '';
	end;

	{ Create the list of story files. }
	FList := CreateFileList( Series_Directory + FName );

	{ Create the list of scenes that match. }
	{ Storing the scenes as a list of string attributes doesn't make much sense, }
	{ but there are pre-existing functions to handle lists of strings, and those }
	{ make it worthwhile for a lazy guy like me. }
	Adv := GG_LocateAdventure( GB , Source );
	Scene := Adv^.SubCom;
	SceneList := Nil;
	while Scene <> Nil do begin
		if ( Scene^.G = GG_Scene ) and PartMatchesCriteria( SATtValue( Scene^.SA , 'TYPE' ) , SceneDesc ) then begin
			StoreSAtt( SceneList , BStr( Scene^.S ) );
		end;
		Scene := Scene^.Next;
	end;

	{ Keep going until we run out of scenes or run out of stories }
	TempSceneList := Nil;
	while ( SceneList <> Nil ) and ( FList <> Nil ) do
	begin
		{ Select a random filename }
		F := SelectRandomSAtt( FList );
		{ Copy the list of unused scenes to make
		  a temporary list of untried but available
		  scenes.  This allows us to ensure a given
		  Scene/File combination is never retried,
		  while still leaving an discarded Scene available
		  for use by other story files.
		}
		S := SceneList;
		while (S <> Nil) do begin
			StoreSAtt(TempSceneList,S^.Info);
			S := S^.Next;
		end;

 		while (TempSceneList <> Nil) do begin
			TS := SelectRandomSAtt( TempSceneList );
			Val( TS^.Info , SceneNum , N );
			if N <> 0 then SceneNum := 0;
			Scene := FindActualScene( GB , SceneNum );
			if AS_StoryInsertion( GB , Scene , F^.Info ) then begin
				S := SceneList;
				while (S^.Info <> TS^.Info) do S := S^.Next;
				RemoveSAtt(SceneList, S);
				DisposeSAtt( TempSceneList);
			end else begin
				RemoveSAtt( TempSceneList , TS );
			end;
		end;
		RemoveSAtt( FList , F );

	end;
	if FList <> Nil then DisposeSAtt( FList );
	if SceneList <> Nil then DisposeSAtt( SceneList );
end;

Procedure ProcessAttack( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Team 1 is going to attack Team 2. }
var
	t1,T2: Integer;
	Team1,Mek: GearPtr;
begin
	{ Error check - We need that gameboard! }
	if GB = Nil then Exit;

	{ Read the script values. }
	T1 := ScriptValue( Event , GB , Source );
	T2 := ScriptValue( Event , GB , Source );

	{ Find the attacking team, and set the enemy value. }
	Team1 := LocateTeam( GB , T1 );
	if Team1 <> Nil then begin
		SetNAtt( Team1^.NA , NAG_SideReaction , T2 , NAV_AreEnemies );
	end;

	{ Locate each member of the team and set AIType to SEEK AND DESTROY. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = T1 then begin
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_SeekAndDestroy );
		end;
		Mek := Mek^.Next;
	end;
end;

Procedure ProcessSalvage( GB: GameBoardPtr );
	{ It's looting time!!! Check every mecha on the game board; if it's }
	{ not operational but not destroyed, switch its TEAM to NAV_DefPlayerTeam. }
var
	Mek,M2,PC: GearPtr;
	CanScavenge: Boolean;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if GB = Nil then Exit;

	{ Check to see if the PC has the Scavenger talent. }
	PC := GG_LocatePC( GB );
	CanScavenge := HasTalent( PC , NAS_Scavenger );

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if NotDestroyed( Mek ) and ( not GearOperational( Mek ) ) then begin
			{ Remove any pilots that may be in the mek... }
			repeat
				M2 := ExtractPilot( Mek );
				if M2 <> Nil then DeployMek( GB , M2 , False );
			until M2 = Nil;

			SetNAtt( Mek^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
		end else if ( Mek^.G = GG_Mecha ) and ( not GearOperational( Mek ) ) and CanScavenge and ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) <> NAV_DefPlayerTeam ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin
			{ Remove any pilots that may be in the mek... }
			repeat
				M2 := ExtractPilot( Mek );
				if M2 <> Nil then DeployMek( GB , M2 , False );
			until M2 = Nil;

			M2 := SelectRandomGear( Mek^.SubCom );
			if NotDestroyed( M2 ) and ( M2^.S <> GS_Body ) and ( RollStep( SkillValue( PC , 15 ) ) > 15 ) then begin
				DelinkGear( Mek^.SubCom , M2 );
				SetNAtt( M2^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
				AppendGear( GB^.Meks , M2 );
			end;
		end;
		Mek := Mek^.Next;
	end;
end;

Procedure ProcessRetreat( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ When this command is invoked, all the functioning masters }
	{ belonging to the listed team are removed from the map. A }
	{ Number Of Units trigger is then set. }
var
	Team: Integer;
	Mek: GearPtr;
	P: Point;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if GB = Nil then Exit;

	{ Find out which team is running away. }
	Team := ScriptValue( event , GB , Source );

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if GearOperational( Mek ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) then begin
			P := GearCurrentLocation( Mek );
			SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_Y , 0 );
			RedrawTile( GB , P.X , P.Y );
		end;
		Mek := Mek^.Next;
	end;

	{ Set the trigger. }
	SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
end;

Procedure ProcessAirRaidSiren( GB: GameBoardPtr );
	{ When this command is invoked, all the functioning masters }
	{ belonging to all NPC teams are ordered to run for their lives. }
var
	Mek: GearPtr;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if GB = Nil then Exit;

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if GearOperational( Mek ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) <> NAV_DefPlayerTeam ) then begin
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_RunAway );
		end;
		Mek := Mek^.Next;
	end;
end;

Procedure ProcessGRunAway( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ When this command is invoked, the grabbed gear is removed }
	{ from the map. A Number Of Units trigger is then set. }
var
	Mek,NPC: GearPtr;
	P: Point;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if ( GB = Nil ) or ( Grabbed_Gear = Nil ) then Exit;

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if Mek = Grabbed_Gear then begin
			P := GearCurrentLocation( Mek );
			SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_Y , 0 );
			RedrawTile( GB , P.X , P.Y );

			{ Set the trigger. }
			SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( MEK^.NA , NAG_Location , NAS_Team ) ) );
		end else if IsMasterGear( Mek ) then begin
			NPC := LocatePilot( Mek );
			if ( NPC <> Nil ) and ( NPC = Grabbed_Gear ) then begin
				P := GearCurrentLocation( Mek );
				SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_Y , 0 );
				RedrawTile( GB , P.X , P.Y );

				{ Set the trigger. }
				SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( MEK^.NA , NAG_Location , NAS_Team ) ) );
			end;
		end;
		Mek := Mek^.Next;
	end;
end;


Procedure ProcessTime( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Advance the game clock by a specified amount. }
var
	N: LongInt;
begin
	{ Find out how much to adjust the value by. }
	N := ScriptValue( Event , GB , Source );


	QuickTime( GB , N );
end;

Procedure ProcessForceChat( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Force the player to talk with the specified NPC. }
var
	N: LongInt;
begin
	{ Find out which NPC to speak with. }
	N := ScriptValue( Event , GB , Source );

	if GB <> Nil then begin
		StoreSAtt( GB^.Trig , '!TALK ' + BStr( N ) );
	end;
end;

Procedure ProcessTrigger( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new trigger will be placed in the trigger queue. }
var
	BaseTrigger: String;
	N: LongInt;
begin
	{ Find out the trigger's details. }
	BaseTrigger := ExtractWord( Event );
	N := ScriptValue( Event , GB , Source );

	if GB <> Nil then begin
		StoreSAtt( GB^.Trig , BaseTrigger + BStr( N ) );
	end;
end;

Procedure ProcessTransform( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Alter the appearance of the SOURCE gear. }
var
	N: LongInt;
	S: String;
	Procedure SwapSAtts( tag: String );
	begin
		S := AS_GetString ( Source , tag + BStr( N ) );
		if S <> '' then SetSAtt( Source^.SA , tag + ' <' + S + '>' );
	end;
begin
	{ Find out which aspect to change to. }
	N := ScriptValue( Event , GB , Source );

	{Switch all known dispay descriptors. }
	SwapSAtts( 'ROGUECHAR' );
	SwapSAtts( 'NAME' );
	SwapSAtts( 'SDL_SPRITE' );
	SwapSAtts( 'SDL_COLORS' );
	SetNAtt( Source^.NA , NAG_Display , NAS_PrimaryFrame , NAttValue( Source^.NA , NAG_Display , N ) );

	if GB <> Nil then begin
		RedrawTile( GB , Source );
		{ While we're here, redo the shadow map. }
		UpdateShadowMap( GB );
	end;
end;

Procedure ProcessMoreText( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Load and display a text file. }
var
	FName: String;
	txt,L: SAttPtr;
begin
	{ First, find the file name of the text file to look for. }
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
	end else begin
		FName := '';
	end;

	{ Secondly, load and display the file. }
	if FName <> '' then begin
		txt := LoadStringList( Series_Directory + FName );


		if txt <> Nil then begin
			{ Process the text. }
			L := txt;
			while L <> Nil do begin
				FormatMessageString( L^.Info , GB , Source );
				L := L^.Next;
			end;

			MoreText( txt , 1 );
			DisposeSAtt( txt );

			{ Restore the display. }
			if IntMenu <> Nil then begin
				SetupInteractDisplay( TeamColor( GB , I_NPC ) );
				DisplayGearInfo( I_NPC , GB );
				DisplayGearInfo( I_PC , GB , ZONE_Menu );

			end else if GB <> Nil then begin
				GFCombatDisplay( GB );

			end;
		end;
	end;

end; { ProcessMoreText }

Procedure ProcessMoreMemo( var Event: String; GB: GameBoardPtr );
	{ View messages of a certain type - EMAIL, NEWS, or MEMO. }
var
	Key: String;
begin
	{ First, find the memo key to use. }
	Key := ExtractWord( Event );

	{ Secondly, send this to the memo browser. }
	BrowseMemoType( GB , Key );

	{ Finally, update the display. }
	GFCombatDisplay( GB );
end; { ProcessMoreMemo }

Procedure ProcessSeekGate( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Aim for a specific gate when entering the next level. }
var
	N: LongInt;
begin
	{ Find out which gate we're talking about. }
	N := ScriptValue( Event , GB , Source );

	SCRIPT_Gate_To_Seek := N;
end;

Procedure ProcessUpdateProps( GB: GameBoardPtr );
	{ Just send an UPDATE trigger to all items on the gameboard. }
var
	T: String;
begin
	T := 'UPDATE';
	if GB <> Nil then begin
		CheckTriggerAlongPath( T , GB , GB^.Meks , True );
	end;
end;

Procedure ProcessBlock( var T: String );
	{ Erase the trigger, so as to prevent other narrative gears }
	{ from acting upon it. }
begin
	{ Do I really need to comment this line? }
	T := '';
end;

Procedure ProcessAccept( var T: String );
	{ Set the trigger to ACCEPT so the CONDITIONACCEPTED function }
	{ knows that it's been accepted. }
begin
	{ Do I really need to comment this line? }
	T := 'ACCEPT';
end;

Procedure ProcessBomb( GB: GameBoardPtr );
	{ Drop a bomb on the town. Yay! }
begin
	RandomExplosion( GB );
end;

Procedure ProcessXPV( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Give some experience points to all PCs and lancemates. }
var
	XP,T,N,Ld: LongInt;
	M,PC: GearPtr;
begin
	{ Find out how much to give. }
	XP := ScriptValue( Event , GB , Source );

	{ Search for models to give XP to. }
	{ Do the first pass to count them, the second pass to award them. }
	if GB <> Nil then begin
		N := 0;
		Ld := 0;
		M := GB^.Meks;
		while M <> Nil do begin
			T := NAttValue( M^.NA , NAG_Location , NAS_Team );
			if ( T = NAV_DefPlayerTeam ) then begin
				{ At this time, also record the LEADERSHIP rating. }
				PC := LocatePilot( M );
				if ( PC <> Nil ) and ( NAttValue( PC^.NA , NAG_Skill , 39 ) > Ld ) then Ld := NAttValue( PC^.NA , NAG_Skill , 39 );
				if GearActive( M ) then Inc( N );
			end else if ( T = NAV_LancemateTeam ) and OnTheMap( M ) and GearActive( M ) then begin
				Inc( N );
			end;
			M := M^.Next;
		end;

		{ Based on the number of characters found, modify the XP award downwards. }
		if ( N > 1 ) and ( N > (( Ld + 1 ) div 2 ) ) then begin
			XP := XP div ( N - (( Ld + 1 ) div 2 ) );
			if XP < 1 then XP := 1;
		end;

		{ On the second pass actually give the XP. }
		M := GB^.Meks;
		while M <> Nil do begin
			T := NAttValue( M^.NA , NAG_Location , NAS_Team );
			if ( T = NAV_DefPlayerTeam ) then begin
				DoleExperience( M , XP );
			end else if ( T = NAV_LancemateTeam ) and OnTheMap( M ) then begin
				DoleExperience( M , XP );
			end;
			M := M^.Next;
		end;
	end;

	DialogMsg( ReplaceHash( MSgString( 'AS_XPV' ) , Bstr( XP ) ) );
end;


Procedure ProcessGSkillXP( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Give some skill experience points to the grabbed gear. }
var
	Sk,XP: LongInt;
begin
	{ Find out what skill to give XP for, and how much XP to give. }
	Sk := ScriptValue( Event , GB , Source );
	XP := ScriptValue( Event , GB , Source );

	{ As long as we have a grabbed gear, go for it! }
	if Grabbed_Gear <> Nil then begin
		DoleSkillExperience( Grabbed_Gear , Sk , XP );
	end;
end;

Procedure ProcessGMental( GB: GameBoardPtr );
	{ The grabbed gear is doing something. Make it wait, and spend }
	{ one mental point. }
begin
	{ As long as we have a grabbed gear, go for it! }
	if Grabbed_Gear <> Nil then begin
		WaitAMinute( GB , Grabbed_Gear , ReactionTime( Grabbed_Gear ) * 3 );
		AddMentalDown( Grabbed_Gear , 5 );
	end;
end;

Procedure ProcessGQuitLance( GB: GameBoardPtr );
	{ The grabbed gear will quit the lance. }
begin
	if Grabbed_Gear <> Nil then begin
		RemoveLancemate( GB , Grabbed_Gear );
	end;
end;

Procedure ProcessGSkillLevel( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Set the skill points for the grabbed gear. }
var
	Skill: NAttPtr;
	SkLvl: Integer;
	Pilot: GearPtr;
begin
	{ Find out what level the NPC should be at. }
	SkLvl := ( ScriptValue( Event , GB , Source ) div 7 ) + 3;
	if SkLvl < 1 then SkLvl := 1;

	{ As long as we have a grabbed gear, go for it! }
	Pilot := LocatePilot( Grabbed_Gear );
	if ( Pilot <> Nil ) then begin
		Skill := Pilot^.NA;
		while Skill <> Nil do begin
			if Skill^.G = NAG_Skill then begin
				Skill^.V := SkLvl;
			end;
			Skill := Skill^.Next;
		end;
	end;
end;

Procedure ProcessGAbsoluteLevel( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Set the skill points for the grabbed gear. }
	{ Unlike the above procedure, this one scales the skill points by a % based on }
	{ their current value. }
var
	Skill: NAttPtr;
	SkLvl: Integer;
begin
	{ Find out what level the NPC should be at. }
	SkLvl := ScriptValue( Event , GB , Source ) + 35;
	if SkLvl < 1 then SkLvl := 1;

	{ As long as we have a grabbed gear, go for it! }
	if ( Grabbed_Gear <> Nil ) then begin
		Skill := Grabbed_Gear^.NA;
		while Skill <> Nil do begin
			if Skill^.G = NAG_Skill then begin
				Skill^.V := ( Skill^.V * SkLvl ) div 100;
				if Skill^.V < 1 then Skill^.V := 1;
			end;
			Skill := Skill^.Next;
		end;
	end;
end;

Procedure ProcessGMoraleDmg( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Give some morale points to the grabbed gear. }
var
	M: LongInt;
begin
	{ Find out how much morale change. }
	M := ScriptValue( Event , GB , Source );

	{ As long as we have a grabbed gear, go for it! }
	if Grabbed_Gear <> Nil then begin
		AddMoraleDMG( Grabbed_Gear , M );
	end;
end;

Procedure ProcessDrawTerr( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Alter a single gameboard tile. }
var
	X,Y,T: LongInt;
begin
	{ Find out where and what to adjust. }
	X := ScriptValue( Event , GB , Source );
	Y := ScriptValue( Event , GB , Source );
	T := ScriptValue( Event , GB , Source );

	if ( GB <> NIl ) and OnTheMap( X , Y ) and ( T >= 1 ) and ( T <= NumTerr ) then begin
		GB^.Map[ X , Y ].terr := T;
		GB^.Map[ X , Y ].visible := False;
	end;
end;

Procedure ProcessMagicMap( GB: GameBoardPtr );
	{ Make every tile on the map visible, then redraw. }
var
	X,Y: Integer;
begin
	for X := 1 to XMax do begin
		for Y := 1 to YMax do begin
			GB^.Map[ X , Y ].Visible := True;
		end;
	end;
	GFCombatDisplay( GB );
end;

Procedure CheckMechaEquipped( GB: GameBoardPtr );
	{ A dynamic encounter is about to be entered. The PC is going to }
	{ want a mecha for it, most likely. }
var
	PC,Mek: GearPtr;
begin
	{ Error check - make sure we have a gameboard to start with. }
	if GB = Nil then Exit;

	{ Find the PC. If the PC doesn't have a mek equipped, then }
	{ prompt for one to be equipped. }
	PC := GG_LocatePC( GB );
	if ( PC <> Nil ) and ( PC^.G <> GG_Mecha ) then begin
		Mek := FindPilotsMecha( GB^.Meks , PC );
		if ( Mek = Nil ) and ( NumPCMeks( GB ) > 0 ) then begin
{$IFNDEF SDLMODE}
			DrawZoneBorder( ZONE_YesNoTotal , BorderBlue );
{$ENDIF}
			GameMSG( MsgString( 'ARENASCRIPT_CheckMechaEquipped' ) , ZONE_UsagePrompt , InfoGreen );
{$IFDEF SDLMODE}
			MechaSelectionMenu( GB , GB^.Meks , PC , ZONE_UsageMenu );
{$ELSE}
			MechaSelectionMenu( GB^.Meks , PC , ZONE_UsageMenu );
{$ENDIF}
		end;
	end;
end;

Procedure InvokeEvent( Event: String; GB: GameBoardPtr; Source: GearPtr; var Trigger: String );
	{ Do whatever is requested by game script EVENT. }
	{ SOURCE refers to the virtual gear which is currently being }
	{ used- it may be a SCENE gear, or a CONVERSATION gear, or }
	{ whatever else I might add in the future. }
var
	cmd: String;
begin
	while ( Event <> '' ) do begin
		cmd := UpCase( ExtractWord( Event ) );

		if SAttValue( Script_Macros , cmd ) <> '' then begin
			{ Install the macro. }
			InitiateMacro( Event , SAttValue( Script_Macros , cmd ) );

		end else if not Attempt_Gear_Grab( Cmd , Event , GB , Source ) then begin
			{ If this is a gear-grabbing command, our work here is done. }

		if cmd = 'EXIT' then ProcessExit( Event , GB , Source )
		else if cmd = 'GADDNATT' then ProcessGAddNAtt( Event , GB , Source )
		else if cmd = 'GSETNATT' then ProcessGSetNAtt( Event , GB , Source )
		else if cmd = 'GADDSTAT' then ProcessGAddStat( Event , GB , Source )
		else if cmd = 'GSETSTAT' then ProcessGSetStat( Event , GB , Source )
		else if cmd = 'GSETSATT' then ProcessGSetSAtt( Event , Source )
		else if cmd = 'DELETEGG' then ProcessDeleteGG( GB , Source )
		else if cmd = 'MOVEGG' then ProcessMoveGG( Event , GB , Source )
		else if cmd = 'DEPLOYGG' then ProcessDeployGG( Event , GB , Source )
		else if cmd = 'DYNAGG' then ProcessDynaGG( Event , GB , Source )
		else if cmd = 'GIVEGG' then ProcessGiveGG( GB )
		else if cmd = 'GNEWPART' then ProcessGNewPart( Event , GB , Source )
		else if cmd = 'RETURN' then ProcessReturn( GB )
		else if cmd = 'PRINT' then ProcessPrint( Event , GB , Source )
		else if cmd = 'ALERT' then ProcessAlert( Event , GB , Source )
		else if cmd = 'MEMO' then ProcessMemo( Event , GB , Source )
		else if cmd = 'NEWS' then ProcessNews( Event , GB , Source )
		else if cmd = 'EMAIL' then ProcessEMail( Event , GB , Source )
		else if cmd = 'HISTORY' then ProcessHistory( Event , GB , Source )
		else if cmd = 'VICTORY' then ProcessVictory( GB )
		else if cmd = 'VMSG' then ProcessValueMessage( Event , GB , Source )
		else if cmd = 'SAY' then ProcessSay( Event , GB , Source )
		else if cmd = 'SAYANYTHING' then ProcessSayAnything()
		else if cmd = 'IFGINPLAY' then ProcessIfGInPlay( Event , Source )
		else if cmd = 'IFGOK' then ProcessIfGOK( Event , Source )
		else if cmd = 'IFGSEXY' then ProcessIfGSexy( Event , GB , Source )
		else if cmd = 'IFGARCHENEMY' then ProcessIfGArchEnemy( Event , GB , Source )
		else if cmd = 'IFGARCHALLY' then ProcessIfGArchAlly( Event , GB , Source )
		else if cmd = 'IFFACTION' then ProcessIfFaction( Event , GB , Source )
		else if cmd = 'IFSCENE' then ProcessIfScene( Event , GB , Source )
		else if cmd = 'IFKEYITEM' then ProcessIfKeyItem( Event , GB , Source )
		else if cmd = 'IF=' then ProcessIfEqual( Event , GB , Source )
		else if cmd = 'IF#' then ProcessIfNotEqual( Event , GB , Source )
		else if cmd = 'IFG' then ProcessIfGreater( Event , GB , Source )
		else if cmd = 'IFSTORYLESS' then ProcessIfStoryless( Event , Source )
		else if cmd = 'IFYESNO' then ProcessIfYesNo( Event , GB , Source )
		else if cmd = 'IFNOOBJECTIONS' then ProcessIfNoObjections( Event , GB , Source )
		else if cmd = 'TORD' then ProcessTeamOrders( Event , GB , Source )
		else if cmd = 'COMPOSE' then ProcessCompose( Event , GB , Source )
		else if cmd = 'BLOCK' then ProcessBlock( Trigger )
		else if cmd = 'ACCEPT' then ProcessAccept( Trigger )
		else if cmd = 'NEWCHAT' then ProcessNewChat
		else if cmd = 'ENDCHAT' then ProcessEndChat
		else if cmd = 'GOTO' then ProcessGoto( Event , Source )
		else if cmd = 'ADDCHAT' then ProcessAddChat( Event , GB , Source )
		else if cmd = 'SEEKTERR' then ProcessSeekTerr( Event , GB , Source )
		else if cmd = 'SHOP' then ProcessShop( Event , GB , Source )
		else if cmd = 'SCHOOL' then ProcessSchool( Event , GB , Source )
		else if cmd = 'EXPRESSDELIVERY' then ProcessExpressDelivery( Event , GB , Source )
		else if cmd = 'ADVANCEPLOT' then ProcessAdvancePlot( Event , GB , Source )
		else if cmd = 'ENDSTORY' then ProcessEndStory( GB , Source )
		else if cmd = 'PURGESTORY' then ProcessPurgeStory( GB , Source )
		else if cmd = 'TREPUTATION' then ProcessTReputation( Event , GB , Source )
		else if cmd = 'XPV' then ProcessXPV( Event , GB , Source )
		else if cmd = 'MECHAPRIZE' then ProcessMechaPrize( Event , GB , Source )
		else if cmd = 'SETSCENEFACTION' then ProcessSetSceneFaction( Event , GB , Source )
		else if cmd = 'DELETEFACTION' then ProcessDeleteFaction( Event , GB , Source )
		else if cmd = 'NEWD' then ProcessNewD( Event , GB , Source )
		else if cmd = 'LOADD' then ProcessLoadD( Event , GB , Source )
		else if cmd = 'TSTOCKD' then ProcessTStockD( Event , GB , Source )
		else if cmd = 'WMECHA' then ProcessWMecha( Event , GB , Source )
		else if cmd = 'TMSTOCKD' then ProcessTMStockD( Event , GB , Source )
		else if cmd = 'ENCOUNTER' then ProcessEncounter( Event , GB , Source )
		else if cmd = 'STORYLINE' then ProcessStoryLine( Event , GB , Source )
		else if cmd = 'BATCHLOADPLOT' then ProcessBatchLoadPlot( Trigger , Event , GB , Source )
		else if cmd = 'XRANPLOT' then ProcessXRanPlot( Event , GB , Source )
		else if cmd = 'STARTSTORY' then ProcessStartStory( Event , GB , Source )
		else if cmd = 'GLOBALSTORYPATTERN' then ProcessGlobalStoryPattern( Event , GB , Source )
		else if cmd = 'ATTACK' then ProcessAttack( Event , GB , Source )
		else if cmd = 'SALVAGE' then ProcessSalvage( GB )
		else if cmd = 'RETREAT' then ProcessRetreat( Event , GB , Source )
		else if cmd = 'GRUNAWAY' then ProcessGRunAway( Event , GB , Source )
		else if cmd = 'AIRRAIDSIREN' then ProcessAirRaidSiren( GB )
		else if cmd = 'FORCECHAT' then ProcessForceChat( Event , GB , Source )
		else if cmd = 'TIME' then ProcessTime( Event , GB , Source )
		else if cmd = 'TRANSFORM' then ProcessTransform( Event , GB , Source )
		else if cmd = 'SEEKGATE' then ProcessSeekGate( Event , GB , Source )
		else if cmd = 'TRIGGER' then ProcessTrigger( Event , GB , Source )
		else if cmd = 'UPDATEPROPS' then ProcessUpdateProps( GB )
		else if cmd = 'MORETEXT' then ProcessMoreText( Event , GB , Source )
		else if cmd = 'MOREMEMO' then ProcessMoreMemo( Event , GB )
		else if cmd = 'BOMB' then ProcessBomb( GB )
		else if cmd = 'GSKILLXP' then ProcessGSkillXP( Event , GB , Source )
		else if cmd = 'GABSOLUTELEVEL' then ProcessGAbsoluteLevel( Event , GB , Source )
		else if cmd = 'GSKILLLEVEL' then ProcessGSkillLevel( Event , GB , Source )
		else if cmd = 'GMORALEDMG' then ProcessGMoraleDmg( Event , GB , Source )
		else if cmd = 'DRAWTERR' then ProcessDrawTerr( Event , GB , Source )
		else if cmd = 'MAGICMAP' then ProcessMagicMap( GB )
		else if cmd = 'GMENTAL' then ProcessGMental( GB )
		else if cmd = 'GQUITLANCE' then ProcessGQuitLance( GB )

		else if cmd <> '' then begin
					DialogMsg( 'ERROR: Unknown ASL command ' + cmd + ' in ' + GearName( Source ) );
					DialogMsg( 'CONTEXT: ' + event );
			end;

		end; { If not GrabGear }
	end;

	{ Process rounding-up events here. }
	if ( SCRIPT_DynamicEncounter <> Nil ) and ( SCRIPT_DynamicEncounter^.V > 0 ) then CheckMechaEquipped( GB );
end;

Procedure HandleChat( GB: GameBoardPtr; var FreeRumors: Integer );
	{ Call the CHAT procedure, then display the string that is returned. }
var
	msg: String;
begin
	msg := DoChatting( GB , I_Rumors , I_PC , I_NPC , I_Endurance , FreeRumors );
{$IFDEF SDLMODE}
	CHAT_Message := msg;
{$ELSE}
	GameMsg( msg , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	QuickTime( GB , 16 + Random( 15 ) );
end;

Procedure AddLancemate( GB: GameBoardPtr; NPC: GearPtr );
	{ Add the listed NPC to the PC's lance. }
begin
	{ This NPC will have to quit their current team to do this... }
	{ so, better set a trigger. }
	SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) ) );

	SetNAtt( NPC^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
end;

Procedure AttemptJoin( GB: GameBoardPtr );
	{ I_NPC will attempt to join the party. Yay! }
var
	LMP: Integer;	{ Lancemate Points needed }
begin
	{ Make sure we've got an NPC to deal with. }
	if I_NPC = Nil then Exit;

	{ Need two more available lancemate points than are currently in use. }
	LMP := LancematesPresent( GB ) + 2;
	if ReactionScore( GB^.Scene , I_PC , I_NPC ) < ( 50 - 2 * I_PC^.Stat[ STAT_Charm ] ) then begin
{$IFDEF SDLMODE}
		CHAT_Message := MsgString( 'JOIN_REFUSE' );
{$ELSE}
		GameMsg( MsgString( 'JOIN_REFUSE' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end else if FindPersonaPlot( FindRoot( GB^.Scene ) , NAttValue( I_NPC^.NA , NAG_Personal , NAS_CID ) ) <> Nil then begin
{$IFDEF SDLMODE}
		CHAT_Message := MsgString( 'JOIN_BUSY' );
{$ELSE}
		GameMsg( MsgString( 'JOIN_BUSY' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	end else if LMP > LancematePoints( I_PC ) then begin
{$IFDEF SDLMODE}
		CHAT_Message := MsgString( 'JOIN_NOPOINT' );
{$ELSE}
		GameMsg( MsgString( 'JOIN_NOPOINT' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}

	end else begin
{$IFDEF SDLMODE}
		CHAT_Message := MsgString( 'JOIN_JOIN' );
{$ELSE}
		GameMsg( MsgString( 'JOIN_JOIN' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
		AddLancemate( GB , I_NPC );
	end;
end;

Procedure RemoveLancemate( GB: GameBoardPtr; NPC: GearPtr );
	{ Remove NPC from the party. }
	{ ERROR CHECK: Lancemates cannot be removed in dynamic scenes! }
begin
	if not IsInvCom( GB^.Scene ) then begin
		SetSAtt( NPC^.SA , 'TEAMDATA <Ally>' );
		ChooseTeam( NPC , GB^.Scene );
	end;
end;

Procedure HandleQuit( GB: GameBoardPtr );
	{ I_NPC will quit the party. }
begin
	if I_NPC = Nil then Exit;
{$IFDEF SDLMODE}
	CHAT_Message := MsgString( 'QUIT_LANCE' );
{$ELSE}
	GameMsg( MsgString( 'QUIT_LANCE' ) , ZONE_InteractMsg , InfoHiLight );
{$ENDIF}
	RemoveLancemate( GB , I_NPC );
end;

{$IFDEF SDLMODE}
Procedure InteractRedraw;
	{ Redraw the screen for whatever interaction is going to go on. }
begin
	QuickCombatDisplay( ASRD_GameBoard );
	SetupInteractDisplay( TeamColor( ASRD_GameBoard , I_NPC ) );
	if I_NPC <> Nil then begin
		DisplayInteractStatus( ASRD_GameBoard , I_NPC , CHAT_React , I_Endurance );
		DisplayGearInfo( I_NPC , ASRD_GameBoard );
	end;
	NFGameMsg( CHAT_Message , ZONE_InteractMsg , InfoHiLight );
end;
{$ENDIF}

Procedure PruneNothings( var LList: GearPtr );
	{ Traverse the list. Anything marked as ABSOLUTELYNOTHING gets deleted, along with }
	{ all of its children gears. That's tough, but that's life... }
var
	L,L2: GearPtr;
begin
	L := LList;
	while L <> Nil do begin
		L2 := L^.Next;

		if L^.G = GG_AbsolutelyNothing then begin
			RemoveGear( LList , L );
		end else begin
			PruneNothings( L^.SubCom );
			PruneNothings( L^.InvCom );
		end;

		L := L2;
	end;
end;

Procedure HandleInteract( GB: GameBoardPtr; PC,NPC,Interact: GearPtr );
	{ The player has just entered a conversation. }
	{ HOW THIS WORKS: The interaction menu is built by an ASL script. }
	{ the player selects one of the provided responses, which will }
	{ either trigger another script ( V >= 0 ) or call one of the }
	{ standard interaction routines ( V < 0 ) }
var
	IntScr: String;		{ Interaction Script }
	N,FreeRumors: Integer;
	RTT: LongInt;		{ ReTalk Time }
	T: String;
begin
	{ Start by allocating the menu. }
	IntMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );

	{ Set up the display. }
	SetupInteractDisplay( TeamColor( GB , NPC ) );

	DisplayGearInfo( NPC , GB );
	DisplayGearInfo( PC , GB , ZONE_Menu );

	{ Initialize interaction variables. }
	I_PC := PC;
	I_NPC := NPC;
	I_Rumors := CreateRumorList( GB , PC , NPC );
{$IFDEF SDLMODE}
	ASRD_GameBoard := GB;
{$ENDIF}

	{ If the NPC is fully recharged from talking with you last time, }
	{ get full endurance of 10. Otherwise, only gets partial endurance. }
	if NAttValue( NPC^.NA , NAG_Personal , NAS_ReTalk ) > GB^.ComTime then begin
		I_Endurance := 1;
	end else begin
		I_Endurance := 10;
	end;

	{ Determine the number of "Free" rumors the PC will get. }
	FreeRumors := 0;
	N := ReactionScore( GB^.Scene , PC , NPC );
	if N > 20 then FreeRumors := ( N - 13 ) div 7;
	N := CStat( PC , STAT_Charm );
	if N > 12 then FreeRumors := FreeRumors + Random( N - 11 );

	{ Invoke the greeting event. }
	if ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( Interact <> Nil ) and ( Interact^.Parent <> Nil ) and ( Interact^.Parent^.G = GG_Scene ) then begin
		{ Lancemates won't use their local personas while part of the lance. }
		{ Hence the mother of all conditionals above... }
		IntScr := 'SAYANYTHING NEWCHAT';
	end else if Interact <> Nil then begin
		IntScr := AS_GetString( Interact , 'GREETING' );
	end else begin
		{ If there is no standard greeting, set the event to }
		{ build the default interaction menu. }
		IntScr := 'SAYANYTHING NEWCHAT';
	end;
	T := 'Greeting';
	InvokeEvent( IntScr , GB , Interact , T );

	repeat
		{ Print the NPC description. }
		{ This could change depending upon what the PC does. }
{$IFNDEF SDLMODE}
		{ SDLMode handles InteractStatus in the redraw, so there's no need to }
		{ do it here if we're in SDL mode... }
		DisplayInteractStatus( GB , NPC , ReactionScore( GB^.Scene , PC , NPC ) , I_Endurance );
{$ENDIF}

		if IntMenu^.NumItem > 0 then begin
{$IFDEF SDLMODE}
			ASRD_GameBoard := GB;
			CHAT_React := ReactionScore( GB^.Scene , PC , NPC );
			N := SelectMenu( IntMenu , @InteractRedraw );
{$ELSE}
			N := SelectMenu( IntMenu );
{$ENDIF}
		end else begin
			{ If the menu is empty, we must leave this procedure. }
			{ More importantly, we better not do anything in }
			{ the conditional below... Set N to equal a "goodbye" result. }
			N := -1;
		end;

		if N >= 0 then begin
			{ One of the placed options have been triggered. }
			{ Attempt to find the appropriate script to }
			{ invoke. }
			IntScr := AS_GetString( Interact , 'RESULT' + BStr( N ) );
			InvokeEvent( IntScr , GB , Interact , T );

		{ It wasn't a scripted response chosen. }
		{ Handle one of the standard options. }
		end else if N = CMD_Chat then begin
			HandleChat( GB , FreeRumors );

		end else if N = CMD_Join then begin
			AttemptJoin( GB );

		end else if N = CMD_Quit then begin
			HandleQuit( GB );

		end;

	until ( N = -1 ) or ( IntMenu^.NumItem < 1 ) or ( I_Endurance < 1 ) or ( I_NPC = Nil );

	{ If the menu is empty, pause for a minute. Or at least a keypress. }
	if IntMenu^.NumItem < 1 then begin
{$IFDEF SDLMODE}
		InteractRedraw;
		GHFlip;
{$ENDIF}
		EndOfGameMoreKey;
	end;

	{ If the conversation ended because the NPC ran out of patience, }
	{ store a negative reaction modifier. }
	if I_Endurance < 1 then begin
		AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) , -5 );

		{ Overchatting is a SOCIABLE action. }
		AddReputation( PC , 3 , 1 );
	end;

	{ Check - If this persona gear is the child of a gear whose type }
	{ is GG_ABSOLUTELYNOTHING, chances are that it used to be a plot }
	{ but it's been advanced by the conversation. Delete it. }
	if Interact <> Nil then begin
		Interact := FindRoot( Interact );
		PruneNothings( Interact );
	end;

	{ Set the ReTalk value. }
	{ Base retalk time is 1500 ticks; may be raised or lowered depending }
	{ upon the NPC's ENDURANCE and also how well the NPC likes the PC. }
	if ( I_NPC <> Nil ) and ( SCRIPT_DynamicEncounter = Nil ) then begin
		RTT := GB^.ComTime + 1500 - ( 15 * ReactionScore( GB^.Scene , PC , NPC ) ) - ( 50 * I_Endurance );
		if RTT < ( GB^.ComTime + AP_Minute ) then RTT := GB^.ComTime + AP_Minute;
		SetNAtt( NPC^.NA , NAG_Personal , NAS_ReTalk , RTT );
	end;

	{ Get rid of the menu. }
	DisposeRPGMenu( IntMenu );
	DisposeSAtt( I_Rumors );

	{ Restore the display. }
	ClrZone( ZONE_InteractTotal );
end;

Procedure ForceInteract( GB: GameBoardPtr; CID: LongInt );
	{ Attempt to force the PC to converse with the provided NPC. }
var
	PC,NPC,Interact: GearPtr;
begin
	{ Locate all the required elements. }
	PC := LocatePilot( GG_LocatePC( GB ) );
	NPC := SeekGearByCID( GB^.Meks , CID );
	if NPC = Nil then NPC := SeekGearByCID( FindRoot( GB^.Scene ) , CID );
	Interact := SeekPersona( GB , CID );

	if ( PC <> Nil ) and ( NPC <> Nil ) and NotDestroyed( PC ) then begin
		{ Before initiating the conversation, get rid of the }
		{ recharge timer, since the NPC initiated this chat }
		{ and won't get pissed off. }
		SetNAtt( NPC^.NA , NAG_Personal , NAS_ReTalk , 0 );

		{ Hand everything to the interaction procedure. }
		HandleInteract( GB , PC , NPC , Interact );
	end;
	DisplayMap( GB );
end;

Function TriggerGearScript( GB: GameBoardPtr; Source: GearPtr; var Trigger: String ): Boolean;
	{ Attempt to trigger the requested script in this gear. If the }
	{ script cannot be found, then do nothing. }
var
	E: String;
	it: Boolean;
begin
	it := False;
	if Source <> Nil then begin
		E := AS_GetString( Source , Trigger );
		if E <> '' then begin
			InvokeEvent( E , GB , Source , Trigger );
			it := True;
		end;
	end;
	TriggerGearScript := it;
end;

Function CheckTriggerAlongPath( var T: String; GB: GameBoardPtr; Plot: GearPtr; CheckAll: Boolean ): Boolean;
	{ Check all the active narrative gears in this list (plots, stories, and factions) }
	{ looking for events which match the provided trigger. }
	{ Return TRUE if an event was invoked, or FALSE if no event was encountered. }
var
	P2: GearPtr;
	it,I2: Boolean;
begin
	it := False;
	while ( Plot <> Nil ) and ( T <> '' ) do begin
		P2 := Plot^.Next;
		if CheckAll or ( Plot^.G = GG_Plot ) or ( Plot^.G = GG_Faction ) or ( Plot^.G = GG_Story ) or ( Plot^.G = GG_Adventure ) then begin
			{ FACTIONs and STORYs can hold active plots in their InvCom. }
			if ( Plot^.G = GG_Faction ) or ( Plot^.G = GG_Story ) or ( Plot^.G = GG_Adventure ) then CheckTriggerAlongPath( T , GB , Plot^.InvCom , CheckAll);

			I2 := TriggerGearScript( GB , Plot , T );
			it := it or I2;

			{ The trigger above might have changed the }
			{ structure, so reset P2. }
			P2 := Plot^.Next;

			{ Remove the plot, if it's been advanced. }
			if Plot^.G = GG_AbsolutelyNothing then RemoveGear( Plot^.Parent^.InvCom , Plot );
		end;
		Plot := P2;
	end;
	CheckTriggerAlongPath := it;
end;

Procedure HandleTriggers( GB: GameBoardPtr );
	{ Go through the list of triggers, enacting events if any are }
	{ found. Deallocate the triggers as they are processed. }
var
	TList,TP: SAttPtr;	{ Trigger List , Trigger Pointer }
	E: String;
begin
	IntMenu := Nil;

	{ Only try to implement triggers if this gameboard has a scenario }
	{ defined. }
	if GB^.Scene <> Nil then begin

		{ Some of the events we process might add their own }
		{ triggers to the list. So, we check all the triggers }
		{ currently set, then look at the GB^.Trig list again }
		{ to see if any more got put there. }
		while GB^.Trig <> Nil do begin
			{ Copy the list pointer to TList, clear the }
			{ list pointer from GB, and set the pointer }
			{ to the first trigger. }
			TList := GB^.Trig;
			GB^.Trig := Nil;
			TP := TList;

			while TP <> Nil do begin
				{ Brand New Thing - v0.531 July 18 2002 }
				{ Commands can be embedded in the triggers list. }
				{ The actual point of this is to allow scripts }
				{ to automatically activate interactions & props. }
				if ( Length( TP^.Info ) > 0 ) and ( TP^.Info[1] = '!' ) then begin
					{ Copy the command. }
					E := UpCase( ExtractWord( TP^.Info ) );
					DeleteFirstChar( E );

					if E = 'TALK' then begin
						ForceInteract( GB , ExtractValue( TP^.Info ) );
					end;

					{ Clear this trigger. }
					TP^.Info := '';

				end else if TP^.Info <> '' then begin
					{ If there is a SAtt in the scenario description }
					{ named after this trigger description, it will }
					{ happen now. First, see if such an event exists. }

					{ Check the PLOTS, FACTIONS and STORIES in }
					{ Adventure/InvCom first. }
					if GB^.Scene^.Parent <> Nil then begin
						CheckTriggerAlongPath( TP^.Info , GB , FindRoot( GB^.Scene ) , False );
					end;

					{ Check the current scene last. }
					if TP^.Info <> '' then TriggerGearScript( GB , GB^.Scene , TP^.Info );

				end;

				TP := TP^.Next;
			end;

			{ Get rid of the trigger list. }
			DisposeSAtt( TList );

		end;
	end;
end;

initialization
	SCRIPT_DynamicEncounter := Nil;
	Grabbed_Gear := Nil;
	Script_Macros := LoadStringList( Script_Macro_File );
	Value_Macros := LoadStringList( Value_Macro_File );

	lancemate_tactics_persona := LoadFile( 'lmtactics.txt' , Data_Directory );

finalization
	if SCRIPT_DynamicEncounter <> Nil then begin
		DisposeGear( SCRIPT_DynamicEncounter );
	end;
	DisposeSAtt( Script_Macros );
	DisposeSAtt( Value_Macros );
	DisposeGear( lancemate_tactics_persona );

end.
