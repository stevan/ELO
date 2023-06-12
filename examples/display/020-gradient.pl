#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Time::HiRes qw[ sleep ];

use Data::Dumper;

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];

use ELO::Graphics qw[
    Color
    Palette
    TransPixel
    ColorPixel
    CharPixel
    Image
    ImageData
    Display
    Point
];

# ...

my $HEIGHT  = 24;
my $WIDTH   = 94;
my $DELAY   = 0.5;

my $d = Display(
    *STDOUT,
    Point(1,1)->rect_with_extent( Point($HEIGHT, $WIDTH) )
);

$d->clear_screen( Color( 0, 0.7, 1.0 ) );

{
    my $offset_by   = Point( 2, 4 );
    my $transitions = 20;
    my $change_by   = 1/$transitions;

    my $start_color = Color( 0.0, 0.0, 0.0 );

    foreach my $x ( 1 .. 20 ) {
        my $c = $start_color->add( Color( $x * $change_by, $x * $change_by, $x * $change_by ) );
        foreach my $y ( 1 .. 20 ) {
            $d->poke(
                Point( $x, $y )->add( $offset_by ),
                ColorPixel( $c )
            )
        }
    }
}

{
    my $offset_by   = Point( 2, 26 );
    my $transitions = 20;
    my $change_by   = 1/$transitions;

    my $start_color = Color( 0.0, 0.0, 0.0 );

    foreach my $x ( 1 .. 20 ) {
        foreach my $y ( 1 .. 20 ) {
            my $c = $start_color->add( Color( $y * $change_by, $y * $change_by, $y * $change_by ) );
            $d->poke(
                Point( $x, $y )->add( $offset_by ),
                ColorPixel( $c )
            )
        }
    }
}

{
    my $offset_by   = Point( 2, 48 );
    my $transitions = 40;
    my $change_by   = 1/$transitions;

    my $start_color = Color( 0.0, 0.0, 0.0 );
    #my $start_color = Color( 0.3, 0.2, 0.1 );

    foreach my $x ( 1 .. 20 ) {
        my $x_c = $start_color->add( Color( $x * $change_by, $x * $change_by, $x * $change_by ) );
        foreach my $y ( 1 .. 20 ) {
            my $y_c = $start_color->add( Color( $y * $change_by, $y * $change_by, $y * $change_by ) );
            $d->poke(
                Point( $x, $y )->add( $offset_by ),
                ColorPixel( $x_c->add( $y_c ) )
            )
        }
    }
}

{
    my $offset_by   = Point( 2, 70 );
    my $transitions = 40;
    my $change_by   = 1/$transitions;

    my $start_color = Color( 0.0, 0.0, 0.0 );
    #my $start_color = Color( 0.3, 0.2, 0.1 );

    foreach my $x ( 1 .. 20 ) {
        my $x_c = $start_color->add( Color( $x * $change_by, $x * $change_by, $x * $change_by ) );
        foreach my $y ( 1 .. 20 ) {
            my $y_c = $x_c->sub( Color( $y * $change_by, $y * $change_by, $y * $change_by ) );
            $d->poke(
                Point( $x, $y )->add( $offset_by ),
                ColorPixel( $start_color->add( $y_c ) )
            )
        }
    }
}

$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__
