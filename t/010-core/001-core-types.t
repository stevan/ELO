#!perl

use v5.36;
no warnings 'once';

use Test::More;
use Test::Differences;

use ok 'ELO::Types', qw[ :core lookup_type ];

subtest '... checking *Bool' => sub {
    ok( lookup_type(*Bool)->check( !!1 ),   '... this type checked for Bool with !!1' );
    ok( lookup_type(*Bool)->check( !!0 ),   '... this type checked for Bool with !!0' );
    ok( lookup_type(*Bool)->check( 1 ),   '... this type checked for Bool with 1' );
    ok( lookup_type(*Bool)->check( 0 ),   '... this type checked for Bool with 0' );
    ok( lookup_type(*Bool)->check( '' ),   '... this type checked for Bool with empty-string' );

    ok( !lookup_type(*Bool)->check( "Foo" ), '... this failed the type check for Bool with an Str' );
    ok( !lookup_type(*Bool)->check( 100 ),   '... this failed the type check for Bool with an Int' );
    ok( !lookup_type(*Bool)->check( 0.01 ),  '... this failed the type check for Bool with an Float' );
    ok( !lookup_type(*Bool)->check( [] ),    '... this failed the type check for Bool with an ArrayRef' );
    ok( !lookup_type(*Bool)->check( {} ),    '... this failed the type check for Bool with an HashRef' );
};

subtest '... checking *Str' => sub {
    ok( lookup_type(*Str)->check( 'foo' ),   '... this type checked for Str with a single-quoted Str' );
    ok( lookup_type(*Str)->check( "foo" ),   '... this type checked for Str with a double-quoted Str' );
    ok( lookup_type(*Str)->check( q[foo] ),  '... this type checked for Str with a q[] Str' );
    ok( lookup_type(*Str)->check( qq[foo] ), '... this type checked for Str with a qq[] Str' );
    ok( lookup_type(*Str)->check( '1000' ), '... this type checked for Str with a quoted number Str' );

    ok( lookup_type(*Str)->check( !!1 ),  '... this type checked for Str with an Bool (see also - Perl)' );
    ok( lookup_type(*Str)->check( 100 ),  '... this type checked for Str with an Int (see also - Perl)' );
    ok( lookup_type(*Str)->check( 0.01 ), '... this type checked for Str with an Float (see also - Perl)' );

    ok( !lookup_type(*Str)->check( [] ),   '... this failed the type check for Str with an ArrayRef' );
    ok( !lookup_type(*Str)->check( {} ),   '... this failed the type check for Str with an HashRef' );
};

subtest '... checking *Num' => sub {
    ok( lookup_type(*Num)->check( 1 ),   '... this type checked for Num with a single-digit Int' );
    ok( lookup_type(*Num)->check( 100 ),   '... this type checked for Num with a regular Int' );
    ok( lookup_type(*Num)->check( 1_000_000 ),  '... this type checked for Num with a _ seperated Int' );
    ok( lookup_type(*Num)->check( int("256") ),  '... this type checked for Num with a Str converted via int()' );

    ok( lookup_type(*Num)->check( !!1 ),  '... this type checked for Num with a Bool (see also - Perl)' );
    ok( lookup_type(*Num)->check( "256" ),  '... this type checked for Num with a Str containing numbers (see also - Perl)' );
    ok( lookup_type(*Num)->check( 1.0 ),   '... this type checked for Num with a simple Float' );
    ok( lookup_type(*Num)->check( 0.0001 ),   '... this type checked for Num with a simple Float' );
    ok( lookup_type(*Num)->check( '3.14' ),  '... this type checked for a Num with a Str containing a float (see also - Perl)' );

    ok( !lookup_type(*Num)->check( 'foo' ),   '... this failed the type check for Num with a single-quoted Str' );
    ok( !lookup_type(*Num)->check( "foo" ),   '... this failed the type check for Num with a double-quoted Str' );
    ok( !lookup_type(*Num)->check( q[foo] ),  '... this failed the type check for Num with a q[] Str' );
    ok( !lookup_type(*Num)->check( qq[foo] ), '... this failed the type check for Num with a qq[] Str' );
    ok( !lookup_type(*Num)->check( [] ),   '... this failed the type check for Num with an ArrayRef' );
    ok( !lookup_type(*Num)->check( {} ),   '... this failed the type check for Num with an HashRef' );
};

subtest '... checking *Int' => sub {
    ok( lookup_type(*Int)->check( 1 ),   '... this type checked for Int with a single-digit Int' );
    ok( lookup_type(*Int)->check( 100 ),   '... this type checked for Int with a regular Int' );
    ok( lookup_type(*Int)->check( 1_000_000 ),  '... this type checked for Int with a _ seperated Int' );
    ok( lookup_type(*Int)->check( int("256") ),  '... this type checked for Int with a Str converted via int()' );

    ok( lookup_type(*Int)->check( !!1 ),  '... this type checked for Int with a Bool (see also - Perl)' );
    ok( lookup_type(*Int)->check( "256" ),  '... this type checked for Int with a Str containing numbers (see also - Perl)' );

    ok( !lookup_type(*Int)->check( 'foo' ),   '... this failed the type check for Int with a single-quoted Str' );
    ok( !lookup_type(*Int)->check( "foo" ),   '... this failed the type check for Int with a double-quoted Str' );
    ok( !lookup_type(*Int)->check( q[foo] ),  '... this failed the type check for Int with a q[] Str' );
    ok( !lookup_type(*Int)->check( qq[foo] ), '... this failed the type check for Int with a qq[] Str' );
    ok( !lookup_type(*Int)->check( 0.01 ), '... this failed the type check for Int with an Float' );
    ok( !lookup_type(*Int)->check( [] ),   '... this failed the type check for Int with an ArrayRef' );
    ok( !lookup_type(*Int)->check( {} ),   '... this failed the type check for Int with an HashRef' );
};

subtest '... checking *Float' => sub {
    ok( lookup_type(*Float)->check( 1.0 ),   '... this type checked for Float with a simple Float' );
    ok( lookup_type(*Float)->check( 0.0001 ),   '... this type checked for Float with a simple Float' );

    ok( lookup_type(*Float)->check( int("256") ),  '... this type checked for a Float with a Str converted via int() (see also - Perl)' );
    ok( lookup_type(*Float)->check( 100 ),   '... this type checked for Float with with an Int (see also - Perl)' );
    ok( lookup_type(*Float)->check( !!1 ),  '... this type checked for Float with a Bool (see also - Perl)' );
    ok( lookup_type(*Float)->check( '3.14' ),  '... this type checked for a Float with a Str containing a float (see also - Perl)' );

    ok( !lookup_type(*Float)->check( 'foo' ),   '... this failed the type check for Float with a single-quoted Str' );
    ok( !lookup_type(*Float)->check( "foo" ),   '... this failed the type check for Float with a double-quoted Str' );
    ok( !lookup_type(*Float)->check( q[foo] ),  '... this failed the type check for Float with a q[] Str' );
    ok( !lookup_type(*Float)->check( qq[foo] ), '... this failed the type check for Float with a qq[] Str' );
    ok( !lookup_type(*Float)->check( [] ),   '... this failed the type check for Float with an ArrayRef' );
    ok( !lookup_type(*Float)->check( {} ),   '... this failed the type check for Float with an HashRef' );
};

subtest '... checking *ArrayRef' => sub {
    ok( lookup_type(*ArrayRef)->check( [] ),   '... this type checked for ArrayRef with an ArrayRef' );

    ok( !lookup_type(*ArrayRef)->check( 1.0 ),   '... this failed the type check for ArrayRef with a simple Flot' );
    ok( !lookup_type(*ArrayRef)->check( 100 ),   '... this failed the type check for ArrayRef with with an Int' );
    ok( !lookup_type(*ArrayRef)->check( !!1 ),  '... this failed the type check for ArrayRef with a Bool' );
    ok( !lookup_type(*ArrayRef)->check( '3.14' ),  '... this failed the type check for ArrayRef with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*ArrayRef)->check( 'foo' ),   '... this failed the type check for ArrayRef with a single-quoted Str' );
    ok( !lookup_type(*ArrayRef)->check( "foo" ),   '... this failed the type check for ArrayRef with a double-quoted Str' );
    ok( !lookup_type(*ArrayRef)->check( q[foo] ),  '... this failed the type check for ArrayRef with a q[] Str' );
    ok( !lookup_type(*ArrayRef)->check( qq[foo] ), '... this failed the type check for ArrayRef with a qq[] Str' );
    ok( !lookup_type(*ArrayRef)->check( {} ),   '... this failed the type check for ArrayRef with an HashRef' );
};

subtest '... checking *HashRef' => sub {
    ok( lookup_type(*HashRef)->check( {} ),   '... this type checked for HashRef with an HashRef' );

    ok( !lookup_type(*HashRef)->check( 1.0 ),   '... this failed the type check for HashRef with a simple Flot' );
    ok( !lookup_type(*HashRef)->check( 100 ),   '... this failed the type check for HashRef with with an Int' );
    ok( !lookup_type(*HashRef)->check( !!1 ),  '... this failed the type check for HashRef with a Bool' );
    ok( !lookup_type(*HashRef)->check( '3.14' ),  '... this failed the type check for HashRef with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*HashRef)->check( 'foo' ),   '... this failed the type check for HashRef with a single-quoted Str' );
    ok( !lookup_type(*HashRef)->check( "foo" ),   '... this failed the type check for HashRef with a double-quoted Str' );
    ok( !lookup_type(*HashRef)->check( q[foo] ),  '... this failed the type check for HashRef with a q[] Str' );
    ok( !lookup_type(*HashRef)->check( qq[foo] ), '... this failed the type check for HashRef with a qq[] Str' );
    ok( !lookup_type(*HashRef)->check( [] ),   '... this failed the type check for HashRef with an ArrayRef' );
};

subtest '... checking *PID' => sub {
    ok( lookup_type(*PID)->check( '000:Foo' ),   '... this type checked for PID with an PID' );

    ok( !lookup_type(*PID)->check( 1.0 ),   '... this failed the type check for PID with a simple Flot' );
    ok( !lookup_type(*PID)->check( 100 ),   '... this failed the type check for PID with with an Int' );
    ok( !lookup_type(*PID)->check( !!1 ),  '... this failed the type check for PID with a Bool' );
    ok( !lookup_type(*PID)->check( '3.14' ),  '... this failed the type check for PID with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*PID)->check( 'foo' ),   '... this failed the type check for PID with a single-quoted Str' );
    ok( !lookup_type(*PID)->check( "foo" ),   '... this failed the type check for PID with a double-quoted Str' );
    ok( !lookup_type(*PID)->check( q[foo] ),  '... this failed the type check for PID with a q[] Str' );
    ok( !lookup_type(*PID)->check( qq[foo] ), '... this failed the type check for PID with a qq[] Str' );
    ok( !lookup_type(*PID)->check( [] ),   '... this failed the type check for PID with an ArrayRef' );
    ok( !lookup_type(*PID)->check( {} ),   '... this failed the type check for PID with an HashRef' );
};

subtest '... checking *Process' => sub {
    ok( lookup_type(*Process)->check( bless {} => 'ELO::Core::Process' ),   '... this type checked for Process with an Process' );

    ok( !lookup_type(*Process)->check( 1.0 ),   '... this failed the type check for Process with a simple Flot' );
    ok( !lookup_type(*Process)->check( 100 ),   '... this failed the type check for Process with with an Int' );
    ok( !lookup_type(*Process)->check( !!1 ),  '... this failed the type check for Process with a Bool' );
    ok( !lookup_type(*Process)->check( '3.14' ),  '... this failed the type check for Process with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*Process)->check( 'foo' ),   '... this failed the type check for Process with a single-quoted Str' );
    ok( !lookup_type(*Process)->check( "foo" ),   '... this failed the type check for Process with a double-quoted Str' );
    ok( !lookup_type(*Process)->check( q[foo] ),  '... this failed the type check for Process with a q[] Str' );
    ok( !lookup_type(*Process)->check( qq[foo] ), '... this failed the type check for Process with a qq[] Str' );
    ok( !lookup_type(*Process)->check( [] ),   '... this failed the type check for Process with an ArrayRef' );
    ok( !lookup_type(*Process)->check( {} ),   '... this failed the type check for Process with an HashRef' );
};

subtest '... checking *Promise' => sub {
    ok( lookup_type(*Promise)->check( bless {} => 'ELO::Core::Promise' ),   '... this type checked for Promise with an Promise' );

    ok( !lookup_type(*Promise)->check( 1.0 ),   '... this failed the type check for Promise with a simple Flot' );
    ok( !lookup_type(*Promise)->check( 100 ),   '... this failed the type check for Promise with with an Int' );
    ok( !lookup_type(*Promise)->check( !!1 ),  '... this failed the type check for Promise with a Bool' );
    ok( !lookup_type(*Promise)->check( '3.14' ),  '... this failed the type check for Promise with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*Promise)->check( 'foo' ),   '... this failed the type check for Promise with a single-quoted Str' );
    ok( !lookup_type(*Promise)->check( "foo" ),   '... this failed the type check for Promise with a double-quoted Str' );
    ok( !lookup_type(*Promise)->check( q[foo] ),  '... this failed the type check for Promise with a q[] Str' );
    ok( !lookup_type(*Promise)->check( qq[foo] ), '... this failed the type check for Promise with a qq[] Str' );
    ok( !lookup_type(*Promise)->check( [] ),   '... this failed the type check for Promise with an ArrayRef' );
    ok( !lookup_type(*Promise)->check( {} ),   '... this failed the type check for Promise with an HashRef' );
};

subtest '... checking *TimerId' => sub {
    ok( lookup_type(*TimerId)->check( \(my $x = 0) ),   '... this type checked for TimerId with an TimerId' );

    ok( !lookup_type(*TimerId)->check( 1.0 ),   '... this failed the type check for TimerId with a simple Flot' );
    ok( !lookup_type(*TimerId)->check( 100 ),   '... this failed the type check for TimerId with with an Int' );
    ok( !lookup_type(*TimerId)->check( !!1 ),  '... this failed the type check for TimerId with a Bool' );
    ok( !lookup_type(*TimerId)->check( '3.14' ),  '... this failed the type check for TimerId with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*TimerId)->check( 'foo' ),   '... this failed the type check for TimerId with a single-quoted Str' );
    ok( !lookup_type(*TimerId)->check( "foo" ),   '... this failed the type check for TimerId with a double-quoted Str' );
    ok( !lookup_type(*TimerId)->check( q[foo] ),  '... this failed the type check for TimerId with a q[] Str' );
    ok( !lookup_type(*TimerId)->check( qq[foo] ), '... this failed the type check for TimerId with a qq[] Str' );
    ok( !lookup_type(*TimerId)->check( [] ),   '... this failed the type check for TimerId with an ArrayRef' );
    ok( !lookup_type(*TimerId)->check( {} ),   '... this failed the type check for TimerId with an HashRef' );
};

done_testing;

1;

__END__
