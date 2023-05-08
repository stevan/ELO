#!perl

use v5.36;

use Data::Dumper;

use ELO::Loop;
use ELO::Actors qw[ match build_actor ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Types  qw[ :core :events ];

use Term::ANSIColor qw[ colored ];

use ELO::Util::TermDisplay;

my $term = ELO::Util::TermDisplay->new;

event *eTick => ();

sub ParticleFactory (%args) {

    my $sprite  = $args{sprite} //= '#';

    my $start_x = $args{start_x} //= 0;
    my $start_y = $args{start_y} //= 0;

    return build_actor Particle => sub ($this, $msg) {

        state $up_down    = !!1; # DOWN,  0 = UP
        state $right_left = !!1; # RIGHT, 0 = LEFT

        state $fade = 255;

        state $x = $start_x;
        state $y = $start_y;

        match $msg, state $handlers //= {
            *eTick => sub () {
                # clear the old ...
                $term->go_to( $x, $y )->put_string(' ');

                $fade = 255 unless $fade;

                $x += ($up_down    ? rand : -rand );
                $y += ($right_left ? rand : -rand );

                if ($x >= $term->term_height) {
                    $x = $term->term_height;
                    $up_down = !$up_down;
                }
                elsif ($x <= 0) {
                    $x = 0;
                    $up_down = !$up_down
                }

                if ($y >= $term->term_width) {
                    $y = $term->term_width;
                    $right_left = !$right_left;
                }
                elsif ($y <= 0) {
                    $y = 0;
                    $right_left = !$right_left
                }

                $term->go_to( $x, $y )
                     ->put_string( $sprite )
                     ->go_to( 0, $term->term_width + 2 );
            }
        };
    }
}

sub init ($this, $msg) {

    my @ws = map {
        $this->spawn(
            Wander => ParticleFactory(
                sprite  => colored('.', 'ansi'.($_) ),
                start_x => $term->term_height
            )
        )
    } 0 .. 255;

    $term->clear_screen;

    my $i1 = interval( $this, 0.01, sub {
        $this->send( $_, [ *eTick => () ] ) foreach @ws;
    });
}

ELO::Loop->run( \&init );

1;
