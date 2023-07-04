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


$d->clear_screen( Color( 0.9, 0.7, 0.3 ) );
$d->hide_cursor;

my $shader_rect = $d->area->inset_by( Point(4, 2) );
my $shader_origin = $shader_rect->origin;

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

my $start = time;
my $frames = 0;

my $gradient = Gradient(
    Color( 0.2, 0.1, 0.3 ),
    Color( 1.0, 0.2, 0.5 ),
    1
);

while ($frames <= $F) {

    $frames++;

    $d->poke_shader(
        PixelShaderHGR(
            $shader_rect,
            sub ($x, $y, $width, $height) {
                my $t = time;

                # START COORDS

                $x = $x /  $width;
                $y = $y / $height;

                # center the coordinates and
                # shift them into the colorspace
                $x = $x * 2.0 - 1.0;
                $y = $y * 2.0 - 1.0;

                my $d = sqrt(($x*$x) + ($y*$y));

                my $at = sin($d * 0.5 + $t * 0.5 + ($y * $d));
                   $at = abs( -$at );

                #warn $at;

                #y @color = pallete($at);
                #olor(
                #   min( 1.0, $color[0] ),
                #   min( 1.0, $color[1] ),
                #   min( 1.0, $color[2] ),
                #;

                return $gradient->calculate_at( $at );
            }
        )
    );
}


my $elapsed = time - $start;

$d->end_cursor;
$d->show_cursor;

say "\n\n\nGoodbye";
say "elapesed: $elapsed";
say sprintf "fps: %f", ($F / $elapsed);

1;

__END__
