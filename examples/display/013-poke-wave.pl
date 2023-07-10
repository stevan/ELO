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

my $HEIGHT  = $ARGV[0] // 40;
my $WIDTH   = $ARGV[1] // 90;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

my $Purple = Color(0.6, 0.1, 0.3);

my $Red   = Color(0.9, 0.1, 0.1);
my $Green = Color(0.1, 0.9, 0.1);
my $Blue  = Color(0.1, 0.1, 0.9);

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
        $Background->add( Color( 0.1, 0.1, 0.1 ) ),
        sub ( $d, $x, $t ) {
            state $w = Wave( 10, 0.03, 0 );

            my %colors = (
                cosec => $Blue,
                sec   => Color( 0.8, 0.6, 0.1 ),
                tan   => Color( 0.2, 0.6, 0.3 ),
                cot   => Color( 0.1, 0.3, 0.5 ),
                sin   => $Red,
                cos   => $Green,
            );

            foreach my $method (qw[ cosec tan sec cot sin cos ]) {
                my $y = $w->$method( $t );

                if ($y <= 18 && $y > -18) {
                    $d->poke( Point( $x, $y )->add($shift_by), ColorPixel( $colors{$method} ));
                    #warn "$method => $y \n" ;
                }
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






