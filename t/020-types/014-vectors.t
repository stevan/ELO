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

# ...

type *Height => *Int;
type *Width  => *Int;
type *Space  => *ArrayRef;

# ...

datatype *Matrix => sub {
    case Matrix2D => ( *Height, *Width, *Space )
};

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
                return $s->[$coord->x]->[$coord->y];
            }
        }
    };

    method set => sub ($m, $coord, $value) { # *Coord2D, *Any
        match [*Matrix, $m ] => {
            Matrix2D => sub ($, $, $s) {
                my ($x, $y) = @$coord;
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
                }
            }
        };

    };

    method to_string => sub ($m) {
        match [*Matrix, $m ] => {
            Matrix2D => sub ($h, $w, $s) {
                join "\n" => (map { join '' => map { $_//'u' } @$_ } reverse @$s);
            }
        }
    };

    method to_graph => sub ($m) {
        match [*Matrix, $m ] => {
            Matrix2D => sub ($h, $w, $s) {
                my $marker2 = colored('|_', 'dark cyan');
                my $marker1 = colored('_', 'dark cyan');

                join "\n" => map {
                    join '' => map {
                        defined $_ ? ($_.$marker1) : $marker2
                    } @$_
                } reverse @$s;
            }
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

=pod


      |
      |---*
      |  /|
      |_*_|___
     /
    /

=cut

subtest '... testing the Coord2D * Matrix2D types' => sub {

    my $matrix = Matrix2D( 25, 40, [] )->alloc;


    my @vectors = (
        [ Vector2D( 2, 10 ), colored( '=', 'ansi210' ) ],
        [ Vector2D( 3,  5 ), colored( '◼︎', 'ansi35' ) ],
        [ Vector2D( 16, 9 ), colored( '/', 'ansi169' ) ],
        [ Vector2D( 9 ,12 ), colored( '*', 'ansi129' ) ],
    );

    foreach ( @vectors ) {
        my ($v, $marker) = @$_;
        $matrix->plot( $v, $marker );
        $matrix->set( $v->as_coord, colored( '@', 'red' ) );
    }

    $matrix->set( Coord2D(0, 0), '&' );

    #say $matrix->to_string;
    say $matrix->to_graph;
    #warn Dumper $matrix;


    ok(1, '... shhh');
};


done_testing;

1;

__END__








