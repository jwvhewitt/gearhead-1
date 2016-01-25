**************************
***  GEARHEAD  README  ***
**************************

Welcome to GearHead. This is, as far as I know, the world's first roguelike
mecha role playing game. I hope you enjoy playing it.

You may find the game a bit confusing at first. If you've played other
roguelike games (Moria, Angband, ADOM) or other mecha games (MechFight,
Titans of Steel, Power Dolls) before, you'll be less confused. If you're
familiar with both types of game then you may even feel right at home.
The file doc/introduction.txt has some information and hints for new
players.

If you can't find the information you need, check the 'doc/' directory.
If you're still lost you can check the wiki or the forum:

  http://gearhead.chaosforge.org/wiki/index.php?title=GearHead
  http://gearhead.chaosforge.org/forum/

**********************
***  INSTALLATION  ***
**********************

Unzip the game files to a directory on your hard drive. That should be
just about all you need to do.

If you are upgrading from a previous version of GearHead, delete the
"Series" directory before installing the new package.

If you are installing the SDL version, things get a bit more
complicated. You'll also need to download and install the image files,
and the SDL libraries. The image files go in the directory
"gearhead/image" alongside "gearhead/series", "gearhead/design", and all
the other game directories. You'll also need to install the runtime
libraries for SDL, SDL_Image, and SDL_ttf. These should be included for
the Windows compile of the game; for Linux you can download them from
www.libsdl.org. You can unzip the dll's to the same directory as
"arena.exe", or install them in your System folder.

****************************
***  THE  GAME  DISPLAY  ***
****************************

MAP WINDOW

	This is the big area with the cyan border.

INFORMATION WINDOW

	This is the small area in the upper right corner of the screen.
	Here you will find the vital stats for your character, or whatever
	you happen to be looking at.

	Below the name in the information window are some useful indicators.
	Starting at the left is the position indicator; the white '+' shows
	what direction you are facing, while the number in the center
	indicates your elevation. If the number is blue, it indicates your
	depth underwater.

	Nest to the position indicator should be a damage indicator. For
	characters, this will just show your health points. For mecha, the
	damage indicator shows a schematic of all the mecha's parts
	indicating which bits have taken the most punishment.

MENU WINDOW

	Beneath the information window is the menu window. This is where
	the control menus will appear.

CLOCK WINDOW

	Beneath the menu window is the clock. This will show the current
	game time. GearHead uses a clock-based game engine. Any action your
	character can perform takes a certain amount of time. Once a
	command is entered the clock advances until the action is completed
	and control is returned to the player.

	If you've played either MechForce or Titans of Steel you should be
	familiar with this control type already. If you've played any of the
	Final Fantasy games with the combat pause option on you should be
	able to figure it out pretty quickly.

MESSAGE WINDOW

	The message window is meant to provide the narration for GearHead,
	though at the moment it's mostly sleeping on the job and spouting
	cryptic acronyms. I will work on making this window more useful...


**********************************
***  CONTROLLING  YOUR  MECHA  ***
**********************************

There are an awful lot of different movement and attack options
in this game. Characters are controlled through a hopefully-familiar
roguelike interface, while mecha are controlled using a menu interface
similar to the one used in the old Amiga MechFight game (and more
recently in Titans of Steel).

MOVEMENT MENU

	This is the top layer of the menus.

	A mecha can travel at two speeds- CRUISE SPEED and FULL SPEED.
	While traveling at FULL SPEED, the mecha moves faster than
	normal, but it recieves a significant penalty to its attack
	rolls.

	WALKING is, in general, a slow way to move around. However, it
	does have several advantages. Turns can be made very quickly
	in this move mode. Also, walking mecha are better able to deal
	with rough terrain.

	ROLLING mecha use wheels or treads to move about. This move
	mode is faster than WALKING, but usually slower than SKIMMING.
	Mechas using this mode are more strongly affected by terrain.
	They have a harder time passing difficult terrain, but receive
	a greater speed bonus when traveling on roads.

	SKIMMING mecha hover several meters off the ground. They may pass
	over low obstacles without slowing down, and may fly across the
	surface of bodies of water.


WEAPONS MENU

	From here you should see a list of all the weapons your mecha
	is equipped with. You can select a weapon, then select a target
	to fire at.

	When a weapon is fired, it cannot be used again for a short
	period of time. Most weapons will recharge in 30 clicks, though
	some will be faster or slower.

	CALLED SHOT: If this option is set to "ON", the player will be
	able to select which part of the enemy mecha he wishes to
	hit. It is more difficult to make a called shot than it is to
	make a regular shot.

	WAIT FOR RECHARGE: Sometimes there will not be any weapons
	available to fire with. Select this option to wait until your
	next weapon recharges.

	OPTIONS: This will take you to the game options menu. You can
	select either menu-based or roguelike control. Note that when
	changing control type, it may be necessary to enter one last
	action in the previously selected control mode before the change
	will take effect.

	BALLISTIC WEAPON BV, ENERGY WEAPON BV, and MISSILE BV allow you
	to set the rapid fire settings for ballistic weapons, energy beam
	weapons, and missile launchers. The value selected for MISSILE BV
	indicates what fraction of the total missile payload will be
	fired in each salvo. So, if a missile launcher contains 20
	missiles and the BV is set to 1/4, five missiles will be launched
	when it is fired.


************************
***   DISTRIBUTION   ***
************************

GearHead: Arena is distributed under the terms of the LGPL. See "license.txt"
for more details.

pyrrho12@yahoo.ca
http://gearhead.roguelikedevelopment.org/

