package ELO::Graphics::Scrollers;
use v5.36;
use experimental 'for_list';

use Math::Trig;

use ELO::Types qw[ :core :types :typeclasses ];

use ELO::Graphics::Geometry;
use ELO::Graphics::Pixels;
use ELO::Graphics::Colors;
use ELO::Graphics::Displays;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    Wave
    SideScroller

    *Wave
    *SideScroller
];


## ----------------------------------------------------------------------------
## Wave
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *Amplitude => *Int;
type *Frequency => *Float;
type *Period    => *Num;

datatype [ Wave => *Wave ] => ( *Amplitude, *Frequency, *Period );

typeclass[*Wave] => sub {
    method amplitude => *Amplitude;
    method frequency => *Frequency;
    method period    => *Period;

    method sin => [ *Num ] => sub ($w, $x) {
        $w->amplitude * sin( 2 * pi * $w->frequency * $x + $w->period )
    };

    method cos => [ *Num ] => sub ($w, $x) {
        $w->amplitude * cos( 2 * pi * $w->frequency * $x + $w->period )
    };

    method tan => [ *Num ] => sub ($w, $x) {
        $w->amplitude * tan( 2 * pi * $w->frequency * $x + $w->period )
    };

    method cot => [ *Num ] => sub ($w, $x) {
        $w->amplitude * cot( 2 * pi * $w->frequency * $x + $w->period )
    };

    method sec => [ *Num ] => sub ($w, $x) {
        $w->amplitude * sec( 2 * pi * $w->frequency * $x + $w->period )
    };

    method cosec => [ *Num ] => sub ($w, $x) {
        $w->amplitude * cosec( 2 * pi * $w->frequency * $x + $w->period )
    };
};

## ----------------------------------------------------------------------------
## SideScroller
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *Area      => *Rectangle;
type *Procedure => *CodeRef;
type *BgColor   => *Color;

datatype [SideScroller => *SideScroller] => ( *Display, *Area, *BgColor, *Procedure );

typeclass[*SideScroller] => sub {
    method display   => *Display;
    method area      => *Area;
    method bg_color  => *BgColor;
    method procedure => *Procedure;

    method scroll => [ *Num ] => sub ($s, $tick) {
        my $d        = $s->display;
        my $area     = $s->area;
        my $bg_color = $s->bg_color;

        foreach my $y ( $area->origin->y .. $area->corner->y  ) {
            # insert new character at the start, and delete from the end ...
            $d->poke( Point( $area->origin->x, $y ), CmdPixel( $bg_color, "\e[@" ) );
            $d->poke( Point( $area->corner->x, $y ), CmdPixel( $bg_color, "\e[P" ) );
        }

        $s->procedure->( $d, $area->origin->x, $tick );
    }

};

1;

__END__

