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
use constant CLEAR_SCREEN => "\e[0;0H;\e[2J";
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
    state $singleton;

    die "Height must be a even number, ... or reall weird stuff happens" if ($args{height} % 2) != 0;

    $singleton //= bless {
        height   => ($args{height}  // die 'You must specify a `height` parameter'),
        width    => ($args{width}   // die 'You must specify a `width` parameter'),
        bg_color => $args{bg_color} // undef,

        start => time,
        frame => 1,
        rows  => [ 0 .. ($args{height} - 1) ],
        cols  => [ 0 .. ($args{width}  - 1) ],
    } => __PACKAGE__;
}

sub reset ($self) {
    $self->{start} = time;
    $self->{frame} = 1;
}

sub turn_on ($) {
    # TODO: switch buffers
    print HIDE_CURSOR;
    print CLEAR_SCREEN;
}

sub turn_off ($) {
    # TODO: restore buffers
    print SHOW_CURSOR;
    print CLEAR_SCREEN;
    print RESET;
}

sub run_shader ($self, $shader) {
    state $height = $self->{height} - 1;
    state $width  = $self->{width}  - 1;

    state @rows = $self->{rows}->@*;
    state @cols = $self->{cols}->@*;

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

sub background_color ($self, $color) {
    state @rows = $self->{rows}->@*;
    state @cols = $self->{cols}->@*;

    $self->{bg_color} = $color;

    print HOME_CURSOR;
    foreach my ($x1, $x2) ( @rows ) {
        foreach my $y ( @cols ) {
            #printf( COLOR_FORMAT.($x1 % 10), (0,0,255), $color->rgb );
            printf( COLOR_FORMAT.($y % 10), $color->rgb, $color->rgb );
        }
        say '';
    }
    print HOME_CURSOR;
}

sub poke ($self, $x, $y, $color) {

    my @bg_color        = $self->{bg_color} ? $self->{bg_color}->rgb : (0, 0, 0);
    my ($r, $g, $b, $a) = $color->rgba;

    my $_x = ceil($x / 2);
    printf(GOTO_FORMAT, $_x, $y);

    # both pixels on
    if ( $a ) {
        if ( ($x % 2) != 0 ) {
            printf( PIXEL_FORMAT, ($r, $g, $b), @bg_color );
        }
        else {
            printf( PIXEL_FORMAT, @bg_color, ($r, $g, $b) );
        }
    }
    else {
        printf( EMPTY_FORMAT, @bg_color );
    }
}

sub bit_block ($self, $x, $y, $block) {

    my @bg_color = $self->{bg_color} ? $self->{bg_color}->rgb : (0, 0, 0);

    my $_x = $x == 0 ? 1 : ceil($x / 2);
    printf(GOTO_FORMAT, $_x, $y);
    foreach my ($row1, $row2) ( $block->get_all_rows ) {

        foreach my $i ( 0 .. $block->width ) {

            my ($r1, $g1, $b1, $a1) = $row1->[$i]->rgba;
            my ($r2, $g2, $b2, $a2) = $row2->[$i]->rgba;

            # both pixels on
            if ( $a1 && $a2 ) {
                printf( PIXEL_FORMAT, ($r1, $g1, $b1), ($r2, $g2, $b2) );
            }
            # top pixel transparent
            elsif ( $a1 && !$a2 ) {
                printf( PIXEL_FORMAT, ($r1, $g1, $b1), @bg_color );
            }
            # bottom pixel transparent
            elsif ( !$a1 && $a2 ) {
                printf( PIXEL_FORMAT, @bg_color, ($r2, $g2, $b2) );
            }
            # both pixels off
            else {
                printf( EMPTY_FORMAT, @bg_color );
            }
        }

        $_x++;
        printf(GOTO_FORMAT, $_x, $y);
    }
}

1;

__END__
