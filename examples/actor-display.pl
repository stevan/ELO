#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor';

use ELO::Loop;
use ELO::Types  qw[ :core :events ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive ];

use Data::Dumper;

use List::Util  qw[ min ];
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
    state $frame = 1;
    state $start = time;

    my $height = $h-1;
    my $width  = $w-1;

    my @rows = reverse 0 .. $height;
    my @cols =         0 .. $width;

    my $time = time;

    print HOME_CURSOR;
    foreach my ($x1, $x2) ( @rows ) {
        foreach my $y ( @cols ) {
            printf( PIXEL_FORMAT,
                # normalize it to 0 .. 255
                map { $_ < 0 ? 0 : min(255, int(255 * $_)) }
                    $shader->( $x1, $y, $time ),
                    $shader->( $x2, $y, $time ),
            );
        }
        say '';
    }
    print RESET;

    my $dur = time - $start;
    my $fps = 1 / ($dur / $frame);

    printf(GOTO_FORMAT, ($h/2)+2, 0);
    printf('frame: %05d | fps: %3d | elapsed: %f',
        $frame, $fps, $dur);

    $frame++;
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

    # https://www.youtube.com/watch?v=f4s1h2YETNY&ab_channel=kishimisu
    # this follows along with the video

    my sub pallete ($t) {

        state @a = (0.5, 0.5, 0.5);
        state @b = (0.5, 0.5, 0.5);
        state @c = (1.0, 1.0, 1.0);
        state @d = (0.263, 0.416, 0.557);

        my @r;
        foreach my $i ( 0, 1, 2 ) {
            my $a = $a[$i];
            my $b = $b[$i];
            my $c = $c[$i];
            my $d = $d[$i];

            #$r[$i] = $a[$i] + $b[$i] * cos( 6.28318 * ($c[$i] * $t + $d[$i]));
            $r[$i] = ($a + $b * cos( 6.28318 * ($c * $t + $d )));
        }

        return @r;
    }

    my sub shader2 ($x, $y, $t) {
        state $height = $HEIGHT-1;
        state $width  =  $WIDTH-1;
        state $aspect = ($height / $width);

        # START COORDS

        $x = $x / $height;
        $y = $y /  $width;

        # center the coordinates and
        # shift them into the colorspace
        $x = $x * 2.0 - 1.0;
        $y = $y * 2.0 - 1.0;

        # make sure we don't strech the canvas
        $x *= $aspect;

        # DONE COORDS

        my @final_color = (0, 0, 0);

        my $d0 = sqrt(($x*$x) + ($y*$y));

        for( my $i = 0.0; $i < 3.0; $i++ ) {

            # START REPETITION
            $x = $x * 1.5;
            $y = $y * 1.5;

            $x = $x - floor($x);
            $y = $y - floor($y);

            $x -= 0.5;
            $y -= 0.5;

            # END REPETITION

            # length
            my $d = sqrt(($x*$x) + ($y*$y));

            $d *= exp( -$d0 );

            my @color = pallete($d0 + $i * 0.4 + $t * 0.4);

            $d = sin($d * 8 + $t)/8;
            $d = abs($d);

            # step it ...
            $d = $d < 0.1 ? ($d / 0.1) : 1;

            #$d = 0.04 / $d;
            $d = (0.04 / $d) ** 1.2;

            $final_color[0] += $color[0] * $d;
            $final_color[1] += $color[1] * $d;
            $final_color[2] += $color[2] * $d;
        }

        return @final_color;
    }

    #shader2( $_, $_, $_ ) foreach 0 .. 60 * 60;
    #die;

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

    my $i0 = $this->loop->add_interval( (1 / $FPS), sub { run_shader( $HEIGHT, $WIDTH, \&shader2 ) });

    timer( $this, $TIMEOUT, sub {
        $this->loop->cancel_timer( $i0 );
        turn_off();
        $this->exit(0);
    });

}

ELO::Loop->run( \&init );

1;

__END__


