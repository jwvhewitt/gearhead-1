unit randchar;
	{ This unit contains the nuts and bolts of the GearHead }
	{ character generator. }
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
	RC_DirList = Series_Directory + OS_Search_Separator + OS_Current_Directory;

	BaseStatPts = 80;
	MaxStartingSkill = 5;

Function SkillDesc( N: Integer ): String;
Procedure SaveChar( PC: GearPtr );
Function CharacterCreator: GearPtr;
Procedure GenerateNewPC;

implementation

{$IFDEF SDLMODE}
uses gearutil,ghchars,texutil,ui4gh,sdlgfx,sdlinfo,sdlmenus;
{$ELSE}
uses gearutil,ghchars,texutil,ui4gh,congfx,coninfo,conmenus,context;
{$ENDIF}

{$IFDEF SDLMODE}
var
	RCPC: GearPtr;
	RCPromptMessage,RCDescMessage,RCCaption,RCHintMessage: String;

Procedure RandCharRedraw;
	{ Redraw the screen for SDL. }
begin
	DrawCharGenBorder;
	if RCPC <> Nil then CharacterDisplay( RCPC , Nil, ZONE_CharGenChar );
	GameMsg( RCDescMessage , ZONE_CharGenDesc.GetRect() , InfoGreen );
	CMessage( RCPromptMessage , ZONE_CharGenPrompt.GetRect() , InfoGreen );
	if RCCaption <> '' then CMessage( RCCaption , ZONE_CharGenCaption.GetRect() , InfoGreen );
    if RCHintMessage <> '' then begin
    	InfoBox( ZONE_CharGenHint.GetRect() );
        CMessage( RCHintMessage , ZONE_CharGenHint.GetRect() , InfoGreen );
    end;
end;
{$ENDIF}

Function SkillDesc( N: Integer ): String;
	{ Return a description for this skill. The main text is taken }
	{ from the messages.txt file, plus the name of the stat which }
	{ governs this skill. }
var
	msg: String;
begin
	msg := '';

	{ Error check- only provide description for a legal skill }
	{ number. Otherwise just return an empty string. }
	if ( N >= 1 ) and ( N <= NumSkill ) then begin
		msg := '[' + UpCase( StatName[SkillMan[N].Stat] ) + '] ' + MsgString( 'SKILL_' + BStr( N ) );
	end;
	SkillDesc := msg;
end;

Procedure SaveChar( PC: GearPtr );
	{ Save this character to disk, in the "SaveGame" directory. }
var
	Leader: GearPtr;
	FName: String;		{ Filename for the character. }
	F: Text;		{ The file to write to. }
begin
	Leader := PC;
	while ( Leader <> Nil ) and ( ( Leader^.G <> GG_Character ) or ( NAttValue( Leader^.NA , NAG_CharDescription , NAS_CharType ) <> 0 ) ) do Leader := Leader^.Next;
	if Leader = Nil then Exit;

	FName := Save_Character_Base + GearName(Leader) + Default_File_Ending;
	Assign( F , FName );
	Rewrite( F );
	WriteCGears( F , PC );
	Close( F );
end;

Function SelectMode: Integer;
	{ Prompt the user for a mode selection. }
var
	RPM: RPGMenuPtr;
	G: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );

	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_SMOp0' ) , 0 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_SMOp1' ) , 1 );
{$IFDEF SDLMODE}
	RCPromptMessage := MsgString( 'RANDCHAR_SMPrompt' );
	RCDescMessage := MsgString( 'RANDCHAR_SMDesc' );
	RCCaption := '';
	G := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
	CMessage( MsgString( 'RANDCHAR_SMPrompt' ) , ZONE_CharGenPrompt , InfoHilight );
	GameMsg( MsgString( 'RANDCHAR_SMDesc' ) , ZONE_CharGenDesc , InfoGreen );
	G := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );
	SelectMode := G;
end;

Function SelectGender: Integer;
	{ Prompt the user for a gender selection. }
var
	RPM: RPGMenuPtr;
	G: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );

	AddRPGMenuItem( RPM , GenderName[ NAV_Male ] , NAV_Male );
	AddRPGMenuItem( RPM , GenderName[ NAV_Female ] , NAV_Female );
{$IFDEF SDLMODE}
	RCDescMessage := MsgString( 'RANDCHAR_SGDesc' );
	RCPromptMessage := MsgString( 'RANDCHAR_SGPrompt' );
	RCCaption := '';
	G := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
	GameMsg( MsgString( 'RANDCHAR_SGDesc' ) , ZONE_CharGenDesc , InfoGreen );
	CMessage( MsgString( 'RANDCHAR_SGPrompt' ) , ZONE_CharGenPrompt , InfoGreen );
	G := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );

{$IFNDEF SDLMODE}
	ClrZone( ZONE_CharGenPrompt );
	ClrZone( ZONE_CharGenDesc );
{$ENDIF}

	SelectGender := G;
end;

Function SelectAge: Integer;
	{ Prompt the user for character age. }
var
	RPM: RPGMenuPtr;
	T: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );

	for t := -4 to 10 do begin
		AddRPGMenuItem( RPM , BStr( T + 20 ) + ' years old' , T );
	end;

{$IFDEF SDLMODE}
	RCDescMessage := MsgString( 'RANDCHAR_SADesc' );
	RCPromptMessage := MsgString( 'RANDCHAR_SAPrompt' );
	RCCaption := '';
	T := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
	GameMsg( MsgString( 'RANDCHAR_SADesc' ) , ZONE_CharGenDesc , InfoGreen );
	CMessage( MsgString( 'RANDCHAR_SAPrompt' ) , ZONE_CharGenPrompt , InfoGreen );
	T := SelectMenu( RPM );
{$ENDIF}
	DisposeRPGMenu( RPM );
	SelectAge := T;
end;

Procedure GenerateFamilyHistory( PC: GearPtr; var Cash: LongInt; CanEdit: Boolean );
	{ Roll for jobs for both parents. }
const
	Parental_XP = 210;
var
	RPM: RPGMenuPtr;
	JobList,F,M: SAttPtr;
	N: Integer;
	Bio1: String;
{ Procedures block. }
	Procedure ApplyParentalBonus( SA: SAttPtr );
	var
		skills: Array [1..8] of integer;
		B: String;
		N,T: Integer;
	begin
		{ Error check - SA might be NIL. }
		{ Extract the bonus string. }
		if SA <> Nil then B := RetrieveAString( SA^.Info )
		else B := '';

		{ See what's in there. }
		N := 0;
		for t := 1 to 8 do begin
			skills[t] := ExtractValue( B );
			if skills[t] > 0 then Inc( N );
		end;

		{ Apply bonuses. }
		if N > 0 then begin
			for t := 1 to 8 do begin
				if skills[ t ] > 0 then AddNAtt( PC^.NA , NAG_Experience , NAS_Skill_XP_Base + skills[ t ] , Parental_XP div N );
			end;
		end else begin
			AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , ( Parental_XP * 2 ) div 3 );
		end;
	end;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_FHAccept' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_FHDecline' ) , -1 );

	if CanEdit then begin
{$IFDEF SDLMODE}
		RCPromptMessage := MsgString( 'RANDCHAR_FHPrompt' );
		RCDescMessage := MsgString( 'RANDCHAR_FHDesc' );
		RCCaption := '';
{$ELSE}
		CMessage( MsgString( 'RANDCHAR_FHPrompt' ) , ZONE_CharGenPrompt , InfoHilight );
		GameMsg( MsgString( 'RANDCHAR_FHDesc' ) , ZONE_CharGenDesc , InfoGreen );
{$ENDIF}
	end;

	JobList := LoadStringList( Jobs_File );

	repeat
		{ Decide upon the family history here, giving skill points }
		{ and whatever. }

		{ Determine the jobs of both the father and the mother. }
		if Random(3) <> 1 then F := SelectRandomSAtt( JobList )
		else F := Nil;
		if Random(3) <> 1 then M := SelectRandomSAtt( JobList )
		else M := Nil;

		if ( F <> Nil ) and ( M <> Nil ) then begin
			{ Both father and mother had jobs worth mentioning. }
			if F = M then begin
				Bio1 := MsgString( 'RANDCHAR_FHBothParents1' ) + RetrieveAPreamble( F^.Info ) + MsgString( 'RANDCHAR_FHBothParents2' );
			end else if Random( 2 ) = 1 then begin
				Bio1 := MsgString( 'RANDCHAR_FM1' ) + RetrieveAPreamble( F^.Info );
				Bio1 := Bio1 + MsgString( 'RANDCHAR_FM2' ) + RetrieveAPreamble( M^.Info ) + MsgString( 'RANDCHAR_FM3' );
			end else begin
				Bio1 := MsgString( 'RANDCHAR_MF1' ) + RetrieveAPreamble( M^.Info );
				Bio1 := Bio1 + MsgString( 'RANDCHAR_MF2' ) + RetrieveAPreamble( F^.Info ) + MsgString( 'RANDCHAR_MF3' );
			end;
		end else if F <> Nil then begin
			{ Father had a special job; Mother didn't. }
			Bio1 := MsgString( 'RANDCHAR_F1' ) + RetrieveAPreamble( F^.Info ) + MsgString( 'RANDCHAR_F2' );
		end else if M <> Nil then begin
			{ Mother had a special job; Father didn't. }
			Bio1 := MsgString( 'RANDCHAR_M1' ) + RetrieveAPreamble( M^.Info ) + MsgString( 'RANDCHAR_M2' );
		end else begin
			{ Neither father nor mother had a special job. }
			Bio1 := MsgString( 'RANDCHAR_WCF' );
		end;

		{ Display the created biography for the user. }
{$IFDEF SDLMODE}
		SetSAtt( PC^.SA , 'BIO1 <' + Bio1 + '>' );
{$ELSE}
		GameMsg( Bio1 , ZONE_Biography , InfoGreen );
{$ENDIF}

		{ Decide whether to accept or decline this family history. }
		if CanEdit then begin
{$IFDEF SDLMODE}
			N := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
			N := SelectMenu( RPM );
{$ENDIF}
		end else begin
			N := 1;
		end;
	until N = 1;

	ApplyParentalBonus( F );
	ApplyParentalBonus( M );

{$IFNDEF SDLMODE}
	SetSAtt( PC^.SA , 'BIO1 <' + Bio1 + '>' );
	CharacterDisplay( PC , Nil );
{$ENDIF}

	DisposeRPGMenu( RPM );
	DisposeSATt( JobList );
end;

Procedure AllocateStatPoints( PC: GearPtr; StatPt: Integer );
	{ Distribute the listed number of points out to the PC. }
var
	RPM: RPGMenuPtr;
	PCStats: Array [1..NumGearStats] of Integer;
	T: Integer;
	Function StatSelectorMsg( N: Integer ): String;
	var
		msg: String;
	begin
		msg := StatName[ N ];
{$IFDEF SDLMODE}
		while TextLength( Game_Font , msg ) < ( ZONE_CharGenMenu.W - 50 ) do msg := msg + ' ';
{$ELSE}
		while Length( msg ) < 12 do msg := msg + ' ';
{$ENDIF}
		msg := msg + BStr( PCStats[ N ] + PC^.Stat[ N ] );
		StatSelectorMsg := msg;
	end;
begin
	{ Zero out the base stat line, and make sure minimum values are met. }
	for t := 1 to NumGearStats do begin
		PCStats[ T ] := 0;
		if PC^.Stat[ T ] < 1 then begin
			PC^.Stat[ T ] := 1;
			Dec( StatPt );
		end;
	end;

	{ Create the menu & set up the display. }
{$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
{$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_SkillGenMenu );
{$ENDIF}
	RPM^.Mode := RPMNoCleanup;
{$IFDEF SDLMODE}
	RCDescMessage := '';
	RCPromptMessage := MsgString( 'RANDCHAR_ASPPrompt' );
    RCHintMessage := MsgString( 'RANDCHAR_LeftRightHint' );
{$ELSE}
	GameMsg( MsgString( 'RANDCHAR_ASPDesc' ) , ZONE_CharGenDesc , InfoGreen );
	DrawExtBorder( ZONE_SkillGenDesc , BorderBlue );
{$ENDIF}
	for t := 1 to NumGearStats do begin
		AddRPGMenuItem( RPM , StatSelectorMsg( T ) , 1 , MsgString( 'STAT_' + BStr( T ) ) );
	end;
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_ASPDone' ) , 2 );

	RPM^.dtexcolor := InfoGreen;
{$IFDEF SDLMODE}
	AttachMenuDesc( RPM , ZONE_CharGenDesc );
{$ELSE}
	AttachMenuDesc( RPM , ZONE_SkillGenDesc );
{$ENDIF}


	{ Add RPGKeys for the left and right buttons, since these will be }
	{ used to spend & retrieve points. }
{$IFDEF SDLMODE}
	AddRPGMenuKey( RPM , RPK_Right ,  1 );
	AddRPGMenuKey( RPM , RPK_Left , -1 );
{$ELSE}
	AddRPGMenuKey( RPM , KeyMap[ KMC_East ].KCode ,  1 );
	AddRPGMenuKey( RPM , KeyMap[ KMC_West ].KCode , -1 );
{$ENDIF}

	repeat
{$IFDEF SDLMODE}
		RCCaption := MsgString( 'RANDCHAR_ASPCaption' ) + BStr( StatPt );
		T := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
		CMessage( MsgString( 'RANDCHAR_ASPCaption' ) + BStr( StatPt ) , ZONE_CharGenPrompt , InfoHilight );
		T := SelectMenu( RPM );
{$ENDIF}

		if ( T = 1 ) and ( RPM^.selectitem <= NumGearStats ) and ( StatPt > 0 ) then begin
			{ Increase Stat }
			{ Only do this if the player has enough points to do so... }
			if ( StatPt > 1 ) or ( PCStats[ RPM^.selectitem ] < NormalMaxStatValue ) then begin
				{ Increase the stat. }
				Inc( PCStats[ RPM^.selectitem ] );

				{ Decrease the free stat points. Take away 2 if }
				{ this stat has been improved to the normal maximum. }
				Dec( StatPt );
				if PCStats[ RPM^.selectitem ] > NormalMaxStatValue then Dec( StatPt );

				{ Replace the message line. }
				RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := StatSelectorMsg( RPM^.selectitem );
			end;
		end else if ( T = -1 ) and ( RPM^.selectitem <= NumGearStats ) then begin
			{ Decrease Stat }
			if PCStats[ RPM^.selectitem ] > 0 then begin
				{ Decrease the stat. }
				Dec( PCStats[ RPM^.selectitem ] );

				{ Increase the free stat points. Give back 2 if }
				{ this stat has been improved to the normal maximum. }
				Inc( StatPt );
				if PCStats[ RPM^.selectitem ] >= NormalMaxStatValue then Inc( StatPt );

				{ Replace the message line. }
				RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := StatSelectorMsg( RPM^.selectitem );
			end;

		end;

	until T = 2;

	{ Copy temporary values into the PC record. }
	for T := 1 to NumGearStats do PC^.Stat[T] := PC^.Stat[T] + PCStats[T];

	{ Spend remaining stat points randomly. }
	if StatPt > 0 then RollStats( PC , StatPt );

	{ Get rid of the menu. }
	DisposeRPGMenu( RPM );

	{ Clear the menu area. }
{$IFNDEF SDLMODE}
	ClrZone( ZONE_CharGenMenu );
{$ELSE}
    RCHintMessage := '';
{$ENDIF}
end;

Procedure EasyStatPoints( PC: GearPtr; StatPt: Integer );
	{ Allocate the stat points for the PC mostly randomly, making sure there are no }
	{ obvious deficiencies. }
var
	T: Integer;
begin
	{ Every stat needs at least 10 in it. }
	for t := 1 to NumGearStats do begin
		PC^.Stat[ T ] := 10;
		StatPt := StatPt - 10;
	end;

	{ Spend remaining stat points randomly. }
	if StatPt > 0 then RollStats( PC , StatPt );
end;

Function JobCashBonus( JobFX: String ): LongInt;
    { Return the amount of bonus cash this job provides. }
var
    Skill,N: Integer;
begin
	N := 0;

	{ Count how many skills there are. }
	while JobFX <> '' do begin
		Skill := ExtractValue( JobFX );
		if ( Skill > 0 ) and ( Skill <= NumSkill ) then begin
			Inc( N );
		end;
	end;

	{ The fewer skills the PC has, the more cash he'll get. }
	if N < 5 then begin
        JobCashBonus := ( 5 - N ) * 20000;
    end else begin
        JobCashBonus := 0;
    end;
end;

Procedure ApplyJobBonus( PC: GearPtr; var Cash: LongInt; JobString: String );
	{ Apply the bonuses gained from this job to the PC record. }
var
	Skill: Integer;
	FX,Name: String;
begin
	{ Apply skill bonuses. }
	FX := RetrieveAString( JobString );
	Name := RetrieveAPreamble( JobString );
    Cash := Cash + JobCashBonus( FX );

	{ The PC gets a +1 to each job skill. }
	while FX <> '' do begin
		Skill := ExtractValue( FX );
		if ( Skill > 0 ) and ( Skill <= NumSkill ) then begin
			AddNAtt( PC^.NA , NAG_Skill , SKill , 1 );
		end;
	end;

	{ Record the player's job. }
	SetSAtt( PC^.SA , 'JOB <' + Name + '>' );
end;

Procedure RandomJob( PC: GearPtr; var Cash: LongInt );
	{ Select a job from the standard job list, then give out skill points }
	{ and take away cash. }
var
	JobList,Job: SAttPtr;
begin
	JobList := LoadStringList( Jobs_File );

	Job := SelectRandomSAtt( JobList );

	ApplyJobBonus( PC , Cash , Job^.Info );

	DisposeSAtt( JobList );
end;

Procedure SelectJob( PC: GearPtr; var Cash: LongInt );
	{ Select a job from the standard job list, then give out skill points }
	{ and take away cash. }
	Function JobDescription( Job: String ): String;
		{ Return a description for this job: This will be its category }
		{ and its list of skills. }
	var
		fx,msg: String;
		Skill,N: Integer;
        Cash: LongInt;
	begin
    	FX := RetrieveAString( Job );
	    msg := RetrieveAPreamble( Job ) + ': ';
        Cash := JobCashBonus( FX );

		{ Add the skills. }
		N := 0;
        while FX <> '' do begin
    		Skill := ExtractValue( FX );

    		if ( Skill > 0 ) and ( Skill <= NumSkill ) then begin
				if N > 0 then msg := msg + ', ';
				msg := msg + SkillMan[ Skill ].name + '+1';
				inc( N );
			end;
		end;

        if Cash > 0 then begin
            if n > 0 then msg := msg + ', ';
            msg := msg + '+$' + BStr( Cash );
        end;
		JobDescription := msg;
	end;

var
	RPM: RPGMenuPtr;
	JobList,Job: SAttPtr;
	N: Integer;
begin
{$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	AttachMenuDesc( RPM , ZONE_CharGenDesc );
	RCPromptMessage := MsgString( 'RANDCHAR_JobPrompt' );
	RCDescMessage := '';
	RCCaption := '';
{$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_SkillGenMenu );
	AttachMenuDesc( RPM , ZONE_SkillGenDesc );
	CMessage( MsgString( 'RANDCHAR_JobPrompt' ) , ZONE_CharGenPrompt , InfoHilight );
	GameMsg( MsgString( 'RANDCHAR_JobDesc' ) , ZONE_CharGenDesc , InfoGreen );
{$ENDIF}

	JobList := LoadStringList( Jobs_File );

	{ Fill out the menu. }
	N := 1;
	Job := JobList;
	while Job <> Nil do begin
		AddRPGMenuItem( RPM , RetrieveAPreamble( Job^.Info ) , N, JobDescription( Job^.Info ) );
		Inc( N );
		Job := Job^.Next;
	end;
	RPMSortAlpha( RPM );

{$IFDEF SDLMODE}
	N := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
	N := SelectMenu( RPM );
{$ENDIF}

	if N <> -1 then begin
		{ Find the job that was chosen. }
		Job := JobList;
		while N > 1 do begin
			Job := Job^.Next;
			Dec( N );
		end;	

		ApplyJobBonus( PC , Cash , Job^.Info );
    end else begin
        RandomJob( PC, Cash );
	end;

	DisposeRPGMenu( RPM );
	DisposeSAtt( JobList );
end;

Procedure AllocateSkillPoints( PC: GearPtr; SkillPt: Integer );
	{ Distribute the listed number of points out to the PC. }
var
	RPM: RPGMenuPtr;
	PCSkills: Array [1..NumSkill] of Integer;
	T,SkNum: Integer;
	Function SkillSelectorMsg( N: Integer ): String;
	var
		msg: String;
	begin
		msg := SkillMan[ N ].Name;
{$IFDEF SDLMODE}
		while TextLength( Game_Font , msg ) < ( ZONE_CharGenMenu.W - 50 ) do msg := msg + ' ';
{$ELSE}
		while Length( msg ) < 20 do msg := msg + ' ';
{$ENDIF}
		msg := msg + BStr( NAttValue( PC^.NA , NAG_Skill , N ) + PCSkills[ N ] );
		SkillSelectorMsg := msg;
	end;
	Function NumPickedSkills: Integer;
	var
		SkT,NPS: Integer;
	begin
		NPS := 0;
		for SkT := 1 to NumSkill do begin
			if ( NAttValue( PC^.NA , NAG_Skill , SkT ) > 0 ) or ( PCSkills[ Skt ] > 0 ) then Inc( NPS );
		end;
		NumPickedSkills := NPS;
	end;
begin
	{ Zero out the base skill values. }
	for t := 1 to NumSkill do begin
		PCSkills[ T ] := 0;
	end;

	{ Create the menu & set up the display. }
{$IFDEF SDLMODE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
{$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_SkillGenMenu );
{$ENDIF}
	RPM^.Mode := RPMNoCleanup;

{$IFDEF SDLMODE}
	RCDescMessage := '';
	RCPromptMessage := MsgString( 'RANDCHAR_SkillPrompt' );
    RCHintMessage := MsgString( 'RANDCHAR_LeftRightHint' );
{$ELSE}
	GameMsg( MsgString( 'RANDCHAR_SkillDesc' ) , ZONE_CharGenDesc , InfoGreen );
	DrawExtBorder( ZONE_SkillGenDesc , BorderBlue );
{$ENDIF}
	for t := 1 to NumSkill do begin
		AddRPGMenuItem( RPM , SkillSelectorMsg( T ) , T , SkillDesc( T ) );
	end;
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_ASPDone' ) , -2 );

	RPM^.dtexcolor := InfoGreen;
{$IFDEF SDLMODE}
	AttachMenuDesc( RPM , ZONE_CharGenDesc );
{$ELSE}
	AttachMenuDesc( RPM , ZONE_SkillGenDesc );
{$ENDIF}

	{ Add RPGKeys for the left and right buttons, since these will be }
	{ used to spend & retrieve points. }
{$IFDEF SDLMODE}
	AddRPGMenuKey( RPM , RPK_Right ,  1 );
	AddRPGMenuKey( RPM , RPK_Left , -1 );
{$ELSE}
	AddRPGMenuKey( RPM , KeyMap[ KMC_East ].KCode ,  1 );
	AddRPGMenuKey( RPM , KeyMap[ KMC_West ].KCode , -1 );
{$ENDIF}

	repeat
{$IFDEF SDLMODE}
		RCCaption := MsgString( 'RANDCHAR_ASPCaption' ) + BStr( SkillPt );
		T := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
		if TooManySkillsPenalty( PC , NumPickedSkills ) > 0 then begin
			CMessage( MsgString( 'RANDCHAR_ASPCaption' ) + BStr( SkillPt ) , ZONE_CharGenPrompt , EnemyRed );
		end else begin
			CMessage( MsgString( 'RANDCHAR_ASPCaption' ) + BStr( SkillPt ) , ZONE_CharGenPrompt , InfoHilight );
		end;
		T := SelectMenu( RPM );
{$ENDIF}
		if ( T > 0 ) and ( SkillPt > 0 ) then begin
			{ Increase Skill }
			{ Figure out which skill we're changing... }
			SkNum := RPMLocateByPosition(RPM , RPM^.selectitem )^.value;

			{ Only increase if the skill < 10... }
			if ( SkNum > 0 ) and ( SkNum <= NumSkill ) and ( PCSkills[ SkNum ] < MaxStartingSkill ) and ( SkillPt >= PCSkills[ SkNum ] ) then begin
				if PCSkills[ SkNum ] = 0 then begin
					Dec( SkillPt );
				end else begin
					SkillPt := SkillPt - PCSkills[ SkNum ];
				end;
				Inc( PCSkills[ SkNum ] );

				{ Replace the message line. }
				RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := SkillSelectorMsg( SkNum );
			end; 

		end else if ( T = -1 ) then begin
			{ Decrease Skill }
			{ Figure out which skill we're changing... }
			SkNum := RPMLocateByPosition(RPM , RPM^.selectitem )^.value;

			{ Only decrease if the skill > 0... }
			if ( SkNum > 0 ) and ( SkNum <= NumSkill ) and ( PCSkills[ SkNum ] > 0 ) then begin
				if PCSkills[ SkNum ] = 1 then begin
					Inc( SkillPt );
				end else begin
					SkillPt := SkillPt + PCSkills[ SkNum ] - 1;
				end;
				Dec( PCSkills[ SkNum ] );

				{ Replace the message line. }
				RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := SkillSelectorMsg( SkNum );
			end; 

		end;

	until T = -2;

	{ Copy temporary values into the PC record. }
	for T := 1 to NumSkill do AddNAtt( PC^.NA , NAG_Skill , T , PCSkills[T] );

	{ Convert remaining skill points into experience points. }
	if SkillPt > 0 then AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , SkillPt * 100 );

	{ Get rid of the menu. }
	DisposeRPGMenu( RPM );

	{ Clear the menu area. }
{$IFNDEF SDLMODE}
	ClrZone( ZONE_CharGenMenu );
{$ELSE}
    RCHintMessage := '';
{$ENDIF}
end;

Procedure RandomSkillPoints( PC: GearPtr; SkillPt: Integer );
	{ Allocate out some sensible skill points to hopefully keep this beginning character }
	{ alive. }
const
	NumBeginnerSkills = 13;
	BeginnerSkills: Array [1..NumBeginnerSkills] of Byte = (
		11, 12, 13, 14, 15,
		18, 20, 21, 23, 25,
		26, 30, 33
	);
	PointsForLevel: Array [1..5] of Byte = (
		1,2,4,7,11
	);
	Function CheckLevel( L: Integer ): Integer;
		{ If the requested skill level is too great for the }
		{ number of skill points posessed, reduce it. }
	begin
		if SkillPt < 1 then Exit( 0 );
		while SkillPt < PointsForLevel[ L ] do Dec( L );
		CheckLevel := L;
	end;
var
	t,L,tries,X1,X2: Integer;
begin
	{ First give decent Mecha Piloting and Dodge scores. }
	t := Random( 2 ) + 4;
	AddNatt( PC^.NA , NAG_Skill , 5 , T );
	SkillPt := SkillPt - PointsForLevel[ t ];

	t := Random( 2 ) + 4;
	AddNatt( PC^.NA , NAG_Skill , 10 , T );
	SkillPt := SkillPt - PointsForLevel[ t ];

	{ Give some Conversation. }
	t := Random( 3 ) + 1;
	AddNatt( PC^.NA , NAG_Skill , 19 , T );
	SkillPt := SkillPt - PointsForLevel[ t ];

	{ Add combat skills. }
	{ The default character will get three decent combat skills for }
	{ mecha and another three for personal. }
	X1 := Random( 4 ) + 1;
	X2 := Random( 4 ) + 1;
	for t := 1 to 4 do begin
		if T <> X1 then begin
			L := CheckLevel( 2 + Random( 4 ) );
			AddNAtt( PC^.NA , NAG_Skill , T , L );
			if L > 0 then SkillPt := SkillPt - PointsForLevel[ L ];
		end;

		if T <> X2 then begin
			L := CheckLevel( 2 + Random( 3 ) );
			AddNAtt( PC^.NA , NAG_Skill , T + 5 , L );
			if L > 0 then SkillPt := SkillPt - PointsForLevel[ L ];
		end;
	end;

	{ Add miscellaneous skills. }
	tries := 500;
	while ( SkillPt > 0 ) and ( tries > 0 ) do begin
		Dec( tries );
		t := BeginnerSkills[ Random( NumBeginnerSkills ) + 1 ];
		if NAttValue( PC^.NA , NAG_Skill , T ) <= 1 then begin
			L := CheckLevel( 3 + Random( 3 ) );
			AddNAtt( PC^.NA , NAG_Skill , T , L );
			SkillPt := SkillPt - PointsForLevel[ L ];
		end;
	end;

	if SkillPt > 0 then AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , SkillPt * 100 );
end;

Procedure SetTraits( PC: GearPtr );
	{ Set some personality traits for the PC. }
var
	RPM: RPGMenuPtr;
	N,Traits: Integer;
begin
	{ Create the menu and set up the display. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	RPM^.Mode := RPMNoCleanup;
{$IFDEF SDLMODE}
	RCDescMessage := MsgString( 'RANDCHAR_STDesc' );
{$ELSE}
	GameMsg( MsgString( 'RANDCHAR_STDesc' ) , ZONE_CharGenDesc , InfoGreen );
{$ENDIF}

	{ Add the personality traits to the menu. There are two traits which }
	{ cannot be selected at the time of character generation and instead }
	{ have to be earned through play- Heroic/Villainous and Renowned/Wangtta. }
	{ v0.850: Lawful/Chaotic cannot be set at the start of play either. }
	for N := 3 to Num_Personality_Traits do begin
		if N <> Abs( NAS_Renowned ) then begin
			{ Store the positive traits as 1... , }
			{ the negative ones as 1+Num_Personality_Traits... }
			AddRPGMenuItem( RPM , PTraitName[ N , 1 ] , N );
			AddRPGMenuItem( RPM , PTraitName[ N , 2 ] , N + Num_Personality_Traits );
		end;
	end;
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_STCancel' ) , -1 );

	Traits := 3;
	repeat
{$IFDEF SDLMODE}
		RCPromptMessage := MsgString( 'RANDCHAR_STPrompt' );
        RCCaption := MsgString( 'RANDCHAR_STCaption' ) + BStr( Traits );
		N := SelectMenu( RPM , @RandCharRedraw );
{$ELSE}
		CMessage( MsgString( 'RANDCHAR_STPrompt' ) + BStr( Traits ) , ZONE_CharGenPrompt , InfoHilight );
		N := SelectMenu( RPM );
{$ENDIF}

		if N > Num_Personality_Traits then begin
			{ The PC is placing negative points into this trait. }
			N := N - Num_Personality_Traits;
			AddNAtt( PC^.NA , NAG_CharDescription , -N , -25 );
			Dec( Traits );

		end else if N > 0 then begin
			{ The PC is placing positive points into this trait. }
			AddNAtt( PC^.NA , NAG_CharDescription , -N , 25 );
			Dec( Traits );

		end;

	until ( N = -1 ) or ( Traits = 0 );

	{ Get rid of the menu. }
	DisposeRPGMenu( RPM );

	{ Clear the menu area. }
{$IFNDEF SDLMODE}
	ClrZone( ZONE_CharGenMenu );
{$ENDIF}
end;

{$IFDEF SDLMODE}
Procedure SelectSprite( PC: GearPtr );
	{ Select a sprite for the PC's portrait. }
var
	RPM: RPGMenuPtr;
	PList: SAttPtr;
	P,N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_NextPicture' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_LastPicture' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_AcceptPicture' ) , -1 );

	if NAttValue( PC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
		PList := CreateFileList( Graphics_Directory + 'por_m_*.*' );
	end else begin
		PList := CreateFileList( Graphics_Directory + 'por_f_*.*' );
	end;

	RCDescMessage := '';
	RCPromptMessage := MsgString( 'RANDCHAR_PicturePrompt' );
	RCCaption := '';
	P := Random( NumSAtts( PList ) ) + 1;

	repeat
		CleanSpriteList;
		SetSAtt( PC^.SA , 'SDL_PORTRAIT <' + RetrieveSAtt( PList , P )^.Info + '>' );
		N := SelectMenu( RPM , @RandCharRedraw );

		if N = 1 then begin
			Inc( P );
			if P > NumSatts( PList ) then P := 1;
		end else if N = 2 then begin
			Dec( P );
			if P < 1 then P := NumSatts( PList );
		end;
	until N = -1;
	DisposeSAtt( PList );
	DisposeRPGMenu( RPM );
end;
{$ENDIF}

Function CharacterCreator: GearPtr;
	{ This is my brand-spankin' new character generator. It is meant }
	{ to emulate the interactive way in which characters are generated }
	{ for such games as Mekton and Traveller. }
const
	MODE_Regular = 1;
	MODE_Easy = 0;
var
	PC: GearPtr;
	M: Integer;
	N,StatPt,SkillPt,Cash: LongInt;
	name: String;
begin
	ClrScreen;
	DrawCharGenBorder;

	M := SelectMode;
	if M = -1 then Exit( Nil );

	{ Start by allocating the PC record. }
	PC := NewGear( Nil );
	PC^.G := GG_Character;
	InitGear( PC );
	StatPt := 100;
	SkillPt := 50;
	Cash := 35000;
{$IFDEF SDLMODE}
    SetSAtt( PC^.SA, 'SDL_PORTRAIT <por_x_silhouette.png>' );
    SetSAtt( PC^.SA, 'SDL_COLORS <' + RandomColorString(CS_Clothing) + ' ' + RandomColorString(CS_Skin) + ' ' + RandomColorString(CS_Hair) + '>' );
{$ENDIF}

	{ First select gender, keeping in mind that the selection may be }
	{ cancelled. }
	N := SelectGender;
	if N = -1 then begin
		DisposeGear( PC );
		Exit( Nil );
	end else begin
		SetNAtt( PC^.NA , NAG_CharDescription , NAS_Gender , N );
	end;
{$IFNDEF SDLMODE}
	CharacterDisplay( PC , Nil );
{$ENDIF}

	{ Next select age. }
	if M = MODE_Regular then begin
		N := SelectAge;
		SetNAtt( PC^.NA , NAG_CharDescription , NAS_DAge , N );
{$IFNDEF SDLMODE}
		CharacterDisplay( PC , Nil );
{$ENDIF}
	end else begin
		N := Random( 10 ) - Random( 5 );
		SetNAtt( PC^.NA , NAG_CharDescription , NAS_DAge , N );
	end;

	{ Adjust cash & free skill points based on Age. }
	AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , ( N + 5 ) * 25 );
	Cash := Cash - N*3000;
{$IFDEF SDLMODE}
	RCPC := PC;
{$ENDIF}

	if M = MODE_Regular then begin
		GenerateFamilyHistory( PC , Cash , True );
	end else begin
		GenerateFamilyHistory( PC , Cash , False );
	end;
{$IFNDEF SDLMODE}
	CharacterDisplay( PC , Nil );
{$ENDIF}

	{ Allocate stat points. }
	if M = MODE_Regular then begin
		AllocateStatPoints( PC , StatPt );
{$IFNDEF SDLMODE}
		CharacterDisplay( PC , Nil );
{$ENDIF}
	end else begin
		EasyStatPoints( PC , StatPt );
	end;

	{ Select a job. }
	if M = MODE_Regular then begin
		SelectJob( PC , Cash );
{$IFNDEF SDLMODE}
		CharacterDisplay( PC , Nil );
{$ENDIF}
	end else begin
		RandomJob( PC , Cash );
	end;

	{ Allocate skill points. }
	if M = MODE_Regular then begin
		AllocateSkillPoints( PC , SkillPt );
{$IFNDEF SDLMODE}
		CharacterDisplay( PC , Nil );
{$ENDIF}
	end else begin
		RandomSkillPoints( PC , SkillPt );
	end;

	{ Set personality traits. }
	if M = MODE_Regular then begin
		SetTraits( PC );
{$IFNDEF SDLMODE}
		CharacterDisplay( PC , Nil );
{$ENDIF}
	end;

	{ Store cash. }
	if Cash < 1 then Cash := 1;
	Cash := Cash + Random( 100 );
	AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );
{$IFNDEF SDLMODE}
	CharacterDisplay( PC , Nil );
{$ENDIF}

	{ Select a name. }
	{ If no name is entered, this cancels character creation. }
{$IFDEF SDLMODE}
	{ In SDLMode, before selecting a name, finalize the portrait. }
	SelectSprite( PC );
    RCPromptMessage := '';
	name := GetStringFromUser( MsgString( 'RANDCHAR_GetName' ) , @RandCharRedraw );
{$ELSE}
	name := GetStringFromUser( MsgString( 'RANDCHAR_GetName' ) );
{$ENDIF}
	if  Name <> '' then begin
		SetSAtt( PC^.SA , 'name <'+name+'>');
{$IFNDEF SDLMODE}
		CharacterDisplay( PC , Nil );
{$ENDIF}
	end else begin
		DisposeGear( PC );

	end;

{$IFDEF SDLMODE}
	RCPC := Nil;
{$ENDIF}

	{ Clear the screen, and return the PC. }
	ClrScreen;
	CharacterCreator := PC;
end;

Procedure GenerateNewPC;
	{ Call the character creator, and save the resultant }
	{ character to disk. }
var
	PC: GearPtr;
begin
	PC := CharacterCreator;
	if PC <> Nil then begin
		{ Write this character to disk. }
		SaveChar( PC );

		{ Get rid of the PC gear. }
		DisposeGear( PC );
	end;
end;

end.
