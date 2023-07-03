#!perl

use v5.36;
use experimental 'for_list', 'builtin';
use builtin 'floor', 'ceil', 'indexed';

use Data::Dumper;

use List::Util  qw[ min max ];
use Time::HiRes qw[ sleep ];

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers ];
use ELO::Actors qw[ receive ];

use ELO::Graphics;
use ELO::IO;

## ----------------------------------------------------------------------------
# ...
## ----------------------------------------------------------------------------

my $Empty = TransPixel();

my $Black = Color(0,0,0);
my $White = Color(1,1,1);
my $Grey  = Color(0.5,0.5,0.5);
my $Blue  = Color(0.1,0.2,0.6);
my $Green = Color(0.4,0.7,0.2);

my $palette = Palette({
    ' ' => $Empty,
    '#' => ColorPixel($White),
    '=' => ColorPixel($Grey),
    '<' => ColorPixel($Blue),
    '>' => ColorPixel($Green),
});

# ...

my $horz_ship_image = ImageData( $palette, [
'<><><>    ',
'  ==      ',
' =#==>>#>>',
'  ==      ',
'<><><>    ',
])->create_image;

my $vert_ship_image = ImageData( $palette, [
'   >   ',
'   #   ',
'   >   ',
'<> = <>',
'<>=#=<>',
'<>   <>',
])->create_image;

# ...

my $sky_gradient = Gradient(
    Color( 0.01, 0.01, 0.02 ),
    Color( 0.33, 0.33, 0.99 ),
);


## ----------------------------------------------------------------------------

enum *Direction => (
    *Up, *Down, *Left, *Right
);

protocol *StarField => sub {
    event *Init       => ();
    event *OnKeyPress => ( *Direction );
    event *Draw       => ();
};

sub StarField (%args) {

    my sub make_star () { rand() < 0.01 ? '*' : ' ' }

    my $display  = $args{display};
    my $gradient = $args{gradient};

    my $steps       = $display->area->height * 4;
    my $step_offset = $display->area->height;

    my $ship;
    my @stars;

    my $scroll_dir = *Left;

    receive[*StarField] => +{
        *Init => sub ($this) {
            @stars = map {
                [ map make_star(), 1 .. $display->cols ]
            } 1 .. $display->rows;

            $ship = $horz_ship_image;
        },
        *OnKeyPress => sub ($this, $direction) {
            match[*Direction, $direction] => +{
                *Down  => sub {
                    $scroll_dir = *Down;
                    $ship = $vert_ship_image->flip;
                },
                *Up    => sub {
                    $scroll_dir = *Up;
                    $ship = $vert_ship_image;
                },
                # invert these for the scroll dir
                *Left  => sub {
                    $scroll_dir = *Right;
                    $ship = $horz_ship_image->mirror;
                },
                *Right => sub {
                    $scroll_dir = *Left;
                    $ship = $horz_ship_image;
                },
            };
        },
        *Draw => sub ($this) {

            match[*Direction, $scroll_dir] => +{
                *Down    => sub {
                    shift @stars;
                    push @stars => [ map make_star(), 1 .. $display->cols ];
                    $step_offset++;
                },
                *Up  => sub {
                    pop @stars;
                    unshift @stars => [ map make_star(), 1 .. $display->cols ];
                    $step_offset--;
                },
                *Left  => sub {},
                *Right => sub {},
            };

            foreach my $i ( 0 .. $#stars ) {

                my $line = $stars[$i];

                $display->poke(
                    Point(0, $i),
                    CharPixel(
                        $gradient->calculate_at( ($i + $step_offset) / $steps ),
                        $White,
                        (join '' => @$line)
                    )
                );

                match[*Direction, $scroll_dir] => +{
                    *Up    => sub {},
                    *Down  => sub {},
                    *Left  => sub {
                        shift @$line;
                        push @$line => make_star();
                    },
                    *Right => sub {
                        pop @$line;
                        unshift @$line => make_star();
                    },
                };
            }

            $display->poke_block(
                $display->area->center->sub(
                    Point( $ship->width / 2, $ship->height / 2 )
                ),
                $ship
            );
        }
    }
}


## ----------------------------------------------------------------------------

my $HEIGHT  = 60;
my $WIDTH   = 200;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

$d->clear_screen( $Black );
$d->hide_cursor;

$SIG{INT} = sub {
    $d->show_cursor;
    $d->end_cursor;
    die "\n\n\nEnded";
};


## ----------------------------------------------------------------------------

sub init ($this, $msg=[]) {

    my $f = $this->spawn(
        StarField(
            display  => $d,
            gradient => $sky_gradient,
        )
    );

    $this->send( $f, [ *Init ] );

    my $i1 = interval( $this, 0.0366, sub {
        $this->send( $f, [ *Draw ] );
    });

    on_keypress( $this, *STDIN, 0.01, sub ($key) {
        my $direction;
        $direction = *Up    if $key eq "\e[A";
        $direction = *Left  if $key eq "\e[D";
        $direction = *Down  if $key eq "\e[B";
        $direction = *Right if $key eq "\e[C";

        $this->send( $f, [ *OnKeyPress => $direction ] ) if $direction;
    });

}

ELO::Loop->run( \&init );

say "\n\n\nGoodbye";

1;

__END__
