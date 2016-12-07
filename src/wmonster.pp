unit WMonster;
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

const
	{ This is the minimum point value for meks when calling the STOCKSCENE }
	{ procedure. }
	MinPointValue = 65000;


Function GenerateMonster( MTV,Scale: Integer; MDesc: String ): GearPtr;
Procedure RestockRandomMonsters( GB: GameBoardPtr );
Function GenerateMechaList( MPV: LongInt ): SAttPtr;
Function PurchaseForces( ShoppingList: SAttPtr; UPV: LongInt ): GearPtr;
Procedure SelectEnemyForces( GB: GameBoardPtr; MekList: SAttPtr; UPV: LongInt );
Procedure StockSceneWithEnemies( Scene: GearPtr; UPV: longInt; TeamID: Integer );
Procedure StockSceneWithMonsters( Scene: GearPtr; MPV,TeamID: Integer; MDesc: String );


implementation

{$IFDEF SDLMODE}
uses dos,ability,action,gearutil,ghchars,ghparser,texutil,sdlmap;
{$ELSE}
uses dos,ability,action,gearutil,ghchars,ghparser,texutil,conmap;
{$ENDIF}

Function MatchWeight( S, M: String ): Integer;
	{ Return a value showing how well the monster M matches the }
	{ quoted source S. }
var
	Trait: String;
	it: Integer;
begin
	it := 0;

	while M <> '' do begin
		Trait := ExtractWord( M );

		if AStringHasBString( S , Trait ) then begin
			if it = 0 then it := 1
			else it := it * 2;
		end;
	end;

	MatchWeight := it;
end;

Function GenerateMonster( MTV,Scale: Integer; MDesc: String ): GearPtr;
	{ Generate a monster with no greater than NTV threat value, }
	{ which corresponds to MDesc. }
var
	ShoppingList,ShoppingItem: NAttPtr;
	Total: LongInt;
	WM: GearPtr;
	N,Match: Integer;
begin
	ShoppingList := Nil;
	WM := WMonList;
	N := 1;
	Total := 0;
	while WM <> Nil do begin
		{ If this monster matches our criteria, add its number to the list. }
		if ( WM^.V <= MTV ) and ( WM^.Scale <= Scale ) then begin
			Match := MatchWeight( MDesc , SAttValue( WM^.SA , 'TYPE' ) );
			SetNAtt( ShoppingList , 0 , N , Match );
			Total := Total + Match;
		end;

		{ Move to the next monster, and increase the monster index. }
		WM := WM^.Next;
		Inc( N );
	end;

	if Total > 0 then begin
		Match := Random( Total );
		ShoppingItem := ShoppingList;
		while Match > ShoppingItem^.V do begin
			Match := Match - ShoppingItem^.V;
			ShoppingItem := ShoppingItem^.Next;
		end;
		N := ShoppingItem^.S;

		{ Return the selected monster. }
		GenerateMonster := CloneGear( RetrieveGearSib( WMonList , N ) );
	end else begin
		{ Return a random monster. }
		GenerateMonster := CloneGear( SelectRandomGear( WMonList ) );
	end;
end;

Procedure AddRandomMonsters( GB: GameBoardPtr; Team: GearPtr; Threat: Integer );
	{ Place some wandering monsters on the map. }
var
	ShoppingList,ShoppingItem: NAttPtr;
	Total: LongInt;
	WM: GearPtr;
	WMonType: String;
	Gen,N,Match: Integer;
	MTV: LongInt;	{ Maximum Threat Value }
begin
	{ Check the TEAM gear to see what kinds of monsters we're looking for. }
	WMonType := SAttValue( Team^.SA , 'TYPE' );

	{ Create the shopping list. }
	{ Remove those that don't match the description, that are too big }
	{ for this game board, and that have a Threat Value which is too high. }
	MTV := Team^.Stat[ STAT_WanderMon ] div 2;
	if MTV < 1 then MTV := 1;

	ShoppingList := Nil;
	WM := WMonList;
	N := 1;
	Total := 0;
	while WM <> Nil do begin
		{ If this monster matches our criteria, add its number to the list. }
		if ( WM^.V <= MTV ) and ( WM^.Scale <= GB^.Scale ) then begin
			Match := MatchWeight( WMonType , SAttValue( WM^.SA , 'TYPE' ) );
			SetNAtt( ShoppingList , N , N , Match );
			Total := Total + Match;

		end;



		{ Move to the next monster, and increase the monster index. }
		WM := WM^.Next;
		Inc( N );
	end;


	{ If no monsters were loaded, exit the procedure. }
	if ShoppingList = Nil then Exit;

	{ Decide upon how many monsters to add. }
	Gen := Random( 5 );

	while ( Gen > 0 ) and ( Threat > 0 ) do begin
		{ Choose a random monster to add. }
		Match := Random( Total );
		ShoppingItem := ShoppingList;
		while Match > 0 do begin
			Match := Match - ShoppingItem^.V;
			if Match > 0 then ShoppingItem := ShoppingItem^.Next;
		end;
		N := ShoppingItem^.S;

		{ Deploy the monster on the map by cloning it. }
		WM := CloneGear( RetrieveGearSib( WMonList , N ) );
		SetNAtt( WM^.NA , NAG_Location , NAS_Team , Team^.S );

		{ Give the monster some money. }
		if WM^.V > 0 then begin
			SetNAtt( WM^.NA , NAG_Experience , NAS_Credits , Random( WM^.V + 3 ) );
		end;
		DeployMek( GB , WM , True );

		{ Reduce the generation counter and the threat points. }
		Threat := Threat - WM^.V;
		Dec( Gen );
	end;

	DisposeNAtt( ShoppingList );
end;

Procedure RestockRandomMonsters( GB: GameBoardPtr );
	{ Replenish this level's supply of random monsters. }
var
	Team: GearPtr;
	TPV: LongInt;
begin
	{ Error check - make sure the scene is defined. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;

	{ Search through the scene gear for teams which need random }
	{ monsters. If they don't have enough PV, add some monsters. }
	Team := GB^.Scene^.SubCom;
 	while Team <> Nil do begin
		{ if this gear is a team, and it has a wandering monster }
		{ allocation set, add some monsters. }
		if ( Team^.G = GG_Team ) and ( Team^.STat[ STAT_WanderMon ] > 0 ) then begin
			{ Calculate total point value of this team's units. }
			TPV := TeamTV( GB^.Meks , Team^.S );

			if TPV < Team^.Stat[ STAT_WanderMon ] then begin
				AddRandomMonsters( GB , Team , Team^.Stat[ STAT_WanderMon ] - TPV );
			end;
		end;

		{ Move to the next gear. }
		Team := Team^.Next;
	end;

end;

Function GenerateMechaList( MPV: LongInt ): SAttPtr;
	{ Build a list of mechas from the DESIGN diectory which have }
	{ a maximum point value of MPV or less. }
	{ Format for the description string is: pv index <filename> }
	{ where PV = Point Value, Index = Root Gear Number (since a }
	{ design file may contain more than one mecha), and filename }
	{ is the filename stored as an alligator string. }
var
	SRec: SearchRec;
	it,current: SAttPtr;
	DList,Mek: GearPtr;
	F: Text;
	N,MinValFound: LongInt;	{ The lowest value found so far. }
	MVInfo: String;		{ Info on the mek with the lowest value. }
begin
	it := Nil;
	MinValFound := 0;
	MVInfo := '';

	{ Start the search process going... }
	FindFirst( Design_Directory + Default_Search_Pattern , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		{ Load this mecha design file from disk. }
		Assign( F , Design_Directory + SRec.Name );
		reset(F);
		DList := ReadGear(F);
		Close(F);

		{ Search through it for mecha. }
		Mek := DList;
		N := 1;
		while Mek <> Nil do begin
			if ( Mek^.G = GG_Mecha ) then begin
				if ( GearValue( Mek ) <= MPV ) then begin
					Current := CreateSAtt( it );
					Current^.Info := BStr( GearValue( Mek ) ) + ' ' + BStr( N ) + ' <' + SRec.Name + '>';
				end else if ( GearValue( Mek ) < MinValFound ) or ( MinValFound = 0 ) then begin
					MVInfo := BStr( GearValue( Mek ) ) + ' ' + BStr( N ) + ' <' + SRec.Name + '>';
					MinValFound := GearValue( Mek );
				end;
			end;
			Mek := Mek^.Next;
			Inc( N );
		end;

		{ Dispose of the list. }
		DisposeGear( DList );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;

	{ Error check- we don't want to return an empty list, }
	{ but we will if we have to. }
	if ( it = Nil ) and ( MVInfo <> '' ) then begin
		Current := CreateSAtt( it );
		Current^.Info := MVInfo;
	end;

	GenerateMechaList := it;
end;

Function PurchaseForces( ShoppingList: SAttPtr; UPV: LongInt ): GearPtr;
	{ Pick a number of random meks with point value at least }
	{ equal to UPV. Add pilots to these meks. }

	Function ObtainMekFromFile( S: String ): GearPtr;
		{ Using the description string S, locate and load }
		{ a mek from disk. }
	var
		N: LongInt;
		F: Text;
		FList,Mek: GearPtr;
	begin
		{ Load the design file. }
		Assign(F, Design_Directory + RetrieveAString( S ) );
		reset(F);
		FList := ReadGear(F);
		Close(F);

		{ Get the number of the mek we want. }
		N := ExtractValue( S );

		{ Clone the mecha we want. }
		Mek := CloneGear( RetrieveGearSib( FList , N ) );

		{ Get rid of the design record. }
		DisposeGear( FList );

		{ Return the mek obtained. }
		ObtainMekFromFile := Mek;
	end;

	Function SelectNextMecha: String;
		{ Select a mecha file to load. Try to make it appropriate }
		{ to the point value of the encounter. }
	var
		M1,M2: STring;
		T: Integer;
		V,V2: LongInt;
	begin
		{ Select a mecha at random, and find out its point value. }
		M1 := SelectRandomSAtt( ShoppingList )^.Info;
		V := ExtractValue( M1 );

		{ If the PV of this mecha seems a bit low, }
		{ look for a more expensive model and maybe pick that }
		{ one instead. }
		t := 3;
		while ( t > 0 ) and ( V < ( UPV div 5 ) ) do begin
			M2 := SelectRandomSAtt( ShoppingList )^.Info;
			V2 := ExtractValue( M2 );
			if V2 > V then begin
				M1 := M2;
				V := V2;
			end;

			Dec( T );
		end;

		{ Return the info string selected. }
		SelectNextMecha := M1;
	end;
var
	MPV: LongInt;
	Lvl: LongInt;		{ Pilot level. }
	StPt,SkPt: LongInt;	{ Stat points and skill points of the pilot. }
	Mek,MList,CP: GearPtr;
begin
	{ Initialize our list to Nil. }
	MList := Nil;

	{ Keep processing until we run out of points. }
	while ( UPV > 0 ) and ( ShoppingList <> Nil ) do begin
		{ Select a mek at random. }
		{ Load & Clone the mek. }
		Mek := ObtainMekFromFile( SelectNextMecha );
		MPV := GearValue( Mek );

		{ Select a pilot skill level. }
		{ Set default values. }
		StPt := 90;
		SkPt := 3;

		if ( MPV > UPV ) or ( Random(10) = 1 ) then begin
			{ Level will be between 0 and -5 }
			Lvl := Random( 6 );
			StPt := StPt - ( Lvl * 3 );
			SkPt := SkPt - ( Lvl div 2 );
			MPV := ( MPV * ( 10 - Lvl ) ) div 10;

		end else if Random( MPV ) < Random( UPV ) then begin
			{ Level will be between 0 and 20 }
			Lvl := Random( 21 );

			{ Make sure we don't go overboard. }
			while ( ( ( MPV * ( 5 + Lvl ) ) div 5 ) > UPV ) and ( Lvl > 0 ) do begin
				Dec( Lvl );
			end;

			StPt := StPt + Lvl;
			SkPt := SkPt + ( Lvl div 2 );
			MPV := ( MPV * ( 5 + Lvl ) ) div 5;
		end;

		{ Add this mecha to our list. }
		Mek^.Next := MList;
		MList := Mek;

		{ Insert pilot in this mecha. }
		CP := SeekGear( Mek , GG_CockPit , 0 );
		if CP <> Nil then begin
			InsertSubCom( CP , RandomPilot( StPt , SkPt ) );
		end;

		{ Reduce UPV by an appropriate amount. }
		UPV := UPV - MPV;
	end;

	PurchaseForces := MList;
end;

Procedure SelectEnemyForces( GB: GameBoardPtr; MekList: SAttPtr; UPV: LongInt );
	{ This procedure will buy a number of mecha, provide them with pilots, }
	{ and stick them on the map. }
var
	MList,Mek: GearPtr;
begin
	{ Purchase the mecha. }
	MList := PurchaseForces( MekList , UPV );

	{ Stick the mecha on the map. }
	while MList <> Nil do begin
		{ Delink the first mecha from the list. }
		Mek := MList;
		DelinkGear( MList , Mek );

		{ Set its team to the enemy team. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_Team , NAV_DefEnemyTeam );

		{ Place it on the map. }
		DeployMek( GB , Mek , True );
	end;
end;

Procedure StockSceneWithSoldiers( Scene: GearPtr; UPV: LongInt; TeamID: Integer );
	{ Fill this team with people, but instead of mechas just give }
	{ them some random equipment. }
var
	F: Text;
	EquipList,NPC: GearPtr;
	EPV,AvgPointValue: LongInt;
	StPt,SkPt,Lvl: Integer;
begin
	Assign( F , PC_Equipment_File );
	Reset( F );
	EquipList := ReadGear( F );
	Close( F );

	AvgPointValue := 800;
	{ Use Lvl temporarily to store the maximum number of combatants we want. }
	lvl := 10 + Random( 20 );
	if ( UPV div AvgPointValue ) > lvl then AvgPointValue := UPV div lvl;

	While UPV > 0 do begin
		StPt := 90;
		SkPt := 5;
		EPV := AvgPointValue + Random( 500 ) - Random( 500 );
		if EPV > UPV then EPV := UPV
		else if EPV < 500 then EPV := 500;

		if ( EPV < 1000 ) or ( Random( 5 ) = 1 ) then begin
			Lvl := -Random( 5 );
			StPt := StPt + 2*Lvl;
			SkPt := SkPt + Lvl;
			EPV := EPV - ( 500 - lvl * lvl * 20 );
			UPV := UPV - ( 500 - lvl * lvl * 20 );
		end else if ( EPV > 1500 ) and ( Random( 5 ) <> 1 ) then begin
			repeat
				Lvl := Random( 10 );
			until ( 500 + lvl * lvl * 150 ) < ( EPV div 2 );
			StPt := StPt + Lvl;
			SkPt := SkPt + Lvl;
			EPV := EPV - ( 500 + lvl * lvl * 150 );
			UPV := UPV - ( 500 + lvl * lvl * 150 );
		end else begin
			EPV := EPV - 500;
			UPV := UPV - 500;
		end;

		NPC := RandomSoldier( StPt , SkPt );
		ExpandCharacter( NPC );

		SelectCombatEquipment( NPC , EquipList , EPV );
		UPV := UPV - EPV;

		{ Set its team to the ID provided. }
		SetNAtt( NPC^.NA , NAG_Location , NAS_Team , TeamID );

		{ Place it in the scene. }
		InsertInvCom( Scene , NPC );
	end;

	DisposeGear( EquipList );
end;

Procedure StockSceneWithMeks( Scene: GearPtr; UPV: longInt; TeamID: Integer );
	{ This scene requires a number of mecha to be added. Purchase an }
	{ appropriate value of mecha, then stick them in the scene. }
var
	ShoppingList: SAttPtr;
	MaxPointValue: LongInt;
	MList,Mek: GearPtr;
begin
	{ Generate the shopping list, then purchase mecha. }
	MaxPointValue := UPV div 2;
	if MaxPointValue < MinPointValue then MaxPointValue := MinPointValue;
	ShoppingList := GenerateMechaList( UPV );
	MList := PurchaseForces( ShoppingList , UPV );
	DisposeSAtt( ShoppingList );

	{ Stick the mecha in the scene. }
	while MList <> Nil do begin
		{ Delink the first mecha from the list. }
		Mek := MList;
		DelinkGear( MList , Mek );

		{ Set its team to the ID provided. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_Team , TeamID );

		{ Place it in the scene. }
		InsertInvCom( Scene , Mek );
	end;

end;

Procedure StockSceneWithEnemies( Scene: GearPtr; UPV: longInt; TeamID: Integer );
	{ Put some enemies in the scene. }
begin
	if Scene^.V = 0 then begin
		StockSceneWithSoldiers( Scene , UPV , TeamID );
	end else begin
		StockSceneWithMeks( Scene , UPV , TeamID );
	end;
end;

Procedure StockSceneWithMonsters( Scene: GearPtr; MPV,TeamID: Integer; MDesc: String );
	{ Place some monsters in this scene. }
var
	M: GearPtr;
begin
	while MPV > 0 do begin
		{ Grab a monster. }
		M := GenerateMonster( MPV , Scene^.V , MDesc );

		{ Reduce the PV by the monster's threat value. }
		MPV := MPV - M^.V;

		{ Set the team to the correct value. }
		{ Set its team to the ID provided. }
		SetNAtt( M^.NA , NAG_Location , NAS_Team , TeamID );

		{ Stick the monster in the scene. }
		InsertInvCom( Scene , M );
	end;

end;


end.
