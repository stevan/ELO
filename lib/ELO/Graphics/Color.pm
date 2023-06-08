package ELO::Graphics::Color;
use v5.36;

use ELO::Types  qw[ :core :types :typeclasses ];
use ELO::Actors qw[ match ];

use Exporter 'import';

my @TYPES = (
    *Color,
        ( *R, *G, *B, *Opacity ),
    *Palette,
);

my @CONSTRUCTORS = qw(
    RGB
    RGBA
    Palette
);

my @TYPE_GLOBS = map { '*'.((split /\:\:/ => "$_")[-1]) } @TYPES;

sub get_type_name ( $type ) {
    (split /\:\:/ => "$type")[-1]
}

our @EXPORT_OK = (
    @CONSTRUCTORS,
    @TYPE_GLOBS
);

our %EXPORT_TAGS = (
    all          => [ @CONSTRUCTORS, @TYPE_GLOBS ],
    constructors => [ @CONSTRUCTORS              ],
    types        => [                @TYPE_GLOBS ],
);

=pod

TODO:

http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Color.htm

- convert R, G, B to Floats between 0 and 1
    - then it can be converted to a bit-depth

- speaking of bit-depth, that should be a value the palette holds

- add constants for named colors:
    - ex: use constant BLACK => RGBA(0,0,0,1)

=cut


# ...

type *R       => *Int;
type *G       => *Int;
type *B       => *Int;
type *Opacity => *Bool;

datatype *Color => sub {
    case RGB  => ( *R, *G, *B );
    case RGBA => ( *R, *G, *B, *Opacity );
};

typeclass[*Color] => sub {
    method r => {
        RGB  => sub ($r, $, $)    { $r },
        RGBA => sub ($r, $, $, $) { $r },
    };

    method g => {
        RGB  => sub ($, $g, $)    { $g },
        RGBA => sub ($, $g, $, $) { $g },
    };

    method b => {
        RGB  => sub ($, $, $b)    { $b },
        RGBA => sub ($, $, $b, $) { $b },
    };

    method a => {
        RGB  => sub ($, $, $)     { 1 },
        RGBA => sub ($, $, $, $a) { $a },
    };

    method rgb => {
        RGB  => sub ($r, $g, $b)    { $r, $g, $b },
        RGBA => sub ($r, $g, $b, $) { $r, $g, $b },
    };

    method rgba => {
        RGB  => sub ($r, $g, $b)     { $r, $g, $b, 1 },
        RGBA => sub ($r, $g, $b, $a) { $r, $g, $b, $a },
    };
};


# ...

datatype *Palette => sub {
    case Palette => ( *HashRef ); # *Str => *Color
};

typeclass[*Palette] => sub {

    method map => sub ($p, @chars) {
        match[*Palette, $p] => {
            Palette => sub ($m) { map $m->{ $_ }, @chars }
        };
    };
};

1;

__END__

=pod

=cut
