#!perl

use v5.36;

use Data::Dumper;

use Time::HiRes qw[ sleep ];

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];

use ELO::Graphics;

# ...

my $HEIGHT  = 40;
my $WIDTH   = 120;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);


$d->clear_screen( Color( 0.0, 0.2, 0.4 ) );
$d->hide_cursor;

my @pixels = map {
    [ Point( int(rand($WIDTH)), 0 ), rand() ]
} 0 .. ($WIDTH * 2);

while (1) {

    foreach my $p (@pixels) {

        $d->poke( $p->[0], ColorPixel( Color( 0.0, 0.2, 0.4 ) ) );


        $p->[0] = $p->[0]->add( Point(
                (rand() > rand() ? -rand() : rand()) * $p->[1],
                (rand() * 0.66) + $p->[1],
            )
        );

        if ( $p->[0]->y >= $HEIGHT ) {

            $p->[0] = Point( int(rand($WIDTH)), 0 );
            $p->[1] = rand;
        }

        if ( $p->[0]->x >= $WIDTH ) {

            $p->[0] = Point( int(rand($WIDTH)), 0 );
            $p->[1] = rand;
        }


        $d->poke(
            $p->[0],
            CharPixel(
                Color( 0.0, 0.2, 0.4 ),
                Color( 0.0, 0.5, 0.9 )->add( Color( $p->[1], $p->[1], $p->[1] ) ),
                '*',
            )
        );
    }


    sleep(0.016);
}

$d->show_cursor;
$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__
