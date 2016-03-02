unit gears;
	{The building block from which everything in this game}
	{is constructed is called a GEAR. Just seemed a good}
	{thing to name the record, given the name of the game.}
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

Const
	NumGearStats = 8;	{The number of STAT slots}
				{in a GEAR record}

	{ In general, negative G scores denote abstract things. }
	{ Vitual gears are not subject to most game rules, range }
	{ checking, and whatnot. }
	GG_Story = -10;
	GG_Plot = -9;
	GG_MapFeature = -8; { Something that should be placed on the random map; subcom of SCENE. }
	GG_Adventure = -7; { A placeholder for SCENES and FACTIONS. }
	GG_Faction = -6; { A group or organization }
	GG_Persona = -5; { A conversation or interaction with a NPC }
	GG_Team = -4;	{ A team is a single cohesive unit on a map. }
	GG_Scene = -3;
	GG_Unit = -2;
	GG_AbsolutelyNothing = -1;

	GG_Mecha = 0;
	GG_Module = 1;
	GG_Character = 2;
	GG_Cockpit = 3;
	GG_Weapon = 4;
	GG_Ammo = 5;
	GG_MoveSys = 6;
	GG_Holder = 7;
	GG_Sensor = 8;
	GG_Support = 9;
	GG_Shield = 10;
	GG_ExArmor = 11;
	GG_Swag = 12;
	GG_Prop = 13;
	GG_Electronics = 14;
	GG_MetaTerrain = 15;	{ Acts kind of like terrain, but it's a gear. }
	GG_Usable = 16;		{ Gears which may be used continuously. Dealt with under ghswag. }
	GG_RepairFuel = 17;
	GG_Consumable = 18;
	GG_Modifier = 19;	{ Modifies stats; Defined in ghmodule.pp }
	GG_WeaponAddOn = 20;	{ Weapon accessory; Defined in ghweapon.pp }

	NAG_GearOps = 2;

	NumMaterial = 2;
	NAS_Material = 0;	{ This is the famous duality taken from }
	NAV_Metal = 0;		{ CyberPunk- metal vs. meat. Metal has }
	NAV_Meat = 1;		{ higher DP, but meat regenerates. }
		{ Default material for all items is metal. }
	NAV_BioTech = 2;	{ Biotech has HP like metal but regen }
				{ like meat. }

	{ This array tells if a given material regenerates damage. }
	MAT_Regenerate: Array [0..NumMaterial] of Boolean = (
		False, True, True
	);

	NAS_MassAdjust = 1;	{ Can make an item heavier or lighter. }

	NAS_DominationTarget = 2;	{ Target number for Dominate Animal skill }
	NAS_EvolveAt = 3;		{ XP target for evolution }
	NAS_Fudge = 4;			{ Value adjustment. }


	NAG_Narrative = 7;	{ Variables having to do with RPG }
	NAS_NID = 0;	{ Narrative ID }

	{ The following are used by the randmaps unit... }
	NAS_LockedDoorChance = 101;
	NAS_SecretDoorChance = 102;

	NAS_MaxCID = 3;
	NAS_MaxNID = 4;


	NAS_XRMystery = 10;
	NAS_XREnemy = 11;
	NAS_XRBadThing = 12;

	{ The following may be used by various scenarios... }
	NAS_VictimsRecovered = 201;

	MassPerMV = 15;		{ Amount of mass per MV , TR modifier. }

	NAG_Display = 13;
	NAS_PrimaryFrame = 0;

	NAG_Prefrences = 15;
	NAS_DefAtOp = 0;	{ Default Attack Option }

	{ ******************************* }
	{ ***  FILE  NAME  CONSTANTS  *** }
	{ ******************************* }

	OS_Dir_Separator = DirectorySeparator;
	OS_Search_Separator = PathSeparator;
	OS_Current_Directory = '.';

	{ All of the following file names have been checked for }
	{ correct capitalization. Hopefully, everything should run }
	{ fine. }
	Default_File_Ending = '.txt';
	Default_Search_Pattern = '*.txt';

{	Save_Game_DirName = 'SaveGame';
	Save_Game_Directory = Save_Game_DirName + OS_Dir_Separator;
	Save_Character_Base = Save_Game_Directory + 'CHA';
	Save_Unit_Base = Save_Game_Directory + 'GHU';
	Save_Campaign_Base = Save_Game_Directory + 'RPG';
}
	Design_DirName = 'Design';
	Design_Directory = Design_DirName + OS_Dir_Separator;
	PC_Equipment_File = Design_Directory + 'PC_Equipment.txt';
	Mek_Equipment_File = Design_Directory + 'Mek_Equipment.txt';
	Series_DirName = 'Series';
	Series_Directory = Series_DirName + OS_Dir_Separator;
	Archetypes_File = Series_Directory + 'ANPCdefault.txt';
	Adventure_File_Base = Series_Directory + 'ADV_';
	STC_Item_File = Series_Directory + 'STCdefault.txt';
	Plot_Seacrh_Pattern = Series_Directory + 'PLOT' + Default_Search_Pattern;
	Jobs_File = Series_Directory + 'RCJobs.txt';
	Monsters_File = Series_Directory + 'WMONdefault.txt';
	Data_DirName = 'GameData';
	Data_Directory = Data_DirName + OS_Dir_Separator;
	MetaTerrain_File_Base = Data_Directory + 'meta';
	Trait_Chatter_Base = Data_Directory + 'TC_';
	Standard_Message_File = Data_Directory + 'messages.txt';
	Damage_Strings_File = Data_Directory + 'damage.txt';
	Ability_Message_File = Data_Directory + 'ability.txt';
	Standard_Nouns_File = Data_Directory + 'nouns.txt';
	Standard_Phrases_File = Data_Directory + 'phrases.txt';
	Standard_Adjectives_File = Data_Directory + 'adjectives.txt';
	Standard_Rumors_File = Data_Directory + 'rumors.txt';
	Standard_Chatter_File = Data_Directory + 'chat_msg.txt';
	Standard_Threats_File = Data_Directory + 'threats.txt';
	Parser_Macro_File = Data_Directory + 'ghpmacro.txt';
	Script_Macro_File = Data_Directory + 'aslmacro.txt';
	Value_Macro_File = Data_Directory + 'asvmacro.txt';
	Effects_Message_File = Data_Directory + 'effects.txt';
	RandMaps_Param_File = Data_Directory + 'randmaps.txt';
	NPC_Chatter_File = Data_Directory + 'taunts.txt';

	Doc_DirName = 'doc';
	Doc_Directory = Doc_DirName + OS_Dir_Separator;
	Mecha_Help_File = Doc_Directory + 'man_umek.txt';
	FieldHQ_Help_File = Doc_Directory + 'man_mecha.txt';
	Chara_Help_File = Doc_Directory + 'man_chara.txt';


{$IFDEF SDLMODE}
	Graphics_DirName = 'Image';
	Graphics_Directory = Graphics_Dirname + OS_Dir_Separator;
{$ENDIF}

	STARTUP_OK: Boolean = True;

Type
	SAttPtr = ^SAtt;
	SAtt = Record		{*** STRING ATTRIBUTE ***}
		info: String;
		next: SAttPtr;
	end;

	NAttPtr = ^NAtt;
	NAtt = Record		{*** NUMERICAL ATTRIBUTE ***}
		G,S: Integer;		{General, Specific, Value}
		V: LongInt;
		next: NAttPtr;
	end;

	GearPtr = ^gear;
	gear = Record		{*** GEARHEAD BIT ***}
		G,S,V: Integer;		{General Descriptive,}
					{Specific Descriptive,}
					{and Value Descriptive}

		Scale: Integer;		{Scale of this Gear}
		Stat: Array [1..NumGearStats] of Integer;
					{Gear Stats. Needed info for Gear type.}

		SA: SAttPtr;		{String Attributes.}
		NA: NAttPtr;		{Numerical Attributes.}

		next: GearPtr;		{Next sibling Gear}
		subcom: GearPtr;	{Child Internal Gear}
		invcom: GearPtr;	{Child External Gear}
		parent: GearPtr;	{Parent of the current Gear.}
	end;

var
	Save_Game_DirName,Save_Game_Directory,Save_Character_Base,Save_Unit_Base,Save_Campaign_Base: String;
	Config_Directory,Config_File: String;



Function CreateSAtt(var LList: SAttPtr): SAttPtr;
Procedure DisposeSAtt(var LList: SAttPtr);
Procedure RemoveSAtt(var LList,LMember: SAttPtr);
Function FindSAtt(LList: SAttPtr; const Code_In: String): SAttPtr;
Function SetSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
Function StoreSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
Function AddSAtt( var LList: SAttPtr; const S_Label_in,S_Data: String ): SAttPtr;
Function SAttValue(LList: SAttPtr; const Code: String): String;
function NumSAtts( GList: SAttPtr ): Integer;
function RetrieveSAtt( List: SAttPtr; N: Integer ): SAttPtr;
function SelectRandomSAtt( SAList: SAttPtr ): SAttPtr;
Function LoadStringList( const FName_In: String ): SAttPtr;
Procedure SaveStringList( const FName: String; SList: SattPtr );
Procedure ExpandFileList( var FList: SAttPtr; const P: String );
Function CreateFileList( const P: String ): SAttPtr;

Function NumHeadMatches( const head_in: String; LList: SAttPtr ): Integer;
Function FindHeadMatch( const head_in: String; LList: SAttPtr; N: Integer ): SAttPtr;
Function StringInList( const string_to_match: String; LList: SAttPtr ): Boolean;

Function CreateNAtt(var LList: NAttPtr): NAttPtr;
Procedure DisposeNAtt(var LList: NAttPtr);
Procedure RemoveNAtt(var LList,LMember: NAttPtr);
Function FindNAtt(LList: NAttPtr; G,S: Integer): NAttPtr;
Function SetNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt): NAttPtr;
Function AddNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt): NAttPtr;
Function NAttValue(LList: NAttPtr; G,S: Integer): LongInt;
Procedure StripNAtt( Part: GearPtr ; G: Integer );

Function LastGear(LList: GearPtr): GearPtr;
Function NewGear( Parent: GearPtr ): GearPtr;
Procedure AppendGear( var LList: GearPtr; It: GearPtr );
Function AddGear(var LList: GearPtr; Parent: GearPtr): GearPtr;
Procedure DisposeGear(var LList: GearPtr);
Procedure RemoveGear(var LList,LMember: GearPtr);
Procedure DelinkGear(var LList,LMember: GearPtr);
function NumSiblingGears( GList: GearPtr ): Integer;
function SelectRandomGear( GList: GearPtr ): GearPtr;

function FindRoot( Part: GearPtr ): GearPtr;
Procedure InsertSubCom( Parent,NewMember: GearPtr );
Procedure InsertInvCom( Parent,NewMember: GearPtr );

Function IsFoundAlongTrack( Track,Part: GearPtr ): Boolean;
Function IsSubCom( Part: GearPtr ): Boolean;
Function IsInvCom( Part: GearPtr ): Boolean;

Function CloneSAtt( SA: SAttPtr ): SAttPtr;
Function CloneGear( Part: GearPtr ): GearPtr;
Function RetrieveGearSib( List: GearPtr; N: Integer ): GearPtr;
Procedure Rescale( Part: GearPtr; SF: Integer );



implementation

{ "sysutils" has to come before "dos" }
uses sysutils,dos,texutil;

Function LastSAtt( LList: SAttPtr ): SAttPtr;
	{ Find the last SAtt in this particular list. }
begin
	if LList <> Nil then while LList^.Next <> Nil do LList := LList^.Next;

	LastSAtt := LList;
end;

Function CreateSAtt(var LList: SAttPtr): SAttPtr;
	{Add a new element to the tail of LList.}
var
	it: SAttPtr;
begin
	{Allocate memory for our new element.}
	New(it);
	if it = Nil then exit( Nil );
	it^.Next := Nil;

	{Attach IT to the list.}
	if LList = Nil then begin
		LList := it;
	end else begin
		LastSAtt( LList )^.Next := it;
	end;

	{Return a pointer to the new element.}
	CreateSAtt := it;
end;

Procedure DisposeSAtt(var LList: SAttPtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: SAttPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;
		Dispose(LList);
		LList := LTemp;
	end;
end;

Procedure RemoveSAtt(var LList,LMember: SAttPtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: SAttPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveSAtt asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		Dispose(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		Dispose(B);
	end;
end;

Function LabelsMatch( const info,code: String ): Boolean;
	{ Return TRUE if UpCase( CODE ) matches UpCase( INFO ) all the }
	{ way to the first '<', ignoring spaces and tabs. }
var
	i_pos,c_pos: Integer;
begin
	{ error check... }
	if ( info = '' ) or ( code = '' ) then Exit( False );
	i_pos := 0;
	c_pos := 0;
	repeat
		inc( i_pos );
		inc( c_pos );
		while (i_pos <= Length(info)) and ((info[i_pos] = ' ') or (info[i_pos] = #9)) do begin
			Inc(i_pos);
		end;
		while (c_pos <= Length(code)) and ((code[c_pos] = ' ') or (code[c_pos] = #9)) do begin
			Inc(c_pos);
		end;
	until ( i_pos > Length( info ) ) or ( c_pos > Length( code ) ) or ( UpCase( info[i_pos] ) <> UpCase( code[c_pos] ) );

	LabelsMatch := ( c_pos > Length( code ) ) and ( i_pos <= Length( info ) ) and ( info[i_pos] = '<' );
end;

Function FindSAtt(LList: SAttPtr; const Code_In: String): SAttPtr;
	{Search through the list looking for a String Attribute}
	{whose code matches CODE and return its address.}
	{Return Nil if no such SAtt can be found.}
var
	it: SAttPtr;
	Code: String;
begin
	{Initialize IT to Nil.}
	it := Nil;

	Code := UpCase(Code_In);

	{Check through all the SAtts looking for the SATT in question.}
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if LabelsMatch( LList^.info , Code ) then it := LList;
		LList := LList^.Next;
	end;

	FindSAtt := it;
end;

Function SetSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
	{Add string attribute Info to the list. However, a gear}
	{may not have two string attributes with the same name.}
	{So, check to see whether or not the list already contains}
	{a string attribute of this type; if so, just replace the}
	{INFO field. If not, create a new SAtt and fill it in.}
var
	it: SAttPtr;
	code: String;
begin
	{Determine the CODE of the string.}
	code := Info;
	code := ExtractWord(code);

	{See if that code already exists in the list,}
	{if not create a new entry for it.}
	it := FindSAtt(LList,code);

	{Plug in the value.}
	if RetrieveAString( Info ) = '' then begin
		if it <> Nil then RemoveSAtt( LList , it );
	end else begin
		if it = Nil then it := CreateSAtt(LList);
		it^.info := Info;
	end;

	{Return a pointer to the new attribute.}
	SetSAtt := it;
end;

Function StoreSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
	{ Add string attribute Info to the list. This procedure }
	{ doesn't check to make sure this attribute isn't duplicated. }
var
	it: SAttPtr;
begin
	it := CreateSAtt(LList);
	it^.info := Info;

	{Return a pointer to the new attribute.}
	StoreSAtt := it;
end;

Function AddSAtt( var LList: SAttPtr; const S_Label_In,S_Data: String ): SAttPtr;
	{ Store this data in the string attributes list with kind-of the }
	{ same label. If the label already exists, store under Label1, }
	{ then the next data under Label2, and so on. }
var
	T: SAttPtr;
	Info: String;
	Max,N: Integer;
	S_Label: String;
begin
	{ Find the maximum value of this label currently stored in }
	{ the list. }
	Max := 1;
	S_Label := UpCase( S_Label_In );

	{ Scan the list for examples of this label. }
	T := LList;
	while T <> Nil do begin
		Info := T^.Info;
		Info := UpCase( ExtractWord( Info ) );

		{ If the first characters are the same as S_label, this }
		{ is another copy of the list. }
		if Copy( Info , 1 , Length( S_Label ) ) = S_Label then begin
			Info := Copy( Info , Length( S_Label ) + 1 , Length( Info ) );
			N := ExtractValue( Info );
			if N >= Max then Max := N + 1;
		end;

		T := T^.Next;
	end;

	AddSAtt := SetSAtt( LList , S_Label + BStr( Max ) + ' <' + S_Data + '>' );
end;

Function SAttValue(LList: SAttPtr; const Code: String): String;
	{Find a String Attribute which corresponds to Code, then}
	{return its embedded alligator string.}
var
	it: SAttPtr;
begin
	it := FindSAtt(LList,Code);

	if it = Nil then Exit('');

	SAttValue := RetrieveAString(it^.info);
end;

function NumSAtts( GList: SAttPtr ): Integer;
	{ Count the number of sibling gears along this track. }
var
	N: Integer;
begin
	N := 0;
	while GList <> Nil do begin
		Inc( N );
		GList := GList^.Next;
	end;
	NumSAtts := N;
end;

function RetrieveSAtt( List: SAttPtr; N: Integer ): SAttPtr;
	{ Retrieve a SAtt from the list. }
begin
	{ error check- if asked to find a gear before the first one in }
	{ the list, obviously we can't do that. Return Nil. }
	if N < 1 then Exit( Nil );

	{ Search for the desired gear. }
	while ( N > 1 ) and ( List <> Nil ) do begin
		Dec( N );
		List := List^.Next;
	end;

	{ Return the last gear found. }
	RetrieveSAtt := List;
end;

function SelectRandomSAtt( SAList: SAttPtr ): SAttPtr;
	{ Pick one of the string attributes from the provided }
	{ list at random. }
var
	ST: SAttPtr;
	N,T: Integer;
begin
	{ Count the number of SAtts total. }
	ST := SAList;
	N := NumSAtts( SAList );
	{ Choose one randomly. }
	if N > 0 then begin
		T := Random( N ) + 1;
		ST := RetrieveSATt( SAList , T );
	end;
	SelectRandomSAtt := ST;
end;

Function LoadStringList( const FName_In: String ): SAttPtr;
	{ Load a list of string attributes from the listed file, }
	{ if it can be found. }
var
	SList: SAttPtr;
	F: Text;
	S: String;
        FName: String;
begin
	SList := Nil;
	FName := FSearch( FName_In , '.' );
	if FName <> '' then begin
		Assign( F , FName );
		Reset( F );

		{ Get rid of the opening comment }
		ReadLn( F , S );

		while not EOF( F ) do begin
			ReadLn( F , S );
			if S <> '' then StoreSAtt( SList , S );
		end;

		Close( F );
	end;
	LoadStringList := SList;
end;

Procedure SaveStringList( const FName: String; SList: SattPtr );
	{ Save a list of string attributes to the listed filename. }
var
	F: Text;
begin
	Assign( F , FName );
	Rewrite( F );

	WriteLn( F , '%%% File saved by SaveStringList %%%' );

	while SList <> Nil do begin
		WriteLn( F , SList^.Info );
		SList := SList^.Next;
	end;
	Close( F );
end;

Procedure ExpandFileList( var FList: SAttPtr; const P: String );
	{ Add more files to the list. }
var
	SRec: SearchRec;
begin
	FindFirst( P , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		StoreSAtt( FList , SRec.Name );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;
	FindClose( SRec );
end;

Function CreateFileList( const P: String ): SAttPtr;
	{ Create a list of file names which match the requested pattern. }
var
	LList: SAttPtr;
begin
	{ Start the search process going... }
	LList := Nil;
	ExpandFileList( LList , P );
	CreateFileList := LList;
end;

Function NumHeadMatches( const head_in: String; LList: SAttPtr ): Integer;
	{ Return how many SAtts in the list match the HEAD provided. }
	{ A match is made if the first Length(head) characters of }
	{ the string attribute are equal to head. }
var
	N: Integer;
        Head: String;
begin
	N := 0;
	Head := UpCase( Head_In );
	while LList <> Nil do begin
		if UpCase( Copy( LList^.Info , 1 , Length( Head ) ) ) = Head then begin
			Inc( N );
		end;
		LList := LList^.Next;
	end;
	NumHeadMatches := N;
end;

Function FindHeadMatch( const head_in: String; LList: SAttPtr; N: Integer ): SAttPtr;
	{ Return head match number N, as defined above. }
	{ If no match is found return Nil. }
var
	HM: SAttPtr;
        Head: String;
begin
	HM := Nil;
	Head := UpCase( Head_In );
	while LList <> Nil do begin
		if UpCase( Copy( LList^.Info , 1 , Length( Head ) ) ) = Head then begin
			Dec( N );
			if N = 0 then HM := LList;
		end;
		LList := LList^.Next;
	end;
	FindHeadMatch := HM;
end;

Function StringInList( const string_to_match: String; LList: SAttPtr ): Boolean;
    { Check this list to see if it includes string_to_match. If it does, }
    { return True. Otherwise return False. }
var
    foundit: Boolean;
begin
    foundit := False;
    while ( LList <> Nil ) and not foundit do begin
        if LList^.Info = string_to_match then foundit := True;
        LList := LList^.Next;
    end;
    StringInList := foundit;
end;

Function CreateNAtt(var LList: NAttPtr): NAttPtr;
	{Add a new element to the head of LList.}
var
	it: NAttPtr;
begin
	{Allocate memory for our new element.}
	New(it);
	if it = Nil then exit( Nil );

	{Initialize values.}

	it^.Next := LList;
	LList := it;

	{Return a pointer to the new element.}
	CreateNAtt := it;
end;

Procedure DisposeNAtt(var LList: NAttPtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: NAttPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;
		Dispose(LList);
		LList := LTemp;
	end;
end;

Procedure RemoveNAtt(var LList,LMember: NAttPtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: NAttPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveLink asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		Dispose(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		Dispose(B);
	end;
end;

Function FindNAtt(LList: NAttPtr; G,S: Integer): NAttPtr;
	{Locate the numerical attribute described by G,S and}
	{return a pointer to it. If no such attribute exists}
	{in the list, return Nil.}
var
	it: NAttPtr;
begin
	{Initialize it to Nil.}
	it := Nil;

	{Loop through all the elements.}
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if (LList^.G = G) and (LList^.S = S) then it := LList;
		LList := LList^.Next;
	end;

	{Return the value.}
	FindNatt := it;
end;

Function SetNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt ): NAttPtr;
	{Set the Numerical Attribute described by G,S to value V.}
	{If the attribute already exists, change its value. If not,}
	{create the attribute.}
var
	it: NAttPtr;
begin
	it := FindNAtt(LList,G,S);

	if ( it = Nil ) and ( V <> 0 ) then begin
		{The attribute doesn't currently exist. Create it.}
		it := CreateNAtt(LList);
		it^.G := G;
		it^.S := S;
		it^.V := V;
	end else if ( it <> Nil ) and ( V = 0 ) then begin
		RemoveNAtt( LList , it );
	end else if it <> Nil then begin
		{The attribute is already posessed. Just change}
		{its Value field.}
		it^.V := V;
	end;

	SetNAtt := it;
end;

Function AddNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt ): NAttPtr;
	{Add value V to the value field of the Numerical Attribute}
	{described by G,S. If the attribute does not exist, create}
	{it and set its value to V.}
	{If, as a result of this operation, V drops to 0,}
	{the numerical attribute will be removed and Nil will}
	{be returned.}
var
	it: NAttPtr;
begin
	it := FindNAtt(LList,G,S);

	if it = Nil then begin
		{The attribute doesn't currently exist. Create it.}
		it := CreateNAtt(LList);
		it^.G := G;
		it^.S := S;
		it^.V := V;
	end else begin
		it^.V := it^.V + V;
	end;

	if it^.V = 0 then RemoveNAtt(LList,it);

	AddNAtt := it;
end;

Function NAttValue(LList: NAttPtr; G,S: Integer): LongInt;
	{Return the value of Numeric Attribute G,S. If this}
	{attribute is not posessed, return 0.}
var
	it: LongInt;
begin
	it := 0;
	while LList <> Nil do begin
		if (LList^.G = G) and (LList^.S = S) then it := LList^.V;
		LList := LList^.Next;
	end;
	NAttValue := it;
end;

Procedure StripNAtt( Part: GearPtr ; G: Integer );
	{ Remove all numeric attributes of general type G from }
	{ PART and all of its children. }
var
	SG: GearPtr;
	NA,NA2: NAttPtr;
begin
	{ Remove from PART. }
	NA := Part^.NA;
	while NA <> Nil do begin
		NA2 := NA^.Next;
		if NA^.G = G then RemoveNAtt( Part^.NA , NA );
		NA := NA2;
	end;

	{ Remove from the InvComponents. }
	SG := Part^.InvCom;
	while SG <> Nil do begin
		StripNAtt( SG , G );
		SG := SG^.Next;
	end;

	{ Remove from the SubComponents. }
	SG := Part^.SubCom;
	while SG <> Nil do begin
		StripNAtt( SG , G );
		SG := SG^.Next;
	end;
end;

Function LastGear(LList: GearPtr): GearPtr;
	{Search through the linked list, and return the last element.}
	{If LList is empty, return Nil.}
begin
	if LList <> Nil then
		while LList^.Next <> Nil do
			LList := LList^.Next;
	LastGear := LList;
end;

Function NewGear( Parent: GearPtr ): GearPtr;
	{ Create a new gear, and initialize it to default values. }
var
	T: Integer;
	it: GearPtr;
begin
	{Allocate memory for our new element.}
	New(it);
	if it = Nil then exit;

	{Initialize values.}
	it^.Next := Nil;
	it^.SA := Nil;
	it^.NA := Nil;
	it^.SubCom := Nil;
	it^.InvCom := Nil;
	it^.Parent := Parent;

	it^.G := 0;
	it^.S := 0;
	it^.V := 0;
	it^.Scale := 0;

	for t := 1 to NumGearStats do it^.Stat[t] := 0;

	NewGear := it;
end;

Procedure AppendGear( var LList: GearPtr; It: GearPtr );
	{ Attach IT to the end of the list. }
begin
	{Attach IT to the list.}
	if LList = Nil then
		LList := it
	else
		LastGear(LList)^.Next := it;
end;

Function AddGear(var LList: GearPtr; Parent: GearPtr): GearPtr;
	{Add a new element to the end of LList.}
var
	it: GearPtr;
begin
	it := NewGear( Parent );

	AppendGear( LList , It );

	{Return a pointer to the new element.}
	AddGear := it;
end;

Procedure DisposeGear( var LList: GearPtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: GearPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;

		{Dispose of all resources and children attached to this GEAR.}
		if LList^.SA <> Nil then DisposeSAtt(LList^.SA);
		if LList^.NA <> Nil then DisposeNAtt(LList^.NA);

		DisposeGear( LList^.SubCom );
		DisposeGear( LList^.InvCom );

		{Dispose of the GEAR itself.}
		Dispose(LList);
		LList := LTemp;
	end;
end;

Procedure RemoveGear(var LList,LMember: GearPtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: GearPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveGear asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		B^.Next := Nil;
		DisposeGear(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.next := Nil;
		DisposeGear(B);
	end;
end;

Procedure DelinkGear(var LList,LMember: GearPtr);
	{Locate and extract member LMember from list LList.}
var
	a,b: GearPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- DelinkGear asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		B^.Next := Nil;
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.next := Nil;
	end;

	{ LMember has been delinked. Get rid of its parent, if it had one. }
	LMember^.Parent := Nil;
end;

function NumSiblingGears( GList: GearPtr ): Integer;
	{ Count the number of sibling gears along this track. }
var
	N: Integer;
begin
	N := 0;
	while GList <> Nil do begin
		Inc( N );
		GList := GList^.Next;
	end;
	NumSiblingGears := N;
end;

function SelectRandomGear( GList: GearPtr ): GearPtr;
	{ Pick one of the sibling gears from the provided }
	{ list at random. }
var
	ST: GearPtr;
	N,T: Integer;
begin
	{ Count the number of gears total. }
	N := NumSiblingGears( GList );

	{ Choose one randomly. }
	if N > 0 then begin
		T := Random( N ) + 1;
		ST := GList;
		N := 1;
		while N < T do begin
			Inc( N );
			St := St^.Next;
		end;
	end else begin
		ST := Nil;
	end;
	SelectRandomGear := ST;
end;


function FindRoot( Part: GearPtr ): GearPtr;
	{ Locate the master of PART. Return NIL if there is no master. }
begin
	{ Move the pointer up to either root level or the first Master parent. }
	while ( Part <> Nil ) and ( Part^.Parent <> Nil ) do Part := Part^.Parent;

	FindRoot := Part;
end;

Procedure InsertSubCom( Parent,NewMember: GearPtr );
	{ Insert the new gear NewMember as a child of Parent. }
begin
	if Parent^.SubCom = Nil then begin
		Parent^.SubCom := NewMember;
	end else begin
		LastGear(Parent^.SubCom)^.Next := NewMember;
	end;

	{ Set the parent value to the parent gear. Do this for every }
	{ item in the NewMember list. }
	while NewMember <> Nil do begin
		NewMember^.Parent := Parent;
		NewMember := NewMember^.Next;
	end;
end;

Procedure InsertInvCom( Parent,NewMember: GearPtr );
	{ Insert the new gear NewMember as a child of Parent. }
begin
	if Parent^.InvCom = Nil then begin
		Parent^.InvCom := NewMember;
	end else begin
		LastGear(Parent^.InvCom)^.Next := NewMember;
	end;

	{ Set the parent value to the parent gear. Do this for every }
	{ item in the NewMember list. }
	while NewMember <> Nil do begin
		NewMember^.Parent := Parent;
		NewMember := NewMember^.Next;
	end;
end;

Function CloneSAtt( SA: SAttPtr ): SAttPtr;
	{ Exactly copy a list of strings. }
var
	LList: SAttPtr;
begin
	LList := Nil;
	while SA <> Nil do begin
		SetSAtt( LList , SA^.Info );
		SA := SA^.Next;
	end;
	CloneSAtt := LList;
end;

Function CloneGear( Part: GearPtr ): GearPtr;
	{ Create an exact copy of PART, including all attributes and }
	{ components. }
	Procedure XeroxGear( Master,Blank: GearPtr );
		{ Copy Master to Blank, ignoring the connective fields. }
	var
		t: Integer;
		NA: NAttPtr;
	begin
		{ Copy basic info. }
		Blank^.G := Master^.G;
		Blank^.S := Master^.S;
		Blank^.V := Master^.V;
		Blank^.Scale := Master^.Scale;

		{ Copy stats. }
		for T := 1 to NumGearStats do Blank^.Stat[t] := Master^.Stat[t];

		{ Copy attributes. }
		NA := Master^.NA;
		while NA <> Nil do begin
			SetNAtt( Blank^.NA , NA^.G , NA^.S , NA^.V );
			NA := NA^.Next;
		end;

		Blank^.SA := CloneSAtt( Master^.SA );
	end;

	Function CloneTrack( Parent,Part: GearPtr ): GearPtr;
		{ Copy this gear and all its siblings. }
	var
		it,P2: GearPtr;
	begin
		it := Nil;

		while Part <> Nil do begin
			P2 := AddGear( it , Parent );
			XeroxGear( Part , P2 );
			P2^.SubCom := CloneTrack( P2 , Part^.SubCom );
			P2^.InvCom := CloneTrack( P2 , Part^.InvCom );
			Part := Part^.Next;
		end;

		CloneTrack := it;
	end;
var
	it: GearPtr;
begin
	if Part = Nil then exit( Nil );

	it := NewGear( Nil );
	XeroxGear( Part , it );
	it^.SubCom := CloneTrack( it , Part^.SubCom );
	it^.InvCom := CloneTrack( it , Part^.InvCom );
	CloneGear := it;
end;

Function RetrieveGearSib( List: GearPtr; N: Integer ): GearPtr;
	{ Find the address of the Nth sibling gear in this list. }
	{ If no such gear exists, return Nil. }
begin
	{ error check- if asked to find a gear before the first one in }
	{ the list, obviously we can't do that. Return Nil. }
	if N < 1 then Exit( Nil );

	{ Search for the desired gear. }
	while ( N > 1 ) and ( List <> Nil ) do begin
		Dec( N );
		List := List^.Next;
	end;

	{ Return the last gear found. }
	RetrieveGearSib := List;
end;

Function IsFoundAlongTrack( Track,Part: GearPtr ): Boolean;
	{ Return TRUE if PART is found as a sibling component somewhere }
	{ along TRACK, or FALSE if it cannot be found. }
var
	it: Boolean;
begin
	it := False;

	While Track <> Nil do begin
		if Track = Part then it := True;
		Track := Track^.Next;
	end;

	IsFoundAlongTrack := it;
end;

Function IsSubCom( Part: GearPtr ): Boolean;
	{ Return TRUE if PART is a subcomponent of its parent, FALSE otherwise. }
begin
	{ First an error check- if PART doesn't exist, or if it is at root }
	{ level, it can't be a subcom. }
	if ( Part = Nil ) or ( Part^.Parent = Nil ) then begin
		IsSubCom := False;
	end else begin
		IsSubCom := IsFoundAlongTrack( Part^.Parent^.SubCom , Part );
	end;
end;

Function IsInvCom( Part: GearPtr ): Boolean;
	{ Return TRUE if PART is an invcomponent of its parent, FALSE otherwise. }
begin
	{ First an error check- if PART doesn't exist, or if it is at root }
	{ level, it can't be an invcom. }
	if ( Part = Nil ) or ( Part^.Parent = Nil ) then begin
		IsInvCom := False;
	end else begin
		IsInvCom := IsFoundAlongTrack( Part^.Parent^.InvCom , Part );
	end;
end;

Procedure CheckDirectoryPresent;
	{ Make sure that the default save directory exists. If not, }
	{ create it. }
var
	S: String;
begin
	if not DirectoryExists( Config_Directory ) then begin
		MkDir( Config_Directory );
	end;
	if not DirectoryExists( Save_Game_Directory ) then begin
		MkDir( Save_Game_Directory );
	end;

	{ Check to make sure all the other directories can be found. }
	Startup_OK := DirectoryExists( Design_DirName );
	Startup_OK := Startup_OK and DirectoryExists( Series_DirName );
	Startup_OK := Startup_OK and DirectoryExists( Data_DirName );
{$IFDEF SDLMODE}
	Startup_OK := Startup_OK and DirectoryExists( Graphics_DirName );
{$ENDIF}
end;

Procedure Rescale( Part: GearPtr; SF: Integer );
	{ Alter the scale of this part and all its subcoms. }
var
	S: GearPtr;
begin
	Part^.Scale := SF;
	S := Part^.SubCom;
	while S <> Nil do begin
		Rescale( S , SF );
		S := S^.Next;
	end;
	S := Part^.InvCom;
	while S <> Nil do begin
		Rescale( S , SF );
		S := S^.Next;
	end;
end;

initialization
	{ Make sure we have the required data directories. }
{$IFDEF WINDOWS}
    Config_Directory := GetUserDir() + OS_Dir_Separator + 'gharena' + OS_Dir_Separator;
{$ELSE}
    Config_Directory := GetAppConfigDir(False);
{$ENDIF}
	Config_File := Config_Directory + 'gharena.cfg';

	Save_Game_DirName := 'SaveGame';
	Save_Game_Directory := Config_Directory + Save_Game_Dirname + OS_Dir_Separator;

	Save_Character_Base := Save_Game_Directory + 'CHA';
	Save_Unit_Base := Save_Game_Directory + 'GHU';
	Save_Campaign_Base := Save_Game_Directory + 'RPG';

{$IFNDEF go32v2}
	CheckDirectoryPresent;
{$ENDIF}
end.
