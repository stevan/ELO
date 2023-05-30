#!perl

use v5.36;
use experimental 'try', 'builtin';
use builtin qw[ ceil floor ];

use Data::Dumper;

use Term::ANSIColor qw[ colored ];
use List::Util qw[ max min ];

use Test::More;
use Test::Differences;

use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Types',  qw[
    :core
    :types
    :typeclasses
];

use ELO::Util::TermDisplay;

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

# ...

type *X => *Int;
type *Y => *Int;

datatype *Coord => sub {
    case Coord2D => ( *X, *Y );
};

typeclass[*Coord] => sub {
    method x => { Coord2D => sub ($x, $) { $x } };
    method y => { Coord2D => sub ($, $y) { $y } };

    method flatten => { Coord2D => sub ($x, $y) { $x, $y } };
};

# ...

type *Magnitude => *Int;
type *Direction => *Int;

datatype *Vector => sub {
    case Vector2D => ( *Magnitude, *Direction );
};

typeclass[*Vector] => sub {
    method magnitude => { Vector2D => sub ($m, $) { $m } };
    method direction => { Vector2D => sub ($, $d) { $d } };

    method as_coord => { Vector2D => sub ($m, $d) { Coord2D( $m, $d ) } };
};

# ...

# TODO:
# Make this into an example
#
# Also make a Matrix Actor which can call some of the
# methods as messages, which will also allow us to type
# check the args via events :)

subtest '... testing the Coord2D * Matrix2D types' => sub {

    my $term = ELO::Util::TermDisplay->new;

    my $height = $term->term_height - 10;
    my $width  = $term->term_width;

    my $marker = '●';

    my $matrix = Matrix2D( $height, $width, [] )->alloc;
    isa_ok($matrix, '*::Matrix::Matrix2D');

    foreach ( 0 .. 500 ) {
        $matrix->plot(
            Vector2D(
                int(rand($matrix->height))+1,
                int(rand($matrix->width))+1
            ),
            colored( $marker, 'ansi'.int(rand(255)) )
        );
    }

    say $matrix->to_string;
    #say $matrix->to_graph;
    #warn Dumper $matrix;

    ok(1, '... shhh');
};


done_testing;

1;

__END__








