#!perl

use v5.36;
use experimental 'try', 'builtin';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ELO::Types    qw[ :core :types :typeclasses ];
use ELO::Graphics qw[ Palette Color ColorPixel ];


subtest '... testing *Palette' => sub {

    my $black = ColorPixel( Color(0.0, 0.0, 0.0) );
    my $white = ColorPixel( Color(1.0, 1.0, 1.0) );
    my $grey  = ColorPixel( Color(0.5, 0.5, 0.5) );

    my $mono_map = {
        ' ' => $black,
        '#' => $white,
        ':' => $grey,
    };

    my $mono  = Palette($mono_map);

    isa_ok($mono,  'ELO::Graphics::Palette');

    my @colors = $mono->map(split // => ' :#: ');

    is($colors[0], $black, '... got the expected color');
    is($colors[1], $grey,  '... got the expected color');
    is($colors[2], $white, '... got the expected color');
    is($colors[3], $grey,  '... got the expected color');
    is($colors[4], $black, '... got the expected color');

};

done_testing;

1;

__END__


