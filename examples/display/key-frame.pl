#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Data::Dumper;

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Actors qw[ receive match ];

use ELO::Util::PixelDisplay;

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

type *StartFrame => *Frame;
type *KeyFrames  => *ArrayRef; # *KeyFrame, ...

datatype *Timeline => sub {
    case Timeline => ( *StartFrame, *KeyFrames );
};

typeclass[*Timeline] => sub {

    method 'tick' => sub ($t, $frame) {
        match[*Timeline, $t], +{
            Timeline => sub ($start, $keyframes) {
                return if $start > $frame;
                my @keyframes = grep { $_->offset == $frame - $start } @$keyframes;
                $_->trigger foreach @keyframes;
            }
        }
    }
};


my $timeline = Timeline( 3, [
    KeyFrame( 0, sub { print '[1]' }),
    KeyFrame( 2, sub { print '[2]' }),
    KeyFrame( 2, sub { print '[2a]' }),
    KeyFrame( 4, sub { print '[3]' }),
    KeyFrame( 4, sub { print '[3a]' }),
    KeyFrame( 4, sub { print '[3b]' }),
    KeyFrame( 6, sub { print '[4]' }),
]);


# ...

sub init ($this, $) {

    my $frame = 0;
    my $i = $this->loop->add_interval( 0.5, sub {
        printf "%3d > " => $frame;
        $timeline->tick( $frame++ );
        print "\n";
    });

}

ELO::Loop->run( \&init );

1;

__END__


