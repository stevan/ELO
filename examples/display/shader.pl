#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use ELO::Loop;
use ELO::Types  qw[ :core :events ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive ];

use ELO::Util::PixelDisplay;

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

my $display = ELO::Util::PixelDisplay->new( height => $HEIGHT, width => $WIDTH );

# https://www.youtube.com/watch?v=f4s1h2YETNY&ab_channel=kishimisu
# this follows along with the video

sub pallete ($t) {
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

sub shader ($x, $y, $t) {
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

sub init ($this, $) {

    $display->turn_on();


    my $i0 = $this->loop->add_interval(
        (1 / $FPS),
        sub { $display->run_shader( \&shader ) }
    );

    timer( $this, $TIMEOUT, sub {
        $this->loop->cancel_timer( $i0 );
        $display->turn_off();
        $this->exit(0);
    });

    local $SIG{INT} = sub {
        $display->turn_off();
        exit(0);
    };
}

ELO::Loop->run( \&init );

1;

__END__


