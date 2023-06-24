#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

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

{
    $d->clear_screen( Color(1,1,1) );

    my $origin = Point( int(rand($WIDTH)), int(rand($HEIGHT)) );

    my @lines;

    my $begin = $origin;
    foreach my $i ( 0 .. $LINES ) {
        my $next = Point( int(rand($WIDTH)), int(rand($HEIGHT)) );

        my $color = Color( rand, rand, rand );

        poke_line(
            $d,
            $begin,
            $next,
            ColorPixel( $color )
        );

        $begin = $next;
    }

    poke_line(
        $d,
        $begin,
        $origin,
        ColorPixel( Color( rand, rand, rand ) )
    );

    print "THE END!";

    sleep(1);
    redo;
}

$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__




