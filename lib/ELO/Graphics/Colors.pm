package ELO::Graphics::Colors;
use v5.36;

use List::Util qw[ min max ];
use ELO::Types qw[ :core :types :typeclasses ];

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    Color
    Gradient

    *Color
    *Gradient
];

## ----------------------------------------------------------------------------
## Color
## ----------------------------------------------------------------------------
## http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Color.htm
## ----------------------------------------------------------------------------

type *R => *Float, range => [ 0.0, 1.0 ];
type *G => *Float, range => [ 0.0, 1.0 ];
type *B => *Float, range => [ 0.0, 1.0 ];

datatype [ Color => *Color ] => ( *R, *G, *B );

typeclass[*Color] => sub {

    method r => *R;
    method g => *G;
    method b => *B;

    method rgb => sub ($c) { ($c->r, $c->g, $c->b) };

    # constrain all the values we create with out match operations

    my sub __ ($x) { max(0, min(1.0, $x)); } # $x > 1.0 ? 1.0 : $x < 0.0 ? 0.0 : $x }

    method add => sub ($c1, $c2) { Color( __($c1->r + $c2->r), __($c1->g + $c2->g), __($c1->b + $c2->b) ) };
    method sub => sub ($c1, $c2) { Color( __($c1->r - $c2->r), __($c1->g - $c2->g), __($c1->b - $c2->b) ) };
    method mul => sub ($c1, $c2) { Color( __($c1->r * $c2->r), __($c1->g * $c2->g), __($c1->b * $c2->b) ) };

    method alpha => sub ($c, $a) { Color( __($c->r * $a), __($c->g * $a), __($c->b * $a) ) };

    method factor => sub ($c, $factor) { Color( __($c->r * $factor), __($c->g * $factor), __($c->b * $factor) ) };

    # TODO:
    # merge colors
    #   - http://www.java2s.com/example/java-utility-method/color-merge/mergecolors-color-a-float-fa-color-b-float-fb-9e963.html

    method equals => sub ($c1, $c2) {
        return 1 if $c1->r == $c2->r && $c1->g == $c2->g && $c1->b == $c2->b;
        return 0;
    };
};

## ----------------------------------------------------------------------------
## Gradient
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *StartColor => *Color;
type *EndColor   => *Color;
type *Steps      => *Int;

datatype [ Gradient => *Gradient ] => ( *StartColor, *EndColor, *Steps );

typeclass[*Gradient] => sub {

    method start_color => *StartColor;
    method end_color   => *EndColor;
    method steps       => *Steps;

    method calculate_at => sub ($g, $value) {
        my $start = $g->start_color;
        my $end   = $g->end_color;
        my $steps = $g->steps;

        my $ratio = $value / $steps;

        return $end   if $ratio > 1;
        return $start if $ratio < 0;

        Color(
            $start->r + $ratio * ($end->r - $start->r),
            $start->g + $ratio * ($end->g - $start->g),
            $start->b + $ratio * ($end->b - $start->b),
        )
    };
};


1;

__END__

