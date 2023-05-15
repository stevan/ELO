#!perl

use v5.36;
no warnings 'once';

use Test::More;
use Test::Differences;

use ok 'ELO::Types', qw[ :core :types :events ];

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

done_testing;

1;

__END__
