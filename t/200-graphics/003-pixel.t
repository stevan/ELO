#!perl

use v5.36;
use experimental 'try', 'builtin';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ELO::Types    qw[ :core :types :typeclasses ];
use ELO::Graphics qw[ ColorPixel CharPixel Color Point ];


subtest '... testing *Pixel' => sub {

    my $black = Color(0.0, 0.0, 0.0);
    my $white = Color(1.0, 1.0, 1.0);
    my $grey  = Color(0.5, 0.5, 0.5);

    my $red   = Color(1.0, 0.0, 0.0);
    my $green = Color(0.0, 1.0, 0.0);
    my $blue  = Color(0.0, 0.0, 1.0);

    my $pixel = ColorPixel( $white );
    isa_ok($pixel, 'ELO::Graphics::Pixels::Pixel::ColorPixel');

    is($pixel->bg_color, $white, '... got the expected color from ColorPixel');
    ok((not defined $pixel->fg_color),'... got the expected fg-color from ColorPixel');
    is($pixel->char, ' ', '... got the expected char from ColorPixel');

    is_deeply([$pixel->colors], [undef, $white], '... got the right colors');

    my $char_pixel = CharPixel( $red, $green, '*' );
    isa_ok($char_pixel, 'ELO::Graphics::Pixels::Pixel::CharPixel');

    is($char_pixel->bg_color, $red, '... got the expected color from CharPixel');
    is($char_pixel->fg_color, $green, '... got the expected fg-color from CharPixel');
    is($char_pixel->char, '*', '... got the expected char from CharPixel');

    is_deeply([$char_pixel->colors], [$green, $red], '... got the right colors');
};

done_testing;

1;

__END__


