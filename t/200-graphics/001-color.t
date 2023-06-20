#!perl

use v5.36;
use experimental 'try', 'builtin';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ELO::Types    qw[ :core :types ];
use ELO::Graphics qw[ Color ];


subtest '... testing *Color' => sub {

    my $black = Color(0.0, 0.0, 0.0);
    my $white = Color(1.0, 1.0, 1.0);
    my $grey  = Color(0.5, 0.5, 0.5);

    my $red   = Color(1.0, 0.0, 0.0);
    my $green = Color(0.0, 1.0, 0.0);
    my $blue  = Color(0.0, 0.0, 1.0);

    isa_ok($black, *ELO::Graphics::Colors::Color);
    isa_ok($white, *ELO::Graphics::Colors::Color);

    isa_ok($red,   *ELO::Graphics::Colors::Color);
    isa_ok($green, *ELO::Graphics::Colors::Color);
    isa_ok($blue,  *ELO::Graphics::Colors::Color);

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

done_testing;

1;

__END__


