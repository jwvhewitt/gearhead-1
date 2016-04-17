{
   This file, included from congfx.pp, enables use of the Code Page #437 box
   drawing characters in the MSDOS and Win32-console platforms.

   It is seperated so that it can be easily replaced by a patch to enable
   boxdrawing on other platforms.

   If a flag NEEDSHIFTS is defined here, congfx.pp will bracket usage of
   the boxdrawing characters with calls to procedures ShiftAltCharset and
   ShiftNormalCharset.  Those procedures don't exist in vanilla gearhead
   or the FPC libraries, but the calls provide a hook useful in
   implementing boxdrawing on VT110-like terminals. (eg: Linux console and
   Xterm)
}

Const

{$IFDEF go32v2}
{$DEFINE use_cp437}
{$ELSE}
{$IFDEF win32}
{$DEFINE use_cp437}
{$ENDIF}
{$ENDIF}

	BoxUpperLeft_I18N = '+';
	BoxUpperRight_I18N = '+';
	BoxLowerLeft_I18N = '+';
	BoxLowerRight_I18N = '+';
	BoxHorizontal_I18N = '-';
	BoxVertical_I18N = '|';
	BoxSeperator_I18N = '~';

{$IFDEF use_cp437}
	BoxUpperLeft = #218;
	BoxUpperRight = #191;
	BoxLowerLeft = #192;
	BoxLowerRight = #217;
	BoxHorizontal = #196;
	BoxVertical = #179;
	BoxSeperator = #196;
{$ELSE}
	BoxUpperLeft = '+';
	BoxUpperRight = '+';
	BoxLowerLeft = '+';
	BoxLowerRight = '+';
	BoxHorizontal = '-';
	BoxVertical = '|';
	BoxSeperator = '~';
{$ENDIF}
