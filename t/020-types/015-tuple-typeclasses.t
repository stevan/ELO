#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use List::Util qw[ max min ];

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive match ];

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

# ... Color
# http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Color.htm

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

=pod

subtest '... testing *Color' => sub {

    my $black = Color(0.0, 0.0, 0.0);
    my $white = Color(1.0, 1.0, 1.0);
    my $grey  = Color(0.5, 0.5, 0.5);

    my $red   = Color(1.0, 0.0, 0.0);
    my $green = Color(0.0, 1.0, 0.0);
    my $blue  = Color(0.0, 0.0, 1.0);

    isa_ok($black, *::Color::Color);
    isa_ok($white, *::Color::Color);

    isa_ok($red,   *::Color::Color);
    isa_ok($green, *::Color::Color);
    isa_ok($blue,  *::Color::Color);

    is($red->r, 1.0, '... got the right r for red');
    is($red->g, 0.0, '... got the right g for red');
    is($red->b, 0.0, '... got the right b for red');
    eq_or_diff( [ $red->rgb ], [ 1.0, 0.0, 0.0 ], '... got the right rgb for red');

    is($green->r, 0.0, '... got the right r for green');
    is($green->g, 1.0, '... got the right g for green');
    is($green->b, 0.0, '... got the right b for green');
    eq_or_diff( [ $green->rgb ], [ 0.0, 1.0, 0.0 ], '... got the right rgb for green');

    is($blue->r, 0.0, '... got the right r for blue');
    is($blue->g, 0.0, '... got the right g for blue');
    is($blue->b, 1.0, '... got the right b for blue');
    eq_or_diff( [ $blue->rgb ], [ 0.0, 0.0, 1.0 ], '... got the right rgb for blue');

    ok($white->sub( $red )->sub( $green )->sub( $blue )->equals( $black ), '... make black');
    ok($red->add( $green )->add( $blue )->equals( $white ), '... make white');
};

=cut


# ... Point
# http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Point.htm

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

# ... Rectangle
# http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Rectangle.htm

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

# ...

=pod

subtest '... testing *Point' => sub {

#           (x) ->
#          ___________________________________
#         | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
#     +===|===|===|===|===|===|===|===|===|===|
# (y) | 0 |_x_|___|___|___|___|___|___|___|___| (2,1)(4,1)
#  |  | 1 |___|___|_@_|_._|_@_|___|___|___|___|   + - +
#  V  | 2 |___|___|_._|___|_._|___|___|___|___|   | *-|->(3,2)
#     | 3 |___|___|_@_|_._|_@_|___|___|___|___|   + - +
#     | 4 |___|___|___|___|___|___|___|___|___| (2,3)(4,3)
#     | 5 |___|___|___|___|___|___|___|___|___|
#     | 6 |___|___|___|___|___|___|___|___|___|
#     | 7 |___|___|___|___|___|___|___|___|___|
#     | 8 |___|___|___|___|___|___|___|___|_x_|

    my $home = Point(0,0);
    my $end  = Point(8,8);

    ok( lookup_type(*Point)->check( $home ), '... this passed the type check for Point with home(0,0)');
    ok(!lookup_type(*Point)->check( [0,0] ), '... this passed the !type check for Point with ArrayRef[0,0]');

    my $top_left     = Point( 2, 1 );
    my $top_right    = Point( 4, 1 );
    my $center       = Point( 3, 2 );
    my $bottom_left  = Point( 2, 3 );
    my $bottom_right = Point( 4, 3 );

    isa_ok( $home, *::Point::Point );
    isa_ok( $end,  *::Point::Point );

    isa_ok( $top_left,     *::Point::Point );
    isa_ok( $top_right,    *::Point::Point );
    isa_ok( $center,       *::Point::Point );
    isa_ok( $bottom_left,  *::Point::Point );
    isa_ok( $bottom_right, *::Point::Point );

    my $rect = Rectangle( $top_left, $bottom_right );
    isa_ok( $rect, *::Rectangle::Rectangle );

    subtest '... testing Rectangle' => sub {

        is($rect->height, 2, '... got the right height');
        is($rect->width, 2, '... got the right width');

        isa_ok( $rect->origin, *::Point::Point );
        isa_ok( $rect->corner, *::Point::Point );

        isa_ok( $rect->center, *::Point::Point );
        isa_ok( $rect->extent, *::Point::Point );

        isa_ok( $rect->top_left,     *::Point::Point );
        isa_ok( $rect->top_right,    *::Point::Point );
        isa_ok( $rect->bottom_left,  *::Point::Point );
        isa_ok( $rect->bottom_right, *::Point::Point );

        is( $rect->origin, $top_left, '... origin is the same point as top-left' );
        is( $rect->corner, $bottom_right, '... corner is the same point as bottom-right' );

        is( $rect->top_left, $top_left, '... origin is the same point as top-left' );

        isnt( $rect->top_right, $top_right, '... top_right is not the same instance as top_right' );
        ok( $rect->top_right->equals($top_right), '... top_right is equal to top_right' );

        isnt( $rect->center, $center, '... center is not the same instance as center' );
        ok( $rect->center->equals($center), '... center is equal to center' );

        isnt( $rect->bottom_left, $bottom_left, '... bottom_left is not the same instance as bottom_left' );
        ok( $rect->bottom_left->equals($bottom_left), '... bottom_left is equal to bottom_left' );

        is( $rect->bottom_right, $bottom_right, '... bottom-right is the same point as bottom-right' );

        ok( $rect->extent->equals( Point(2,2) ), '... extend is equal to Point(2,2)' );
    };

    subtest '... testing rect_with_extent' => sub {
        my $extent = Point(2, 2);

        my $r = $top_left->rect_with_extent( $extent );
        isa_ok($r, *::Rectangle::Rectangle );

        is($r->height, 2, '... got the right height');
        is($r->width, 2, '... got the right width');

        isa_ok( $r->origin, *::Point::Point );
        isa_ok( $r->corner, *::Point::Point );
        isa_ok( $r->center, *::Point::Point );
        isa_ok( $r->extent, *::Point::Point );

        isnt($r, $rect, '... this is a new rectangle instance');

        is( $r->origin, $top_left, '... origin is the same point as top-left' );
        isnt( $r->corner, $bottom_right, '... corner is not the same point as bottom right' );

        ok( $r->corner->equals($bottom_right), '... however, corner is equal to bottom right' );

        isnt( $r->center, $center, '... center is not the same instance as center' );
        ok( $r->center->equals($center), '... center is equal to center' );

        isnt( $r->extent, $extent, '... extent is not the same instance as extent' );
        ok( $r->extent->equals( $extent ), '... extent is equal to Point(2,2)' );
    };

    subtest '... testing rect_to_corner' => sub {
        my $r = $top_left->rect_to_corner( $bottom_right );
        isa_ok($r, *::Rectangle::Rectangle );

        is($r->height, 2, '... got the right height');
        is($r->width, 2, '... got the right width');

        isa_ok( $r->origin, *::Point::Point );
        isa_ok( $r->corner, *::Point::Point );
        isa_ok( $r->center, *::Point::Point );
        isa_ok( $r->extent, *::Point::Point );

        isnt($r, $rect, '... this is a new rectangle instance');

        is( $r->origin, $top_left, '... origin is the same point as top-left' );
        is( $r->corner, $bottom_right, '... corner is the same point as bottom right' );

        isnt( $r->center, $center, '... center is not the same instance as center' );
        ok( $r->center->equals($center), '... center is equal to center' );

        ok( $r->extent->equals( Point(2,2) ), '... extend is equal to Point(2,2)' );
    };

    subtest '... testing rect_from_center' => sub {
        my $extent = Point(2, 2);

        my $r = $center->rect_from_center( $extent );
        isa_ok($r, *::Rectangle::Rectangle );

        is($r->height, 2, '... got the right height');
        is($r->width, 2, '... got the right width');

        isa_ok( $r->origin, *::Point::Point );
        isa_ok( $r->corner, *::Point::Point );
        isa_ok( $r->center, *::Point::Point );
        isa_ok( $r->extent, *::Point::Point );

        isnt($r, $rect, '... this is a new rectangle instance');

        isnt( $r->origin, $top_left, '... origin is the same point as top-left' );
        isnt( $r->corner, $bottom_right, '... corner is the same point as bottom right' );

        ok( $r->origin->equals($top_left), '... origin is equal to top-left' );
        ok( $r->corner->equals($bottom_right), '... corner is equal to bottom right' );

        isnt( $r->center, $center, '... center is not the same instance as center' );
        ok( $r->center->equals($center), '... center is equal to center' );

        isnt( $r->extent, $extent, '... extent is not the same instance as extent' );
        ok( $r->extent->equals( $extent ), '... extent is equal to Point(2,2)' );
    };

    subtest '... testing x,y' => sub {
        is($top_left->x, 2, '... got the expected x coord');
        is($top_left->y, 1, '... got the expected y coord');

        is($top_right->x, 4, '... got the expected x coord');
        is($top_right->y, 1, '... got the expected y coord');

        is($bottom_left->x, 2, '... got the expected x coord');
        is($bottom_left->y, 3, '... got the expected y coord');

        is($bottom_right->x, 4, '... got the expected x coord');
        is($bottom_right->y, 3, '... got the expected y coord');
    };

    subtest '... testing add' => sub {
        my $p = $bottom_right->add( $bottom_right );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coord after add');
        is($p->y, 6, '... got the expected y coord after add');
    };

    subtest '... testing sub' => sub {
        my $p = $bottom_right->sub( Point( 2, 1 ) );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 2, '... got the expected x coords after sub');
        is($p->y, 2, '... got the expected y coords after sub');
    };

    subtest '... testing mul' => sub {
        my $p = $bottom_right->mul( Point( 2, 2 ) );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coords after mul');
        is($p->y, 6, '... got the expected y coords after mul');
    };

    subtest '... testing equals' => sub {
        ok($bottom_right->equals( $bottom_right ), '... bottom-right(x,y) == bottom-right(x,y)');
        ok($home->equals( Point(0,0) ), '... home(x,y) == Point(0,0)');
    };

    subtest '... testing min' => sub {
        is( $top_left->min( $bottom_right ), $top_left, '... top-left(1,2) is less than bottom-right(4,3');
        is( $bottom_right->min( $top_left ), $top_left, '... bottom-right(4,3) is greater than top-left(1,2) ');

        is( $top_left->min( $home ), $home, '... home(0,0) is less than top-left(1,2)');
        is( $home->min( $top_left ), $home, '... top-left(1,2) is greater than home(0,0)');

        is( $top_left->min( $end  ), $top_left, '... top-left(1,2) is less than end(8,8)');
        is( $end->min( $top_left  ), $top_left, '... end(8,8) is greater than top-left(1,2)');

        is( $top_left->min( $top_right ), $top_left, '... top-left(1,2) is less than top_right(1,4)' );
        is( $top_right->min( $top_left ), $top_left, '... top_right(1,4) is greater than top_left(1,2)' );

        is( $top_left->min( Point( 2, 1 ) ), $top_left, '... top-left(1,2) is equal to (1,2), return invocant' );
    };

    subtest '... testing max' => sub {
        is( $top_left->max( $bottom_right ), $bottom_right, '... top-left(1,2) is less than bottom-right(4,3');
        is( $bottom_right->max( $top_left ), $bottom_right, '... bottom-right(4,3) is greater than top-left(1,2) ');

        is( $top_left->max( $home ), $top_left, '... home(0,0) is less than top-left(1,2)');
        is( $home->max( $top_left ), $top_left, '... top-left(1,2) is greater than home(0,0)');

        is( $top_left->max( $end  ), $end, '... top-left(1,2) is less than end(8,8)');
        is( $end->max( $top_left  ), $end, '... end(8,8) is greater than top-left(1,2)');

        is( $top_left->max( $top_right ), $top_right, '... top-left(1,2) is less than top_right(1,4)' );
        is( $top_right->max( $top_left ), $top_right, '... top_right(1,4) is greater than top_left(1,2)' );

        is( $top_left->max( Point( 2, 1 ) ), $top_left, '... top-left(1,2) is equal to (1,2), return invocant' );
    };

    subtest '... testing scale_by_point' => sub {
        my $p = $bottom_right->scale_by_point( Point( 2, 2 ) );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coords after mul');
        is($p->y, 6, '... got the expected y coords after mul');
    };

    subtest '... testing scale_by_factor' => sub {
        my $p = $bottom_right->scale_by_factor( 2 );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coords after mul');
        is($p->y, 6, '... got the expected y coords after mul');
    };


    subtest '... testing scale_by_factors' => sub {
        my $p = $bottom_right->scale_by_factors( 2, 2 );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coords after mul');
        is($p->y, 6, '... got the expected y coords after mul');
    };
};

=cut

# ... Screen

type *Height => *Int;
type *Width  => *Int;
type *Device => *Any;

datatype [ Screen => *Screen ] => ( *Height, *Width, *Device );

typeclass[*Screen] => sub {

    method height => *Height;
    method width  => *Width;
    method device => *Device;

    method rows => sub ($d) { $d->height - 1 };
    method cols => sub ($d) { $d->width  - 1 };

    my sub fmt_pixel ($p, $c, $pixel) {
        sprintf((
            "\e[s".               # save cursor pos
            "\e[%d;%dH".          # goto pixel
            "\e[48;2;%d;%d;%d;m". # paint it
            "%s".                 # draw it
            "\e[0m".              # reset color
            "\e[u"                # restore cursor pos
        ), (
            $p->add( Point(2,2) )->xy,  # account for 1 indexed screen
            (map { 255 * $_ } $c->rgb),
            $pixel
        ))
    }

    method poke => sub ($d, $p, $c) {
        $d->device->print( fmt_pixel( $p, $c, ' ' ) );
    };

    method paint => sub ($d, $r, $c) {
        $d->poke( $r->top_left,     $c );
        $d->poke( $r->top_right,    $c );
        $d->poke( $r->center,       $c );
        $d->poke( $r->bottom_left,  $c );
        $d->poke( $r->bottom_right, $c );
    };
};

my $screen = Screen( 30, 30, *STDOUT );

print "\e[0;0H\e[2J+";
print(($_ % 10) == 0 ? "\e[38;2;255;127;127;mv\e[0m" : ($_ % 10)) for 0 .. 29;
print("\n");
  say(($_ % 10) == 0 ? "\e[38;2;255;127;127;m>\e[0m" : ($_ % 10)) for 0 .. 29;

#$screen->poke( Point(5, 5 + $_), Color(1/$_, 0, 0) ) for 1 .. 10;

$screen->paint(
    Point($_, $_)->rect_with_extent( Point( $_+1, $_+1 ) ),
    Color(1/$_*0.7, 1/$_, 1/($_ * 0.3))
) for reverse 1 .. 10;

sleep(1);

# this could be used to initialize the screen quickly
# but since it can only insert, it is limited in use
# in other situations

print "\e[s"              # save cursor
    . "\e[5;5H"           # goto 5,5
    . "\e[48;2;255;0;0m"  # make background color
    . "\e[10".'@'         # draw 10 characters
    . "\e[0m"             # reset colors
    . "\e[u"              # restore cursor
;

# quick rectangle filling code

print "\e[s"              # save cursor
    . "\e[8;5H"           # goto 8,5
    . "\e[48;2;255;99;0m" # make background color

    . "          \e[1B\e[10D" # print 10 spaces ... move down, and back
    . "          \e[1B\e[10D" # print 10 spaces ... move down, and back
    . "          \e[1B\e[10D" # print 10 spaces ... move down, and back
    . "          "            # print 10 spaces ... no need to do any movement here

    . "\e[0m"             # reset colors
    . "\e[u"              # restore cursor
;

#$screen->paint(
#    Point(10, 10)->rect_with_extent( Point( 10, 10 ) ),
#    Color(0, 0, 1)
#);

done_testing;

1;

__END__


