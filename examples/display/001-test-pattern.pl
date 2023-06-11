
#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Time::HiRes qw[ alarm sleep ];


# -----------------------------------------------------------------------------
# TODO:
# -----------------------------------------------------------------------------
# - implement a Color->generate_random or something similar
# - use an IO::Scalar as *Output to test this
# - implement a refresh screen method that redraws the background
# -----------------------------------------------------------------------------

my $H = $ARGV[0] // 40;
my $W = $ARGV[1] // 160;

my $d = Device(
    *STDOUT,
    Point(1,1)->rect_with_extent( Point($H, $W) )
);

# remeber we have a 1,1 origin

# ... seed color and alarm animation
my $seed_color = Color( rand, rand, rand );

local $SIG{ALRM} = sub { $seed_color = Color( rand, rand, rand ) };
alarm 1, 0.25;

my $margin = Point( 2, 4 );
my $area1  = $d->area->inset_by( $margin );
my $area2  = $area1->inset_by( Point( 2, 4 ) );
my $area3  = $area2->inset_by( Point( 4, 8 ) );
my $area4  = $area3->origin
                   ->add( Point(1, 2) )
                   ->rect_with_extent(
                        Point(
                            $area3->height,
                            ($area3->width / 2)
                        )->sub( Point(2, 3) )
                   );

my $area5  = $area3->origin
                   ->add( Point(1, 1+($area3->width / 2)) )
                   ->rect_with_extent(
                        Point(
                            $area3->height,
                            ($area3->width / 2)
                        )->sub( Point(2, 3) )
                   );
#die Dumper [ $area3, $area5 ];

$d->clear_screen( Color( 0.6, 0.6, 0.6 ) );

$d->draw_rectangle( $area1, Color( 0.6, 0.3, 0.1 ) );
$d->draw_rectangle( $area2, Color( 0.3, 0.6, 0.2 ) );
$d->draw_rectangle( $area3, Color( 0.3, 0.3, 0.9 ) );
$d->draw_rectangle( $area4, Color( 0.5, 0.5, 0.6 ) );
$d->draw_rectangle( $area5, Color( 0.4, 0.6, 0.6 ) );

do {
    #last;

    $d->poke_color(
       $area4->origin->add( Point(
           int(rand($area4->height)),
           int(rand($area4->width)),
       )),
       Color( rand, rand, rand )->mul( $seed_color ),
    );

    $d->poke_char(
        $area5->origin->add( Point(
            int(rand($area4->height)),
            int(rand($area4->width)),
        )),
        '▀',
        Color( rand, rand, rand )->mul( $seed_color ),
        Color( rand, rand, rand )->mul( $seed_color ),
    );

} while 1;

$d->end_cursor;

1;

__END__
