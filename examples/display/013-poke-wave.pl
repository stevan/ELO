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

my $HEIGHT  = $ARGV[0] // 30;
my $WIDTH   = $ARGV[1] // 90;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

my $PI = 3.14159;

my $Purple = Color(0.6, 0.1, 0.3);

my $Red   = Color(0.9, 0.1, 0.1);
my $Green = Color(0.1, 0.9, 0.1);
my $Blue  = Color(0.1, 0.1, 0.9);

my $Background = Color(0.3,0.3,0.3);

my $offset = 0;

$d->hide_cursor;
#$d->enable_alt_buffer;

$SIG{INT} = sub {
    #$d->disable_alt_buffer;
    $d->show_cursor;
    $d->end_cursor;
    say "\n\n\nInteruptted!";
    die "Goodbye";
};

my $shift_by = Point( 0, $HEIGHT / 2 );

my $a = 10;
my $f = 0.03;
my $b = 0;

sub poke_waves ( $x ) {
    my $sin_y = $a * sin( 2 * $PI * $f * $x + $b );
    my $cos_y = $a * cos( 2 * $PI * $f * $x + $b );

    $d->poke( Point( 0, $sin_y )->add($shift_by), ColorPixel( $Red ));
    $d->poke( Point( 0, $cos_y )->add($shift_by), ColorPixel( $Green ));
}

$d->clear_screen( $Background );
{


    my $x = 0;
    while (1) {
        sleep(0.03);

        foreach ( (($HEIGHT / 2) - $a) .. (($HEIGHT / 2) + $a) ) {
            $d->move_cursor( Point( 0, $_ ) );
            print "\e[48;2;77;77;77;m\e[@";
            $d->move_cursor( Point( $d->width + 1, $_ ) );
            print "\e[P";
        }

        poke_waves( $x -= 0.5 );
    }
}

#$d->disable_alt_buffer;
$d->show_cursor;
$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__






