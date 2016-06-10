unit termenc;

interface

uses sysutils,
{$IF DEFINED(VER2) or not DEFINED(UNIX) or DEFINED(USE_ICONV_SUBSTITUTE_WRAPPER)}
	libiconv
{$ELSE}
	iconvenc
{$ENDIF}
	;


type
	enc_type = (ENC_UNKNOWN, SINGLEBYTE, EUCJP, EUCKR, EUCCN, EUCTW, UTF8, SJIS, CP932);


const
	SENC: enc_type = ENC_UNKNOWN;
	SYSTEM_CHARSET: String = '';

	{ A conversion charset for the terminal. }
	TENC: enc_type = ENC_UNKNOWN;
	TERMINAL_CHARSET: String = '';

	TERMINAL_bidiRTL: Boolean = False;
	TERMINAL_bidiRTL_Punctuation: String = '';
	TERMINAL_bidiRTL_ConvPair1: String = '';
	TERMINAL_bidiRTL_ConvPair2: String = '';

	{ A conversion charset for SDL_TTF.TTF_RenderUnicode_Solid(). }
	UNICODE_CHARSET = 'UTF-16LE';


var
	{ Conversion tables for the terminal. }
	iconv_enc2tenc: iconv_t;
	iconv_tenc2enc: iconv_t;

	{ Conversion tables for SDL_TTF.TTF_RenderUnicode_Solid(). }
	iconv_enc2utf16: iconv_t;
	iconv_utf16toenc: iconv_t;



implementation

uses i18nmsg,texutil;


Function Parse_EncType( const encoding: String; var charset: String ): enc_type;
var
	P1, P2: Integer;
	codec: String;
	encoding_order: Boolean = False;
begin
	Parse_EncType := ENC_UNKNOWN;

	P1 := Pos( '.', encoding );
	if 0 < P1 then begin
		charset := UpCase(Copy( encoding, P1+1, Length(encoding) -P1 ));
	end else begin
		charset := UpCase(encoding);
	end;

	P2 := Pos('-', charset);
	if 0 < P2 then begin
		codec := Copy( charset, 1, P2-1 );
		if ('SINGLEBYTE' = codec) then begin
			Parse_EncType := SINGLEBYTE;
			encoding_order := True;
		end else if ('MULTIBYTE' = codec) then begin
			Parse_EncType := ENC_UNKNOWN;
			encoding_order := True;
		end else if ('2BYTE' = codec) then begin
			Parse_EncType := ENC_UNKNOWN;
			encoding_order := True;
		end;
		if encoding_order then begin
			charset := Copy( charset, P2+1, Length(charset) -P2 );
		end;
	end;
	if (0 = Length(charset)) or ('SINGLEBYTE' = charset) then begin
		charset := 'ISO8859-1';
		Parse_EncType := SINGLEBYTE;
	end else if ('EUCJP' = charset) or ('EUC-JP' = charset) then begin
		Parse_EncType := EUCJP;
	end else if ('EUCKR' = charset) or ('EUC-KR' = charset) then begin
		Parse_EncType := EUCKR;
	end else if ('EUCCN' = charset) or ('EUC-CN' = charset) then begin
		Parse_EncType := EUCCN;
	end else if ('EUCTW' = charset) or ('EUC-TW' = charset) then begin
		Parse_EncType := EUCTW;
	end else if ('UTF-8' = charset) then begin
		Parse_EncType := UTF8;
	end else if ('SJIS' = charset) or ('SHIFT-JIS' = charset) or ('SHIFT_JIS' = charset) then begin
		Parse_EncType := SJIS;
	end else if ('CP932' = charset) or ('MS932' = charset) then begin
		Parse_EncType := CP932;
	end else begin
		Parse_EncType := SINGLEBYTE;
	end;
end;



Procedure Get_senc();
var
	codec: String;
begin
	codec := I18N_Settings('SYSTEM_ENCODING', '');
	SENC := Parse_EncType( codec, SYSTEM_CHARSET );
end;


Procedure Get_tenc();
var
	codec: String;
begin
	codec := '';
	if '' = codec then begin
		codec := GetEnvironmentVariable('GEARHEAD_LANG');
	end;
	if '' = codec then begin
		codec := GetEnvironmentVariable('LC_ALL');
	end;
	if '' = codec then begin
		codec := GetEnvironmentVariable('LC_MESSAGES');
	end;
	if '' = codec then begin
		codec := GetEnvironmentVariable('LOCALE');
	end;
	if '' = codec then begin
		codec := GetEnvironmentVariable('LANGUAGE');
	end;
	if '' = codec then begin
		codec := GetEnvironmentVariable('LANG');
	end;
{$IF DEFINED(WINDOWS)}
	if '' = codec then begin
		codec := I18N_Settings('TERMINAL_ENCODING_DEFAULT_MSWIN','');
	end;
{$ENDIF}
	if '' = codec then begin
		codec := I18N_Settings('TERMINAL_ENCODING_DEFAULT','');
	end;
	if '' = codec then begin
		codec := I18N_Settings('SYSTEM_ENCODING','');
	end;

	if 'C' = UpCase(codec) then begin
		codec := 'ISO8859-1';
	end;

	TENC := Parse_EncType( codec, TERMINAL_CHARSET );

	TERMINAL_bidiRTL := EvaluateTF( I18N_Settings('TERMINAL_ENCODING_CONV_bidiRTL','') );
	TERMINAL_bidiRTL_Punctuation := ' '  + I18N_Settings('bidiRTL_CONVERT_PUNCTUATION','');
	TERMINAL_bidiRTL_ConvPair1   := '< ' + I18N_Settings('bidiRTL_CONVERT_CHAR_PAIR1','');
	TERMINAL_bidiRTL_ConvPair2   := '> ' + I18N_Settings('bidiRTL_CONVERT_CHAR_PAIR2','');
end;



Procedure Get_enc();
var
	err: Boolean = False;
begin
	Get_senc();
	Get_tenc();

	if ENC_UNKNOWN = SENC then begin
		WriteLn('ERROR- Unknown locale "' + SYSTEM_CHARSET + '".');
		err := True;
	end;

	if ENC_UNKNOWN = TENC then begin
		WriteLn('ERROR- Unknown locale "' + TERMINAL_CHARSET + '".');
		err := True;
	end;

	if err then begin
		halt(255);
	end;
end;



Procedure Init_tenc();
var
	tenc_cstr: Array[0..255] of Char;
	senc_cstr: Array[0..255] of Char;
begin
	{ Initialize conversion tables. }
	StrPCopy( tenc_cstr, TERMINAL_CHARSET );
	StrPCopy( senc_cstr, SYSTEM_CHARSET );
	if (CP932 = TENC) and (EUCJP = SENC) then begin
		StrPCopy( senc_cstr, 'EUCJP-MS' );
	end;
	if (CP932 = SENC) and (EUCJP = TENC) then begin
		StrPCopy( tenc_cstr, 'EUCJP-MS' );
	end;
	iconv_enc2tenc := iconv_open( tenc_cstr, senc_cstr );
	iconv_tenc2enc := iconv_open( senc_cstr, tenc_cstr );
	if (iconv_t(-1) = iconv_enc2tenc) or (iconv_t(-1) = iconv_tenc2enc) then begin
		WriteLn('ERROR- termenc initialization failed. (system encoding "' + SYSTEM_CHARSET + '", terminal encoding "' + TERMINAL_CHARSET + '")');
		halt(255);
	end;
end;


Procedure Init_unicode();
var
	uenc_cstr: Array[0..255] of Char;
	senc_cstr: Array[0..255] of Char;
begin
	{ Initialize conversion tables. }
	StrPCopy( uenc_cstr, UNICODE_CHARSET );
	StrPCopy( senc_cstr, SYSTEM_CHARSET );
	iconv_enc2utf16 := iconv_open( uenc_cstr, senc_cstr );
	iconv_utf16toenc := iconv_open( senc_cstr, uenc_cstr );
	if (iconv_t(-1) = iconv_enc2utf16) or (iconv_t(-1) = iconv_utf16toenc) then begin
		WriteLn('ERROR- termenc initialization failed. (system encoding "' + SYSTEM_CHARSET + '", unicode encoding "' + UNICODE_CHARSET + '")');
		halt(255);
	end;
end;



{$IF DEFINED(VER2) or not DEFINED(UNIX) or DEFINED(USE_ICONV_SUBSTITUTE_WRAPPER)}
{$ELSE}
var
	iconvenc_errmsg: AnsiString;
{$ENDIF}

initialization
begin
{$IF DEFINED(VER2) or not DEFINED(UNIX) or DEFINED(USE_ICONV_SUBSTITUTE_WRAPPER)}
{$ELSE}
	if not iconvenc.InitIconv(iconvenc_errmsg) then begin
		Writeln('iconvenc initialization failed:', iconvenc_errmsg );
		halt;
	end;
{$ENDIF}

{$IF DEFINED(ENCODING_SINGLEBYTE)}
	SENC := SINGLEBYTE;
	SYSTEM_CHARSET := '';
{$ELSEIF DEFINED(ENCODING_EUCJP)}
	SENC := EUCJP;
	SYSTEM_CHARSET := 'EUCJP';
{$ELSEIF DEFINED(ENCODING_EUCKR)}
	SENC := EUCKR;
	SYSTEM_CHARSET := 'EUCKR';
{$ELSEIF DEFINED(ENCODING_EUCCN)}
	SENC := EUCCN;
	SYSTEM_CHARSET := 'EUCCN';
{$ELSEIF DEFINED(ENCODING_EUCTW)}
	SENC := EUCTW;
	SYSTEM_CHARSET := 'EUCTW';
{$ELSEIF DEFINED(ENCODING_UTF8)}
	SENC := UTF8;
	SYSTEM_CHARSET := 'UTF-8';
{$ELSEIF DEFINED(ENCODING_SJIS)}
	SENC := SJIS;
	SYSTEM_CHARSET := 'SJIS';
{$ELSEIF DEFINED(ENCODING_CP932)}
	SENC := CP932;
	SYSTEM_CHARSET := 'CP932';
{$ELSE}
	SENC := ENC_UNKNOWN;
	SYSTEM_CHARSET := '';
{$ENDIF}

	Get_enc();
	Init_tenc();
	Init_unicode();
end;

finalization
begin
	iconv_close( iconv_utf16toenc );
	iconv_close( iconv_enc2utf16 );
	iconv_close( iconv_tenc2enc );
	iconv_close( iconv_enc2tenc );
end;

end.
