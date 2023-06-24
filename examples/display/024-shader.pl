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
my $F = $ARGV[2] // 10;

#$ELO::Types::TYPES_DISABLED = 1;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($W, $H) )
);

my $white = Color(1,1,1);
my $black = Color(0,0,0);

$d->clear_screen( $black );
$d->hide_cursor;

my $shader_rect = $d->area;
my $shader_origin = $shader_rect->origin;

my $start = time;
my $frames = 0;

sub time_varying_color ($x, $y, $t, $weight=0.5) {

    my @coords = ($x, $y, $x);
    my @offset = (0, 2, 4);

    my @col;
    foreach my $i ( 0, 1, 2 ) {
        $col[$i] = $weight + $weight * cos($t + $coords[$i] + $offset[$i]);
    }

    return @col;
}

while ($frames <= $F) {

    $frames++;

    $d->poke_shader(
        PixelShaderHGR(
            $shader_rect,
            sub ($x, $y, $width, $height) {
                my $t = time;

                $x = $x /  $width;
                $y = $y / $height;

                $x = $x * 2.0 - 1.0;
                $y = $y * 2.0 - 1.0;

                my $d = sqrt(($x*$x) + ($y*$y));

                return Color(
                    time_varying_color(
                        ($x * $y) / 13,
                        ($y * $x) / 7,
                        ($d * 10.5 + $t * 3.2),
                    )
                );

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
