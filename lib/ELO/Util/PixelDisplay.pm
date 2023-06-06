package ELO::Util::PixelDisplay;
use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Data::Dumper;

use List::Util  qw[ min ];
use Time::HiRes qw[ sleep time ];

$|++;

# cursors
use constant HIDE_CURSOR  => "\e[?25l";
use constant SHOW_CURSOR  => "\e[?25h";
use constant HOME_CURSOR  => "\e[0;0H";

# clearing and reseting terminal attributes
use constant CLEAR_SCREEN => "\e[0;0H\e[2J";
use constant RESET        => "\e[0m";

# formats for codes with args ...

use constant EMPTY        => ' ';
use constant PIXEL        => '▀';

use constant FG_ANSI_FORMAT => "38;2;%d;%d;%d;";
use constant BG_ANSI_FORMAT => "48;2;%d;%d;%d;";

use constant FG_COLOR_FORMAT => "\e[".(FG_ANSI_FORMAT)."m";
use constant BG_COLOR_FORMAT => "\e[".(BG_ANSI_FORMAT)."m";
use constant COLOR_FORMAT    => "\e[".(FG_ANSI_FORMAT.BG_ANSI_FORMAT)."m";

use constant PIXEL_FORMAT => (COLOR_FORMAT    . PIXEL);
use constant EMPTY_FORMAT => (BG_COLOR_FORMAT . EMPTY);

use constant GOTO_FORMAT  => "\e[%d;%dH";

sub new ($class, %args) {

    die 'You must specify a `height` parameter' unless $args{height};
    die 'You must specify a `width` parameter'  unless $args{width};

    die "Height must be a even number, ... or reall weird stuff happens" if ($args{height} % 2) != 0;

    my $rows = $args{height} - 1;
    my $cols = $args{width}  - 1;

    bless {
        height   => $rows,
        width    => $cols,
        bg_color => $args{bg_color},

        start => time,
        frame => 1,
        rows  => [ 0 .. $rows ],
        cols  => [ 0 .. $cols ],
        vram  => [ map { [ map $args{bg_color}, (0 .. $cols) ] } (0 .. $rows) ]
    } => __PACKAGE__;
}

sub height ($self) { $self->{height} }
sub width  ($self) { $self->{width}  }

sub turn_on ($self) {
    # TODO: switch buffers
    print HIDE_CURSOR;
    print CLEAR_SCREEN;
    $self->draw_background if $self->{bg_color};
}

sub turn_off ($) {
    # TODO: restore buffers
    print SHOW_CURSOR;
    print CLEAR_SCREEN;
    print RESET;
}

sub draw_background ($self) {
    my @rows = $self->{rows}->@*;
    my @cols = $self->{cols}->@*;

    my @rgb = $self->{bg_color}->rgb;

    print HOME_CURSOR;
    foreach my ($x1, $x2) ( @rows ) {
        foreach my $y ( @cols ) {
            printf( COLOR_FORMAT.($y % 10), @rgb, @rgb );
        }
        say '';
    }
    print HOME_CURSOR;
}

sub run_shader ($self, $shader) {
    my $height = $self->{height} - 1;
    my $width  = $self->{width}  - 1;

    my @rows = $self->{rows}->@*;
    my @cols = $self->{cols}->@*;

    my $time = time;

    print HOME_CURSOR;
    foreach my ($x1, $x2) ( @rows ) {
        foreach my $y ( @cols ) {
            printf( PIXEL_FORMAT,
                # normalize it to 0 .. 255
                map { $_ < 0 ? 0 : min(255, int(255 * $_)) }
                    $shader->( $x1, $y, $time ),
                    $shader->( $x2, $y, $time ),
            );
        }
        say '';
    }
    print RESET;

    my $dur = time - $self->{start};
    my $fps = 1 / ($dur / $self->{frame});

    printf(GOTO_FORMAT, ($height/2)+2, 0);
    printf('frame: %05d | fps: %3d | elapsed: %f',
        $self->{frame}, $fps, $dur);

    $self->{frame}++;
}

sub poke ($self, $x, $y, $color) {
    my $vram = $self->{vram};

    my ($r, $g, $b, $a) = $color->rgba;

    # coords are 1-based
    my $_x = $x + 1;
    my $_y = $y + 1;

    # and we have vertical sub-pixels
    $_x = ceil($_x / 2);

    printf(GOTO_FORMAT, $_x, $_y);

    if ( $a ) {
        if ( ($x % 2) == 0 ) {
            printf( PIXEL_FORMAT, ($r, $g, $b), $vram->[$x+1]->[$y]->rgb );

        }
        else {
            printf( PIXEL_FORMAT, $vram->[$x-1]->[$y]->rgb, ($r, $g, $b) );
        }
    }

    $vram->[$x]->[$y] = $color;
}

sub bit_block ($self, $x, $y, $block) {
    my $vram = $self->{vram};

    my @rows = map { $_ } $block->get_all_rows;

    if (($x % 2) != 0) {
        $x--;
        unshift @rows => [ $vram->[ $x ]->@[ $y .. ($block->width + $y)] ];
    }

    if (($#rows % 2) == 0) {
        push @rows => [ $vram->[ scalar(@rows) + $x ]->@[ $y .. ($block->width + $y)] ];
    }

    # coords are 1-based
    my $_x = $x + 1;
    my $_y = $y + 1;

    # and we have vertical sub-pixels
    $_x = ceil($_x / 2);

    printf(GOTO_FORMAT, $_x, $_y);
    foreach my ($i1, $i2) ( 0 .. $#rows ) {

        my $row1 = $rows[ $i1 ];
        my $row2 = $rows[ $i2 ];

        my $vram1 = $vram->[ $x + $i1 ];
        my $vram2 = $vram->[ $x + $i2 ];

        foreach my $j ( 0 .. $block->width ) {

            my $color1 = $row1->[$j];
            my $color2 = $row2->[$j];

            # both pixels on
            if ( $color1->a && $color2->a ) {
                printf( PIXEL_FORMAT, $color1->rgb, $color2->rgb );

                $vram1->[ $y + $j ] = $color1;
                $vram2->[ $y + $j ] = $color2;
            }
            # top pixel visible, bottom transparent
            elsif ( $color1->a && !$color2->a ) {
                printf( PIXEL_FORMAT, $color1->rgb, $vram2->[ $y + $j ]->rgb );
                $vram1->[ $y + $j ] = $color1;
            }
            # bottom pixel visible, top transparent
            elsif ( !$color1->a && $color2->a ) {
                printf( PIXEL_FORMAT, $vram1->[ $y + $j ]->rgb, $color2->rgb );
                $vram2->[ $y + $j ] = $color2;
            }
            # both pixels off
            else {
                printf( PIXEL_FORMAT,
                    $vram1->[ $y + $j ]->rgb,
                    $vram2->[ $y + $j ]->rgb,
                );
            }

        }

        $_x++;
        printf(GOTO_FORMAT, $_x, $_y);
    }
}

1;

__END__
