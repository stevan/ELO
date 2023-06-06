#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';

use ELO::Loop;
use ELO::Types  qw[ :core :events ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive ];

use ELO::Util::PixelDisplay;

#  fps | time in milliseconds
# -----+---------------------
#  120 | 0.00833
#  100 | 0.01000
#   60 | 0.01667
#   50 | 0.02000
#   30 | 0.03333
#   25 | 0.04000
#   10 | 0.10000

my $FPS     = $ARGV[0] // 30;
my $HEIGHT  = $ARGV[1] // 60;
my $WIDTH   = $ARGV[2] // 120;
my $TIMEOUT = $ARGV[3] // 10;

die "Height must be a even number, ... or reall weird stuff happens" if ($HEIGHT % 2) != 0;

my $display = ELO::Util::PixelDisplay->new( height => $HEIGHT, width => $WIDTH );

sub init ($this, $) {

    $display->turn_on();

    # https://htmlcolors.com/palette/70/super-mario-bros

    my $RED    = [194, 53, 45, 0];
    my $EMPTY  = [  0,  0,  0, 1];
    my $BLACK  = [  0,  0,  0, 0];
    my $BLUE   = [  8, 70,158, 0];
    my $GOLD   = [216,158,109, 0];
    my $BROWN  = [130, 76, 65, 0];
    my $WHITE  = [244,243,244, 0];
    my $YELLOW = [244,243,  8, 0];

    my %color_map = (
        '$' => $RED,
        ' ' => $EMPTY,
        '`' => $BLACK,
        '_' => $BROWN,
        '.' => $BLUE,
        '@' => $GOLD,
        '#' => $WHITE,
        '%' => $YELLOW,
    );

    $display->background_color( [ 0, 180, 255 ]);

    # https://cdn-learn.adafruit.com/assets/assets/000/074/898/original/gaming_newMarioFour02.png?1556139661

    $display->bit_block( $HEIGHT-15, 1, [
        map { [ map { $color_map{$_} } split //, $_ ] }
        ('   $$$$$    ',
         '  $$$$$$$$$ ',
         '  ...@@.@   ',
         ' .@.@@@.@@@ ',
         ' .@..@@@.@@@',
         ' ..@@@@@....',
         '   @@@@@@@  ',
         '  ..$...    ',
         ' ...$..$....',
         '....$$$$....',
         '@@.$@$$@$.@@',
         '@@@$$$$$$@@@',
         '@@$$$$$$$$@@',
         '  $$$  $$$  ',
         ' ...    ... ',
         '....    ....')
    ]);


    $display->bit_block( 2, 18, [
        map { [ map { $color_map{$_} } split //, $_ ] }
        ('####                 ',
         '####   $$$$$$$$      ',
         '###$$$$$$$$$$$$$     ',
         '###$$$$$$$$$$$$$     ',
         '..... @@`@@@___      ',
         '.....@@@`@@@@_@_     ',
         '.....@@@`@@@__@_     ',
         '..@@@@__@@@@____     ',
         '  _______@@@@@__     ',
         '   ..@@@@@@@@@       ',
         '     .$$....$$.....  ',
         '     .$$....$$...... ',
         '     .$$....$$...... ',
         '     ......$......###',
         ' ```  .$$$$$......###',
         ' ``  %%$$$%%$.$$ ####',
         ' ``$$%%$$$%%$$$$  ## ',
         ' ``$$$$$$$$$$$$``    ',
         ' ``$$$$$$$$$$$````   ',
         '        $$$$$$$```   ',
         '           $$$  ``   ',
         '                ``   ')
    ]);

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


