unit ghparser;
	{This unit reads a text file and converts it into game}
	{data for GearHead.}
	{ See MDLref.txt for a list of commands. }
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

uses gears;

Const
	SLOT_Next = 0;
	SLOT_Sub  = 1;
	SLOT_Inv  = 2;

var
	Parser_Macros: SAttPtr;

	Archetypes_List: GearPtr;
	WMonList: GearPtr;
	Standard_Equipment_List: GearPtr;
	STC_Item_List: GearPtr;

Procedure SelectCombatEquipment( NPC,EquipList: GearPtr; EPV: LongInt );
Procedure CheckValidity( var it: GearPtr );
Function ReadGear(var F: Text): GearPtr;

Function LoadFile( FName,DName: String ): GearPtr;
Function LoadGearPattern( FName,DName: String ): GearPtr;
Function LoadXRanPlot( FName,DName: String; Enemy,Mystery,BadThing: Integer ): GearPtr;
Function LoadSingleMecha( FName,DName: String ): GearPtr;
Function LoadNewMonster( MonsterName: String ): GearPtr;
Function LoadNewNPC( NPCName: String ): GearPtr;
Function LoadNewSTC( Desig: String ): GearPtr;

implementation

uses dos,ability,gearutil,ghchars,ghmodule,
     ghsupport,interact,locale,rpgdice,texutil;

Const
	Recursion_Level: Integer = 0;

Procedure IndividualizeNPC( NPC: GearPtr );
	{ Randomize up this NPC a bit, to give it that hand-crafted }
	{ NPC look. }
var
	N,T: Integer;
begin
	{ If the NPC doesn't have a body defined, create one. }
	if NPC^.SubCom = Nil then begin
		ExpandCharacter( NPC );
	end;

	{ Give the NPC a random name + gender + age + personality traits. }
	SetSAtt( NPC^.SA , 'NAME <' + RandomName + '>' );
	SetNAtt( NPC^.NA , NAG_CharDescription , NAS_Gender , Random( 2 ) );
	SetNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , 1 + Random( 10 ) - Random( 10 ) + RollStep( 1 ) );

	{ Give out some personality traits. }
	N := Random( 5 ) + 1;
	for t := 1 to N do begin
		{ Positive traits are far more common than negative ones. }
		if Random( 3 ) = 1 then begin
			AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , -RollStep( 8 ) );
		end else begin
			AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , RollStep( 8 ) );
		end;
	end;
	{ The random personality traits may have affected morale. }
	SetNAtt( NPC^.NA , NAG_Condition , NAS_MoraleDamage , 0 );

	{ Randomize up those stats a bit. }
	for t := 1 to NumGearStats do begin
		NPC^.Stat[T] := NPC^.Stat[T] + Random( 4 ) - Random( 4 );
		if NPC^.Stat[T] < 1 then NPC^.Stat[T] := 1;
	end;

	{ Make sure the body parts match the Body stat }
	ResizeCharacter( NPC );
end;

Procedure SelectCombatEquipment( NPC,EquipList: GearPtr; EPV: LongInt );
	{ Search through the standard equipment list and find some }
	{ combat gear to equip this NPC with. }
	Function BuyWeapon: GearPtr;
		{ Search through the list of equipment provided. Select }
		{ a weapon for this character. }
	var
		Wep: GEarPtr;
		N: Integer;
		SL,Item: SAttPtr;	{ Shopping List. }
	begin
		{ Step One - Create a list of all weapons that this character }
		{ can afford, based upon EPV. }
		SL := Nil;
		Wep := EquipList;
		N := 1;
		while Wep <> Nil do begin
			{ If this item is a weapon and affordable, add it to the list. }
			if ( Wep^.G = GG_Weapon ) and ( GearValue( Wep ) <= EPV ) then begin
				StoreSAtt( SL , BStr( N ) );
			end;

			{ Move to the next item. }
			Inc( N );
			Wep := Wep^.Next;
		end;
		if SL = Nil then Exit( Nil );

		{ Step Two - Select one of those weapons at random. }
		Item := SelectRandomSAtt( SL );
		N := ExtractValue( Item^.Info );

		{ Step Three - Clone the desired weapon, reduce EPV, and }
		{ get rid of the shopping list. }
		Wep := CloneGear( RetrieveGearSib( EquipList , N ) );
		EPV := EPV - GearValue( Wep );
		DisposeSAtt( SL );
		BuyWeapon := Wep;
	end;
	Function BuyArmor( BP: Integer ): GearPtr;
		{ Search through the list of equipment provided. Select }
		{ some armor for the requested hit location. }
	var
		Armor: GEarPtr;
		N: Integer;
		SL,Item: SAttPtr;	{ Shopping List. }
	begin
		{ Step One - Create a list of all armor that this character }
		{ can afford, based upon EPV. }
		SL := Nil;
		Armor := EquipList;
		N := 1;
		while Armor <> Nil do begin
			{ If this item is a weapon and affordable, add it to the list. }
			if ( Armor^.G = GG_ExArmor ) and ( Armor^.S = BP ) and ( GearValue( Armor ) <= EPV ) then begin
				StoreSAtt( SL , BStr( N ) );
			end;

			{ Move to the next item. }
			Inc( N );
			Armor := Armor^.Next;
		end;
		if SL = Nil then Exit( Nil );

		{ Step Two - Select one of those items at random. }
		Item := SelectRandomSAtt( SL );
		N := ExtractValue( Item^.Info );

		{ Step Three - Clone the desired armor, reduce EPV, and }
		{ get rid of the shopping list. }
		Armor := CloneGear( RetrieveGearSib( EquipList , N ) );
		EPV := EPV - GearValue( Armor );
		DisposeSAtt( SL );
		BuyArmor := Armor;
	end;

var
	Slot: GearPtr; { Place to stick current equipment. }
	Part,UEPart: GearPtr; { Part to equip, part that's been unequipped. }
begin
	{ First, stick a weapon in the right hand. }
	Slot := SeekGearByName( NPC^.SubCOm , SATtValue( ABILITY_MESSAGES , 'EXPAND_RightHand' ) );
	if Slot <> Nil then begin
		Part := BuyWeapon;
		UEPart := EquipGear( Slot , Part );
		if UEPart <> Nil then InsertInvCom( NPC , UEPart );
	end;

	{ Move through all the NPC's modules, possibly adding armor to each. }
	Slot := NPC^.SubCOm;
	while Slot <> Nil do begin
		if ( Slot^.G = GG_Module ) and ( EPV > Random( 100 ) ) and ( Random( 3 ) <> 1 ) then begin
			Part := BuyArmor( Slot^.S );
			UEPart := EquipGear( Slot , Part );
			if UEPart <> Nil then InsertInvCom( NPC , UEPart );
		end;

		{ Move to the next module. }
		Slot := Slot^.Next;
	end;

	{ If there's any monel left over, stick a weapon in }
	{ the left hand as well. }
	Slot := SeekGearByName( NPC^.SubCOm , SATtValue( ABILITY_MESSAGES , 'EXPAND_LeftHand' ) );
	if ( Slot <> Nil ) and ( EPV > Random( 100 ) ) then begin
		Part := BuyWeapon;
		UEPart := EquipGear( Slot , Part );
		if UEPart <> Nil then InsertInvCom( NPC , UEPart );
	end;

	{ Store remaining money. }
	if EPV > 0 then AddNAtt( NPC^.NA , NAG_Experience , NAS_Credits , EPV );
end;

Procedure ComponentScan( it: GearPtr );
	{ This procedure will check each individual component of a mek }
	{ to make sure it is legal. }
begin
	{Loop through all the components.}
	while it <> Nil do begin
		{Perform specific checks here.}
		CheckGearRange( it );

		if it^.SubCom <> Nil then ComponentScan(it^.SubCom);
		if it^.InvCom <> Nil then ComponentScan(it^.InvCom);
		it := it^.Next;
	end;
end;

Procedure CheckMechaMetrics(it: GearPtr);
	{ Examine the components of this mecha to make sure it has everything }
	{ it needs. }
	{ - Exactly one Cockpit }
	{ - Exactly one Body }
	{ - Exactly one engine in the body; If not present, add one. }
	{ - Exactly one gyroscope in the body; If not present, add one. }
	{ If unrecoverable errors are encountered, mark mek as invalid. }
var
	S,SG: GearPtr;
	Body,CPit: Integer;
	procedure SubComScan( P: GearPtr );
	begin
		while P <> Nil do begin
			if P^.G = GG_Cockpit then Inc( CPit );
			if P^.SubCom <> Nil then SubComScan( P^.SubCom );
			P := P^.Next;
		end;
	end;
begin
	{ Count the number of body modules. }
	{ ASSERT: All level one subcomponents will be modules, and }
	{  if a body module is found it will be of the correct size. }
	{  The range checker, called before this procedure, should have }
	{  dealt with that already. }
	S := it^.SubCom;
	Body := 0;
	while S <> Nil do begin
		if ( S^.G = GG_Module ) and ( S^.S = GS_Body ) then begin
			Inc( Body );
			if Body = 1 then begin
				{ Check for the engine. If no engine, install one. }
				SG := S^.SubCom;
				while ( SG <> Nil ) and (( SG^.G <> GG_Support ) or ( SG^.S <> GS_Engine )) do SG := SG^.Next;
				if SG = Nil then begin
					{ Add an engine here. }
					SG := NewGear( S );
					SG^.G := GG_Support;
					SG^.S := GS_Engine;
					SG^.V := S^.V;
					InitGear( SG );
					InsertSubCom( S , SG );
				end;

				{ Check for the gyro. If no gyro, install one. }
				SG := S^.SubCom;
				while ( SG <> Nil ) and (( SG^.G <> GG_Support ) or ( SG^.S <> GS_Gyro )) do SG := SG^.Next;
				if SG = Nil then begin
					{ Add an engine here. }
					SG := NewGear( S );
					SG^.G := GG_Support;
					SG^.S := GS_Gyro;
					SG^.V := 1;
					InitGear( SG );
					InsertSubCom( S , SG );
				end;
			end;
		end;
		S := S^.Next;
	end;
	if Body <> 1 then begin
		it^.G := GG_AbsolutelyNothing;
	end;

	{ Make sure the mecha has exactly one cockpit. }
	CPit := 0;
	SubComScan( it^.SubCom );
	if CPit <> 1 then begin
		it^.G := GG_AbsolutelyNothing;
	end;
end;

Procedure MetricScan( var head: GearPtr );
	{ Scan all the parts, looking for parts which need some counting done. }
var
	P,P2: GEarPtr;
begin
	P := Head;
	while P <> Nil do begin
		P2 := P^.Next;

		{Perform specific checks here.}
		if P^.G = GG_Mecha then CheckMechaMetrics( P );

		{ After the above checking, this gear might be marked for }
		{ deletion. If so, delete it. }
		if P^.G = GG_AbsolutelyNothing then begin
			RemoveGear( Head , P );
		end else begin
			if P^.SubCom <> Nil then MetricScan(P^.SubCom);
			if P^.InvCom <> Nil then MetricScan(P^.InvCom);
		end;
		P := P2;
	end;

end;

Procedure CheckValidity( var it: GearPtr );
	{Check the gears that have just been loaded and make sure}
	{that they conform to the game rules. To do this, we will}
	{scan through every gear in the list, recursing to this}
	{procedure as necessary.}
begin
	{ Do the individual components check. }
	ComponentScan( it );

	{ Do the metrics check for specific components. }
	MetricScan( it );
end;

Function ReadGear(var F: Text): GearPtr;
	{F is an open file of type F.}
	{Start reading information from the file, stopping}
	{whenever all the info is read.}
	{ Note that the current implementation of this procedure contracts }
	{ out all validity checking to the CheckGearRange procedure }
	{ in gearutil.pp. }
const
	NDum: GearPtr = Nil;
var
	TheLine,cmd: String;
	it,C: GearPtr;	{IT is the total list which is returned.}
			{C is the current GEAR being worked on.}
	dest: Byte;	{DESTination of the next GEAR to be added.}
			{ 0 = Sibling; 1 = SubCom; 2 = InvCom }

{*** LOCAL PROCEDURES FOR GHPARSER ***}

Procedure InstallGear(IG_G,IG_S,IG_V: Integer);
	{Install a GEAR of the specified type in the currently}
	{selected installation location. }
begin
	{Determine where the GEAR is to be installed, and check to}
	{see if this is a legal place to stick it.}

	{Do the installing}
	{if C = Nil, we're installing as a sibling at the root level.}
	{ASSERT: If IT = Nil, then C = Nil as well.}
	if (dest = 0) or (C = Nil) then begin
		{NEXT COMPONENT}
		if C = Nil then C := AddGear(it,NDum)
		else C := AddGear(C,C^.Parent);

	end else if dest = 1 then begin
		{SUB COMPONENT}
		C := AddGear(C^.SubCom,C);
		dest := SLOT_Next;
	end else if dest = 2 then begin
		{INV COMPONENT}
		C := AddGear(C^.InvCom,C);
		dest := SLOT_Next;
	end;

	C^.G := IG_G;
	C^.S := IG_S;
	C^.V := IG_V;
	InitGear(C);
end;

Procedure AssignStat( AS_Slot, AS_Val: Integer );
	{ Set stat SLOT of the current gear to value VAL. }
	{ Do nothing if there's some reason why this is impossible. }
begin
	{ Can only assign a stat if the current gear is defined. }
	if C <> Nil then begin
		{ Make sure NUM is in the allowable range. }
		if ( AS_Slot >= 1 ) and ( AS_Slot <= NumGearStats ) then begin
			C^.Stat[ AS_Slot ] := AS_Val;
		end;
	end;
end;

Procedure AssignNAtt( ANA_G, ANA_S, ANA_V: LongInt );
	{ Store the described numeric attribute in the current gear. }
	{ Do nothing if there's some reason why this is impossible. }
begin
	{ Can only store info if the current gear is defined. }
	if C <> Nil then begin
		SetNAtt( C^.NA , ANA_G , ANA_S , ANA_V );
	end;
end;

Procedure CheckMacros( CM_CMD: String );
	{ This command wasn't found in the list of basic commands. }
	{ Maybe it's part of the macro file? Check and see. }
	Function GetMacroValue( var GMV_FX: String ): LongInt;
		{ Extract a value from the macro string, or read it }
		{ from the current line. }
	var
		GMV_MacDat,GMV_LineDat: String;
	begin
		{ First, read the data definition. }
		GMV_MacDat := ExtractWord( GMV_FX );

		{ If the first character is a ?, this means that we should }
		{ read the value from the regular line. }
		if ( GMV_MacDat <> '' ) and ( GMV_MacDat[1] = '?' ) then begin
			{ If the data is found, return it. }
			{ Otherwise return the macro default value. }
			GMV_LineDat := ExtractWord( TheLine );
			if GMV_LineDat <> '' then begin
				GetMacroValue := ExtractValue( GMV_LineDat );
			end else begin
				DeleteFirstChar( GMV_MacDat );
				GetMacroValue := ExtractValue( GMV_MacDat );
			end;
		end else begin
			GetMacroValue := ExtractValue( GMV_MacDat );
		end;
	end;
var
	CM_FX: String;
	CM_A, CM_B, CM_C: LongInt;
begin
	CM_FX := SAttValue( Parser_Macros , CM_CMD );

	{ If a macro matching this command was found, process it. }
	if CM_FX <> '' then begin
		CM_CMD := UpCase( ExtractWord( CM_FX ) );

		if CM_CMD[1] = 'G' then begin
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			CM_C := GetMacroValue( CM_FX );
			InstallGear( CM_A , CM_B , CM_C );

		end else if CM_CMD[1] = 'S' then begin
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			AssignStat( CM_A , CM_B );

		end else if CM_CMD[1] = 'N' then begin
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			CM_C := GetMacroValue( CM_FX );
			AssignNAtt( CM_A , CM_B , CM_C );

		end;
	end;
end;

Procedure CMD_Mod;
	{ syntax -> MOD (module type) }
var
	CM_Code: Integer;
begin
	{Move back to the Master module, set destination to Sub.}
	while (C<>Nil) and not IsMasterGear(C) do C := C^.Parent;
	if C <> Nil then dest := SLOT_Sub
	else dest := SLOT_Next;

	{Determine what kind of a module is to be installed.}
	CM_Code := LookupModuleCode(ExtractWord(TheLine));
	if CM_Code = -1 then begin
		{The requested module type cannot be found.}
		{Replace it with a Storage module.}
		CM_Code := 8;
	end;

	InstallGear(GG_Module,CM_Code,MasterSize(C));
	dest := SLOT_Next;
end;

Procedure CMD_Sub;
	{Set the destination to SUBCOMPONENT}
begin
	dest := SLOT_Sub;
end;

Procedure CMD_Inv;
	{Set the destination to INVCOMPONENT}
begin
	dest := SLOT_Inv;
end;

Procedure CMD_End;
	{Finish off a range of subcomponents.}
	{If Dest = 0, move to the parent gear.}
	{If Dest <> 0, set Dest to 0.}
begin
	if (dest = 0) and (C <> Nil) then C := C^.Parent
	else dest := 0;
end;


Procedure CMD_Size;
	{Set the V field of the current module to the supplied value.}
var
	CS_Size: Integer;
begin
	CS_Size := ExtractValue(TheLine);

	if C <> Nil then C^.V := CS_Size;
end;

Procedure CMD_Arch;
	{Create a new archetypal character gear.}
	{ The rest of this line is the name of the new archetype. }
begin
	InstallGear(GG_Character,0,0);
	DeleteWhiteSpace( TheLine );
	SetSAtt( C^.SA , 'Name <' + TheLine + '>' );
	TheLine := '';
end;

Procedure CMD_StatLine;
	{ Read all the stats for this gear from a single line. }
var
	CSL_N,CSL_V: Integer;
begin
	{ Error Check! }
	if C = Nil then Exit;

	CSL_N := 1;
	while ( TheLine <> '' ) and ( CSL_N <= NumGearStats ) do begin
		CSL_V := ExtractValue( TheLine );
		C^.Stat[CSL_N] := CSL_V;
		Inc( CSL_N );
	end;
end;

Procedure CMD_Room;
	{ Define a room gear. }
begin
	{ Install the new room. }
	InstallGear( GG_MapFeature , GS_Building , 0 );

	{ Randomize up the dimensions a little bit. }
	C^.Stat[ STAT_MFWidth ] := ExtractValue( TheLine );
	C^.Stat[ STAT_MFWidth ] := C^.Stat[ STAT_MFWidth ] + Random( 2 ) - Random( 2 );
	if C^.Stat[ STAT_MFWidth ] < MapFeatureMinDimension then C^.Stat[ STAT_MFWidth ] := MapFeatureMinDimension
	else if C^.Stat[ STAT_MFWidth ] > MapFeatureMaxWidth then C^.Stat[ STAT_MFWidth ] := MapFeatureMaxWidth;

	C^.Stat[ STAT_MFHeight ] := ExtractValue( TheLine );
	C^.Stat[ STAT_MFHeight ] := C^.Stat[ STAT_MFHeight ] + Random( 2 ) - Random( 2 );
	if C^.Stat[ STAT_MFHeight ] < MapFeatureMinDimension then C^.Stat[ STAT_MFHeight ] := MapFeatureMinDimension
	else if C^.Stat[ STAT_MFHeight ] > MapFeatureMaxHeight then C^.Stat[ STAT_MFHeight ] := MapFeatureMaxHeight;
end;


Procedure CMD_SetAlly;
	{ Read this team's allies from the line. }
var
	CSA_AllyID: Integer;
begin
	if ( C = Nil ) then Exit;

	while ( TheLine <> '' ) do begin
		CSA_AllyID := ExtractValue( TheLine );
		if C^.G = GG_Faction then begin
			SetNAtt( C^.NA , NAG_FactionScore , CSA_AllyID , 10 );
		end else begin
			SetNAtt( C^.NA , NAG_SideReaction , CSA_AllyID , NAV_AreAllies );
		end;
	end;
end;

Procedure CMD_SetEnemy;
	{ Read this team's enemies from the line. }
var
	CSE_EnemyID: Integer;
begin
	if ( C = Nil ) then Exit;

	while ( TheLine <> '' ) do begin
		CSE_EnemyID := ExtractValue( TheLine );
		if C^.G = GG_Faction then begin
			AddNAtt( C^.NA , NAG_FactionScore , CSE_EnemyID , -10 );
		end else begin
			SetNAtt( C^.NA , NAG_SideReaction , CSE_EnemyID , NAV_AreEnemies );
		end;
	end;
end;

Procedure META_InsertPartIntoIt( IPII_Part: GEarPtr );
	{ Insert a part into the current gear-being-loaded by the }
	{ method specified in the dest variable. Afterwards, set C }
	{ to equal this new part. }
begin
	if IPII_Part <> Nil then begin
		{ Stick the part somewhere appropriate. }
		if (dest = 0) or (C = Nil) then begin
			{NEXT COMPONENT}
			{ If there is no currently defined C component, }
			{ stick the NPC as the next component at root level. }
			if C = Nil then LastGear( it )^.Next := IPII_Part
			else begin
				LastGear( C )^.Next := IPII_Part;
				IPII_Part^.Parent := C^.Parent;
			end;
		end else if dest = 1 then begin
			{SUB COMPONENT}
			InsertSubCom( C , IPII_Part );
		end else if dest = 2 then begin
			{INV COMPONENT}
			InsertInvCom( C , IPII_Part );
		end;
		dest := SLOT_Next;

		{ Set the current gear to the item's base record. }
		{ Any further modifications will be done there. }
		C := IPII_Part;
	end;
end;

Procedure CMD_NPC;
	{ Search for & then duplicate one of the standard character }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	NPC: GearPtr;
begin
	{ NPC cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the NPC record first. }
	{ Exit the procedure if no appropriate NPC can be found. }
	DeleteWhiteSpace( TheLine );
	NPC := LoadNewNPC( TheLine );
	if NPC = Nil then begin
		Exit;
	end;

	{ Store a JOB description. This will be the archetype name. }
	SetSATt( NPC^.SA , 'JOB <' + TheLine + '>' );

	{ Get rid of the NPC name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the NPC somewhere appropriate. }
	META_InsertPartIntoIt( NPC );
end;

Procedure CMD_Monster;
	{ Search for & then duplicate one of the standard monster }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	Mon: GearPtr;
begin
	{ Monster cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the Monster record first. }
	{ Exit the procedure if no appropriate NPC can be found. }
	DeleteWhiteSpace( TheLine );
	Mon := LoadNewMonster( TheLine );
	if Mon = Nil then begin
		Exit;
	end;

	{ Get rid of the NPC name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the monster somewhere appropriate. }
	META_InsertPartIntoIt( Mon );
end;

Procedure CMD_STC;
	{ Search for & then duplicate one of the standard item }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	STC_Part: GearPtr;
begin
	{ Item cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the item record first. }
	{ Exit the procedure if no appropriate item can be found. }
	DeleteWhiteSpace( TheLine );
	STC_Part := LoadNewSTC( TheLine );
	if STC_Part = Nil then begin
		Exit;
	end;

	{ Get rid of the item name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the item somewhere appropriate. }
	META_InsertPartIntoIt( STC_Part );
end;

Procedure CMD_Scale;
	{ Sets the scale field for the current gear. }
var
	CS_Scale: Integer;
begin
	{ Error check- if there is no current gear, exit this procedure. }
	if ( C = Nil ) then Exit;

	{ Determine what scale to set the current gear to. }
	CS_Scale := ExtractValue( TheLine );

	C^.Scale := CS_Scale;
end;

Procedure CMD_EquipChar;
	{ This procedure should equip a recently created NPC. }
begin
	{ Error check- we must be dealing with an NPC here. }
	if ( C = Nil ) or ( C^.G <> GG_Character ) then exit;

	SelectCOmbatEquipment( C , Standard_Equipment_List , ExtractValue( TheLine ) );
end;

Procedure CMD_CharDesc;
	{ This procedure allows certain aspects of a character gear to be }
	{ modified. }
var
	CCD_Cmd: String;	{ Command extracted from line. }
	t: Integer;
begin
	{ Error check! This command only works for characters. }
	if ( C = Nil ) or ( C^.G <> GG_Character ) then Exit;

	while TheLine <> '' do begin
		CCD_Cmd := ExtractWord( TheLine );

		{ Check to see if this is a gender command. }
		for t := 0 to 1 do begin
			if CCD_Cmd = UpCase( GenderName[ T ] ) then begin
				SetNAtt( C^.NA , NAG_CharDescription , NAS_Gender , T );
			end;
		end;

		{ If not, check to see if it's a personality command. }
		for t := 1 to Num_Personality_Traits do begin
			if CCD_Cmd = UpCase( PTraitName[ T , 1 ] ) then begin
				if NAttValue( C^.NA , NAG_CharDescription , -T ) < 25 then begin
					SetNAtt( C^.NA , NAG_CharDescription , -T , 25 );
				end else begin
					AddNAtt( C^.NA , NAG_CharDescription , -T , 10 );
				end;
			end else if CCD_Cmd = UpCase( PTraitName[ T , 2 ] ) then begin
				if NAttValue( C^.NA , NAG_CharDescription , -T ) > -25 then begin
					SetNAtt( C^.NA , NAG_CharDescription , -T , -25 );
				end else begin
					AddNAtt( C^.NA , NAG_CharDescription , -T , -10 );
				end;
			end;
		end;

		{ If not, check to see if it's an age command. }
		if CCD_Cmd = 'YOUNG' then begin
			{ Set the character's age to something below 20. }
			while NAttValue( C^.NA , NAG_CharDescription , NAS_DAge ) >= 0 do begin
				AddNAtt( C^.NA , NAG_CharDescription , NAS_DAge , -( Random( 6 ) + 1 ) );
			end;
		end else if CCD_Cmd = 'OLD' then begin
			{ Set the character's age to something above 40. }
			while NAttValue( C^.NA , NAG_CharDescription , NAS_DAge ) <= 20 do begin
				AddNAtt( C^.NA , NAG_CharDescription , NAS_DAge , ( Random( 20 ) + 1 ) );
			end;
		end;
	end;
end;

begin
	{ Initialize variables. }
	it := Nil;
	C := Nil;
	dest := SLOT_Next;

	{ Increase the recursion level; the NPC command uses recursion }
	{ and could get stuck in an endless loop. }
	Inc( Recursion_Level );

	while not EoF(F) do begin
		{Read the line from disk, and delete leading whitespace.}
		readln(F,TheLine);
		DeleteWhiteSpace(TheLine);

		if ( TheLine = '' ) or ( TheLine[1] = '%' ) then begin
			{ *** COMMENT *** }
			TheLine := '';

		end else if Pos('<',TheLine) > 0 then begin
			{ *** STRING ATTRIBUTE *** }
			if C <> Nil then SetSAtt(C^.SA,TheLine);

		end else begin
			{ *** COMMAND LINE *** }

			{To make things easier upon us, just set the whole}
			{line to uppercase now.}
			TheLine := UpCase(TheLine);

			{Keep processing the line until the end is reached.}
			while TheLine <> '' do begin
				CMD := ExtractWord(TheLine);

				{Branch depending upon what the command is.}
				 	if CMD = 'MOD' then CMD_Mod
				else	if CMD = 'SUB' then CMD_Sub
				else	if CMD = 'INV' then CMD_Inv
				else	if CMD = 'END' then CMD_End
				else	if CMD = 'SIZE' then CMD_Size
				else	if CMD = 'ARCH' then CMD_Arch
				else	if CMD = 'STATLINE' then CMD_StatLine
				else	if CMD = 'ROOM' then CMD_Room
				else	if CMD = 'SETALLY' then CMD_SetAlly
				else	if CMD = 'SETENEMY' then CMD_SetEnemy
				else	if CMD = 'NPC' then CMD_NPC
				else	if CMD = 'SCALE' then CMD_Scale
				else	if CMD = 'CHARDESC' then CMD_CharDesc
				else	if CMD = 'MONSTER' then CMD_Monster
				else	if CMD = 'STC' then CMD_STC
				else	if CMD = 'EQUIPCHAR' then CMD_EquipChar
				else	CheckMacros( CmD );
			end;
		end;
	end;

	{Run a check on each of the Master Gears we have loaded,}
	{making sure that they are both valid and complete. If}
	{there are any errors, remove the offending entries.}
	{ See TheRules.txt for a brief outline of things to be checked. }
	CheckValidity(it);

	{ Decrement the recursion level. }
	Dec( Recursion_Level );

	ReadGear := it;
end;

Function LoadFile( FName,DName: String ): GearPtr;
	{ Open and load a text file. }
var
	F: Text;
	it: GearPtr;
begin
	{ Use FSEARCH to confirm the file name. }
	FName := FSearch( FName , DName );
	it := Nil;
	if FName <> '' then begin
		{ The filename has been found and confirmed. }
		{ Actually load the file. }
		Assign( F , FName );
		Reset( F );
		it := ReadGear( F );
		Close( F );
	end;
	LoadFile := it;
end;

Function LoadGearPattern( FName,DName: String ): GearPtr;
	{ Attempt to load a gear file from disk. Search for }
	{ pattern matches. }
var
	FList: SAttPtr;
	it: GearPtr;
begin
	it := Nil;
	if FName <> '' then begin
		{ Build search list for files that match the source. }
		FList := CreateFileList( DName + FName );

		if FList <> Nil then begin
			FName := SelectRandomSAtt( FList )^.Info;
			DisposeSAtt( FList );

			it := LoadFile( FName , DName );
		end;
	end;

	{ Return the selected & loaded gears. }
	LoadGearPattern := it;
end;

Function LoadXRanPlot( FName,DName: String; Enemy,Mystery,BadThing: Integer ): GearPtr;
	{ Attempt to load a gear file from disk. Search for }
	{ pattern matches. }
const
	num_enemy_types = 2;
	num_mystery_types = 5;
	num_badthing_types = 6;
	enemy_symbol: array [0..num_enemy_types] of char = (
		'U','C','F'
	);
	mystery_symbol: array [0..num_mystery_types] of char = (
		'R','U','F','A','N','I'
	);
	badthing_symbol: array [0..num_badthing_types] of char = (
		'R','U','F','I','S','X','L'
	);
var
	FName2: String;
	FList: SAttPtr;
	it: GearPtr;
	T: Integer;
begin
	it := Nil;

	{ Make sure the three plot descriptors are within legal range. }
	if Enemy > num_enemy_types then Enemy := 0;
	if Mystery > num_Mystery_types then Mystery := 0;
	if BadThing > num_badthing_types then Badthing := 0;

	if FName <> '' then begin
		{ Build search list for files that match the source. }
		FList := Nil;
		for t := 0 to 8 do begin
			{ Construct the search pattern. }
			if ( T mod 2 ) = 1 then begin
				FName2 := ReplaceHash( FName , enemy_symbol[ Enemy ] );
			end else begin
				FName2 := ReplaceHash( FName , '-' );
			end;
			if ( ( T mod 4 ) div 2 ) = 1 then begin
				FName2 := ReplaceHash( FName2 , mystery_symbol[ Mystery ] );
			end else begin
				FName2 := ReplaceHash( FName2 , '-' );
			end;
			if ( T div 4 ) = 1 then begin
				FName2 := ReplaceHash( FName2 , badthing_symbol[ BadThing ] );
			end else begin
				FName2 := ReplaceHash( FName2 , '-' );
			end;
			{ Expand the search with items matching this pattern. }
			ExpandFileList( FList , DName + FName2 );
		end;

		if FList <> Nil then begin
			FName := SelectRandomSAtt( FList )^.Info;
			DisposeSAtt( FList );

			it := LoadFile( FName , DName );
		end;
	end;

	{ Return the selected & loaded gears. }
	LoadXRanPlot := it;
end;

Function LoadSingleMecha( FName,DName: String ): GearPtr;
	{ Load a mecha file. Return a single mecha from that file. }
	{ Return Nil if the mecha could not be loaded. }
var
	MList,Mek: GearPtr;
begin
	{ Use the above procedure to load a mecha from disk. }
	MList := LoadGearPattern( FName , DName );
	Mek := Nil;

	if MList <> Nil then begin
		Mek := CloneGear( SelectRandomGear( MList ) );
		DisposeGear( MList );
	end;

	LoadSingleMecha := Mek;
end;

Function LoadNamedGear( FName,GName: String ): GearPtr;
	{ This function will load a file with the given file name. }
	{ Once that is loaded, it will search for a single gear within }
	{ that file with the given gear name. }
var
	F: Text;
	G,LList: GearPtr;
begin
	{ Open and load the archetypes. }
	Assign( F , FName );
	Reset( F );
	LList := ReadGear( F );
	Close( F );

	{ Locate the desired archetype. }
	G := SeekGearByName( LList , GName );
	if G <> Nil then G := CloneGear( G );

	{ Dispose of the list & return the cloned gear. }
	DisposeGear( LList );
	LoadNamedGear := G;
end;


Function LoadNewMonster( MonsterName: String ): GearPtr;
	{ This function will load the default monster list and }
	{ return a monster of the requested type. }
var
	Mon: GearPtr;
begin
	{ Load monster from disk. }
	if WMonList = Nil then begin
		Mon := LoadNamedGear( Monsters_File , MonsterName );
	end else begin
		Mon := CloneGear( SeekGearByName( WMonList , MonsterName ) );
	end;

	{ If it loaded successfully, set its job to "ANIMAL". }
	if Mon <> Nil then begin
		SetSATt( Mon^.SA , 'JOB <ANIMAL>' );
	end;

	{ Return whatever value was returned. }
	LoadNewMonster := Mon;
end;

Function LoadNewNPC( NPCName: String ): GearPtr;
	{ This function will load the NPC archetypes list and }
	{ return a character of the requested type. }
var
	NPC: GearPtr;
begin
	{ Attempt to load the NPC from the standard archetypes file. }
	if Archetypes_List = Nil then begin
		NPC := LoadNamedGear( Archetypes_File , NPCName );
	end else begin
		NPC := CloneGear( SeekGearByName( Archetypes_List , NPCName ) );
	end;

	{ If the NPC was loaded, set its job name and individualize it. }
	if NPC <> Nil then begin
		{ Store a JOB description. This will be the archetype name. }
		SetSATt( NPC^.SA , 'JOB <' + NPCName + '>' );

		IndividualizeNPC( NPC );
	end;

	{ Return the finished product. }
	LoadNewNPC := NPC;
end;

Function LoadNewSTC( Desig: String ): GearPtr;
	{ This function will load the STC parts list and }
	{ return an item of the requested type. }
var
	Item: GearPtr;
begin
	{ Attempt to load the item from the standard items file. }
	if STC_Item_List = Nil then begin
		Item := LoadNamedGear( STC_Item_File , Desig );
	end else begin
		Item := CloneGear( SeekGearByDesig( STC_Item_List , Desig ) );
	end;

	{ Return the finished product. }
	LoadNewSTC := Item;
end;

Procedure LoadArchetypes;
	{ Load the default, archetypal gears which may be used in the }
	{ construction of other gears. This includes NPC archetypes and }
	{ so forth. }
var
	F: Text;
begin
	{ Open and load the archetypes. }
	Assign( F , Archetypes_File );
	Reset( F );
	Archetypes_List := ReadGear( F );
	Close( F );

	Assign( F , Monsters_File );
	Reset( F );
	WMonList := ReadGear( F );
	Close( F );

	Assign( F , PC_Equipment_File );
	Reset( F );
	Standard_Equipment_List := ReadGear( F );
	Close( F );

	Assign( F , STC_Item_File );
	Reset( F );
	STC_Item_List := ReadGear( F );
	Close( F );

end;

initialization
	Parser_Macros := LoadStringList( Parser_Macro_File );
	LoadArchetypes;

finalization
	DisposeSAtt( Parser_Macros );
	DisposeGear( Archetypes_List );
	DisposeGear( WMonList );
	DisposeGear( Standard_Equipment_List );
	DisposeGear( STC_Item_List );

end.
