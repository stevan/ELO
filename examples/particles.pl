#!perl

use v5.36;

use Data::Dumper;

use ELO::Loop;
use ELO::Actors qw[ receive ];
use ELO::Timers qw[ :timers :tickers ];
use ELO::Types  qw[ :core :events ];

use Term::ANSIColor qw[ colored uncolor ];

use ELO::Util::TermDisplay;

my $term = ELO::Util::TermDisplay->new;

my $term_height = $term->term_height - 1;
my $term_width  = $term->term_width  - 1;

event *eTick;

sub Particle ($id) {

    state $sprite  = '●';

    my $color = 'ansi'.($id % 255);

    my $up_down    = !!(rand); # 1 = DOWN,  0 = UP
    my $right_left = !!(rand); # 1 = RIGHT, 0 = LEFT

    my $x_weight = rand;
    my $y_weight = rand;

    my $x_seed = rand;
    my $y_seed = rand;

    my $x = rand($term_height);
    my $y = rand($term_width);

    receive +{
        *eTick => sub ($this) {

            my ($old_x, $old_y) = ($x, $y);

            my $_x = ($up_down    ? $x_seed : -$x_seed );
            my $_y = ($right_left ? $y_seed : -$x_seed );

            $x += $_x * $x_weight;
            $y += $_y * $y_weight;

            if ($x >= $term_height) {
                $x = $term_height;
                $up_down = !$up_down;
            }
            elsif ($x <= 0) {
                $x = 0;
                $up_down = !$up_down;
                $x_weight = rand;
            }

            if ($y >= $term_width) {
                $y = $term_width;
                $right_left = !$right_left;
            }
            elsif ($y <= 0) {
                $y = 0;
                $right_left = !$right_left;
                $y_weight = rand;
            }

            $term->go_to( $old_x, $old_y )
                 ->put_string( colored('_', 'dark blue') )
                 ->go_to( $x, $y )
                 ->put_string( colored( $sprite, $color ) )
                 ->go_to( 0, $term_width + 100 )
            unless $old_x == $x && $old_y == $y;
        }
    }
}

my $NUM_PARTICLES = shift(@ARGV) // 1;
my $WAIT_TIME     = shift(@ARGV) // 10;

sub init ($this, $msg) {

    my @ws = map {
        $this->spawn( Particle( $_ ) )
    } 1 .. $NUM_PARTICLES;

    $term->clear_screen;

    # ~ 60 fps
    my $i1 = interval( $this, 0.01, sub {
        $this->send( $_, [ *eTick ] ) foreach @ws;
    });

    my $t = timer( $this, $WAIT_TIME, sub {
        cancel_timer( $this, $i1 );
        $this->exit(0);
    });
}

ELO::Loop->run( \&init );

1;
