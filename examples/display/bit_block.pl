#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Data::Dumper;

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive match ];

use ELO::Util::PixelDisplay;

# ...

type *R       => *Int;
type *G       => *Int;
type *B       => *Int;
type *Opacity => *Bool;

datatype *Color => sub {
    case RGB  => ( *R, *G, *B );
    case RGBA => ( *R, *G, *B, *Opacity );
};

typeclass[*Color] => sub {
    method r => {
        RGB  => sub ($r, $, $)    { $r },
        RGBA => sub ($r, $, $, $) { $r },
    };

    method g => {
        RGB  => sub ($, $g, $)    { $g },
        RGBA => sub ($, $g, $, $) { $g },
    };

    method b => {
        RGB  => sub ($, $, $b)    { $b },
        RGBA => sub ($, $, $b, $) { $b },
    };

    method a => {
        RGB  => sub ($, $, $)     { 1 },
        RGBA => sub ($, $, $, $a) { $a },
    };

    method rgb => {
        RGB  => sub ($r, $g, $b)    { $r, $g, $b },
        RGBA => sub ($r, $g, $b, $) { $r, $g, $b },
    };

    method rgba => {
        RGB  => sub ($r, $g, $b)     { $r, $g, $b, 1 },
        RGBA => sub ($r, $g, $b, $a) { $r, $g, $b, $a },
    };
};

# ...

datatype *Palette => sub {
    case Palette => ( *HashRef ); # *Str => *Color
};

typeclass[*Palette] => sub {

    method map => sub ($p, @chars) {
        match[*Palette, $p] => {
            Palette => sub ($m) { map $m->{ $_ }, @chars }
        };
    };
};

# ...

datatype *Image => sub {
    case Image => ( *ArrayRef ); # [ *Color, ... ]
};

typeclass[*Image] => sub {

    method height => { Image => sub ($data) { $data->$#*      } };
    method width  => { Image => sub ($data) { $data->[0]->$#* } };

    method get_all_rows => { Image => sub ($data) { $data->@* } };
};

# ...

type *Rows => *ArrayRef; # [ *Str, ... ]

datatype *ImageData => sub {
    case ImageData => ( *Palette, *Rows );
};

typeclass[*ImageData] => sub {

    method create_image => {
        ImageData => sub ($p, $rows) {
            Image([ map [ $p->map( split //, $_ ) ], @$rows ])
        }
    };
};


# ...

# https://htmlcolors.com/palette/70/super-mario-bros

my $RED    = RGBA( 194, 53, 45, 1 );
my $EMPTY  = RGBA(   0,  0,  0, 0 );
my $BLACK  = RGBA(   0,  0,  0, 1 );
my $BLUE   = RGBA(   8, 70,158, 1 );
my $GOLD   = RGBA( 216,158,109, 1 );
my $BROWN  = RGBA( 130, 76, 65, 1 );
my $WHITE  = RGBA( 244,243,244, 1 );
my $YELLOW = RGBA( 244,243,  8, 1 );

my $PALETTE = Palette({
    '$' => $RED,
    ' ' => $EMPTY,
    '`' => $BLACK,
    '_' => $BROWN,
    '.' => $BLUE,
    '@' => $GOLD,
    '#' => $WHITE,
    '%' => $YELLOW,
});

# ...

my $FPS     = $ARGV[0] // 30;
my $HEIGHT  = $ARGV[1] // 60;
my $WIDTH   = $ARGV[2] // 120;
my $TIMEOUT = $ARGV[3] // 10;

die "Height must be a even number, ... or reall weird stuff happens" if ($HEIGHT % 2) != 0;

my $display = ELO::Util::PixelDisplay->new(
    height   => $HEIGHT,
    width    => $WIDTH,
    bg_color => RGB( 0, 180, 255 )
);

sub init ($this, $) {

    # https://cdn-learn.adafruit.com/assets/assets/000/074/898/original/gaming_newMarioFour02.png?1556139661

    my $image1_data = ImageData( $PALETTE, [
        '   $$$$$    ',
        '  $$$$$$$$$ ',
        '  ...@@.@   ',
        ' .@.@@@.@@@ ',
        ' .@..@@@.@@ ',
        ' ..@@@@@... ',
        '   @@@@@@@  ',
        '  ..$...    ',
        ' ...$..$... ',
        '....$$$$....',
        '@@.$@$$@$.@@',
        '@@@$$$$$$@@@',
        '@@$$$$$$$$@@',
        '  $$$  $$$  ',
        ' ...    ... ',
        '....    ....',
    ]);

    my $image2_data = ImageData( $PALETTE, [
        ' ###                 ',
         '####   $$$$$$$$      ',
         '###$$$$$$$$$$$$$     ',
         '###$$$$$$$$$$$$$     ',
         '...   @@`@@@___      ',
         '...  @@@`@@@@_@_     ',
         '.....@@@`@@@__@_     ',
         '..@@@@__@@@@____     ',
         '  _______@@@@@__     ',
         '   ..@@@@@@@@@       ',
         '     .$$....$$.....  ',
         '     .$$....$$...... ',
         '     .$$....$$...... ',
         '     ......$.... ### ',
         ' ```  .$$$$$.... ####',
         ' ``  %%$$$%%$.$$ ####',
         ' ``$$%%$$$%%$$$$  ## ',
         ' ``$$$$$$$$$$$$``    ',
         ' ``$$$$$$$$$$$````   ',
         '        $$$$$$$```   ',
         '           $$$  ``   ',
         '                ``   ',
    ]);

    my $image1 = $image1_data->create_image;
    my $image2 = $image2_data->create_image;

    $display->turn_on;

    # make a background we stand out against ...
    do {
        my $x = $_;
        $display->poke(
            $x, $_,
            RGB( $_, $x, $_ )
        ) for 0 .. $display->width
    } for 0 .. $display->height;

    $display->bit_block( 3, 3, $image1 );
    $display->bit_block( 3, ($display->width - $image1->width)-3, $image1 );
    $display->bit_block( ($display->height - $image1->height)-3, 3, $image1 );
    $display->bit_block( ($display->height - $image1->height)-3, ($display->width - $image1->width)-3, $image1 );
    $display->bit_block(
        (($display->height/2) - ($image2->height/2)),
        ($display->width  - $image2->width)/2,
        $image2
    );

    timer( $this, $TIMEOUT, sub {
        $display->turn_off();
        $this->exit(0);
    });

    local $SIG{INT} = sub {
        $display->turn_off();
        exit(0);
    };
}

ELO::Loop->run( \&init );

1;

__END__

