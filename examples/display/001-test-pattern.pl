#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Time::HiRes qw[ alarm ];

use ELO::Graphics;

# -----------------------------------------------------------------------------
# TODO:
# -----------------------------------------------------------------------------
# - implement a Color->generate_random or something similar
# - use an IO::Scalar as *Output to test this
# - implement a refresh screen method that redraws the background
# - make this use ELO::Loop and not `alarm` ;)
# -----------------------------------------------------------------------------

my $H = $ARGV[0] // 40;
my $W = $ARGV[1] // 120;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($W, $H) )
);

# remeber we have a 1,1 origin

# ... seed color and alarm animation
my $seed_color = Color( rand, rand, rand );

local $SIG{ALRM} = sub { $seed_color = Color( rand, rand, rand ) };
alarm 1, 0.25;

my $margin = Point( 4, 2 );
my $area1  = $d->area->inset_by( $margin );
my $area2  = $area1->inset_by( Point( 4, 2 ) );
my $area3  = $area2->inset_by( Point( 8, 4 ) );
my $area4  = $area3->origin
                   ->add( Point(2, 1) )
                   ->rect_with_extent(
                        Point(
                            ($area3->width / 2),
                            $area3->height,
                        )->sub( Point(4, 2) )
                   );

my $area5  = $area3->origin
                   ->add( Point( 2 + ($area3->width / 2),  1 ) )
                   ->rect_with_extent(
                        Point(
                            ($area3->width / 2),
                            $area3->height,
                        )->sub( Point(4, 2) )
                   );
#die Dumper [ $area3, $area5 ];


$d->clear_screen( Color( 0.6, 0.6, 0.6 ) );

$d->poke( Point(0, 0), ColorPixel( Color( 0.5, 0.9, 0.2 ) ) );
$d->poke( Point($W, $H), ColorPixel( Color( 0.5, 0.9, 0.2 ) ) );

$d->poke_rectangle( $area1, Color( 0.6, 0.3, 0.1 ) );
$d->poke( $area1->top_left,     ColorPixel( Color( 1.0, 0.0, 0.0 ) ) );
$d->poke( $area1->top_right,    ColorPixel( Color( 0.0, 1.0, 0.0 ) ) );
$d->poke( $area1->bottom_left,  ColorPixel( Color( 0.0, 0.0, 1.0 ) ) );
$d->poke( $area1->bottom_right, ColorPixel( Color( 1.0, 1.0, 1.0 ) ) );


$d->poke_rectangle( $area2, Color( 0.3, 0.6, 0.2 ) );
$d->poke_rectangle( $area3, Color( 0.3, 0.3, 0.9 ) );
$d->poke_rectangle( $area4, Color( 0.5, 0.5, 0.6 ) );
$d->poke_rectangle( $area5, Color( 0.4, 0.6, 0.6 ) );

while (1) {
    #last;

    $d->poke(
        $area4->origin->add( Point(
                int(rand($area4->width + 1)),
                int(rand($area4->height + 1)),
        )),
        ColorPixel( Color( rand, rand, rand )->mul( $seed_color ) )
    );

    $d->poke(
        $area5->origin->add( Point(
            int(rand($area5->width + 1)),
            int(rand($area5->height + 1)),
        )),
        CharPixel(
            Color( rand, rand, rand )->mul( $seed_color ),
            Color( rand, rand, rand )->mul( $seed_color ),
            '▀'
        )
    );

}

$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__
