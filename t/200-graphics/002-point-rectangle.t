#!perl

use v5.36;
use experimental 'try', 'builtin';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ELO::Types    qw[ :core :types ];
use ELO::Graphics qw[ Color ];

use ELO::Graphics qw[ Point Rectangle ];


subtest '... testing *Point and *Rectangle' => sub {

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

    ok( lookup_type(*ELO::Graphics::Point)->check( $home ), '... this passed the type check for Point with home(0,0)');
    ok(!lookup_type(*ELO::Graphics::Point)->check( [0,0] ), '... this passed the !type check for Point with ArrayRef[0,0]');

    my $top_left     = Point( 2, 1 );
    my $top_right    = Point( 4, 1 );
    my $center       = Point( 3, 2 );
    my $bottom_left  = Point( 2, 3 );
    my $bottom_right = Point( 4, 3 );

    isa_ok( $home, *ELO::Graphics::Point );
    isa_ok( $end,  *ELO::Graphics::Point );

    isa_ok( $top_left,     *ELO::Graphics::Point );
    isa_ok( $top_right,    *ELO::Graphics::Point );
    isa_ok( $center,       *ELO::Graphics::Point );
    isa_ok( $bottom_left,  *ELO::Graphics::Point );
    isa_ok( $bottom_right, *ELO::Graphics::Point );

    my $rect = Rectangle( $top_left, $bottom_right );
    isa_ok( $rect, *ELO::Graphics::Rectangle );

    subtest '... testing Rectangle' => sub {

        is($rect->height, 2, '... got the right height');
        is($rect->width, 2, '... got the right width');

        isa_ok( $rect->origin, *ELO::Graphics::Point );
        isa_ok( $rect->corner, *ELO::Graphics::Point );

        isa_ok( $rect->center, *ELO::Graphics::Point );
        isa_ok( $rect->extent, *ELO::Graphics::Point );

        isa_ok( $rect->top_left,     *ELO::Graphics::Point );
        isa_ok( $rect->top_right,    *ELO::Graphics::Point );
        isa_ok( $rect->bottom_left,  *ELO::Graphics::Point );
        isa_ok( $rect->bottom_right, *ELO::Graphics::Point );

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
        isa_ok($r, *ELO::Graphics::Rectangle );

        is($r->height, 2, '... got the right height');
        is($r->width, 2, '... got the right width');

        isa_ok( $r->origin, *ELO::Graphics::Point );
        isa_ok( $r->corner, *ELO::Graphics::Point );
        isa_ok( $r->center, *ELO::Graphics::Point );
        isa_ok( $r->extent, *ELO::Graphics::Point );

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
        isa_ok($r, *ELO::Graphics::Rectangle );

        is($r->height, 2, '... got the right height');
        is($r->width, 2, '... got the right width');

        isa_ok( $r->origin, *ELO::Graphics::Point );
        isa_ok( $r->corner, *ELO::Graphics::Point );
        isa_ok( $r->center, *ELO::Graphics::Point );
        isa_ok( $r->extent, *ELO::Graphics::Point );

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
        isa_ok($r, *ELO::Graphics::Rectangle );

        is($r->height, 2, '... got the right height');
        is($r->width, 2, '... got the right width');

        isa_ok( $r->origin, *ELO::Graphics::Point );
        isa_ok( $r->corner, *ELO::Graphics::Point );
        isa_ok( $r->center, *ELO::Graphics::Point );
        isa_ok( $r->extent, *ELO::Graphics::Point );

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
        isa_ok( $p, *ELO::Graphics::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coord after add');
        is($p->y, 6, '... got the expected y coord after add');
    };

    subtest '... testing sub' => sub {
        my $p = $bottom_right->sub( Point( 2, 1 ) );
        isa_ok( $p, *ELO::Graphics::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 2, '... got the expected x coords after sub');
        is($p->y, 2, '... got the expected y coords after sub');
    };

    subtest '... testing mul' => sub {
        my $p = $bottom_right->mul( Point( 2, 2 ) );
        isa_ok( $p, *ELO::Graphics::Point );

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
        isa_ok( $p, *ELO::Graphics::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coords after mul');
        is($p->y, 6, '... got the expected y coords after mul');
    };

    subtest '... testing scale_by_factor' => sub {
        my $p = $bottom_right->scale_by_factor( 2 );
        isa_ok( $p, *ELO::Graphics::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coords after mul');
        is($p->y, 6, '... got the expected y coords after mul');
    };


    subtest '... testing scale_by_factors' => sub {
        my $p = $bottom_right->scale_by_factors( 2, 2 );
        isa_ok( $p, *ELO::Graphics::Point );

        is($bottom_right->x, 4, '... old x coord is unchanged');
        is($bottom_right->y, 3, '... old y coord is unchanged');

        is($p->x, 8, '... got the expected x coords after mul');
        is($p->y, 6, '... got the expected y coords after mul');
    };
};

done_testing;

1;

__END__


