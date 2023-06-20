package ELO::Graphics::Shaders;
use v5.36;
use experimental 'for_list';

use ELO::Types qw[ :core :types :typeclasses ];

use ELO::Graphics::Geometry;
use ELO::Graphics::Pixels;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    PixelShader
    PixelShaderHGR

    *Shader
];

## ----------------------------------------------------------------------------
## Shader
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *ShadedArea => *Rectangle;
type *ShaderFunc => *CodeRef;

datatype *Shader => sub {
    case PixelShader    => ( *ShadedArea, *ShaderFunc );
    case PixelShaderHGR => ( *ShadedArea, *ShaderFunc );
};

typeclass[*Shader] => sub {

    method area => *ShadedArea;

    method create_pixels => {
        PixelShader => sub ( $area, $shader_func ) {

            my $h = $area->height;
            my $w = $area->width;

            my $cols = $w + 1;
            my $rows = $h + 1;

            my @pixels;
            foreach my $y ( 0 .. $h ) {
                foreach my $x ( 0 .. $w ) {
                    push @pixels => ColorPixel(
                        $shader_func->( $x, $y, $cols, $rows )
                    );
                }
            }

            @pixels;
        },
        PixelShaderHGR => sub ( $area, $shader_func ) {

            my $h = $area->height * 2 - 1;
            my $w = $area->width;

            my $cols = $w + 1;
            my $rows = $h + 1;

            my @pixels;
            foreach my ($y1, $y2) ( 0 .. $h ) {
                foreach my $x ( 0 .. $w ) {
                    push @pixels => CharPixel(
                        $shader_func->( $x, $y2, $cols, $rows ),
                        $shader_func->( $x, $y1, $cols, $rows ),
                        '▀',
                    );
                }
            }

            @pixels;
        }
    };
};

1;

__END__

