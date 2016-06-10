unit i18nmsg;
	{ Return the standard message string which has the requested label. }

interface

var
	I18N_UseOriginalName: Boolean = False;


Function I18N_Settings( const MsgLabel: String; const DefaultMsg: String ): String;
Function I18N_Name( const CategoryLabel, MsgLabel: String; const I18N: Boolean ): String;
Function I18N_Name( const CategoryLabel, MsgLabel: String ): String;
Function I18N_Name_withDefault( const MsgLabel, DefaultMsg: String ): String;
Function I18N_Name_NoFailback( const CategoryLabel, MsgLabel: String ): String;
Function I18N_Name( const MsgLabel: String ): String;
Function I18N_MsgString( const CategoryLabel, MsgLabel: String; const I18N: Boolean ): String;
Function I18N_MsgString( const CategoryLabel, MsgLabel: String ): String;
Function I18N_MsgString( const MsgLabel: String ): String;



implementation

uses gears;


var
	I18N_Settings_SAtt: SAttPtr;
	I18N_Name_SAtt:     SAttPtr;
	I18N_Messages_SAtt: SAttPtr;



Function ConcatenateLabel( const CategoryLabel, MsgLabel: String ): String;
var
	P: Integer;
begin
	ConcatenateLabel := CategoryLabel + '_' + MsgLabel;
	P := Pos( ' ', ConcatenateLabel );
	while (0 < P) do begin
		ConcatenateLabel[P] := '_';
		P := Pos( ' ', ConcatenateLabel );
	end;
end;


Function DeconcatenateLabel( MsgLabel: String ): String;
var
	P: Integer;
begin
	DeconcatenateLabel := MsgLabel;
	P := Pos( '_', DeconcatenateLabel );
	while (0 < P) do begin
		DeconcatenateLabel[P] := ' ';
		P := Pos( '_', DeconcatenateLabel );
	end;
end;



Function I18N_Settings( const MsgLabel: String; const DefaultMsg: String ): String;
begin
	I18N_Settings := SAttValue( I18N_Settings_SAtt, MsgLabel );
	if (0 = Length(I18N_Settings)) then begin
		WriteLn( 'ERROR- I18N_Settings: "' + MsgLabel + '" not found.' );
		I18N_Settings := DefaultMsg;
	end;
end;



Function I18N_Name( const CategoryLabel, MsgLabel: String; const I18N: Boolean ): String;
begin
	if I18N and not(I18N_UseOriginalName) then begin
		I18N_Name := SAttValue( I18N_Name_SAtt, ConcatenateLabel( CategoryLabel, MsgLabel) );
		if (0 = Length(I18N_Name)) then begin
			WriteLn( 'ERROR- I18N_Name: "' + CategoryLabel + ':' + MsgLabel + '" not found.' );
			I18N_Name := MsgLabel;
		end;
	end else begin
		I18N_Name := MsgLabel;
	end;
end;


Function I18N_Name( const CategoryLabel, MsgLabel: String ): String;
begin
	if I18N_UseOriginalName then begin
		I18N_Name := MsgLabel;
	end else begin
		I18N_Name := SAttValue( I18N_Name_SAtt, ConcatenateLabel( CategoryLabel, MsgLabel) );
		if (0 = Length(I18N_Name)) then begin
			WriteLn( 'ERROR- I18N_Name: "' + CategoryLabel + ':' + MsgLabel + '" not found.' );
			I18N_Name := MsgLabel;
		end;
	end;
end;


Function I18N_Name_withDefault( const MsgLabel, DefaultMsg: String ): String;
var
	lbl: String;
begin
	lbl := ConcatenateLabel( '', MsgLabel );
	if I18N_UseOriginalName then begin
		I18N_Name_withDefault := DefaultMsg;
	end else begin
		I18N_Name_withDefault := SAttValue( I18N_Name_SAtt, lbl );
		if (0 = Length(I18N_Name_withDefault)) then begin
			I18N_Name_withDefault := DefaultMsg;
		end;
	end;
end;


Function I18N_Name_NoFailback( const CategoryLabel, MsgLabel: String ): String;
begin
	if I18N_UseOriginalName then begin
		I18N_Name_NoFailback := '';
	end else begin
		I18N_Name_NoFailback := SAttValue( I18N_Name_SAtt, ConcatenateLabel( CategoryLabel, MsgLabel) );
	end;
end;


Function I18N_Name( const MsgLabel: String ): String;
var
	lbl: String;
begin
	lbl := ConcatenateLabel( '', MsgLabel );
	if I18N_UseOriginalName then begin
		I18N_Name := DeconcatenateLabel( lbl );
	end else begin
		I18N_Name := SAttValue( I18N_Name_SAtt, lbl );
		if (0 = Length(I18N_Name)) then begin
			WriteLn( 'ERROR- I18N_Name: "' + lbl + '" not found.' );
			I18N_Name := DeconcatenateLabel( lbl );
		end;
	end;
end;



Function I18N_MsgString( const CategoryLabel, MsgLabel: String; const I18N: Boolean ): String;
begin
	if I18N then begin
		I18N_MsgString := SAttValue( I18N_Messages_SAtt, ConcatenateLabel( CategoryLabel, MsgLabel) );
		if (0 = Length(I18N_MsgString)) then begin
			WriteLn( 'ERROR- I18N_MsgString: "' + CategoryLabel + ':' + MsgLabel + '" not found.' );
			I18N_MsgString := MsgLabel;
		end;
	end else begin
		I18N_MsgString := MsgLabel;
	end;
end;


Function I18N_MsgString( const CategoryLabel, MsgLabel: String ): String;
begin
	I18N_MsgString := SAttValue( I18N_Messages_SAtt, ConcatenateLabel( CategoryLabel, MsgLabel) );
	if (0 = Length(I18N_MsgString)) then begin
		WriteLn( 'ERROR- I18N_MsgString: "' + CategoryLabel + ':' + MsgLabel + '" not found.' );
		I18N_MsgString := MsgLabel;
	end;
end;


Function I18N_MsgString( const MsgLabel: String ): String;
begin
	I18N_MsgString := SAttValue( I18N_Messages_SAtt, MsgLabel );
	if (0 = Length(I18N_MsgString)) then begin
		WriteLn( 'ERROR- I18N_MsgString: "' + MsgLabel + '" not found.' );
		I18N_MsgString := MsgLabel;
	end;
end;



initialization
begin
	I18N_Settings_SAtt := LoadStringList( I18N_Settings_File );
	I18N_Name_SAtt     := LoadStringList( I18N_Name_File );
	I18N_Messages_SAtt := LoadStringList( I18N_Messages_File );
end;


finalization
begin
	DisposeSAtt( I18N_Messages_SAtt );
	DisposeSAtt( I18N_Name_SAtt );
	DisposeSAtt( I18N_Settings_SAtt );
end;

end.
