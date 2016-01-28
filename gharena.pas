program GHArena;
	{ This program can hopefully be used as a test for all }
	{ the various GEARHEAD units. I want to make a game similar }
	{ to the old Amiga MechFight game, but based on the }
	{ GearHead engine. }

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


{$IFDEF SDLMODE}
{$IFNDEF DEBUG}
{$APPTYPE GUI}
{$ENDIF}
uses gears,sdlgfx,arenahq,sdlmenus,randchar,navigate,sdlmap;
{$ELSE}
uses gears,congfx,arenahq,conmenus,randchar,navigate,context,mapedit;
{$ENDIF}

const
	Version = '1.100';

var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	AddRPGMenuItem( RPM , 'Start RPG Campaign' , 4 );
	AddRPGMenuItem( RPM , 'Load RPG Campaign' , 5 );
{$IFNDEF SDLMODE}
	AddRPGMenuItem( RPM , 'New Arena Unit' , 1 );
	AddRPGMenuItem( RPM , 'Load Arena Unit' , 2 );
{$ENDIF}
	AddRPGMenuItem( RPM , 'Create Character' , 3 );
{$IFNDEF SDLMODE}
	AddRPGMenuItem( RPM , 'Edit Map' , 6 );
{$ENDIF}
	AddRPGMenuItem( RPM , 'View Design Files' , 7 );
	AddRPGMenuItem( RPM , 'Quit Game' , -1 );

	repeat
		ClrScreen;

		{ Get rid of the console history from previous games. }
		DisposeSAtt( Console_History );

		CMessage( 'GearHead Arena v' + Version, ZONE_Map, InfoHilight );
		if not STARTUP_OK then DialogMsg( 'ERROR: Main game directories not found. Please check installation of the game.' );
{$IFDEF SDLMODE}
		PrepOpening;
		N := SelectMenu( RPM , @RedrawOpening );
{$ELSE}
		N := SelectMenu( RPM );
{$ENDIF}

		case N of
			1:	CreateNewUnit;
			2:	LoadUnit;
			3:	GenerateNewPC;
			4:	StartRPGCampaign;
			5:	RestoreCampaign;
{$IFNDEF SDLMODE}
			6:	EditMap;
{$ENDIF}
			7:	DesignDirBrowser;
		end;
	until N = -1;

	{deallocate all dynamic resources.}
	DisposeRPGMenu( RPM );
end.
