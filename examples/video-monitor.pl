#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin qw[ ceil floor indexed ];

use Data::Dumper;
use Data::Dump;

use Time::HiRes     qw[ sleep time ];
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

my sub sanitize ($x) { defined $x && $x > 23 ? 23 : ($x < 0 ? 0 : int($x)) }

my $BLOCK = ' ';
my $PIXEL = '▀';

type *Height => *Int;
type *Width  => *Int;

datatype *Display => sub {
    case MonochromeDisplay => ( *Width, *Height );
};

typeclass[*Display] => sub {

    state $tc;
    state @buffer;

    method turn_on => {
        MonochromeDisplay => sub ($w, $h) {
            $tc = _init_termcap;
            $tc->Tputs('vi', 1, *STDOUT);
            $tc->Tputs('cl', 1, *STDOUT);

            @buffer = ( map { ' ' x $w } 0 .. $h );
        }
    };

    method turn_off => {
        MonochromeDisplay => sub ($w, $h) {
            $tc->Tputs('ve', 1, *STDOUT) if $tc;
            $tc->Tputs('cl', 1, *STDOUT) if $tc;
        }
    };

    method render_frame => sub ($d, $shader) {

        match [ *Display, $d ] => {
            MonochromeDisplay => sub ($w, $h) {
                my @frame;
                foreach my ($x1, $x2) ( 0 .. $h-1 ) {
                    my @row;
                    foreach my $y ( 0 .. $w-1 ) {
                        push @row => colored(
                            $PIXEL,
                            join ' ' => (
                                   'grey'.sanitize($shader->( $x1, $y )),
                                'on_grey'.sanitize($shader->( $x2, $y )),
                            )
                        );
                    }
                    push @frame => join '' => @row;
                }

                $tc->Tgoto('cm', 0, 0, *STDOUT);
                foreach my $i ( 0 .. $#frame ) {
                    #$tc->Tputs('ce', 1, *STDOUT);
                    #die if $frame[$i] eq $buffer[$i];
                    print $frame[$i]#.('-' x $i)
                        if $frame[$i] ne $buffer[$i];
                    $tc->Tputs('do', 1, *STDOUT);
                }
                #$tc->Tgoto('cm', 0, 0, *STDOUT);

                @buffer = @frame;
            }
        }
    };

};

my $d = MonochromeDisplay( 80, 60 );

my $start = time;
my $tick  = 0;

sub print_stats {
    my $duration = time - $start;
    printf 'elapsed: %.05f frames: %05d fps: %.02f' => $duration, $tick, (($duration / $tick) * 1000);
}

$d->turn_on;
$SIG{INT} = sub {
    $d->turn_off;
    print_stats;
    exit(0);
};

while (++$tick) {
    $d->render_frame(sub ($x, $y) { $x * ($tick / 10) });
    print_stats;
    #say $tick;
    sleep(0.03);
}

1;

__END__




