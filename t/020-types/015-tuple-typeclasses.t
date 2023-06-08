#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive match ];

=pod

TODO:

Use smalltalk as inspiration

http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplScreen.htm
    http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Form.htm
        http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplayMedium.htm
            http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplayObject.htm


http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Pen.htm
http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/BitBlt.htm

=cut

# ... Point
# http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Point.htm

type *X => *Int;
type *Y => *Int;

datatype [ Point => *Point ] => ( *X, *Y );

typeclass[*Point] => sub {

    method x => *X;
    method y => *Y;

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

    # Rectangle constructors
    method extent => sub ($p1, $p2) { Rectangle( $p1, $p1->add( $p2 ) ) };
    method corner => sub ($p1, $p2) { Rectangle( $p1, $p2 ) };
};

# ... Rectangle
# http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Rectangle.htm

type *Origin => *Point;
type *Corner => *Point;

datatype [ Rectangle => *Rectangle ] => ( *Origin, *Corner );

typeclass[*Rectangle] => sub {

    method origin => *Origin;
    method corner => *Corner;

    method equals => sub ($r1, $r2) {
        return 1 if $r1->origin->equals( $r2->origin )
                 && $r1->corner->equals( $r2->corner );
        return 0;
    };
};

# ...

subtest '... testing *Point' => sub {

#           (y) ->
#          ___________________________________
#         | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
#     +===|===|===|===|===|===|===|===|===|===|
# (x) | 0 |_x_|___|___|___|___|___|___|___|___| (1,2)(1,4)
#  |  | 1 |___|___|_@_|_._|_@_|___|___|___|___|   + - +
#  V  | 2 |___|___|_._|___|_._|___|___|___|___|   |   |
#     | 3 |___|___|_@_|_._|_@_|___|___|___|___|   + - +
#     | 4 |___|___|___|___|___|___|___|___|___| (3,2)(3,4)
#     | 5 |___|___|___|___|___|___|___|___|___|
#     | 6 |___|___|___|___|___|___|___|___|___|
#     | 7 |___|___|___|___|___|___|___|___|___|
#     | 8 |___|___|___|___|___|___|___|___|_x_|

    my $home = Point(0,0);
    my $end  = Point(8,8);

    ok( lookup_type(*Point)->check( $home ), '... this passed the type check for Point with home(0,0)');
    ok(!lookup_type(*Point)->check( [0,0] ), '... this passed the !type check for Point with ArrayRef[0,0]');

    my $top_left     = Point( 1, 2 );
    my $top_right    = Point( 1, 4 );

    my $bottom_left  = Point( 3, 2 );
    my $bottom_right = Point( 3, 4 );

    isa_ok( $home, *::Point::Point );
    isa_ok( $end,  *::Point::Point );

    isa_ok( $top_left,     *::Point::Point );
    isa_ok( $top_right,    *::Point::Point );
    isa_ok( $bottom_left,  *::Point::Point );
    isa_ok( $bottom_right, *::Point::Point );

    my $rect = Rectangle( $top_left, $bottom_right );
    isa_ok( $rect, *::Rectangle::Rectangle );

    subtest '... testing Rectangle' => sub {

        isa_ok( $rect->origin, *::Point::Point );
        isa_ok( $rect->corner, *::Point::Point );

        is( $rect->origin, $top_left, '... origin is the same point as top-left' );
        is( $rect->corner, $bottom_right, '... corner is the same point as bottom-right' );
    };

    subtest '... testing extent' => sub {
        my $r = $top_left->extent( Point(2, 2) );
        isa_ok($r, *::Rectangle::Rectangle );

        isa_ok( $r->origin, *::Point::Point );
        isa_ok( $r->corner, *::Point::Point );

        isnt($r, $rect, '... this is a new rectangle instance');

        is( $r->origin, $top_left, '... origin is the same point as top-left' );
        isnt( $r->corner, $bottom_right, '... corner is not the same point as bottom right' );

        ok( $r->corner->equals($bottom_right), '... however, corner is equal to bottom right' );
    };

    subtest '... testing corner' => sub {
        my $r = $top_left->corner( $bottom_right );
        isa_ok($r, *::Rectangle::Rectangle );

        isa_ok( $r->origin, *::Point::Point );
        isa_ok( $r->corner, *::Point::Point );

        isnt($r, $rect, '... this is a new rectangle instance');

        is( $r->origin, $top_left, '... origin is the same point as top-left' );
        is( $r->corner, $bottom_right, '... corner is the same point as bottom right' );
    };

    subtest '... testing x,y' => sub {
        is($top_left->x, 1, '... got the expected x coord');
        is($top_left->y, 2, '... got the expected y coord');

        is($top_right->x, 1, '... got the expected x coord');
        is($top_right->y, 4, '... got the expected y coord');

        is($bottom_left->x, 3, '... got the expected x coord');
        is($bottom_left->y, 2, '... got the expected y coord');

        is($bottom_right->x, 3, '... got the expected x coord');
        is($bottom_right->y, 4, '... got the expected y coord');
    };

    subtest '... testing add' => sub {
        my $p = $bottom_right->add( $bottom_right );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 3, '... old x coord is unchanged');
        is($bottom_right->y, 4, '... old y coord is unchanged');

        is($p->x, 6, '... got the expected x coord after add');
        is($p->y, 8, '... got the expected y coord after add');
    };

    subtest '... testing sub' => sub {
        my $p = $bottom_right->sub( Point( 2, 1 ) );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 3, '... old x coord is unchanged');
        is($bottom_right->y, 4, '... old y coord is unchanged');

        is($p->x, 1, '... got the expected x coords after sub');
        is($p->y, 3, '... got the expected y coords after sub');
    };

    subtest '... testing mul' => sub {
        my $p = $bottom_right->mul( Point( 2, 2 ) );
        isa_ok( $p, *::Point::Point );

        is($bottom_right->x, 3, '... old x coord is unchanged');
        is($bottom_right->y, 4, '... old y coord is unchanged');

        is($p->x, 6, '... got the expected x coords after mul');
        is($p->y, 8, '... got the expected y coords after mul');
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

        is( $top_left->min( Point( 1, 2 ) ), $top_left, '... top-left(1,2) is equal to (1,2), return invocant' );
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

        is( $top_left->max( Point( 1, 2 ) ), $top_left, '... top-left(1,2) is equal to (1,2), return invocant' );
    };

};

done_testing;

1;

__END__


