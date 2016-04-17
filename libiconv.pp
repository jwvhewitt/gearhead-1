unit libiconv;
{*******************************}
{	iconv wrapper		}
{	Wed,27 Feb,2008		}
{*******************************}
{example:
uses unixtype,libiconv;
Function NewConvUni( const pmsg: PChar ): PWord;
const
	WCLen = 512;
var
	src_len, dst_len: size_t;
	pdst: PChar;
	psrc_tmp, pdst_tmp: PChar;
	iconv_enc2utf16: iconv_t;
	iconv_result: size_t;
begin
	pdst := StrAlloc( WCLen );
	src_len := Length(pmsg);
	dst_len := WCLen - 2;
	psrc_tmp := pmsg;
	pdst_tmp := pdst;
	iconv_enc2tenc := libiconv.iconv_open( "EUCJP", "UTF-8" );
	iconv_result := libiconv.iconv( iconv_enc2utf16,
				@psrc_tmp, @src_len, @pdst_tmp, @dst_len );
	iconv_result := libiconv.iconv( iconv_enc2utf16,
				NIL, NIL, @pdst_tmp, @dst_len );
	pdst_tmp[0] := #0; pdst_tmp[1] := #0;
	NewConvUni := PWord(pdst);
	libiconv.iconv_close( iconv_enc2utf16 );
end;
}
{*******************************}

{$MODE FPC}

interface

{$IF DEFINED(UNIX)}
uses pthreads, baseunix, unix, unixtype;
{$ELSEIF DEFINED(WINDOWS)}
uses windows, JwaWinType;
{$ENDIF}


type
{{$IF DEFINED(WIN32)}}
{	Psize_t = ^size_t;}
{	size_t = LongWord;}
{{$ELSEIF DEFINED(WIN64)}}
{	Psize_t = ^size_t;}
{	size_t = QWord;}
{{$ENDIF}}
	Piconv_t = ^iconv_t;
	iconv_t = pointer;


const
{$IF DEFINED(LIBC_ICONV)}
	libiconvname='c';
{$ELSEIF DEFINED(LIBICONV_ICONV)}
	libiconvname='iconv';
{$ELSEIF DEFINED(FREEBSD)}
	libiconvname='iconv';
{$ELSEIF DEFINED(BSD)}
	libiconvname='iconv';
{$ELSEIF DEFINED(LINUX)}
	libiconvname='c';
{$ELSEIF DEFINED(UNIX)}
	libiconvname='iconv';
{$ELSEIF DEFINED(WINDOWS)}
	libiconvname='iconv.dll';
{$ELSE}
	libiconvname='iconv';
{$ENDIF}
{$IF DEFINED(LIBICONV_PLUG)}
	libiconv_functionname_iconv_open	= 'iconv_open';
	libiconv_functionname_iconv		= 'iconv';
	libiconv_functionname_iconv_close	= 'iconv_close';
{$ELSEIF DEFINED(LIBICONV_NOPLUG)}
	libiconv_functionname_iconv_open	= 'libiconv_open';
	libiconv_functionname_iconv		= 'libiconv';
	libiconv_functionname_iconv_close	= 'libiconv_close';
{$ELSEIF DEFINED(FREEBSD)}	{ libiconv-1.14_9 package or later package }
	libiconv_functionname_iconv_open	= 'iconv_open';
	libiconv_functionname_iconv		= 'iconv';
	libiconv_functionname_iconv_close	= 'iconv_close';
{$ELSEIF DEFINED(BSD)}		{ libiconv-1.14_8 package or before package }
	libiconv_functionname_iconv_open	= 'libiconv_open';
	libiconv_functionname_iconv		= 'libiconv';
	libiconv_functionname_iconv_close	= 'libiconv_close';
{$ELSEIF DEFINED(LINUX)}
	libiconv_functionname_iconv_open	= 'iconv_open';
	libiconv_functionname_iconv		= 'iconv';
	libiconv_functionname_iconv_close	= 'iconv_close';
{$ELSEIF DEFINED(UNIX)}
	libiconv_functionname_iconv_open	= 'libiconv_open';
	libiconv_functionname_iconv		= 'libiconv';
	libiconv_functionname_iconv_close	= 'libiconv_close';
{$ELSEIF DEFINED(WINDOWS)}
	libiconv_functionname_iconv_open	= 'libiconv_open';
	libiconv_functionname_iconv		= 'libiconv';
	libiconv_functionname_iconv_close	= 'libiconv_close';
{$ELSE}
	libiconv_functionname_iconv_open	= 'libiconv_open';
	libiconv_functionname_iconv		= 'libiconv';
	libiconv_functionname_iconv_close	= 'libiconv_close';
{$ENDIF}



function iconv_open( __tocode: Pchar; __fromcode: Pchar ): iconv_t;
cdecl; external libiconvname name libiconv_functionname_iconv_open;

function iconv( __cd: iconv_t; __inbuf: PPchar; __inbytesleft: Psize_t; __outbuf: PPchar; __outbytesleft: Psize_t ): size_t;
cdecl; external libiconvname name libiconv_functionname_iconv;

function iconv_close( __cd: iconv_t ): longint;
cdecl; external libiconvname name libiconv_functionname_iconv_close;



implementation

end.
