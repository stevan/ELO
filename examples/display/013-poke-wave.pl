#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

$|++;

use Time::HiRes qw[ sleep ];
use List::Util qw[ shuffle sample ];

use Data::Dumper;

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];

use ELO::Graphics;

# ...

my $HEIGHT  = $ARGV[0] // 40;
my $WIDTH   = $ARGV[1] // 80;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

my $Purple = Color(0.6, 0.1, 0.3);

my $Red   = Color(0.9, 0.1, 0.1);
my $Green = Color(0.1, 0.9, 0.1);
my $Blue  = Color(0.1, 0.1, 0.9);
my $Black = Color(0.0, 0.0, 0.0);
my $Yellow = Color(1.0, 0.9, 0.0);

my $Background = Color(0.3,0.3,0.3);

$d->hide_cursor;
$d->enable_alt_buffer;

$SIG{INT} = sub {
    $d->disable_alt_buffer;
    $d->show_cursor;
    $d->end_cursor;
    say "\n\n\nInteruptted!";
    die "Goodbye";
};

my $shift_by = Point( 0, $HEIGHT / 2 );

$d->clear_screen( $Background );
{

    my $scroller = SideScroller(
        $d,
        $d->area->inset_by( Point( 2, 2 )),
        $Background->add( Color( 0.1, 0.3, 1.0 ) ),
        sub ( $d, $x, $t ) {
            state @waves = (
                Wave( 2, 0.065, 0 ),
                Wave( 1, 0.050, 0 ),
                Wave( 4, 0.010, 0 ),
                Wave( 2, 0.075, 0 ),
                Wave( 1, 0.050, 10 ),
            );

            my $g_to_top = Gradient(
                Color( 0.0, 1.0, 0.0 ),
                Color( 0.2, 0.3, 0.2 ),
                20,
            );

            my $g_to_bottom = Gradient(
                Color( 0.0, 0.0, 1.0 ),
                Color( 1.0, 0.0, 0.3 ),
                20,
            );

            my %colors = (
                cosec => $Blue,
                sec   => Color( 0.8, 0.6, 0.1 ),
                tan   => Color( 0.2, 0.6, 0.3 ),
                cot   => Color( 0.1, 0.3, 0.5 ),
                sin   => $Red,
                cos   => $Green,
            );

            my $y = 0;
            $y += $_->cos( $t ) foreach  @waves;

            if ($y <= 18 && $y > -18) {

                my $to_bottom = int(($HEIGHT /2) - $y) - 1;
                my $to_top    = int(($HEIGHT /2) + $y) - 2;

                foreach ( 1 .. $to_bottom ) {
                    $d->poke(
                        Point( $x, $y + $_ )->add($shift_by),
                        ColorPixel( $g_to_bottom->calculate_at( $_ ) )
                    );
                }

                foreach ( 1 .. $to_top ) {
                    $d->poke(
                        Point( $x, $y - $_ )->add($shift_by),
                        ColorPixel( $g_to_top->calculate_at( $_ ) )
                    );
                }

                $d->poke( Point( $x, $y )->add($shift_by), ColorPixel( $Black ));
                $d->poke( Point( $x, $y - 8 )->add($shift_by), ColorPixel( $Yellow ));
                $d->poke( Point( $x, $y + 8 )->add($shift_by), ColorPixel( $Red ));

                #warn "$method => $y \n" ;
            }
        }
    );

    my $t = 0;
    while (1) {
        sleep(0.03);
        $scroller->scroll( $t -= 0.5 );
    }
}

$d->disable_alt_buffer;
$d->show_cursor;
$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__






