package ELO::Graphics;
use v5.36;
use experimental 'builtin';
use builtin 'floor', 'ceil';

use ELO::Types qw[ :core :types :typeclasses ];

## ----------------------------------------------------------------------------
## Environment Variables
## ----------------------------------------------------------------------------

use constant DEBUG => $ENV{ELO_GR_DEVICE_DEBUG} // 0;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT_OK = qw[
    Color

    Point
    Rectangle

    ColorPixel
    CharPixel

    Display
];

## ----------------------------------------------------------------------------
## Color
## ----------------------------------------------------------------------------
## http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Color.htm
## ----------------------------------------------------------------------------

type *R => *Float;
type *G => *Float;
type *B => *Float;

datatype [ Color => *Color ] => ( *R, *G, *B );

typeclass[*Color] => sub {

    method r => *R;
    method g => *G;
    method b => *B;

    method rgb => sub ($c) { ($c->r, $c->g, $c->b) };

    my sub __ ($x) { $x > 1.0 ? 1.0 : $x < 0.0 ? 0.0 : $x }

    method add => sub ($c1, $c2) { Color( __($c1->r + $c2->r), __($c1->g + $c2->g), __($c1->b + $c2->b) ) };
    method sub => sub ($c1, $c2) { Color( __($c1->r - $c2->r), __($c1->g - $c2->g), __($c1->b - $c2->b) ) };
    method mul => sub ($c1, $c2) { Color( __($c1->r * $c2->r), __($c1->g * $c2->g), __($c1->b * $c2->b) ) };

    method alpha => sub ($c, $a) { Color( __($c->r * $a), __($c->g * $a), __($c->b * $a) ) };

    # TODO:
    # merge colors
    #   - http://www.java2s.com/example/java-utility-method/color-merge/mergecolors-color-a-float-fa-color-b-float-fb-9e963.html

    method equals => sub ($c1, $c2) {
        return 1 if $c1->r == $c2->r && $c1->g == $c2->g && $c1->b == $c2->b;
        return 0;
    };
};

## ----------------------------------------------------------------------------
## Point
## ----------------------------------------------------------------------------
## http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Point.htm
## ----------------------------------------------------------------------------

type *X => *Num;
type *Y => *Num;

datatype [ Point => *Point ] => ( *X, *Y );

typeclass[*Point] => sub {

    method x => *X;
    method y => *Y;

    method xy => sub ($p) { ($p->x, $p->y) };
    method yx => sub ($p) { ($p->y, $p->x) };

    method add => sub ($p1, $p2) { Point( $p1->x + $p2->x, $p1->y + $p2->y ) };
    method sub => sub ($p1, $p2) { Point( $p1->x - $p2->x, $p1->y - $p2->y ) };
    method mul => sub ($p1, $p2) { Point( $p1->x * $p2->x, $p1->y * $p2->y ) };

    method min => sub ($p1, $p2) {
        # returns the top-left corner defined by rectangle of $p1 x $p2
        return $p1 if $p1->x <= $p2->x && $p1->y <= $p2->y; # $p1 is above and to the to the left of $p2
        return $p2 if $p2->x <= $p1->x && $p2->y <= $p1->y; # $p2 is below and to the to the right of $p1
    };

    method max => sub ($p1, $p2) {
        # returns the bottom-right corner defined by rectangle of $p1 x $p2
        return $p1 if $p1->x >= $p2->x && $p1->y >= $p2->y; # $p1 is below and to the to the right of $p2
        return $p2 if $p2->x >= $p1->x && $p2->y >= $p1->y; # $p2 is below and to the to the right of $p1
    };

    method equals => sub ($p1, $p2) {
        return 1 if $p1->x == $p2->x && $p1->y == $p2->y;
        return 0;
    };

    method scale_by_point => sub ($p1, $p2) { $p1->mul( $p2 ) };

    method scale_by_factor => sub ($p, $factor) {
        Point( ceil( $p->x * $factor ), ceil( $p->y * $factor ) )
    };

    method scale_by_factors => sub ($p, $x_factor, $y_factor) {
        Point( ceil( $p->x * $x_factor ), ceil( $p->y * $y_factor ) )
    };

    # TODO:
    # translate_by (delta)

    # Rectangle constructors
    method rect_with_extent => sub ($p, $extent) { Rectangle( $p, $p->add( $extent ) ) };
    method rect_to_corner   => sub ($p, $corner) { Rectangle( $p, $corner ) };
    method rect_from_center => sub ($p, $extent) {
        $p->sub( $extent->scale_by_factor( 0.5 ) )->rect_with_extent( $extent );
    };
};

## ----------------------------------------------------------------------------
## Rectangle
## ----------------------------------------------------------------------------
## http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Rectangle.htm
## ----------------------------------------------------------------------------

type *Origin => *Point;
type *Corner => *Point;

datatype [ Rectangle => *Rectangle ] => ( *Origin, *Corner );

typeclass[*Rectangle] => sub {

    method origin => *Origin;
    method corner => *Corner;

    method height => sub ($r) { $r->extent->x };
    method width  => sub ($r) { $r->extent->y };

    method top_left     => sub ($r) { $r->origin };
    method top_right    => sub ($r) { Point( $r->corner->x, $r->origin->y ) };
    method bottom_left  => sub ($r) { Point( $r->origin->x, $r->corner->y ) };
    method bottom_right => sub ($r) { $r->corner };

    method extent => sub ($r) { $r->corner->sub( $r->origin )  };
    method center => sub ($r) {
        $r->origin->add( $r->extent->scale_by_factor( 0.5 ) )
    };

    method inset_by => sub ($r, $inset_by) {
        Rectangle(
            $r->origin->add( $inset_by ),
            $r->corner->sub( $inset_by ),
        )
    };

    # TODO:
    # inset_by  (delta : Rect | Point | Num) -> Rect
    # expand_by (delta : Rect | Point | Num) -> Rect
    #
    # contains_rect  (Rect)  -> Bool
    # contains_point (point) -> Bool
    # intersects     (Rect)  -> Bool
    #
    # intersect    (Rect)  -> Rect
    # encompass    (Point) -> Rect
    # areasOutside (Rect)  -> Array[Rect]
    # translate_by (delta) -> Rect

    method equals => sub ($r1, $r2) {
        return 1 if $r1->origin->equals( $r2->origin )
                 && $r1->corner->equals( $r2->corner );
        return 0;
    };
};

## ----------------------------------------------------------------------------
## Pixel
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *FgColor => *Color;

datatype *Pixel => sub {
    case ColorPixel => ( *Point, *Color );
    case CharPixel  => ( *Point, *Color, *FgColor, *Char );
};

typeclass[*Pixel] => sub {

    method coord => *Point;
    method color => *Color;

    method fg_color => {
        ColorPixel => sub ($, $) {  () },
        CharPixel  => *FgColor,
    };

    method char => {
        ColorPixel => sub ($, $) { ' ' },
        CharPixel  => *Char,
    };

    # TODO:
    # - implement equals

};

## ----------------------------------------------------------------------------
## Display
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

# ... Screen

type *DisplayArea => *Rectangle;
type *Output      => *Any; # this will be a filehandle

datatype [ Device => *Device ] => ( *Output, *DisplayArea );

typeclass[*Device] => sub {

    method area   => *DisplayArea;
    method output => *Output;

    method height => sub ($d) { $d->area->height };
    method width  => sub ($d) { $d->area->width };

    # ... private methods in the class scope

    my $RESET        = "\e[0m";
    my $CLEAR_SCREEN = "\e[2J";
    my $HOME_CURSOR  = "\e[H";

    my sub format_bg_color ($c) {
        return unless defined $c;
        sprintf "\e[48;2;%d;%d;%d;m" => map int(255 * $_), $c->rgb
    };
    my sub format_fg_color ($c) {
        return unless defined $c;
        sprintf "\e[38;2;%d;%d;%d;m" => map int(255 * $_), $c->rgb
    };

    my sub format_goto ($p) { sprintf "\e[%d;%dH" => $p->xy }

    my sub out ($d, @str) { $d->output->print( @str ); $d }

    # ...
    # these should all return $self

    method clear_screen => sub ($d, $c) {
        $d->home_cursor;
        out( $d => (
            $CLEAR_SCREEN,   # clear the screen first
            # set background color
            format_bg_color($c),
            # paint background
            # draw of $width spaces and goto next line
            ((sprintf "\e[%d\@\e[E" => $d->width) x $d->height), # and repeat it $height times
            # end paint background
            "\e[0m",  # reset colors
            (DEBUG
                ? ("B(origin: ".(join ' @ ' => $d->area->origin->xy).", "
                  ."corner: ".(join ' @ ' => $d->area->corner->xy).", "
                  ."{ h: ".$d->height.", w: ".$d->width." })")
                : ()),
        ));

        if (DEBUG) {
            my $two_marker = Color(0.3,0.5,0.8);
            my $ten_marker = Color(0.1,0.3,0.5);

            $d->home_cursor;
            # draw markers
            $d->poke_color( Point( 1, $_*2 ), (($_*2) % 10) == 0 ? $ten_marker : $two_marker )
                foreach 1 .. ($d->width/2);
            $d->poke_color( Point( $d->height, $_*2 ), (($_*2) % 10) == 0 ? $ten_marker : $two_marker )
                foreach 1 .. ($d->width/2);

            $d->poke_color( Point( $_*2, 1 ), (($_*2) % 10) == 0 ? $ten_marker : $two_marker )
                foreach 1 .. ($d->height/2);
            $d->poke_color( Point( $_*2, $d->width ), (($_*2) % 10) == 0 ? $ten_marker : $two_marker )
                foreach 1 .. ($d->height/2);
        }
    };

    method home_cursor  => sub ($d) { out( $d => $HOME_CURSOR ) };
    method end_cursor   => sub ($d) { out( $d => "\e[".$d->height."H"  ) };

    method poke => sub ($d, $pixel) {
        out( $d => (
            format_goto     ( $pixel->coords   ),
            format_fg_color ( $pixel->fg_color ),
            format_bg_color ( $pixel->color    ),
                            ( $pixel->char     ),
            $RESET
        ));
    };

    method draw_rectangle => sub ($d, $rectangle, $color) {

        my $h = $rectangle->height;
        my $w = $rectangle->width;

        out( $d => (
            format_goto( $rectangle->origin ),
            format_bg_color($color),
            # paint rectangle
            (((' ' x $w) . "\e[B\e[${w}D") x $h),
            $RESET,  # reset colors
            # end paint rectangle
            (DEBUG
                ? ("R(origin: ".(join ' @ ' => $rectangle->origin->xy).", "
                  ."corner: ".(join ' @ ' => $rectangle->corner->xy).", "
                  ."{ h: $h, w: $w })")
                : ()),
        ));
    };

};

1;

__END__



=pod

https://iterm2.com/documentation-escape-codes.html
https://vt100.net/docs/vt510-rm/IRM.html ???

https://metacpan.org/pod/Chart::Colors << return an endless stream of new distinct
                                          RGB colours codes (good for coloring any
                                          number of chart lines)

TODO:

Use smalltalk as inspiration

http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/EoC.htm

http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplScreen.htm
    http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Form.htm
        http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplayMedium.htm
            http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplayObject.htm


http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Pen.htm
http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/BitBlt.htm

=cut
