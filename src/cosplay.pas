program cosplay2;

uses gears,sdlgfx,sdlmenus,colormenu,sdl;

Procedure RedrawOpening;
	{ The opening menu redraw procedure. }
begin
	ClrScreen;
	ClearExtendedBorder( ZONE_Menu.GetRect() );
end;

Procedure BrowseByType( FPat: String; width,height,frames,ColorMode: Integer );
	{ Browse the images by file pattern and color mode. }
var
	FileMenu: RPGMenuPtr;
	SpriteName: String;
begin
	FileMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
    if FPat = '' then begin
        { We want all the mecha. All of them!!! }
        BuildFileMenu( FileMenu , Graphics_Directory + 'aer_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'ara_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'btr_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'gca_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'ger_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'ghu_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'hov_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'orn_*.png' );
        BuildFileMenu( FileMenu , Graphics_Directory + 'zoa_*.png' );

    end else BuildFileMenu( FileMenu , Graphics_Directory + FPat );
	RPMSortAlpha( FileMenu );
    AddRPGMenuItem( FileMenu, MsgString( 'EXIT' ), -1 );
	SpriteName := '';

	repeat
		SpriteName := SelectFile( FileMenu , @RedrawOpening );
		if SpriteName <> '' then SelectColorPalette( ColorMode, SpriteName, '200 0 0 200 200 0 0 200 0', width, height, frames, @ClrScreen );
	until SpriteName = '';

	DisposeRPGMenu( FileMenu );
end;

var
	FileMenu: RPGMenuPtr;
	N: Integer;
    MySprite: SensibleSpritePtr;

begin
	FileMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );

    {MySprite := ConfirmSprite( 'Elisha_Demo.png', '80 40 120 255 230 200 166 47 32', 64, 64 );}
    {SDL_SaveBmp( MySprite^.img , 'out.bmp' );}

	AddRPGMenuItem( FileMenu , 'Browse Portraits' , 1 );
	AddRPGMenuItem( FileMenu , 'Browse Mecha' , 2 );
	AddRPGMenuItem( FileMenu , 'Browse Monsters' , 3 );
	AddRPGMenuItem( FileMenu , 'Browse All' , 4 );

	repeat
		N := SelectMenu( FileMenu , @RedrawOpening );
		case N of
			1: BrowseByType( 'por_*.png' , 100, 150, 0, colormenu_mode_character );
			2: BrowseByType( '' , 64, 64, 8, colormenu_mode_mecha );
			3: BrowseByType( 'monster_*.png' , 64, 64, 8, colormenu_mode_allcolors );
			4: BrowseByType( '*.png' , 211, 308, 0, colormenu_mode_allcolors );
		end;

	until N = -1;



	DisposeRPGMenu( FileMenu );
end.
