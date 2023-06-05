#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';

use ELO::Loop;
use ELO::Types  qw[ :core :events ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive ];

use Data::Dumper;

use Time::HiRes qw[ sleep time ];

$|++;

# cursors
use constant HIDE_CURSOR  => "\e[?25l";
use constant SHOW_CURSOR  => "\e[?25h";
use constant HOME_CURSOR  => "\e[0;0H";

# clearing and reseting terminal attributes
use constant CLEAR_SCREEN => "\e[0;0H;\e[2J";
use constant RESET        => "\e[0m";

# formats for codes with args ...

use constant PIXEL        => '▀';
use constant PIXEL_FORMAT => "\e[38;2;%d;%d;%d;48;2;%d;%d;%d;m".PIXEL;

use constant GOTO_FORMAT  => "\e[%d;%dH";

sub turn_on () {
    print HIDE_CURSOR;
    print CLEAR_SCREEN;
}

sub turn_off () {
    print SHOW_CURSOR;
    print CLEAR_SCREEN;
    print RESET;
}

sub run_shader ($h, $w, $shader) {
    state $ticks = 1;
    state $start = time;

    print HOME_CURSOR;
    foreach my ($x1, $x2) ( 0 .. $h-1 ) {
        foreach my $y ( 0 .. $w-1 ) {
            printf( PIXEL_FORMAT,
                $shader->( $x1, $y, $ticks ),
                $shader->( $x2, $y, $ticks ),
            );
        }
        say '';
    }
    print RESET;

    my $dur = time - $start;
    my $fps = 1 / ($dur / $ticks);

    printf(GOTO_FORMAT, ($h/2)+2, 0);
    printf('frame: %05d | fps: %3d | elapsed: %f',
        $ticks, $fps, $dur);

    $ticks++;
}

#  fps | time in milliseconds
# -----+---------------------
#  120 | 0.00833
#  100 | 0.01000
#   60 | 0.01667
#   50 | 0.02000
#   30 | 0.03333
#   25 | 0.04000
#   10 | 0.10000

my $FPS     = $ARGV[0] // 30;
my $HEIGHT  = $ARGV[1] // 60;
my $WIDTH   = $ARGV[2] // 120;
my $TIMEOUT = $ARGV[3] // 10;

die "Height must be a even number, ... or reall weird stuff happens" if ($HEIGHT % 2) != 0;

sub init ($this, $) {

    my sub shader ($x, $y, $t) {

        #return $x, $y, $t;

        #return (55,55,55) if $x == 0 || $x == ($HEIGHT-1);
        #return (55,55,55) if $y == 0 || $y == ($WIDTH-1);

        return (0, 0, 0) if ($x % 10) == 0; # || $x > ($HEIGHT-5);
        return (0, 0, 0) if ($y % 10) == 0; # || $y > ($WIDTH-5);

        my $r = ((($t / 255) % 2) == 0) ? ($t % 255) : (255 - ($t % 255));
        my $g = $x;
        my $b = $y;

        #return $r, $g, $b;

        # make some plaid ...
        my $bump = 25;
        foreach ( 6, 4, 8 ) {
            ($r+=$bump, $g+=$bump, $b+=$bump) if ($y % $_) == 0;
            ($r+=$bump, $g+=$bump, $b+=$bump) if ($x % $_) == 0;
            $bump += ($bump < 0) ? 30 : -45;
        }

        # make sure we don't overflow ...
        $r = 255 if $r > 255;
        $g = 255 if $g > 255;
        $b = 255 if $b > 255;

        $r = 0 if $r < 0;
        $g = 0 if $g < 0;
        $b = 0 if $b < 0;

        return $r, $g, $b;
    }

    #die (0.1 / $FPS);

    turn_on();

    my $i0 = $this->loop->add_interval( (1 / $FPS), sub { run_shader( $HEIGHT, $WIDTH, \&shader ) });

    timer( $this, $TIMEOUT, sub {
        $this->loop->cancel_timer( $i0 );
        turn_off();
        $this->exit(0);
    });

}

ELO::Loop->run( \&init );

1;

__END__


