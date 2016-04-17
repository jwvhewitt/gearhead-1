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

	FontSearchNameDesc = Record
		FontFile: String;
		FontFace: Integer;
		FontSize: Integer;
	end;
	PFontSearchNameDesc = ^FontSearchNameDesc;

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
	{ PATCH_I18N: Converted by Load_I18N_Default }
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
	{ PATCH_I18N: Converted by Load_I18N_Default }
	BVTypeName: Array [1..4] of string = ('Off','1/4','1/2','Max');

	DoAutoSave: Boolean = True;

	Use_Alpha_Blending: Boolean = True;
	Alpha_Level: Byte = 135;
    Transparent_Interface: Boolean = True;

	Names_Above_Heads: Boolean = False;

	Max_Plots_Per_Adventure: Byte = 50;
	Load_Plots_At_Start: Boolean = False;

	Display_Mini_Map: Boolean = FaLSE;

	UseTacticsMode: Boolean = False;

	UseAdvancedColoring: Boolean = False;

    Accessibility_On: Boolean = False;

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

{$IF DEFINED(UNIX)}
	MaxFontSearchDirNum = 11;
	FontSearchDir: Array [1..MaxFontSearchDirNum] of String = (
		'',						{ Read from gharena.cfg }
		'Image',					{ default directory }
		'',						{ current directory }
		'/usr/local/share/fonts/gnu-unifont-ttf',	{ Failback Directory, FreeBSD 9.x and later }
		'/usr/local/share/fonts/OTF',			{ Failback Directory, FreeBSD 9.x and later }
		'/usr/local/share/fonts/TTF',			{ Failback Directory, FreeBSD 9.x and later }
		'/usr/local/lib/X11/fonts/TrueType',		{ Failback Directory, FreeBSD 6.3 and later }
		'/usr/X11R6/lib/X11/fonts/TrueType',		{ Failback Directory, FreeBSD 6.2 and before, some Distribution of GNU/Linux }
		'/usr/share/fonts/truetype/unifont',		{ Failback Directory, Debian GNU/Linux }
		'/usr/share/fonts/truetype/sazanami',		{ Failback Directory, Debian GNU/Linux }
		'/usr/share/fonts/opentype/ipafont-gothic'	{ Failback Directory, Debian GNU/Linux }
	);
	MaxFontSearchNameNum = 14;
	FontSearchName_Big: Array [1..MaxFontSearchNameNum] of FontSearchNameDesc = (
		(	{ Read from gharena.cfg }
			FontFile: '';
			FontFace: 0;
			FontSize: 14;
		), (	{ Read from GameData/I18N_settings.txt }
			FontFile: '';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 1 }
			FontFile: 'unifont.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 2 }
			FontFile: 'sazanami-gothic.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 3 }
			FontFile: 'sazanami-mincho.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 4 }
			FontFile: 'ipag.otf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 5 }
			FontFile: 'ipam.otf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 6 }
			FontFile: 'ipag.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 7 }
			FontFile: 'ipam.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 8 }
			FontFile: 'kochi-gothic-subst.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 9 }
			FontFile: 'kochi-mincho-subst.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 10 }
			FontFile: 'kochi-gothic.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 11 }
			FontFile: 'kochi-mincho.ttf';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, Default }
			FontFile: 'VeraBd.ttf';
			FontFace: 0;
			FontSize: 14;
		)
	);
	FontSearchName_Small: Array [1..MaxFontSearchNameNum] of FontSearchNameDesc = (
		(	{ Read from gharena.cfg }
			FontFile: '';
			FontFace: 0;
			FontSize: 11;
		), (	{ Read from GameData/I18N_settings.txt }
			FontFile: '';
			FontFace: 0;
			FontSize: 11;
		), (	{ Failback Font, 1 }
			FontFile: 'unifont.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 2 }
			FontFile: 'sazanami-gothic.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 3 }
			FontFile: 'sazanami-mincho.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 4 }
			FontFile: 'ipag.otf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 5 }
			FontFile: 'ipam.otf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 6 }
			FontFile: 'ipag.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 7 }
			FontFile: 'ipam.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 8 }
			FontFile: 'kochi-gothic-subst.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 9 }
			FontFile: 'kochi-mincho-subst.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 10 }
			FontFile: 'kochi-gothic.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, 11 }
			FontFile: 'kochi-mincho.ttf';
			FontFace: 0;
			FontSize: 12;
		), (	{ Failback Font, Default }
			FontFile: 'VeraMoBd.ttf';
			FontFace: 0;
			FontSize: 11;
		)
	);
{$ELSEIF DEFINED(WINDOWS)}
	MaxFontSearchDirNum = 6;
	FontSearchDir: Array [1..MaxFontSearchDirNum] of String = (
		'',			{ Read from gharena.cfg }
		'Image',		{ default directory }
		'',			{ current directory }
		'',			{ Failback Directory, Read environment %windir% or %SystemRoot% }
		'C:\WINDOWS\Fonts',	{ Failback Directory, MS-Windows XP, MS-Windows 7, MS-Windows 8.1, Wine }
		'C:\WINNT\Fonts'	{ Failback Directory, MS-Windows 2000 }
	);
	MaxFontSearchNameNum = 6;
	FontSearchName_Big: Array [1..MaxFontSearchNameNum] of FontSearchNameDesc = (
		(	{ Read from gharena.cfg }
			FontFile: '';
			FontFace: 0;
			FontSize: 15;
		), (	{ Read from GameData/I18N_settings.txt }
			FontFile: '';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, 1 }
			FontFile: 'meiryo.ttc';
			FontFace: 0;
			FontSize: 15;
		), (	{ Failback Font, 2 }
			FontFile: 'msgothic.ttc';
			FontFace: 0;
			FontSize: 15;
		), (	{ Failback Font, 3 }
			FontFile: 'msmincho.ttc';
			FontFace: 0;
			FontSize: 15;
		), (	{ Failback Font, Default }
			FontFile: 'VeraBd.ttf';
			FontFace: 0;
			FontSize: 14;
		)
	);
	FontSearchName_Small: Array [1..MaxFontSearchNameNum] of FontSearchNameDesc = (
		(	{ Read from gharena.cfg }
			FontFile: '';
			FontFace: 0;
			FontSize: 13;
		), (	{ Read from GameData/I18N_settings.txt }
			FontFile: '';
			FontFace: 0;
			FontSize: 11;
		), (	{ Failback Font, 1 }
			FontFile: 'meiryo.ttc';
			FontFace: 0;
			FontSize: 13;
		), (	{ Failback Font, 2 }
			FontFile: 'msgothic.ttc';
			FontFace: 0;
			FontSize: 13;
		), (	{ Failback Font, 3 }
			FontFile: 'msmincho.ttc';
			FontFace: 0;
			FontSize: 13;
		), (	{ Failback Font, Default }
			FontFile: 'VeraMoBd.ttf';
			FontFace: 0;
			FontSize: 11;
		)
	);
{$ELSE}
	MaxFontSearchDirNum = 3;
	FontSearchDir: Array [1..MaxFontSearchDirNum] of String = (
		'',			{ Read from gharena.cfg }
		'Image',		{ default directory }
		''			{ current directory }
	);
	MaxFontSearchNameNum = 3;
	FontSearchName_Big: Array [1..MaxFontSearchNameNum] of FontSearchNameDesc = (
		(	{ Read from gharena.cfg }
			FontFile: '';
			FontFace: 0;
			FontSize: 14;
		), (	{ Read from GameData/I18N_settings.txt }
			FontFile: '';
			FontFace: 0;
			FontSize: 14;
		), (	{ Failback Font, Default }
			FontFile: 'VeraBd.ttf';
			FontFace: 0;
			FontSize: 14;
		)
	);
	FontSearchName_Small: Array [1..MaxFontSearchNameNum] of FontSearchNameDesc = (
		(	{ Read from gharena.cfg }
			FontFile: '';
			FontFace: 0;
			FontSize: 11;
		), (	{ Read from GameData/I18N_settings.txt }
			FontFile: '';
			FontFace: 0;
			FontSize: 11;
		), (	{ Default font }
			FontFile: 'VeraMoBd.ttf';
			FontFace: 0;
			FontSize: 11;
		)
	);
{$ENDIF}

	FontSize_Big: Integer = 0;
	FontSize_Small: Integer = 0;
	{ PATCH_I18N: Converted by Load_I18N_Default }
	ProhibitationHead  : String = '! ) , . > ? ] }';
	ProhibitationTrail : String = '( < [ {';

	I18N_UseNameORG : Boolean = False;
const
	SDL_AAFont        : Boolean = False;
	SDL_AAFont_Shaded : Boolean = False;


Function I18N_Help_Keymap_Name_String( const MsgLabel: String ): String;
Function I18N_Help_Keymap_Desc_String( const MsgLabel: String ): String;


implementation

uses sysutils,dos,i18nmsg,ability,gears,texutil;


var
	I18N_Help_Keymap_Name: SAttPtr;
	I18N_Help_Keymap_Desc: SAttPtr;


Function I18N_Help_Keymap_Name_String( const MsgLabel: String ): String;
begin
	I18N_Help_Keymap_Name_String := SAttValue( I18N_Help_Keymap_Name, MsgLabel );
end;

Function I18N_Help_Keymap_Desc_String( const MsgLabel: String ): String;
begin
	I18N_Help_Keymap_Desc_String := SAttValue( I18N_Help_Keymap_Desc, MsgLabel );
end;

Procedure Load_I18N_Default;
begin
	ControlTypeName[0] := I18N_MsgString('ui4gh_ControlTypeName','Menu');
	ControlTypeName[1] := I18N_MsgString('ui4gh_ControlTypeName','Roguelike');
	BVTypeName[1]      := I18N_MsgString('ui4gh','BVTypeName1');
	BVTypeName[2]      := I18N_MsgString('ui4gh','BVTypeName2');
	BVTypeName[3]      := I18N_MsgString('ui4gh','BVTypeName3');
	BVTypeName[4]      := I18N_MsgString('ui4gh','BVTypeName4');
	ProhibitationHead                := I18N_Settings('ProhibitationHead',ProhibitationHead);
	ProhibitationTrail               := I18N_Settings('ProhibitationTrail',ProhibitationTrail);
	FontSearchName_Big[2].FontFile   := I18N_Settings('Default_FontFileBig',FontSearchName_Big[2].FontFile);
	FontSearchName_Big[2].FontFace   := StrToInt(I18N_Settings('Default_FontFaceBig',IntToStr(FontSearchName_Big[2].FontFace)));
	FontSearchName_Big[2].FontSize   := StrToInt(I18N_Settings('Default_FontSizeBig',IntToStr(FontSearchName_Big[2].FontSize)));
	FontSearchName_Small[2].FontFile := I18N_Settings('Default_FontFileSmall',FontSearchName_Small[2].FontFile);
	FontSearchName_Small[2].FontFace := StrToInt(I18N_Settings('Default_FontFaceSmall',IntToStr(FontSearchName_Small[2].FontFace)));
	FontSearchName_Small[2].FontSize := StrToInt(I18N_Settings('Default_FontSizeSmall',IntToStr(FontSearchName_Small[2].FontSize)));
end;


	Procedure LoadConfig;
		{ Open the configuration file and set the variables }
		{ as needed. }
	var
		F: Text;
		S,CMD,C: String;
		T: Integer;
{$IF DEFINED(WINDOWS)}
		WinDir: String;
{$ENDIF}
	begin
{$IF DEFINED(WINDOWS)}
		WinDir := '';
		if '' = WinDir then begin
			WinDir := GetEnvironmentVariable('SystemRoot');
		end;
		if '' = WinDir then begin
			WinDir := GetEnvironmentVariable('windir');
		end;
		if '' <> WinDir then begin
			FontSearchDir[4] := WinDir + DirectorySeparator + 'Fonts';
		end;
{$ENDIF}
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
					end else if cmd = 'NO_TRANSPARENT_INTERFACE' then begin
						Transparent_Interface := False;
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

                    end else if cmd = 'ACCESSIBILITY_ON' then begin
                        Accessibility_On := True;

					end else if cmd = 'I18N_USEORIGINALNAME' then begin
						if ExtractTF(S) then I18N_UseOriginalName := True else I18N_UseOriginalName := False;
					end else if cmd = 'I18N_USENAMEORG' then begin
						if ExtractTF(S) then I18N_UseNameORG := True else I18N_UseNameORG := False;
					end else if cmd = 'FONTFILEBIG' then begin
						FontSearchName_Big[1].FontFile   := ExtractWord( S );
						FontSearchName_Big[1].FontFace   := ExtractValue( S );
						if FontSearchName_Big[1].FontFace < 0 then begin FontSearchName_Big[1].FontFace := 0; end;
					end else if cmd = 'FONTFILESMALL' then begin
						FontSearchName_Small[1].FontFile := ExtractWord( S );
						FontSearchName_Small[1].FontFace := ExtractValue( S );
						if FontSearchName_Small[1].FontFace < 0 then begin FontSearchName_Small[1].FontFace := 0; end;
					end else if cmd = 'FONTSIZEBIG' then begin
						FontSize_Big := ExtractValue( S );
						if FontSize_Big < 1 then begin FontSize_Big := 0; end;
					end else if cmd = 'FONTSIZESMALL' then begin
						FontSize_Small := ExtractValue( S );
						if FontSize_Small < 1 then begin FontSize_Small := 0; end;

					end else if cmd = 'SDL_AAFONT' then begin
						if ExtractTF(S) then SDL_AAFont := True else SDL_AAFont := False;
					end else if cmd = 'SDL_AAFONT_SHADED' then begin
						if ExtractTF(S) then SDL_AAFont_Shaded := True else SDL_AAFont_Shaded := False;

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
		Procedure AddTrueFalse( const OpTag: String; IsOn: Boolean );
			{ Add one of the boolean options to the file. }
		begin
			if IsOn then begin
				writeln( F , OpTag + ' TRUE' );
			end else begin
				writeln( F , OpTag + ' FALSE' );
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
	    AddBoolean( 'NO_TRANSPARENT_INTERFACE' , not Transparent_Interface );
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
	    AddBoolean( 'ACCESSIBILITY_ON' ,  Accessibility_On );

		AddTrueFalse( 'I18N_USEORIGINALNAME' , I18N_UseOriginalName );
		AddTrueFalse( 'I18N_USENAMEORG' , I18N_UseNameORG );
		writeln( F , 'FONTFILEBIG ' + FontSearchName_Big[1].FontFile + ' ' + BStr( FontSearchName_Big[1].FontFace ) );
		writeln( F , 'FONTFILESMALL ' + FontSearchName_Small[1].FontFile + ' ' + BStr( FontSearchName_Small[1].FontFace ) );
		writeln( F , 'FONTSIZEBIG ' + BStr( FontSize_Big ) );
		writeln( F , 'FONTSIZESMALL ' + BStr( FontSize_Small ) );
		AddTrueFalse( 'SDL_AAFONT' , SDL_AAFont );
		AddTrueFalse( 'SDL_AAFONT_SHADED' , SDL_AAFont_Shaded );

	    Close(F);
    end;


initialization
begin
	I18N_Help_Keymap_Name := LoadStringList( I18N_Help_Keymap_Name_File );
	I18N_Help_Keymap_Desc := LoadStringList( I18N_Help_Keymap_Desc_File );
	Load_I18N_Default;

	LoadConfig;
end;

finalization
begin
	SaveConfig;
	DisposeSAtt( I18N_Help_Keymap_Desc );
	DisposeSAtt( I18N_Help_Keymap_Name );
end;

end.
