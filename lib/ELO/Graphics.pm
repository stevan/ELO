package ELO::Graphics;
use v5.36;
use experimental 'builtin';
use builtin 'floor', 'ceil';

$|++;

use ELO::Types qw[ :core :types :typeclasses ];

## ----------------------------------------------------------------------------
## Environment Variables
## ----------------------------------------------------------------------------

use constant DEBUG => $ENV{ELO_GR_DISPLAY_DEBUG} // 0;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    Color
    Gradient

    Point
    Rectangle

    ColorPixel
    CharPixel
    TransPixel

    GradientFill

    Horizontal
    Vertical

    Palette

    ImageData
    Image

    Display
];

## ----------------------------------------------------------------------------
## Color
## ----------------------------------------------------------------------------
## http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Color.htm
## ----------------------------------------------------------------------------

type *R => *Float, range => [ 0.0, 1.0 ];
type *G => *Float, range => [ 0.0, 1.0 ];
type *B => *Float, range => [ 0.0, 1.0 ];

datatype [ Color => *Color ] => ( *R, *G, *B );

typeclass[*Color] => sub {

    method r => *R;
    method g => *G;
    method b => *B;

    method rgb => sub ($c) { ($c->r, $c->g, $c->b) };

    # constrain all the values we create with out match operations
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
## Gradient
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *StartColor => *Color;
type *EndColor   => *Color;

datatype [ Gradient => *Gradient ] => ( *StartColor, *EndColor );

typeclass[*Gradient] => sub {

    method start_color => *StartColor;
    method end_color   => *EndColor;

    method calculate_at => sub ($g, $percent) {
        my $start = $g->start_color;
        my $end   = $g->end_color;

        Color(
            $start->r + $percent * ($end->r - $start->r),
            $start->g + $percent * ($end->g - $start->g),
            $start->b + $percent * ($end->b - $start->b),
        )
    };
};

## ----------------------------------------------------------------------------
## Point
## ----------------------------------------------------------------------------
## http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Point.htm
## ----------------------------------------------------------------------------

# use Num here so that we can support Int and Floats in the same class
# and no need to constrain this either, it can be negative and positve
# if they need to be

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
type *BgColor => *Color;

# This might also be a place to implement the StackedPixel to get
# the higher resolution. Hmmm ???

datatype *Pixel => sub {
    case ColorPixel => ( *BgColor );
    case CharPixel  => ( *BgColor, *FgColor, *Char );
    case TransPixel => ();
};

typeclass[*Pixel] => sub {

    method bg_color => {
        ColorPixel => *BgColor,
        CharPixel  => *BgColor,
        TransPixel => sub () { () },
    };
    method fg_color => {
        ColorPixel => sub ($) { () },
        CharPixel  => *FgColor,
        TransPixel => sub () { () },
    };

    method colors => {
        ColorPixel => sub ($bg_color)               {     undef, $bg_color },
        CharPixel  => sub ($bg_color, $fg_color, $) { $fg_color, $bg_color },
        TransPixel => sub () { undef, undef },
    };

    method char => {
        ColorPixel => sub ($) { ' ' },
        CharPixel  => *Char,
        TransPixel => sub () { "\e[C" }, #  Move cursor over by one
        # XXX: should I have an ANSI code here? What are my alternatives?
        # I am already encoding data here about spacees with ColorPixel
    };

    method lighten => sub ($p, $lighten_by) {
        match[*Pixel, $p] => +{
            TransPixel => sub ()                { TransPixel() },
            ColorPixel => sub ($bg)             { ColorPixel( $bg->sub( $lighten_by ) ) },
            CharPixel  => sub ($bg, $fg, $char) {
                CharPixel(
                    $bg->sub( $lighten_by ),
                    $fg->sub( $lighten_by ),
                    $char,
                )
            },
        }
    };

    method darken => sub ($p, $darken_by) {
        match[*Pixel, $p] => +{
            TransPixel => sub ()                { TransPixel() },
            ColorPixel => sub ($bg)             { ColorPixel( $bg->add( $darken_by ) ) },
            CharPixel  => sub ($bg, $fg, $char) {
                CharPixel(
                    $bg->add( $darken_by ),
                    $fg->add( $darken_by ),
                    $char,
                )
            },
        }
    };

    # TODO:
    # - implement equals

};

## ----------------------------------------------------------------------------
## Image
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *BitRow => *ArrayRef, of => [ *Pixel  ];
type *BitMap => *ArrayRef, of => [ *BitRow ];

datatype [ Image => *Image ] => ( *BitMap );

typeclass[*Image] => sub {

    method bitmap => *BitMap;

    method height => sub ($i) { scalar $i->bitmap->@*      };
    method width  => sub ($i) { scalar $i->bitmap->[0]->@* };

    method get_all_rows => sub ($i)        { $i->bitmap->@* };
    method get_row      => sub ($i, $idx)  { $i->bitmap->[ $idx ]->@* };

    # NOTE:
    # the below methods will copy the
    # full bitmap as these are immutable
    # references

    method mirror => sub ($i) {
        Image([ map { [ reverse @$_ ] } $i->get_all_rows ])
    };

    method flip => sub ($i) {
        Image([ map { [ @$_ ] } reverse $i->get_all_rows ])
    };

    method map => sub ($i, $f) {
        Image([ map { [ map $f->($_), @$_ ] } $i->get_all_rows ])
    };

    method lighten => sub ($i, $lighten_by) {
        my $lightener = Color( $lighten_by, $lighten_by, $lighten_by );
        Image([
            map { [
                map $_->lighten( $lightener ), @$_
            ] } $i->get_all_rows
        ])
    };

    method darken => sub ($i, $darken_by) {
        my $darkener = Color( $darken_by, $darken_by, $darken_by );
        Image([
            map { [
                map $_->darken( $darkener ), @$_
            ] } $i->get_all_rows
        ])
    };
};

## ----------------------------------------------------------------------------
## Palette
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *ColorMap => *HashRef, of => [ *Pixel ];

datatype [ Palette => *Palette ] => ( *ColorMap );

typeclass[*Palette] => sub {

    method color_map => *ColorMap;
    method colors    => sub ($p) { values $p->color_map->%* };

    method map => sub ($p, @chars) {
        my $map = $p->color_map;
        my @out = map { $map->{ $_ } // die 'Could not find color for ('.$_.')' } @chars;
        return @out;
    };
};


## ----------------------------------------------------------------------------
## ImageData
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *RawImageData => *ArrayRef, of => [ *Str ]; # lines of image data stored as *Str

datatype [ ImageData => *ImageData ] => ( *Palette, *RawImageData );

typeclass[ *ImageData ] => sub {

    method palette  => *Palette;
    method raw_data => *RawImageData;

    method get_all_rows => sub ($i)        { $i->raw_data->@* };
    method get_row      => sub ($i, $idx)  { $i->raw_data->[ $idx ]->@* };

    method create_image => sub ($img) {
        my $p = $img->palette;
        Image([ map [ $p->map( split //, $_ ) ], $img->get_all_rows ])
    };
};

## ----------------------------------------------------------------------------
## Fill
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

datatype *FillDirection => sub {
    case Vertical   => ();
    case Horizontal => ();
};

typeclass[*FillDirection] => sub {
    method is_horz => { Horizontal => sub { 1 }, Vertical => sub { 0 } };
    method is_vert => { Horizontal => sub { 0 }, Vertical => sub { 1 } };
};

# ...

type *FillArea => *Rectangle;

datatype *Fill => sub {
    case GradientFill => ( *FillArea, *Gradient, *FillDirection );
};

typeclass[*Fill] => sub {

    method area      => *FillArea;
    method direction => *FillDirection;

    method create_pixels => {
        GradientFill => sub ( $area, $gradient, $direction ) {
            my $steps = $direction->is_horz ? $area->width : $area->height;

            map ColorPixel( $gradient->calculate_at( $_ / $steps) ), (1 .. $steps);
        }
    };
};

## ----------------------------------------------------------------------------
## Display
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

# ... Screen

type *DisplayArea => *Rectangle;
type *Output      => *Any; # this will be a filehandle

datatype [ Display => *Display ] => ( *Output, *DisplayArea );

typeclass[*Display] => sub {

    method area   => *DisplayArea;
    method output => *Output;

    method height => sub ($d) { $d->area->height };
    method width  => sub ($d) { $d->area->width };

    # ... private methods in the class scope

    my $RESET        = "\e[0m";
    my $CLEAR_SCREEN = "\e[2J";
    my $HOME_CURSOR  = "\e[H";

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
            $RESET,
            (DEBUG
                ? ("D(origin: ".(join ' @ ' => $d->area->origin->xy).", "
                  ."corner: ".(join ' @ ' => $d->area->corner->xy).", "
                  ."{ h: ".$d->height.", w: ".$d->width." })")
                : ()),
        ));

        if (DEBUG) {
            my $two_marker = Color(0.3,0.5,0.8);
            my $ten_marker = Color(0.1,0.3,0.5);

            $d->home_cursor;
            # draw markers
            $d->poke( Point( 1, $_*2 ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 1 .. ($d->width/2);
            $d->poke( Point( $d->height, $_*2 ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 1 .. ($d->width/2);

            $d->poke( Point( $_*2, 1 ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 1 .. ($d->height/2);
            $d->poke( Point( $_*2, $d->width ), ColorPixel( (($_*2) % 10) == 0 ? $ten_marker : $two_marker ))
                foreach 1 .. ($d->height/2);
        }
    };

    method home_cursor  => sub ($d) { out( $d => $HOME_CURSOR ) };
    method end_cursor   => sub ($d) { out( $d => "\e[".$d->height."H"  ) };

    method poke => sub ($d, $coord, $pixel) {
        out( $d => (
            format_goto(  $coord ),
            format_pixel( $pixel ),
            $RESET,
        ));
    };

    method poke_rectangle => sub ($d, $rectangle, $color) {

        my $h = $rectangle->height;
        my $w = $rectangle->width;

        out( $d => (
            format_goto( $rectangle->origin ),
            format_bg_color($color),
            # paint rectangle
            (((' ' x $w) . "\e[B\e[${w}D") x $h),
            # end paint rectangle
            $RESET,
            (DEBUG
                ? ("R(origin: ".(join ' @ ' => $rectangle->origin->xy).", "
                  ."corner: ".(join ' @ ' => $rectangle->corner->xy).", "
                  ."{ h: $h, w: $w })")
                : ()),
        ));
    };

    method poke_fill => sub ($d, $fill) {

        my $area = $fill->area;
        my $h    = $area->height;
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
                ? ("F(origin: ".(join ' @ ' => $area->origin->xy).", "
                  ."corner: ".(join ' @ ' => $area->corner->xy).", "
                  ."{ h: $h, w: $w })")
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
                ? ("I(coord: ".(join ' @ ' => $coord->xy).", "
                  ."{ h: ".$image->height.", w: ".$image->width." })")
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
