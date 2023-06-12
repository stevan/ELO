#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Data::Dumper;

use Hash::Util::FieldHash qw[ id ];
use Term::ANSIColor qw[ colored ];

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive ];

# ...

type *Frame => *Int;

# ...

type *Offset      => *Int;
type *FrameAction => *CodeRef;

datatype *KeyFrame => sub {
    case KeyFrame => ( *Offset, *FrameAction );
};

typeclass[*KeyFrame] => sub {
    method 'offset'  => { KeyFrame => sub ($offset, $) { $offset     } };
    method 'action'  => { KeyFrame => sub ($, $action) { $action     } };
    method 'trigger' => { KeyFrame => sub ($, $action) { $action->() } };
};

# ..

type *Delay      => *Offset;
type *StartFrame => *Frame;
type *KeyFrames  => *ArrayRef; # *KeyFrame, ...

datatype *Animation => sub {
    case Animation     => ( *StartFrame, *KeyFrames );
    case AnimationLoop => ( *StartFrame, *Delay, *KeyFrames );
};

typeclass[*Animation] => sub {

    method 'tick' => sub ($t, $frame) {
        match[*Animation, $t], +{
            Animation => sub ($start, $keyframes) {
                my @keyframes = grep { $_->offset == $frame - $start } @$keyframes;

                $_->trigger for @keyframes;

                return if 0 == scalar grep { ($start + $_->offset) > $frame } @$keyframes;
                return $t;
            },
            AnimationLoop => sub ($start, $delay, $keyframes) {
                my @keyframes = grep { $_->offset == $frame - $start } @$keyframes;

                $_->trigger for @keyframes;

                return AnimationLoop( $frame + $delay + 1, $delay, $keyframes )
                    if 0 == scalar grep { ($start + $_->offset) > $frame } @$keyframes;

                return $t;
            }
        }
    }
};


# ...

my %animation_colors;

my ($animation_1, $animation_2, $animation_3, $animation_4);

$animation_1 = AnimationLoop( 3, 2, [
    KeyFrame( 0, sub { print "\e[55G".colored( '[START]' , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 0, sub { print "\e[55G".colored( '[1]'     , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 2, sub { print "\e[55G".colored( '[2]'     , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 2, sub { print "\e[55G".colored( '[2a]'    , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 4, sub { print "\e[55G".colored( '[3]'     , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 4, sub { print "\e[55G".colored( '[3a]'    , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 4, sub { print "\e[55G".colored( '[3b8]'   , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 6, sub { print "\e[55G".colored( '[4]'     , $animation_colors{ id($animation_1) } ) }),
    KeyFrame( 8, sub { print "\e[55G".colored( '[END]'   , $animation_colors{ id($animation_1) } ) }),
]);

$animation_2 = AnimationLoop( 1, 9, [
    KeyFrame( 0, sub { print  "\e[70G".colored( ' <LOOP>'  , $animation_colors{ id($animation_2) } ) }),
    KeyFrame( 1, sub { print  "\e[70G".colored( '</LOOP>' , $animation_colors{ id($animation_2) } ) }),
]);


$animation_3 = AnimationLoop( 4, 4, [
    KeyFrame( 0, sub { print "\e[85G".colored( '<< {{.0}} >>'  , $animation_colors{ id($animation_3) } ) }),
    KeyFrame( 1, sub { print "\e[85G".colored( '<< {{.1}} >>'  , $animation_colors{ id($animation_3) } ) }),
    KeyFrame( 5, sub { print "\e[85G".colored( '<< {{.2}} >>'  , $animation_colors{ id($animation_3) } ) }),
    KeyFrame( 6, sub { print "\e[85G".colored( '<< {{.3}} >>'  , $animation_colors{ id($animation_3) } ) }),
]);

$animation_4 = AnimationLoop( 1, 9, [
    KeyFrame( 0, sub { print "\e[100G".colored( '.oO( 0.0 )Oo.'  , $animation_colors{ id($animation_4) } ) }),
    KeyFrame( 1, sub { print "\e[100G".colored( '.oO( /.\ )Oo.'  , $animation_colors{ id($animation_4) } ) }),
]);

# ...

sub init ($this, $) {

    my $frame = 0;
    my $i = $this->loop->add_interval( 0.2, sub {

        $animation_colors{ id($animation_1) } //= 'black on_ansi'.( 50 + int(rand(50)));
        $animation_colors{ id($animation_2) } //= 'black on_ansi'.(100 + int(rand(50)));
        $animation_colors{ id($animation_3) } //= 'black on_ansi'.(20  + int(rand(50)));
        $animation_colors{ id($animation_4) } //= 'black on_ansi'.(130 + int(rand(50)));

        printf " %s %s %s %s ".colored('| %03d ', 'blue').colored('▶︎ ', 'cyan').colored( ('______________|' x 4), 'grey5 on_grey2' ) => (
            colored( id($animation_1), $animation_colors{ id($animation_1) } ),
            colored( id($animation_2), $animation_colors{ id($animation_2) } ),
            colored( id($animation_3), $animation_colors{ id($animation_3) } ),
            colored( id($animation_4), $animation_colors{ id($animation_4) } ),
            $frame,
        );
        $animation_1 = $animation_1->tick( $frame );
        $animation_2 = $animation_2->tick( $frame );
        $animation_3 = $animation_3->tick( $frame );
        $animation_4 = $animation_4->tick( $frame );
        $frame++;

        print "\n";
    });

}

ELO::Loop->run( \&init );

1;

__END__


