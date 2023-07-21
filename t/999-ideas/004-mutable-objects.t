#!perl

use v5.36;

use Test::More;
use Test::Differences;

use Data::Dumper;

use ok 'ELO::Types', qw[ :core :types ];

=pod

The GLOB accessors can be mutable if we make
the generated methods `lvalue` methods.

type *X => *Int;
type *Y => *Int;

datatype [Point => *Point] => ( *X, *Y );

typeclass[*Point] => sub {
    method x => mutable(*X);
    method y => mutable(*Y);
};

This would then allow this syntax:

my $p = Point(10, 10);
$p->x = 0;
$p->y = 0;

Unfortunately lvalue's cannot be type checked, so
there is that.

=cut

done_testing;



