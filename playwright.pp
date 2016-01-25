unit playwright;
	{ This unit handles the PLOT type of gear. }
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

	{ G = GG_Plot                            }
	{ S = ID Number (not nessecarily unique) }
	{ Stat[1..8] = Elements (Described by SAtts Element1..Element8) }


Function ElementLocation( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
Function ElementFaction( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
Function ElementName( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): String;

Function SceneDesc( Scene: GearPtr ): String;

Function NumFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
Function FindFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;

Function SearchForScene( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;
Function TeamDescription( Scene,Team: GearPtr ): String;
Procedure ChooseTeam( NPC , Scene: GearPtr );

Function InsertPlot( Adventure,Plot: GearPtr; Debug: Boolean; GB: GameBoardPtr ): Boolean;
Function InsertStory( Slot,Story: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertGlobalArc( Adventure,ARC: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertStoryArc( Story,Arc: GearPtr; GB: GameBoardPtr ): Boolean;
Procedure AdvancePlot( GB: GameBoardPtr; Adv,Plot: GearPtr; N: Integer );

Procedure InsertNPCIntoDynamicScene( NPC,Scene: GearPtr; Team: Integer );
Procedure AddArchEnemyToScene( Adventure,Scene,PC: GearPtr; MDesc: String );
Procedure AddArchAllyToScene( Adventure,Scene,PC: GearPtr );


implementation

{$IFDEF SDLMODE}
uses ability,interact,gearutil,ghchars,ghparser,texutil,rpgdice,sdlgfx;
{$ELSE}
uses ability,interact,gearutil,ghchars,ghparser,texutil,rpgdice,context;
{$ENDIF}
var
	Fast_Seek_Element: Array [1..NumGearStats] of GearPtr;

Function ElementLocation( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
	{ Find the scene number where this element resides. If no such }
	{ scene can be found, return 0. }
var
	E: GearPtr;
	it: Integer;
begin
	E := SeekPlotElement( Adv, Plot, N , GB );

	{ First, call the normal FindGearScene function. }
	it := FindGearScene( E , GB );

	ElementLocation := it;
end;

Function ElementFaction( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
	{ Find the scene number where this element resides. If no such }
	{ scene can be found, return 0. }
var
	E: GearPtr;
begin
	E := SeekPlotElement( Adv, Plot, N , GB );

	ElementFaction := GetFactionID( E );
end;

Function FilterElementDescription( var IDesc: String ): String;
	{ Given this element description, break it up into the }
	{ intrinsic and relative description strings. }
var
	ZeroDesc,cmd,RDesc: String;
begin
	ZeroDesc := IDesc;
	RDesc := '';
	IDesc := '';

	while ZeroDesc <> '' do begin
		cmd := ExtractWord( ZeroDesc );

		if cmd[1] = '!' then begin
			RDesc := RDesc + ' ' + cmd;

			{ If this relative command requires a value, }
			{ copy that over as well. }
			{ The two that don't are !Global and !Lancemate. }
			if ( UpCase( cmd )[2] <> 'G' ) and ( UpCase( cmd )[2] <> 'L' ) then begin
				cmd := ExtractWord( ZeroDesc );
				RDesc := RDesc + ' ' + cmd;
			end;

		end else begin
			IDesc := IDesc + ' ' + cmd;

		end;

	end;

	FilterElementDescription := RDesc;
end;

Function PWAreEnemies( Adv, Part: GearPtr; N: Integer ): Boolean;
	{ Return TRUE if the faction of element N is an enemy of the }
	{ faction of PART. }
var
	Fac: GearPtr;
	F0,F1: Integer;
begin
	F0 := GetFactionID( Fast_Seek_Element[ N ] );
	F1 := GetFactionID( Part );

	{ A faction is never its own enemy. }
	if F0 = F1 then Exit( False );

	Fac := SeekFaction( Adv , F1 );

	if Fac <> Nil then begin
		PWAreEnemies := NAttValue( Fac^.NA , NAG_FactionScore , F0 ) < 0;
	end else begin
		PWAreEnemies := False;
	end;
end;

Function PWAreAllies( Adv, Part: GearPtr; N: Integer ): Boolean;
	{ Return TRUE if the faction of element N is an ally of the }
	{ faction of PART. }
var
	Fac: GearPtr;
	F0,F1: Integer;
begin
	F0 := GetFactionID( Fast_Seek_Element[ N ] );
	F1 := GetFactionID( Part );

	{ A faction is always allied with itself. }
	if F0 = F1 then Exit( True );

	Fac := SeekFaction( Adv , F1 );

	if Fac <> Nil then begin
		PWAreAllies := NAttValue( Fac^.NA , NAG_FactionScore , F0 ) > 0;
	end else begin
		PWAreAllies := False;
	end;
end;

Function PartMatchesRelativeCriteria( Adv,Plot,Part: GearPtr; GB: GameBoardPtr; Desc: String ): Boolean;
	{ Return TRUE if the part matches the relative criteria }
	{ provided, or FALSE if it does not. }
var
	it: Boolean;
	cmd: String;
	Q: Char;
begin
	{ Assume TRUE unless shown otherwise. }
	it := True;

	{ Lancemates can only be selected if they're asked for by the plot. }
	if AStringHasBString( Desc , '!LANCEMATE' ) then it := ( Part^.G = GG_Character ) and ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam )
	else it := ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam );

	{ Check all the bits in the description string. }
	While ( Desc <> '' ) and it do begin
		Cmd := ExtractWord( Desc );
		if Cmd <> '' then begin
			DeleteFirstChar( cmd );
			Q := UpCase( cmd )[ 1 ];

			if ( Q = 'N' ) and ( Plot <> Nil ) then begin
				{ L1 must equal L2. }
				it := it and ( FindGearScene( Part , GB ) = FindGearScene( Fast_Seek_Element[ ExtractValue( Desc ) ] , GB ) );

			end else if ( Q = 'F' ) and ( Plot <> Nil ) then begin
				{ L1 must not equal L2. }
				it := it and ( FindGearScene( Part , GB ) <> FindGearScene( Fast_Seek_Element[ ExtractValue( Desc ) ] , GB ) );

			end else if Q = 'M' then begin
				{ MEMBER. This part must belong to the }
				{ requested faction. }
				it := it and ( GetFactionID( Part ) = ExtractValue( Desc ) );

			end else if ( Q = 'C' ) and ( Plot <> Nil ) then begin
				{ COMRADE. This part must belong to the }
				{ same faction as the requested element. }
				it := it and ( GetFactionID( Fast_Seek_Element[ ExtractValue( Desc ) ] ) = GetFactionID( Part ) );

			end else if ( Q = 'X' ) and ( Plot <> Nil ) then begin
				{ eXclude. This part must not belong to the }
				{ same faction as the requested element. }
				it := it and ( not PWAreAllies( Adv, Part , ExtractValue( Desc ) ) );

			end else if ( Q = 'E' ) and ( Plot <> Nil ) then begin
				{ ENEMY. The faction of the requested }
				{ element must be hated by this part's }
				{ faction. }
				it := it and PWAreEnemies( Adv, Part , ExtractValue( Desc ) );

			end;
		end;
	end;

	{ Return the result. }
	PartMatchesRelativeCriteria := it;
end;

Function NPCMatchesDesc( Adv,Plot,NPC: GearPtr; IDesc,RDesc: String; GB: GameBoardPtr ): Boolean;
	{ Return TRUE if the supplied NPC matches this description }
	{ string, FALSE otherwise. Note that an extra check is performed }
	{ to prevent animals from being chosen for plots, which could }
	{ otherwise happen if the animal in question has a Character ID. }
	{ Thank you Fluffy the Stegosaurus. }
var
	it: Boolean;
begin
	{ DESC should contain a string list of all the stuff we want }
	{ our NPC to have. Things like gender, personality traits, }
	{ et cetera. Most of these things are intrinsic to the NPC, }
	{ but some of them are defined relative to other elements of }
	{ this plot. }

	it := PartMatchesCriteria( XNPCDesc( Adv , NPC ) , IDesc );
	if it then it := PartMatchesRelativeCriteria( Adv, Plot, NPC, GB, RDesc );

	NPCMatchesDesc := it and ( UpCase( SAttValue( NPC^.SA , 'JOB' )) <> 'ANIMAL' );
end;

Function NumFreeNPC( Adv, Plot: GearPtr; Desc: String; GB: GameBoardPtr ): Integer;
	{ This function will count the number of CHARACTER gears }
	{ present in ADVENTURE which have a CID, which match the DESC, }
	{ and which are not currently involved in a plot. }
var
	IDesc,RDesc: String;
	Total: Integer;
	Function CheckAlongPath( P: GearPtr ): Integer;
	var
		CID: LongInt;
		N: Integer;
	begin
		N := 0;
		while P <> Nil do begin
			if ( P^.G = GG_Character ) and NPCMatchesDesc( Adv, Plot, P , IDesc , RDesc , GB ) then begin
				{ Next, check to make sure it has an assigned CID. }
				CID := NAttValue( P^.NA , NAG_Personal , NAS_CID );
				if ( CID <> 0 ) then Inc( N );
			end;
			N := N + CheckAlongPath( P^.SubCom );
			N := N + CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
		CheckAlongPath := N;
	end;
begin
	{ Initialize the total to 0. }
	Adv := FindRoot( Adv );

	{ Filter the relative description from the instrinsic description. }
	IDesc := Desc;
	RDesc := FilterElementDescription( IDesc );

	Total := CheckAlongPath( Adv^.SubCom );

	{ Check the invcomponents of the adventure only if global }
	{ NPCs are allowed by the DESC string. }
	if AStringHasBString( RDesc , '!G' ) then begin
		Total := Total + CheckAlongPath( Adv^.InvCom );
	end;
	if GB <> Nil then begin
		Total := Total + CheckAlongPath( GB^.Meks );
	end;

	{ Return the value. }
	NumFreeNPC := Total;
end;

Function FindFreeNPC( Adventure,Plot: GearPtr; Desc: String; Num: Integer; GB: GameBoardPtr ): GearPtr;
	{ Locate the Nth free NPC in the tree. }
var
	CID,N: Integer;
	RDesc: String;
	TheGearWeWant: GearPtr;
{ PROCEDURES BLOCK. }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( TheGearWeWant = Nil ) do begin
			{ Increment N if this gear matches our description. }
			if ( Part^.G = GG_Character ) and NPCMatchesDesc( Adventure, Plot, Part , Desc , RDesc , GB ) then begin
				{ Next, check to make sure it has an assigned CID. }
				CID := NAttValue( Part^.NA , NAG_Personal , NAS_CID );
				if ( CID <> 0 ) then Inc( N );
			end;

			if N = Num then TheGearWeWant := Part;
			if TheGearWeWant = Nil then CheckAlongPath( Part^.InvCom );
			if TheGearWeWant = Nil then CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	TheGearWeWant := Nil;
	N := 0;

	{ Filter the description into relative and intrinsic bits. }
	RDesc := FilterElementDescription( Desc );

	{ Part 0 is the master gear itself. }
	if Num < 1 then Exit( Adventure );

	{ Check the invcomponents of the adventure only if global }
	{ NPCs are allowed by the DESC string. }
	if AStringHasBString( RDesc , '!G' ) then begin
		CheckAlongPath( Adventure^.InvCom );
	end;
	if TheGearWeWant = Nil then CheckAlongPath( Adventure^.SubCom );
	if TheGearWeWant = Nil then CheckAlongPath( GB^.Meks );

	FindFreeNPC := TheGearWeWant;
end; { FindFreeNPC }

Function CharacterSearch(Adv, Plot: GearPtr; Desc: String; GB: GameBoardPtr ): GearPtr;
	{ Search high and low looking for a character that matches }
	{ the provided search description! }
var
	NPC: GearPtr;
	NumMatches: Integer;
begin
	NumMatches := NumFreeNPC( Adv , Plot , Desc , GB );
	if NumMatches > 0 then begin
		{ Pick one of the free NPCs at random. }
		NPC := FindFreeNPC( Adv , Plot , Desc , Random( NumMatches ) + 1 , GB );
	end else begin
		{ No free NPCs were found. Bummer. }
		NPC := Nil;
	end;
	CharacterSearch := NPC;
end; { Character Search }


Function SceneDesc( Scene: GearPtr ): String;
	{ Create a description string for this scene. }
var
	it: String;
begin
	if ( Scene = Nil ) or ( Scene^.G <> GG_Scene ) then begin
		it := '';
	end else begin
		it := SAttValue( Scene^.SA , 'TYPE' ) + ' SCALE' + BStr( Scene^.V );
	end;
	SceneDesc := it;
end;

Function NumFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many scenes match the provided description. }
var
	Scene: GearPtr;
	RDesc: String;
	N: Integer;
begin
	Scene := Adventure^.SubCom;
	N := 0;
	RDesc := FilterElementDescription( Desc );

	while Scene <> Nil do begin
		if ( Scene^.G = GG_Scene ) and PartMatchesCriteria( SceneDesc( Scene ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Scene, GB, RDesc ) then Inc( N );
		Scene := Scene^.Next;
	end;

	NumFreeScene := N;
end;

Function FindFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;
	{ Find the NUM'th scene that matches the provided description. }
var
	Scene,S2: GearPtr;
	RDesc: String;
begin
	Scene := Adventure^.SubCom;
	S2 := Nil;
	RDesc := FilterElementDescription( Desc );

	while Scene <> Nil do begin
		if ( Scene^.G = GG_Scene ) and PartMatchesCriteria( SceneDesc( Scene ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Scene, GB, RDesc ) then begin
			Dec( Num );
			if Num = 0 then S2 := Scene;
		end;
		Scene := Scene^.Next;
	end;

	FindFreeScene := S2;
end;

Function SearchForScene( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;
	{ Try to find a scene matching the description. }
var
	NumElements: Integer;
begin
	NumElements := NumFreeScene( Adventure , Plot , GB , Desc );
	if NumElements > 0 then begin
		{ Pick one of the free scenes at random. }
		SearchForScene := FindFreeScene( Adventure , Plot , GB , Desc , Random( NumElements ) + 1 );
	end else begin
		SearchForScene := Nil;
	end;
end;

function FactionDesc( Fac: GearPtr ): String;
	{ Return a description of the provided faction. }
var
	it: String;
begin
	{ Basic description is the faction's TYPE string attribute. }
	it := SATtValue( Fac^.SA , 'TYPE' );

	FactionDesc := it;
end;

Function NumFreeFaction( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many factions match the provided description. }
var
	Fac: GearPtr;
	N: Integer;
	RDesc: String;
begin
	Fac := Adventure^.InvCom;
	N := 0;
	RDesc := FilterElementDescription( Desc );

	while Fac <> Nil do begin
		if ( Fac^.G = GG_Faction ) and PartMatchesCriteria( FactionDesc( Fac ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Fac, GB, RDesc ) then Inc( N );
		Fac := Fac^.Next;
	end;

	NumFreeFaction := N;
end;

Function FindFreeFaction( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;
	{ Find the NUM'th scene that matches the provided description. }
var
	Fac,F2: GearPtr;
	RDesc: String;
begin
	Fac := Adventure^.InvCom;
	F2 := Nil;
	RDesc := FilterElementDescription( Desc );

	while Fac <> Nil do begin
		if ( Fac^.G = GG_Faction ) and PartMatchesCriteria( FactionDesc( Fac ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Fac, GB, RDesc ) then begin
			Dec( Num );
			if Num = 0 then F2 := Fac;
		end;
		Fac := Fac^.Next;
	end;

	FindFreeFaction := F2;
end;


Function TeamDescription( Scene,Team: GearPtr ): String;
	{ Create a description for this team. This is to be used }
	{ by the team location routines. }
var
	it: String;
begin
	{ Start with an empty string. }
	it := '';

	if Team <> Nil then begin
		if AreEnemies( Scene, Team^.S , NAV_DefPlayerTeam ) then begin
			it := it + ' enemy';
		end else if AreAllies( Scene , Team^.S , NAV_DefPlayerTeam ) then begin
			it := it + ' ally';
		end;

		it := it + ' ' + AI_Type_Label[ Team^.Stat[ STAT_TeamOrders ] ];

		if Team^.Stat[ STAT_WanderMon ] > 0 then it := it + ' wmon';
	end;

	TeamDescription := it;
end;

Function CreateTeam( Scene: GearPtr; TDesc: String ): GearPtr;
	{ Make a new team corresponding to the description provided. }
var
	Team: GearPtr;
	CMD: String;
	T: Integer;
begin
	Team := NewGear( Nil );
	Team^.G := GG_Team;
	Team^.S := NewTeamID( Scene );
	InsertSubCom( Scene , Team );

	{ Set the new team's attributes based upon the remainder of }
	{ the PLACE string. }
	TDesc := UpCase( TDesc );
	while TDesc <> '' do begin
		cmd := ExtractWord( TDesc );

		if cmd = 'ENEMY' then begin
			SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreEnemies );
		end else if cmd = 'ALLY' then begin
			SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreAllies );

		end else begin
			{ This command may be an AIType. }
			for t := 0 to NumAITypes do begin
				if cmd = AI_Type_Label[ t ] then Team^.Stat[ STAT_TeamOrders ] := t;
			end;
		end;
	end;

	CreateTeam := Team;
end;

Function FindMatchingTeam( Scene: GearPtr; TDesc: String ): GearPtr;
	{ Locate a team which matches the provided description. }
	{ If no such team can be found, return Nil. If more than }
	{ one team is found, return one of them, although there's }
	{ no guarantee which one. }
var
	T,it: GearPtr;
begin
	{ Teams are located as root subcomponents of the scene, }
	{ so look there. }
	T := Scene^.SubCom;

	{ Initialize our search bit to NIL. }
	it := Nil;

	while ( T <> Nil ) and ( it = Nil ) do begin
		if ( T^.G = GG_Team ) and ( T^.S <> NAV_DefPlayerTeam ) and PartMatchesCriteria( TeamDescription( Scene , T ) , TDesc ) then begin
			it := T;
		end;

		T := T^.Next;
	end;

	FindMatchingTeam := it;
end;

Procedure ChooseTeam( NPC , Scene: GearPtr );
	{ Find a team which matches the NPC's needs. }
var
	TeamData: String;
	Team: GearPtr;
begin
	TeamData := SAttValue( NPC^.SA , 'TEAMDATA' );
	Team := FindMatchingTeam( Scene , TeamData );

	{ If no matching team was found, create a new team. }
	if Team = Nil then begin
		Team := CreateTeam( Scene , TeamData );
	end;

	{ Store the correct team number in the NPC. }
	SetNAtt( NPC^.NA , NAG_Location , NAS_Team , Team^.S );
end;

Procedure DelinkNPCForEncounter( NPC: GearPtr );
	{ Delink the provided NPC from its current location. }
	{ BUGS: This procedure won't work if the NPC is on the game board. }
	{ It's really only used by the AddEnemyToScene and AddAllyToScene }
	{ procedures below; a very similar procedure can be found in the }
	{ ProcessSetSceneFaction procedure in ArenaScript. I should probably }
	{ combine the two into a single procedure some day... }
var
	Scene: GearPtr;
begin
	{ If the NPC is currently local, add information so that it }	
	{ will be able to return home. }
	Scene := NPC^.Parent;
	while ( Scene <> Nil ) and ( Scene^.G <> GG_Scene ) do Scene := Scene^.Parent;
	if Scene <> Nil then begin
		SetNAtt( NPC^.NA , NAG_ParaLocation , NAS_OriginalHome , Scene^.S );
		SetSATt( NPC^.SA , 'TEAMDATA <' + TeamDescription( Scene, LocateTeam( Scene , NAttValue( NPC^.NA , NAG_Location , NAS_Team ) ) ) + '>' );
	end else begin
		SetNAtt( NPC^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
	end;

	{ Get rid of the NPC's location info. }
	StripNAtt( NPC , NAG_Location );

	if IsSubCom( NPC ) then DelinkGear( NPC^.Parent^.Subcom , NPC )
	else if IsInvCom( NPC ) then DelinkGear( NPC^.Parent^.Invcom , NPC );
end;


Function DeploySceneElement( GB: GameBoardPtr; Adventure,Plot: GearPtr; N: Integer ): GearPtr;
	{ Deploy the next element, give it a unique ID number if }
	{ appropriate, then return a pointer to the it. }
var
	E,Dest: GearPtr;	{ Element & Destination. }
	D: Integer;
	Place: String;
	ID: LongInt;
begin
	{ Find the first uninitialized entry in the list. }
	{ This is gonna be our next element. }
	E := Plot^.InvCom;
	While ( E <> Nil ) and ( SAttValue( E^.SA , 'ELEMENT' ) <> '' ) do begin
		E := E^.Next;
	end;

	if E <> Nil then begin
		{ Give our new element a unique ID, and store its ID in the Plot. }
		{ Characters get CIDs, everything else gets NIDs. }
		if E^.G = GG_Character then begin
			ID := NewCID( GB , Adventure );
			SetNAtt( E^.NA , NAG_Personal , NAS_CID , ID );
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <C Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <C Prefab>' );
		end else begin
			ID := NewNID( GB , Adventure );
			SetNAtt( E^.NA , NAG_Narrative , NAS_NID , ID );
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <I Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <I Prefab>' );
		end;
		Plot^.Stat[ N ] := ID;


		{ Find out if we have to put this element somewhere else. }
		Place := SAttValue( E^.SA , 'PLACE' );

		{ If we have to put it somewhere, do so now. }
		{ Otherwise leave it where it is. }
		if Place <> '' then begin
			{ Delink the element from the plot. }
			DelinkGear( Plot^.InvCom , E );

			{ Determine its target location. }
			D := ExtractValue( Place );
			if ( D >= 1 ) and ( D < N ) then begin
				Dest := SeekPlotElement( Adventure , Plot , D , Nil );

				if Dest = Nil then begin
					{ An invalid location was specified... }
					DisposeGear( E );

				end else if ( Dest^.G <> GG_Scene ) and IsLegalSlot( Dest , E ) then begin
					{ If E can be an InvCom of Dest, stick it there. }
					InsertInvCom( Dest , E );

				end else begin
					{ If Dest isn't a scene, find the scene DEST is in itself }
					{ and stick E in there. }
					while ( Dest <> Nil ) and ( Dest^.G <> GG_Scene ) do Dest := Dest^.Parent;

					if Dest <> Nil then begin
						InsertInvCom( Dest , E );

						{ If E is a character, this brings us to the next problem: }
						{ we need to assign a TEAM for E to be a member of. }
						if E^.G = GG_Character then begin
							SetSAtt( E^.SA , 'TEAMDATA <' + Place + '>' );
							ChooseTeam( E , Dest );
						end;

					end else begin
						{ Couldn't find a SCENE gear. Get rid of E. }
						DisposeGear( E );
					end;
				end;
			end;
		end; 

	end;
	DeploySceneElement := E;
end;

Function FindElement( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ; Debug: Boolean ): Boolean;
	{ Locate and store the Nth element for this plot. }
	{ Return TRUE if a suitable element could be found, or FALSE }
	{ if no suitable element exists in the adventure & this plot }
	{ will have to be abandoned. }
var
	Element: GearPtr;
	Desc,EKind: String;
	OK: Boolean;
	NumElements: Integer;
begin
	{ Error check }
	if ( N < 1 ) or ( N > NumGearStats ) then Exit( False );

	{ Find the description for this element. }
	desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );
	DeleteWhiteSpace( Desc );

	{ Initialize OK to TRUE. }
	OK := True;

	if desc <> '' then begin
		EKind := ExtractWord( Desc );

		if EKind[1] = 'C' then begin
			{ This element is a CHARACTER. Find one. }

			{ IMPORTANT!!!: Character being sought muct not have a plot already!!! }
			if ( Plot <> Nil ) and ( Plot^.G = GG_Plot ) then desc := 'NOPLOT ' + desc;

			Element := CharacterSearch( Adventure , Plot , Desc , GB );

			if Element <> Nil then begin
				{ Store the NPC's ID in the plot. }
				Plot^.Stat[ N ] := NAttValue( Element^.NA , NAG_Personal , NAS_CID );
				Fast_Seek_Element[ N ] := Element;

			end else begin
				{ No free NPCs were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'S' then begin
			{ This element is a SCENE. Find one. }
			{ Pick one of the free scenes at random. }
			Element := SearchForScene( Adventure , Plot , GB , Desc );

			if Element <> Nil then begin
				{ Store the Scene ID in the plot. }
				Plot^.Stat[ N ] := Element^.S;
				Fast_Seek_Element[ N ] := Element;

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'F' then begin
			{ Faction element. }
			NumElements := NumFreeFaction( Adventure , Plot , GB , Desc );
			if NumElements > 0 then begin
				{ Pick one of the free scenes at random. }
				Element := FindFreeFaction( Adventure , Plot , GB , Desc , Random( NumElements ) + 1 );
				Fast_Seek_Element[ N ] := Element;

				{ Store the Scene ID in the plot. }
				Plot^.Stat[ N ] := Element^.S;

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'P' then begin
			{ PreFab element. Check Plot/InvCom and }
			{ retrieve it. }
			Element := DeploySceneElement( GB , Adventure , Plot , N );
			Fast_Seek_Element[ N ] := Element;
			OK := Element <> Nil;
		end;		
	end;

	if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
		if not OK then DialogMsg( 'PLOT ERROR: ' + BStr( N ) + ' Element Not Found!' )
		else if desc <> '' then DialogMsg( 'PLOT ELEMENT ' + BStr( N ) + ': ' + BStr( Plot^.Stat[ N ] ) + ' ' + GearName( Element ) );
	end;

	FindElement := OK;
end;

Function ElementName( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): String;
	{ Find the name of element N. Return an empty string if no such }
	{ element can be found. }
var
	Desc: String;
	Part: GearPtr;
begin
	Desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );

	if Desc <> '' then begin
		Part := SeekPlotElement( Adventure, Plot, N , GB );

		if Part <> Nil then begin
			ElementName := GearName( Part );
		end else begin
			ElementName := '***ERROR***';
		end;
	end else begin
		ElementName := '***NOT DEFINED***';
	end;
end;

Procedure FormatRumorString( Adventure,Plot,RBase: GearPtr; GB: GameBoardPtr );
	{ Make sure the rumor strings are properly formatted for this plot. }
	{ RBase is the gear whose rumor we are currently interested in. }
	{ Also, format rumor strings for all sub-components. }
var
	R0,R1,W,C: String;
	S: GearPtr;
	N: Integer;
begin
	{ Locate the rumor string. }
	R0 := SAttValue( RBase^.SA , 'RUMOR' );
	R1 := '';

	{ Go through the rumor string replacing element name commands with }
	{ the actual element names. }
	if R0 <> '' then begin
		while R0 <> '' do begin
			W := ExtractWord( R0 );

			{ If a string begins with !, it's to be replaced. }
			if W[1] = '!' then begin
				DeleteFirstChar( W );
				C := W[1];
				DeleteFirstChar( W );
				N := ExtractValue( C );
				W := ElementName( Adventure , Plot , N , GB ) + W;
			end;

			R1 := R1 + ' ' + W;
		end;

		DeleteWhiteSpace( R1 );
		SetSAtt( RBase^.SA , 'RUMOR <' + R1 + '>' );
	end;

	{ Format the rumors of all sub and inv components. }
	S := RBase^.SubCom;
	while S <> Nil do begin
		FormatRumorString( Adventure , Plot , S , GB );
		S := S^.Next;
	end;

	S := RBase^.InvCom;
	while S <> Nil do begin
		FormatRumorString( Adventure , Plot , S , GB );
		S := S^.Next;
	end;
end;

Procedure InitPlot( Adventure,Plot: GearPtr; GB: GameBoardPtr );
	{ Initialize this plot. }
	{ Currently, this procedure has only one purpose- to format the }
	{ rumor strings. }
	{ GB can be NIL. }
begin
	FormatRumorString( Adventure , Plot , Plot , GB );
end;

Function MatchPlotToAdventure( Slot,Plot: GearPtr; GB: GameBoardPtr; Debug: Boolean ): Boolean;
	{ This PLOT gear is meant to be inserted into this ADVENTURE gear. }
	{ Perform the insertion, select unselected elements, and make sure }
	{ that everything fits. }
	{ This procedure now also works for Stories. }
var
	T: Integer;
	E: STring;
	Adventure,PFE: GearPtr;	{ Prefab Element }
	EverythingOK,OKNow: Boolean;
begin
	{ Error Check }
	if ( Plot = Nil ) or ( Slot = Nil ) then Exit;

	EverythingOK := True;

	{ We need to stick the PLOT into the ADVENTURE to prevent }
	{ the FindElement procedure from choosing the same item for }
	{ multiple elements. }
	InsertInvCom( Slot , Plot );
	Adventure := FindRoot( Slot );

	{ Select Actors }
	{ First clear the FastSeek array. }
	for t := 1 to NumGearStats do Fast_Seek_Element[ t ] := Nil;

	for t := 1 to NumGearStats do begin
		{ If we are inserting an adventure arc instead of a truly }
		{ random plot, several of the elements may already have been }
		{ assigned. The plot is OK if those elements exist & are OK. }
		if ( Plot^.Stat[T] = 0 ) and EverythingOK then begin
			OkNow := FindElement( Adventure , Plot , T , GB , Debug );
		end else if EverythingOK then begin
			Fast_Seek_Element[ T ] := SeekPlotElement( Adventure , Plot , T , GB );
			OkNow := Fast_Seek_Element[ T ] <> Nil;
			if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
				if not OKNow then DialogMsg( 'PLOT ERROR: ' + GearName( Plot ) + BStr( T ) + ' Predefined Element ' + BStr( Plot^.Stat[t] ) + ' Not Found!' )
				else DialogMsg( 'PLOT ELEMENT ' + BStr( T ) + ': ' + ElementName( Adventure , Plot , T , GB ) );
			end;
		end;

		if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
			DialogMsg( BStr( T ) + '=> ' + BStr( Plot^.Stat[ T ] ) );
		end;

		EverythingOK := EverythingOK and OKNow;
	end;

	if EverythingOK then begin
		{ The plot has been successfully installed into the }
		{ adventure. Initialize the stuff... rumor strings }
		{ mostly. }
		InitPlot( Adventure , Plot , GB );

	end else begin
		{ This plot won't fit in this adventure. Dispose of it. }
		{ First get rid of any already-placed prefab elements. }
		for t := 1 to NumGearStats do begin
			E := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if AStringHasBString( E , 'PREFAB' ) then begin
				PFE := SeekPlotElement( Adventure , Plot , T , GB );
				if PFE <> Nil then begin
					if IsSubCom( PFE ) then begin
						RemoveGear( PFE^.Parent^.SubCom , PFE );
					end else if IsInvCom( PFE ) then begin
						RemoveGear( PFE^.Parent^.InvCom , PFE );
					end;
				end; {if PFE <> Nil}
			end;			
		end;

		RemoveGear( Plot^.Parent^.InvCom , Plot );
	end;

	MatchPlotToAdventure := EverythingOK;
end;

Function InsertPlot( Adventure,Plot: GearPtr; Debug: Boolean; GB: GameBoardPtr ): Boolean;
	{ Stick PLOT into ADVENTURE, selecting Actors and Locations }
	{ as required. If everything is found, insert PLOT as an InvCom }
	{ of the Adventure. Otherwise, delete it. }
begin
	InsertPlot := MatchPlotToAdventure( Adventure , Plot , GB , Debug );
end;

Function InsertStory( Slot,Story: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick STORY into SLOT, selecting Actors and Locations }
	{ as required. If everything is found, insert STORY as an InvCom }
	{ of the SLOT. Otherwise, delete it. }
begin
	InsertStory := MatchPlotToAdventure( Slot , Story , GB , False );
end;

Function InsertGlobalArc( Adventure,ARC: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick ARC into ADVENTURE, selecting Actors and Locations }
	{ as required. If everything is found, insert PLOT as an InvCom }
	{ of the Adventure. Otherwise, delete it. }
var
	T,N: Integer;
	E,Plot: GearPtr;
begin
	{ Step One - If there are any characters requested by this plot, }
	{ check to see if they are currently involved in other plots. If so, }
	{ remove those other plots from play. }
	for t := 1 to NumGearStats do begin
		if Arc^.Stat[ T ] <> 0 then begin
			{ Clear the arc's stat for now, to keep it from }
			{ being returned by SeekPlotElement. }
			N := Arc^.Stat[ T ];
			Arc^.Stat[ T ] := 0;

			E := SeekPlotElement( Adventure , Arc , T , GB );
			if ( E <> Nil ) and ( E^.G = GG_Character ) and ( NAttValue( E^.NA , NAG_Personal , NAS_CID ) <> 0 ) then begin
				Plot := FindPersonaPlot( Adventure , NAttValue( E^.NA , NAG_Personal , NAS_CID ) );
				if Plot <> Nil then RemoveGear( Plot^.Parent^.InvCom , Plot );
			end;

			Arc^.Stat[ T ] := N;
		end;
	end;

	{ Step Two - Attempt to insert this plot into the adventure. }
	InsertGlobalArc := MatchPlotToAdventure( Adventure , ARC , GB , False );
end;

Function InsertStoryArc( Story,Arc: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick ARC into Story, selecting Actors and Locations }
	{ as required. If everything is found, insert PLOT as an InvCom }
	{ of the Story. Otherwise, delete it. }
var
	Desc: String;
	T,N: Integer;
	Plot: GearPtr;
	EverythingOK: Boolean;
begin
	EverythingOK := True;

	{ Step One - Copy element info from the parent story as required. }
	{ If there are any characters requested by this plot, }
	{ check to see if they are currently involved in other plots. If so, }
	{ insertion will fail. }
	for t := 1 to NumGearStats do begin
		{ If an element grab is requested, process that now. }
		desc := SAttValue( Arc^.SA , 'ELEMENT' + BStr( T ) );
		if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
			ExtractWord( desc );
			N := ExtractValue( desc );
			desc := SAttValue( Story^.SA , 'ELEMENT' + BStr( N ) );
			{ Only copy over the first character of the element description, }
			{ since that's all we need, and also because copying a PREFAB tag }
			{ may result in story elements being unnessecarily deleted. }
			SetSAtt( Arc^.SA , 'ELEMENT' + BStr( T ) + ' <' + desc[1] + '>' );
			Arc^.Stat[ T ] := Story^.Stat[ N ];
		end;

		{ If this gear is a character, better see whether or not }
		{ it is already involved in a plot. }
		if ( Arc^.Stat[ T ] <> 0 ) and ( UpCase( Desc[1] ) = 'C' ) then begin
			{ Clear the arc's stat for now, to keep it from }
			{ being returned by SeekPlotElement. }
			N := Arc^.Stat[ T ];
			Arc^.Stat[ T ] := 0;

			Plot := FindPersonaPlot( FindRoot( Story ) , N );
			if Plot <> Nil then begin
				EverythingOK := False;
			end;

			Arc^.Stat[ T ] := N;
		end;
	end;

	{ Step Two - Attempt to insert this plot into the adventure. }
	if EverythingOK then begin
		InsertStoryArc := MatchPlotToAdventure( Story , ARC , GB , False );
	end else begin
		DisposeGear( Arc );
		InsertStoryArc := False;
	end;
end;


Procedure AdvancePlot( GB: GameBoardPtr; Adv,Plot: GearPtr; N: Integer );
	{ This plot is over... but it's possible that we'll be able to }
	{ move to a sub-plot. }
var
	T: Integer;
	SubPlot,P2: GearPtr;
	EName: String;
begin
	{ Find the sub-plot, if one exists. }
	P2 := Plot^.SubCom;
	SubPlot := Nil;
	while ( P2 <> Nil ) do begin
		if ( P2^.G = GG_Plot ) and ( P2^.S = N ) then SubPlot := P2;
		P2 := P2^.Next;
	end;

	if SubPlot <> Nil then begin
		{ Copy over all relevant values, then put the sub-plot }
		{ in its correct place. }
		SubPlot^.V := Plot^.V;
		for t := 1 to NumGearStats do begin
			SubPlot^.Stat[T] := Plot^.Stat[T];
			EName := 'ELEMENT' + BStr( T );
			SetSAtt( SubPlot^.SA , EName + ' <' + SAttValue( Plot^.SA , EName ) + '>' );
		end;
		DelinkGear( Plot^.SubCom , SubPlot );
		InsertInvCom( Adv , SubPlot );
		InitPlot( FindRoot( Adv ) , SubPlot , GB );
	end;

	{ Finally, set the PLOT's type to absolutely nothing, so it will }
	{ be removed. }
	Plot^.G := GG_AbsolutelyNothing;
end;

Procedure SkillCheater( PC , NPC: GearPtr );
	{ This NPC is supposed to be keeping up with the PC... }
	{ So, better train all the appropriate skills. }
const
	Num_Cheating_Skills = 6;
	Skills_To_Cheat: Array [1..Num_Cheating_Skills] of Byte = (
		11, 12, 13, 18, 26, 30
	);
var
	T: Integer;
begin
	if ( PC <> Nil ) and ( NPC <> Nil ) then begin
		{ First, the combat skills get a big push. }
		for t := 1 to 10 do begin
			if SkillValue( PC , T ) > SkillValue( NPC , T ) then begin
				AddNAtt( NPC^.NA , NAG_Skill , T , Random( 3 ) + 1 );
			end;
		end;

		for t := 1 to Num_Cheating_Skills do begin
			if SkillValue( NPC , Skills_To_Cheat[T] ) < RollStep( 2 ) then begin
				AddNAtt( NPC^.NA , NAG_Skill , Skills_To_Cheat[T] , 1 );
			end;
		end;
	end; { Skill Cheating }
end;

Procedure InsertNPCIntoDynamicScene( NPC,Scene: GearPtr; Team: Integer );
	{ The (already delinked) NPC will be inserted into the dynamic scene. }
	{ Note that this procedure can be called for items as well as }
	{ NPCs... it's just that NPCs were the intended usage. }
	{ IMPORTANT: NPC must be delinked, and should have its }
	{ Paralocation/OriginalHome value set if you don't want it to }
	{ be deleted when the scene is finished. }
var
	Mek: GearPtr;
begin
	{ Set the NPC team value. }
	SetNAtt( NPC^.NA , NAG_Location , NAS_Team , Team );

	{ Load a mecha for the NPC, }
	{ and set everything on the board. }
	MEK := LoadSingleMecha( SAttValue( NPC^.SA , 'MECHA' ) , Design_Directory );
	if Mek <> Nil then begin
		{ Only use the mecha if the scene is appropriate. }
		if Mek^.SCale <= Scene^.V then begin
			InsertInvCom( Scene , MEK );
			SetNAtt( MEK^.NA , NAG_Location , NAS_Team , Team );
			if not BoardMecha( Mek , NPC ) then begin
				InsertInvCom( Scene , NPC );
			end;

		end else begin
			DisposeGear( Mek );
			InsertInvCom( Scene , NPC );
		end;
	end else begin
		InsertInvCom( Scene , NPC );
	end;
end;

Procedure AddArchEnemyToScene( Adventure,Scene,PC: GearPtr; MDesc: String );
	{ Search the ADVENTURE for one of the PC's arch-enemies. }
	{ Insert the enemy into the scene, along with an appropriate }
	{ PERSONA gear, a START trigger to FORCECHAT with the PC, }
	{ and the NPC's mecha. }
	{ Note that this procedure may result in no actual enemy being }
	{ added to the scene, depending upon whether or not the PC }
	{ has any enemies. }
	{ ALSO: Check through the NPC's combat skills. If any of them }
	{ are lower than the PC's, increment them. }
var
	NPC,HOOK: GearPtr;
	HDesc,EDesc,CMD: String;
begin
	{ Divide the description string into those parts which refer to }
	{ the hook and those parts which refer to the NPC. }
	HDesc := '';

	{ Default enemy description: Must have a mecha, and may be }
	{ a global character, and must not be involved in a plot. }
	EDesc := '!G HASMECHA NOPLOT';
	DeleteWhiteSpace( MDesc );
	While MDesc <> '' do begin
		CMD := ExtractWord( MDesc );

		{ Hook descriptions will start with either + or !. }
		if ( CMD[1] = '+' ) then begin
			HDesc := HDesc + ' ' + CMD;
		end else begin
			EDesc := EDesc + ' ' + CMD;
		end;
	end;

	{ Locate a suitable NPC. }
	NPC := CharacterSearch( Adventure , Nil , EDesc , Nil );

	{ If a NPC was found, and it is not part of a plot, add it }
	{ to the requested scene. }
	if NPC <> Nil then begin
		{ Delink NPC from current location. }
		DelinkNPCForEncounter( NPC );

		InsertNPCIntoDynamicScene( NPC , Scene , NAV_DefEnemyTeam );

		{ Generate a suitable hook, based on the HDesc string. }
		Hook := GenerateEnemyHook( Scene , PC , NPC , HDesc );
		InsertSubCom( Scene , Hook );

		{ If the NPC isn't currently an enemy of the PC, move }
		{ them one step closer. }
		if not ISArchEnemy( Adventure , NPC ) then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_ArchEnemy );
		end;

		{ Add the START trigger. }
		CMD := SAttValue( Scene^.SA , 'START' );
		CMD := 'ForceChat ' + BStr( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) ) + ' ' + CMD;
		SetSATt( Scene^.SA , 'START <' + CMD + '>' );

		{ Do NPC skill train-cheating. }
		{ For each of the combat skills (that's the first 10) }
		{ if the PC is better than the NPC, the NPC gets one }
		{ point of improvement. }
		SkillCheater( PC , NPC );

	end;

end;

Procedure AddArchAllyToScene( Adventure,Scene,PC: GearPtr );
	{ Search the ADVENTURE for one of the PC's arch-ally. }
	{ Insert the ally into the scene, along with an appropriate }
	{ PERSONA gear, a START trigger to FORCECHAT with the PC, }
	{ and the NPC's mecha. }
	{ Note that this procedure may result in no actual ally being }
	{ added to the scene, depending upon whether or not the PC }
	{ actually has any. }
	{ ALSO: Check through the NPC's combat skills. If any of them }
	{ are lower than the PC's, increment them. }
const
	AllySearch = '!G HASMECHA NOPLOT ARCHALLY';
	TeamData = 'ALLY SD';
var
	NPC,Team,Hook: GearPtr;
	CMD: String;
begin
	{ Locate a suitable NPC. }
	NPC := CharacterSearch( Adventure , Nil , AllySearch , Nil );

	{ If a NPC was found, and it is not part of a plot, add it }
	{ to the requested scene. }
	if NPC <> Nil then begin
		{ Delink NPC from current location. }
		DelinkNPCForEncounter( NPC );

		{ Set the NPC team value. }
		Team := CreateTeam( Scene , TeamData );
		Team^.S := -1;

		{ Set the PC team's ALLY value. }
		Team := LocateTeam( Scene , NAV_DefPlayerTeam );
		SetNAtt( Team^.NA , NAG_SideReaction , -1 , NAV_AreAllies );

		InsertNPCIntoDynamicScene( NPC , Scene , -1 );

		{ Generate a suitable hook, based on the HDesc string. }
		Hook := GenerateAllyHook( Scene , PC , NPC );
		InsertSubCom( Scene , Hook );

		{ Add the START trigger. }
		CMD := SAttValue( Scene^.SA , 'START' );
		CMD := 'ForceChat ' + BStr( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) ) + ' ' + CMD;
		SetSATt( Scene^.SA , 'START <' + CMD + '>' );

		{ Do NPC skill train-cheating. }
		{ For each of the combat skills (that's the first 10) }
		{ if the PC is better than the NPC, the NPC gets one }
		{ point of improvement. }
		SkillCheater( PC , NPC );
	end;

end;


end.
