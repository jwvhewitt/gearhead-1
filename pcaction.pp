unit pcaction;
	{ This unit specifically handles PC actions. }
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

Procedure PCSaveCampaign( Camp: CampaignPtr; PC: gearPtr; PrintMsg: Boolean );
Procedure DoTraining( GB: GameBoardPtr; PC: GearPtr );
Procedure GetPlayerInput( Mek: GearPtr; Camp: CampaignPtr );


implementation

{$IFDEF SDLMODE}
uses ability,action,aibrain,arenacfe,arenascript,backpack,
     damage,effects,gearutil,gflooker,ghchars,ghparser,
     ghprop,ghswag,ghweapon,interact,menugear,movement,
     playwright,randchar,rpgdice,skilluse,texutil,ui4gh,
     sdlgfx,sdlinfo,sdlmap,sdlmenus;
{$ELSE}
uses ability,action,aibrain,arenacfe,arenascript,backpack,
     damage,effects,gearutil,gflooker,ghchars,ghparser,
     ghprop,ghswag,ghweapon,interact,menugear,movement,
     playwright,randchar,rpgdice,skilluse,texutil,ui4gh,
     congfx,coninfo,conmap,conmenus,context;
{$ENDIF}

const
	{ This array cross-references the RL direction key with }
	{ the gearhead direction number it corresponds to. }
	Roguelike_D: Array [1..9] of Byte = ( 3, 2, 1, 4, 0, 0, 5, 6, 7 );
	Reverse_RL_D: Array [0..7] of Byte = ( 6 , 3 , 2 , 1 , 4 , 7, 8 , 9 );

{$IFDEF SDLMODE}
var
	PCACTIONRD_PC: GearPtr;
	PCACTIONRD_GB: GameBoardPtr;
Procedure PCActionRedraw;
	{ Redraw the map and the PC's info. }
begin
	QuickCombatDisplay( PCACTIONRD_GB );
	DisplayGearInfo( PCACTIONRD_PC , PCACTIONRD_GB );
end;

Procedure PCSRedraw;
	{ Redraw the map and the PC's info. }
begin
	QuickCombatDisplay( PCACTIONRD_GB );
	DisplayGearInfo( PCACTIONRD_PC , PCACTIONRD_GB );
	SetupMemoDisplay;
end;
{$ENDIF}


Procedure FHQ_Rename( GB: GameBoardPtr; NPC: GearPtr );
	{ Enter a new name for NPC. }
var
	name: String;
begin
{$IFDEF SDLMODE}
	name := GetStringFromUser( ReplaceHash( MsgString( 'FHQ_Rename_Prompt' ) , GearName( NPC ) ) , @PCActionRedraw );
{$ELSE}
	name := GetStringFromUser( ReplaceHash( MsgString( 'FHQ_Rename_Prompt' ) , GearName( NPC ) ) );
	GFCombatDisplay( GB );
{$ENDIF}
	if name <> '' then SetSAtt( NPC^.SA , 'name <' + name + '>' );
end;


Procedure FHQ_Rejoin( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ NPC will rejoin the party if there's enough room. }
begin
	if LancematesPresent( GB ) < LancematePoints( PC ) then begin
		DialogMsg( ReplaceHash( MsgString( 'REJOIN_OK' ) , GearName( NPC ) ) );
		AddLancemate( GB , NPC );
	end else begin
		DialogMsg( ReplaceHash( MsgString( 'REJOIN_DontWant' ) , GearName( NPC ) ) );
	end;
end;

Procedure AutoTraining( GB: GameBoardPtr; var NPC: GearPtr );
	{ The NPC in question is going to raise some skills. }
var
	N,T: Integer;
	FXP: LongInt;
	TrainedSome: Boolean;
	M,M2: GearPtr;
	Gene: String;
begin
	TrainedSome := False;
	repeat
		FXP := NAttValue( NPC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( NPC^.NA , NAG_Experience , NAS_SpentXP );
		{ Determine how many skills or stats may be trained. }
		N := 0;
		for t := 1 to NumSkill do begin
			if ( NAttValue( NPC^.NA , NAG_SKill , T ) > 0 ) and ( SkillAdvCost( NPC , NAttValue( NPC^.NA , NAG_SKill , T ) ) <= FXP ) then begin
				Inc( N );
			end;
		end;

		if N > 0 then begin
			N := Random( N );
			
			for t := 1 to NumSkill do begin
				if ( NAttValue( NPC^.NA , NAG_SKill , T ) > 0 ) and ( SkillAdvCost( NPC , NAttValue( NPC^.NA , NAG_SKill , T ) ) <= FXP ) then begin
					if N = 0 then begin
						AddNAtt( NPC^.NA , NAG_Experience , NAS_SpentXP , SkillAdvCost( NPC , NAttValue( NPC^.NA , NAG_SKill , T ) ) );
						AddNAtt( NPC^.NA , NAG_Skill , T , 1 );
						dialogmsg( ReplaceHash( ReplaceHash( MsgString( 'AUTOTRAIN_LEARN' ) , GearName( NPC ) ) , SkillMan[ T ].Name ) );
						TrainedSome := True;
						N := 5;
					end;
					Dec( N );
				end;
			end;
		end;
	until N < 1;

	{ Free XP now becomes Freaky XP... check for evolution. }
	FXP := NAttValue( NPC^.NA , NAG_GearOps , NAS_EvolveAt );
	if ( FXP > 0 ) and ( NAttValue( NPC^.NA , NAG_Experience , NAS_TotalXP ) > FXP ) then begin
		{ Search the monster list for another creature which is: 1) from the }
		{ same genepool as our original, and 2) more powerful. }
		M := WMOnList;
		Gene := UpCase( SATtValue( NPC^.SA , 'GENEPOOL' ) );
		N := 0;
		while M <> Nil do begin
			if ( UpCase( SAttValue( M^.SA , 'GENEPOOL' ) ) = Gene ) and ( M^.V > NPC^.V ) then Inc( N );
			M := M^.Next;
		end;

		{ If at least one such monster has been found, }
		{ it's time to do the evolution! }
		if N > 0 then begin
			N := Random( N );
			M2 := Nil;
			M := WMonList;
			while M <> Nil do begin
				if ( UpCase( SAttValue( M^.SA , 'GENEPOOL' ) ) = Gene ) and ( M^.V > NPC^.V ) then begin
					Dec( N );
					if N = -1 then M2 := M;
				end;
				M := M^.Next;
			end;

			{ We've selected a new body. Change over. }
			if ( M2 <> Nil ) and ( NPC^.Parent = Nil ) then begin
				{ First, make the current monster drop everything }
				{ it's carrying. }
				ShakeDown( GB , NPC , NAttValue( NPC^.NA , NAG_Location , NAS_X ) , NAttValue( NPC^.NA , NAG_Location , NAS_Y ) );

				{ Then copy the new body to the map. }
				M := CloneGear( M2 );
				{ Insert M into the map. }
				DeployMek( GB , M , True );

				DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'AUTOTRAIN_EVOLVE' ) , GearName( NPC ) ) , GearName( M ) ) );

				{ Copy over name, XP, team, location, and skills. }
				SetSAtt( M^.SA , 'name <' + GearName( NPC ) + '>' );
				SetNAtt( M^.NA , NAG_Experience , NAS_SpentXP , NAttValue( NPC^.NA , NAG_Experience , NAS_SpentXP ) );
				SetNAtt( M^.NA , NAG_Experience , NAS_TotalXP , NAttValue( NPC^.NA , NAG_Experience , NAS_TotalXP ) );
				SetNAtt( M^.NA , NAG_Location , NAS_Team , NAttValue( NPC^.NA , NAG_Location , NAS_Team ) );
				SetNAtt( M^.NA , NAG_Location , NAS_X , NAttValue( NPC^.NA , NAG_Location , NAS_X ) );
				SetNAtt( M^.NA , NAG_Location , NAS_Y , NAttValue( NPC^.NA , NAG_Location , NAS_Y ) );
				SetNAtt( M^.NA , NAG_Personal , NAS_CID , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) );
				SetNAtt( M^.NA , NAG_CharDescription , NAS_CharType , NAttValue( NPC^.NA , NAG_CharDescription , NAS_CharType ) );
				GearUp( M );

				for t := 1 to NumSkill do begin
					if NAttValue( NPC^.NA , NAG_Skill , T ) > NAttValue( M^.NA , NAG_Skill , T ) then SetNAtt( M^.NA , NAG_Skill , T , NAttValue( NPC^.NA , NAG_Skill , T ) );
				end;

				TrainedSome := True;

				{ Now, delete the original. }
				RemoveGear( GB^.Meks , NPC );
				NPC := M;
			end;
		end;
	end;

	if not TrainedSome then DialogMsg( ReplaceHash( MsgString( 'AUTOTRAIN_FAIL' ) , GearName( NPC ) ) );
end;

Procedure FHQ_Disassemble( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ Robot NPC is no longer desired. Disassemble it into spare parts, delete the NPC, }
	{ then give the parts to PC. }
var
	M: Integer;
begin
	{ Error check- NPC must be on the gameboard. }
	if not IsFoundAlongTrack( GB^.Meks , NPC ) then Exit;

	{ First, make the robot drop everything it's carrying. }
	ShakeDown( GB , NPC , NAttValue( NPC^.NA , NAG_Location , NAS_X ) , NAttValue( NPC^.NA , NAG_Location , NAS_Y ) );

	{ Print a message. }
	DialogMsg( ReplaceHash( MsgString( 'FHQ_DIS_Doing' ) , GearName( NPC ) ) );

	{ The size of the spare parts is to be determined by the weight of the robot. }
	M := GearMass( NPC );

	{ Delete the NPC. }
	RemoveGear( GB^.Meks , NPC );

	{ Get the spare parts. }
	NPC := LoadNewSTC( 'SPAREPARTS-1' );
	NPC^.V := M * 5;
	InsertInvCom( PC , NPC );
end;

Procedure FHQ_ThisLancemateWasSelected( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ NPC was selected by the lancemate browser. Allow the PC to train, }
	{ equip, or dismiss this character. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	if IsSafeArea( GB ) or OnTheMap( NPC ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_LMV_Equip' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'FHQ_LMV_Train' ) , 2 );

	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) <> 0 ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_SelectMecha' ) , 4 );
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) or ( UpCase( SAttValue( NPC^.SA , 'JOB' ) ) = 'ROBOT' ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_Rename' ) , 5 );
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) and ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_Rejoin' ) , 6 );
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and IsSubCom( GB^.Scene ) and IsSAfeArea( GB ) and OnTheMap( NPC ) and ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_LMV_Dismiss' ) , 3 );
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) and ( UpCase( SAttValue( NPC^.SA , 'JOB' ) ) = 'ROBOT' ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_Disassemble' ) , 7 );

	AddRPGMenuItem( RPM , MsgString( 'FHQ_PartEditor' ) , 8 );

	AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

	repeat
{$IFDEF SDLMODE}
		PCACTIONRD_PC := NPC;
		n := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
		DisplayGearInfo( NPC , GB );
		n := SelectMenu( RPM );
{$ENDIF}
		case N of
			1: 	LancemateBackpack( GB , PC , NPC );
			2: 	if NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) <> 0 then DoTraining( GB , NPC )
				else AutoTraining( GB , NPC );
			3: 	begin
				RemoveLancemate( GB , NPC );
				DialogMsg( ReplaceHash( MsgString( 'FHQ_LMV_Removed' ) , GearName( NPC ) ) );
				N := -1;
				end;
			4: 	FHQ_SelectMechaForPilot( GB , NPC );
			5: 	FHQ_Rename( GB , NPC );
			6: 	FHQ_Rejoin( GB , PC , NPC );
			7:	begin
				FHQ_Disassemble( GB , PC , NPC );
				N := -1;
				end;
			8:
{$IFDEF SDLMODE}
				MechaPartBrowser( NPC , @PCActionRedraw );
{$ELSE}
				MechaPartBrowser( NPC );
{$ENDIF}
		end;
	until N = -1;
	DisposeRPGMenu( RPM );
end;

Procedure FieldHQ( GB: GameBoardPtr; PC: GearPtr );
	{ View the PC's lancemates. This menu should allow the PC to view, equip, }
	{ train and dismiss these characters. }
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
var
	RPM: RPGMenuPtr;
	N: Integer;
	M: GearPtr;
begin
	repeat
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
		M := GB^.Meks;
		N := 1;
		while M <> Nil do begin
			if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
				AddRPGMenuItem( RPM , LanceMateMenuName( M ) , N );
			end else if ( NAttValue( M^.NA , NAG_CharDescription , NAS_CharType ) = NAV_CTLancemate ) and ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) = 0 ) Then begin
				AddRPGMenuItem( RPM , LanceMateMenuName( M ) , N );
			end else if ( M^.G <> GG_Character ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then begin
				AddRPGMenuItem( RPM , LanceMateMenuName( M ) , N );
			end;
			M := M^.Next;
			Inc( N );
		end;
		RPMSortAlpha( RPM );
		AddRPGMenuItem( RPM , MSgString( 'EXIT' ) , -1 );

		{ Get a selection from the menu. }
{$IFDEF SDLMODE}
		n := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
		n := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N > 0 Then begin
			M := RetrieveGearSib( GB^.Meks , N );
			if M^.G = GG_Character then begin
				FHQ_ThisLancemateWasSelected( GB , PC , M );
			end else begin
				FHQ_ThisWargearWasSelected( GB , GB^.Meks , PC , M );
			end;
		end;

	until N = -1;
end;


Procedure CheckHiddenMetaterrain( GB: GameBoardPtr; Mek: GearPtr );
	{ Some metaterrain might be hidden. If any hidden metaterrain }
	{ is located, reveal it and run its REVEAL trigger. }
var
	MT: GearPtr;
	T: String;
	P: Point;
begin
	{ First record the PC's current position, for future reference. }
	P := GearCurrentLocation( Mek );

	{ Look through all the gears on the board, searching for metaterrain. }
	MT := GB^.Meks;
	while MT <> Nil do begin
		{ If this terrain matches our basic criteria, }
		{ we'll perform the next few tests. }
		if ( MT^.G = GG_MetaTerrain ) and ( MT^.Stat[ STAT_MetaVisibility ] > 0 ) and ( Range( MT , P.X , P.Y ) <= 1 ) then begin
			{ Roll the PC's INVESTIGATION skill. If it beats }
			{ the terrain's concealment score, reveal it. }
			if RollStep( SkillValue( Mek , NAS_Investigation ) ) > MT^.Stat[ STAT_MetaVisibility ] then begin
				MT^.Stat[ STAT_MetaVisibility ] := 0;
				T := 'REVEAL';
				TriggerGearScript( GB , MT , T );
				VisionCheck( GB , Mek );
			end;
		end;

		MT := MT^.Next;
	end;
end;

Procedure PCSearch( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will search for enemy units and hidden things. }
	{ This action costs MENTAL. }
var
	Mek: GearPtr;
begin
	{ Costs one point of MENTAL and an action. }
	AddMentalDown( PC , 1 );
	WaitAMinute( GB , PC , ReactionTime( PC ) );

	{ Look through all the gears on the board, searching for ones }
	{ that aren't visible yet. }
	{ Note that by searching in this way, the PC will not be vunerable }
	{ to being spotted himself. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if OnTheMap( Mek ) and not MekCanSeeTarget( GB , PC , Mek ) then begin
			if IsMasterGear( Mek ) and CheckLOS( GB , PC , Mek ) then begin
				{ The mek has just been spotted. }
				RevealMek( GB , Mek , PC );
			end;
		end;
		Mek := Mek^.Next;
	end;
	CheckHiddenMetaTerrain( GB , PC );
end;

Procedure MemoBrowser( GB: GameBoardPtr; PC: GearPtr );
	{ Find all the memos that the player has accumulated, then allow }
	{ them to be browsed through, then restore the display afterwards. }
var
	MainMenu: RPGMenuPtr;
	CRating,A: Integer;
begin
	CRating := PCommRating( PC );
	if CRating < 1 then begin
		DialogMsg( MsgString( 'MEMO_NoBrowser' ) );
		Exit;
	end;

	if CRating >= PCC_EMail then begin
{$IFNDEF SDLMODE}
		SetupMemoDisplay;
{$ENDIF}
		MainMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoText );
		AddRPGMenuItem( MainMenu , MsgString( 'MEMO_ReadMemo' ) , PCC_Memo );
		if CRating >= PCC_EMail then AddRPGMenuItem( MainMenu , MsgString( 'MEMO_ReadEMail' ) , PCC_EMail );
		if CRating >= PCC_News then AddRPGMenuItem( MainMenu , MsgString( 'MEMO_ReadNews' ) , PCC_News );
		AlphaKeyMenu( MainMenu );

		repeat
{$IFDEF SDLMODE}
			A := SelectMenu( MainMenu , @PCSRedraw );
{$ELSE}
			A := SelectMenu( MainMenu );
{$ENDIF}
			case A of
				PCC_Memo: BrowseMemoType( GB , 'MEMO' );
				PCC_News: BrowseMemoType( GB , 'NEWS' );
				PCC_EMail: BrowseMemoType( GB , 'EMAIL' );
			end;

		until A = -1;

		DisposeRPGMenu( MainMenu );
	end else begin
		{ If all we have is the memo browser, might as well just go there. }
		BrowseMemoType( GB , 'MEMO' );
	end;
	GFCombatDisplay( GB );
end;

Function InterfaceType( GB: GameBoardPtr; Mek: GearPtr ): Integer;
	{ Return the constant for the currently-being-used control type. }
begin
	if GB^.Scale > 2 then begin
		InterfaceType := WorldMapMethod;
	end else if Mek^.G = GG_Character then begin
		InterfaceType := CharacterMethod;
	end else begin
		InterfaceType := ControlMethod;
	end;
end;

Procedure DoTalkingWIthNPC( GB: GameBoardPtr; PC,NPC: GearPtr; ByTelephone: Boolean );
	{ Actually handle the talking with an NPC already selected. }
var
	Persona: GearPtr;
	CID: Integer;
	React: Integer;
	ReTalk: LongInt;
begin
	if ( NPC <> Nil ) and GearActive( NPC ) then begin
		if ByTelephone or ( Range( GB , PC , NPC ) < 5 ) then begin
			CID := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
			if CID <> 0 then begin
				{ Everything should be okay to talk... Now see if the NPC wants to. }
				{ Determine the NPC's RETALK and REACT values. }
				ReTalk := NAttValue( NPC^.NA , NAG_Personal , NAS_Retalk );
				React := ReactionScore( GB^.Scene , PC , NPC );

				if NAttValue( NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam then begin
					Persona := lancemate_tactics_persona;
				end else begin
					Persona := SeekPersona( GB , CID );
				end;

				{ If the NPC really doesn't like the PC, }
				{ they'll refuse to talk on principle. }
				if ( ( React + RollStep( SkillValue ( PC , 28 ) ) ) < -Random( 120 ) ) or AreEnemies( GB , NPC , PC ) then begin
					DialogMsg( GearName( NPC ) + ' doesn''t want to talk to you.' );
					SetNAtt( NPC^.NA , NAG_Personal , NAS_Retalk , GB^.ComTime + 1500 );

				{ If the NPC is ready to talk, is friendly with the PC, or has a PERSONA gear defined, }
				{ they'll be willing to talk. }
				end else if ( ReTalk < GB^.ComTime ) or ( Random( 50 ) < ( React + 20 ) ) or ( Persona <> Nil ) then begin
					DialogMsg( 'You strike up a conversation with ' + GearName( NPC ) + '.' );

					HandleInteract( GB , PC , NPC , Persona );
					GFCombatDisplay( gb );
					DisplayGearInfo( PC , GB );

				end else begin
					DialogMsg( GearName( NPC ) + ' doesn''t want to talk right now.' );

				end;
			end else begin
				DialogMsg( 'No response!' );
			end;
		end else begin
			DialogMsg( 'You''re too far away to talk with ' + GearName( NPC ) + '.' );
		end;
	end else begin
		DialogMsg( 'Not found!' );
	end;
end;

Procedure PCTalk( GB: GameBoardPtr; PC: GearPtr );
	{ PC wants to do some talking. Select an NPC, then let 'er rip. }
begin
	DialogMsg( 'Select a character to talk with.' );
	if LookAround( GB , PC ) then begin
		DoTalkingWithNPC( GB , PC , LOOKER_Gear , False );
	end else begin
		DialogMsg( 'Talking cancelled.' );
	end;
end;

Procedure PCTelephone( GB: GameBoardPtr; PC: GearPtr );
	{ Make a telephone call, if the PC has a telephone. }
var
	Name: String;
	NPC: GearPtr;
begin
	if HasPCommCapability( PC , PCC_Comm ) then  begin
		DialogMsg( MsgString( 'PHONE_Prompt' ) );
{$IFDEF SDLMODE}
		Name := GetStringFromUser( MsgString( 'PHONE_GetName' ) , @PCActionRedraw );
{$ELSE}
		Name := GetStringFromUser( MsgString( 'PHONE_GetName' ) );
{$ENDIF}
		if Name = '*' then Name := SAttValue( PC^.SA , 'REDIAL' )
		else SetSAtt( PC^.SA , 'REDIAL <' + Name + '>' );

		if Name <> '' then begin
			NPC := SeekGearByName( GB^.Meks , Name );
			if NPC = Nil then NPC := FindNPCByKeyword( GB , Name );

			if NPC <> Nil then begin
				DoTalkingWithNPC( GB , PC , NPC , True );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'PHONE_NotFound' ) , Name ) );
			end;
			GFCombatDisplay( gb );
		end else begin
			GFCombatDisplay( gb );
		end;
	end else begin
		DialogMsg( MsgString( 'PHONE_NoPhone' ) );
	end;
end;

Procedure UsePropFrontEnd( GB: GameBoardPtr; PC , Prop: GearPtr; T: String );
	{ Do everything that needs to be done when a prop is used. }
begin
	TriggerGearScript( GB , Prop , T );
	VisionCheck( GB , PC );
	WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Function SelectOneVisibleUsableGear( GB: GameBoardPtr; X,Y: Integer; Trigger: String ): GearPtr;
	{ Create a menu, then select one of the visible, usable gears }
	{ from tile X,Y. }
var
	RPM: RPGMenuPtr;
	it: GearPtr;
	N: Integer;
begin
	{ Create and fill the menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	N := NumVisibleUsableGearsXY( GB , X , Y , Trigger );
	while N > 0 do begin
		it := FindVisibleUsableGearXY( GB , X , Y , N , Trigger );
		AddRPGMenuItem( RPM , GearName( it ) , N );
		Dec( N );
	end;

	{ Select an item. }
{$IFDEF SDLMODE}
	N := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
	N := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );

	if N > 0 then begin
		SelectOneVisibleUsableGear := FindVisibleUsableGearXY( GB , X , Y , N , Trigger );
	end else begin
		SelectOneVisibleUsableGear := Nil;
	end;
end;

Function ActivatePropAtSpot( GB: GameBoardPtr; PC: GearPtr; X,Y: Integer; Trigger: String ): Boolean;
	{ Check spot X,Y. If there are any usable items there, use one. }
	{ If there are multiple items in the spot, prompt for a selection. }
	{ Return TRUE if a prop was activated, or FALSE otherwise. }
var
	N: Integer;
	Prop: GearPtr;
begin
	{ First count how many usable items there are at the spot. }
	N := NumVisibleUsableGearsXY( GB , X , Y , Trigger );

	{ Next, choose the item which is to be used. }
	if N > 0 then begin
		if N = 1 then begin
			Prop := FindVisibleUsableGearXY( GB , X , Y , 1 , Trigger );
		end else begin
			Prop := SelectOneVisibleUsableGear( GB , X , Y , Trigger );
		end;

		if ( Prop <> Nil ) then begin
			UsePropFrontEnd( GB , PC , Prop , Trigger );
			ActivatePropAtSpot := True;
		end else begin
			ActivatePropAtSpot := False;
		end;

	end else begin
		ActivatePropAtSpot := False;
	end;
end;

Procedure PCUseProp( GB: GameBoardPtr; PC: GearPtr );
	{ PC wants to do something with a prop. Select an item, then let 'er rip. }
var
	D,PropD: Integer;
	P: Point;
begin
	{ See whether or not there's only one prop to use. }
	PropD := -1;
	P := GearCurrentLocation( PC );
	for D := 0 to 7 do begin
		if NumVisibleUsableGearsXY( GB , P.X + AngDir[ D , 1 ] , P.Y + AngDir[ D , 2 ] , 'USE' ) > 0 then begin
			if PropD = -1 then PropD := D
			else PropD := -2;
		end;
	end;

	if PropD < 0 then begin
		DialogMsg( MsgString( 'PCUS_Prompt' ) );
{$IFDEF SDLMODE}
		PropD := DirKey( @PCActionRedraw );
{$ELSE}
		PropD := DirKey;
{$ENDIF}
	end;

	if PropD > -1 then begin
		if not ActivatePropAtSpot( GB , PC , P.X + AngDir[ PropD , 1 ] , P.Y + AngDir[ PropD , 2 ] , 'USE' ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );
	end;
end;

Procedure PCEnter( GB: GameBoardPtr; PC: GearPtr );
	{ The PC is attempting to enter a place. }
	{ Seek a usable gear in this tile, then try to activate it. }
var
	P: Point;
begin
	P := GearCurrentLocation( PC );
	if not ActivatePropAtSpot( GB , PC , P.X , P.Y , 'USE' ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );;
end;

Procedure PCUseSkillOnProp( GB: GameBoardPtr; PC: GearPtr; Skill: Integer );
	{ PC wants to do something with a prop. Select an item, then let 'er rip. }
var
	PropD: Integer;
	P: Point;
	Trigger: String;
begin
	P := GearCurrentLocation( PC );
	DialogMsg( MsgString( 'PCUSOP_Prompt' ) );
{$IFDEF SDLMODE}
	PropD := DirKey( @PCActionRedraw );
{$ELSE}
	PropD := DirKey;
{$ENDIF}
	Trigger := 'CLUE' + BStr( Skill );

	if ( PropD = -1 ) and ( NumVisibleUsableGearsXY( GB , P.X , P.Y , Trigger ) > 0 ) then begin
		if not ActivatePropAtSpot( GB , PC , P.X , P.Y , Trigger ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );;
	end else if ( PropD <> -1 ) and ( NumVisibleUsableGearsXY( GB , P.X + AngDir[ PropD , 1 ] , P.Y + AngDir[ PropD , 2 ] , Trigger ) > 0 ) then begin
		if not ActivatePropAtSpot( GB , PC , P.X + AngDir[ PropD , 1 ] , P.Y + AngDir[ PropD , 2 ] , Trigger ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );;
	end else if GB^.Scene <> Nil then begin
		TriggerGearScript( GB , GB^.Scene , Trigger );
	end;
end;

Procedure DoPCRepair( GB: GameBoardPtr; PC: GearPtr; Skill: Integer );
	{ The PC is going to use one of the repair skills. Call the }
	{ standard procedure, then print output. }
var
	D,Best: Integer;
	P: Point;
	Mek,Target: GearPtr;
begin
	DialogMsg( MsgString( 'PCREPAIR_Prompt' ) );
{$IFDEF SDLMODE}
	D := DirKey( @PCActionRedraw );
{$ELSE}
	D := DirKey;
{$ENDIF}
	P := GearCurrentLocation( PC );
	if D <> -1 then begin
		P.X := P.X + AngDir[ D , 1 ];
		P.Y := P.Y + AngDir[ D , 2 ];
	end;

	Mek := GB^.Meks;
	Target := Nil;
	Best := 0;
	while Mek <> Nil do begin
		if ( not AreEnemies( GB , PC , Mek ) ) and ( TotalRepairableDamage( Mek , Skill ) > Best ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_X ) = P.X ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Y ) = P.Y ) then begin
			Target := Mek;
			Best := TotalRepairableDamage( Mek , Skill );
		end;
		mek := mek^.Next;
	end;
	if Target <> Nil then begin
		DoFieldRepair( GB , PC , FindRoot( Target ) , Skill );
		DisplayGearInfo( PC , GB );
	end else begin
		if not ActivatePropAtSpot( GB , PC , P.X , P.Y , 'CLUE' + BStr( Skill ) ) then DialogMsg( MsgString( 'PCREPAIR_NoDamageDone' ) );
	end;
end;

Procedure StartPerforming( GB: GameBoardPtr; PC: GearPtr );
	{ Start performing on a musical instrument. First this procedure }
	{ will seek the best instrument currently held, then it will set }
	{ up the continuous action. }
var
	Instrument: GearPtr;
begin
	Instrument := SeekBestInstrument( PC );
	if Instrument <> Nil then begin
		StartContinuousUseItem( GB , PC , Instrument );
	end else begin
		DialogMsg( MsgString( 'PERFORMANCE_NoInstrument' ) );
	end;
end;

Procedure BuildRobot( GB: GameBoardPtr; PC: GearPtr );
	{ Start performing on a musical instrument. First this procedure }
	{ will seek the best instrument currently held, then it will set }
	{ up the continuous action. }
var
	Ingredients,Robot: GearPtr;
	T: Integer;
begin
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_TOO_TIRED' ) );
		Exit;
	end else if not IsSafeArea( GB ) then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_NOT_SAFE' ) );
		Exit;
	end;

	PC := LocatePilot( PC );
	DialogMsg( MsgString( 'BUILD_ROBOT_START' ) );
	Ingredients := SelectRobotParts( GB , PC );
{$IFDEF SDLMODE}
	BasicCombatDisplay( GB );
{$ELSE}
	DisplayMap( GB );
{$ENDIF}


	{ If no ingredients were selected, no robot will be built. }
	if Ingredients = Nil then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_NO_PARTS' ) );
		Exit;
	end;

	Robot := UseRobotics( GB , PC , Ingredients );
	if Robot = Nil then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_FAILED' ) );
	end else begin
		SetNAtt( Robot^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
		SetNAtt( Robot^.NA , NAG_Relationship , 0 , NAV_ArchAlly );
		SetNAtt( Robot^.NA , NAG_CharDescription , NAS_CharType , NAV_CTLancemate );
		DeployMek( GB , Robot , True );

		if LancematesPresent( GB ) > LancematePoints( PC ) then RemoveLancemate( GB , Robot );

		if NAttValue( Robot^.NA , NAG_Personal , NAS_CID ) = 0 then begin
			DialogMsg( ReplaceHash( MsgString( 'BUILD_ROBOT_SUCCESS' ) , GearName( Robot ) ) );
		end else begin
			DialogMsg( ReplaceHash( MsgString( 'BUILD_ROBOT_SENTIENT' ) , GearName( Robot ) ) );
		end;

		{ Give the PC a rundown on the new robot's skills. }
		for t := 1 to Num_Robot_Skill do begin
			if NAttValue( Robot^.NA , NAG_Skill , Robot_Skill[ T ] ) > 0 then begin
				DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'BUILD_ROBOT_SKILL' ) , GearName( Robot ) ) , SkillMan[ Robot_Skill[ t ] ].Name ) );
			end;
		end;
	end;
end;

Procedure DominateAnimal( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will attempt to dominate this animal. Make a skill roll and see }
	{ if it's possible. If the skill roll fails, the animal may become enraged. }
	Function IsGoodTarget( M: GearPtr ): Boolean;
		{ Return TRUE if M is a good target for domination, or FALSE otherwise. }
	begin
		if GearActive( M ) and AreEnemies( GB , M , PC ) and ( NAttValue( M^.NA , NAG_PErsonal , NAS_CID ) = 0 ) then begin
			IsGoodTarget := True;
		end else if GearActive( M ) and ( NAttValue( M^.NA , NAG_PErsonal , NAS_CID ) = 0 ) and ( NAttValue( M^.NA , NAG_CharDescription , NAS_CharType ) = NAV_CTLancemate ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin
			IsGoodTarget := True;
		end else begin
			IsGoodTarget := False;		end;
	end;
var
	D: Integer;
	M,Target: GearPtr;
	SkTarget,SkRoll: Integer;
	P,P2: Point;
begin
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgString( 'DOMINATE_TOO_TIRED' ) );
		Exit;
	end;

	DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Announce' ) , PilotName( PC ) ) );
	P := GearCurrentLocation( PC );

	{ Pass one - try to find a monster nearby. }
	M := GB^.Meks;
	Target := Nil;
	D := 0;
	while M <> Nil do begin
		{ Two types of animal may be dominated: those which are hostile }
		{ to the PC, and those which are already his pets. }
		P2 := GearCurrentLocation( M );
		if ( Abs( P2.X - P.X ) <= 1 ) and ( Abs( P2.Y - P.Y ) <= 1 ) and IsGoodTarget( M ) then begin
			Target := M;
			Inc( D );
		end;
		M := M^.Next;
	end;

	{ If more than one monster was found, prompt for a direction. }
	if D > 1 then begin
		DialogMsg( MsgString( 'DOMINATE_Prompt' ) );
{$IFDEF SDLMODE}
		D := DirKey( @PCActionRedraw );
{$ELSE}
		D := DirKey;
{$ENDIF}
		P.X := P.X + AngDir[ D , 1 ];
		P.Y := P.Y + AngDir[ D , 2 ];

		M := GB^.Meks;
		Target := Nil;
		while M <> Nil do begin
			{ Two types of animal may be dominated: those which are hostile }
			{ to the PC, and those which are already his pets. }
			P2 := GearCurrentLocation( M );
			if ( P2.X = P.X ) and ( P2.Y = P.Y ) and IsGoodTarget( M ) then Target := M;
			M := M^.Next;
		end;
	end;

	if Target = Nil then begin
		DialogMsg( MsgString( 'DOMINATE_NotFound' ) );
		Exit;
	end else if AreEnemies( GB , Target , PC ) then begin
		{ Locate the target value for this animal. }
		{ If it has no skill target, then either it can't be dominated or }
		{ the PC has already tried and failed to dominate it. }
		SkTarget := NAttValue( Target^.NA , NAG_GearOps , NAS_DominationTarget );

		{ The PC only gets one attempt regardless... }
		SetNAtt( Target^.NA , NAG_GearOps , NAS_DominationTarget , 0 );

		if SkTarget < 1 then begin
			DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Fail' ) , GearName( Target ) ) );
		end else begin
			SkRoll := RollStep( SkillValue( PC , 40 ) );

			if ( SkRoll > SkTarget ) and ( LancematesPresent( GB ) < LancematePoints( PC ) ) then begin
				DialogMsg( ReplaceHash( MsgString( 'DOMINATE_OK' ) , GearName( Target ) ) );
				AddLancemate( GB , Target );
				SetNAtt( Target^.NA , NAG_CharDescription , NAS_CharType , NAV_CTLancemate );

				if HasTalent( PC , NAS_AnimalTrainer ) then DoleExperience( Target , CStat( LocatePilot( PC ) , STAT_Knowledge ) * 50 );
				DoleSkillExperience( PC , 40 , SkTarget * 2 );
				DoleExperience( PC , Target , SkTarget );
			end else if ( SkRoll < ( SkTarget div 3 ) ) then begin
				DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Enraged' ) , GearName( Target ) ) );
				for SkRoll := 6 to 10 do AddNAtt( Target^.NA , NAG_Skill , SkRoll , Random( 5 ) );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Fail' ) , GearName( Target ) ) );
				if SkTarget > 0 then DoleSkillExperience( PC , 40 , Random( 5 ) + 1 );
			end;
		end;

	end else begin
		{ This animal is an ex-member of the party. It'll come back fairly }
		{ peacefully, as long as there's room. }
		if LancematesPresent( GB ) < LancematePoints( PC ) then begin
			DialogMsg( ReplaceHash( MsgString( 'DOMINATE_OK' ) , GearName( Target ) ) );
			AddLancemate( GB , Target );
		end else begin
			DialogMsg( ReplaceHash( MsgString( 'DOMINATE_DontWant' ) , GearName( Target ) ) );
		end;
	end;

	{ Dominating an animal costs MP and takes time. }
	{ If no animal was chosen, the procedure already exited above... }
	AddMentalDown( PC , 5 );
	WaitAMinute( GB , PC , ReactionTime( PC ) * 2 );
end;

Procedure PickPockets( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will attempt to steal from a nearby NPC. }
	Function IsGoodTarget( M: GearPtr ): Boolean;
		{ Return TRUE if M is a good target for pick pockets, or FALSE otherwise. }
		{ It's a good target if it's an NPC (with CID), not a lancemate or the PC }
		{ himself, and alive. }
	var
		Team: Integer;
	begin
		if GearActive( M ) and ( M^.G = GG_Character ) and ( NAttValue( M^.NA , NAG_PErsonal , NAS_CID ) <> 0 ) then begin
			Team := NAttValue( M^.NA , NAG_Location , NAS_Team );
			IsGoodTarget := ( Team <> NAV_DefPlayerTeam ) and ( Team <> NAV_LancemateTeam );
		end else begin
			IsGoodTarget := False;
		end;
	end;
var
	D: Integer;
	M,Target: GearPtr;
	SkTarget,SkRoll: Integer;
	P,P2: Point;
	Cash,NID: LongInt;
begin
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgString( 'PICKPOCKET_TOO_TIRED' ) );
		Exit;
	end;

	DialogMsg( ReplaceHash( MsgString( 'PICKPOCKET_Announce' ) , PilotName( PC ) ) );
	P := GearCurrentLocation( PC );

	{ Pass one - try to find a target nearby. }
	M := GB^.Meks;
	Target := Nil;
	D := 0;
	while M <> Nil do begin
		P2 := GearCurrentLocation( M );
		if ( Abs( P2.X - P.X ) <= 1 ) and ( Abs( P2.Y - P.Y ) <= 1 ) and IsGoodTarget( M ) then begin
			Target := M;
			Inc( D );
		end;
		M := M^.Next;
	end;

	{ If more than one monster was found, prompt for a direction. }
	if D > 1 then begin
		DialogMsg( MsgString( 'PICKPOCKET_Prompt' ) );
{$IFDEF SDLMODE}
		D := DirKey( @PCActionRedraw );
{$ELSE}
		D := DirKey;
{$ENDIF}
		P.X := P.X + AngDir[ D , 1 ];
		P.Y := P.Y + AngDir[ D , 2 ];

		M := GB^.Meks;
		Target := Nil;
		while M <> Nil do begin
			P2 := GearCurrentLocation( M );
			if ( P2.X = P.X ) and ( P2.Y = P.Y ) and IsGoodTarget( M ) then Target := M;
			M := M^.Next;
		end;
	end;

	{ From here on, we want to deal with the actual PC. I don't think anyone will ever }
	{ get the chance to pick pockets in a mecha, but better safe than sorry. }
	PC := LocatePilot( PC );

	if Target = Nil then begin
		DialogMsg( MsgString( 'PICKPOCKET_NotFound' ) );
		Exit;
	end else if ( NAttValue( Target^.NA , NAG_Personal , NAS_PickPocketRestock ) > GB^.ComTime ) and ( Target^.InvCom = Nil ) then begin
		{ If the victim has nothing to steal, then the PC can't very well steal it, }
		{ can he? }
		DialogMsg( ReplaceHash( MsgString( 'PICKPOCKET_EMPTY' ) , GearName( Target ) ) );
		Exit;
	end else begin
		{ Time to start the actual stealing of stuff. }
		SkTarget := Target^.Stat[ STAT_Perception ] + 5;
		SkRoll := RollStep( SkillValue( PC , NAS_PickPockets ) );

		if SkRoll > SkTarget then begin
			{ The PC will now steal something. }
			{ Roll the amount of money claimed. }
			Cash := Calculate_Threat_Points( NAttValue( Target^.NA , NAG_CharDescription , NAS_Renowned ) * 2 , Random( 5 ) + 1 ) div 20 + Random( 10 );
			if Cash < 10 then Cash := Random( 8 ) + Random( 8 ) + 2;
			AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );

			{ Check for items... }
			M := SelectRandomGear( Target^.InvCom );
			if M <> Nil then begin
				DelinkGear( Target^.InvCom , M );
				{ mark the item as stolen... }
				SetSAtt( M^.SA , 'TYPE <' + SAttValue( M^.SA , 'TYPE' ) + ' STOLEN>' );
				InsertInvCom( PC , M );

				{ Set the trigger for picking up an item, just in case }
				{ there are any plots tied to this item. }
				NID := NAttValue( M^.NA , NAG_Narrative , NAS_NID );
				if NID <> 0 then SetTrigger( GB , TRIGGER_GetItem + BStr( NID ) );

				DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'PICKPOCKET_CASH+ITEM' ) , BStr( Cash ) ) , GearName( M ) ) );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'PICKPOCKET_CASH' ) , BStr( Cash ) ) );
			end;
			DoleSkillExperience( PC , NAS_PickPockets , SkTarget div 2 );
			DoleExperience( PC , Target , SkTarget );
		end else begin
			DialogMsg( MsgString( 'PICKPOCKET_FAIL' ) );
			{ If the failure was bad, the Guardians may notice... }
			DoleSkillExperience( PC , NAS_PickPockets , 1 );
			if SkRoll < ( SkTarget - 10 ) then begin
				SetTrigger( GB , 'THIEF!' );
				AddReputation( PC , 6 , -1 );
				AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( Target^.NA , NAG_PErsonal , NAS_CID ) , -20 );
			end;
		end;

		{ Picking pockets always has the consequences of Chaotic reputation }
		{ and the target will like you less. Even if they don't know it's you }
		{ stealing from them, it seems like every time they meet you they end }
		{ up poorer...? }
		if SkRoll < ( SkTarget + 10 ) then AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( Target^.NA , NAG_PErsonal , NAS_CID ) , -( 5 + Random(10) ) );
		AddReputation( PC , 2 , -2 );

		{ Also set the recharge time. }
		SetNAtt( Target^.NA , NAG_Personal , NAS_PickPocketRestock , GB^.ComTime + 43200 + Random( 86400 ) );
	end;

	{ Stealing things takes concentration and time. }
	AddMentalDown( PC , 5 );
	WaitAMinute( GB , PC , ReactionTime( PC ) * 2 );
end;


Procedure PCActivateSkill( GB: GameBoardPtr; PC: GearPtr );
	{ Allow the PC to pick a known skill from his list, then apply }
	{ that skill to either himself or a nearby object. }
	{ There are two kinds of skills that can be activated by this }
	{ command: repair skills and clue skills. Clue skills must be }
	{ applied to an item. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	{ Make sure we have the actual PC first. }
	PC := LocatePilot( PC );
	if PC = Nil then Exit;

	{ Make the skill menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	AttachMenuDesc( RPM , ZONE_Info );
	RPM^.DTexColor := InfoGreen;

	{ Add all usable skills to the list, as long as the PC knows them. }
	for N := 1 to NumSkill do begin
		if ( SkillMan[ N ].Usage = USAGE_Clue ) and ( TeamHasSkill( GB , NAV_DefPlayerTeam , N ) or HasTalent( PC , NAS_JackOfAll ) ) then begin
			AddRPGMenuItem( RPM , SkillMan[N].Name , N , SkillDesc( N ) );
		end else if ( SkillMan[ N ].Usage > 0 ) and HasSkill( PC , N ) then begin
			AddRPGMenuItem( RPM , SkillMan[N].Name , N , SkillDesc( N ) );
		end;
	end;
	RPMSortAlpha( RPM );
	AlphaKeyMenu( RPM );
	AddRPGMenuItem( RPM , MsgString( 'PCAS_Cancel' ) , -1 );
	DialogMSg( MsgString( 'PCAS_Prompt' ) );

{$IFDEF SDLMODE}
	N := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
	N := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );

	if ( N > 0 ) and ( N <= NumSkill ) then begin
		if SkillMan[ N ].Usage = USAGE_Repair then begin
			DoPCRepair( GB , PC , N );
		end else if SkillMan[ N ].Usage = USAGE_Clue then begin
			PCUseSkillOnProp( GB , PC , N );
		end else if SkillMan[ N ].Usage = USAGE_Performance then begin
			StartPerforming( GB , PC );
		end else if SkillMan[ N ].Usage = USAGE_Robotics then begin
			BuildRobot( GB , PC );
		end else if SkillMan[ N ].Usage = USAGE_DominateAnimal then begin
			DominateAnimal( GB , PC );
		end else if SkillMan[ N ].Usage = USAGE_PickPockets then begin
			PickPockets( GB , PC );
		end;

	end else begin
		DialogMsg( MsgString( 'Cancelled' ) );
	end;
end;

Procedure ForcePlot( GB: GameBoardPtr; Scene: GearPtr );
	{ Debugging command - forcibly loads a plot into the adventure. }
var
	RPM: RPGMenuPtr;
	PName: String;
	Plot: GearPtr;
	F: text;
begin
	if ( scene = Nil ) or ( Scene^.Parent = Nil ) then exit;
	{ Create a menu listing all the units in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( RPM , Plot_Seacrh_Pattern );

	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select plot file to load.');
{$IFDEF SDLMODE}
		pname := SelectFile( RPM , @PCActionRedraw );
{$ELSE}
		pname := SelectFile( RPM );
{$ENDIF}
		if pname <> '' then begin
			Assign( F , Series_Directory + pname );
			reset(F);
			Plot := ReadGear(F);
			Close(F);
			if InsertPlot( FindRoot( Scene ) , Plot , True , GB ) then begin
				DialogMsg( 'Plot successfully loaded.' );
			end else begin
				DialogMsg( 'Plot rejected.' );
			end;
		end;
	end;
	DisposeRPGMenu( RPM );
end;

Procedure PCSaveCampaign( Camp: CampaignPtr; PC: gearPtr; PrintMsg: Boolean );
	{ Save the campaign and all associated info to disk. }
var
	Name: String;
	F: Text;
begin
	{ Decide whether or not CAMP is suitable to be saved. }
	if ( Camp = Nil ) or ( Camp^.GB = Nil ) or ( Camp^.GB^.Scene = Nil ) then begin
		Dialogmsg( MsgString( 'SAVEGAME_NoGood' ) );
		Exit;
	end;

	{ Find the PC's name, open the file, and save. }
	Name := Save_Campaign_Base + PilotName( PC ) + Default_File_Ending;
	Assign( F , Name );
	Rewrite( F );
	WriteCampaign( Camp , F );
	Close( F );

	{ Let the player know that everything went fine. }
	if PrintMsg then Dialogmsg( MsgString( 'SAVEGAME_OK' ) );
end;

Procedure DoSelectPCMek( GB: GameBoardPtr; PC: GearPtr );
	{ Select one of the team 1 mecha for the player to use. }
begin
	CMessage( MsgString( 'SELECTMECHA_PROMPT' ) , ZONE_Menu1 , InfoHilight );
{$IFDEF SDLMODE}
	MechaSelectionMenu( GB , GB^.Meks ,PC , ZONE_Menu2 );
{$ELSE}
	MechaSelectionMenu( GB^.Meks ,PC , ZONE_Menu2 );
	ClrZone( ZONE_Menu );
{$ENDIF}
end;

{$IFDEF SDLMODE}
Procedure TrainingRedraw;
	{ Redraw the training screen. }
begin
	SetupCombatDisplay;
	CharacterDisplay( PCACTIONRD_PC , PCACTIONRD_GB );
	RedrawConsole;
	NFCMessage( 'FREE XP: ' + BStr( NAttValue( PCACTIONRD_PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PCACTIONRD_PC^.NA , NAG_Experience , NAS_SpentXP ) ) , ZONE_Menu1 , InfoHilight );
end;

Procedure NewSkillRedraw;
	{ Redraw the training screen. }
begin
	SetupCombatDisplay;
	CharacterDisplay( PCACTIONRD_PC , PCACTIONRD_GB );
	RedrawConsole;
	NFCMessage( BStr( NumberOfSkills( PCACTIONRD_PC ) ) + '/' + BStr( NumberOfSkillSlots( PCACTIONRD_PC ) ) , ZONE_Menu1 , InfoHilight );
end;
{$ENDIF}

Procedure DoTraining( GB: GameBoardPtr; PC: GearPtr );
	{ The player wants to spend some of this character's }
	{ accumulated experience points. Go to it! }
	Procedure ImproveSkills( PC: GearPtr );
		{ The PC is going to improve his or her skills. }
	var
		FXP: LongInt;		{ Free XP Points }
		SkMenu: RPGMenuPtr;	{ Training Hall Menu }
		Sk: NAttPtr;		{ A skill counter }
		N: LongInt;		{ A number }
		SI,TI: Integer;		{ Selected Item , Top Item }
	begin
		{ Initialize the Selected Item and Top Item to the }
		{ top of the list. }
		SI := 1;
		TI := 1;
{$IFNDEF SDLMODE}
		DrawExtBorder( ZONE_SubInfo , BorderBlue );
{$ENDIF}
		repeat
			{ The number of free XP is the total XP minus the spent XP. }
			FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

			{ Create the skill menu. }
			SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
			Sk := PC^.NA;

			SkMenu^.dtexcolor := InfoGreen;
{$IFDEF SDLMODE}
			AttachMenuDesc( SkMenu , ZONE_Info );
{$ELSE}
			AttachMenuDesc( SkMenu , ZONE_SubInfo );
{$ENDIF}


			while Sk <> Nil do begin
				if ( Sk^.G = NAG_Skill ) and ( Sk^.S > 0 ) then begin
					{ Add this skill to the menu. This is going to be one doozy of a long description. }
					AddRPGMenuItem( SkMenu , SkillMan[Sk^.S].Name + ' +' + BStr( Sk^.V ) + '   (' + BStr( SkillAdvCost( PC , Sk^.V ) ) + ' XP)' , Sk^.S , SkillDesc( Sk^.S ) );
				end;
				Sk := Sk^.Next;
			end;

			RPMSortAlpha( SkMenu );
			AddRPGMenuItem( SkMenu , MsgString( 'RANDCHAR_ASPDone' ) , -1 );

			{ Restore SelectItem , TopItem from the last time. }
			SkMEnu^.SelectItem := SI;
			SkMenu^.TopItem := TI;

{$IFDEF SDLMODE}
			N := SelectMenu( SkMenu , @TrainingRedraw );
{$ELSE}
			CMessage( 'FREE XP: ' + BStr( FXP ) , ZONE_Menu1 , InfoHilight );
			N := SelectMenu( SkMenu );
{$ENDIF}

			{ Save the last cursor position, then dispose of }
			{ the menu. }
			SI := SkMenu^.SelectItem;
			TI := SkMenu^.TopItem;
			DisposeRPGMenu( SkMenu );

			if N > 0 then begin
				{ Locate the exact skill being improved. }
				Sk := FindNAtt( PC^.NA , NAG_Skill , N );

				{ Use N to store this skill's cost. }
				N := SkillAdvCost( PC , Sk^.V );

				{ If the PC has enough free XP, this skill will be improved. }
				{ Otherwise, do nothing. }
				if N > FXP then begin
					DialogMsg( GearName( PC ) + ' doesn''t have enough experience points to improve ' + SkillMan[Sk^.S].name + '.' );
				end else begin
					{ Improve the skill, pay the XP. }
					DialogMsg( GearName( PC ) + ' has improved ' + SkillMan[Sk^.S].name + '.' );
					AddNAtt( PC^.NA , NAG_Skill , Sk^.S , 1 );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , N );
				end;
			end;
		until N = -1;
	end;

	Function StatCanBeAdvanced( N: Integer ): Boolean;
		{ Return TRUE if the requested stat is eligible for }
		{ advancement, or FALSE if it is not. In order to be }
		{ advanced a stat must have sufficient skills at the }
		{ sufficient level. }
		{ To improve a skill N times, the PC must know (N+1) skills }
		{ based on that stat, and they all must be at least of }
		{ rank (N+5). }
	var
		CIV, T: Integer;	{ Current Improvement Value. }
		min_rank,num_required: Integer;
	begin
		CIV := NAttValue( PC^.NA , NAG_StatImprovementLevel , N );
		min_rank := ( CIV div 2 ) + 6;
		num_required := ( CIV + 3 ) div 2;

		for t := 1 to NumSkill do begin
			if ( SkillMan[ T ].Stat = N ) and ( NAttValue( PC^.NA , NAG_Skill , T ) >= min_rank ) then begin
				num_required := num_required - ( NAttValue( PC^.NA , NAG_Skill , T ) div min_rank );
			end;
		end;

		StatCanBeAdvanced := ( num_required <= 0 );
	end;

	Function OneStatCanBeAdvanced: Boolean;
		{ Return TRUE if at least one stat is capable of being }
		{ advanced, or FALSE otherwise. }
	var
		t,N: Integer;
	begin
		N := 0;
		for t := 1 to NumGearStats do begin
			if StatCanBeAdvanced( T ) then Inc( N );
		end;
		OneStatCanBeAdvanced := N > 0;
	end;

	Function StatImprovementCost( CIV: Integer ): LongInt;
		{ Return the cost of improving this stat. }
	begin
		StatImprovementCost := ( CIV + 1 ) * 500;
	end;

	Procedure ImproveStats( PC: GearPtr );
		{ The PC is going to improve his or her stats. }
	var
		FXP: LongInt;		{ Free XP Points }
		StMenu: RPGMenuPtr;	{ Training Hall Menu }
		CIV: Integer;		{ Current Improvement Value. }
		N,T,SI,TI: Integer;	{ Selected Item , Top Item }
		XP: LongInt;
	begin
		{ Initialize the Selected Item and Top Item to the }
		{ top of the list. }
		SI := 1;
		TI := 1;
{$IFNDEF SDLMODE}
		DrawExtBorder( ZONE_SubInfo , BorderBlue );
{$ENDIF}
		repeat
			DisplayGearInfo( PC );

			{ The number of free XP is the total XP minus the spent XP. }
			FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

			{ Create the skill menu. }
			StMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

			for t := 1 to NumGearStats do begin
				if StatCanBeAdvanced( T ) then begin
					{ Find out how many times this stat has been }
					{ improved thus far. }
					CIV := NAttValue( PC^.NA , NAG_StatImprovementLevel , T );
					AddRPGMenuItem( StMenu , StatName[ T ] + '   (' + BStr( StatImprovementCost( CIV ) ) + ' XP)' , T );
				end;
			end;

			AddRPGMenuItem( StMenu , MsgString( 'RANDCHAR_ASPDone' ) , -1 );

			{ Restore SelectItem , TopItem from the last time. }
			StMEnu^.SelectItem := SI;
			StMenu^.TopItem := TI;

{$IFDEF SDLMODE}
			N := SelectMenu( StMenu , @TrainingRedraw );
{$ELSE}
			CMessage( 'FREE XP: ' + BStr( FXP ) , ZONE_Menu1 , InfoHilight );
			N := SelectMenu( StMenu );
{$ENDIF}

			{ Save the last cursor position, then dispose of }
			{ the menu. }
			SI := StMenu^.SelectItem;
			TI := StMenu^.TopItem;
			DisposeRPGMenu( StMenu );

			if N > 0 then begin
				{ Find out how many times this stat has been }
				{ improved thus far. }
				CIV := NAttValue( PC^.NA , NAG_StatImprovementLevel , N );

				XP := StatImprovementCost( CIV );

				if XP > FXP then begin
					DialogMsg( GearName( PC ) + ' doesn''t have enough experience points.' );
				end else begin
					{ Improve the skill, pay the XP. }
					DialogMsg( GearName( PC ) + ' has improved ' + StatName[ N ] + '.' );
					Inc( PC^.Stat[ N ] );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , XP );
					AddNAtt( PC^.NA , NAG_StatImprovementLevel , N , 1 );
				end;

			end;
		until N = -1;
	end;

	Procedure ForgetLowSkill( PC: GearPtr );
		{ The PC wants to forget a currently known skill. }
		{ Choose the skill with the lowest rank to delete. }
	var
		LowSkill,LowSkillRank,T,R: Integer;
	begin
		LowSkill := 1;
		LowSkillRank := 9999;
		for t := 1 to NumSkill do begin
			R := NAttValue( PC^.NA , NAG_Skill , T );
			if R > 0 then begin
				if R < LowSkillRank then begin
					LowSkill := T;
					LowSkillRank := R;
				end else if ( R = LowSkillRank ) and ( Random( 2 ) = 1 ) then begin
					LowSkill := T;
					LowSkillRank := R;
				end;
			end;
		end;
		SetNAtt( PC^.NA , NAG_Skill , LowSkill , 0 );
		{ Also remove any talents based on this skill. }
		for t := 1 to NumTalent do begin
			if Talent_PreReq[ T , 1 ] = LowSkill then SetNAtt( PC^.NA , NAG_Talent , T , 0 );
		end;
	end;

	Procedure GetNewSkill( PC: GearPtr );
		{ The PC is going to purchase a new skill. }
	var
		FXP: LongInt;		{ Free XP Points }
		SkMenu: RPGMenuPtr;	{ Training Hall Menu }
		N,N2: LongInt;		{ A number }
	begin
		{ The number of free XP is the total XP minus the spent XP. }
		FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

		{ Create the skill menu. }
		{ We only want this menu to contain skills the PC does }
		{ not currently know. }
		SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

{$IFDEF SDLMODE}
		AttachMenuDesc( SkMenu , ZONE_Info );
{$ELSE}
		DrawExtBorder( ZONE_SubInfo , BorderBlue );
		AttachMenuDesc( SkMenu , ZONE_SubInfo );
{$ENDIF}
		SkMenu^.dtexcolor := InfoGreen;

		for N := 1 to NumSkill do begin
			if FindNAtt( PC^.NA , NAG_Skill , N ) = Nil then begin
				AddRPGMenuItem( SkMenu , SkillMan[N].Name + '   (' + BStr( SkillAdvCost( PC , 0 ) ) + ' XP)' , N , SkillDesc( N ) );
			end;
		end;
		RPMSortAlpha( SkMenu );
		AddRPGMenuItem( SkMenu , '  Cancel' , -1 );

{$IFDEF SDLMODE}
		N := SelectMenu( SkMenu , @NewSkillRedraw );
{$ELSE}
		CMessage( BStr( NumberOfSkills( PC ) ) + '/' + BStr( NumberOfSkillSlots( PC ) ) , ZONE_Menu1 , InfoHilight );
		N := SelectMenu( SkMenu );
{$ENDIF}
		DisposeRPGMenu( SkMenu );

		if N > 0 then begin
			{ If the PC has enough free XP, this skill will be improved. }
			{ Otherwise, do nothing. }
			if SkillAdvCost( PC , 0 ) > FXP then begin
				DialogMsg( GearName( PC ) + ' doesn''t have enough experience points to learn ' + SkillMan[N].name + '.' );

			end else begin
				{ Improve the skill, pay the XP. }
				if NumberOfSkills( PC ) >= NumberOfSkillSlots( PC ) then begin
					SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
{$IFDEF SDLMODE}
					AttachMenuDesc( SkMenu , ZONE_Info );
{$ELSE}
					DrawExtBorder( ZONE_SubInfo , BorderBlue );
					AttachMenuDesc( SkMenu , ZONE_SubInfo );
{$ENDIF}
					SkMenu^.dtexcolor := InfoGreen;
					AddRPGMenuItem( SkMenu , MsgSTring( 'LearnSkill_AcceptPenalty' ) , 1 , MsgString( 'LearnSkill_Warning' ) );
					AddRPGMenuItem( SkMenu , MsgString( 'LearnSkill_ForgetPrevious' ) , 2 , MsgString( 'LearnSkill_Warning' ) );
					AddRPGMenuItem( SkMenu , MsgString( 'Cancel' ) , -1 , MsgString( 'LearnSkill_Warning' ) );

{$IFDEF SDLMODE}
					N2 := SelectMenu( SkMenu , @NewSkillRedraw );
{$ELSE}
					N2 := SelectMenu( SkMenu );
{$ENDIF}
					if N2 = -1 then begin
						{ Cancelled learning new skill. }
						N := -1;
					end else if N2 = 2 then begin
						{ Will forget previous skill. }
						ForgetLowSkill( PC );
					end;

					DisposeRPGMenu( SkMenu );
				end;


				if ( N >= 1 ) and ( N <= NumSkill ) then begin
					DialogMsg( GearName( PC ) + ' has learned the ' + SkillMan[N].name + ' skill.' );
					SetNAtt( PC^.NA , NAG_Skill , N , 1 );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , SkillAdvCost( PC , 0 ) );

					FXP := FXP - SkillAdvCost( PC , 0 );
				end;
			end;
		end;
end;

	Procedure GetNewTalent( PC: GearPtr );
		{ The PC is going to purchase a new talent. }
	var
		FXP: LongInt;		{ Free XP Points }
		TMenu: RPGMenuPtr;	{ Training Hall Menu }
		N: LongInt;		{ A number }
	begin
		{ The number of free XP is the total XP minus the spent XP. }
		FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

		{ Create the skill menu. }
		{ We only want this menu to contain skills the PC does }
		{ not currently know. }
		TMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

{$IFDEF SDLMODE}
		AttachMenuDesc( TMenu , ZONE_Info );
{$ELSE}
		DrawExtBorder( ZONE_SubInfo , BorderBlue );
		AttachMenuDesc( TMenu , ZONE_SubInfo );
{$ENDIF}
		TMenu^.dtexcolor := InfoGreen;

		for N := 1 to NumTalent do begin
			if CanLearnTalent( PC , N ) then begin
				AddRPGMenuItem( TMenu , MsgString( 'TALENT' + BStr( N ) ) , N , MsgString( 'TALENTDESC' + BStr( N ) ) );
			end;
		end;
		RPMSortAlpha( TMenu );
		AddRPGMenuItem( TMenu , '  Cancel' , -1 );

		CMessage( 'FREE XP: ' + BStr( FXP ) , ZONE_Menu1 , InfoHilight );

		repeat
{$IFDEF SDLMODE}
			N := SelectMenu( TMenu , @TrainingRedraw );
{$ELSE}
			N := SelectMenu( TMenu );
{$ENDIF}

			if N > 0 then begin
				{ If the PC has enough free XP, this skill will be improved. }
				{ Otherwise, do nothing. }
				if 1000 > FXP then begin
					DialogMsg( MsgString( 'CANTAFFORDTALENT' ) );
				end else if NumFreeTalents( PC ) < 1 then begin
					DialogMsg( MsgString( 'NOFREETALENTS' ) );
				end else begin
					{ Improve the skill, pay the XP. }
					DialogMsg( GearName( PC ) + ' has learned ' + MsgString( 'TALENT' + BStr( N ) ) + '.' );
					ApplyTalent( PC , N );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , 1000 );

					FXP := FXP - 1000;

					{ Having purchased a skill, we want to leave this procedure. }
					N := -1;
				end;
			end;
		until N = -1;

		CMessage( 'FREE XP: ' + BStr( FXP ) , ZONE_Menu1 , InfoHilight );
		DisposeRPGMenu( TMenu );
	end;

	Procedure ReviewTalents( PC: GearPtr );
		{ The PC is going to review his talents. }
	var
		FXP: LongInt;		{ Free XP Points }
		TMenu: RPGMenuPtr;	{ Training Hall Menu }
		N: LongInt;		{ A number }
	begin
		{ The number of free XP is the total XP minus the spent XP. }
		FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

		{ Create the skill menu. }
		TMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

{$IFDEF SDLMODE}
		AttachMenuDesc( TMenu , ZONE_Info );
{$ELSE}
		DrawExtBorder( ZONE_SubInfo , BorderBlue );
		AttachMenuDesc( TMenu , ZONE_SubInfo );
{$ENDIF}
		TMenu^.dtexcolor := InfoGreen;

		for N := 1 to NumTalent do begin
			if HasTalent( PC , N ) then begin
				AddRPGMenuItem( TMenu , MsgString( 'TALENT' + BStr( N ) ) , N , MsgString( 'TALENTDESC' + BStr( N ) ) );
			end;
		end;
		RPMSortAlpha( TMenu );
		AddRPGMenuItem( TMenu , '  Exit' , -1 );

		CMessage( 'FREE XP: ' + BStr( FXP ) , ZONE_Menu1 , InfoHilight );

{$IFDEF SDLMODE}
		N := SelectMenu( TMenu , @TrainingRedraw );
{$ELSE}
		N := SelectMenu( TMenu );
{$ENDIF}
		DisposeRPGMenu( TMenu );
	end;

	Procedure ReviewCyberware( PC: GearPtr );
		{ The PC is going to review his talents. }
	var
		FXP: LongInt;		{ Free XP Points }
		S: GearPtr;		{ Subcoms of PC. }
		TMenu: RPGMenuPtr;	{ Training Hall Menu }
	begin
		{ The number of free XP is the total XP minus the spent XP. }
		{ We just need this for display purposes. }
		FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

		{ Create the cyber menu. }
		TMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

{$IFDEF SDLMODE}
		AttachMenuDesc( TMenu , ZONE_Info );
{$ELSE}
		DrawExtBorder( ZONE_SubInfo , BorderBlue );
		AttachMenuDesc( TMenu , ZONE_SubInfo );
{$ENDIF}
		TMenu^.dtexcolor := InfoGreen;

		S := PC^.SubCom;
		while S <> Nil do begin
			if AStringHasBString( SAttValue( S^.SA , 'TYPE' ) , 'CYBER' ) then begin
				AddRPGMenuItem( TMenu , GearName( S ) , 0 , ExtendedDescription( S ) + ' (' + SAttValue( S^.SA , 'CYBERSLOT' ) + ')' );
			end;
			S := S^.Next;
		end;
		RPMSortAlpha( TMenu );
		AddRPGMenuItem( TMenu , '  Exit' , -1 );

		CMessage( 'FREE XP: ' + BStr( FXP ) , ZONE_Menu1 , InfoHilight );

{$IFDEF SDLMODE}
		SelectMenu( TMenu , @TrainingRedraw );
{$ELSE}
		SelectMenu( TMenu );
{$ENDIF}
		DisposeRPGMenu( TMenu );
	end;

var
	DTMenu: RPGMenuPtr;
	N: Integer;
begin
	{ Error check - PC must point to the character record. }
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

{$IFDEF SDLMODE}
	PCACTIONRD_PC := PC;
	PCACTIONRD_GB := GB;
{$ENDIF}


	repeat
		DTMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ImproveSkill' ) , 1 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_NewSkill' ) , 2 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ReviewCyberware' ) , 6 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ReviewTalents' ) , 5 );
		if ( NumFreeTalents( PC ) > 0 ) and ( NAttValue( PC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin
			AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_NewTalent' ) , 4 );
		end;
		if OneStatCanBeAdvanced then begin
			AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ImproveStat' ) , 3 );
		end;
		AddRPGMenuItem( DTMenu ,  MsgString( 'Exit' ) , -1 );
{$IFDEF SDLMODE}
		N := SelectMenu( DTMenu , @TrainingRedraw );
{$ELSE}
		DisplayGearInfo( PC );
		CMessage( 'FREE XP: ' + BStr( NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP ) ) , ZONE_Menu1 , InfoHilight );
		N := SelectMenu( DTMenu );
{$ENDIF}
		DisposeRPGMenu( DTMenu );

		if N = 1 then ImproveSkills( PC )
		else if N = 3 then ImproveStats( PC )
		else if N = 2 then GetNewSkill( PC )
		else if N = 4 then GetNewTalent( PC )
		else if N = 5 then ReviewTalents( PC )
		else if N = 6 then ReviewCyberware( PC );

	until N = -1;
end;

Procedure DoFirstAid( GB: GameBoardPtr; PC: GearPtr );
	{ The PC is using the quick first aid ability. }
	{ All this procedure does is call the general repair procedure }
	{ with the first aid skill. }
begin
	DoPCRepair( GB , PC , 20 );
end;

Procedure PCBackpackMenu( GB: GameBoardPtr; PC: GearPtr; StartWithInv: Boolean );
	{ This is a front-end for the BackpackMenu command; all it does is }
	{ call that procedure, then redraw the map afterwards. }
begin
	BackpackMenu( GB , PC , StartWithInv );
	GFCombatDisplay( GB );
	DisplayGearInfo( PC , GB );
end;

Procedure PCFieldHQ( GB: GameBoardPtr; PC: GearPtr );
	{ This is a front-end for the BackpackMenu command; all it does is }
	{ call that procedure, then redraw the map afterwards. }
begin
	FieldHQ( GB , PC );
	GFCombatDisplay( GB );
	DisplayGearInfo( PC , GB );
end;

Procedure SetPlayOptions( GB: GameBoardPtr; Mek: GearPtr );
	{ Allow the player to set control type, default burst value settings, }
	{ and whatever other stuff you think is appropriate. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	{ The menu needs to be re-created with each iteration, since the }
	{ data in it needs to be updated. }
{$IFNDEF SDLMODE}
	CMessage( 'Set game prefrences' , ZONE_Menu1 , NeutralGrey );
{$ENDIF}
	N := 1;
	repeat
{$IFDEF SDLMODE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
{$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
{$ENDIF}
		AddRPGMenuItem( RPM , 'Mecha Control: '+ControlTypeName[ControlMethod] , 1 );
		AddRPGMenuItem( RPM , 'Chara Control: '+ControlTypeName[CharacterMethod] , 5 );
		AddRPGMenuItem( RPM , 'Explore Control: '+ControlTypeName[WorldMapMethod] , 6 );
		AddRPGMenuItem( RPM , 'Ballistic Wpn BV: '+BVTypeName[DefBallisticBV] , 2 );
		AddRPGMenuItem( RPM , 'Energy Wpn BV: '+BVTypeName[DefBeamGunBV] , 3 );
		AddRPGMenuItem( RPM , 'Missile BV: '+BVTypeName[DefMissileBV] , 4 );
{$IFDEF SDLMODE}
		if Use_Alpha_Blending then begin
			AddRPGMenuItem( RPM , 'Disable Transparency' , 7 );
		end else begin
			AddRPGMenuItem( RPM , 'Enable Transparency' , 7 );
		end;
		if Display_Mini_Map then begin
			AddRPGMenuItem( RPM , 'Disable Mini-Map' , 8 );
		end else begin
			AddRPGMenuItem( RPM , 'Enable Mini-Map' , 8 );
		end;
		if Names_Above_Heads then begin
			AddRPGMenuItem( RPM , 'Disable Name Display' , 9 );
		end else begin
			AddRPGMenuItem( RPM , 'Enable Name Display' , 9 );
		end;
{$ENDIF}
		AddRPGMenuItem( RPM , '  Exit Prefrences' , -1 );
		SetItemByValue( RPM , N );
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		DisposeRPGMenu( RPM );

		if N = 1 then begin
			if ControlMethod = MenuBasedInput then ControlMethod := RLBasedInput
			else ControlMethod := MenuBasedInput;
			WaitAMinute( GB , Mek , 1 );
		end else if N = 5 then begin
			if CharacterMethod = MenuBasedInput then CharacterMethod := RLBasedInput
			else CharacterMethod := MenuBasedInput;
			WaitAMinute( GB , Mek , 1 );
		end else if N = 6 then begin
			if WorldMapMethod = MenuBasedInput then WorldMapMethod := RLBasedInput
			else WorldMapMethod := MenuBasedInput;
			WaitAMinute( GB , Mek , 1 );
		end else if N = 2 then begin
			if DefBallisticBV = BV_Off then DefBallisticBV := BV_Max
			else DefBallisticBV := BV_Off;
		end else if N = 3 then begin
			if DefBeamGunBV = BV_Off then DefBeamGunBV := BV_Max
			else DefBeamGunBV := BV_Off;

		end else if N = 4 then begin
			DefMissileBV := DefMissileBV + 1;
			if DefMissileBV > BV_Max then DefMissileBV := BV_Off;

		end else if N = 7 then begin
			{ Toggle the Alpha_Blending boolean. }
			Use_Alpha_Blending := Not Use_Alpha_Blending;

		end else if N = 8 then begin
			{ Toggle the Mini-Map. }
			Display_Mini_Map := Not Display_Mini_Map;

		end else if N = 9 then begin
			Names_Above_Heads := Not Names_Above_Heads;

		end;

	until N = -1;
end;

Procedure BrowsePersonalHistory( GB: GameBoardPtr; PC: GearPtr );
	{ As the PC advances throughout the campaign, she will likely }
	{ accumulate a number of history messages. This procedure will }
	{ allow those messages to be browsed. }
var
	HList,SA: SAttPtr;
	Adv: GearPtr;
begin
	HList := Nil;
	Adv := FindRoot( GB^.Scene );
	if Adv <> Nil then begin
		SA := Adv^.SA;
		while SA <> Nil do begin
			if UpCase( Copy( SA^.Info , 1 , 7 ) ) = 'HISTORY' then begin
				StoreSAtt( HList , RetrieveAString( SA^.Info ) );
			end;
			SA := SA^.Next;

		end;

		if HList <> Nil then begin
			MoreText( HList , 1 );
			DisposeSAtt( HList );
			DisplayGearInfo( PC , GB );
		end;
	end;
end;

Procedure PCViewChar( GB: GameBoardPtr; PC: GearPtr );
	{ This procedure is supposed to allow the PC to see his/her }
	{ stats, edit mecha, access the training and option screens, }
	{ and otherwise provide a nice all-in-one command for a }
	{ bunch of different play options. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin

	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );

	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_BackPack' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_Injuries' ) , 3 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_Training' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_FieldHQ' ) , 4 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_SetOptions' ) , 5 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_PersonalHistory' ) , 6 );
{$IFDEF SDLMODE}
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_SetColor' ) , 7 );
	if PC^.G = GG_Character then AddRPGMenuItem( RPM , MsgString( 'PCVIEW_SetSprite' ) , 8 );
{$ENDIF}
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_Exit' ) , -1 );


	repeat
{$IFDEF SDLMODE}
		PCACTIONRD_PC := PC;
		N := SelectMenu( RPM , @TrainingRedraw );
{$ELSE}
		CharacterDisplay( PC , GB );
		N := SelectMenu( RPM );
{$ENDIF}

		case N of
			1:	BackPackMenu( GB , PC , True );
			2:	DoTraining( GB , PC );
			3:	begin
				InjuryViewer( PC );
				RPGKey;
				end;
			4:	FieldHQ( GB , PC );
			5:	SetPlayOptions( GB , PC );
			6:	BrowsePersonalHistory( GB , PC );
{$IFDEF SDLMODE}
			7:	SelectColors( PC , @TrainingRedraw );
			8:	SelectSprite( PC , @TrainingRedraw );
{$ENDIF}

		end;
	until N = -1;

{$IFDEF SDLMODE}
	CleanSpriteList;
{$ENDIF}
	DisposeRPGMenu( RPM );
	GFCombatDisplay( GB );
end;

Procedure WaitOnRecharge( GB: GameBoardPtr; Mek: GearPtr );
	{ Set the mek's CALLTIME to whenever the next weapon is supposed to }
	{ be recharged. }
var
	CT: LongInt;
	procedure SeekWeapon( Part: GearPtr );
		{ Seek the weapon which will recharge soonest. }
	var
		RT: LongInt;
	begin
		while ( Part <> Nil ) do begin
			if NotDestroyed( Part ) then begin
				if ( Part^.G = GG_Module ) or ( Part^.G = GG_Weapon ) then begin
					RT := NAttValue( Part^.NA , NAG_WeaponModifier , NAS_Recharge);
					{ Set the Call Time to this weapon's recharge time if it recharges quicker }
					{ than any other seen so far, and if it is currently recharging. }
					if ( RT < CT ) and ( RT > GB^.ComTime ) then CT := RT;
				end;
				if ( Part^.SubCom <> Nil ) then SeekWeapon( Part^.SubCom );
				if ( Part^.InvCom <> Nil ) then SeekWeapon( Part^.InvCom );
			end;
			Part := Part^.Next;
		end;
	end;

begin
	{ Set a default waiting period of a single round. If no weapon will }
	{ recharge before this time, return control to the player anyhow. }
	CT := GB^.ComTime + ClicksPerRound + 1;

	{ Check through all weapons to find which one recharges soonest. }
	SeekWeapon( Mek^.SubCom );

	{ Set the call time to whatever time was found. }
	SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CT );
end;

Function DefaultAtOp( Weapon: GearPtr ): Integer;
	{ Return the default Attack Options value for the weapon selected. }
var
	atop,PVal: Integer;
begin
	AtOp := 0;
	PVal := WeaponBVSetting( Weapon );

	if ( Weapon^.G = GG_Weapon ) then begin
		if ( ( Weapon^.S = GS_Ballistic ) or ( Weapon^.S = GS_BeamGun ) ) and ( Weapon^.Stat[ STAT_BurstValue ] > 0 ) then begin
			if PVal = BV_Max then begin
				AtOp := Weapon^.Stat[ STAT_BurstValue ];
			end else if PVal = BV_Half then begin
				AtOp := Weapon^.Stat[ STAT_BurstValue ] div 2;
				if AtOp < 1 then AtOp := 1;
			end else if PVal = BV_Quarter then begin
				AtOp := Weapon^.Stat[ STAT_BurstValue ] div 4;
				if AtOp < 1 then AtOp := 1;
			end;
		end else if Weapon^.S = GS_Missile then begin
			if PVal = BV_Max then begin
				AtOp := Weapon^.Stat[ STAT_Magazine ] - 1;
				if AtOp < 0 then AtOp := 0;
			end else if PVal = BV_Half then begin
				AtOp := ( Weapon^.Stat[ STAT_Magazine ] div 2 ) - 1;
				if AtOp < 0 then AtOp := 0;
			end else if PVal = BV_Quarter then begin
				AtOp := ( Weapon^.Stat[ STAT_Magazine ] div 4 ) - 1;
				if AtOp < 0 then AtOp := 0;
			end;

		end;
	end;
	DefaultAtOp := atop;
end;

Procedure RLSmartAttack( GB: GameBoardPtr; Mek: GearPtr );
	{ Turn and then fire upon the PC's target. }
var
	Enemy,Weapon: GearPtr;
	CD,MoveAction,T,TX,TY,N,AtOp: Integer;
begin
	{ Find out the mek's current target. }
	T := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Target );
	Enemy := LocateMekByUID( GB , T );
	TX := NAttValue( Mek^.NA , NAG_Location , NAS_SmartX );
	TY := NAttValue( Mek^.NA , NAG_Location , NAS_SmartY );

	{ Error check- if the smart attack isn't executed within five moves, }
	{ forget about it. }
	AddNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , 1 );
	if NAttValue( Mek^.NA , NAG_Location , NAS_SmartCount ) > 5 then begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );
		DialogMsg( MsgString( 'PCATTACK_OutOfArc' ) );
		Exit;
	end;

	{ Find the weapon being used in the attack. }
	Weapon := LocateGearByNumber( Mek , NAttValue( Mek^.NA , NAG_Location , NAS_SmartWeapon ) );
	if ( T = -1 ) and OnTheMap( TX , TY ) then begin
		{ If T=-1, the PC is firing at a spot instead of a }
		{ specific enemy. }
		if ArcCheck( GB , Mek , Weapon , TX , TY ) then begin
			{ Whatever else happens, the smartattack is over. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );

			{ The enemy is within the proper arc. Fire away! }
			if RangeArcCheck( GB , Mek , Weapon , TX , TY , TerrMan[ GB^.Map[ TX , TY ].terr ].Altitude ) then begin
				{ Everything is okay. Call the attack procedure. }
				AttackerFrontEnd( GB , Mek , Weapon , TX , TY , TerrMan[ GB^.Map[ TX , TY ].terr ].Altitude , DefaultAtOp( Weapon ) );

			end else begin
				DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
			end;
		end else begin
			{ Turn to face the target. }
			CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );

			MoveAction := NAV_TurnRight;

			{ Arcs CD and CD+7mod8 don't need to be checked, since }
			{ those are covered by the current F90 arc. }
			for t := 1 to 3 do begin
				if CheckArc( Mek , TX , TY , ( CD + T ) mod 8 ) then MoveAction := NAV_TurnRight
				else if CheckArc( Mek , TX , TY , ( CD + 7 - T ) mod 8 ) then MoveAction := NAV_TurnLeft;
			end;
			PrepAction( GB , Mek , MoveAction );
		end;

	end else if ( Enemy = Nil ) or ( Not GearOperational( Enemy ) ) or ( not MekVisible( GB , Enemy ) ) or ( Weapon = Nil ) or ( not ReadyToFire( GB , Mek , Weapon ) ) then begin
		{ This mecha is no longer a good target, or the weapon }
		{ selected is no longer valid. Cancel the SmartAttack. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );

	end else if ArcCheck( GB , Mek , Weapon , Enemy ) then begin
		{ Whatever else happens, the smartattack is over. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );

		{ See if we're aiming for the main body or a subcom. }
		N := NAttValue( Mek^.NA , NAG_Location , NAS_SmartTarget );
		if N > 0 then begin
			Enemy := LocateGearByNumber( Enemy , N );
			AtOp := 0;
		end else begin
			AtOp := DefaultAtOp( Weapon );
		end;

		{ The enemy is within the proper arc. Fire away! }
		if RangeArcCheck( GB , Mek , Weapon , Enemy ) then begin
			{ Everything is okay. Call the attack procedure. }
			AttackerFrontEnd( GB , Mek , Weapon , Enemy , AtOp );

		end else begin
			DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
		end;
	end else begin
		{ Turn to face the target. }
		CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );

		MoveAction := NAV_TurnRight;

		{ Arcs CD and CD+7mod8 don't need to be checked, since }
		{ those are covered by the current F90 arc. }
		for t := 1 to 3 do begin
			if CheckArc( Mek , Enemy , ( CD + T ) mod 8 ) then MoveAction := NAV_TurnRight
			else if CheckArc( Mek , Enemy , ( CD + 7 - T ) mod 8 ) then MoveAction := NAV_TurnLeft;
		end;
		PrepAction( GB , Mek , MoveAction );
	end;
end;


Procedure AimThatAttack( Mek,Weapon: GearPtr; CallShot: Boolean; GB: GameBoardPtr );
	{ A weapon has been selected; now, select a target. }
var
	WPM: RPGMenuPtr;
	N,AtOp: Integer;
begin
	if not ReadyToFire( GB , Mek , Weapon ) then begin
		DialogMsg( ReplaceHash( MsgString( 'ATA_NotReady' ) , GearName( Weapon ) ) );
		Exit;
	end;

	AtOp := DefaultAtOp( Weapon );
	if SelectTarget( GB , Mek , Weapon , CallShot , AtOp ) then begin
		{ Check to make sure the target is within maximum range, }
		{ and that it falls within the correct arc. }
		AtOp := DefaultAtOp( Weapon );

		if ( LOOKER_Gear = Nil ) and RangeArcCheck( GB , Mek , Weapon , LOOKER_X , LOOKER_Y , TerrMan[ GB^.Map[ LOOKER_X , LOOKER_Y ].terr ].Altitude ) then begin
			AttackerFrontEnd( GB , Mek , Weapon , LOOKER_X , LOOKER_Y , TerrMan[ GB^.Map[ LOOKER_X , LOOKER_Y ].terr ].Altitude , DefaultAtOp( Weapon ) );

		end else if LOOKER_Gear = Nil then begin
			if ( Range( Mek , LOOKER_X , LOOKER_Y ) > WeaponRange( GB , Weapon ) ) and ( Range( Mek , LOOKER_X , LOOKER_Y ) > ThrowingRange( GB , Mek , Weapon ) ) then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
			end else if InterfaceType( GB , Mek ) = MenuBasedInput then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfArc' ) );
			end else begin
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , NAV_SmartAttack );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , 0 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , FindGearIndex( Mek , Weapon ) );
				SetNAtt( Mek^.NA , NAG_EPisodeData , NAS_Target , -1 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartX , LOOKER_X );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartY , LOOKER_Y );

				RLSmartAttack( GB , Mek );
			end;

		end else if ( FindRoot( LOOKER_Gear ) = FindRoot( Mek ) ) then begin
			DialogMSG( 'Attack cancelled.' );

		end else if RangeArcCheck( GB , Mek , Weapon , LOOKER_Gear ) then begin
			{ Call the Attack procedure with the info we've gained. }
			DisplayGearInfo( LOOKER_Gear , gb );

			{ If a called shot was requested, create the menu here. }
			{ Note that called shots cannot be made using burst firing. }
			if CallShot and ( LOOKER_Gear^.SubCom <> Nil ) then begin
				{ Create a menu, fill it with bits. }
				WPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
				BuildGearMenu( WPM , LOOKER_Gear , GG_Module );
{$IFDEF SDLMODE}
				N := SelectMenu( WPM , @PCActionRedraw );
{$ELSE}
				N := SelectMenu( WPM );
{$ENDIF}
				if N <> -1 then begin
					LOOKER_Gear := LocateGearByNumber( LOOKER_Gear , N );
				end;
				DisposeRPGMenu( WPM );
				AtOp := 0;
			end;

			AttackerFrontEnd( GB , Mek , Weapon , LOOKER_Gear , AtOp );

		end else begin
			if ArcCheck( GB , Mek , Weapon , LOOKER_Gear ) then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
			end else if InterfaceType( GB , Mek ) = MenuBasedInput then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfArc' ) );
			end else begin
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , NAV_SmartAttack );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , 0 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , FindGearIndex( Mek , Weapon ) );

				if CallShot and ( LOOKER_Gear^.SubCom <> Nil ) then begin
					{ Create a menu, fill it with bits. }
					WPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
					BuildGearMenu( WPM , LOOKER_Gear , GG_Module );
{$IFDEF SDLMODE}
					N := SelectMenu( WPM , @PCActionRedraw );
{$ELSE}
					N := SelectMenu( WPM );
{$ENDIF}
					if N <> -1 then begin
						SetNAtt( Mek^.NA , NAG_Location , NAS_SmartTarget , N );
					end else begin
						SetNAtt( Mek^.NA , NAG_Location , NAS_SmartTarget , 0 );
					end;
					DisposeRPGMenu( WPM );
				end else begin
					SetNAtt( Mek^.NA , NAG_Location , NAS_SmartTarget , 0 );
				end;


				RLSmartAttack( GB , Mek );
			end;
		end;
	end;

end;

Procedure DoPlayerAttack( Mek: GearPtr; GB: GameBoardPtr );
	{ The player has accessed the weapons menu. Select an active }
	{ weapon, then select a target. If the target is within range, }
	{ process the attack and report upon it to the user. }
const
	CalledShotOff = '  Called Shot: Off [/]';
	CalledShotOn = '  Called Shot: On [/]';
var
	WPM: RPGMenuPtr;	{ The Weapons Menu }
	MI,MI2: RPGMenuItemPtr;	{ For checking all the weapons. }
	Weapon: GearPtr;	{ Also for checking all the weapons. }
	N: Integer;
	CallShot: Boolean;
begin
	{ Error check - make sure that MEK is a valid, active master gear. }
	if not IsMasterGear( Mek ) then exit;

	{ *** START MENU BUILDER *** }
	{ Create the weapons menu. }
	{ Travel through the mek structure in the standard pattern }
	{ looking for things which may be attacked with. }
	{ WEAPONS - may be attacked with. Duh. }
	{ MODULES - Arms enable punching, Legs enable kicking, tails enable tail whipping. }
	{ AMMO - Missiles with Range=0 in the general inventory may be thrown. }
	WPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AttachMenuDesc( WPM , ZONE_Menu1 );
	WPM^.DTexColor := InfoGreen;

	BuildGearMenu( WPM , Mek , GG_Weapon );
	BuildGearMenu( WPM , Mek , GG_Module );
	BuildGearMenu( WPM , Mek , GG_Ammo );
	AlphaKeyMenu( WPM );

	{ Next, filter the generated list so that only weapons which are ready }
	{ to attack may be attacked with. }
	MI := WPM^.FirstItem;
	while MI <> Nil do begin
		MI2 := MI^.Next;

		Weapon := LocateGearByNumber( Mek , MI^.Value );

		if not ReadyToFire( GB , Mek , Weapon ) then begin
			{ This weapon isn't ready to fire. Remove it from the menu. }
			RemoveRPGMenuItem( WPM , MI );

		end else begin
			{ This weapon _is_ ready to fire. Give it a spiffy }
			{ description. }
			MI^.desc := GearName( Weapon ) + ' ' + WeaponDescription( Weapon );
		end;

		MI := MI2;
	end;

	{ Add the firing options. Save the address of the called shot entry. }
	MI := AddRPGMenuItem( WPM , CalledShotOff , -4 );
	AddRPGMenuKey( WPM , '/' , -4 );
	CallShot := False;
	AddRPGMenuItem( WPM , '  Wait for recharge [.]' , -3 );
	AddRPGMenuKey( WPM , '.' , -3 );
	AddRPGMenuItem( WPM , '  Options [?]' , -2 );
	AddRPGMenuKey( WPM , '?' , -2 );
	AddRPGMenuItem( WPM , '  Cancel [ESC]' , -1 );
	{ *** END MENU BUILDER *** }

	{ Actually get a selection from the menu. }
	{ A loop is needed so that if the player wants to set options, the game }
	{ will return directly to the weapons menu afterwards. }
	repeat
		{ Need to clear the entire menu zone, just to make sure the }
		{ display looks right. }
{$IFDEF SDLMODE}
		N := SelectMenu( WPM , @PCActionRedraw );
{$ELSE}
		ClrZone( ZONE_Menu );
		N := SelectMenu( WPM );
{$ENDIF}
		if N = -2 then SetPlayOptions( GB , Mek )
		else if N = -4 then begin
			CallShot := Not CallShot;
			if CallShot then MI^.msg := CalledShotOn
			else MI^.msg := CalledShotOff;
		end;
	until ( N <> -2 ) and ( N <> -4 );

	{ Get rid of the menu. We don't need it any more. }
	DisposeRPGMenu( WPM );

	{ If the selection wasn't cancelled, proceed with the attack. }
	if N > -1 then begin
		{ A weapon has been selected. Now, select a target. }
		Weapon := LocateGearByNumber( Mek , N );

		{ Call the LOOKER procedure to select a target. }
		AimThatAttack( Mek , Weapon , CallShot , GB );

	end else if N = -3 then begin
		{ Wait on Recharge was selected from the menu. }
		WaitOnRecharge( GB , Mek );
	end;

	ClrZone( ZONE_Menu );
end;

Procedure DoEjection( GB: GameBoardPtr; Mek: GearPtr );
	{ The player wants to eject from this mecha. First prompt to }
	{ make sure that the PC is serious about this, then do the }
	{ ejection itself. }
var
	RPM: RPGMenuPtr;
	Pilot: GearPtr;
	P: Point;
begin
	{ Error check - One cannot eject from oneself. }
	{ The PC must be in a mecha to use this command. }
	if ( Mek = Nil ) or ( Mek^.G <> GG_Mecha ) then Exit;

	{ Make sure that the player is really serious about this. }
	DialogMsg( MsgString( 'EJECT_Prompt' ) );
	RPM := CreateRPGMenu( teamcolor( GB , mek ) , StdWhite , ZONE_Menu2 );
	AddRPGMenuItem( RPM , MsgString( 'EJECT_Yes' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'EJECT_No' ) , -1 );
	SetItemByPosition( RPM , 2 );

{$IFDEF SDLMODE}
	if SelectMenu( RPM , @PCActionRedraw ) <> -1 then begin
{$ELSE}
	if SelectMenu( RPM ) <> -1 then begin
{$ENDIF}
		{ Better set the following triggers. }
		SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) ) );
		SetTrigger( GB , TRIGGER_UnitEliminated2 + BStr( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID ) ) );

		P := GearCurrentLocation( Mek );

		repeat
			Pilot := ExtractPilot( Mek );

			if Pilot <> Nil then begin
				DialogMsg( GearName( Pilot ) + MsgString( 'EJECT_Message' ) + GearName( Mek ) + '.' );
				{ In a safe area, deploy the pilot in the same tile as the mecha. }
				if IsSafeArea( GB ) and not IsBlocked( Pilot , GB , P.X , P.Y ) then begin
					SetNAtt( Pilot^.NA , NAG_Location , NAS_X , P.X );
					SetNAtt( Pilot^.NA , NAG_Location , NAS_Y , P.Y );
					DeployMek( GB , Pilot , True );
				end else begin
					DeployMek( GB , Pilot , False );
				end;
			end;

		until Pilot = Nil;

		if IsSAfeArea( GB ) then begin
			SetSAtt( Mek^.SA , 'PILOT <>' );
		end else begin
			{ Since this mecha is being abandoned in a combat zone, set the team }
			{ value to 0. Otherwise the PC could just use ejection }
			{ as an easy out to any combat without risking losing a }
			{ mecha. If the player team wins and gets salvage, they }
			{ should get this mek back anyhow. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_Team , 0 );
		end;
	end;

	DisposeRPGMenu( RPM );
end;

Procedure DoRest( GB: GameBoardPtr; Mek: GearPtr );
	{ The PC wants to rest, probably because he's out of stamina. Take a break for }
	{ an hour or so of game time. }
begin
	if ( NAttValue( LocatePilot( Mek )^.NA , NAG_Condition , NAS_Hunger ) > HUNGER_PENALTY_STARTS ) then begin
		DialogMsg( MsgString( 'REST_TooHungry' ) );
	end else if IsSafeArea( GB ) then begin
		DialogMsg( MsgString( 'REST_OK' ) );
		QuickTime( GB , 3600 );
		WaitAMinute( GB , Mek , 1 );
	end else begin
		DialogMsg( MsgString( 'REST_NotHere' ) );
	end;
end;




procedure ShiftGears( Mek: GearPtr );
	{ Set the mek's MoveMode attribute to the next }
	{ active movemode that this mek has. }
var
	MM,CMM: Integer;
begin
	CMM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	MM := CMM mod NumMoveMode + 1;

	while ( MM <> CMM ) and ( BaseMoveRate( Mek , MM ) <= 0 ) do begin
		MM := MM mod NumMoveMode + 1;
	end;

	if MM <> 0 then SetNAtt( Mek^.NA , NAG_Action , NAS_MoveMode , MM);
end;

Procedure KeyMapDisplay;
	{ Display the game commands and their associated keystrokes. }
var
	RPM: RPGMenuPtr;
	RPI: RPGMenuItemPtr;
	T: Integer;
begin
	DialogMSG( MSgString( 'HELP_Prompt' ) );
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AttachMenuDesc( RPM , ZONE_Menu1 );

	for t := 1 to NumMappedKeys do begin
		AddRPGMenuItem( RPM , KeyMap[T].CmdName , T , KeyMap[T].CmdDesc );
	end;

	RPMSortAlpha( RPM );
	RPI := RPM^.FirstItem;
	while RPI <> Nil do begin
		RPI^.msg := KeyMap[RPI^.Value].KCode + ' - ' + RPI^.msg;
		RPI := RPI^.Next;
	end;

{$IFDEF SDLMODE}
	SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
	SelectMenu( RPM );
{$ENDIF}

	DisposeRPGMenu( RPM );
	ClrZone( ZONE_Menu );
end;

Procedure BrowseTextFile( GB: GameBoardPtr; FName: String );
	{ Load and display a text file, then clean up afterwards. }
var
	txt: SAttPtr;
begin
	txt := LoadStringList( FName );

	if txt <> Nil then begin
		MoreText( txt , 1 );
		DisposeSAtt( txt );
		GFCombatDisplay( GB );
	end;
end;

Procedure PCRLHelp( GB: GameBoardPtr );
	{ Show help information for all the commands available to the }
	{ RogueLike interface. }
var
	RPM: RPGMenuPtr;
	A: Integer;
begin
	DialogMSG( MSgString( 'HELP_Prompt' ) );
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );

	AddRPGMenuItem( RPM , MsgString( 'HELP_KeyMap' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_Chara' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_Mecha' ) , 3 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_FieldHQ' ) , 4 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_Exit' ) , -1 );

	repeat
{$IFDEF SDLMODE}
		A := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
		A := SelectMenu( RPM );
{$ENDIF}

		case A of
			1: KeyMapDisplay;
			2: BrowseTextFile( GB , Chara_Help_File );
			3: BrowseTextFile( GB , Mecha_Help_File );
			4: BrowseTextFile( GB , FieldHQ_Help_File );
		end;
	until A = -1;

	DisposeRPGMenu( RPM );
end;

Procedure RLQuickAttack( GB: GameBoardPtr; PC: GearPtr );
	{ Try to attack. If no weapon is ready, wait for recharge. }
var
	Weapon: GearPtr;
	procedure SeekWeapon( Part: GearPtr );
		{ Look for a weapon which is ready to fire, select }
		{ based on range. }
	var
		WR1,WR2: Integer;
	begin
		while ( Part <> Nil ) do begin

			if ReadyToFire( GB , PC , Part ) then begin
				WR1 := WeaponRange( GB , Weapon );
				if ThrowingRange( GB , PC , Weapon ) > WR1 then WR1 := ThrowingRange( GB , PC , Weapon );
				WR2 := WeaponRange( GB , Part );
				if ThrowingRange( GB , PC , Part ) > WR2 then WR2 := ThrowingRange( GB , PC , Part );

				if Weapon = Nil then Weapon := Part
				else  if WR2 > WR1 then Weapon := Part
				else  if ( WR2 = WR1 ) and ( WeaponDC(Part,0) > WeaponDC(Weapon,0) ) then Weapon := Part;
			end;

			if ( Part^.SubCom <> Nil ) then SeekWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
begin
	{ Start by looking for a weapon to use. }
	Weapon := Nil;
	SeekWeapon( PC^.SubCom );
	SeekWeapon( PC^.InvCom );

	if Weapon = Nil then begin
		DialogMsg( 'You don''t have a weapon ready!' );
		WaitOnRecharge( GB , PC );

	end else begin
		AimThatAttack( PC , Weapon , False , GB );

	end;
end;

Function CoreBumpAttack( GB: GameBoardPtr; PC,Target: GearPtr ): Boolean;
	{ Try to attack TARGET. If no weapon is ready, wait for recharge. }
	{ If an attack takes place, clear the location var SmartAction. }
var
	Weapon: GearPtr;
	function NewWeaponBetter( W1,W2: GearPtr ): Boolean;
		{ Return TRUE if W2 is better than W1 for the purposes }
		{ of smartbump attacking, or FALSE otherwise. }
		{ A better weapon is a short range one with the best damage. }
	var
		R1,R2: Integer;
	begin
		R1 := WeaponRange( Nil , W1 );
		R2 := WeaponRange( Nil , W2 );
		if ( R2 < 3 ) and ( R1 > 2 ) then begin
			NewWeaponBetter := True;
		end else if ( ( R1 div 3 ) = ( R2 div 3 ) ) and ( WeaponDC( W2 , 0 ) > WeaponDC( W1 , 0 ) ) then begin
			NewWeaponBetter := True;
		end else begin
			NewWeaponBetter := False;
		end;
	end;
	procedure SeekWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of hitting target. }
		{ Preference is given to short-range weapons. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Module ) or ( Part^.G = GG_Weapon ) then begin
				if ReadyToFire( GB , PC , Part ) and RangeArcCheck( GB , PC , Part , Target ) then begin
					if Weapon = Nil then Weapon := Part
					else begin
						if NewWeaponBetter( Weapon , Part ) then begin
							Weapon := Part;
						end;
					end;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
begin
	{ Start by looking for a weapon to use. }
	Weapon := Nil;
	SeekWeapon( PC^.SubCom );

	if Weapon = Nil then begin
		CoreBumpAttack := False;
	end else begin
		{ Note that BumpAttacks are always done at AtOp = 0. }
		AttackerFrontEnd( GB , PC , Weapon , Target , 0 );
		SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , 0 );
		CoreBumpAttack := True;
	end;
end;

Procedure RLBumpAttack( GB: GameBoardPtr; PC,Target: GearPtr );
	{ Call the core bumpattack procedure, cancelling the action if it fails. }
begin
	if not CoreBumpAttack( GB , PC , Target ) then begin
		DialogMsg( 'You don''t have a weapon ready!' );
		WaitOnRecharge( GB , PC );
		SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , 0 );
	end;
end;

Procedure PCPlayInstrument( GB: GameBoardPtr; PC,Instrument: GearPtr );
	{ The PC is playing an instrument. Whee! Check how many positive }
	{ reactions the PC scores. The PC might also earn money, if the }
	{ public response is positive enough. }
var
	Success: LongInt;
	msg: String;
begin
	{ Call the performance procedure to find out how well the }
	{ player has done. }
	Success := UsePerformance( GB , PC , Instrument );

	msg := ReplaceHash( MsgString( 'PERFORMANCE_Base' ) , GearName( Instrument ) );

	{ Print an appropriate message. }
	if Success > 0 then begin
		{ Good show! The PC made some money as a busker. }
		msg := msg + ' ' + ReplaceHash( MsgString( 'PERFORMANCE_DidWell' + BStr( Random( 3 ) ) ) , BStr( Success ) );
	end else if Success < 0 then begin
		{ The PC flopped. No money made, and possibly damage }
		{ to his reputation. }
		msg := msg + ' ' + MsgString( 'PERFORMANCE_Horrible' + BStr( Random( 3 ) ) );
	end;

	DialogMsg( msg );
end;

Procedure ContinuousItemUse( GB: GameBoardPtr; Mek: GearPtr );
	{ An item is in continuous use. Find out what item it is, }
	{ and use it. }
var
	Item: GearPtr;
begin
	Item := LocateGearByNumber( Mek , NAttValue( Mek^.NA , NAG_Location , NAS_SmartWeapon ) );
	if ( Item <> Nil ) and NotDestroyed( Item ) and ( Item^.G = GG_Usable ) then begin
		{ Depending upon what kind of usable item this is, }
		{ branch to a different procedure. }
		Case Item^.S of
			GS_Instrument: PCPlayInstrument( GB , Mek , Item );
		else SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		end;

		{ Decrease the usage count by one. }
		{ If it drops to zero, end this action. }
		{ Otherwise add a delay for the next action. }
		AddNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , -1 );
		if NAttValue( Mek^.NA , NAG_Location , NAS_SmartCount ) < 1 then SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 )
		else WaitAMinute( GB , Mek , ReactionTime( Mek ) );
	end else begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
	end;
end;

Procedure RLSmartGo( GB: GameBoardPtr; Mek: GearPtr );
	{ The PC is going somewhere. March him in the right direction. }
var
	DX,DY: Integer;
begin
	DX := NAttValue( Mek^.NA , NAG_Location , NAS_SmartX );
	DY := NAttValue( Mek^.NA , NAG_Location , NAS_SmartY );

	AddNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , -1 );

	IF NAttValue( Mek^.NA , NAG_Location , NAS_SmartCount ) < 1 then begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
	end else if not MOVE_MODEL_TOWARDS_SPOT( Mek , GB , DX , DY ) then begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
	end;
end;

Procedure RLSmartAction( GB: GameBoardPtr; Mek: GearPtr );
	{ Do the smart bump! What is smart bump? Well, in most games of }
	{ this sort bumping into another model will cause you to attack it. }
	{ In this game I wanted the player's model to react semi-intelligently }
	{ to stuff it bumps into. If it's an enemy, attack it. If it's a }
	{ friend, talk to it. If it's a wall, just look at it... }
var
	CD,SD: Integer;	{ Current Direction, Smart Direction }
	T,MoveAction: Integer;
	P,P2: Point;
	M2: GearPtr;
begin
	CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );
	SD := NAttValue( Mek^.NA , NAG_Location , NAS_SmartAction );

	{ First, check to see if we have chosen a continuous action other }
	{ than simply walking. }
	if SD = NAV_SmartAttack then begin
		RLSmartAttack( GB , Mek );
	end else if SD = NAV_UseItem then begin
		ContinuousItemUse( GB , Mek );
	end else if SD = NAV_SmartGo then begin
		RLSmartGo( GB , Mek );

	end else if CD <> Roguelike_D[ SD ] then begin
		{ Turn to face the required direction. }
		P := GearCurrentLocation( Mek );
		P.X := P.X + AngDir[ Roguelike_D[ SD ] , 1 ];
		P.Y := P.Y + AngDir[ Roguelike_D[ SD ] , 2 ];

		M2 := FindVisibleBlockerAtSpot( GB , P.X , P.Y );

		if ( M2 <> Nil ) and GearOperational( M2 ) and AreEnemies( GB , Mek , M2 ) and CoreBumpAttack( GB , Mek , M2 ) then begin
			{ If the attack was performed, cancel the SmartAction. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );

		end else begin
			MoveAction := NAV_TurnRight;
			for t := 1 to 4 do begin
				if (( CD + T ) mod 8 ) = Roguelike_D[ SD ] then MoveAction := NAV_TurnRight
				else if (( CD + 8 - T ) mod 8 ) = Roguelike_D[ SD ] then MoveAction := NAV_TurnLeft;
			end;
			PrepAction( GB , Mek , MoveAction );
		end;

	end else begin
		{ We are already looking in the correct direction. }
		{ Do something. }
		P := GearCurrentLocation( Mek );
		P.X := P.X + AngDir[ CD , 1 ];
		P.Y := P.Y + AngDir[ CD , 2 ];

		M2 := FindVisibleBlockerAtSpot( GB , P.X , P.Y );

		if ( M2 = Nil ) or not GearOperational( M2 ) then begin
			{ CLear the SmartBump counter. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );

			if IsBlocked( Mek , GB , P.X , P.Y ) then begin
				DialogMsg( 'Blocked!' );
			end else begin
				{ The move isn't blocked, so walk straight ahead. }
				if PC_SHOULD_RUN and ( CurrentStamina( Mek ) > 0 ) then begin
					PrepAction( GB , Mek , NAV_FullSpeed );
				end else begin
					PrepAction( GB , Mek , NAV_NormSpeed );
					PC_SHOULD_RUN := False;
				end;
			end;

		end else if ( M2^.G = GG_Prop ) or not IsMasterGear( M2 ) then begin
			{ M2 is an object of some type. Try using it. }
			{ CLear the SmartBump counter. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
			PrepAction( GB , Mek , NAV_Stop );
			UsePropFrontEnd( GB , Mek , M2 , 'USE' );

		end else if AreEnemies( GB , Mek , M2 ) then begin
			{ M2 is an enemy! Thwack it! Thwack it now!!! }
			RLBumpAttack( GB , Mek , M2 );

		end else if ( NAttValue( M2^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and not IsObstacle( GB , Mek , GB^.Map[ P.X , P.Y ].terr ) then begin
			{ M2 is a lancemate. Try changing places with it. }
			{ This will happen outside of the normal movement code... I hope that }
			{ it won't be exploitable... }
			P := GearCurrentLocation( Mek );
			P2 := GearCurrentLocation( M2 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_X , P2.X );
			SetNAtt( Mek^.NA , NAG_Location , NAS_Y , P2.Y );
			SetNAtt( M2^.NA , NAG_Location , NAS_X , P.X );
			SetNAtt( M2^.NA , NAG_Location , NAS_Y , P.Y );
			WaitAMinute( GB , Mek , CPHMoveRate( Mek , GB^.Scale ) );
			WaitAMinute( GB , M2 , CPHMoveRate( M2 , GB^.Scale ) );
			RedrawTile( GB , Mek );
			RedrawTile( GB , M2 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );

		end else begin
			{ M2 isn't an enemy... try talking to it. }
			DoTalkingWithNPC( GB , Mek , M2 , False );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );

		end;


	end;
end;

Procedure RLWalker( GB: GameBoardPtr; Mek: GearPtr; D: Integer );
	{ The player has pressed a direction key and is preparing to }
	{ walk in that direction... or, alternatively, to attack }
	{ an enemy in that tile, or to speak with an ally in that tile. }
begin
	SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , D );
	RLSmartAction( GB , Mek );
end;

Procedure GameOptionMenu( Mek: GEarPtr; GB: GameBoardPtr );
	{ Let the user set options from this menu. }
	{ -> Combat Settings }
	{ -> Quit Game }
var
	N: Integer;
	RPM: RPGMenuPtr;
begin
	RPM := CreateRPGMenu( teamcolor( GB , mek ) , StdWhite , ZONE_Menu );
	AddRPGMenuItem( RPM , 'Inventory' , 2 );
	AddRPGMenuItem( RPM , 'Get Item' , 3 );
	AddRPGMenuItem( RPM , 'Enter Location' , 4 );
	AddRPGMEnuItem( RPM , 'Do Repairs' , 5 );
	AddRPGMenuItem( RPM , 'Combat Settings' , 1 );
	AddRPGMEnuItem( RPM , 'Eject from Mecha' , -6 );
	AddRPGMenuItem( RPM , 'Character Info' , 6 );
	AddRPGMenuItem( RPM , 'Quit Game' , -2 );
	AddRPGMenuItem( RPM , 'Return to Main' , -1 );

	DialogMsg('Advanced options menu.');

	repeat
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		if N = 1 then SetPlayOptions( GB , Mek )
		else if N = 2 then PCBackpackMenu( GB , Mek , True )
		else if N = 3 then PCGetItem( GB , Mek )
		else if N = 4 then PCEnter( GB , Mek )
		else if N = 5 then PCActivateSkill( GB , Mek )
		else if N = 6 then PCViewChar( GB , Mek )
		else if N = -6 then DoEjection( GB , Mek )
		else if N = -2 then GB^.QuitTheGame := True;
	until ( N < 0 ) or ( NAttValue( Mek^.NA , NAG_Action , NAS_CallTime ) > GB^.ComTime );

	DisposeRPGMenu( RPM );
end;

Procedure InfoMenu( Mek: GEarPtr; GB: GameBoardPtr );
	{ This menu contains various information utilities. }
	{ -> Examine Map }
	{ -> Pilot Stats }
var
	N: Integer;
	RPM: RPGMenuPtr;
begin
	RPM := CreateRPGMenu( teamcolor( GB , mek ) , StdWhite , ZONE_Menu );
	AddRPGMenuItem( RPM , 'Examine Map' , 1 );
	AddRPGMenuItem( RPM , 'Mecha Browser' , 3 );
	AddRPGMenuItem( RPM , 'Return to Main' , -1 );

	DialogMsg('Information Menu.');

	repeat
{$IFDEF SDLMODE}
		N := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}
		if N = 1 then LookAround( GB , Mek )
{$IFDEF SDLMODE}
		else if N = 3 then MechaPartBrowser( Mek , @PCActionRedraw );
{$ELSE}
		else if N = 3 then MechaPartBrowser( Mek );
{$ENDIF}

	until N < 0;

	DisposeRPGMenu( RPM );
end;

Procedure MenuPlayerInput( Mek: GearPtr; GB: GameBoardPtr );
	{ This mek belongs to the player. Get input. }
var
	MoveMode, T , S: Integer;
	RPM: RPGMenuPtr;
begin
	{ Create the action menu. }
	RPM := CreateRPGMenu( teamcolor( GB , mek ) , StdWhite , ZONE_Menu );

	{ Add movement options - Cruise, Full, Turn-L, Turn-R }
	{ - if it's appropriate to do so. Check to make sure }
	{ that the mek is capable of moving first. }
	MoveMode := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	if CPHMoveRate( Mek , gb^.Scale ) > 0 then begin
		if MoveMode = MM_Walk then begin
			AddRPGMenuItem( RPM , 'Walk' , NAV_NormSpeed );
			AddRPGMenuItem( RPM , 'Run' , NAV_FullSpeed );
		end else begin
			AddRPGMenuItem( RPM , 'Cruise Speed' , NAV_NormSpeed );
			if MoveLegal( Mek , NAV_FullSpeed , GB^.ComTime ) then AddRPGMenuItem( RPM , 'Full Speed' , NAV_FullSpeed );
		end;
		if MoveLegal( Mek , NAV_TurnLeft , GB^.ComTime ) then AddRPGMenuItem( RPM , '<<< Turn Left', NAV_TurnLeft );
		if MoveLegal( Mek , NAV_TurnRight , GB^.ComTime ) then AddRPGMenuItem( RPM , '    Turn Right >>>', NAV_TurnRight);
		if MoveLegal( Mek , NAV_Reverse , GB^.ComTime ) then AddRPGMenuItem( RPM , '    Reverse', NAV_Reverse);
	end;

	{ Add movemode switching options, if applicable. }
	{ Check to see what movemodes the mek has }
	{ available. }
	for t := NumMoveMode downto 1 do begin
		{ We won't add a switch option for the move mode currently }
		{ being used. }
		if T <> MoveMode then begin
			if ( BaseMoveRate( Mek , T ) > 0 ) and MoveLegal( Mek , T , NAV_NormSpeed , GB^.ComTime ) then begin
				if T = MM_Fly then begin
					if JumpTime( Mek ) > 0 then begin
						AddRPGMenuItem( RPM , 'Jump' , 100+T );
					end else begin
						AddRPGMenuItem( RPM , MoveModeName[T] , 100+T );
					end;
				end else begin
					AddRPGMenuItem( RPM , MoveModeName[T] , 100+T );
				end;
			end;
		end;
	end;

	{ Add the Stop/Wait option. For meks which have }
	{ had their movement systems disabled, this will }
	{ be the only option. }
	if NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction ) = NAV_Stop then begin
		AddRPGMenuItem( RPM , 'Wait', -1 );
	end else begin
		AddRPGMenuItem( RPM , 'Stop', -1 );
	end;

	AddRPGMenuItem( RPM , 'Weapons Menu', -3 );
	AddRPGMenuItem( RPM , 'Info Menu', -2 );
	AddRPGMenuItem( RPM , 'Options Menu', -5 );
	AddRPGMenuItem( RPM , 'Search' , -6 );

	{ Set the SelectItem field of the menu to the }
	{ item which matches the mek's last menu action. }
	SetItemByValue( RPM , NAttValue( Mek^.NA , NAG_Location , NAS_LastMenuItem ) );

	RPM^.Mode := RPMNoCleanup;

	{ Keep processing input from the mek until we get }
	{ an input which changes the CallTime. }
	while (NAttValue( Mek^.NA , NAG_Action , NAS_CallTime) <= GB^.ComTime ) and (not GB^.QuitTheGame) and GearActive( Mek ) do begin
		{ Indicate the mek to get the action for, }
		{ and prepare the display. }
		DisplayGearInfo( Mek , gb );
{$IFDEF SDLMODE}
		IndicateTile( GB , Mek , True );
{$ELSE}
		IndicateTile( GB , Mek );
{$ENDIF}
		ClrZone( ZONE_Menu );

		{ Input the action. }
{$IFDEF SDLMODE}
		S := SelectMenu( RPM , @PCActionRedraw );
{$ELSE}
		S := SelectMenu( RPM );
{$ENDIF}

		{ Set ETA, movement stats, whatever. }
		if ( S > -1 ) and ( S < 100 ) then begin
			{ Some basic movement command. }
			PrepAction( GB , Mek , S );

		end else if ( S div 100 ) = 1 then begin
			{ A movemode switch has been selected. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveAction , NAV_Stop );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveMode , S mod 100 );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + 1 );

		end else if S = -1 then begin
			{ WAIT or STOP, depending... }
			PrepAction( GB , Mek , NAV_Stop );

		end else if S = -2 then begin
			InfoMenu( Mek , GB );
		end else if S = -3 then begin
			DoPlayerAttack( Mek , GB );
		end else if S = -5 then begin
			GameOptionMenu( Mek , GB );
		end else if S = -6 then begin
			PCSearch( GB , Mek );
		end; {if}

	end; {While}

	{ Record the last used menu action. }
	SetNAtt( Mek^.NA , NAG_Location , NAS_LastMenuItem , S );

	{ De-Indicate the mek. }
	RedrawTile( gb , mek );

	{ De-allocate the menu. }
	DisposeRPGMenu( RPM );

end;

Procedure ShowRep( PC: GearPtr );
	{ Display all of the PC's reputations. }
	{ This is a debugging command. }
var
	T,N: Integer;
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		for t := 1 to 7 do begin
			N := NAttValue( PC^.NA , NAG_CharDescription , -T );
			if N <> 0 then DialogMsg( PersonalityTraitDesc( T , N ) + ' (' + BStr( Abs( N ) ) + ')' );
		end;
	end;
end;

Procedure DirectScript( GB: GameBoardPtr );
	{ CHEAT COMMAND! Directly invoke an ASL script. }
var
	event: String;
begin
{$IFDEF SDLMODE}
	event := GetStringFromUser( 'DEBUG CODE 45123' , @PCActionRedraw );
{$ELSE}
	event := GetStringFromUser( 'DEBUG CODE 45123' );
{$ENDIF}
	if event <> '' then begin
		GFCombatDisplay( GB );
		InvokeEvent( event , GB , GB^.Scene , event );
	end else begin
		GFCombatDisplay( GB );
	end;
end;

Procedure PCLeftButton( GB: GameBoardPtr; PC: GearPtr );
	{ The PC has just hit a mouse button. Do something. }
var
	P1,P2: Point;
	M,Weapon: GearPtr;
	function NewWeaponBetter( W1,W2: GearPtr ): Boolean;
		{ Return TRUE if W2 is better than W1 for the purposes }
		{ of smartbump attacking, or FALSE otherwise. }
		{ A better weapon is a short range one with the best damage. }
	var
		R1,R2: Integer;
	begin
		R1 := WeaponRange( Nil , W1 );
		R2 := WeaponRange( Nil , W2 );
		if R2 > R1 then begin
			NewWeaponBetter := True;
		end else if ( WeaponDC( W2 , 0 ) > WeaponDC( W1 , 0 ) ) and ( R2 = R1 ) then begin
			NewWeaponBetter := True;
		end else begin
			NewWeaponBetter := False;
		end;
	end;
	procedure SeekWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of hitting target. }
		{ Preference is given to short-range weapons. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Module ) or ( Part^.G = GG_Weapon ) then begin
				if ReadyToFire( GB , PC , Part ) then begin
					if Weapon = Nil then Weapon := Part
					else begin
						if NewWeaponBetter( Weapon , Part ) then begin
							Weapon := Part;
						end;
					end;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
const
	WalkDir: Array [-1..1,-1..1] of Byte = (
		( 7 , 4 , 1 ),
		( 8 , 5 , 2 ),
		( 9 , 6 , 3 )
	);
begin
	{ Find out where the PC is. }
	P1 := GearCurrentLocation( PC );

	{ Find out where the PC has clicked. }
{$IFDEF SDLMODE}
	P2 := MouseMapPos;

	{ If the tile is more than one square away, check for an enemy. }
	{ If there is an enemy, attack it. }
	{ If there's no enemy, walk there. }
	{ Otherwise smartbump in the appropriate direction. }
	if ( P2.X = P1.X ) and ( P2.Y = P1.Y ) then begin
		PrepAction( GB , PC , NAV_Stop );
		PCEnter( GB , PC );

	end else if ( Abs( P2.X - P1.X ) <= 1 ) and ( Abs( P2.Y - P1.Y ) <= 1 ) then begin
		RLWalker( GB , PC , WalkDir[ P2.X - P1.X , P2.Y - P1.Y ] );

	end else begin
		M := FindVisibleBlockerAtSpot( GB , P2.X , P2.Y );

		if ( M <> Nil ) and GearOperational( M ) and AreEnemies( GB , PC , M ) then begin
			SetNAtt( PC^.NA , NAG_EpisodeData , NAS_Target , NAttValue( M^.NA , NAG_EpisodeData , NAS_UID ) );
			SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , NAV_SmartAttack );
			Weapon := Nil;
			SeekWeapon( PC^.SubCom );
			if Weapon <> Nil then SetNAtt( PC^.NA , NAG_Location , NAS_SmartWeapon , FindGearIndex( PC , Weapon ) );
			RLSmartAction( GB , PC );
		end else if ( M <> Nil ) and ( M^.G = GG_Character ) and GearOperational( M ) and not AreEnemies( GB , PC , M ) then begin
			{ If it's an NPC, try talking to it. }
			DoTalkingWIthNPC( GB , PC , M , False );
		end else begin
			SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , NAV_SmartGo );
			SetNAtt( PC^.NA , NAG_Location , NAS_SmartCount , 25 );
			SetNAtt( PC^.NA , NAG_Location , NAS_SmartX , P2.X );
			SetNAtt( PC^.NA , NAG_Location , NAS_SmartY , P2.y );
			RLSmartAction( GB , PC );
		end;
	end;
{$ENDIF}
end;

Procedure PCRunToggle;
	{ If the PC is running, switch to walking. If he's walking, switch to running. }
begin
	PC_SHOULD_RUN := not PC_SHOULD_RUN;
	if PC_SHOULD_RUN then begin
		DialogMsg( MsgString( 'RUN_ON' ) );
	end else begin
		DialogMsg( MsgString( 'RUN_OFF' ) );
	end;
end;

Procedure RLPlayerInput( Mek: GearPtr; Camp: CampaignPtr );
	{ Allow the PC to control the action as per normal in a RL }
	{ game- move using the arrow keys, use other keys for everything }
	{ else. }
var
	KP: Char;	{ Key Pressed }
	GotMove: Boolean;
	Mobile: Boolean;
	P: Point;
begin
	{ Record where the mek currently is. }
	Mobile := BaseMoveRate( Mek ) > 0;

	if ( NAttValue( Mek^.NA , NAG_Location , NAS_SmartAction ) <> 0 ) and Mobile then begin
		{ The player is smartbumping. Call the appropriate procedure. }
		RLSmartAction( Camp^.GB , Mek );

	end else begin
		GotMove := False;

		{ Start the input loop. }
		while (NAttValue( Mek^.NA , NAG_Action , NAS_CallTime) <= Camp^.GB^.ComTime) and (not GotMove) and (not Camp^.GB^.QuitTheGame) and GearActive( Mek ) do begin
			{ Indicate the mek to get the action for. }
			DisplayGearInfo( Mek , Camp^.gb );
{$IFDEF SDLMODE}
			P := MouseMapPos;
			if OnTheMap( P.X , P.Y ) and Mouse_Active then MouseAtTile( Camp^.GB , P.X , P.Y );

			IndicateTile( Camp^.GB , Mek , True );
{$ELSE}
			IndicateTile( Camp^.GB , Mek );
{$ENDIF}
			ClrZone( ZONE_Menu );

			{ Input the action. }
			KP := RPGKey;

			if KP = KeyMap[ KMC_NormSpeed ].KCode then begin
				RLWalker( Camp^.GB , Mek , Reverse_RL_D[ NAttValue( Mek^.NA , NAG_Location , NAS_D ) ] );
				GotMove := True;
			end else if KP = KeyMap[ KMC_FullSpeed ].KCode then begin
				PrepAction( Camp^.GB , Mek , NAV_FullSpeed );
			end else if KP = KeyMap[ KMC_Reverse ].KCode then begin
				PrepAction( Camp^.GB , Mek , NAV_Reverse );
			end else if KP = KeyMap[ KMC_TurnLeft ].KCode then begin
				PrepAction( Camp^.GB , Mek , NAV_TurnLeft );
			end else if KP = KeyMap[ KMC_TurnRight ].KCode then begin
				PrepAction( Camp^.GB , Mek , NAV_TurnRight );
			end else if KP = KeyMap[ KMC_Stop ].KCode then begin
				PrepAction( Camp^.GB , Mek , NAV_Stop );
			end else if KP = KeyMap[ KMC_SouthWest ].KCode then begin
				RLWalker( Camp^.GB , Mek , 1 );
				GotMove := True;
			end else if KP = KeyMap[ KMC_South ].KCode then begin
				RLWalker( Camp^.GB , Mek , 2 );
				GotMove := True;
			end else if KP = KeyMap[ KMC_SouthEast ].KCode then begin
				RLWalker( Camp^.GB , Mek , 3 );
				GotMove := True;
			end else if KP = KeyMap[ KMC_West ].KCode then begin
				RLWalker( Camp^.GB , Mek , 4 );
				GotMove := True;
			end else if KP = KeyMap[ KMC_East ].KCode then begin
				RLWalker( Camp^.GB , Mek , 6 );
				GotMove := True;
			end else if KP = KeyMap[ KMC_NorthWest ].KCode then begin
				RLWalker( Camp^.GB , Mek , 7 );
				GotMove := True;
			end else if KP = KeyMap[ KMC_North ].KCode then begin
				RLWalker( Camp^.GB , Mek , 8 );
				GotMove := True;
			end else if KP = KeyMap[ KMC_NorthEast ].KCode then begin
				RLWalker( Camp^.GB , Mek , 9 );
				GotMove := True;


			end else if KP = KeyMap[ KMC_ShiftGears ].KCode then begin
				ShiftGears( Mek );
			end else if KP = KeyMap[ KMC_ExamineMap ].KCode then begin
				LookAround( Camp^.GB , Mek );
			end else if KP = KeyMap[ KMC_AttackMenu ].KCode then begin
				DoPlayerAttack( Mek , Camp^.GB );
			end else if KP = KeyMap[ KMC_Attack ].KCode then begin
				RLQuickAttack( Camp^.GB , Mek );
			end else if KP = KeyMap[ KMC_QuitGame ].KCode then begin
				Camp^.GB^.QuitTheGame := True;

			end else if KP = KeyMap[ KMC_Talk ].KCode then begin
				PCTalk( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_Telephone ].KCode then begin
				PCTelephone( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_Help ].KCode then begin
				PCRLHelp( Camp^.GB );

			end else if KP = KeyMap[ KMC_Get ].KCode then begin
				PCGetItem( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_Recenter ].KCode then begin
				FocusOnMek( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_Inventory ].KCode then begin
				PCBackpackMenu( Camp^.GB , Mek , True );
			end else if KP = KeyMap[ KMC_Equipment ].KCode then begin
				PCBackpackMenu( Camp^.GB , Mek , False );

			end else if ( KP = KeyMap[ KMC_Enter ].KCode ) or ( KP = KeyMap[ KMC_Enter2 ].KCode ) then begin
				PCEnter( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_PartBrowser ].KCode then begin
{$IFDEF SDLMODE}
				MechaPartBrowser( Mek , @PCActionRedraw );
{$ELSE}
				MechaPartBrowser( Mek );
{$ENDIF}

			end else if KP = KeyMap[ KMC_LearnSkills ].KCode then begin
				DoTraining( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_SelectMecha ].KCode then begin
				DoSelectPCMek( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_SaveGame ].KCode then begin
				PCSaveCampaign( Camp , Mek , True );

			end else if KP = KeyMap[ KMC_CharInfo ].KCode then begin
				PCViewChar( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_FirstAid ].KCode then begin
				DoFirstAid( Camp^.GB , Mek );
			end else if KP = KeyMap[ KMC_ApplySkill ].KCode then begin
				PCActivateSkill( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_Eject ].KCode then begin
				DoEjection( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_Rest ].KCode then begin
				DoRest( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_History ].KCode then begin
				DisplayConsoleHistory( Camp^.GB );

			end else if KP = KeyMap[ KMC_FieldHQ ].KCode then begin
				PCFieldHQ( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_ViewMemo ].KCode then begin
				MemoBrowser( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_UseProp ].KCode then begin
				PCUseProp( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_Search ].KCode then begin
				PCSearch( Camp^.GB , Mek );

			end else if KP = KeyMap[ KMC_RunToggle ].KCode then begin
				PCRunToggle;

{$IFDEF SDLMODE}
			end else if ( KP = RPK_MouseButton ) and Mouse_Active then begin
				PCLeftButton( Camp^.GB , Mek );
			end else if ( KP = RPK_RightButton ) and Mouse_Active then begin
				GameOptionMenu( Mek , Camp^.GB );
{$ENDIF}

			end else if KP = 'P' then begin
				ForcePlot( Camp^.GB , Camp^.GB^.Scene );
			end else if ( KP = '!' ) and ( Camp^.GB^.Scene <> Nil ) then begin
{$IFDEF SDLMODE}
				MechaPartBrowser( FindRoot( Camp^.GB^.Scene ) , @PCActionRedraw );
{$ELSE}
				MechaPartBrowser( FindRoot( Camp^.GB^.Scene ) );
{$ENDIF}
			end else if KP = '@' then begin
				ShowRep( Mek );

			end else if KP = '#' then begin
				DirectScript( Camp^.GB );

			end; {if}

		end; {While}
	end; {IF}

	{ De-Indicate the mek. }
	RedrawTile( Camp^.GB , mek );
end;

Procedure GetPlayerInput( Mek: GearPtr; Camp: CampaignPtr );
	{ Branch to either the MENU based input routine or the RL one. }
var
	IT: Integer;
	TL: LongInt;
begin
{$IFDEF SDLMODE}
	PCACTIONRD_PC := Mek;
	PCACTIONRD_GB := Camp^.GB;
{$ENDIF}

	{ Check the player for jumping. }
	TL := NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit );
	if ( TL > 0 ) then begin
		DialogMsg( BStr( Abs( TL - Camp^.GB^.ComTime ) ) + ' seconds jump time left.' );
	end;

	{ Check the player for valid movemode. This is needed }
	{ for jumping mecha. I think that the way jumping is }
	{ currently handled in the game is a bit messy- lots of }
	{ bits here and there trying to make it look right. }
	{ Someday I'll try to clean up action.pp and make everything }
	{ more elegant, but for right now as long as everything works }
	{ and is vaguely understandable I can't complain. }
	if not MoveLegal( Mek , NAV_NormSpeed , Camp^.GB^.ComTime ) then begin
		GearUp( Mek );
	end;

	{ Find out what kind of interface to use. }
	IT := InterfaceType( Camp^.GB , Mek );

	if IT = MenuBasedInput then begin
		MenuPlayerInput( Mek , Camp^.GB );
	end else begin
		RLPlayerInput( Mek , Camp );
	end;

	{ At the end of any action, do a search for metaterrain. }
	if GearActive( Mek ) then CheckHiddenMetaterrain( Camp^.GB , Mek );
end;

end.
