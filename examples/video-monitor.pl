#!perl

use v5.36;
use experimental 'try', 'builtin';
use builtin qw[ ceil floor ];

use Data::Dumper;
use Data::Dump;

use Term::ANSIColor qw[ colored ];
use List::Util      qw[ max min ];
use Carp            qw[ confess ];

use ELO::Actors qw[ match ];
use ELO::Types  qw[
    :core
    :types
    :typeclasses
];

# ...

sub raise ($err) { confess $err }

# ...

type *Height => *Int;
type *Width  => *Int;

# ...

datatype *Matrix => sub {
    case Matrix => ( *Height, *Width, *ArrayRef )
};

typeclass[*Matrix] => sub {

    method alloc => sub ($m, $init=undef) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                @$s = map [ map { $init } 0 .. $w ], 0 .. $h;
            }
        };
        return $m;
    };

    method height => { Matrix => sub ($h, $, $) { $h } };
    method width  => { Matrix => sub ($, $w, $) { $w } };

    method get_all_rows => { Matrix => sub ($, $, $s) { @$s } };

    method get_row => sub ($m, $x) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                return $s->[$x]->@*;
            }
        }
    };

    method get_col => sub ($m, $y) {
        match [*Matrix, $m ] => {
            Matrix => sub ($, $w, $s) {
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                return map $_->[$y], $s->@*;
            }
        }
    };

    method get => sub ($m, $x, $y) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                return $s->[$x]->[$y];
            }
        }
    };

    method set => sub ($m, $x, $y, $value) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                $s->[$x]->[$y] = $value;
            }
        };
        return $m;
    };

    method set_row => sub ($m, $x, @values) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The `values` array must be the same width($w) as the matrix ($#values)")
                    if $#values != $w;
                $s->[$x]->@* = @values;
            }
        };
        return $m;
    };

    method set_col => sub ($m, $y, @values) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                raise("The `values` array must be the same height($h) as the matrix ($#values))")
                    if $#values != $h;
                foreach my $i ( 0 .. $h ) {
                    $s->[$i]->[$y] = $values[$i];
                }
            }
        };
        return $m;
    };

    method map => sub ($m, $x, $y, $f) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                $s->[$x]->[$y] = $f->( $s->[$x]->[$y] );
            }
        };
        return $m;
    };

    method map_row => sub ($m, $x, $f) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                $s->[$x]->@* = map { $f->($_) } $s->[$x]->@*;
            }
        };
        return $m;
    };

    method map_col => sub ($m, $y, $f) {
        match [*Matrix, $m ] => {
            Matrix => sub ($h, $w, $s) {
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                foreach my $i ( 0 .. $h ) {
                    $s->[$i]->[$y] = $f->( $s->[$i]->[$y] );
                }
            }
        };
        return $m;
    };

    method DEBUG => {
        Matrix => sub ($h, $w, $s) {
            warn "h: $h, w: $w \n";
            warn "rows: (".($s->$#*).")\n";
            warn "!! >> found too many rows" if $w != $s->$#*;
            my $i = 0;
            foreach my $row ( @$s ) {
                warn sprintf "row[%2d] = %d\n" => $i, $row->$#*;
                warn "!! >> found too many columns in row($i)" if $h != $row->$#*;
                $i++;
            }
            #warn Dumper [ $h, $w, $s ];
        }
    };


    method as_Str => {
        Matrix => sub ($h, $w, $s) {
            join "\n" => (map { join '' => map { $_//' ' } @$_ } reverse @$s);
        }
    };

};


# ...

my $BLOCK = ' ';
my $PIXEL = '▀';

datatype *Display => sub {
    case MonochromeDisplay => ( *Matrix );
};

typeclass[*Display] => sub {

    method height => { MonochromeDisplay => sub ($m) { $m->height } };
    method width  => { MonochromeDisplay => sub ($m) { $m->width  } };

    my sub run_shader ($m, $rows, $shader) {
        my $h = $m->height;
        my $w = $m->width;

        my $i = 0;
        join "\n" => (
            #'    '.(join '' => 0 .. 9, '_', 1 .. 9, '_' ),
            '   ┏'.('━' x ($w+1)).'┓',
            (map {
                #sprintf('%02d ' => $i++)
                .'┃'
                .(join '' => map { $shader->( $_ ) } @$_)
                .'┃'
            } @$rows),
            '   ┗'.('━' x ($w+1)).'┛',
        );
    }

    method as_Str => {
        MonochromeDisplay => sub ($m) {
            run_shader($m, [ $m->get_all_rows ], sub ($x) {
                colored( $BLOCK => 'on_grey'.(defined $x && $x > 23 ? 23 : ($x < 0 ? 0 : $x)))
            });
        }
    };

};



my $m = Matrix( 20, 20, [] )->alloc(0);

$m->set( $_,        (20 - $_), 10 )
  ->set( (20 - $_), (20 - $_), 15 )
    foreach (0 .. 20);

$m->set_row( 10, map 5,  0 .. 20  )
  ->set_col( 10, map 20, 0 .. 20  );

#say $m->as_Str;
#$m->DEBUG;

my $d = MonochromeDisplay( $m );

#say $d->as_Str;

$m->map_row( 5,  sub ($x) { $x + 5 });
$m->map_col( 15, sub ($x) { $x + 10 });

$m->map( $_, (20 - $_), sub ($x) { $x - 5 } )
    foreach (5 .. 15);

say $d->as_Str;

1;

__END__








