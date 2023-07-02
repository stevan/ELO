#!perl

use v5.36;
use experimental 'for_list', 'builtin';
use builtin 'floor', 'ceil', 'indexed';

use Data::Dumper;

use List::Util  qw[ min max ];
use Time::HiRes qw[ sleep ];

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];

use ELO::Graphics;
use ELO::IO;

# ...

my $HEIGHT  = 40;
my $WIDTH   = 100;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

my $Black = Color(0,0,0);
my $White = Color(1,1,1);
my $Empty = TransPixel();

enum *Direction => (
    *Up, *Down, *Left, *Right
);

type *Sky   => *Display;
type *Stars => *ArrayRef;

datatype [StarField => *StarField] => ( *Sky, *Stars );

typeclass[*StarField] => sub {

    method sky   => *Sky;
    method stars => *Stars;

    method alloc => sub ($f) {
        $f->stars->@* = (
            map {
                [
                    map {
                        rand() < 0.01 ? '*' : ' '
                    } 1 .. $d->cols
                ]
            } 1 .. $d->rows
        );

        $f;
    };

    method draw => sub ($f, $direction) {

        state $gradient = Gradient(
            Color( 0.0, 0.1, 0.3 ),
            Color( 0.2, 0.0, 0.2 ),
        );

        state $horz_dir;

        my $d = $f->sky;

        my $steps = $d->area->height;

        my $vert_offset = 0;

        match[*Direction, $direction] => +{
            *Down    => sub {
                shift $f->stars->@*;
                push $f->stars->@* => [ map { rand() < 0.01 ? '*' : ' ' } 1 .. $d->cols ];
                #$direction = $horz_dir if $horz_dir;
            },
            *Up  => sub {
                pop $f->stars->@*;
                unshift $f->stars->@* => [ map { rand() < 0.01 ? '*' : ' ' } 1 .. $d->cols ];
                #$direction = $horz_dir if $horz_dir;
            },
            *Left  => sub {},
            *Right => sub {},
        };

        foreach my $i ( 0 .. $f->stars->$#* ) {

            my $stars = $f->stars->[$i];
            my $str = join '' => @$stars;

            $d->poke(
                Point(0, $i),
                CharPixel(
                    $gradient->calculate_at( $i / $steps ),
                    $White,
                    $str
                )
            );

            match[*Direction, $direction] => +{
                *Up    => sub { $vert_offset-- },
                *Down  => sub { $vert_offset++ },
                *Left  => sub {
                    shift @$stars;
                    push @$stars => rand() < 0.01 ? '*' : ' ';
                    $horz_dir = $direction;
                },
                *Right => sub {
                    pop @$stars;
                    unshift @$stars => rand() < 0.01 ? '*' : ' ';
                    $horz_dir = $direction;
                },
            };
        }
    };
};

my $palette = Palette({
    ' ' => $Empty,
    '#' => ColorPixel($White),
    '=' => ColorPixel(Color(0.5,0.5,0.5)),
    '<' => ColorPixel(Color(0.1,0.2,0.6)),
    '>' => ColorPixel(Color(0.4,0.7,0.2)),
});

# ...

my $horz_ship_image_data = ImageData( $palette, [
'>=<>    ',
' ===>>#>',
'>=<>    ',
]);

my $vert_ship_image_data = ImageData( $palette, [
' > ',
' # ',
' > ',
'>>>',
'=>=',
'< <',
]);

my $horz_ship_image = $horz_ship_image_data->create_image;
my $vert_ship_image = $vert_ship_image_data->create_image;


$d->clear_screen( $Black );
$d->hide_cursor;

$SIG{INT} = sub {
    $d->show_cursor;
    $d->end_cursor;
    die "\n\n\nEnded";
};


sub init ($this, $msg=[]) {

    my $f = StarField( $d, [] )->alloc;

    my $ship             = $horz_ship_image;
    my $scroll_direction = *Left;

    my $i1 = interval( $this, 0.03, sub {
        $f->draw( $scroll_direction );
        $d->poke_block(
            $d->area->center->sub(
                Point( $ship->width / 2, $ship->height / 2 )
            ),
            $ship
        );
    });

    on_keypress( $this, *STDIN, 0.03, sub ($key) {

        # update the ship direction
        $ship = $horz_ship_image->mirror if $key eq "\e[D";
        $ship = $horz_ship_image         if $key eq "\e[C";
        $ship = $vert_ship_image         if $key eq "\e[A";
        $ship = $vert_ship_image->flip   if $key eq "\e[B";

        # update scroll direction
        $scroll_direction = *Right if $key eq "\e[D"; # inverse
        $scroll_direction = *Left  if $key eq "\e[C";
        $scroll_direction = *Up    if $key eq "\e[A";
        $scroll_direction = *Down  if $key eq "\e[B";
        #warn "Scroll: $scroll_direction \n";
    });

}

ELO::Loop->run( \&init );

say "\n\n\nGoodbye";

1;

__END__
