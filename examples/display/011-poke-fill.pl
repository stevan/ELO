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

my $HEIGHT  = 30;
my $WIDTH   = 90;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

{
    $d->clear_screen( Color( 0, 0.7, 1.0 ) );

    # use the hi-res mode to make a smoother vertical gradient
    my $r1 = $d->area->inset_by( Point( 4, 2 ) );
    $d->poke_fill(
        GradientFillHGR(
            $r1,
            Gradient(
                Color( 0.5, 0.3, 0.9 ),
                Color( 0.0, 1.0, 0.4 ),
                $r1->height * 2,
            ),
            Vertical()
        ),
    );

    # horizontal gradients don't really matter, they're the same
    # in GR and HGR
    my $r2 = $d->area->inset_by( Point( 14, 7 ) );
    $d->poke_fill(
        GradientFill(
            $r2,
            Gradient(
                Color( 1.0, 0.1, 0.2 ),
                Color( 0.5, 0.5, 0.5 ),
                $r2->width,
            ),
            Horizontal()
        ),
    );

    # GR gradients can be used if banding is desired
    my $r3 = $d->area->inset_by( Point( 22, 12 ) );
    $d->poke_fill(
        GradientFill(
            $r3,
            Gradient(
                Color( 0.9, 0.6, 0.1 ),
                Color( 0.1, 0.6, 0.9 ),
                $r3->height,
            ),
            Vertical()
        ),
    );
}

$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__
