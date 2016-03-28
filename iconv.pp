unit iconv;

interface

uses sysutils;


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



implementation

uses i18nmsg;


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
	bidiRTL: String;
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
{$IFDEF Windows}
	if '' = codec then begin
		codec := I18N_Settings('TERMINAL_ENCODING_DEFAULT_MSWIN','');
	end;
{$ENDIF Windows}
	if '' = codec then begin
		codec := I18N_Settings('TERMINAL_ENCODING_DEFAULT','');
	end;
	if '' = codec then begin
		codec := I18N_Settings('SYSTEM_ENCODING','');
	end;

	TENC := Parse_EncType( codec, TERMINAL_CHARSET );

	bidiRTL := I18N_Settings('TERMINAL_ENCODING_CONV_bidiRTL','');
	case bidiRTL[1] of
	'T':	TERMINAL_bidiRTL := True;
	'F':	TERMINAL_bidiRTL := False;
	end;
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
		WriteLn('Unknown locale "' + SYSTEM_CHARSET + '".');
		err := True;
	end;

	if ENC_UNKNOWN = TENC then begin
		WriteLn('Unknown locale "' + TERMINAL_CHARSET + '".');
		err := True;
	end;

	if err then begin
		halt(255);
	end;
end;



initialization
begin
	Get_enc();
end;

finalization
begin
end;

end.
