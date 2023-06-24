#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

$|++;

use Data::Dumper;
use Time::HiRes qw[ sleep time ];
use List::Util qw[ min max ];

use ELO::Graphics;

my $H = $ARGV[0] // 40;
my $W = $ARGV[1] // 80;
my $F = $ARGV[2] // 200;

#$ELO::Types::TYPES_DISABLED = 1;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($W, $H) )
);

# remeber we have a 1,1 origin

$d->clear_screen( Color( 0.9, 0.7, 0.3 ) );
$d->hide_cursor;

#warn Dumper  $d->area->inset_by( Point( 2, 4 ) );

my $start = time;

my $shader_total;
my $poke_total;

my $frames = 0;

#my $COLOR = Color( rand, rand, rand );
#my $PIXEL = ColorPixel( $COLOR );

my $shader_rect = $d->area->inset_by( Point(4, 2) );

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

        $r[$i] = ($a + $b * cos( 6.28318 * ($c * $t + $d )));
    }

    return @r;
}


my $EMPTY  = TransPixel();
my $RED    = ColorPixel( Color( 0.8, 0.2, 0.2 ) );
my $BLACK  = ColorPixel( Color( 0.0, 0.0, 0.0 ) );
my $BLUE   = ColorPixel( Color( 0.0, 0.3, 0.6 ) );
my $GOLD   = ColorPixel( Color( 0.8, 0.6, 0.4 ) );
my $BROWN  = ColorPixel( Color( 0.5, 0.3, 0.3 ) );
my $WHITE  = ColorPixel( Color( 1.0, 1.0, 1.0 ) );
my $YELLOW = CharPixel( Color( 1.0, 1.0, 0.0 ), Color( 0.7, 0.6, 0.0 ), '*' );

my $mario_palette = Palette({
    '$' => $RED,
    ' ' => $EMPTY,
    '`' => $BLACK,
    '.' => $BROWN,
    ':' => $BLUE,
    '@' => $GOLD,
    '#' => $WHITE,
    '%' => $YELLOW,
});

# ...

my $small_mario_image_data = ImageData( $mario_palette, [
'   $$$$$    ',
'  $$$$$$$$$ ',
'  ...@@`@   ',
' .@.@@@`@@@ ',
' .@..@@@.@@ ',
' ..@@@@@... ',
'   @@@@@@@  ',
'  ::$::$::  ',
' :::$::$::: ',
':::$$$$$$:::',
'## $%$$%$ ##',
'@@@$$$$$$@@@',
'@@$$$$$$$$@@',
'  $$$  $$$  ',
' ...    ... ',
'....    ....',
]);

my $small_mario_image = $small_mario_image_data->create_image;

my $frame_cutoff = ($shader_rect->top_right->x - $small_mario_image->width-2);

my $shader_origin = $shader_rect->origin;

while ($frames <= $F) {

    $frames++;

    #my $poke_start = time;

    $d->poke_shader(
        PixelShaderHGR(
            $shader_rect,
            sub ($x, $y, $width, $height) {

                my $t = time;

                #my $shader_start = time;

                # START COORDS

                $x = $x /  $width;
                $y = $y / $height;

                # center the coordinates and
                # shift them into the colorspace
                $x = $x * 2.0 - 1.0;
                $y = $y * 2.0 - 1.0;

                # start the madness
                my $d0 = sqrt(($x*$x) + ($y*$y));

                my @color = pallete($d0 * 0.5 + $t * 0.5);

                Color(
                    min( 1.0, $color[0] ),
                    min( 1.0, $color[1] ),
                    min( 1.0, $color[2] ),
                )
            }
        )
    );

    $d->poke_block(
        Point(
            $shader_origin->x + ($frames % $frame_cutoff),
            15,
        ),
        $small_mario_image
    );

    #$poke_total += time - $poke_start;

    #$COLOR = Color( rand, rand, rand );
    #last;
    #sleep( 0.016 );
}


my $elapsed = time - $start;

#$d->poke_rectangle( $d->area->inset_by( Point(4, 2) )->center->rect_with_extent( Point(1, 1) ), Color( 0.9, 0.4, 0.2 ) );
#$d->poke( $d->area->inset_by( Point(4, 2) )->origin, ColorPixel( Color( 1.0, 0.0, 0.0 ) ) );
#$d->poke( $d->area->inset_by( Point(4, 2) )->corner, ColorPixel( Color( 0.0, 1.0, 0.0 ) ) );


$d->end_cursor;
$d->show_cursor;

say "\n\n\nGoodbye";

#say "shader_total: $shader_total";
#say "poke_total: $poke_total";

say "elapesed: $elapsed";
say sprintf "fps: %f", ($F / $elapsed);

1;

__END__
