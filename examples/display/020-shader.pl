#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

$|++;

use Data::Dumper;
use Time::HiRes qw[ sleep time ];

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

#warn Dumper  $d->area->inset_by( Point( 2, 4 ) );

my $start = time;

my $shader_total;
my $poke_total;

my $frames = 0;

my $COLOR = Color( rand, rand, rand );
#my $PIXEL = ColorPixel( $COLOR );

my $shader_rect = $d->area->inset_by( Point(4, 2) );

while ($frames <= $F) {

    $frames++;

    #my $poke_start = time;

    $d->poke_shader(
        $shader_rect,
        sub ($x, $y, $width, $height) {

            #my $shader_start = time;

            #return TransPixel() if ($x % 5) == 0 && ($y % 5) == 0;

            # START COORDS

            $x = $x /  $width;
            $y = $y / $height;

            # center the coordinates and
            # shift them into the colorspace
            $x = $x * 2.0 - 1.0;
            $y = $y * 2.0 - 1.0;

            # start the madness
            my $d0 = sqrt(($x*$x) + ($y*$y));

            # START REPETITION
            $x = $x * 1.5;
            $y = $y * 1.5;

            $x = $x - floor($x);
            $y = $y - floor($y);

            $x -= 0.5;
            $y -= 0.5;

            # END REPETITION

            # length
            my $d  = sqrt(($x*$x) + ($y*$y));
               $d *= exp( -$d0 );

            $d = sin($d * 2 + time)/2;
            $d = abs($d);

            # step it ...
            $d = $d < 0.1 ? ($d / 0.1) : 1;

            $d = 0.4 / $d;
            #$d = (0.04 / $d) ** 1.2;

            #$shader_total += time - $shader_start;

            my $color = $COLOR->factor( $d );

            ColorPixel( $color );
        }
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

say "\n\n\nGoodbye";

#say "shader_total: $shader_total";
#say "poke_total: $poke_total";

say "elapesed: $elapsed";
say sprintf "fps: %f", ($F / $elapsed);

1;

__END__
