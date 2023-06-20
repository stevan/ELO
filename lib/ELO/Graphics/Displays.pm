package ELO::Graphics::Displays;
use v5.36;
use experimental 'for_list';

$|++;

use ELO::Types qw[ :core :types :typeclasses ];

use ELO::Graphics::Colors;
use ELO::Graphics::Geometry;
use ELO::Graphics::Pixels;
use ELO::Graphics::Fills;

## ----------------------------------------------------------------------------
## Environment Variables
## ----------------------------------------------------------------------------

use constant DEBUG => $ENV{ELO_GR_DISPLAY_DEBUG} // 0;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    Display

    *Display
];

## ----------------------------------------------------------------------------
## Display
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------
##           (x) ->
##          ___________________________________
##         | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
##     +===|===|===|===|===|===|===|===|===|===|
## (y) | 1 |_x_|___|___|___|___|___|___|___|___| (3,2)(5,2)
##  |  | 2 |___|___|_@_|_._|_@_|___|___|___|___|   + - +
##  V  | 3 |___|___|_._|___|_._|___|___|___|___|   | *-|->(4,3)
##     | 4 |___|___|_@_|_._|_@_|___|___|___|___|   + - +
##     | 5 |___|___|___|___|___|___|___|___|___| (3,4)(5,4)
##     | 6 |___|___|___|___|___|___|___|___|___|
##     | 7 |___|___|___|___|___|___|___|___|___|
##     | 8 |___|___|___|___|___|___|___|___|___|
##     | 9 |___|___|___|___|___|___|___|___|_x_|

# ... Screen

type *DisplayArea => *Rectangle;
type *Output      => *Any; # this will be a filehandle

datatype [ Display => *Display ] => ( *Output, *DisplayArea );

typeclass[*Display] => sub {

    method area   => *DisplayArea;
    method output => *Output;

    method cols => sub ($d) { $d->area->width  + 1 };
    method rows => sub ($d) { $d->area->height + 1 };

    method height => sub ($d) { $d->area->height };
    method width  => sub ($d) { $d->area->width };

    # ... private methods in the class scope

    my $RESET        = "\e[0m";
    my $CLEAR_SCREEN = "\e[2J";
    my $HOME_CURSOR  = "\e[H";

    my $HIDE_CURSOR  = "\e[?25l";
    my $SHOW_CURSOR  = "\e[?25h";

    my $ENABLE_ALT_BUF  = "\e[?1049h";
    my $DISABLE_ALT_BUF = "\e[?1049l";

    my sub format_bg_color ($c=undef) {
        return '' unless defined $c;
        sprintf "\e[48;2;%d;%d;%d;m" => map int(255 * $_), $c->rgb
    }

    my sub format_fg_color ($c=undef) {
        return '' unless defined $c;
        sprintf "\e[38;2;%d;%d;%d;m" => map int(255 * $_), $c->rgb
    }

    my sub format_colors ($fg_color=undef, $bg_color=undef) {
        return ''                           if !defined $fg_color && !defined $bg_color;
        return format_fg_color( $fg_color ) if  defined $fg_color && !defined $bg_color;
        return format_bg_color( $bg_color ) if !defined $fg_color &&  defined $bg_color;
        sprintf "\e[38;2;%d;%d;%d;48;2;%d;%d;%d;m"
            => map int(255 * $_),
                $fg_color->rgb,
                $bg_color->rgb,
    }

    my sub format_pixel ($p) { format_colors( $p->colors ).($p->char) }

    my sub format_goto ($p) { sprintf "\e[%d;%dH" => map $_+1, $p->yx }

    my sub out ($d, @str) { $d->output->print( @str ); $d }

    # ...
    # these should all return $self

    method clear_screen => sub ($d, $bg_color) {
        $d->home_cursor;
        out( $d => (
            $CLEAR_SCREEN,   # clear the screen first
            # set background color
            format_bg_color($bg_color),
            # paint background
            # draw of $width spaces and goto next line
            ((sprintf "\e[%d\@\e[E" => ($d->cols)) x ($d->rows)), # and repeat it $height times
            # end paint background
            $RESET,
            (DEBUG
                ? ("D(origin: x:".(join ' @ y:' => $d->area->origin->xy).", "
                  ."corner: x:".(join ' @ y:' => $d->area->corner->xy).", "
                  ."{ w: ".$d->width.", h: ".$d->height." })")
                : ()),
        ));

        if (DEBUG) {
            my $two_marker = Color(0.3,0.5,0.8);
            my $ten_marker = Color(0.1,0.3,0.5);

            $d->home_cursor;
            # draw markers
            $d->poke( Point( 0, $_*2 ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 0 .. ($d->height/2);
            $d->poke( Point( $d->width, $_*2 ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 0 .. ($d->height/2);

            $d->poke( Point( $_*2, 0 ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 0 .. ($d->width/2);
            $d->poke( Point( $_*2, $d->height ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 0 .. ($d->width/2);
        }
    };

    method home_cursor  => sub ($d) { out( $d => $HOME_CURSOR ) };
    method end_cursor   => sub ($d) { out( $d => "\e[".($d->rows)."H"  ) };

    method hide_cursor  => sub ($d) { out( $d => $HIDE_CURSOR ) };
    method show_cursor  => sub ($d) { out( $d => $SHOW_CURSOR ) };

    method enable_alt_buffer  => sub ($d) { out( $d => $ENABLE_ALT_BUF  ) };
    method disable_alt_buffer => sub ($d) { out( $d => $DISABLE_ALT_BUF ) };

    method poke => sub ($d, $coord, $pixel) {
        out( $d => (
            format_goto(  $coord ),
            format_pixel( $pixel ),
            $RESET,
        ));
    };

    method poke_rectangle => sub ($d, $rectangle, $bg_color) {

        my $h = $rectangle->height + 1;
        my $w = $rectangle->width  + 1;

        out( $d => (
            format_goto( $rectangle->origin ),
            format_bg_color($bg_color),
            # paint rectangle
            (((' ' x $w) . "\e[B\e[${w}D") x $h),
            # end paint rectangle
            $RESET,
            (DEBUG
                ? ("R(origin: x:".(join ' @ y:' => $rectangle->origin->xy).", "
                  ."corner: x:".(join ' @ y:' => $rectangle->corner->xy).", "
                  ."{ w: ".$rectangle->width.", h: ".$rectangle->height." })")
                : ()),
        ));
    };

    method poke_fill => sub ($d, $fill) {

        my $area = $fill->area;
        my $h    = $area->height; # FIXME - this likely need + 1
        my $w    = $area->width;

        my @pixels = $fill->create_pixels;

        my $filled = match [*FillDirection, $fill->direction] => {
            Vertical   => sub {
                my @formatted = map { format_pixel( $_ ) } @pixels;
                join '' => map { ($_ x $w)."\e[B\e[${w}D" } @formatted;
            },
            Horizontal => sub {
                my $row = join '' => map { format_pixel( $_ ) } @pixels;
                ("${row}\e[B\e[${w}D" x $h);
            },
        };

        out( $d => (
            format_goto( $area->origin ),
            # paint the fill
            $filled,
            # end fill paint
            $RESET,
            (DEBUG
                ? ("F(origin: x:".(join ' @ y:' => $area->origin->xy).", "
                  ."corner: x:".(join ' @ y:' => $area->corner->xy).", "
                  ."{ w: $w, h: $h })")
                : ()),
        ));
    };

    method poke_block => sub ($d, $coord, $image) {

        #die split // => join '' => (map { map { format_colors( $_->colors ).($_->char) } $_->@* } $image->get_all_rows);

        my $carrige_return = "\e[B\e[".$image->width."D";

        out( $d => (
            format_goto( $coord ),
            # paint image
            (join $carrige_return => map {
                join '' => map {
                    #use Data::Dumper;
                    #die Dumper [ split // => format_colors( $_->colors ) ] if $_ isa ELO::Graphics::Pixel::CharPixel;

                    format_colors( $_->colors ).($_->char)
                } $_->@*
            } $image->get_all_rows),
            $carrige_return,
            # end paint image
            $RESET,
            (DEBUG
                ? ("I(coord: x:".(join ' @ y:' => $coord->xy).", "
                  ."{ h: ".$image->height.", w: ".$image->width." })")
                : ()),
        ));
    };

    method poke_shader => sub ($d, $shader) {

        my $area = $shader->area;
        my $cols = $area->width + 1;

        my $carrige_return = "\e[B\e[${cols}D";

        my $i = 0;
        my $shaded = '';
        foreach my $p ( $shader->create_pixels ) {
            $shaded .= format_pixel( $p );
            $i++;
            if ( $i == $cols ) {
                $shaded .= $carrige_return;
                $i = 0;
            }
        }

        out( $d => (
            format_goto( $area->origin ),
            #format_bg_color($color),
            $shaded,
            $RESET,
            (DEBUG
                ? ("S(origin: x:".(join ' @ y:' => $area->origin->xy).", "
                  ."corner: x:".(join ' @ y:' => $area->corner->xy).", "
                  ."{ h: ".$area->height.", w: ".$area->width." })")
                : ()),
        ));
    };

};

1;

__END__

