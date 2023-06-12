#!perl

use v5.36;
use experimental 'try', 'builtin';
use builtin qw[ ceil floor ];

use Data::Dumper;

use List::Util qw[ max min ];

use Test::More;
use Test::Differences;

use ok 'ELO::Types',  qw[
    :core
    :types
    :typeclasses
];

# ...

type *X => *Int;
type *Y => *Int;

datatype [ Point => *Point ] => ( *X, *Y );

=pod

Here is one option, where we specify the signature in the method definition
though I am not sure it would work for tagged unions, maybe like this::

typeclass[*Point] => sub {

    method add => {
        Point2D => [*Point, *Point => *Point] => sub ($p1, $p2) {
            Point2D( $p1->x + $p2->x, $p1->y + $p2->y )
        },
        Point3D => [*Point, *Point => *Point] => sub ($p1, $p2) {
            Point3D( $p1->x + $p2->x, $p1->y + $p2->y, $p1->x + $p2->x )
        }
    };

};


Anyway, here is the idea ....

typeclass[*Point] => sub {

    method x => *X;
    method y => *Y;

    method add => [*Point, *Point => *Point] => sub ($p1, $p2) { Point( $p1->x + $p2->x, $p1->y + $p2->y ) };
    method sub => [*Point, *Point => *Point] => sub ($p1, $p2) { Point( $p1->x - $p2->x, $p1->y - $p2->y ) };
    method mul => [*Point, *Point => *Point] => sub ($p1, $p2) { Point( $p1->x * $p2->x, $p1->y * $p2->y ) };

    method min => [*Point, *Point => *Point] => sub ($p1, $p2) {
        # returns the top-left corner defined by rectangle of $p1 x $p2
        return $p1 if $p1->x <= $p2->x && $p1->y <= $p2->y; # $p1 is above and to the to the left of $p2
        return $p2 if $p2->x <= $p1->x && $p2->y <= $p1->y; # $p2 is below and to the to the right of $p1
    };

    method max => [*Point, *Point => *Point] => sub ($p1, $p2) {
        # returns the bottom-right corner defined by rectangle of $p1 x $p2
        return $p1 if $p1->x >= $p2->x && $p1->y >= $p2->y; # $p1 is below and to the to the right of $p2
        return $p2 if $p2->x >= $p1->x && $p2->y >= $p1->y; # $p2 is below and to the to the right of $p1
    };

    method equals => [*Point, *Point => *Bool]  => sub ($p1, $p2) {
        return 1 if $p1->x == $p2->x && $p1->y == $p2->y;
        return 0;
    };

    # Rectangle constructors
    method extent => [*Point, *Point => *Rectangle] => sub ($p1, $p2) { Rectangle( $p1, $p1->add( $p2 ) ) };
    method corner => [*Point, *Point => *Rectangle] => sub ($p1, $p2) { Rectangle( $p1, $p2 ) };
};

=cut


# ...

type *Height => *Int;
type *Width  => *Int;
type *Space  => *ArrayRef;

# ...

datatype *Matrix => sub {
    case Matrix2D => ( *Height, *Width, *Space )
};

# IDEA:
# What about something like this??
#
# signature[ *Matrix => *T ] => sub {
#
#     method alloc => [ *T ] => [ *Matrix ];
#
#     method height => [] => [ *Height ];
#     method width  => [] => [ *Width  ];
#
#     method get => [ *Coord ]       => [ *Any ];
#
#     method map  => [ *CodeRef ]      => [ *Matrix ];
#     method set  => [ *Coord,  *Any ] => [ *Matrix ];
#     method plot => [ *Vector, *Any ] => [ *Matrix ];
#
#     method to_string => [] => [ *Str ];
#     method to_graph  => [] => [ *Str ];
# };
#
# to (at a minimum) add typechecking to the
# functions.

# XXX : Perhaps also be able to compile the
# methods with arguments into variants instead of
# having to install the same function in all classes
# and let the internal `match` do it's (slow) thing.

typeclass[*Matrix] => sub {

    method alloc => sub ($m, $init=undef) {
        match [*Matrix, $m ] => {
            Matrix2D => sub ($h, $w, $s) {
                @$s = map [ map { $init } 0 .. $w-1 ], 0 .. $h-1;
            }
        };
        return $m;
    };

    method height => { Matrix2D => sub ($h, $, $) { $h } };
    method width  => { Matrix2D => sub ($, $w, $) { $w } };

    method map => sub ($m, $f) {
        match [*Matrix, $m ] => {
            Matrix2D => sub ($, $, $s) {
                # this might be better done in place
                # instead of a copy, **shrug**
                @$s = map [ map { $f->( $_ ) } @$_ ], @$s;
            }
        };
        return $m;
    };

    method get => sub ($m, $coord) { # *Coord2D -> *Any
        match [*Matrix, $m ] => {
            Matrix2D => sub ($, $, $s) {
                my ($x, $y) = $coord->flatten;
                return $s->[$x]->[$y];
            }
        }
    };

    method set => sub ($m, $coord, $value) { # *Coord2D, *Any
        match [*Matrix, $m ] => {
            Matrix2D => sub ($, $, $s) {
                $s->[$coord->x]->[$coord->y] = $value;
            }
        };
        return $m;
    };

    method plot => sub ($m, $vector, $value) { #Vector2D, *Any

        # FIXME: this is crude and can be done better
        my sub round ($x) { $x >= (floor($x) + 0.5) ? ceil($x) : floor($x) };

        match [*Matrix, $m ] => {
            Matrix2D => sub ($h, $w, $s) {

                my $mag = $vector->magnitude;
                my $dir = $vector->direction;

                my $y = 0;
                while (1) {
                    my $x = round($y / ($dir / $mag));
                    #say "$vector - x($x), y($y)";
                    # dont go off the edge here ...
                    last if $x > $h-1 || $y > $w-1;

                    $s->[$x]->[$y] = $value;

                    $y++;

                    # ohh, stripey :)
                    # $y += 5 if $y % 5 == 0;
                }
            }
        };
        return $m;
    };

    method to_string => {
        Matrix2D => sub ($h, $w, $s) {
            join "\n" => (map { join '' => map { $_//' ' } @$_ } reverse @$s);
        }
    };

    method to_graph => {
        Matrix2D => sub ($h, $w, $s) {
            my $marker2 = colored('|_', 'dark blue');
            my $marker1 = colored('_', 'dark blue');

            join "\n" => map {
                join '' => map {
                    defined $_ ? ($_.$_) : $marker2
                } @$_
            } reverse @$s;
        }
    };
};


done_testing;

1;

__END__








