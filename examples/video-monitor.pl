#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin qw[ ceil floor indexed ];

use Data::Dumper;
use Data::Dump;

use Time::HiRes     qw[ sleep   ];
use Term::ANSIColor qw[ colored ];
use List::Util      qw[ max min ];
use Carp            qw[ confess ];

use ELO::Util::TermDisplay;

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
    case Matrix => ( *Width, *Height, *ArrayRef )
};

typeclass[*Matrix] => sub {

    method alloc => sub ($m, $init=undef) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                @$s = map [ map { $init } 0 .. $w ], 0 .. $h;
            }
        };
        return $m;
    };

    method height => { Matrix => sub ($, $h, $) { $h } };
    method width  => { Matrix => sub ($w, $, $) { $w } };

    method get_all_rows => { Matrix => sub ($, $, $s) { @$s } };

    method get_row => sub ($m, $x) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                return $s->[$x]->@*;
            }
        }
    };

    method get_col => sub ($m, $y) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                return map $_->[$y], $s->@*;
            }
        }
    };

    method get => sub ($m, $x, $y) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                return $s->[$x]->[$y];
            }
        }
    };

    method set => sub ($m, $x, $y, $value) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                $s->[$x]->[$y] = $value;
            }
        };
        return $m;
    };

    method set_row => sub ($m, $x, $value) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                $s->[$x]->@* = map $value, $s->[$x]->@*;
            }
        };
        return $m;
    };

    method set_row_with_list => sub ($m, $x, @values) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The `values` array must be the same width($w) as the matrix ($#values)")
                    if $#values != $w;
                $s->[$x]->@* = @values;
            }
        };
        return $m;
    };

    method set_col => sub ($m, $y, $value) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                foreach my $i ( 0 .. $h ) {
                    $s->[$i]->[$y] = $value;
                }
            }
        };
        return $m;
    };

    method set_col_with_list => sub ($m, $y, @values) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
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
            Matrix => sub ($w, $h, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                $s->[$x]->[$y] = $f->( $s->[$x]->[$y], $x, $y );
            }
        };
        return $m;
    };

    method map_row => sub ($m, $x, $f) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for x($x) must be a valid index between 0 and ".$h+1) if $x < 0 || $x >= $h+1;
                foreach my $y ( 0 .. $w ) {
                    $s->[$x]->[$y] = $f->( $s->[$x]->[$y], $x, $y );
                }
            }
        };
        return $m;
    };

    method map_rows => sub ($m, $f) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                foreach my $x ( 0 .. $h ) {
                    foreach my $y ( 0 .. $w ) {
                        $s->[$x]->[$y] = $f->( $s->[$x]->[$y], $x, $y );
                    }
                }
            }
        };
        return $m;
    };

    method map_col => sub ($m, $y, $f) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                raise("The value for y($y) must be a valid index between 0 and ".$w+1) if $y < 0 || $y >= $w+1;
                foreach my $x ( 0 .. $h ) {
                    $s->[$x]->[$y] = $f->( $s->[$x]->[$y], $x, $y );
                }
            }
        };
        return $m;
    };

    method map_cols => sub ($m, $f) {
        match [*Matrix, $m ] => {
            Matrix => sub ($w, $h, $s) {
                foreach my $y ( 0 .. $w ) {
                    foreach my $x ( 0 .. $h ) {
                        $s->[$x]->[$y] = $f->( $s->[$x]->[$y], $x, $y );
                    }
                }
            }
        };
        return $m;
    };

    method DEBUG => {
        Matrix => sub ($w, $h, $s) {
            #warn "h: $h, w: $w \n";
            #warn "rows: (".($s->$#*).")\n";
            warn "!! >> found too many rows" if $h != $s->$#*;
            my $i = 0;
            foreach my $row ( @$s ) {
                #warn sprintf "row[%2d] = %d\n" => $i, $row->$#*;
                warn "!! >> found too many columns in row($i)" if $w != $row->$#*;
                $i++;
            }
            #warn Dumper [ $h, $w, $s ];
        }
    };


    method as_Str => {
        Matrix => sub ($w, $h, $s) {
            join "\n" => (map { join '' => map { $_//' ' } @$_ } @$s);
        }
    };

};


# ...

use POSIX;
use Term::Cap;
use Term::ReadKey qw[ GetTerminalSize ];

my sub _init_termcap {
    my $termios = POSIX::Termios->new; $termios->getattr;
    my $tc = Term::Cap->Tgetent({ TERM => undef, OSPEED => $termios->getospeed });
    # require the following capabilities
    $tc->Trequire(qw/cl ho vi ve do ce/);
    $tc;
}

my $HIDE_CURSOR = (GetTerminalSize())[0] + 100;

my $BLOCK = ' ';
my $PIXEL = '▀';

datatype *Display => sub {
    case MonochromeDisplay => ( *Matrix );
};


typeclass[*Display] => sub {

    state $tc = _init_termcap;

    method height => { MonochromeDisplay => sub ($m) { $m->height } };
    method width  => { MonochromeDisplay => sub ($m) { $m->width  } };

    method turn_on => {
        MonochromeDisplay => sub ($) {
            $tc->Tputs('vi', 1, *STDOUT);
            $tc->Tputs('cl', 1, *STDOUT);
            $SIG{INT} = sub {
                $tc->Tputs('ve', 1, *STDOUT);
                exit(0);
            };
        }
    };

    my sub render_frame ($m, $shader) {
        state @last_frame;

        my @rows = $m->get_all_rows;
        my $h    = $m->height - 1;
        my $w    = $m->width  - 1;

        my @frame;
        foreach my ($x1, $x2) ( 0 .. $h ) {
            my @row;
            foreach my $y ( 0 .. $w ) {
                push @row => colored(
                    $PIXEL,
                    join ' ' => (
                        $shader->( $rows[$x1]->[$y] ),
                        'on_'.$shader->( $rows[$x2]->[$y] )
                    )
                );
            }
            push @frame => join '' => @row;
        }

        #$tc->Tgoto('cm', 0, 0, *STDOUT);
        foreach my $i ( 0 .. $#frame ) {
            #$tc->Tputs('ce', 1, *STDOUT);
            print $frame[$i] #.('-' x $i)
                if @last_frame
                && $frame[$i] ne $last_frame[$i];
            $tc->Tputs('do', 1, *STDOUT);
        }
        $tc->Tgoto('cm', 0, 0, *STDOUT);

        @last_frame = @frame;
    }

    method render_frame => {
        MonochromeDisplay => sub ($m) {
            render_frame($m, sub ($x) {
                # needs to return an ansi color
                'grey'.(defined $x && $x > 23 ? 23 : ($x < 0 ? 0 : int($x)))
            });
        }
    };

};



my $m = Matrix( 120, 80, [] )->alloc(0);
my $d = MonochromeDisplay( $m );

$d->turn_on;

my $tick = 0;
while (++$tick) {
    $m->map_rows(sub ($v, $x, $y) { $x * rand }); #($tick / 100) });
    $d->render_frame;
    sleep(0.016);
}

1;

__END__




