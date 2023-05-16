#!perl

use v5.36;
no warnings 'once';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Types',  qw[
    :core
    :events
    :types
];

datatype *Tree => sub {
    case Node => ( *Int, *Tree, *Tree );
    case Leaf => ();
};

subtest '... check the tagged union' => sub {

    my $tree = Node( 1, Leaf(), Leaf() );

    #warn Dumper $tree;
    #warn Dumper lookup_type( *Tree );

    ok(  lookup_type(*Tree)->check( $tree ), '... this passed the type check for Tree with an Tree' );
    ok( !lookup_type(*Tree)->check( 1 ), '... this failed the type check for Tree with an Int' );
    ok( !lookup_type(*Tree)->check( 1.5 ), '... this failed the type check for Tree with an Float' );

    ok( !lookup_type(*Tree)->check( bless [] => 'Foo' ), '... this failed the type check for Tree with an Object' );
};

done_testing;

1;

__END__

