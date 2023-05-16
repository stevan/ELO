#!perl

use v5.36;

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Types',  qw[
    :core
    :events
    :types
];

# Tagged Unions
# https://en.wikipedia.org/wiki/Tagged_union

datatype *Tree => sub {
    case Node => ( *Int, *Tree, *Tree );
    case Leaf => ();
};

sub dump_tree ( $t ) {
    match [ *Tree, $t ] => +{
        Node => sub ($val, $left, $right) {
            #warn "HERE";
            #warn Dumper [ $val, $left, $right ];
            [ $val, dump_tree($left), dump_tree($right) ];
        },
        Leaf => sub () {
            #warn "THERE";
            ()
        },
    }
}

subtest '... check the tagged union' => sub {

    # https://en.wikipedia.org/wiki/Tagged_union#/media/File:Tagged_union_tree.svg
    my $tree = Node( 5,
        Node( 1, Leaf(), Leaf() ),
        Node( 3,
            Node( 4, Leaf(), Leaf() ),
            Leaf()
        )
    );

    my $result = dump_tree( $tree );

    is_deeply(
        $result,
            [ 5,
        [ 1 ], [ 3,
                  [ 4 ]]],
        '... match succeeded'
    );

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

