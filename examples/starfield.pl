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
use ELO::Actors qw[ setup receive ];

use ELO::Graphics;
use ELO::IO;

## ----------------------------------------------------------------------------
# ...
## ----------------------------------------------------------------------------

my $Empty = TransPixel();

my $Black = Color(0,0,0);
my $White = Color(1,1,1);
my $Grey  = Color(0.7,0.7,0.7);
my $Blue  = Color(0.5,0.5,0.7);
my $Green = Color(0.2,0.9,0.3);

my $palette = Palette({
    ' ' => $Empty,
    '#' => ColorPixel($White),
    '=' => ColorPixel($Grey),
    '<' => ColorPixel($Blue),
    '>' => ColorPixel($Green),
});

# ...

my $horz_ship_image = ImageData( $palette, [
'>><<>>      ',
'  ==        ',
'  ##==>>##>>',
'  ==        ',
'>><<>>      ',
])->create_image;

my $vert_ship_image = ImageData( $palette, [
'    >>    ',
'    ##    ',
'    >>    ',
'>>  ==  >>',
'<<==##==<<',
'>>      >>',
])->create_image;

# ...


## ----------------------------------------------------------------------------

enum *Direction => (
    *Up, *Down, *Left, *Right
);

protocol *StarField => sub {
    event *Init       => ();
    event *OnKeyPress => ( *Direction );
    event *Draw       => ();
};

sub StarField ( $display, $height, $width ) {

    my $star_density = 0.01;

    my sub make_star       () {   rand() < $star_density ? '*' : ' ' }
    my sub make_star_row   () { [ map make_star(),     1 .. $width ] }
    my sub make_star_field () {   map make_star_row(), 1 .. $height  }

    my $gradient = Gradient(
        Color( 0.01, 0.01, 0.02 ),
        Color( 0.33, 0.33, 0.99 ),
        # make the gradient 4x the height
        # of the field, this will spread
        # the gradient over several screen
        # scrolls
        ($height * 4)
    );

    # start in the middle of the gradient ...
    my $step_offset = $gradient->steps / 2;

    my $ship;
    my @stars;
    my $scroll_dir;

    receive[*StarField] => +{
        *Init => sub ($this) {
            @stars      = make_star_field();
            $ship       = $horz_ship_image;
            $scroll_dir = *Left;
        },
        *OnKeyPress => sub ($this, $direction) {
            match[*Direction, $direction] => +{
                *Down => sub {
                    $scroll_dir = *Down;
                    $ship       = $vert_ship_image->flip;
                },
                *Up => sub {
                    $scroll_dir = *Up;
                    $ship       = $vert_ship_image;
                },
                # invert these for the scroll dir
                *Left  => sub {
                    $scroll_dir = *Right;
                    $ship       = $horz_ship_image->mirror;
                },
                *Right => sub {
                    $scroll_dir = *Left;
                    $ship       = $horz_ship_image;
                },
            };
        },
        *Draw => sub ($this) {

            # see if we are doing up/down
            # and apply changes accordingly
            match[*Direction, $scroll_dir] => +{
                *Down    => sub {
                    # remove the first row of stars
                    shift @stars;
                    # and add a new one to the end
                    push @stars => make_star_row();

                    $step_offset++;          # increase the gradient step offset
                    $star_density -= 0.0001; # lower the star density
                },
                *Up  => sub {
                    # remove the last row of stars
                    pop @stars;
                    # and add a new one to the beginning
                    unshift @stars => make_star_row();

                    $step_offset--;          # decrease the gradient step offset
                    $star_density += 0.0001; # increase the star density
                },
                # these are handled below, but
                # need to be ignored here
                *Left  => sub {},
                *Right => sub {},
            };

            # the stars are actually rows
            # of the star field
            foreach my $i ( 0 .. $#stars ) {
                my $line = $stars[$i];

                # display the row
                $display->poke(
                    Point(0, $i),
                    # FIXME:
                    # We use CharPixel here, but we can only
                    # get away with it because *Char is just an
                    # alias to *Str, this needs it's own thing
                    CharPixel(
                        $gradient->calculate_at( $i + $step_offset ),
                        $White,
                        (join '' => @$line)
                    )
                );

                # now handle any left/right scrolling
                match[*Direction, $scroll_dir] => +{
                    # same as above, ignore these here
                    *Up    => sub {},
                    *Down  => sub {},
                    # handle left/right
                    *Left  => sub {
                        # remove char from the start of the line
                        shift @$line;
                        # add one to the back of the line
                        push @$line => make_star();
                    },
                    *Right => sub {
                        # remove char from the end of the line
                        pop @$line;
                        # add one to the back of the line
                        unshift @$line => make_star();
                    },
                };
            }

            # draw the spaceship at the center of field
            $display->poke_block(
                Point( $width / 2, $height / 2 )->sub(
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
$d->enable_alt_buffer;

$SIG{INT} = sub {
    $d->disable_alt_buffer;
    $d->show_cursor;
    $d->end_cursor;
    say "\n\n\nInteruptted!";
    die "Goodbye";
};


## ----------------------------------------------------------------------------

sub init ($this, $msg=[]) {

    my $f = $this->spawn( StarField( $d, 60, 200 ) );

    $this->send( $f, [ *Init ] );

    # animation loop ...
    my $i1 = interval( $this, 0.0366, sub {
        $this->send( $f, [ *Draw ] );
    });

    # input loop ...
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
