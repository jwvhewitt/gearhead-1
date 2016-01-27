program cosplay2;

uses gears,sdlgfx,sdlmenus,colormenu;

Procedure RedrawOpening;
	{ The opening menu redraw procedure. }
begin
	ClrScreen;
	ClearExtendedBorder( ZONE_Menu );
end;

Procedure BrowseByType( FPat: String; ColorMode: Integer );
	{ Browse the images by file pattern and color mode. }
var
	FileMenu: RPGMenuPtr;
	SpriteName: String;
begin
	FileMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( FileMenu , Graphics_Directory + FPat );
	RPMSortAlpha( FileMenu );
	SpriteName := '';

	repeat
		SpriteName := SelectFile( FileMenu , @RedrawOpening );
		if SpriteName <> '' then SelectColorPalette( ColorMode, SpriteName, '200 0 0 200 200 0 0 200 0', 211, 308, 0, @ClrScreen );
	until SpriteName = '';

	DisposeRPGMenu( FileMenu );
end;

var
	FileMenu: RPGMenuPtr;
	N: Integer;

begin
	FileMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );

	AddRPGMenuItem( FileMenu , 'Browse Portraits' , 1 );
	AddRPGMenuItem( FileMenu , 'Browse Mecha' , 2 );
	AddRPGMenuItem( FileMenu , 'Browse Monsters' , 3 );
	AddRPGMenuItem( FileMenu , 'Browse All' , 4 );

	repeat
		N := SelectMenu( FileMenu , @RedrawOpening );
		case N of
			1: BrowseByType( 'por_*.png' , colormenu_mode_character );
			2: BrowseByType( 'item_*.png' , colormenu_mode_mecha );
			3: BrowseByType( 'monster_*.png' , colormenu_mode_allcolors );
			4: BrowseByType( '*.png' , colormenu_mode_allcolors );
		end;

	until N = -1;

	DisposeRPGMenu( FileMenu );
end.
