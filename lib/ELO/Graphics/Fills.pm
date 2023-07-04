package ELO::Graphics::Fills;
use v5.36;
use experimental 'for_list';

use ELO::Types qw[ :core :types :typeclasses ];

use ELO::Graphics::Colors;
use ELO::Graphics::Geometry;
use ELO::Graphics::Pixels;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    Horizontal
    Vertical

    GradientFill
    GradientFillHGR

    *FillDirection
    *Fill
];

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
    case GradientFill    => ( *FillArea, *Gradient, *FillDirection );
    case GradientFillHGR => ( *FillArea, *Gradient, *FillDirection );
};

typeclass[*Fill] => sub {

    method area      => *FillArea;
    method direction => *FillDirection;

    method create_pixels => {
        GradientFill => sub ( $area, $gradient, $direction ) {
            my $height = $direction->is_horz ? $area->width : $area->height;

            map ColorPixel( $gradient->calculate_at( $_ ) ), (1 .. $height);
        },
        GradientFillHGR => sub ( $area, $gradient, $direction ) {
            my $height = $direction->is_horz ? $area->width : $area->height;

            if ( $direction->is_vert ) {
                $height *= 2;

                my @pixels;
                foreach my ($s1, $s2) (1 .. $height) {
                    push @pixels => CharPixel(
                        $gradient->calculate_at( $s2 ),
                        $gradient->calculate_at( $s1 ),
                        '▀',
                    );
                }

                return @pixels;
            }
            else {
                return map ColorPixel( $gradient->calculate_at( $_ ) ), (1 .. $height);
            }
        }
    };
};

1;

__END__

