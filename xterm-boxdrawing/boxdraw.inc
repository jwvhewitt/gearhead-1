{
   This file, included from congfx.pp, enables use of VT110-style line
   drawing graphics.  It is dependent on a hacked version of the CRT
   library that exports two special functions, ShiftAltCharset and
   ShiftNormalCharset.  Calls to these functions in congfx.pp are
   activated by the NeedShifts define below.
}

Const

	BoxUpperLeft = 'l';
	BoxUpperRight = 'k';
	BoxLowerLeft = 'm';
	BoxLowerRight = 'j';
	BoxHorizontal = 'q';
	BoxVertical = 'x';
	BoxSeperator = 'q';

{$DEFINE NeedShifts}
