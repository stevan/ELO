package ELO::Graphics::Pixels;
use v5.36;

use ELO::Types qw[ :core :types :typeclasses ];

use ELO::Graphics::Colors;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    ColorPixel
    CharPixel
    CmdPixel
    TransPixel

    *Pixel
];

## ----------------------------------------------------------------------------
## Pixel
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *FgColor => *Color;
type *BgColor => *Color;

# This might also be a place to implement the StackedPixel to get
# the higher resolution. Hmmm ???

datatype *Pixel => sub {
    case ColorPixel => ( *BgColor );
    case CharPixel  => ( *BgColor, *FgColor, *Char );
    case CmdPixel   => ( *BgColor, *Char );
    case TransPixel => ();
};

typeclass[*Pixel] => sub {

    method bg_color => {
        ColorPixel => *BgColor,
        CharPixel  => *BgColor,
        CmdPixel   => *BgColor,
        TransPixel => sub () { () },
    };
    method fg_color => {
        ColorPixel => sub ($) { () },
        CharPixel  => *FgColor,
        CmdPixel   => sub ($, $) { () },
        TransPixel => sub () { () },
    };

    method colors => {
        ColorPixel => sub ($bg_color)               {     undef, $bg_color },
        CharPixel  => sub ($bg_color, $fg_color, $) { $fg_color, $bg_color },
        CmdPixel   => sub ($bg_color, $)            {     undef, $bg_color },
        TransPixel => sub () { undef, undef },
    };

    method char => {
        ColorPixel => sub ($) { ' ' },
        CharPixel  => *Char,
        CmdPixel   => *Char,
        TransPixel => sub () { "\e[C" }, #  Move cursor over by one
        # XXX: should I have an ANSI code here? What are my alternatives?
        # I am already encoding data here about spacees with ColorPixel
    };

    method lighten => sub ($p, $lighten_by) {
        match[*Pixel, $p] => +{
            TransPixel => sub ()                { TransPixel() },
            ColorPixel => sub ($bg)             { ColorPixel( $bg->sub( $lighten_by ) ) },
            CmdPixel   => sub ($bg, $cmd)       { CmdPixel( $bg->sub( $lighten_by ), $cmd ) },
            CharPixel  => sub ($bg, $fg, $char) {
                CharPixel(
                    $bg->sub( $lighten_by ),
                    $fg->sub( $lighten_by ),
                    $char,
                )
            },
        }
    };

    method darken => sub ($p, $darken_by) {
        match[*Pixel, $p] => +{
            TransPixel => sub ()                { TransPixel() },
            ColorPixel => sub ($bg)             { ColorPixel( $bg->add( $darken_by ) ) },
            CmdPixel   => sub ($bg, $cmd)       { CmdPixel( $bg->add( $darken_by ), $cmd ) },
            CharPixel  => sub ($bg, $fg, $char) {
                CharPixel(
                    $bg->add( $darken_by ),
                    $fg->add( $darken_by ),
                    $char,
                )
            },
        }
    };

    # TODO:
    # - implement equals

};

1;

__END__

