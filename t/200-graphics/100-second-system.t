#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

$|++;

use Data::Dumper;

use Time::HiRes 'sleep', 'time';
use Carp        'confess';

use ELO::Types qw[ :core :types :typeclasses ];

type *R => *Int => (range => [0,255]);
type *G => *Int => (range => [0,255]);
type *B => *Int => (range => [0,255]);

datatype [Color => *Color] => ( *R, *G, *B );

typeclass[*Color] => sub {
    method r => *R;
    method g => *G;
    method b => *B;

    method rgb => sub ($c) { $c->r, $c->g, $c->b };
};

type *Rows    => *Int;
type *Columns => *Int;
type *BgColor => *Color;
type *Device  => *ArrayRef;
type *Buffer  => *ArrayRef;

datatype [VRAM => *VRAM] => ( *Rows, *Columns, *BgColor, *Device, *Buffer );

typeclass[*VRAM] => sub {
    method rows     => *Rows;
    method cols     => *Columns;
    method bg_color => *BgColor;
    method device   => *Device;
    method buffer   => *Buffer;

    method alloc => sub ($vram) {
        my $rows = $vram->rows;
        my $cols = $vram->cols;
        $vram->device->@* = map { [ map undef, 0 .. $cols ] } 0 .. $rows;
        $vram;
    };

    method poke => sub ($vram, $x, $y, $color) {
        #warn "poke( $x, $y, '$color' )\n";

        confess "Bad Coords($x, $y)"
            if $y > $vram->rows
            || $x > $vram->cols
            || $y < 0
            || $x < 0;

        #warn "adjusted2( $x, $y )\n"

        push $vram->buffer->@* => [ $x, $y ];

        $vram->device->[ $y ]->[ $x ] = $color;
        $vram;
    };

    my sub format_goto ($x, $y) {
        sprintf "\e[%d;%dH" => map $_+1, $y, $x;
    }

    my sub format_pixel ($fg, $bg) {
        sprintf "\e[38;2;%d;%d;%d;48;2;%d;%d;%d;m▀\e[0m" => $fg->rgb, $bg->rgb;
    }

    method draw => sub ($vram) {

        my $cols     = $vram->cols;
        my $device   = $vram->device;
        my $buffer   = $vram->buffer;
        my $bg_color = $vram->bg_color;

        my @out;
        foreach my ($row1, $row2) ( @$device ) {

            foreach my $i ( 0 .. $cols ) {

                my $p1 = $row1->[ $i ] // $bg_color;
                my $p2 = $row2
                    ? $row2->[ $i ] // $bg_color
                    : $bg_color;

                push @out => format_pixel($p1, $p2);
            }
            push @out => "\n";
        }

        print format_goto(0,0), join '' => @out;

        @$buffer = ();
    };

    method update => sub ($vram) {

        my $device   = $vram->device;
        my $buffer   = $vram->buffer;
        my $bg_color = $vram->bg_color;

        my @out;
        foreach my $cords ( @$buffer ) {

            my ($p1, $p2);
            my ($x, $y) = @$cords;

            if ( ($y % 2) == 0 ) {
                $p1 = $device->[$y]->[$x] // $bg_color;
                $p2 = $device->[$y + 1]->[$x] // $bg_color;
                #warn "orig: $x, $y, [".(join ', ' => $p1->rgb)."]\n";
                #warn "+neighbor: $x, ".($y+1).", [".(join ', ' => $p2->rgb)."]\n";
            }
            else {
                $p2 = $device->[$y]->[$x] // $bg_color;
                $p1 = $device->[$y - 1]->[$x] // $bg_color;
                #warn "orig: $x, $y, [".(join ', ' => $p1->rgb)."]\n";
                #warn "-neighbor: $x, ".($y-1).", [".(join ', ' => $p2->rgb)."]\n";
            }

            push @out => format_goto( $x, floor($y / 2) ),
                         format_pixel( $p1, $p2 );

        }

        my $out = join '' => @out, format_goto( 0, $vram->rows );
        print $out;
        warn "Output length: ".(scalar split // => $out)."\n";

        @$buffer = ();
    };

};

{

    my $vram = VRAM( 60, 60, Color(127,127,127), [], [] )->alloc();

    my $Yellow = Color(255,255,0);
    my $Red    = Color(255,0,0);
    my $Blue   = Color(0,0,255);
    my $Green  = Color(0,255,0);

=pod
    my $cols = $vram->cols;
    my $rows = $vram->rows;

    my $divs = int($cols / $rows);

    foreach my $y (0 .. $rows) {
        foreach my $x ( 0 .. $divs ) {
            $vram->poke( $x * $rows, $y, $Blue );
        }
    }

    foreach my $y ( 0 .. $rows ) {
        foreach my $x ( 0 .. ($divs-1) ) {
            $vram->poke( ($x * $rows) + $y, $y, $Yellow );
            $vram->poke( ($x * $rows) + $y, ($rows - $y), $Red );
        }
    }

    foreach (0 .. $cols) {
        # row at top and bottom
        $vram->poke( $_,  0,     $Green );
        $vram->poke( $_,  $rows, $Green );
    }
=cut

    $vram->draw();

    foreach my $start ( 0 .. $vram->rows - 2 ) {
        my $end   = $start + 2;
        foreach my $x ( $start .. $end ) {
            foreach my $y ( $start .. $end ) {
                $vram->poke( $x, $y, $Red );
            }
        }
        $vram->update();
        sleep(0.05);
        foreach my $x ( $start .. $end ) {
            foreach my $y ( $start .. $end ) {
                $vram->poke( $x, $y, undef );
            }
        }
    }

}


1;

__END__


type *X => *Int;
type *Y => *Int;

datatype [Coord => *Coord] => ( *X, *Y );

typeclass[*Coord] => sub {
    method x => *X;
    method y => *Y;

    method xy => sub ($c) { $c->x, $c->y };
    method yx => sub ($c) { $c->y, $c->x };
};


type *FgColor => *Color;
type *BgColor => *Color;

datatype *Pixel => sub {
    case CharPixel          => ( *Char );
    case ColorCharPixel     => ( *Char, *FgColor );
    case FullColorCharPixel => ( *Char, *FgColor, *BgColor );
    case TransPixel         => ();
};

typeclass[*Pixel] => sub {
    method char => {
        CharPixel          => *Char,
        ColorCharPixel     => *Char,
        FullColorCharPixel => *Char,
        TransPixel         => sub () { () },
    };

    method fg_color => {
        CharPixel          => sub ($) { () },
        ColorCharPixel     => *FgColor,
        FullColorCharPixel => *FgColor,
        TransPixel         => sub () { () },
    };

    method bg_color => {
        CharPixel          => sub ($)    { () },
        ColorCharPixel     => sub ($, $) { () },
        FullColorCharPixel => *BgColor,
        TransPixel         => sub () { () },
    };

    method render => {
        CharPixel          => sub ($char) { $char },
        ColorCharPixel     => sub ($char, $fg_color) { sprintf "\e[38;2;%d;%d;%d;m%s\e[0m" => $fg_color->rgb, $char },
        FullColorCharPixel => sub ($char, $fg_color, $bg_color) {
            sprintf "\e[38;2;%d;%d;%d;48;2;%d;%d;%d;m%s\e[0m" =>
                $fg_color->rgb,
                $bg_color->rgb,
                $char;
        },
        TransPixel => sub () { '_' },
    };
};

▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀cond-system.t 2> elo.log
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
