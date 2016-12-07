Program xxran;
	{ Test program for the extra-extra-random plot generator. }
	{ No plots will be harmed in the making of this experiment... }

	{ The core of the extra-extra-random plot generator is not just that }
	{ a bunch of episodes will be strung along in random fashion, but also }
	{ that the episodes themselves will be randomly generated. I'll do this }
	{ by making each episode up from a series of pre-generated components. }

	{ Is it feasable? There's only one way to find out... }

{
	+E##	Enemy exists and is known
	+ech	Enemy Type: Generic
	+eof	Enemy Type: Old Friend

	+H##	Helper exists

	+Mfs	Mystery Family Secret

	+Bfd	Bad Thing Family Died
	+Bsr	Bad Thing Seeking Revenge

	-G##	Task: Go to Location

	-Tsh	Task: Speak with helper
	-Tse	Task: Speak with enemy
	-Tle	Task: Look for enemy
	-Tam	Task: Get Ambushed (not much of a task, I know...)

	-I##	Task: Introduction to episode

}

uses texutil,gears;

const
	NumComponent = 10;

var
	components: SAttPtr;
	desc,task: String;	{ XXRAN descriptors for the current episode. }
	Startup,depth: Integer;

function FragmentMatchesParameter( n: Integer; P: String ): Boolean;

var
	fdesc,a: String;
	T: Integer;
	ItMatches: Boolean;
begin
	fdesc := SAttValue( components, 'COMP' + BStr( n ) + 'DESC' );
	t := 1;
	itMatches := True;
	while T < Length( fdesc ) do begin
		a := Copy( fdesc , T , 4 );
		if Pos( a , P ) = 0 then itMatches := False;
		T := t + 4;
	end;
	FragmentMatchesParameter := itMatches;
end;

Function SelectFragment( P: String ): Integer;
	{ Pick a fragment that fits the parameters. }
var
	msg: String;
	T,N,it: Integer;
begin
	{ First, count the number of matches. }
	N := 0;
	T := 1;
	repeat
		msg := SAttValue( components , 'COMP' + BStr( T ) );
		if FragmentMatchesParameter( t , P ) and ( msg <> '' ) then Inc( N );
		Inc( T );
	until msg = '';

	{ Select one at random. }
	it := 0;
	if N > 0 then begin
		N := Random( N );
		t := 1;
		repeat
			msg := SAttValue( components , 'COMP' + BStr( T ) );
			if FragmentMatchesParameter( t , P ) then begin
				Dec( N );
				if N = -1 then it := T;
			end;
			Inc( T );
		until msg = '';
	end;
	SelectFragment := it;
end;

Procedure ApplyResult( var P: String; R: String );

VAR
	a: String;
	T,I: Integer;
begin
	T := 1;
	while T < Length( R ) do begin
		a := Copy( R , T , 4 );

		I := Pos( Copy( a , 1 , 2 ) , P );

		if I <> 0 then begin
			P[I+2] := a[3];
			P[I+3] := a[4];
		end else begin
			P := P + a;
		end;

		T := t + 4;
	end;

end;

Procedure FindNextFragment( var P: String );
	{ Find the next fragment based on parameter list P. }
var
	N: Integer;
begin
	N := SelectFragment( P );
	Inc( Depth );
	if N <> 0 then begin
		writeln( SAttValue( components , 'COMP' + BStr( N ) ) );
		ApplyResult( P , SAttValue( components , 'COMP' + BStr( N ) + 'RESULT' ) );
		if Depth < 5 then FindNextFragment( P );
	end;
end;

begin
	Randomize;
	components := LoadStringList( 'xxcomp.txt' );

	Startup := 1;
	writeln( SAttValue( components , 'START' + BStr( Startup ) ) );
	desc := SAttValue( components , 'START' + BStr( Startup ) + 'DESC' );
	task := SAttValue( components , 'START' + BStr( Startup ) + 'TASK' );

	depth := 0;

	desc := desc + task;
	FindNextFragment( desc );

	DisposeSAtt( components );
end.

