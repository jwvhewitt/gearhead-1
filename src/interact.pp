unit interact;
	{ This unit contains the rules for using interaction skills, }
	{ such as Conversation, et cetera. }
	{ It also, by reason of necessity, contains some procedures }
	{ related to random plots. The main unit for plots is }
	{ playwright.pp; see that unit for more details. }
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
	{ *** PERSONA GEAR *** }
	{ G = GG_Persona                              }
	{ S = Character ID or Plot Element Number     }
	{ V = na                                      }

	{ *** FACTION GEAR *** }
	{ G = GG_Faction                              }
	{ S = Faction ID                              }
	{ V = Undefined                               }

	NAG_Personal = 5;

	NAS_CID = 0;	{ Character ID }
	NAS_FactionID = 2;	{ The character's faction. }
		{ Note that the faction ID for NPCs is stored in the }
		{ character gear, but for the PC it is stored in both }
		{ the character gear and the root Adventure gear. }
	NAS_ReTalk = 1;	{ Busy counter... after talking with an NPC once, }
		{ you can't talk with that same NPC again for a few }
		{ minutes. }
	NAS_RandSeed = 3;	{ Individual seed for shopkeepers. }
	NAS_RestockTime = 4;
	NAS_PickPocketRestock = 5;	{ Recharge time for picking pockets. }

	{ TACTICS SETTINGS }
	NAS_OptMax = 6;
	NAS_OptMin = 7;

	NAS_PerformancePenalty = 8;	{ Harder to impress same NPCs after first few tries. }

	{ This attribute records how well two characters like each other or }
	{ hate each other. The "S" identifier is the CID of the character }
	{ to which this reaction score applies. }
	NAG_ReactionScore = 6;

	{ This attribute records the relationship between two factions. }
	NAG_FactionScore = 8;

	{ This attribute records the relationship this NPC has with }
	{ another NPC in the game. }
	NAG_Relationship = 10;
	{ S descriptor is the CID of the other NPC. }
	{ ... or 0 for the PC. }
	NAV_ArchEnemy = -1;
	NAV_ArchAlly = 1;	{ Is there such a thing as an arch-ally? }
				{ Who really knows. }
		{ If the relationship type is greater than 0, the NPC can join the lance. }
	NAV_Family = 2;
	NAV_Lover = 3;

	ArchEnemyReactionPenalty = 25;

	Same_Faction_Bonus = 10;
	MaxFactionScore = 25;
	MinFactionScore = -50;


Function SeekFaction( Scene: GearPtr; ID: Integer ): GearPtr;
Function GetFactionID( Part: GearPtr ): Integer;
Function FactionIsInactive( Fac: GearPtr ): Boolean;

Function PlotElementID( Plot: GearPtr; Code: Char; ID: LongInt ): Integer;
Function FindPersonaPlot( Adventure: GearPtr; CID: Integer ): GearPtr;
Function SeekPlotElement( Adventure , Plot: GearPtr; N: Integer; GB: GameBoardPtr ): GearPtr;

Function PersonalityCompatability( PC, NPC: GearPtr ): Integer;
Function ReactionScore( Scene, PC, NPC: GearPtr ): Integer;

Function CreateRumorList( GB: gameBoardPtr; PC,NPC: GearPtr ): SAttPtr;
Function IdleChatter: String;
Function IsSexy( PC, NPC: GearPtr ): Boolean;
function DoChatting( GB: GameBoardPtr; var Rumors: SAttPtr; PC,NPC: GearPtr; Var Endurance,FreeRumors: Integer ): String;

Function SeekPersona( GB: GameBoardPtr; CID: LongInt ): GearPtr;
function SeekGearByCID( LList: GearPtr; CID: LongInt ): GearPtr;

Function NewCID( GB: GameBoardPtr; Adventure: GearPtr ): LongInt;
Function NewNID( GB: GameBoardPtr; Adventure: GearPtr ): LongInt;

Function IsArchEnemy( Adv,NPC: GearPtr ): Boolean;
Function IsArchAlly( Adv,NPC: GearPtr ): Boolean;
Function XNPCDesc( Adv,NPC: GearPtr ): String;

Function GenerateEnemyHook( Scene,PC,NPC: GearPtr; Desc: String ): GearPtr;
Function GenerateAllyHook( Scene,PC,NPC: GearPtr ): GearPtr;

Function LancematesPresent( GB: GameBoardPtr ): Integer;

Function FindNPCByKeyWord( GB: GameBoardPtr; KW: String ): GearPtr;


implementation

uses ability,gearutil,ghchars,rpgdice,texutil;

const
	Num_Openings = 7;	{ Number of TraitChatter opening phrases. }
	Num_Improve_Msg = 3;	{ Number of skill improvement messages. }

	Chat_MOS_Measure = 10;


var
	{ Strings for the random conversation generator. }
	Noun_List,Phrase_List,Adjective_List,RLI_List,Chat_Msg_List,Threat_List: SAttPtr;
	Trait_Chatter: Array [1..Num_Personality_Traits,1..2] of SAttPtr;


Function SeekFaction( Scene: GearPtr; ID: Integer ): GearPtr;
	{ Look for a faction corresponding to the provided ID number. }
	{ Return NIL if no such faction is found. }
var
	F: GearPtr;
begin
	{ Error check. }
	if ( Scene = Nil ) or ( ID = 0 ) then Exit( Nil );

	{ Find the root of SCENE, which should be the ADVENTURE. }
	{ The faction should be located along the invcoms. }
	F := FindRoot( Scene )^.InvCom;
	while ( F <> Nil ) and (( F^.G <> GG_Faction ) or ( F^.S <> ID )) do F := F^.Next;

	{ If the faction was not in the normal place, call the }
	{ heavy-duty and cycle-wasteful search routine. }
	if F = Nil then F := SeekGear( FindRoot( Scene ) , GG_Faction , ID );
	SeekFaction := F;
end;

Function GetFactionID( Part: GearPtr ): Integer;
	{ This function will return the Faction ID associated with }
	{ any given part, if appropriate. }
	{ FOr a faction this will be it's "S" descriptor. }
	{ For anything else, faction affiliation is stored as a NAtt. }
begin
	if Part^.G = GG_Faction then begin
		GetFactionID := Part^.S;
	end else begin
		GetFactionID := NAttValue( Part^.NA , NAG_Personal , NAS_FactionID );
	end;
end;

Function FactionIsInactive( Fac: GearPtr ): Boolean;
	{ Return TRUE if this faction has an INACTIVE tag in its }
	{ TYPE string attribute, or FALSE otherwise. }
begin
	FactionIsInactive := AStringHasBString( SATtValue( Fac^.SA , 'TYPE' ) , 'INACTIVE' );
end;

Function PlotElementID( Plot: GearPtr; Code: Char; ID: LongInt ): Integer;
	{ Determine which plot element is referred to by the supplied data. }
	{ CODE indicates what kind of gear we're looking for, while ID }
	{ is the identification number that should be listed in the Plot's }
	{ stats. }
	{ If the supplied ID number cannot be found within this plot, }
	{ return 0. }
var
	t,N: Integer;
	EDesc: String;
begin
	N := 0;
	Code := UpCase( Code );

	for t := 1 to NumGearStats do begin
		if Plot^.Stat[T] = ID then begin
			EDesc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) ) );
			DeleteWhiteSpace( EDesc );

			if ( EDesc <> '' ) and ( EDesc[1] = Code ) then begin
				N := T;
			end;
		end;
	end;

	PlotElementID := N;
end;

Function FindMetaPersona( Source: GearPtr; N: Integer ): GearPtr;
	{ Locate the replacement persona from this PLOT or STORY. }
var
	T,Meta: GearPtr;
begin
	T := Source^.SubCom;
	Meta := Nil;
	while T <> Nil do begin
		if ( T^.G = GG_Persona ) and ( T^.S = N ) then Meta := T;	
		T := T^.Next;
	end;
	FindMetaPersona := Meta;
end;

Function SeekPlotAlongPath( Part: GearPtr;  Code: Char; ID: LongInt; SeekType: Integer; NeedsPersona: Boolean ): GearPtr;
	{ Seek a gear which uses the specified element along the given }
	{ path. If no such plot is found return Nil. Recursively search }
	{ all active subcomponents. }
var
	it: GearPtr;
begin
	it := Nil;
	while ( Part <> Nil ) and ( it = Nil ) do begin
		if ( Part^.G = SeekType ) and ( PlotElementID( Part , Code , ID ) <> 0 ) then begin
			if NeedsPersona then begin
				if FindMetaPersona( Part , PlotElementID( Part , Code , ID ) ) <> Nil then begin
					it := Part;
				end;
			end else begin
				it := Part;
			end;
		end else if ( Part^.G = GG_Story ) or ( Part^.G = GG_Faction ) then begin
			it := SeekPlotALongPath( Part^.InvCom , Code , ID , SeekType , NeedsPersona );
		end;

		Part := Part^.Next;
	end;
	SeekPlotAlongPath := it;
end;

Function FindPersonaPlot( Adventure: GearPtr; CID: Integer ): GearPtr;
	{ Search all through ADVENTURE looking for a plot which }
	{ involves PERSONA. If no such plot is found, return NIL. }
begin
	{ Plots should be located along Adventure/InvCom. Plots which }
	{ are not located there are probably sub-plots, so they probably }
	{ don't yet have actors assigned. }
	Adventure := FindRoot( Adventure );
	if ( Adventure = Nil ) or ( Adventure^.G <> GG_Adventure ) then begin
		FindPersonaPlot := Nil;
	end else begin
		FindPersonaPlot := SeekPlotAlongPath( Adventure^.InvCom , 'C' , CID , GG_Plot , False );
	end;
end;

Function FindPersonaStory( Adventure: GearPtr; CID: Integer ): GearPtr;
	{ Search all through ADVENTURE looking for a story which }
	{ involves PERSONA. If no such story is found, return NIL. }
begin
	Adventure := FindRoot( Adventure );
	if ( Adventure = Nil ) or ( Adventure^.G <> GG_Adventure ) then begin
		FindPersonaStory := Nil;
	end else begin
		FindPersonaStory := SeekPlotAlongPath( Adventure^.InvCom , 'C' , CID , GG_Story , True );
	end;
end;

Function SeekPlotElement( Adventure , Plot: GearPtr; N: Integer; GB: GameBoardPtr ): GearPtr;
	{ Find the gear referred to in the N'th element of PLOT. }
	{ If no such element ay be found return Nil. }
var
	Desc: String;
	Part: GearPtr;
begin
	{ Start by locating the element description string. }
	Desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );
	Adventure := FindRoot( Adventure );

	{ Look for the element in the sensible place, given the }
	{ nature of the string. }
	if Desc = '' then begin
		Part := Nil;
	end else if Desc[1] = 'C' then begin
		{ Find a character. }
		Part := SeekGearByCID( Adventure , Plot^.Stat[N] );
		if ( Part = Nil ) and ( GB <> Nil ) then Part := SeekGearByCID( GB^.Meks , Plot^.Stat[N] );
	end else if Desc[1] = 'S' then begin
		{ Find a scene. }
		if GB <> Nil then begin
			Part := FindActualScene( GB , Plot^.Stat[ N ] );
		end else begin
			Part := SeekGear( Adventure , GG_Scene , Plot^.Stat[ N ] );
		end;
	end else if Desc[1] = 'F' then begin
		{ Find a faction. }
		Part := SeekGear( Adventure , GG_Faction , Plot^.Stat[ N ] );
	end else if Desc[1] = 'I' then begin
		{ Find an item. }
		Part := SeekGearByIDTag( Adventure , NAG_Narrative , NAS_NID , Plot^.Stat[ N ] );
		if ( Part = Nil ) and ( GB <> Nil ) then Part := SeekGearByIDTag( GB^.Meks , NAG_Narrative , NAS_NID , Plot^.Stat[ N ] );
	end else begin
		Part := Nil;
	end;

	{ Return the part that was found. }
	SeekPlotElement := Part;
end;

Function PlotUsedHere( Plot: GearPtr; GB: GameBoardPtr ): Boolean;
	{ See whether or not any of the elements of PLOT are in use on }
	{ this game board or in its associated scene. }
var
	PUH,EH: Boolean;
	T: Integer;
	Desc: String;
begin
	{ Error check - Make sure both the plot and the game board are }
	{ defined. }
	if ( Plot = Nil ) or ( GB = Nil ) then begin
		PlotUsedHere := False;
	end else begin
		{ Assume FALSE, then look for any element that's being used }
		{ on the game board. }
		PUH := False;

		{ Search through all the elements. }
		for t := 1 to NumGearStats do begin
			{ Start by locating the element description string. }
			Desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) ) );

			{ Look for the element in the sensible place, given the }
			{ nature of the string. }
			if Desc = '' then begin
				EH := False;
			end else if Desc[1] = 'C' then begin
				{ Find a character. }
				EH := SeekGearByCID( GB^.Meks , Plot^.Stat[T] ) <> Nil;
			end else if Desc[1] = 'S' then begin
				{ Find a scene. }
				if GB^.Scene <> Nil then EH := Plot^.Stat[ T ] = GB^.Scene^.S
				else EH := False;
			end else if Desc[1] = 'I' then begin
				{ Find an item. }
				EH := SeekGearByIDTag( GB^.Meks , NAG_Narrative , NAS_NID , Plot^.Stat[ T ] ) <> Nil;
			end;

			PUH := PUH or EH;
		end;

		{ Return whatever result was found. }
		PlotUsedHere := PUH;
	end;
end;

Function GeneralCompatability( PC1, PC2: GearPtr ): Integer;
	{ This function will determine the general level of }
	{ compatability between two characters. This is the }
	{ modifier which will be applied to most interaction }
	{ rolls. }
	{ It is determined by several things - }
	{  - Similarity of stats and skills }
var
	T,S1,S2: Integer;
	BCS: Integer;	{ Base compatability score }
begin
	{ Error Check - Make sure both PCs are valid gears. }
	if ( PC1 = Nil ) or ( PC2 = Nil ) then begin
		GeneralCompatability := 0;

	{ Error Check - Make sure both PCs are characters. }
	end else if ( PC1^.G <> GG_Character ) or ( PC2^.G <> GG_Character ) then begin
		GeneralCompatability := 0;

	end else begin
		{ Initialize the compatability score to 0. }
		BCS := 0;

		{ Check the stats. Every stat that is wildly different will }
		{ cause a drop in compatability, while every stat which is }
		{ very similar will cause a rise in compatability. }
		for t := 1 to 8 do begin
			if Abs( PC1^.Stat[t] - PC2^.Stat[t] ) > 8 then begin
				Dec( BCS );
			end else if ( PC1^.Stat[t] - PC2^.Stat[t] ) < 3 then begin
				Inc( BCS );
			end;
		end;

		{ Check the skills. Every skill that both PCs have will }
		{ cause a rise in compatability. }
		for t := 1 to NumSkill do begin
			S1 := NAttValue( PC1^.NA , NAG_Skill , T );
			S2 := NAttValue( PC2^.NA , NAG_Skill , T );

			if ( S1 > 10 ) and ( S2 > 10 ) then begin
				BCS := BCS + 3;
			end else if ( S1 > 5 ) and ( S2 > 5 ) then begin
				BCS := BCS + 2;
			end else if ( S1 > 0 ) and ( S2 > 0 ) then begin
				BCS := BCS + 1;
			end;
		end;

		GeneralCompatability := BCS;
	end;
end;

Function PersonalityCompatability( PC, NPC: GearPtr ): Integer;
	{ Calculate the compatability between PC and NPC based on their }
	{ personality traits. }
var
	T,CS: Integer;
	NPC_Score,PC_Score: Integer;
begin
	{ Initialize the Compatability Score to 0. }
	CS := 0;

	{ Loop through all the personality traits. }
	for t := 1 to Num_Personality_Traits do begin
		{ Determine the scores of both PC and NPC with regard to this }
		{ personality trait. }
		PC_Score := NAttValue( PC^.NA , NAG_CharDescription , -T );
		NPC_Score := NAttValue( NPC^.NA , NAG_CharDescription , -T );

		{ If the personality trait being discussed here is Villainousness, }
		{ this always causes a negative reaction. Otherwise, a reaction }
		{ will only happen if both the PC and the NPC have points in }
		{ this trait. }
		if ( T = Abs( NAS_Heroic ) ) and (PC_Score < -10 ) then begin
			CS := CS - Abs( PC_Score ) div 2;

		end else if ( T = Abs( NAS_Renowned ) ) then begin
			{ Being renowned is always good, while being wangtta is }
			{ always bad. }
			if PC_Score > 0 then begin
				CS := CS + ( PC_Score div 10 );
			end else begin
				CS := CS - ( Abs( PC_Score ) div 10 );
			end;

		end else if ( PC_Score <> 0 ) and ( NPC_Score <> 0 ) then begin
			if Sgn( PC_Score ) = Sgn( NPC_Score ) then begin
				{ The traits are in agreement. Increase CS. }
				CS := CS + Abs( PC_Score ) div 10;

			end else if ( Abs( PC_Score ) > 10 ) and ( Abs( NPC_Score ) > 10 ) then begin
				{ The traits are in opposition. Decrease CS. }
				CS := CS - 5;

			end;
		end;
	end;

	PersonalityCompatability := CS;
end;

Function FactionScore( Scene: GearPtr; F0,F1: Integer ): Integer;
	{ Given two factions, return the amount by which they are }
	{ allied to each other or hate each other. }
var
	Fac_0: GearPtr;
	it: Integer;
begin
	if ( F0 = 0 ) or ( F1 = 0 ) then begin
		it := 0;

	end else if F0 = F1 then begin
		it := Same_Faction_Bonus;

	end else begin
		Fac_0 := SeekFaction( Scene , F0 );
		if Fac_0 <> Nil then begin
			it := NAttValue( Fac_0^.NA , NAG_FactionScore , F1 );
		end else begin
			it := 0;
		end;

	end;
	FactionScore := it;
end;

Function FactionCompatability( Scene, PC, NPC: GearPtr ): Integer;
	{ Determine the faction compatability scores between PC and NPC. }
	{ + the PC's reputation with the NPC's faction. }
	{ - if PC is enemy of allied faction. }
	{ - if PC is ally of enemy faction. }
var
	NPC_FID,PC_FID,it: Integer;
	FAC: GearPtr;
begin
	{ Step one - Locate the FACTION information of the NPC, and }
	{ the PC's FACTION ID.. }
	NPC_FID := NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID );
	Fac := SeekFaction( Scene , NPC_FID );
	PC_FID := NAttValue( PC^.NA , NAG_Personal , NAS_FactionID );

	it := FactionScore( Scene , NPC_FID , PC_FID );
	if FAC <> Nil then it := it + PersonalityCompatability( PC , FAC );

	if it > MaxFactionScore then it := MaxFactionScore
	else if it < MinFactionScore then it := MinFactionScore;

	FactionCompatability := it;
end;

Function ReactionScore( Scene, PC, NPC: GearPtr ): Integer;
	{ Return a score in the range of -100..+100 which tells how much }
	{ the NPC likes the PC. }
var
	it,Persona: Integer;
begin
	{ The basic Reaction Score is equal to GENERAL COMPATABILITY + the }
	{ existing reaction modifier. }
	Persona := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	it := GeneralCompatability( PC , NPC ) + PersonalityCompatability( PC , NPC ) + NAttValue( PC^.NA , NAG_ReactionScore , Persona );

	{ If the scene is defined, add the faction compatability score. }
	if Scene <> Nil then it := it + FactionCompatability( Scene , PC , NPC );

	{ Make sure IT doesn't go out of bounds. }
	if it > 100 then it := 100
	else if it < -100 then it := -100;

    if HasTalent( PC, NAS_Bishounen ) then begin
        it := it + 10;
        if it < 0 then it := 0;
	end else if ( NAttValue( NPC^.NA , NAG_Relationship , NAttValue( PC^.NA , NAG_Personal , NAS_CID ) ) = NAV_ArchEnemy ) then begin
	    { A true archenemy will never have a greater reaction score than 0. }
        { Unless you're very very good looking, of course. }
		it := it - ArchEnemyReactionPenalty;
		if it > 0 then it := 0;
	end;

	ReactionScore := it;
end;

Function BlowOff: String;
	{ The NPC will just say something mostly useless to the PC. }
begin
	{ At some point in time I will make a lovely procedure that will }
	{ create all sorts of useless chatter. Right now, I'll just return }
	{ the following constant string. }
	BlowOff := 'I really don''t have much time to chat today, I have a lot of things to do.';
end;

function MadLibString( SList: SAttPtr ): String;
	{ Given a list of string attributes, return one of them at random. }
var
	SA: SAttPtr;
begin
	SA := SelectRandomSAtt( SList );
	if SA <> Nil then MadLibString := SA^.Info
	else MadLibString := '***ERROR***';
end;

Function FormatChatString( Msg1: String ): String;
	{ Do formatting on this string, adding nouns, adjectives, }
	{ and threats as needed. }
var
	msg2,w: String;
begin
	msg2 := '';

	while msg1 <> '' do begin
		w := ExtractWord( msg1 );

		if W[1] = '%' then begin
			DeleteFirstChar( W );
			if UpCase( W[1] ) = 'N' then begin
				DeleteFirstChar( W );
				W := MadLibString( Noun_List ) + W;
			end else if UpCase( W[1] ) = 'T' then begin
				DeleteFirstChar( W );
				W := MadLibString( Threat_List ) + W;
			end else begin
				DeleteFirstChar( W );
				W := MadLibString( Adjective_List ) + W;
			end;
		end;

		msg2 := msg2 + ' ' + w;
	end;

	DeleteWhiteSpace( Msg2 );
	FormatChatString := Msg2;
end;

Function IdleChatter: String;
	{ Create a Mad-Libs style line for the NPC to tell the PC. }
	{ Hopefully, these mad-libs will simulate the cheerfully nonsensical }
	{ things that poorly tanslated anime characters often say to }
	{ each other. }
	{ After testing this procedure, the effect is more akin to the }
	{ konglish slogans which adorn stationary & other character goods... }
	{ Close enough! I've got a winner here... }
var
	msg1: String;
begin
	{ Start with a MadLib form in msg1, and nothing in Msg2. }
	{ Transfer the message from M1 to M2 one word at a time, replacing }
	{ nouns and adjectives along the way. }
	msg1 := MadLibString( Phrase_List );

	IdleChatter := FormatChatString( Msg1 );
end;

Function DoTraitChatter( NPC: GearPtr; Trait: Integer ): String;
	{ The NPC needs to say a line which should give some indication }
	{ as to his/her orientation with respect to the listed }
	{ personality trait. }
const
	Num_Phrase_Bases = 3;
var
	Rk,Pro: Integer;
	msg: String;
begin
	{ To start with, find the trait rank. }
	Rk := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	{ Insert a basic starting phrase in the message, or perhaps none }
	{ at all... }
	if Random( 10 ) <> 1 then begin
		msg := SAttValue( Chat_Msg_List , 'TRAITCHAT_Lead' + BStr( Random( Num_Openings ) + 1 ) ) + ' ';
	end else begin
		msg := '';
	end;

	if Abs( Rk ) > 10 then begin
		{ Determine which side of the trait the NPC is in favor of. }
		if Rk > 0 then Pro := 1
		else Pro := 2;

		{ The NPC will either say that they like something from their own side, }
		{ or that they dislike something from the other. }
		if Random( 5 ) <> 1 then begin
			{ Like something. }
			msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Like' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , Pro ] ) + '.';

		end else begin
			{ Dislike something. }
			msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Hate' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , 3 - Pro ] ) + '.';

		end;
	end else begin
		Pro := Random( 2 ) + 1;
		msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Ehhh' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , Pro ] ) + '.';

	end;

	DoTraitChatter := Msg;
end;

Function CreateRumorList( GB: gameBoardPtr; PC,NPC: GearPtr ): SAttPtr;
	{ Scour the GB for information which can be passed to the PC. }
var
	InfoList: SAttPtr;
	Part: GearPtr;
{ Procedures Block }
	Procedure ExtractData( P: GearPtr );
		{ Store all relevant info from PART. }
	var
		Rumor: String;
		Trait,Level: Integer;
		Persona: GearPtr;
	begin
		if P <> NPC then begin
			Rumor := SAttValue( P^.SA , 'RUMOR' );
			if Rumor <> '' then StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + Rumor );

			if P^.G = GG_Character then begin
				{ At most one personality trait per NPC will be added }
				{ to the list. This is to keep them from overwhelming the }
				{ rumors from plots & other stuff... }
				Trait := Random( Num_Personality_Traits ) + 1;
				Level := NAttValue( P^.NA , NAG_CharDescription , -Trait );
				if Level <> 0 then begin
					if P = PC then begin
						StoreSAtt( InfoList , MadLibString( RLI_List ) + ' you are ' + LowerCase( PersonalityTraitDesc( Trait,Level ) ) + '.' );
					end else begin
						StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + GearName( P ) + ' is ' + LowerCase( PersonalityTraitDesc( Trait,Level ) ) + '.' );
					end;
				end;

				Persona := SeekPersona( GB , NAttValue( P^.NA , NAG_Personal , NAS_CID ) );
				if Persona <> Nil then ExtractData( Persona );

			end else if Part^.G = GG_Scene then begin
				{ Include a rumor based on what faction controls this scene. }
				Persona := SeekFaction( GB^.Scene , NAttValue( Part^.NA , NAG_Personal , NAS_FactionID ) );
				if Persona <> Nil then begin
					Rumor := MadLibString( RLI_List ) + ' ';
					Rumor := Rumor + SAttValue( Chat_Msg_List , 'RUMOR_TownFac1' ) + GearName( Persona ) + SAttValue( Chat_Msg_List , 'RUMOR_TownFac2' );
					StoreSAtt( InfoList , Rumor );
				end;

			end else if Part^.G = GG_Faction then begin
				{ If the faction is active, tell about its traits. }
				{ Otherwise, tell that it has been disbanded. }
				if AStringHasBString( SAttValue( P^.SA , 'TYPE' ) , 'INACTIVE' ) then begin
					StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + GearName( P ) + SAttValue( chat_msg_list , 'FACTION_IS_INACTIVE' ) );
				end else begin
					Trait := Random( Num_Personality_Traits ) + 1;
					Level := NAttValue( P^.NA , NAG_CharDescription , -Trait );
					if Level <> 0 then begin
						StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + GearName( P ) + ' is ' + LowerCase( PersonalityTraitDesc( Trait,Level ) ) + '.' );
					end;
				end;

			end;
		
		end else begin
			{ Include information about the NPC's faction, }
			{ if appropriate. }
			Persona := SeekFaction( GB^.Scene , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
			if Persona <> Nil then begin
				Rumor := SAttValue( Chat_Msg_List , 'TRAITCHAT_Lead' + BStr( Random( Num_Openings ) + 1 ) ) + ' ';
				Rumor := Rumor + SAttValue( Chat_Msg_List , 'RUMOR_Membership1' ) + GearName( Persona ) + SAttValue( Chat_Msg_List , 'RUMOR_Membership2' );
				StoreSAtt( InfoList , Rumor );
			end;
		end;
	end;
	Procedure CheckTrackForRumors( P: GearPtr );
		{ Check along this path for rumors, calling the Extract Data }
		{ procedure as needed. }
	begin
		while P <> Nil do begin
			if P^.G = GG_Plot then begin
				if PlotUsedHere( P , GB ) then ExtractData( P );
			end else if ( P^.G = GG_Story ) or ( P^.G = GG_Faction ) then begin
				ExtractData( P );
				CheckTrackForRumors( P^.InvCom );
			end;
			P := P^.Next;
		end;

	end;
begin
	{ Initialize INFOLIST to Nil. String Attributes will be used to store }
	{ all the possible bits of information that might be given to the PC. }
	InfoList := Nil;

	{ Check all objects on the map for RUMOR SAtts. }
	Part := GB^.Meks;
	while Part <> Nil do begin
		ExtractData( Part );
		Part := Part^.Next;
	end;

	{ If this gameboard has a SCENE gear defined, check both the scene }
	{ and all of its level one children for runors. }
	if GB^.Scene <> Nil then begin
		Part := GB^.Scene;
		ExtractData( Part );

		Part := GB^.Scene^.SubCom;
		while Part <> Nil do begin
			ExtractData( Part );
			Part := Part^.Next;
		end;

		Part := GB^.Scene^.InvCom;
		while Part <> Nil do begin
			ExtractData( Part );
			Part := Part^.Next;
		end;

		{ Look for an ADVENTURE gear, then extract rumors from the }
		{ global plots. }
		Part := FindRoot( GB^.Scene );
		if ( Part^.G = GG_Adventure ) and ( not AStringHasBString( SAttValue( GB^.Scene^.SA , 'TYPE' ) , 'ISOLATED' ) ) then begin
			CheckTrackForRumors( Part^.InvCom );
		end;
	end;

	CreateRumorList := InfoList;
end;

function InOpposition( PC , NPC: GearPtr; Trait: Integer ): Boolean;
	{ If the PC and the NPC disagree on this personality TRAIT, }
	{ return TRUE. Otherwise return FALSE. }
var
	T1,T2: Integer;
begin
	T1 := NAttValue( PC^.NA , NAG_CharDescription , -Trait );
	T2 := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	if ( Abs( T1 ) > 10 ) and ( Abs( T2 ) > 10 ) then begin
		{ The characters are in opposition if their trait }
		{ values are on opposite sides of 0. }
		InOpposition := Sgn( T1 ) <> Sgn( T2 );
	end else begin
		{ If the traits aren't strongly held by both, then }
		{ no real opposition. }
		InOpposition := False;
	end;
end;

function InHarmony( PC , NPC: GearPtr; Trait: Integer ): Boolean;
	{ If the PC and the NPC agree on this personality TRAIT, }
	{ return TRUE. Otherwise return FALSE. }
var
	T1,T2: Integer;
begin
	T1 := NAttValue( PC^.NA , NAG_CharDescription , -Trait );
	T2 := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	if ( Abs( T1 ) > 10 ) and ( Abs( T2 ) > 10 ) then begin
		{ The characters are in opposition if their trait }
		{ values are on opposite sides of 0. }
		InHarmony := Sgn( T1 ) = Sgn( T2 );
	end else begin
		{ If the traits aren't strongly held by both, then }
		{ no real opposition. }
		InHarmony := False;
	end;
end;

Function IsSexy( PC, NPC: GearPtr ): Boolean;
	{ Return TRUE if there are some potential sparks between }
	{ the PC and NPC, or FALSE if there aren't. }
begin
    if NAttValue( PC^.NA, NAG_CharDescription, NAS_RomanceType ) = NAV_RT_Anyone then begin
    	IsSexy := True;
    end else if NAttValue( PC^.NA, NAG_CharDescription, NAS_RomanceType ) = NAV_RT_Male then begin
    	IsSexy := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male;
    end else if NAttValue( PC^.NA, NAG_CharDescription, NAS_RomanceType ) = NAV_RT_Female then begin
    	IsSexy := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Female;
    end else IsSexy := False;
end;

Function DoleChatExperience( PC,NPC: GearPtr ): String;
	{ Give a skill-specific experience award to either Conversation }
	{ or Flirtation. }
var
	Skill_To_Improve: Integer;
	msg: sTRING;
begin
	{ Give a single point of general experience or a }
	{ skill-specific award. }
	if Random( 2 ) = 1 then begin
		DoleExperience( PC , XPA_GoodChat );
		msg := '';
	end else begin
		Skill_To_Improve := 19;
		if IsSexy( PC , NPC ) and ( Random( 3 ) = 1 ) then Skill_To_Improve := 27;
		if DoleSkillExperience( PC , Skill_To_Improve , XPA_GoodChat ) then begin
			msg := SAttValue( Chat_Msg_List , 'CHAT_Skill' + BStr( Skill_To_Improve ) + '_' + BStr( Random( Num_Improve_Msg ) + 1 ) );
		end else begin
			msg := '';
		end;
	end;
	DoleChatExperience := msg;
end;

function DoChatting( GB: GameBoardPtr; var Rumors: SAttPtr; PC,NPC: GearPtr; Var Endurance,FreeRumors: Integer ): String;
	{ This function will do chatting between the specified PC }
	{ and NPC with the specified persona, adjust the Reaction and }
	{ Endurance variables, then return a string that results }
	{ from the chat session. }
var
	SkRoll,SkTarget,MOS: Integer;
	Persona: Integer;
	msg,alt_msg: String;
	RTemp: SAttPtr;
	Trait: Integer;		{ The personality trait invoked by this conversation. }
	Function TraitWeight( N : Integer ): Integer;
		{ Return a value indicating how strongly this NPC }
		{ feels about this particular personality trait. }
	begin
		TraitWeight := Abs( NAttValue( NPC^.NA , NAG_CharDescription , -N ) ) + 5;
	end;
	Function SelectTraitForChatter: Integer;
		{ Decide what the subject of the conversation is going }
		{ to be based on the NPC's traits. }
	var
		total,N,T: Integer;
	begin
		{ The trait to be used will be determined by the }
		{ weight of the NPC's traits. }
		{ Find the total of the NPC's trait points. }
		total := 0;
		for t := 1 to Num_Personality_Traits do total := total + TraitWeight( T );

		{ Next, select a random value and find a trait based on that. }
		N := Random( Total );
		T := 1;
		while N > TraitWeight( T ) do begin
			N := N - TraitWeight( T );
			Inc( T );
		end;
		SelectTraitForChatter := T;
	end;
	Procedure SelectChatter;
		{ Normally idle chatter has been selected; this procedure may }
		{ select a trait-based interaction instead. }
	begin
		if ( Trait <> 0 ) and ( Random( 2 ) = 1 ) then begin
			{ Trait-Based Chatter. }
			msg := DoTraitChatter( NPC , Trait );
		end else begin
			{ Regular Chatter. }
			msg := IdleChatter;
		end;
	end;
begin
	{ Start by making a social interaction roll for the PC. }
	SkRoll := RollStep( SkillValue( PC , 19 ) );

	{ Apply flirtation bonus to the skill roll, if appropriate. }
	{ The bonus only applies if the PC has ranks in flirtation or is a Jack of all Trades. }
	if ( NAttValue( PC^.NA , NAG_Skill , 27 ) > 0 ) or HasTalent( PC , NAS_JackOfAll ) then begin
        if HasTalent( PC, NAS_Bishounen ) then begin
    		SkRoll := SkRoll + RollStep( SkillValue( PC , 27 ) );
        end else if NAttValue( PC^.NA, NAG_CharDescription, NAS_RomanceType ) in [NAV_RT_NoOne,NAV_RT_Anyone] then begin
            { If looking for anyone, or looking for no-one, apply half the normal bonus. }
    		SkRoll := SkRoll + ( RollStep( SkillValue( PC , 27 ) ) div 2 );
        end else if IsSexy( PC , NPC ) then begin
    		SkRoll := SkRoll + RollStep( SkillValue( PC , 27 ) );
        end;
	end;

	{ Initialize TRAIT to random, and find the NPC's PERSONA value. }
	{ These things will be needed later. }
	if Random( 3 ) <> 1 then begin
		Trait := SelectTraitForChatter;
	end else begin
		Trait := 0;
	end;
	Persona := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );

	{ Determine the effect target number. The more extreme the NPC's }
	{ current opinion of the PC is, the more difficult it will be to }
	{ change that opinion.  In addition, if the opinion is a negative }
	{ one, it'll be even harder to change the opinion. }
	SkTarget := 10 + Abs( ReactionScore( GB^.Scene , PC , NPC ) - 10 ) div 3;

	{ Reduce ENDURANCE. }
	if ( SkRoll > SkTarget ) or ( Random ( 110 ) > ReactionScore( GB^.Scene , PC , NPC ) ) then Dec( Endurance );
	if SkRoll < RollStep( 4 ) then Dec( Endurance );

	{ Finally, decide what the result of all this die rolling will be. }
	{ First see what useful (or useless) information the NPC will share. }
	if ( SkRoll + ReactionScore( GB^.Scene , PC , NPC ) + Random(10) - Random(10) ) < 0 then begin
		msg := BlowOff;

		{ Since the NPC is trying to get rid of the PC, }
		{ decrement ENDURANCE one more time. }
		Dec( Endurance );

	end else if ( FreeRumors > 0 ) and ( Rumors <> Nil ) then begin
		RTemp := SelectRandomSAtt( Rumors );
		msg := RTemp^.info;
		RemoveSAtt( Rumors, RTemp );
		Dec( FreeRumors );

	end else if ( SkRoll + ( ReactionScore( GB^.Scene , PC , NPC ) div  10 ) ) < 10 then begin
		SelectChatter;

	end else begin
		if ( Rumors <> Nil ) and ( SkRoll > ( 10 + Random( 21 ) ) ) then begin
			RTemp := SelectRandomSAtt( Rumors );
			msg := RTemp^.info;
			RemoveSAtt( Rumors, RTemp );
		end else begin
			SelectChatter;
		end;
	end;

	{ Secondly there's a chance that the chatting will improve relations }
	{ between the PC and NPC. If a TRAIT conversation has taken place, }
	{ this could make things harder. }
	if ( Trait <> 0 ) then begin
		if InOpposition( PC , NPC , Trait ) then begin
			SkRoll := SkRoll - SkTarget;
		end else if InHarmony( PC , NPC , Trait ) then begin
			SkRoll := SkRoll + ( ( SkRoll * Abs( NAttValue( PC^.NA , NAG_CharDescription , -Trait ) ) ) div 100 );
		end;
	end;


	if SkRoll > SkTarget then begin
		MOS := 1 + ( SkRoll - SkTarget ) div Chat_MOS_Measure;
		if Persona > 0 then begin
			AddNAtt( PC^.NA , NAG_ReactionScore , Persona , MOS );
			if ( MOS > 1 ) and ( SkTarget > 15 ) then DoleExperience( PC , MOS div 2 );
		end;

	end else if SkRoll < 0 then begin
		{ A negative skill roll means that the reaction is going to worsen. }
		MOS := 1 + Abs( SkRoll ) div 2;

		{ If the PC has the DIPLOMATIC talent, this can be avoided. }
		if HasTalent( PC , NAS_Diplomatic ) and ( RollStep( SkillValue( PC , 19 ) ) > ( NPC^.Stat[ STAT_Ego ] + 2 ) ) then begin
			MOS := 0;
		end;

		AddNAtt( PC^.NA , NAG_ReactionScore , Persona , -MOS );
	end;

	{ If appropriate, dole some experience points out. }
	{ Note that we're doing it down here since flirtation bonus }
	{ should apply. }
	if SkRoll > CHAT_EXPERIENCE_TARGET then begin
		alt_msg := DoleChatExperience( PC , NPC );
		if alt_msg <> '' then msg := alt_msg;
	end;

	DoChatting := msg;
end;


Function SeekPersona( GB: GameBoardPtr; CID: LongInt ): GearPtr;
	{ Seek the closest persona gear with the provided Character ID. }
	{ If this NPC is involved in a plot, use the persona gear from }
	{ the plot if one is provided. Otherwise, seek the PERSONA }
	{ in the GB/Scene gear. }
var
	Plot,Persona: GearPtr;
	N: Integer;
begin
	Persona := Nil;

	{ Use the persona located in the character's PLOT, if appropriate. }
	Plot := FindPersonaPlot( FindRoot( GB^.Scene ) , CID );
	if Plot <> Nil then begin
		{ This character is featured in a plot. The plot may }
		{ well contain a persona for this character to use }
		{ while the plot is in effect. }
		N := PlotElementID( Plot , 'C' , CID );
		Persona := FindMetaPersona( Plot , N );
	end;

	{ Use the persona from the character's STORY next. }
	if Persona = Nil then begin
		Plot := FindPersonaStory( FindRoot( GB^.Scene ) , CID );
		if Plot <> Nil then begin
			N := PlotElementID( Plot , 'C' , CID );
			Persona := FindMetaPersona( Plot , N );
		end;
	end;

	{ Next two places to look - The current scene, and the }
	{ adventure itself. }
	if Persona = Nil then Persona := SeekGear( GB^.Scene , GG_Persona , CID );
	if ( Persona = Nil ) and ( CID > NumGearStats ) then Persona := SeekGear( FindRoot( GB^.Scene ) , GG_Persona , CID );


	SeekPersona := Persona;
end;

function SeekGearByCID( LList: GearPtr; CID: LongInt ): GearPtr;
	{ Seek a gear with the provided ID. If no such gear is }
	{ found, return NIL. }
begin
	SeekGearByCID := SeekGearByIDTag( LList , NAG_Personal , NAS_CID , CID );
end;

Function NewCID( GB: GameBoardPtr; Adventure: GearPtr ): LongInt;
	{ Determine a new, unique CID for a character being added to the }
	{ campaign. To make sure our CID is unique, we'll be making it one }
	{ point higher than the highest CID we can find. }
var
	it,it2: LongInt;
	Procedure CheckAlongPath( LList: GearPtr );
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_Persona ) and ( LList^.S > it ) then it := LList^.S;
			CheckAlongPath( LList^.SubCom );
			CheckAlongPath( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
begin
	{ To start with, find the highest ID being used by a character. }
	it := NAttValue( Adventure^.NA , NAG_Narrative , NAS_MaxCID );
	if it = 0 then begin
		IT := MaxIDTag( Adventure , NAG_Personal , NAS_CID );
		if GB <> Nil then begin
			it2 := MaxIDTag( GB^.Meks , NAG_Personal , NAS_CID );
			if it2 > it then it := it2;
		end;

		{ Next, search all the PERSONA gears to make sure none of them }
		{ have one higher. }
		CheckAlongPath( Adventure );
	end;

	{ Return the highest value found, +1. }
	SetNAtt( Adventure^.NA , NAG_Narrative , NAS_MaxCID , it + 1 );
	NewCID := it + 1;
end;

Function NewNID( GB: GameBoardPtr; Adventure: GearPtr ): LongInt;
	{ Determine a new, unique NID for an item being added to the }
	{ campaign. To make sure our NID is unique, we'll be making it one }
	{ point higher than the highest NID we can find. }
var
	it,it2: LongInt;
begin
	{ To start with, find the highest ID being used by a character. }
	it := NAttValue( Adventure^.NA , NAG_Narrative , NAS_MaxNID );
	if it = 0 then begin
		IT := MaxIDTag( Adventure , NAG_Narrative , NAS_NID );
		if GB <> Nil then begin
			it2 := MaxIDTag( GB^.Meks , NAG_Narrative , NAS_NID );
			if it2 > it then it := it2;
		end;
	end;

	{ Return the highest value found, +1. }
	SetNAtt( Adventure^.NA , NAG_Narrative , NAS_MaxNID , it + 1 );
	NewNID := it + 1;
end;

Procedure LoadTraitChatter;
	{ Load the trait chatter elements from disk. }
var
	t: integer;
begin
	for t := 1 to Num_Personality_Traits do begin
		Trait_Chatter[ T , 1 ] := LoadStringList( Trait_Chatter_Base + BStr( T ) + '_1.txt' );
		Trait_Chatter[ T , 2 ] := LoadStringList( Trait_Chatter_Base + BStr( T ) + '_2.txt' );
	end;
end;

Procedure FreeTraitChatter;
	{ Remove the trait chatter elements from memory. }
var
	t: integer;
begin
	for t := 1 to Num_Personality_Traits do begin
		DisposeSAtt( Trait_Chatter[ T , 1 ] );
		DisposeSAtt( Trait_Chatter[ T , 2 ] );
	end;
end;

Function IsArchEnemy( Adv,NPC: GearPtr ): Boolean;
	{ Return TRUE if the NPC is an arch-enemy of the PC, or }
	{ FALSE otherwise. }
	{ The NPC will be an arch-enemy if it has that particular }
	{ relationship set, or if the NPC and the PC belong to }
	{ warring factions. }
var
	it: Boolean;
	PCF,NPCF: Integer;
begin
	it := NATtValue( NPC^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy;

	{ If this character is not an intrinsic enemy of the PC, maybe }
	{ it will be an enemy because of faction relations. }
	if ( Adv <> Nil ) and not it then begin
		NPCF := GetFactionID( NPC );
		NPC := SeekFaction( Adv , NPCF );
		PCF := NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID );
		it := ( FactionScore( Adv , NPCF , PCF ) < 0 ) or (( NPC <> Nil ) and ( NAttValue( NPC^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy ));
	end;

	IsArchEnemy := it;
end;

Function IsArchAlly( Adv,NPC: GearPtr ): Boolean;
	{ Return TRUE if the NPC is an arch-ally of the PC, or }
	{ FALSE otherwise. }
	{ The NPC will be an arch-ally if it has that particular }
	{ relationship set, or if the NPC and the PC belong to }
	{ the same faction. }
var
	it: Boolean;
	PCF,NPCF: Integer;
begin
	it := NATtValue( NPC^.NA , NAG_Relationship , 0 ) = NAV_ArchAlly;

	{ If this character is not an intrinsic ally of the PC, maybe }
	{ it will be an ally because of faction relations. }
	if ( Adv <> Nil ) and not it then begin
		NPCF := GetFactionID( NPC );
		NPC := SeekFaction( Adv , NPCF );
		PCF := NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID );
		it := ( FactionScore( Adv , NPCF , PCF ) > 0 ) or ( ( NPC <> Nil ) and ( NATtValue( NPC^.NA , NAG_Relationship , 0 ) > 0 ) );
	end;

	IsArchAlly := it;
end;

Function XNPCDesc( Adv,NPC: GearPtr ): String;
	{ Extended NPC description. }
var
	it: String;
begin
	it := NPCTraitDesc( NPC );

	if IsArchEnemy( Adv, NPC ) then it := it + ' ARCHENEMY';
	if NAttValue( NPC^.NA , NAG_Relationship , 0 ) = NAV_Lover then it := it + ' LOVER';
	if NAttValue( NPC^.NA , NAG_Relationship , 0 ) = NAV_Family then it := it + ' FAMILY';
	if IsArchAlly( Adv, NPC ) then it := it + ' ARCHALLY';

	if FindPersonaPlot( Adv , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) ) = Nil then it := it + ' NOPLOT'
	else it := it + ' YESPLOT';

	XNPCDesc := it;
end;

Function GenerateEnemyHook( Scene,PC,NPC: GearPtr; Desc: String ): GearPtr;
	{ Return a PERSONA gear to be used by the provided NPC }
	{ in the upcoming battle. }
	Function RelativeMessage: String;
		{ Provide a message based upon either the Ally/Enemy }
		{ status of the NPC, or upon the reaction score between }
		{ PC and NPC. }
	var
		R: Integer;
	begin
		if Random( 3 ) <> 1 then begin
			if IsArchAlly( Scene , NPC ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_AreAllies_' + BStr( Random( 3 ) + 1 ) );
			end else if IsArchEnemy( Scene , NPC ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_AreEnemies_' + BStr( Random( 3 ) + 1 ) );
			end else begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_AreNeutral_' + BStr( Random( 3 ) + 1 ) );
			end;
		end else begin
			R := ReactionScore( Scene, PC, NPC );
			if R > ( 35 + Random( 50 ) ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_Like_' + BStr( Random( 3 ) + 1 ) );
			end else if R > ( Random( 30 ) - 10 ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_Ehhh_' + BStr( Random( 3 ) + 1 ) );
			end else begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_Hate_' + BStr( Random( 3 ) + 1 ) );
			end;
		end;
	end;

	Function TraitMessage( T: Integer ): String;
	var
		L: Integer;
	begin
		{ Note that a space is added to the front of the }
		{ trait message for formatting purposes. }
		L := NAttValue( NPC^.NA , NAG_CharDescription , -T );
		if L > 10 then begin
			TraitMessage := ' ' + SAttValue( Chat_Msg_List , 'EHOOK_Trait_' + BStr( T ) + '_1_' + BStr( Random( 3 ) + 1 ) );
		end else if L < -10 then begin
			TraitMessage := ' ' + SAttValue( Chat_Msg_List , 'EHOOK_Trait_' + BStr( T ) + '_2_' + BStr( Random( 3 ) + 1 ) );
		end else begin
			TraitMessage := '';
		end;
	end;

	Function IntimidationTarget: Integer;
		{ Determine how easily this NPC may be scared off. }
	const
		baseTV = 5;
		minimumTV = 10;
	var
		IT,Trait: Integer;
	begin
		{ Difficulcy level is based on the NPC's EGO stat. }
		it := baseTV + CStat( NPC , STAT_Ego );

		{ Certain personality traits can affect the IT. }
		{ LAWFUL characters are less likely to abandon their causes. }
		Trait := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful );
		if Trait > 10 then begin
			it := it + ( Trait div 10 );
		end;

		{ PASSIONATE characters long for battle, }
		{ while EASYGOING characters long for comfort. }
		Trait := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Easygoing );
		if Trait > 25 then begin
			it := it - ( Trait div 25 );
		end else if Trait < -15 then begin
			it := it + ( Abs( Trait ) div 15 );
		end;

		{ RENOWNED characters aren't easily intimidated. }
		Trait := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) - NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
		if Trait > 10 then begin
			it := it + ( Trait div 5 );
		end else if Trait < -15 then begin
			it := it - ( Abs( Trait ) div 15 );
		end;

		{ If it's less than the minimum target value, }
		{ set it to at least that much. }
		if it < MinimumTV then it := MinimumTV;

		IntimidationTarget := it;
	end;

var
	Hook: GearPtr;
	greeting,msg1,cmd: String;
	N1,N2: Integer;
begin
	{ Create the gear for the hook. }
	Hook := NewGear( Nil );
	Hook^.G := GG_Persona;
	Hook^.S := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	InitGear( Hook );

	greeting := SAttValue( Chat_Msg_List , 'EHook_Greeting' );

	{ Record the intimidation target and XPV. }
	N1 := IntimidationTarget;
	SetNAtt( Hook^.NA , 0 ,  999 , N1 );
	if N1 > 0 then SetNAtt( Hook^.NA , 0 , 1000 , N1 * 50 );


	{ Create Message 1 - the NPC's speech to the player. }
	{ Start with a trait message. If empty, use a relative message }
	{ instead. }
	N1 := Random( Num_Personality_Traits ) + 1;
	msg1 := TraitMessage( N1 );
	if msg1 = '' then msg1 := RelativeMessage;

	{ Add a second trait message which should not conflict with the }
	{ first one. }
	N2 := Random( Num_Personality_Traits - 1 ) + 1;
	if N2 = N1 then Inc( N2 );
	msg1 := msg1 + TraitMessage( N2 );

	{ Define the options. }
	desc := UpCase( desc );
	while desc <> '' do begin
		cmd := ExtractWord( desc );

		if cmd = '+PCRA' then begin
			{ Player can run away. Enemy will give player }
			{ the option to leave. }
			msg1 := msg1 + ' ' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_PCRA_' + BStr( Random( 5 ) + 1 ) ) );
			greeting := greeting + ' AddChat 2';
			SetSAtt( Hook^.SA , 'prompt2 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_P_2_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
			SetSAtt( Hook^.SA , 'result2 <' + SAttValue( Chat_Msg_List , 'EHOOK_R_2' ) + '>' );
			SetSAtt( Hook^.SA , 'msg3 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg3_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );

		end else if cmd = '+ECRA' then begin
			{ Enemy can run away. Player will have }
			{ the option to threaten the NPC. }
			greeting := greeting + ' AddChat 3';
			SetSAtt( Hook^.SA , 'prompt3 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_P_3_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
			SetSAtt( Hook^.SA , 'result3 <' + SAttValue( Chat_Msg_List , 'EHOOK_R_3' ) + '>' );
			SetSAtt( Hook^.SA , 'msg4 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg4_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
			SetSAtt( Hook^.SA , 'msg5 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg5' ) ) + '>' );

		end;
	end;

	SetSAtt( Hook^.SA , 'greeting <' + greeting + '>' );
	SetSAtt( Hook^.SA , 'msg1 <' + FormatChatString( msg1 ) + '>' );
	SetSAtt( Hook^.SA , 'msg2 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg2_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'prompt1 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_P_1_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'result1 <' + SAttValue( Chat_Msg_List , 'EHook_R_1' ) + '>' );

	GenerateEnemyHook := Hook;
end;

Function GenerateAllyHook( Scene,PC,NPC: GearPtr ): GearPtr;
	{ The only real purpose of this is to let the player know that }
	{ there's another mecha on his side. }
var
	Hook: GearPtr;
begin
	{ Create the gear for the hook. }
	Hook := NewGear( Nil );
	Hook^.G := GG_Persona;
	Hook^.S := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	InitGear( Hook );

	SetSAtt( Hook^.SA , 'greeting <' + SAttValue( chat_msg_list , 'AHOOK_Greeting' ) + '>' );
	SetSAtt( Hook^.SA , 'result1 <' + SAttValue( chat_msg_list , 'AHOOK_R_1' ) + '>' );
	SetSAtt( Hook^.SA , 'Msg1 <' + FormatChatString( SAttValue( chat_msg_list , 'AHOOK_MSG1_' + BStr( Random( 3 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'Msg2 <' + FormatChatString( SAttValue( chat_msg_list , 'AHOOK_MSG2_' + BStr( Random( 3 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'Prompt1 <' + FormatChatString( SAttValue( chat_msg_list , 'AHOOK_P_1_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );

	GenerateAllyHook := Hook;
end;

Function LancematesPresent( GB: GameBoardPtr ): Integer;
	{ Return the number of points worth of lancemates present. }
	{ This will determine whether or not the PC can recruit more. }
	{ Check for Team-3 gears; add +2 to the total for each mecha or }
	{ person, +1 to the total for each other master. }
var
	M: GearPtr;
	N: Integer;
begin
	M := GB^.Meks;
	N := 0;
	while M <> Nil do begin
		if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and GearActive( M ) then begin
			if ( M^.G = GG_Mecha ) or ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) <> 0 ) then begin
				N := N + 2;
			end else begin
				N := N + 1;
			end;
		end;
		M := M^.Next;
	end;
	LancematesPresent := N;
end;

Function FindNPCByKeyWord( GB: GameBoardPtr; KW: String ): GearPtr;
	{ Attempt to locate a NPC by keyword. The keyword may be the job of the NPC, or }
	{ it may be a phrase listed in the NPC's Persona's KEYWORDS string attribute. }
	Function NPCMatchesKW( NPC: GearPtr ): Boolean;
	var
		desc: String;
		Persona: GearPtr;
	begin
		desc := SAttValue( NPC^.SA , 'JOB' );
		Persona := SeekPersona( GB , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) );
		if Persona <> Nil then desc := desc + SAttValue( Persona^.SA , 'KEYWORDS' );
		NPCMatchesKW := AStringHasBString( desc , KW );
	end;
var
	N: Integer;
	M: GearPtr;
begin
	{ Pass one: Locate all NPCs who match the keyword provided. }
	M := GB^.Meks;
	N := 0;
	while M <> Nil do begin
		if M^.G = GG_Character then begin
			if NPCMatchesKW( M ) then Inc( N );
		end;
		M := M^.Next;
	end;

	{ Pass two: Pick one at random, and select it. }
	{ ASSERT: M = Nil }
	if N > 0 then begin
		N := Random( N );
		M := GB^.Meks;
		while ( N >= 0 ) and ( M <> Nil ) do begin
			if M^.G = GG_Character then begin
				if NPCMatchesKW( M ) then begin
					Dec( N );
					if N = -1 then break;
				end;
			end;

			M := M^.Next;
		end;
	end;

	{ Return the NPC found. }
	FindNPCByKeyWord := M;
end;

initialization

	Noun_List := LoadStringList( Standard_Nouns_File );
	Phrase_List := LoadStringList( Standard_Phrases_File );
	Adjective_List := LoadStringList( Standard_Adjectives_File );
	RLI_List := LoadStringList( Standard_Rumors_File );
	Threat_List := LoadStringList( Standard_Threats_File );
	Chat_Msg_List := LoadStringList( Standard_Chatter_File );
	LoadTraitChatter;

finalization
	DisposeSAtt( Noun_List );
	DisposeSAtt( Phrase_List );
	DisposeSAtt( Adjective_List );
	DisposeSAtt( RLI_List );
	DisposeSAtt( Threat_List );
	DisposeSAtt( Chat_Msg_List );
	FreeTraitChatter;
end.
