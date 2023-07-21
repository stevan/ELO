#!perl

use v5.36;

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Types',  qw[
    :core
    :types
    :typeclasses
];

# ...

datatype *Tree => sub {
    case Node => ( *Scalar, *Tree, *Tree );
    case Leaf => ();
};

typeclass[ *Tree ], sub {

    method is_leaf => {
        Node => sub { 0 },
        Leaf => sub { 1 },
    };

    method is_node => {
        Node => sub { 1 },
        Leaf => sub { 0 },
    };

    method get_value => {
        Node => *Scalar,
        Leaf => sub { () },
    };

    method get_left => {
        Node => sub ($, $left, $) { $left },
        Leaf => sub ()            { die "Cannot call get_left on Leaf" },
    };

    method get_right => {
        Node => sub ($, $, $right) { $right },
        Leaf => sub ()             { die "Cannot call get_right on Node" },
    };

    method traverse => [ *CodeRef, *Int ] => +{
        Node =>  sub ($t, $f, $depth) {
            $f            ->($t->get_value, $depth);
            $t->get_left  ->traverse ($f, $depth+1);
            $t->get_right ->traverse ($f, $depth+1);
        },
        Leaf => sub ($, $f, $depth=0) {
            $f -> (undef, $depth);
        },
    };

    method traverse2 => sub ($t, $f, $depth=0) {
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

    my @out1;
    $tree->traverse(sub ($arg, $depth) {
        push @out1 => (('  ' x $depth).($arg && "Node($arg)" // "Leaf" ));
    }, 1); # << NOTE the 1 here ;)
    is(
        (join "\n" => @out1),
q[  Node(5)
    Node(1)
      Leaf
      Leaf
    Node(3)
      Node(4)
        Leaf
        Leaf
      Leaf],
          '... got the expected output from traverse'
    );

    my @out2;
    $tree->traverse2(sub ($arg, $depth) {
        push @out2 => (('  ' x $depth).($arg && "Node($arg)" // "Leaf" ));
    });
    is(
        (join "\n" => @out2),
q[Node(5)
  Node(1)
    Leaf
    Leaf
  Node(3)
    Node(4)
      Leaf
      Leaf
    Leaf],
        '... got the expected output from traverse2'
    );

    my $result = $tree->dump;

    is_deeply(
        $result,
            [ 5,
        [ 1 ], [ 3,
                  [ 4 ]]],
        '... tree->dump gave us the expected results'
    );
};

datatype *Option => sub {
    case None => ();
    case Some => ( *Scalar );
};

typeclass[*Option] => sub {

    method get => {
        Some => *Scalar,
        None => sub () { die 'Cannot call get on None' },
    };

    method get_or_else => [ *CodeRef ] => +{
        Some => sub ($o, $) { $o->get },
        None => sub ($, $f) { $f->() },
    };

    method or_else => [ *CodeRef ] => +{
        Some => sub ($o, $) { Some($o->get) },
        None => sub ($, $f) { $f->() },
    };

    method is_defined => {
        Some => sub { 1 },
        None => sub { 0 },
    };

    method is_empty => {
        Some => sub { 0 },
        None => sub { 1 },
    };

    method map => [ *CodeRef ] => +{
        Some => sub ($o, $f) { Some($f->($o->get)) },
        None => sub ($,   $) { None() },
    };

    method filter => [ *CodeRef ] => +{
        Some => sub ($o, $f) { $f->($o->get) ? Some($o->get) : None() },
        None => sub ($,   $) { None() },
    };

    method foreach => [ *CodeRef ] => +{
        Some => sub ($o, $f) { $f->($o->get) },
        None => sub ($,   $) { () },
    };

};

sub get ($req, $key) {
    exists $req->{ $key } ? Some( $req->{ $key } ) : None();
}

subtest '... testing the Option type' => sub {

    foreach my $name (qw[ Bob Alice Mary Stevan ], '') {
        my $req = { name => $name };

        my $upper = get($req, 'name') #/ get value from hash
            ->map    (sub ($x) { $x =~ s/\s$//r }) #/ trim any trailing whitespace
            ->filter (sub ($x) { length $x != 0 }) #/ ignore if length == 0
            ->map    (sub ($x) { uc $x          }) #/ uppercase it
        ;

        is(
            $upper->get_or_else(sub { 'FOO' }),
            $name ? uc($name) : 'FOO',
            '... got the result we expected'
        );
    }
};

done_testing;

1;

__END__

