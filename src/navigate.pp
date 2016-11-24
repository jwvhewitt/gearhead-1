unit navigate;
	{ This unit is the flow controller for the RPG bits of the game. }
	{ It decides where the PC is, then when the PC exits a scene it }
	{ decides where to go next. }
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
uses gears,locale,sdlgfx;
{$ELSE}
uses gears,locale;
{$ENDIF}

Const
	Max_Number_Of_Plots = 40;
	Plots_Per_Generation = 5;

Procedure Navigator( Camp: CampaignPtr; Scene: GearPtr; var PCForces: GearPtr );
{$IFDEF SDLMODE}
Procedure RestoreCampaign( Redrawer: RedrawProcedureType );
{$ELSE}
Procedure RestoreCampaign;
{$ENDIF}

implementation

{$IFDEF SDLMODE}
uses arenaplay,arenascript,damage,interact,gearutil,
     ghchars,ghweapon,movement,randchar,ui4gh,sdlmap,sdlmenus;
{$ELSE}
uses arenaplay,arenascript,damage,interact,gearutil,
     ghchars,ghweapon,movement,randchar,ui4gh,congfx,conmap,conmenus,context;
{$ENDIF}

Function NoLivingPlayers( PList: GearPtr ): Boolean;
	{ Return TRUE if the provided list of gears contains no }
	{ living characters. Return FALSE if it contains at least }
	{ one. }
var
	it: Boolean;
begin
	{ Start by assuming TRUE, then set to FALSE if a character is found. }
	it := TRUE;

	{ Loop through all the gears in the list. }
	while PList <> Nil do begin
		if ( PList^.G = GG_Character ) and NotDestroyed( PList ) and ( NAttValue( PList^.NA , NAG_CharDescription , NAS_CharType ) = 0 ) then begin
			it := False;
		end;
		PList := PList^.Next;
	end;

	{ Return the result. }
	NoLivingPlayers := it;
end;

Procedure CampaignUpkeep( Camp: CampaignPtr );
	{ Do some gardening work on this campaign. This procedure keeps }
	{ everything in the CAMP structure shiny, fresh, and working. }
	{ - Load a new PLOT, if appropriate. }
	{ - Delete dynamic scenes. }
var
	Part,Part2: GearPtr;
begin
	{ Get rid of any dynamic scenes that have outlived their usefulness. }
	{ If a SCENE is found in the InvComs, it must be dynamic. }
	Part := Camp^.Source^.InvCom;
	while Part <> Nil do begin
		Part2 := Part^.Next;

		if Part^.G = GG_Scene then RemoveGear( Camp^.Source^.InvCom , Part );

		Part := Part2;
	end;
end;

Procedure Navigator( Camp: CampaignPtr; Scene: GearPtr; var PCForces: GearPtr );
	{ This is the role-playing flow controller. It decides what scene }
	{ of an adventure gear to load next. }
var
	N: Integer;
begin
	repeat
		if SCene <> Nil then N := ScenePlayer( Camp , Scene , PCForces );

		{ Move to the destination scene, if appropriate. }
		if N > 0 then begin
			{ Perform upkeep on the campaign- delete dynamic scenes, }
			{ load new plots, yadda yadda yadda. }
			CampaignUpkeep( Camp );

			Scene := SeekGear( Camp^.Source , GG_Scene , N );

		{ If no destination scene was implied, check to see if there's }
		{ a dynamic scene waiting to be processed. }
		end else if SCRIPT_DynamicEncounter <> Nil then begin
			Scene := SCRIPT_DynamicEncounter;

			{ Stick the scene into the campaign. Normally scenes }
			{ are filed under SubComs, but in this case we'll store }
			{ it as an InvCom so we'll remember to delete it later. }
			InsertInvCom( Camp^.Source , Scene );

			{ Set the DynamicEncounter var to Nil, since we've moved }
			{ the scene to the campaign and don't want the ArenaScript }
			{ procedures to try and modify or delete it any more. }
			SCRIPT_DynamicEncounter := Nil;

			{ Set N to >0, since we don't want the "until..." }
			{ condition to exit. }
			N := 1;
		end;

	until ( N < 1 ) or NoLivingPlayers( PCForces ) or ( Scene = Nil );

	{ If the game is over because the PC died, do a [MORE] prompt. }
	if NoLivingPlayers( PCForces ) then begin
		EndOfGameMoreKey;
	end;
end;

{$IFDEF SDLMODE}
Procedure RCRedraw;

begin

end;
{$ENDIF}

{$IFDEF SDLMODE}
Procedure RestoreCampaign( Redrawer: RedrawProcedureType );
{$ELSE}
Procedure RestoreCampaign;
{$ENDIF}
	{ Select a previously saved unit from the menu. If no unit is }
	{ found, jump to the CreateNewUnit procedure above. }
var
	RPM: RPGMenuPtr;
	rpgname: String;	{ Campaign Name }
	Camp: CampaignPtr;
	F: Text;		{ A File }
	PC,Part,P2: GearPtr;
	DoSave: Boolean;
begin
	{ Create a menu listing all the units in the SaveGame directory. }
{$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_TitleScreenMenu );
{$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
{$ENDIF}
	BuildFileMenu( RPM , Save_Campaign_Base + Default_Search_Pattern );

	PC := Nil;

	{ If any units are found, allow the player to load one. }
	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select campaign file to load.');
{$IFDEF SDLMODE}
		rpgname := SelectFile( RPM , Redrawer );
{$ELSE}
		rpgname := SelectFile( RPM );
{$ENDIF}
		if rpgname <> '' then begin
			Assign(F, Save_Game_Directory + rpgname );
			reset(F);
			Camp := ReadCampaign(F);
			Close(F);
			Navigator( Camp , Camp^.GB^.Scene , PC );
			DoSave := Camp^.Source^.S <> 0;
			DisposeCampaign( Camp );
		end else begin
			DoSave := False;
		end;

	end else begin
		{ The menu was empty... print the info message. }
		DialogMsg( MsgString( 'NEWRPGCAMP_NoCamps' ) );
		DoSave := False;
	end;

	if ( PC <> Nil ) and ( DoSave or Always_Save_Character ) then begin
		if not NoLivingPlayers( PC ) then begin
			Part := PC;
			while Part <> Nil do begin
				P2 := Part^.Next;
				{ Lancemates don't get saved to the character file. }
				if NAttValue( Part^.NA , NAG_CharDescription , NAS_CharType ) = NAV_CTLancemate then begin
					RemoveGear( PC , Part );
				end else begin
					{ Everything else does get saved. }
					StripNAtt( Part , NAG_Visibility );
					StripNAtt( Part , NAG_EpisodeData );
					StripNAtt( Part , NAG_WeaponModifier );
					StripNAtt( Part , NAG_Action );
					StripNAtt( Part , NAG_Location );
					StripNAtt( Part , NAG_Damage );
					StripNAtt( Part , NAG_ReactionScore );
					StripNAtt( Part , NAG_FactionScore );
					StripNAtt( Part , NAG_Condition );
					StripNAtt( Part , NAG_StatusEffect );
					StripNAtt( Part , NAG_Narrative );
					SetNAtt( Part^.NA , NAG_Personal , NAS_FactionID , 0 );
				end;
				Part := P2;
			end;
			SaveChar( PC );

		end;
		DisposeGear( PC );
	end;

	DisposeRPGMenu( RPM );
end;

end.
