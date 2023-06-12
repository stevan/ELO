#!perl

use v5.36;
no warnings 'once';

use Test::More;
use Test::Differences;

use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Types',  qw[ :core :types :events ];

# ... extended types

type *ZeroThroughNine => *Int, range => [0, 9];

subtest '... checking *ZeroThroughNine' => sub {
    ok(  lookup_type(*ZeroThroughNine)->check( 1 ),   '... this type checked for ZeroThroughNine with a single-digit ZeroThroughNine' );
    ok(  lookup_type(*ZeroThroughNine)->check( 0 ),   '... this type checked for ZeroThroughNine with a single-digit ZeroThroughNine' );
    ok(  lookup_type(*ZeroThroughNine)->check( 9 ),   '... this type checked for ZeroThroughNine with a single-digit ZeroThroughNine' );
    ok(  lookup_type(*ZeroThroughNine)->check( !!1 ),  '... this type checked for ZeroThroughNine with a Bool (see also - Perl)' );
    ok( !lookup_type(*ZeroThroughNine)->check( -1 ),   '... this type checked for ZeroThroughNine with a single-digit ZeroThroughNine' );
    ok( !lookup_type(*ZeroThroughNine)->check( 10 ),   '... this type checked for ZeroThroughNine with a regular ZeroThroughNine' );
    ok( !lookup_type(*ZeroThroughNine)->check( 100 ),   '... this type checked for ZeroThroughNine with a regular ZeroThroughNine' );
    ok( !lookup_type(*ZeroThroughNine)->check( 1_000_000 ),  '... this type checked for ZeroThroughNine with a _ seperated ZeroThroughNine' );
    ok( !lookup_type(*ZeroThroughNine)->check( int("256") ),  '... this type checked for ZeroThroughNine with a Str converted via int()' );
    ok( !lookup_type(*ZeroThroughNine)->check( "256" ),  '... this type checked for ZeroThroughNine with a Str containing numbers (see also - Perl)' );

    ok( !lookup_type(*ZeroThroughNine)->check( 'foo' ),   '... this failed the type check for ZeroThroughNine with a single-quoted Str' );
    ok( !lookup_type(*ZeroThroughNine)->check( "foo" ),   '... this failed the type check for ZeroThroughNine with a double-quoted Str' );
    ok( !lookup_type(*ZeroThroughNine)->check( q[foo] ),  '... this failed the type check for ZeroThroughNine with a q[] Str' );
    ok( !lookup_type(*ZeroThroughNine)->check( qq[foo] ), '... this failed the type check for ZeroThroughNine with a qq[] Str' );
    ok( !lookup_type(*ZeroThroughNine)->check( 0.01 ), '... this failed the type check for ZeroThroughNine with an Float' );
    ok( !lookup_type(*ZeroThroughNine)->check( [] ),   '... this failed the type check for ZeroThroughNine with an ArrayRef' );
    ok( !lookup_type(*ZeroThroughNine)->check( {} ),   '... this failed the type check for ZeroThroughNine with an HashRef' );
};

type *SayHello => *Str, matches => [qr/^Hello/];

subtest '... checking *SayHello' => sub {
    ok(  lookup_type(*SayHello)->check( "Hello 256" ),  '... this type checked for SayHello with a Str containing Hello' );

    ok( !lookup_type(*SayHello)->check( 1 ),   '... this type checked for SayHello with a single-digit SayHello' );
    ok( !lookup_type(*SayHello)->check( 0 ),   '... this type checked for SayHello with a single-digit SayHello' );
    ok( !lookup_type(*SayHello)->check( 9 ),   '... this type checked for SayHello with a single-digit SayHello' );
    ok( !lookup_type(*SayHello)->check( !!1 ),  '... this type checked for SayHello with a Bool (see also - Perl)' );
    ok( !lookup_type(*SayHello)->check( -1 ),   '... this type checked for SayHello with a single-digit SayHello' );
    ok( !lookup_type(*SayHello)->check( 10 ),   '... this type checked for SayHello with a regular SayHello' );
    ok( !lookup_type(*SayHello)->check( 100 ),   '... this type checked for SayHello with a regular SayHello' );
    ok( !lookup_type(*SayHello)->check( 1_000_000 ),  '... this type checked for SayHello with a _ seperated SayHello' );
    ok( !lookup_type(*SayHello)->check( int("256") ),  '... this type checked for SayHello with a Str converted via int()' );
    ok( !lookup_type(*SayHello)->check( "256" ),  '... this type checked for SayHello with a Str containing numbers (see also - Perl)' );

    ok( !lookup_type(*SayHello)->check( 'foo' ),   '... this failed the type check for SayHello with a single-quoted Str' );
    ok( !lookup_type(*SayHello)->check( "foo" ),   '... this failed the type check for SayHello with a double-quoted Str' );
    ok( !lookup_type(*SayHello)->check( q[foo] ),  '... this failed the type check for SayHello with a q[] Str' );
    ok( !lookup_type(*SayHello)->check( qq[foo] ), '... this failed the type check for SayHello with a qq[] Str' );
    ok( !lookup_type(*SayHello)->check( 0.01 ), '... this failed the type check for SayHello with an Float' );
    ok( !lookup_type(*SayHello)->check( [] ),   '... this failed the type check for SayHello with an ArrayRef' );
    ok( !lookup_type(*SayHello)->check( {} ),   '... this failed the type check for SayHello with an HashRef' );
};

# ... Custom Types

type *Foo, sub ($foo) { "$foo" eq 'foo' };

subtest '... checking *Foo' => sub {
    ok(  lookup_type(*Foo)->check( "foo" ), '... this passed the type check for Foo with an Str(foo)' );
    ok( !lookup_type(*Foo)->check( "Foo" ), '... this failed the type check for Foo with an Str(Foo)' );
    ok( !lookup_type(*Foo)->check( 100 ),   '... this failed the type check for Foo with an Int' );
    ok( !lookup_type(*Foo)->check( 0.01 ),  '... this failed the type check for Foo with an Float' );
    ok( !lookup_type(*Foo)->check( [] ),    '... this failed the type check for Foo with an ArrayRef' );
    ok( !lookup_type(*Foo)->check( {} ),    '... this failed the type check for Foo with an HashRef' );
};

# ... Enumeration Types

enum *Ops => (
    *Ops::Add,
    *Ops::Sub,
    *Ops::Mul,
    *Ops::Div,
);

subtest '... checking *Ops' => sub {
    ok( lookup_type(*Ops)->check( *Ops::Add ), '... this passed the type check for Ops with an Ops::Add' );
    ok( lookup_type(*Ops)->check( *Ops::Sub ), '... this passed the type check for Ops with an Ops::Sub' );
    ok( lookup_type(*Ops)->check( *Ops::Mul ), '... this passed the type check for Ops with an Ops::Mul' );
    ok( lookup_type(*Ops)->check( *Ops::Div ), '... this passed the type check for Ops with an Ops::Div' );

    ok( !lookup_type(*Ops)->check( *Ops::MULTIPLY ), '... this failed the type check for Ops with an Ops::MULITPLY' );
    ok( !lookup_type(*Ops)->check( "Ops" ), '... this failed the type check for Ops with an Str(Ops)' );
    ok( !lookup_type(*Ops)->check( 100 ),   '... this failed the type check for Ops with an Int' );
    ok( !lookup_type(*Ops)->check( 0.01 ),  '... this failed the type check for Ops with an Float' );
    ok( !lookup_type(*Ops)->check( [] ),    '... this failed the type check for Ops with an ArrayRef' );
    ok( !lookup_type(*Ops)->check( {} ),    '... this failed the type check for Ops with an HashRef' );
};

subtest '... check enum with match' => sub {

    my ($op, $l, $r) = (*Ops::Add, 2, 2);

    my $result = match [ *Ops, $op ] => {
        *Ops::Add => sub () { $l + $r },
        *Ops::Sub => sub () { $l - $r },
        *Ops::Mul => sub () { $l * $r },
        *Ops::Div => sub () { $l / $r },
    };

    is_deeply( $result, 4, '... enum match succeeded' );
};

# ... Type Aliases

type *MyFloat    => *Float;
type *MyArrayRef => *ArrayRef;

subtest '... checking *MyFloat' => sub {
    ok( lookup_type(*MyFloat)->check( 1.0 ),   '... this type checked for MyFloat with a simple Float' );
    ok( lookup_type(*MyFloat)->check( 0.0001 ),   '... this type checked for MyFloat with a simple Float' );

    ok( lookup_type(*MyFloat)->check( int("256") ),  '... this type checked for MyFloat with a Str converted via int() (see also - Perl)' );
    ok( lookup_type(*MyFloat)->check( 100 ),   '... this type checked for MyFloat with with an Int (see also - Perl)' );
    ok( lookup_type(*MyFloat)->check( !!1 ),  '... this type checked for MyFloat with a Bool (see also - Perl)' );
    ok( lookup_type(*MyFloat)->check( '3.14' ),  '... this type checked for MyFloat with a Str containing a float (see also - Perl)' );

    ok( !lookup_type(*MyFloat)->check( 'foo' ),   '... this failed the type check for MyFloat with a single-quoted Str' );
    ok( !lookup_type(*MyFloat)->check( "foo" ),   '... this failed the type check for MyFloat with a double-quoted Str' );
    ok( !lookup_type(*MyFloat)->check( q[foo] ),  '... this failed the type check for MyFloat with a q[] Str' );
    ok( !lookup_type(*MyFloat)->check( qq[foo] ), '... this failed the type check for MyFloat with a qq[] Str' );
    ok( !lookup_type(*MyFloat)->check( [] ),   '... this failed the type check for MyFloat with an ArrayRef' );
    ok( !lookup_type(*MyFloat)->check( {} ),   '... this failed the type check for MyFloat with an HashRef' );
};

subtest '... checking *MyArrayRef' => sub {
    ok( lookup_type(*MyArrayRef)->check( [] ),   '... this type checked for MyArrayRef with an ArrayRef' );

    ok( !lookup_type(*MyArrayRef)->check( 1.0 ),   '... this failed the type check for MyArrayRef with a simple Flot' );
    ok( !lookup_type(*MyArrayRef)->check( 100 ),   '... this failed the type check for MyArrayRef with with an Int' );
    ok( !lookup_type(*MyArrayRef)->check( !!1 ),  '... this failed the type check for MyArrayRef with a Bool' );
    ok( !lookup_type(*MyArrayRef)->check( '3.14' ),  '... this failed the type check for MyArrayRef with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*MyArrayRef)->check( 'foo' ),   '... this failed the type check for MyArrayRef with a single-quoted Str' );
    ok( !lookup_type(*MyArrayRef)->check( "foo" ),   '... this failed the type check for MyArrayRef with a double-quoted Str' );
    ok( !lookup_type(*MyArrayRef)->check( q[foo] ),  '... this failed the type check for MyArrayRef with a q[] Str' );
    ok( !lookup_type(*MyArrayRef)->check( qq[foo] ), '... this failed the type check for MyArrayRef with a qq[] Str' );
    ok( !lookup_type(*MyArrayRef)->check( {} ),   '... this failed the type check for MyArrayRef with an HashRef' );
};

# extended types with ArrayRef

type *ArrayRefOfInts => *ArrayRef, ( of => [ *Int ] );

subtest '... checking *ArrayRefOfInts' => sub {
    ok( lookup_type(*ArrayRefOfInts)->check( [] ),   '... this type checked for ArrayRefOfInts with an ArrayRef' );
    ok( lookup_type(*ArrayRefOfInts)->check( [ 1 .. 10 ] ),   '... this type checked for ArrayRefOfInts with an ArrayRef' );

    ok( !lookup_type(*ArrayRefOfInts)->check( [ "string", 30 ] ),   '... this type checked for ArrayRefOfInts with mixed types an ArrayRef' );
    ok( !lookup_type(*ArrayRefOfInts)->check( [ 0.25, 0.33 ] ),   '... this type checked for ArrayRefOfInts with an ArrayRef of Floats' );

    ok( !lookup_type(*ArrayRefOfInts)->check( 1.0 ),   '... this failed the type check for ArrayRefOfInts with a simple Flot' );
    ok( !lookup_type(*ArrayRefOfInts)->check( 100 ),   '... this failed the type check for ArrayRefOfInts with with an Int' );
    ok( !lookup_type(*ArrayRefOfInts)->check( !!1 ),  '... this failed the type check for ArrayRefOfInts with a Bool' );
    ok( !lookup_type(*ArrayRefOfInts)->check( '3.14' ),  '... this failed the type check for ArrayRefOfInts with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*ArrayRefOfInts)->check( 'foo' ),   '... this failed the type check for ArrayRefOfInts with a single-quoted Str' );
    ok( !lookup_type(*ArrayRefOfInts)->check( "foo" ),   '... this failed the type check for ArrayRefOfInts with a double-quoted Str' );
    ok( !lookup_type(*ArrayRefOfInts)->check( q[foo] ),  '... this failed the type check for ArrayRefOfInts with a q[] Str' );
    ok( !lookup_type(*ArrayRefOfInts)->check( qq[foo] ), '... this failed the type check for ArrayRefOfInts with a qq[] Str' );
    ok( !lookup_type(*ArrayRefOfInts)->check( {} ),   '... this failed the type check for ArrayRefOfInts with an HashRef' );
};

type *HashRefOfInts => *HashRef, ( of => [ *Int ] );

subtest '... checking *HashRefOfInts' => sub {
    ok( lookup_type(*HashRefOfInts)->check( {} ),   '... this type checked for HashRefOfInts with an ArrayRef' );
    ok( lookup_type(*HashRefOfInts)->check( { one => 1, two => 2, three => 3 } ),   '... this type checked for HashRefOfInts with an ArrayRef' );

    ok( !lookup_type(*HashRefOfInts)->check( { one => 1, two => 'two', three => 3 } ),   '... this type checked for HashRefOfInts with mixed types an ArrayRef' );
    ok( !lookup_type(*HashRefOfInts)->check( { one => 0.1, two => 0.2, three => 0.3 } ),   '... this type checked for HashRefOfInts with an ArrayRef of Floats' );

    ok( !lookup_type(*HashRefOfInts)->check( 1.0 ),   '... this failed the type check for HashRefOfInts with a simple Flot' );
    ok( !lookup_type(*HashRefOfInts)->check( 100 ),   '... this failed the type check for HashRefOfInts with with an Int' );
    ok( !lookup_type(*HashRefOfInts)->check( !!1 ),  '... this failed the type check for HashRefOfInts with a Bool' );
    ok( !lookup_type(*HashRefOfInts)->check( '3.14' ),  '... this failed the type check for HashRefOfInts with a Str containing a float (see also - Perl)' );
    ok( !lookup_type(*HashRefOfInts)->check( 'foo' ),   '... this failed the type check for HashRefOfInts with a single-quoted Str' );
    ok( !lookup_type(*HashRefOfInts)->check( "foo" ),   '... this failed the type check for HashRefOfInts with a double-quoted Str' );
    ok( !lookup_type(*HashRefOfInts)->check( q[foo] ),  '... this failed the type check for HashRefOfInts with a q[] Str' );
    ok( !lookup_type(*HashRefOfInts)->check( qq[foo] ), '... this failed the type check for HashRefOfInts with a qq[] Str' );
};

done_testing;

1;

__END__
