#!perl

use v5.36;

use Test::More;
use Test::Differences;

use Data::Dumper;

use ok 'ELO::Types', qw[ :core :types ];

=pod

type *T => sub ($type) { !! lookup_type($type) };

datatype *Tree => [ *a ] => sub {
    case Leaf => ();
    case Node => (
        *a,
        (*Tree => *a),
        (*Tree => *a),
    );
};

sub dump_tree ( $t ) {
    match [ *Tree => [*Int], $t ] => +{
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

datatype *Option => [ *T ] => sub {
    case None => ();
    case Some => ( *T );
};


=cut

done_testing;



