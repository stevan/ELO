#!perl

use v5.36;
no warnings 'once';

use Test::More;
use Test::Exception;
use Test::Differences;

use ok 'ELO::Types', qw[ :core :types :typeclasses ];


type *X => *Num;
type *Y => *Num;
type *Z => *Num;

datatype *Point => sub {
    case Point2D => ( *X, *Y );
    case Point3D => ( *X, *Y, *Z );
};

typeclass[*Point] => sub {

    method x => *X;
    method y => *Y;

    method z => {
        Point2D => sub ($,$) { die 'Cannot call `z` on a Point2D type' },
        Point3D => *Z,
    };

    method clear => {
        Point2D => sub ($,$)     { Point2D(0, 0) },
        Point3D => sub ($,$,$)  { Point3D(0, 0, 0) },
    };
};

subtest '... testing Point2D' => sub {

    my $p2d = Point2D(2, 3);
    isa_ok($p2d, *::Point::Point2D);

    is($p2d->x, 2, '... got the expected value for x');
    is($p2d->y, 3, '... got the expected value for y');

    throws_ok { $p2d->z } qr/^Cannot call `z` on a Point2D type/, '... cannot call z on a Point2D';

    my $p2d_clear = $p2d->clear;
    isa_ok($p2d_clear, *::Point::Point2D);

    isnt($p2d, $p2d_clear, '... these are not the same instance');

    is($p2d_clear->x, 0, '... got the expected value for x');
    is($p2d_clear->y, 0, '... got the expected value for y');

};

subtest '... testing Point3D' => sub {
    my $p3d = Point3D(4, 5, 6);
    isa_ok($p3d, *::Point::Point3D);

    is($p3d->x, 4, '... got the expected value for x');
    is($p3d->y, 5, '... got the expected value for y');
    is($p3d->z, 6, '... got the expected value for z');


    my $p3d_clear = $p3d->clear;
    isa_ok($p3d_clear, *::Point::Point3D);

    isnt($p3d, $p3d_clear, '... these are not the same instance');

    is($p3d_clear->x, 0, '... got the expected value for x');
    is($p3d_clear->y, 0, '... got the expected value for y');
    is($p3d_clear->z, 0, '... got the expected value for z');
};

done_testing;
