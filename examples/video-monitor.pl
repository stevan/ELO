#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';

use Data::Dumper;
use Data::Dump;

package MonochromeDisplay {
    use v5.36;
    use experimental 'try', 'builtin', 'for_list';
    use builtin qw[ ceil floor indexed ];

    use Data::Dumper;
    use Data::Dump;

    use Time::HiRes     qw[ sleep time ];
    use Term::ANSIColor qw[ colored ];
    use List::Util      qw[ max min ];
    use Carp            qw[ confess ];

    # ...
    use POSIX;
    use Term::Cap;
    use Term::ReadKey qw[ GetTerminalSize ];

    use constant HIDE_CURSOR  => 'vi';
    use constant SHOW_CURSOR  => 've';
    use constant CLEAR_SCREEN => 'cl';
    use constant CLEAR_LINE   => 'cm';
    use constant TO_NEXT_LINE => 'do';

    use constant PIXEL => '▀';

    my sub _init_termcap {
        my $termios = POSIX::Termios->new; $termios->getattr;
        my $tc = Term::Cap->Tgetent({ TERM => undef, OSPEED => $termios->getospeed });
        $tc->Trequire( HIDE_CURSOR, SHOW_CURSOR, CLEAR_SCREEN, CLEAR_LINE, TO_NEXT_LINE );
        $tc;
    }

    sub new ($class, $width, $height, $refresh_rate) {
        my $self = {
            refresh => ($refresh_rate // die 'A `refresh_rate` is required'),
            width   => ($width        // die 'A `width` is required'),
            height  => ($height       // die 'A `height` is required'),
            tc      => _init_termcap,
            fh      => \*STDOUT,
        };
        bless $self => $class;
    }

    sub turn_on ($self) {
        my $fh  = $self->{fh};
        my $tc  = $self->{tc};

        $tc->Tputs(HIDE_CURSOR,  1, *$fh );
        $tc->Tputs(CLEAR_SCREEN, 1, *$fh );

        $self;
    }

    sub turn_off ($self) {
        my $fh  = $self->{fh};
        my $tc  = $self->{tc};

        $tc->Tputs(SHOW_CURSOR,  1, *$fh );
        $tc->Tputs(CLEAR_SCREEN, 1, *$fh );

        $self;
    }

    my sub sanitize ($x) { defined $x && $x > 23 ? 23 : ($x < 0 ? 0 : int($x)) }

    sub run_shader ($self, $shader) {
        my $fh  = $self->{fh};
        my $tc  = $self->{tc};

        # FIXME: respect previously set singal
        # but not really urgent now
        $SIG{INT} = sub { $self->turn_off; exit(0) };

        my $ticks    = 0;
        my @row_idxs = (0 .. ($self->{height}-1));
        my @col_idxs = (0 .. ($self->{width} -1));
        my @buffer   = ( map { ' ' x $self->{width} } @row_idxs );

        #  fps | time in milliseconds
        # -----+---------------------
        #  60  |  0.01667
        #  50  |  0.02000
        #  30  |  0.03333
        #  25  |  0.04000
        #  10  |  0.10000

        my $refresh = $self->{refresh};
        my $timing  = 1 / $refresh;

        do {
            my $start = time;

            my @frame;
            foreach my ($x1, $x2) ( @row_idxs ) {
                push @frame => join '' => map {
                    colored(PIXEL,
                           'grey'.sanitize($shader->( $x1, $_, $ticks )).' '.
                        'on_grey'.sanitize($shader->( $x2, $_, $ticks ))
                    )
                } @col_idxs;
            }

            my $rows_rendered = 0;
            $tc->Tgoto(CLEAR_LINE, 0, 0, *$fh);
            foreach my $i ( 0 .. $#frame ) {
                if ( $frame[$i] ne $buffer[$i] ) {
                    print $frame[$i];
                    $rows_rendered++;
                }
                $tc->Tputs(TO_NEXT_LINE, 1, *$fh);
            }

            @buffer = @frame;

            my $dur = time - $start;

            #sleep( $timing - $dur ) if $dur < $timing;

            # my $fps = 1 / $timing + $dur;
            my $fps = 1 / $dur;
            printf 'tick: %05d | lines-drawn: %03d | fps: %.03f | time(ms): %.05f' => $ticks, $rows_rendered, $fps, $dur;

        } while ++$ticks;
    }
}

my $d = MonochromeDisplay->new( 120, 60, 120 )
            ->turn_on
            ->run_shader(sub ($x, $y, $t) { $x * ($t / 1000) });


1;

__END__





