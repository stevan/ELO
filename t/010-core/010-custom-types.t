#!perl

use v5.36;
no warnings 'once';

use Test::More;
use Test::Differences;

use ok 'ELO::Types', qw[ :core :types :events ];

# ...

type *Foo, sub ($foo) { "$foo" eq 'foo' };

subtest '... checking *Foo' => sub {
    ok(  lookup_type(*Foo)->check( "foo" ), '... this passed the type check for Foo with an Str(foo)' );
    ok( !lookup_type(*Foo)->check( "Foo" ), '... this failed the type check for Foo with an Str(Foo)' );
    ok( !lookup_type(*Foo)->check( 100 ),   '... this failed the type check for Foo with an Int' );
    ok( !lookup_type(*Foo)->check( 0.01 ),  '... this failed the type check for Foo with an Float' );
    ok( !lookup_type(*Foo)->check( [] ),    '... this failed the type check for Foo with an ArrayRef' );
    ok( !lookup_type(*Foo)->check( {} ),    '... this failed the type check for Foo with an HashRef' );
};

# ...

enum *Ops => qw[
    Add
    Sub
    Mul
    Div
];

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

done_testing;

1;

__END__
