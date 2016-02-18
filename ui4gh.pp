unit ui4gh;
	{ User Interface for GearHead. }
	{ This unit exists to keep me from copying changes back and forth between }
	{ the SDL mode units and the CRT mode units... }
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

type
	KeyMapDesc = Record
		CmdName,CmdDesc: String;
		KCode: Char;
	end;

const
	RPK_UpRight = '9';
	RPK_Up = '8';
	RPK_UpLeft = '7';
	RPK_Left = '4';
	RPK_Right = '6';
	RPK_DownRight = '3';
	RPK_Down = '2';
	RPK_DownLeft = '1';

{$IFDEF SDLMODE}
	RPK_MouseButton = #$90;
	RPK_TimeEvent = #$91;
	RPK_RightButton = #$92;
	FrameDelay: Integer = 50;
{$ELSE}
	FrameDelay: Integer = 100;
{$ENDIF}

	MenuBasedInput = 0;
	RLBasedInput = 1;
	ControlMethod: Byte = MenuBasedInput;
	CharacterMethod: Byte = RLBasedInput;
	WorldMapMethod: Byte = RLBasedInput;
	ControlTypeName: Array [0..1] of string = ('Menu','Roguelike');

	DoFullScreen: Boolean = False;
	Mouse_Active: Boolean = True;

	Always_Save_Character: Boolean = False;
	No_Combat_Taunts: Boolean = False;
	Pillage_On: Boolean = True;

	TacticsRoundLength: Integer = 60;

	PC_SHOULD_RUN: Boolean = False;

	BV_Off = 1;
	BV_Quarter = 2;
	BV_Half = 3;
	BV_Max = 4;
	DefMissileBV: Byte = BV_Quarter;
	DefBallisticBV: Byte = BV_Max;
	DefBeamgunBV: Byte = BV_Max;
	BVTypeName: Array [1..4] of string = ('Off','1/4','1/2','Max');

	DoAutoSave: Boolean = True;

	Use_Alpha_Blending: Boolean = True;
	Alpha_Level: Byte = 135;

	Names_Above_Heads: Boolean = False;

	Max_Plots_Per_Adventure: Byte = 50;
	Load_Plots_At_Start: Boolean = False;

	Display_Mini_Map: Boolean = FaLSE;

	UseTacticsMode: Boolean = False;

	UseAdvancedColoring: Boolean = False;

	{ *** SCREEN DIMENSIONS *** }
	ScreenRows: Byte = 25;
	ScreenColumns: Byte = 80;


	NumMappedKeys = 45;
	KeyMap: Array [1..NumMappedKeys] of KeyMapDesc = (
	(	CmdName: 'NormSpeed';
		CmdDesc: 'Travel foreword at normal speed.';
		KCode: '=';	),
	(	CmdName: 'FullSpeed';
		CmdDesc: 'Travel foreword at maximum speed';
		KCode: '+';	),
	(	CmdName: 'TurnLeft';
		CmdDesc: 'Turn to the left.';
		KCode: '[';	),
	(	CmdName: 'TurnRight';
		CmdDesc: 'Turn to the right.';
		KCode: ']';	),
	(	CmdName: 'Stop';
		CmdDesc: 'Stop moving, wait in place.';
		KCode: '5';	),

{$IFDEF SDLMODE}
{ In SDL Mode, the direction keys for movement need to be shifted }
{ in order to match the isometric display. }
	(	CmdName: 'Dir-SouthWest';
		CmdDesc: 'Move southwest.';
		KCode: RPK_Left;	),
	(	CmdName: 'Dir-South';
		CmdDesc: 'Move south.';
		KCode: RPK_DownLeft;	),
	(	CmdName: 'Dir-SouthEast';
		CmdDesc: 'Move southeast.';
		KCode: RPK_Down;	),
	(	CmdName: 'Dir-West';
		CmdDesc: 'Move west.';
		KCode: RPK_UpLeft;	),
	(	CmdName: 'Dir-East';
		CmdDesc: 'Move east.';
		KCode: RPK_DownRight;	),

	(	CmdName: 'Dir-NorthWest';
		CmdDesc: 'Move northwest.';
		KCode: RPK_Up;	),
	(	CmdName: 'Dir-North';
		CmdDesc: 'Move north.';
		KCode: RPK_UpRight;	),
	(	CmdName: 'Dir-NorthEast';
		CmdDesc: 'Move northeast.';
		KCode: RPK_Right;	),
{$ELSE}
	(	CmdName: 'Dir-SouthWest';
		CmdDesc: 'Move southwest.';
		KCode: RPK_DownLeft;	),
	(	CmdName: 'Dir-South';
		CmdDesc: 'Move south.';
		KCode: RPK_Down;	),
	(	CmdName: 'Dir-SouthEast';
		CmdDesc: 'Move southeast.';
		KCode: RPK_DownRight;	),
	(	CmdName: 'Dir-West';
		CmdDesc: 'Move west.';
		KCode: RPK_Left;	),
	(	CmdName: 'Dir-East';
		CmdDesc: 'Move east.';
		KCode: RPK_Right;	),

	(	CmdName: 'Dir-NorthWest';
		CmdDesc: 'Move northwest.';
		KCode: RPK_UpLeft;	),
	(	CmdName: 'Dir-North';
		CmdDesc: 'Move north.';
		KCode: RPK_Up;	),
	(	CmdName: 'Dir-NorthEast';
		CmdDesc: 'Move northeast.';
		KCode: RPK_UpRight;	),
{$ENDIF}

	(	CmdName: 'ShiftGears';
		CmdDesc: 'Change movement mode.';
		KCode: '.';	),
	(	CmdName: 'Look';
		CmdDesc: 'Look around the map.';
		KCode: 'l';	),

	(	CmdName: 'AttackMenu';
		CmdDesc: 'Access the attack menu.';
		KCode: 'A';	),
	(	CmdName: 'QuitGame';
		CmdDesc: 'Exit the game.';
		KCode: 'Q';	),
	(	CmdName: 'Talk';
		CmdDesc: 'Initiate conversation with a NPC.';
		KCode: 't';	),
	(	CmdName: 'Help';
		CmdDesc: 'View these helpful messages.';
		KCode: 'h';	),
	(	CmdName: 'SwitchWeapon';
		CmdDesc: 'Change the active weapon while selecting a target.';
		KCode: '.';	),

	(	CmdName: 'CalledShot';
		CmdDesc: 'Toggle the Called Shot option while selecting a target.';
		KCode: '/';	),
	(	CmdName: 'Recenter';
		CmdDesc: 'Recenter the display on the currently active character.';
		KCode: 'R';	),
	(	CmdName: 'Get';
		CmdDesc: 'Pick up an item lying on the ground.';
		KCode: ',';	),
	(	CmdName: 'Inventory';
		CmdDesc: 'Access all carried items.';
		KCode: 'i';	),
	(	CmdName: 'Equipment';
		CmdDesc: 'Access all equipped items.';
		KCode: 'e';	),

	{ Commands 26 - 30 }
	(	CmdName: 'Enter';
		CmdDesc: 'Use a stairway or portal.';
		KCode: '>';	),
	(	CmdName: 'PartBrowser';
		CmdDesc: 'Examine the individual components of your PC.';
		KCode: 'B';	),
	(	CmdName: 'LearnSkills';
		CmdDesc: 'Spend accumulated experience points.';
		KCode: 'L';	),
	(	CmdName: 'Attack';
		CmdDesc: 'Perform an attack.';
		KCode: 'a';	),
	(	CmdName: 'UseScenery';
		CmdDesc: 'Activate a stationary item, such as a door or a computer.';
		KCode: 'u';	),

	{ Commands 31 - 35 }
	(	CmdName: 'Messages';
		CmdDesc: 'Review all current adventure memos, email, and news.';
		KCode: 'm';	),
	(	CmdName: 'SaveGame';
		CmdDesc: 'Write the game data to disk, so you can come back and waste time later.';
		KCode: 'X';	),
	(	CmdName: 'Enter2';
		CmdDesc: 'Use a stairway or portal.';
		KCode: '<';	),
	(	CmdName: 'CharInfo';
		CmdDesc: 'View detailed information about your character, access option menus.';
		KCode: 'C';	),
	(	CmdName: 'ApplySkill';
		CmdDesc: 'Select and use a skill that the PC knows.';
		KCode: 's';	),

	{ Commands 36 - 40 }
	(	CmdName: 'Eject';
		CmdDesc: 'Eject from your mecha and abandon it on the field.';
		KCode: 'E';	),
	(	CmdName: 'Rest';
		CmdDesc: 'Take a break for one hour of game time.';
		KCode: 'Z';	),
	(	CmdName: 'History';
		CmdDesc: 'Display past messages.';
		KCode: 'V';	),
	(	CmdName: 'FieldHQ';
		CmdDesc: 'Examine and edit your personal wargear.';
		KCode: 'H';	),
	(	CmdName: 'Search';
		CmdDesc: 'Check the area for enemies and secrets.';
		KCode: 'S';	),

	{ Commands 41 - 45 }
	(	CmdName: 'Telephone';
		CmdDesc: 'Place a telephone call to a local NPC.';
		KCode: 'T';	),
	(	CmdName: 'SwitchBV';
		CmdDesc: 'Switch the Burst Fire option while selecting a target.';
		KCode: '>';	),
	(	CmdName: 'Reverse';
		CmdDesc: 'Travel backward at normal speed.';
		KCode: '-';	),
	(	CmdName: 'SwitchTarget';
		CmdDesc: 'Switch to next visible enemy when selecting a target.';
		KCode: ';';	),
	(	CmdName: 'RunToggle';
		CmdDesc: 'Toggle running on or off.';
		KCode: 'r';	)

	);

	{ *** KEYMAP COMMAND NUMBERS *** }
	KMC_NormSpeed = 1;
	KMC_FullSpeed = 2;
	KMC_TurnLeft = 3;
	KMC_TurnRight = 4;
	KMC_Stop = 5;
	KMC_SouthWest = 6;
	KMC_South = 7;
	KMC_SouthEast = 8;
	KMC_West = 9;
	KMC_East = 10;
	KMC_NorthWest = 11;
	KMC_North = 12;
	KMC_NorthEast = 13;
	KMC_ShiftGears = 14;
	KMC_ExamineMap = 15;
	KMC_AttackMenu = 16;
	KMC_QuitGame = 17;
	KMC_Talk = 18;
	KMC_Help = 19;
	KMC_SwitchWeapon = 20;
	KMC_CalledShot = 21;
	KMC_Recenter = 22;
	KMC_Get = 23;
	KMC_Inventory = 24;
	KMC_Equipment = 25;
	KMC_Enter = 26;
	KMC_PartBrowser = 27;
	KMC_LearnSkills = 28;
	KMC_Attack = 29;
	KMC_UseProp = 30;
	KMC_ViewMemo = 31;
	KMC_SaveGame = 32;
	KMC_Enter2 = 33;
	KMC_CharInfo = 34;
	KMC_ApplySkill = 35;
	KMC_Eject = 36;
	KMC_Rest = 37;
	KMC_History = 38;
	KMC_FieldHQ = 39;
	KMC_Search = 40;
	KMC_Telephone = 41;
	KMC_SwitchBV = 42;
	KMC_Reverse = 43;
	KMC_SwitchTarget = 44;
	KMC_RunToggle = 45;

implementation

uses dos,ability,gears,texutil;

	Procedure LoadConfig;
		{ Open the configuration file and set the variables }
		{ as needed. }
	var
		F: Text;
		S,CMD,C: String;
		T: Integer;
	begin
		{See whether or not there's a configuration file.}
		S := FSearch(Config_File,'.');
		if S <> '' then begin
			{ If we've found a configuration file, }
			{ open it up and start reading. }
			Assign(F,S);
			Reset(F);

			while not Eof(F) do begin
				ReadLn(F,S);
				cmd := ExtractWord(S);
				if (cmd <> '') then begin
					{Check to see if CMD is one of the standard keys.}
					cmd := UpCase(cmd);
					for t := 1 to NumMappedKeys do begin
						if UpCase(KeyMap[t].CmdName) = cmd then begin
							C := ExtractWord(S);
							if Length(C) = 1 then begin
								KeyMap[t].KCode := C[1];
							end;
						end;
					end;

					{ Check to see if CMD is the animation speed throttle. }
					if cmd = 'ANIMSPEED' then begin
						T := ExtractValue( S );
						if T < 0 then T := 0;
						FrameDelay := T;
					end else if cmd = 'MECHACONTROL' then begin
						C := UpCase( ExtractWord( S ) );
						case C[1] of
							'M': ControlMethod := MenuBasedInput;
							'R': ControlMethod := RLBasedInput;
						end;
					end else if cmd = 'CHARACONTROL' then begin
						C := UpCase( ExtractWord( S ) );
						case C[1] of
							'M': CharacterMethod := MenuBasedInput;
							'R': CharacterMethod := RLBasedInput;
						end;
					end else if cmd = 'WORLDCONTROL' then begin
						C := UpCase( ExtractWord( S ) );
						case C[1] of
							'M': WorldMapMethod := MenuBasedInput;
							'R': WorldMapMethod := RLBasedInput;
						end;

					end else if cmd = 'MISSILEBV' then begin
						C := UpCase( ExtractWord( S ) );
						for t := 1 to 4 do begin
							if UpCase(BVTypeName[t]) = C then begin
								DefMissileBV := T;
							end;
						end;

					end else if cmd = 'BALLISTICBV' then begin
						C := UpCase( ExtractWord( S ) );
						for t := 1 to 4 do begin
							if UpCase(BVTypeName[t]) = C then begin
								DefBallisticBV := T;
							end;
						end;

					end else if cmd = 'BEAMGUNBV' then begin
						C := UpCase( ExtractWord( S ) );
						for t := 1 to 4 do begin
							if UpCase(BVTypeName[t]) = C then begin
								DefBeamGunBV := T;
							end;
						end;
					end else if cmd = 'DIRECTSKILLOK' then begin
						Direct_Skill_Learning := True;

					end else if cmd = 'NOAUTOSAVE' then begin
						DoAutoSave := False;
					end else if cmd = 'ALWAYSSAVECHARACTER' then begin
						ALWAYS_SAVE_CHARACTER := True;
					end else if cmd = 'NOCOMBATTAUNTS' then begin
						No_Combat_Taunts := True;

					end else if cmd = 'NOALPHA' then begin
						Use_Alpha_Blending := False;
					end else if cmd = 'ALPHALEVEL' then begin
						T := ExtractValue( S );
						if T > 255 then T := 255
						else if T < 0 then T := 0;
						Alpha_Level := T;

					end else if cmd = 'NUMPLOTS' then begin
						T := ExtractValue( S );
						if T > 255 then T := 255
						else if T < 0 then T := 0;
						Max_Plots_Per_Adventure := T;

					end else if cmd = 'LOADPLOTSATSTART' then begin
						Load_Plots_At_Start := True;

					end else if cmd = 'MINIMAPON' then begin
						Display_Mini_Map := True;

					end else if cmd = 'SCREENHEIGHT' then begin
						T := ExtractValue( S );
						if T > 255 then T := 255
						else if T < 24 then T := 24;
						ScreenRows := T;

					end else if cmd = 'SCREENWIDTH' then begin
						T := ExtractValue( S );
						if T > 255 then T := 255
						else if T < 80 then T := 80;
						ScreenColumns := T;

					end else if cmd = 'FULLSCREEN' then begin
						DoFullScreen := True;

					end else if cmd = 'NOMOUSE' then begin
						Mouse_Active := False;

					end else if cmd = 'NAMESON' then begin
						Names_Above_Heads := True;

					end else if cmd = 'NOPILLAGE' then begin
						Pillage_On := False;
					end else if cmd = 'USETACTICSMODE' then begin
						UseTacticsMode := True;

					end else if cmd = 'AdvancedColors' then begin
						UseAdvancedColoring := True;

				    end else if cmd[1] = '#' then begin
					    S := '';

					end;
				end;
			end;

			{ Once the EOF has been reached, close the file. }
			Close(F);
		end;

	end;

    Procedure SaveConfig;
	    { Open the configuration file and record the variables }
	    { as needed. }
    var
	    F: Text;
	    T: Integer;
	    Procedure AddBoolean( const OpTag: String; IsOn: Boolean );
		    { Add one of the boolean options to the file. }
	    begin
		    if IsOn then begin
			    writeln( F , OpTag );
		    end else begin
			    writeln( F , '#' + OpTag );
		    end;
	    end;
    begin
	    { If we've found a configuration file, }
	    { open it up and start reading. }
	    Assign( F , Config_File );
	    Rewrite( F );

	    writeln( F , '#' );
	    writeln( F , '# ATTENTION:' );
	    writeln( F , '#   Only edit the config file if GearHead is not running.' );
	    writeln( F , '#   Configuration overwritten at game exit.' );
	    writeln( F , '#' );

	    for t := 1 to NumMappedKeys do begin
		    WriteLn( F, KeyMap[t].CmdName + ' ' + KeyMap[t].KCode );
	    end;

	    writeln( F, 'ANIMSPEED ' + BStr( FrameDelay ) );

	    writeln( F, 'MECHACONTROL ' + ControlTypeName[ ControlMethod ] );
	    writeln( F, 'CHARACONTROL ' + ControlTypeName[ CharacterMethod ] );
	    writeln( F, 'WORLDCONTROL ' + ControlTypeName[ WorldMapMethod ] );

	    writeln( F, 'MISSILEBV ' + BVTypeName[ DefMissileBV ] );
	    writeln( F, 'BALLISTICBV ' + BVTypeName[ DefBallisticBV ] );
	    writeln( F, 'BEAMGUNBV ' + BVTypeName[ DefBeamGunBV ] );

	    AddBoolean( 'DIRECTSKILLOK' , Direct_Skill_Learning );
	    AddBoolean( 'NOAUTOSAVE' , not DoAutoSave );
	    AddBoolean( 'ALWAYSSAVECHARACTER' , Always_Save_Character );
	    AddBoolean( 'NOCOMBATTAUNTS' , No_Combat_Taunts );
	    AddBoolean( 'NAMESON' , Names_Above_Heads );

	    AddBoolean( 'NOALPHA' , not Use_Alpha_Blending );
        writeln( F, 'ALPHALEVEL ' + BStr( Alpha_Level ) );

        writeln( F, 'NUMPLOTS ' + BStr( Max_Plots_Per_Adventure ) );
	    AddBoolean( 'LOADPLOTSATSTART' , Load_Plots_At_Start );
	    AddBoolean( 'MINIMAPON' , Display_Mini_Map );

	    writeln( F , 'SCREENHEIGHT ' + BStr( ScreenRows ) );
	    writeln( F , 'SCREENWIDTH ' + BStr( ScreenColumns ) );

	    AddBoolean( 'FULLSCREEN' , DoFullScreen );
	    AddBoolean( 'NOMOUSE' , not Mouse_Active );
	    AddBoolean( 'NOPILLAGE' , not Pillage_On );
	    AddBoolean( 'USETACTICSMODE' , UseTacticsMode );

	    AddBoolean( 'ADVANCEDCOLORS' ,  UseAdvancedColoring );

	    Close(F);
    end;


initialization

	LoadConfig;

finalization

    SaveConfig;

end.
