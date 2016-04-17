unit arenaplay;
	{ This unit holds the combat loop for Arena. }

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

Const
	{ Sets trigger NUMBEROFUNITS }
	TRIGGER_StartGame = 'Start';
	TRIGGER_EndGame = 'END';

	SATT_Artifact = 'ARTIFACT';

Function CombatMain( Camp: CampaignPtr ): Integer;
Function ScenePlayer( Camp: CampaignPtr ; Scene: GearPtr; var PCForces: GearPtr ): Integer;

implementation

{$IFDEF SDLMODE}
uses i18nmsg,ability,aibrain,arenacfe,arenascript,backpack,damage,gearutil,
     ghchars,ghprop,ghweapon,grabgear,menugear,movement,pcaction,
     playwright,randmaps,rpgdice,skilluse,texutil,ui4gh,wmonster,
     sdlmap,sdlgfx;
{$ELSE}
uses i18nmsg,ability,aibrain,arenacfe,arenascript,backpack,damage,gearutil,
     ghchars,ghprop,ghweapon,grabgear,menugear,movement,pcaction,
     playwright,randmaps,rpgdice,skilluse,texutil,ui4gh,wmonster,
     conmap,context;
{$ENDIF}
const
	DEBUG_ON: Boolean = False;

Function Confused( Mek: GearPtr ): Boolean;
	{ Return true if either the pilot or the mecha is either }
	{ HAYWIRE or STONED. }
var
	Pilot: GearPtr;
begin
	if Mek^.G = GG_Mecha then begin
		Pilot := LocatePilot( Mek );
	end else begin
		Pilot := Nil;
	end;

	Confused := HasStatus( Mek , NAS_Haywire ) or HasStatus( Mek , NAS_Stoned ) or HasStatus( Pilot , NAS_Haywire ) or HasStatus( Pilot , NAS_Stoned );
end;

Procedure GetMekInput( Mek: GearPtr; Camp: CampaignPtr; ControlByPlayer: Boolean );
	{ Decide what the mek in question is gonna do next. }
begin
	{ This procedure has to branch depending upon whether we have a }
	{ player controlled mek or a computer controlled mek. }

	{ Branch the first - If this mecha has a HAYWIRE status effect }
	{ it may move randomly 50% of the time. }
	if Confused( Mek ) and ( Random( 2 ) = 1 ) then begin
		ConfusedInput( Mek , Camp^.GB );

	end else if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = 1 ) or ControlByPlayer then begin
		{ It's a player mek. }
		{ In SDL mode, update the display with each player action. }
{$IFDEF SDLMODE}
		IndicateTile( Camp^.GB , Mek , True );
{$ENDIF}

		GetPlayerInput( Mek , Camp );
	end else begin
		{ it's a computer mek. }
		GetAIInput( Mek , Camp^.GB );
	end;
end;

Function KeepPlayingSC( GB: GameBoardPtr ): Boolean;
	{ Check out this scenario and decide whether or not to keep }
	{ playing. Right now, combat will continue as long as there }
	{ is at least one active mek on each team. }
var
	PTeam,ETeam: Integer;		{ Player Team , Enemy Team }
begin
	{ If this scenario is being controlled by a SCENE gear, }
	{ control of when to quit will be handled by the event strings. }
	{ Also, if we have received a QUIT order, stop playing. }

	if gb^.Scene <> Nil then KeepPlayingSC := Not gb^.QuitTheGame
	else if gb^.QuitTheGame then KeepPlayingSC := False
	else begin

		{ Determine the number of player mecha and enemy mecha. }
		PTeam := NumActiveMasters( GB , NAV_DefPlayerTeam );
		ETeam := NumActiveMasters( GB , NAV_DefEnemyTeam );

		KeepPlayingSC := ( PTeam > 0 ) and ( ETeam > 0 );
	end;
end;

Procedure CheckMeks( Camp: CampaignPtr );
	{ Check through all the meks in this scenario. If it's time }
	{ for one to move according to its ETA, call the movement }
	{ procedure. }
var
	M: GearPtr;
	ETA: LongInt;
begin
	M := Camp^.GB^.meks;

	while ( M <> Nil ) and KeepPlayingSC( Camp^.GB ) do begin
		if IsMasterGear( M ) then begin
			{ Check for actions in progress. }
			if NotDestroyed( M ) and OnTheMap( M ) then begin
				ETA := NAttValue( M^.NA , NAG_Action , NAS_MoveETA );
				if ETA <= Camp^.GB^.ComTime then begin
					ProcessMovement( Camp^.GB , M );
				end;
			end;

			{ Check for input. }
			if GearActive( M ) and OnTheMap( M ) then begin
				ETA := NAttValue( M^.NA , NAG_Action , NAS_CallTime );
				if ETA <= Camp^.GB^.ComTime then begin
					GetMekInput( M , Camp , False );
				end;

			end;

		end; { if IsMasterGear then... }

		M := M^.Next;
	end;
end;

Function DecideCombatOutcome( GB: GameBoardPtr ): Integer;
	{ Print a snazzy message detailing the outcome of the combat. }
var
	PTeam,ETeam,T: Integer;
begin
	{ If this scenario is being controlled by a SCENE gear, }
	{ its exit value will have been determined by the SCENE itself. }
	if GB^.Scene <> Nil then T := GB^.ReturnCode
	else begin

		{ Determine the number of player mecha and enemy mecha. }
		PTeam := NumActiveMasters( GB , NAV_DefPlayerTeam );
		ETeam := NumActiveMasters( GB , NAV_DefEnemyTeam );

		{ Display message regarding the outcome of the battle. }
		if ( PTeam > 0 ) and ( ETeam = 0 ) then begin
			DialogMsg( I18N_MsgString('DecideCombatOutcome','Player won') );
			T := 1;
		end else if ( ETeam > 0 ) and ( PTeam = 0 ) then begin
			DialogMsg( I18N_MsgString('DecideCombatOutcome','Computer won') );
			T := -1;
		end else begin
			DialogMsg( I18N_MsgString('DecideCombatOutcome','Draw') );
			T := 0;
		end;
	end;

	DecideCombatOutcome := T;
end;

Procedure UniversalVisionCheck( GB: GameBoardPtr );
	{ Do a vision check for every model on the board. }
var
	M: GearPtr;
begin
	{ First, we need to make sure the shadow map is up to date. }
	UpdateShadowMap( GB );

	{ Next, go through each gear on the gameboard, doing vision checks as needed. }
	M := GB^.Meks;
	while M <> Nil do begin
		if IsMasterGear( M ) and OnTheMap( M ) then VisionCheck( GB , M );
		M := M^.Next;
	end;
end;

Function CombatMain( Camp: CampaignPtr ): Integer;
	{ This is the main meat-and-potatoes combat procedure. }
	{ Actually, it's pretty simple. All the difficult work is }
	{ done by the procedures it calls. }
	{ This function returns 1 if the player won, -1 if the computer }
	{ won, and 0 if the game ended in a draw. }
var
	T: String;
begin
	{ To start with, do a vision check for everyone, }
	{ then set up the display. }
	UniversalVisionCheck( Camp^.GB );
    {$IFNDEF SDLMODE}
	GFCombatDisplay( Camp^.GB );
    {$ENDIF}

	{ Get rid of the old AI pathfinding maps. }
	ClearHotMaps;

	{ Set the STARTGAME trigger, and update all props. }
	SetTrigger( Camp^.GB , TRIGGER_StartGame );
	T := 'UPDATE';
	CheckTriggerAlongPath( T , Camp^.GB , Camp^.GB^.Meks , True );

	{ Add some random monsters, if appropriate. }
	RestockRandomMonsters( Camp^.GB );

	{Start main combat loop here.}
	{Keep going until there's only one side left.}
	while KeepPlayingSC( Camp^.GB ) do begin
		AdvanceGameClock( Camp^.GB, True );

		{ Once every 10 minutes, roll for random monsters. }
		if ( Camp^.GB^.ComTime mod AP_10minutes ) = 233 then RestockRandomMonsters( Camp^.GB );

		{ Once every hour, make sure the PC is still alive. }
		if ( Camp^.GB^.ComTime mod AP_Hour ) = 0 then SetTrigger( Camp^.GB , 'NU1' );

		{ Update clouds every 30 seconds. }
		if ( Camp^.GB^.ComTime mod 30 ) = 0 then BrownianMotion( Camp^.GB );

		HandleTriggers( Camp^.GB );

		CheckMeks( Camp );

        {$IFNDEF SDLMODE}
		UpdateCombatDisplay( Camp^.GB );
        {$ENDIF}
	{end main combat loop.}
	end;

	{ Handle the last pending triggers. }
	SetTrigger( Camp^.GB , TRIGGER_EndGame );
	HandleTriggers( Camp^.GB );

	{ Return the outcome code. }
	CombatMain := DecideCombatOutcome( Camp^.GB );
end;

Function CanTakeTurn( M: GearPtr ): Boolean;
	{ Return TRUE if M can act in this turn. }
begin
	CanTakeTurn := GearOperational( M ) and OnTheMap( M );
end;

Procedure TacticsTurn( Camp: CampaignPtr; M: GearPtr; IsPlayerMek: Boolean );
	{ It's time for this mecha to act. }
	{ Give it 60 seconds in which to do everything. }
var
	CallTime,ETA: LongInt;
	BeginTime,EndTime: LongInt;
	DidBeginTurn: Boolean;
begin
	{ Get rid of the old AI pathfinding maps. }
	ClearHotMaps;

	DidBeginTurn := False;

	BeginTime := NAttValue( Camp^.GB^.Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart );
	EndTime := BeginTime + TacticsRoundLength - 1;
	Repeat
		{ Check for Mecha's action first. }
		ETA := NAttValue( M^.NA , NAG_Action , NAS_MoveETA );
		if ETA <= Camp^.GB^.ComTime then begin
			ProcessMovement( Camp^.GB , M );
		end;

		{ Check for input. }
		CallTime := NAttValue( M^.NA , NAG_Action , NAS_CallTime );
		if ( CallTime <= Camp^.GB^.ComTime ) and CanTakeTurn( M ) then begin
			if GearOperational( M ) then begin
				if IsPlayerMek and not DidBeginTurn then begin
					BeginTurn( Camp^.GB , M );
					DidBeginTurn := True;
				end;

				GetMekInput( M , Camp , IsPlayerMek );
			end else begin
				SetNAtt( M^.NA , NAG_Action , NAS_CallTime , Camp^.GB^.ComTime + 60);
			end;
		end else begin
			inc( Camp^.GB^.ComTime );
		end;

		{ Handle triggers now. }
		HandleTriggers( Camp^.GB );

	until ( Camp^.GB^.ComTime >= EndTime ) or ( not OnTheMap( M ) ) or Destroyed( M ) or ( not KeepPlayingSC( Camp^.GB ) );

	{ At the end, reset the comtime. }
	Camp^.GB^.ComTime := BeginTime;
end;


Function TacticsMain( Camp: CampaignPtr ): Integer;
	{ This is the main meat-and-potatoes combat procedure. }
	{ It functions as the above procedure, but a bit more strangely. }
	{ You see, in order to have a tactics mode without changing any other part }
	{ of the program, this procedure must fool all the PC-input and AI routines }
	{ into believing that the clock is ticking, whereas in fact it's just ticking }
	{ for that one particular model for a stretch of 60 seconds. }
var
	T: String;
	M: GearPtr;
	Team: Integer;
	FoundPCToAct: Boolean;
begin
	{ To start with, do a vision check for everyone, }
	{ then set up the display. }
	UniversalVisionCheck( Camp^.GB );
    {$IFNDEF SDLMODE}
	GFCombatDisplay( Camp^.GB );
    {$ENDIF}

	{ Get rid of the old AI pathfinding maps. }
	ClearHotMaps;

	{ Set the STARTGAME trigger, and update all props. }
	SetTrigger( Camp^.GB , TRIGGER_StartGame );
	T := 'UPDATE';
	CheckTriggerAlongPath( T , Camp^.GB , Camp^.GB^.Meks , True );

	{ Add some random monsters, if appropriate. }
	RestockRandomMonsters( Camp^.GB );

	{Start main combat loop here.}
	{Keep going until there's only one side left.}
	while KeepPlayingSC( Camp^.GB ) do begin
		{ Start by handling triggers; also end by handling triggers. It may }
		{ seem like overkill but it's the only way to catch them all. }
		HandleTriggers( Camp^.GB );

		{ Each round lasts one minute. }
		{ Handle the player mecha first. }
		repeat
			FoundPCToAct := False;
			M := Camp^.GB^.Meks;
			while ( M <> Nil ) and KeepPlayingSC( Camp^.GB ) do begin
				team := NAttValue( M^.NA , NAG_Location , NAS_Team );
				if ( Team = NAV_DefPlayerTeam ) or ( Team = NAV_LancemateTeam ) then begin
					if NotDestroyed( M ) and OnTheMap( M ) then begin
						if CanTakeTurn( M ) and ( NAttValue( M^.NA , NAG_Action , NAS_CallTime ) < ( Camp^.GB^.ComTime + TacticsRoundLength - 1 ) ) then FoundPCToAct := True;
						TacticsTurn( Camp , M , True );
					end;
				end;
				M := M^.Next;
			end;
		until ( not FoundPCToAct );

		{ Handle the enemy mecha next. }
		M := Camp^.GB^.Meks;
		while M <> Nil do begin
			team := NAttValue( M^.NA , NAG_Location , NAS_Team );
			if ( Team <> NAV_DefPlayerTeam ) and ( Team <> NAV_LancemateTeam ) then begin
				if NotDestroyed( M ) and OnTheMap( M ) then begin
					TacticsTurn( Camp , M , False );
				end;
			end;
			M := M^.Next;
		end;

		{ Advance the clock by 60 seconds. }
		QuickTime( Camp^.GB , TacticsRoundLength );
		AddNAtt( Camp^.GB^.Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart , TacticsRoundLength );
		HandleTriggers( Camp^.GB );

		{ Update the display. }
        {$IFNDEF SDLMODE}
		UpdateCombatDisplay( Camp^.GB );
        {$ENDIF}

		{ Update clouds every round. }
		for team := 1 to ( TacticsRoundLength div 30 ) do BrownianMotion( Camp^.GB );

		{ Once every 10 rounds, roll for random monsters. }
		if ( ( Camp^.GB^.ComTime div TacticsRoundLength ) mod 10 ) = 0 then RestockRandomMonsters( Camp^.GB );
	end;

	{ Handle the last pending triggers. }
	SetTrigger( Camp^.GB , TRIGGER_EndGame );
	HandleTriggers( Camp^.GB );

	{ Return the outcome code. }
	TacticsMain := DecideCombatOutcome( Camp^.GB );
end;


Procedure PreparePCForces( Scale: Integer; var PCForces: GearPtr );
	{ ******************************* }
	{ *** PC Forces PreProcessing *** }
	{ ******************************* }
	{ Before sticking the PCs on the map, must first check whether or not }
	{ to stick them in mecha. }
var
	PCT,PC2,PCMek: GearPtr;
begin
	{ Pass One - Set PC Team for all units. }
	PCT := PCForces;
	while PCT <> Nil do begin
		{ The exact team is going to depend on whether this is the primary PC or }
		{ just a lancemate. }
		if NAttValue( PCT^.NA , NAG_CharDescription , NAS_CharType ) = NAV_CTLancemate then begin
			SetNAtt( PCT^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
		end else begin
			SetNAtt( PCT^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
		end;
		PCT := PCT^.Next;
	end;

	{ Pass Two - Insert pilots into mecha as appropriate. }
	PCT := PCForces;
	while PCT <> Nil do begin
		PC2 := PCT^.Next;

		{ If this gear is a character, and is at a smaller scale than }
		{ the map, check to see if he/she has a mecha to get into. }
		if ( PCT^.G = GG_Character ) and ( PCT^.Scale < Scale ) then begin
			PCMek := FindPilotsMecha( PCForces , PCT );
			if ( PCMek <> Nil ) and ( PCMek^.Scale <= Scale ) and HasAtLeastOneValidMovemode( PCMek ) then begin
				{ A mek has been found. Insert the pilot into it. }
				DelinkGear( PCForces , PCT );

				{ If the pilot is a lancemate, so is the mecha. }
				if NAttValue( PCT^.NA , NAG_CharDescription , NAS_CharType ) = NAV_CTLancemate then begin
					SetNAtt( PCMek^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
				end;
				if not BoardMecha( PCMek , PCT ) then begin
					{ The pilot couldn't board the mecha for whatever reason. }
					{ Stick the pilot back in the list, at the beginning. }
					PCT^.Next := PCForces;
					PCForces := PCT;
				end;
			end;
		end;

		PCT := PC2;
	end;
end;

Function NonRecoveryScene( GB: GameBoardPtr ): Boolean;
	{ Return TRUE if this scene isn't a good location for recovery. }
begin
	NonRecoveryScene := ( GB^.Scene = Nil ) or ( not AStringHasBString( SAttValue( GB^.Scene^.SA , 'TYPE' ) , 'TOWN' ) );
end;

Function ShouldDeployLancemate( GB: GameBoardPtr; LM , Scene: GearPtr ): Boolean;
	{ Return TRUE if LM should be placed on this map, or FALSE if LM should be }
	{ kept on the sidelines. }
begin
	if AStringHasBString( SAttValue( Scene^.SA , 'TYPE' ) , 'WORLD' ) then begin
		ShouldDeployLancemate := False;
	end else if AStringHasBString( SAttValue( Scene^.SA , 'TYPE' ) , 'SOLO' ) then begin
		ShouldDeployLancemate := False;
	end else if LM^.Scale < ( Scene^.V - 1 ) then begin
		ShouldDeployLancemate := False;
	end else if ( LM^.G = GG_Character ) and ( NAttValue( LM^.NA , NAG_Damage , NAS_OutOfAction ) <> 0 ) and NonRecoveryScene( GB ) then begin
		ShouldDeployLancemate := False;
	end else begin
		ShouldDeployLancemate := True;
	end;
end;

Procedure DeployJJang( Camp: CampaignPtr; Scene,PCForces: GearPtr );
	{ Deploy the game forces as described in the Scene. }
var
	it,it2: GearPtr;
begin
	if DEBUG_ON then DialogMsg( 'DeployJJang' );

	{ ERROR CHECK - If this campaign already has a GameBoard, no need to }
	{ deploy anything. It was presumably just restored from disk and should }
	{ be fully stocked. }
	if Camp^.GB <> Nil then Exit;

	{ Record the tactics turn start time. }
	{ This gets reset along with the scene, but should not be reset for saved games. }
	SetNAtt( Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart , Camp^.ComTime );

	{ Generate the map for this scene. It will either be created }
	{ randomly or drawn from the frozen maps. }
	Camp^.gb := UnfreezeLocation( GearName( Scene ) , Camp^.Maps );
	if Camp^.GB = Nil then Camp^.gb := RandomMap( SCene );

	Camp^.GB^.ComTime := Camp^.ComTime;
	Camp^.gb^.Scene := Scene;
	Camp^.gb^.Scale := Scene^.V;

	{ Get the PC Forces ready for deployment. }
	PreparePCForces( Camp^.gb^.Scale , PCForces );

	{ Stick the PC forces on the map. }
	{ Clear the PC_TEAM saved position. }
	PC_Team_X := 0;
	while PCForces <> Nil do begin
		it2 := PCForces^.Next;
		it := PCForces;
		DelinkGear( PCForces , it );
		if NAttValue( it^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
			DeployMek( Camp^.gb , it , GearActive( it ) AND ( it^.Scale <= Camp^.GB^.Scale ) );
		end else begin
			if GearActive( it ) AND ( it^.Scale <= Camp^.GB^.Scale ) AND ShouldDeployLancemate( Camp^.GB , it , Scene ) then begin
				DeployMek( Camp^.gb , it , True );
				SetNAtt( it^.NA , NAG_Damage , NAS_OutOfAction , 0 );
			end else begin
				DeployMek( Camp^.gb , it , False );
			end;
		end;
		PCForces := it2;
	end;

	{ Stick the local NPCs on the map. }
	it := Scene^.InvCom;
	while it <> Nil do begin
		it2 := it^.Next;

		{ Check to see if this is a character. }
		if ( it^.G >= 0 ) then begin
			DelinkGear( Scene^.InvCom , it );
			if NAttValue( it^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				DeployMek( Camp^.gb , it , ( it^.G = GG_Character ) );
			end else begin
				DeployMek( Camp^.gb , it , ( ( it^.Scale <= Scene^.V ) or ( it^.G = GG_Character ) ) );
			end;
		end;

		it := it2;
	end;
end;

Function IsGlobalGear( NPC: GearPtr ): Boolean;
	{ This function will decide whether or not the NPC is global. }
	{ Global NPCs are stored as subcomponents of the ADVENTURE }
	{ gear. }
begin
	IsGlobalGear := NAttValue( NPC^.NA , NAG_ParaLocation , NAS_OriginalHome ) <> 0;
end;

Procedure PutAwayGlobal( GB: GameBoardPtr; var Item: GearPtr );
	{ ITEM is a global gear. It belongs somewhere other than it is. }
	{ IMPORTANT: GB, GB^.SCene, and Item are all defined. }
var
	SID: Integer;
	Scene: GearPtr;
begin
	{ Find this gear's original home scene. }
	SID := NAttValue( Item^.NA , NAG_ParaLocation , NAS_OriginalHome );

	{ Erase the original home data, since we're sending it home now. }
	{ If the gear gets moved again its original home data should be }
	{ reset. }
	SetNAtt( Item^.NA , NAG_ParaLocation , NAS_OriginalHome , 0 );

	{ Put it away there. }
	if SID > 0 then begin
		Scene := FindActualScene( GB , SID );
	end else begin
		Scene := Nil;
	end;

	if Scene <> Nil then begin
		InsertInvCom( Scene , Item );

		{ If inserting a character, better choose a team. }
		if IsMasterGear( Grabbed_Gear ) then begin
			ChooseTeam( Item , Scene );
		end;

	end else if GB^.SCene <> Nil then begin
		InsertInvCom( FindRoot( GB^.Scene ) , Item );

	end else begin
		DisposeGear( Item );

	end;
end;

Function ShouldDeleteDestroyed( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ Return TRUE if MEK should be deleted, or FALSE otherwise. }
	{ MEK shouldn't be deleted if it's an artefact. }
begin
	ShouldDeleteDestroyed := not AStringHasBString( SAttValue( Mek^.SA , 'TYPE' ) , SAtt_Artifact );
end;

Procedure PutAwayGear( GB: GameBoardPtr; var Mek,PCForces: GearPtr );
	{ The game is over. Put MEK wherever it belongs. }
	function ShouldBeMoved: Boolean;
		{ MEK is a member of the player team. }
		{ Return TRUE if Mek should be moved, or FALSE otherwise. }
		{ It should be moved if it's a character, if it's the }
		{ PC's chosen mecha, or if the current scene is dynamic }
		{ or the world map. Got all that? }
	begin
		if ( GB^.Scene = Nil ) or ( IsInvCom( GB^.Scene ) ) then begin
			ShouldBeMoved := True;
		end else if Mek^.G = GG_Character then begin
			ShouldBeMoved := True;
		end else if SAttValue( Mek^.SA , 'PILOT' ) <> '' then begin
			ShouldBeMoved := True;
		end else begin
			ShouldBeMoved := False;
		end;
	end;
begin
	if Mek = Nil then begin
		Exit;
	end else if ( Mek^.G = GG_MetaTerrain ) and ( Mek^.S = GS_MetaFire ) then begin
		DisposeGear( Mek );
	end else if Destroyed( Mek ) and ShouldDeleteDestroyed( GB , Mek ) then begin
		DisposeGear( Mek );
	end else if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ShouldBeMoved then begin
		{ Strip the location & visibility info. }
		StripNAtt( Mek , NAG_Location );
		StripNAtt( Mek , NAG_Visibility );
		StripNAtt( Mek , NAG_Action );
		StripNAtt( Mek , NAG_EpisodeData );
		{ Store the mecha in the PCForces list. }
		Mek^.Next := PCForces;
		PCForces := Mek;

	end else if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ShouldBeMoved then begin
		{ Strip the location & visibility info. }
		StripNAtt( Mek , NAG_Location );
		StripNAtt( Mek , NAG_Visibility );
		StripNAtt( Mek , NAG_Action );
		StripNAtt( Mek , NAG_EpisodeData );

		{ Make sure to record that this is a lancemate, if appropriate. }
		if Mek^.G = GG_Character then SetNAtt( Mek^.NA , NAG_CharDescription , NAS_CharType , NAV_CTLancemate );

		{ Store the mecha in the PCForces list. }
		Mek^.Next := PCForces;
		PCForces := Mek;

	end else begin
		{ Strip the stuff we don't want to save. }
		StripNAtt( Mek , NAG_Visibility );
		StripNAtt( Mek , NAG_Action );
		StripNAtt( Mek , NAG_EpisodeData );
		StripNAtt( Mek , NAG_Condition );

		if GB^.Scene <> Nil then begin
			if IsGlobalGear( Mek ) then begin
				StripNAtt( Mek , NAG_Location );
				StripNAtt( Mek , NAG_Damage );
				PutAwayGlobal( GB , Mek );
			end else begin
				InsertInvCom( GB^.Scene , Mek );
			end;
		end else begin
			DisposeGear( Mek );
		end;
	end;

end;

Procedure PreparePCForDelink( GB: GameBoardPtr );
	{ Check the PC forces; restore any dead characters based on the repair skills }
	{ posessed by the party; maybe dole out perminant injuries. }
var
	PC,TruePC: GearPtr;
	team,T,SkRk: LongInt;
begin
	{ If this scene is of a NORESCUE type, exit immediately. }
	if ( GB^.Scene <> Nil ) and AStringHasBString( SAttValue( GB^.Scene^.SA , 'TYPE' ) , 'NORESCUE' ) then Exit;

	{ Step One: Delink the pilots from their mecha. }
	PC := GB^.Meks;
	while PC <> Nil do begin
		team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
		if ( PC^.G = GG_Mecha ) and ( ( team = NAV_DefPlayerTeam ) or ( team = NAV_LancemateTeam ) ) then begin
			repeat
				TruePC := ExtractPilot( PC );
				if TruePC <> Nil then begin
					AppendGear( GB^.Meks , TruePC );
				end;
			until TruePC = Nil;
		end;
		PC := PC^.Next;
	end;

	{ Step Two: Apply emergency healing to all. }
	PC := GB^.Meks;

	while PC <> Nil do begin
		team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
		if ( team = NAV_DefPlayerTeam ) or ( team = NAV_LancemateTeam ) then begin
			if Destroyed( PC ) then begin
				{ Check every repair skill for applicability. }
				for t := 1 to NumSkill do begin
					if ( SkillMan[ T ].Usage = USAGE_Repair ) then begin
						if TotalRepairableDamage( PC , T ) > 0 then begin
							{ Determine how many repair points it's possible }
							{ to apply. }
							if ( PC^.G = GG_Mecha ) then begin
								if TeamHasSkill( GB , NAV_DefPlayerTeam , T ) then begin
									SkRk := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , T ) ) * 5;
								end else SkRk := 0;
							end else if Team = NAV_DefPlayerTeam then begin
								SkRk := TotalRepairableDamage( PC , T );
							end else if TeamHasSkill( GB , NAV_DefPlayerTeam , T ) then begin
								SkRk := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , T ) ) - 10;
								if SkRk < 0 then SkRk := 0;
							end else SkRk := 0;
							ApplyRepairPoints( PC , T , SkRk );
							if PC^.G = GG_Character then SetNAtt( PC^.NA , NAG_Damage , NAS_OutOfAction , 1 );
						end;
					end;
				end;
				if ( PC^.G = GG_Character ) and ( Team = NAV_DefPlayerTeam ) then begin
					AddNAtt( PC^.NA , NAG_Damage , NAS_Resurrections , 1 );
					if NAttValue( PC^.NA , NAG_Damage , NAS_Resurrections ) > (( NAttValue( PC^.NA , NAG_CharDescription , NAS_Heroic ) + RollStep( TeamSkill( GB , NAV_DefPlayerTeam , 16 )) div 20 ) + 1 ) then ApplyPerminantInjury( PC );
					AddReputation( PC , 6 , -10 );
					AddMoraleDmg( PC , 100 );
				end;
				if GearActive( PC ) then begin
					StripNAtt( PC , NAG_StatusEffect );
					if PC^.G = GG_Mecha then begin
						DialogMsg( ReplaceHash( MsgString( 'DJ_MECHARECOVERED' ) , GearName( PC ) ) );
					end else if Team = NAV_DefPlayerTeam then begin
						DialogMsg( ReplaceHash( MsgString( 'DJ_PCRESCUED' ) , PilotName( PC ) ) );
					end else begin
						DialogMsg( ReplaceHash( MsgString( 'DJ_OUTOFACTION' ) , PilotName( PC ) ) );
					end;
				end;
			end;
		end;
		PC := PC^.Next;
	end;

	{ Step Three: Remove PILOT tags from mecha whose pilots are }
	{ no longer with us. }
	PC := GB^.Meks;
	while PC <> Nil do begin
		team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
		if ( team = NAV_DefPlayerTeam ) or ( team = NAV_LancemateTeam ) then begin
			if ( PC^.G = GG_Mecha ) and ( SAttValue( PC^.SA , 'PILOT' ) <> '' ) then begin
				TruePC := SeekGearByName( GB^.Meks , SAttValue( PC^.SA , 'PILOT' ) );
				if ( TruePC = Nil ) or Destroyed( TruePC ) then begin
					SetSAtt( PC^.SA , 'PILOT <>' );
				end;
			end;
		end;
		PC := PC^.Next;
	end;
end;

Procedure DoPillaging( GB: GameBoardPtr );
	{ Pillage everything that isn't nailed down. }
const
	V_MAX = 2147483647;
	V_MIN = -2147483648;
var
	PC,M,M2: GearPtr;
	Cash: Int64;
	NID: LongInt;
begin
	Cash := 0;
	PC := GG_LocatePC( GB );

	{ If this is a NOPILLAGE scene, exit. }
	if ( GB^.Scene <> Nil ) and AStringHasBString( SAttValue( GB^.Scene^.SA, 'TYPE' ) , 'NOPILLAGE' ) then Exit;

	if ( PC <> Nil ) and OnTheMap( PC ) then begin
		{ First pass: Shakedown anything that's destroyed. }
		M := GB^.Meks;
		while M <> Nil do begin
			if OnTheMap( M ) and IsMasterGear( M ) and not GearOperational( M ) then begin
				cash := cash + SHakeDown( GB , M , 1 , 1 );
			end;
			M := M^.Next;
		end;
		if (V_MAX < Cash) then begin
			Cash := V_MAX;
		end else if (Cash < V_MIN) then begin
			Cash := V_MIN;
		end;

		{ Second pass: Pick up anything we can! }
		M := GB^.Meks;
		while M <> Nil do begin
			M2 := M^.Next;

			if OnTheMap( M ) and NotDestroyed( M ) and IsLegalSlot( PC , M ) and ( M^.G > 0 ) and not IsMasterGear( M ) then begin
				DelinkGear( GB^.Meks , M );

				{ Clear the item's location values. }
				StripNAtt( M , NAG_Location );

				InsertInvCom( PC , M );
				NID := NAttValue( M^.NA , NAG_Narrative , NAS_NID );
				if NID <> 0 then SetTrigger( GB , TRIGGER_GetItem + BStr( NID ) );
			end;

			M := M2;
		end;

		{ Finally, hand the PC any money that was found. }
		PC := LocatePilot( PC );
		if ( PC <> Nil ) and ( Cash > 0 ) then AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );
	end;
end;

Function DelinkJJang( GB: GameBoardPtr ): GearPtr;
	{ Delink all the components of the scenario, filing them away }
	{ for fututure use. Return a pointer to the surviving PC forces. }
var
	PCForces,Mek,Pilot: GearPtr;
begin
	if DEBUG_ON then DialogMsg( 'DelinkJJang' );

	{ Step one - Delete obsoleted teams. }
	{ A team will be deleted if it has no members, if it isn't the }
	{ player team or the neutral team, and if it has no wandering }
	{ monsters allocated. }
	DeleteObsoleteTeams( GB );
	if DEBUG_ON then DialogMsg( 'Team update complete.' );

	{ Step one-and-a-half: If this is a dynamic scene, and is safe, and pillaging }
	{ is enabled, then pillage away! }
	if IsInvCom( GB^.Scene ) and IsSafeArea( GB ) and Pillage_On then begin
		DoPillaging( GB );
	end;

	{ Step two - Remove all models from game board. }
	{ Initialize the PC Forces to Nil. }
	PCForces := Nil;

	{ Prepare the PCForces for delinkage. }
	PreparePCForDelink( GB );

	{ Keep processing while there's gears to process. }
	while GB^.Meks <> Nil do begin
		{ Delink the first gear from the list. }
		Mek := GB^.Meks;
		Pilot := Nil;
		DelinkGear( GB^.Meks , Mek );

		{ Decide what to do with this gear. }
		{ - If a mecha or disembodied module, remove its pilots. }
		{ - if on player team, store in PCForces }
		{ - if not on player team, store in GB^.Scene }
		{ - if destroyed, delete it }
		if ( Mek^.G = GG_Mecha ) or ( Mek^.G = GG_Module ) then begin
			{ Delink the pilot, and add to the list. }
			repeat
				Pilot := ExtractPilot( Mek );
				if Pilot <> Nil then begin
					PutAwayGear( GB , Pilot , PCForces );
				end;
			until Pilot = Nil;
		end;

		{ Send MEK to its destination. }
		PutAwayGear( GB , Mek , PCForces );

	end;

	DelinkJJang := PCForces;
end;

Function ScenePlayer( Camp: CampaignPtr ; Scene: GearPtr; var PCForces: GearPtr ): Integer;
	{ Construct then play a scenario. }
	{ Note that this procedure ABSOLUTELY DEFINITELY requires that }
	{ the SCENE gear be defined. }
var
	N: Integer;
begin
	DeployJJang( Camp , Scene , PCForces );

	{ Once everything is deployed, save the campaign. }
	if DoAutoSave then PCSaveCampaign( Camp , GG_LocatePC( Camp^.GB ) , False );

    {$IFDEF SDLMODE}
    InitMapDisplay( Camp^.GB, GG_LocatePC( Camp^.GB ) );
    {$ENDIF}

	if UseTacticsMode and ( Camp^.gb^.Scale = 2 ) then begin
		N := TacticsMain( Camp );
	end else begin
		N := CombatMain( Camp );
	end;

	PCForces := DelinkJJang( Camp^.gb );

	{ Save the final ComTime in the Campaign. }
	Camp^.ComTime := Camp^.GB^.ComTime;

    {$IFDEF SDLMODE}
    FinalizeMapDisplay();
    {$ENDIF}


	{ If SCENE is a part of Camp\Source, the map needs to be saved. }
	{ Otherwise dispose of the map and the scene together. }
	if ( FindGearIndex( Camp^.Source , Camp^.GB^.Scene ) <> -1 ) then begin
		if ( SAttValue( Camp^.GB^.Scene^.SA , 'NAME' ) <> '' ) then begin
			FreezeLocation( GearName( Scene ) , Camp^.GB , Camp^.Maps );
		end;
		Camp^.gb^.Scene := Nil;
	end;
	DisposeMap( Camp^.gb );

	ScenePlayer := N;
end;


end.
