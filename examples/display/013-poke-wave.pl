#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

$|++;

use Time::HiRes qw[ sleep ];

use Data::Dumper;

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];

use ELO::Graphics;

# ...

my $HEIGHT  = $ARGV[0] // 30;
my $WIDTH   = $ARGV[1] // 90;
my $LINES   = $ARGV[2] // 10;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

my $PI = 3.14159;

my $Purple = Color(0.6, 0.1, 0.3);

my $Red   = Color(0.9, 0.1, 0.1);
my $Green = Color(0.1, 0.9, 0.1);
my $Blue  = Color(0.1, 0.1, 0.9);

my $Background = Color(0.3,0.3,0.3);

my $offset = 0;

$d->hide_cursor;
#$d->enable_alt_buffer;

$SIG{INT} = sub {
    #$d->disable_alt_buffer;
    $d->show_cursor;
    $d->end_cursor;
    say "\n\n\nInteruptted!";
    die "Goodbye";
};

my $shift_by = Point( 0, $HEIGHT / 2 );

my $a = 10;
my $f = 0.03;
my $b = 0;

sub poke_line ( $d, $p1, $p2, $pixel ) {

    my $x0 = $p1->x;
    my $x1 = $p2->x;

    my $y0 = $p1->y;
    my $y1 = $p2->y;

    my $dx = abs($x1 - $x0);
    my $sx = $x0 < $x1 ? 1 : -1;
    my $dy = -abs($y1 - $y0);
    my $sy = $y0 < $y1 ? 1 : -1;

    my $error = $dx + $dy;

    while (1) {
        $d->poke( Point( $x0, $y0 ), $pixel );

        last if $x0 == $x1 && $y0 == $y1;

        my $e2 = 2 * $error;

        if ($e2 >= $dy) {
            last if ($x0 == $x1);

            $error = $error + $dy;

            $x0 = $x0 + $sx;
        }

        if ($e2 <= $dx) {
            last if $y0 == $y1;

            $error = $error + $dx;

            $y0 = $y0 + $sy;
        }

        #sleep(0.006);
    }
}

sub poke_waves ( $x ) {
    my $sin_y = $a * sin( 2 * $PI * $f * $x + $b );
    my $cos_y = $a * cos( 2 * $PI * $f * $x + $b );

    $d->poke( Point( 0, $sin_y )->add($shift_by), ColorPixel( $Red ));
    $d->poke( Point( 0, $cos_y )->add($shift_by), ColorPixel( $Green ));
}

$d->clear_screen( $Background );
{


    my $x = 0;
    while (1) {
        sleep(0.03);

        foreach ( 5 .. 25 ) {
            $d->move_cursor( Point( 0, $_ ) );
            print "\e[48;2;77;77;77;m\e[@";
            $d->move_cursor( Point( $d->width + 1, $_ ) );
            print "\e[P";
        }

        poke_waves( $x -= 0.5 );
    }
}

#$d->disable_alt_buffer;
$d->show_cursor;
$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__






