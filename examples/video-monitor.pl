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
        local $SIG{INT} = sub { $self->turn_off; exit(0) };

        my $ticks    = 0;
        my @row_idxs = (0 .. ($self->{height}-1));
        my @col_idxs = (0 .. ($self->{width} -1));
        my @buffer   = ( map { ' ' x $self->{width} } @row_idxs );

        #  fps | time in milliseconds
        # -----+---------------------
        #  120 | 0.00833   0.0003 = 0.036 / 120
        #  100 | 0.01000   0.0006 = 0.06 / 100
        #   60 | 0.01667   0.0015 = 0.09 / 60
        #   50 | 0.02000
        #   30 | 0.03333   0.003  = 0.09 / 30
        #   25 | 0.04000
        #   10 | 0.10000

        my $refresh = $self->{refresh};

        my $bias  = 0.0999999999;
           $bias -= ($refresh - 60) * 0.001 if $refresh > 60;

        my $timing  = (1 / $refresh);
           $timing -= ($timing * $bias);

        #$self->turn_off;
        #die join ', ' => ( $refresh, (1 / $refresh), (($timing / $refresh)), ($timing - ($timing / $refresh)) );

        do {
            my ($start, $rows_rendered, $raw_dur, $dur, $raw_fps, $fps);

            $start         = time;
            $rows_rendered = 0;

            my @frame;
            foreach my ($x1, $x2) ( @row_idxs ) {
                push @frame => join '' => map {
                    colored(PIXEL,
                           'grey'.sanitize($shader->( $x1, $_, $ticks )).' '.
                        'on_grey'.sanitize($shader->( $x2, $_, $ticks ))
                    )
                } @col_idxs;
            }

            $tc->Tgoto(CLEAR_LINE, 0, 0, *$fh);
            foreach my $i ( 0 .. $#frame ) {
                if ( $frame[$i] ne $buffer[$i] ) {
                    print $frame[$i];
                    $rows_rendered++;
                }
                $tc->Tputs(TO_NEXT_LINE, 1, *$fh);
            }

            @buffer = @frame;

            $raw_dur = time - $start;
            $raw_fps = 1 / $raw_dur;

            sleep( $timing - $raw_dur ) if $raw_dur < $timing;

            $dur = time - $start;
            $fps = 1 / $dur;

            printf('tick: %05d | lines-drawn: %03d | fps: %3d | raw-fps: ~%.02f | time(ms): %.05f | raw-time(ms): %.05f',
                   $ticks, $rows_rendered, ceil($fps), $raw_fps, $dur, $raw_dur);

        } while ++$ticks;
    }
}

my $FPS = $ARGV[0] // 60;
my $W   = $ARGV[1] // 120;
my $H   = $ARGV[2] // 60;

my $d = MonochromeDisplay->new( 120, 60, $FPS )
            ->turn_on
            ->run_shader(sub ($x, $y, $t) { $t });


1;

__END__





