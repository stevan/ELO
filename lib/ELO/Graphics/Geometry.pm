package ELO::Graphics::Geometry;
use v5.36;
use experimental 'builtin';
use builtin 'ceil';

use ELO::Types qw[ :core :types :typeclasses ];

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    Point
    Rectangle

    *Point
    *Rectangle
];

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

    method add => [ *Point ] => sub ($p1, $p2) { Point( $p1->x + $p2->x, $p1->y + $p2->y ) };
    method sub => [ *Point ] => sub ($p1, $p2) { Point( $p1->x - $p2->x, $p1->y - $p2->y ) };
    method mul => [ *Point ] => sub ($p1, $p2) { Point( $p1->x * $p2->x, $p1->y * $p2->y ) };

    method min => [ *Point ] => sub ($p1, $p2) {
        # returns the top-left corner defined by rectangle of $p1 x $p2
        return $p1 if $p1->x <= $p2->x && $p1->y <= $p2->y; # $p1 is above and to the to the left of $p2
        return $p2 if $p2->x <= $p1->x && $p2->y <= $p1->y; # $p2 is below and to the to the right of $p1
    };

    method max => [ *Point ] => sub ($p1, $p2) {
        # returns the bottom-right corner defined by rectangle of $p1 x $p2
        return $p1 if $p1->x >= $p2->x && $p1->y >= $p2->y; # $p1 is below and to the to the right of $p2
        return $p2 if $p2->x >= $p1->x && $p2->y >= $p1->y; # $p2 is below and to the to the right of $p1
    };

    method equals => [ *Point ] => sub ($p1, $p2) {
        return 1 if $p1->x == $p2->x && $p1->y == $p2->y;
        return 0;
    };

    method scale_by_point => [ *Point ] => sub ($p1, $p2) { $p1->mul( $p2 ) };

    method scale_by_factor => [ *Num ] => sub ($p, $factor) {
        Point( ceil( $p->x * $factor ), ceil( $p->y * $factor ) )
    };

    method scale_by_factors => [ *Num, *Num ] => sub ($p, $x_factor, $y_factor) {
        Point( ceil( $p->x * $x_factor ), ceil( $p->y * $y_factor ) )
    };

    # TODO:
    # translate_by (delta)

    # Rectangle constructors
    method rect_with_extent => [ *Point ] => sub ($p, $extent) { Rectangle( $p, $p->add( $extent ) ) };
    method rect_to_corner   => [ *Point ] => sub ($p, $corner) { Rectangle( $p, $corner ) };
    method rect_from_center => [ *Point ] => sub ($p, $extent) {
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

    method height => sub ($r) { $r->extent->y };
    method width  => sub ($r) { $r->extent->x };

    method top_left     => sub ($r) { $r->origin };
    method top_right    => sub ($r) { Point( $r->corner->x, $r->origin->y ) };
    method bottom_left  => sub ($r) { Point( $r->origin->x, $r->corner->y ) };
    method bottom_right => sub ($r) { $r->corner };

    method extent => sub ($r) { $r->corner->sub( $r->origin )  };
    method center => sub ($r) {
        $r->origin->add( $r->extent->scale_by_factor( 0.5 ) )
    };

    method inset_by => [ *Point ] => sub ($r, $inset_by) {
        Rectangle(
            $r->origin->add( $inset_by ),
            $r->corner->sub( $inset_by ),
        );
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

    method equals => [ *Rectangle ] => sub ($r1, $r2) {
        return 1 if $r1->origin->equals( $r2->origin )
                 && $r1->corner->equals( $r2->corner );
        return 0;
    };
};

1;

__END__

