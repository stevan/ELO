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

# ...

sub method ($name, $table) { die 'You cannot call `method` outside of a `typeclass`' }

sub typeclass ($t, $body) {

    my $type = lookup_type($t->[0]);

    local *method = sub ($name, $table) {
        my $tag = $type->symbol =~ s/main//r;

        if ( ref $table eq 'CODE' ) {
            foreach my $constructor ( keys $type->cases->%* ) {
                #warn "${constructor}::${name} CODE";
                no strict 'refs';
                *{"${constructor}::${name}"} = $table;
            }
        }
        elsif ( ref $table eq 'HASH' ) {
            # TODO; verify that the table contains all the cases
            foreach my $constructor ( keys %$table ) {
                my $handler = $table->{$constructor};
                #warn "${tag}::${constructor}::${name} HASH";
                no strict 'refs';
                *{"${tag}::${constructor}::${name}"} = sub ($self) { $handler->( @$self ) };
            }
        }
        else {
            die 'Unsupported method type, only CODE and HASH supported';
        }
    };

    $body->();
}

# ...

datatype *Tree => sub {
    case Node => ( *Int, *Tree, *Tree );
    case Leaf => ();
};

typeclass[ *Tree ], sub {

    method is_leaf => {
        Node => sub ($, $, $) { 0 },
        Leaf => sub ()        { 1 },
    };

    method is_node => {
        Node => sub ($, $, $) { 1 },
        Leaf => sub ()        { 0 },
    };

    method get_value => {
        Node => sub ($x, $, $) { $x },
        Leaf => sub ()         { () },
    };

    method get_left => {
        Node => sub ($, $left, $) { $left },
        Leaf => sub ()            { die "Cannot call get_left on Leaf" },
    };

    method get_right => {
        Node => sub ($, $, $right) { $right },
        Leaf => sub ()             { die "Cannot call get_right on Node" },
    };

    method traverse => sub ($t, $f, $depth=0) {
        match[ *Tree => $t ], +{
            Node => sub ($x, $left, $right) {
                $f     -> ($x, $depth);
                $left  -> traverse ($f, $depth+1);
                $right -> traverse ($f, $depth+1);
            },
            Leaf => sub () {
                $f -> (undef, $depth);
            },
        }
    };

    method dump => +{
        Node => sub ($x, $left, $right) {
            [ $x, $left->dump, $right->dump ];
        },
        Leaf => sub () {
            ()
        },
    };
};

subtest '... check the tagged union' => sub {

    # https://en.wikipedia.org/wiki/Tagged_union#/media/File:Tagged_union_tree.svg
    my $tree = Node( 5,
        Node( 1, Leaf(), Leaf() ),
        Node( 3,
            Node( 4, Leaf(), Leaf() ),
            Leaf()
        )
    );

    #warn Dumper $tree;

    is($tree->is_leaf, 0, '... the tree is not a leaf');
    is($tree->is_node, 1, '... the tree is a node');
    is($tree->get_value, 5, '... the tree value is as expected');

    is($tree->get_left->is_leaf, 0, '... the tree->left is not a leaf');
    is($tree->get_left->is_node, 1, '... the tree->left is a node');
    is($tree->get_left->get_value, 1, '... the tree->left value is as expected');

    is($tree->get_right->is_leaf, 0, '... the tree->right is not a leaf');
    is($tree->get_right->is_node, 1, '... the tree->right is a node');
    is($tree->get_right->get_value, 3, '... the tree->right value is as expected');

    is($tree->get_left->get_left->is_leaf, 1, '... the tree->left->left is a leaf');
    is($tree->get_left->get_left->is_node, 0, '... the tree->left->left is not a node');
    is($tree->get_left->get_left->get_value, undef, '... the tree->left->left value is as expected');

    is($tree->get_right->get_left->is_leaf, 0, '... the tree->right->left is not a leaf');
    is($tree->get_right->get_left->is_node, 1, '... the tree->right->left is a node');
    is($tree->get_right->get_left->get_value, 4, '... the tree->right->left value is as expected');

    is($tree->get_right->get_right->is_leaf, 1, '... the tree->right->right is a leaf');
    is($tree->get_right->get_right->is_node, 0, '... the tree->right->right is not a node');
    is($tree->get_right->get_right->get_value, undef, '... the tree->right->right value is as expected');

    $tree->traverse(sub ($arg, $depth) {
        diag( ('  ' x $depth), $arg && "Node($arg)" // "Leaf" );
    });

    my $result = $tree->dump;

    is_deeply(
        $result,
            [ 5,
        [ 1 ], [ 3,
                  [ 4 ]]],
        '... tree->dump gave us the expected results'
    );
};

done_testing;

1;

__END__

