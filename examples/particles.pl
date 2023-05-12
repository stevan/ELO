#!perl

use v5.36;

use Data::Dumper;

use ELO::Loop;
use ELO::Actors    qw[ match receive ];
use ELO::Timers    qw[ :timers :tickers ];
use ELO::Types     qw[ :core :events ];

use Term::ANSIColor qw[ colored uncolor ];

use constant QUIET => $ENV{QUIET} // 0;

use ELO::Util::TermDisplay;

my $term = ELO::Util::TermDisplay->new;

my $term_top    = 1;
my $term_left   = 1;
my $term_height = $term->term_height - 3;
my $term_width  = $term->term_width  - 3;

my $NUM_PARTICLES = shift(@ARGV) // 1;
my $WAIT_TIME     = shift(@ARGV) // 10;
my $GRAVITY       = shift(@ARGV) // 5;

event *eTick;

sub Particle ($id) {

    state $sprite = '⦿';
    state $trail  = '◇';

    my $color = 'ansi'.($id % 255);

    my $up_down    = !!(rand); # 1 = DOWN,  0 = UP
    my $right_left = !!(rand); # 1 = RIGHT, 0 = LEFT

    my $x_weight = rand;
    my $y_weight = rand;

    my $x_seed = rand;
    my $y_seed = rand;

    my $x = rand($term_height);
    my $y = rand($term_width);

    my $mass = rand() / $GRAVITY;

    my $friction = 0;

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
            elsif ($x <= $friction) {
                $x = $friction;
                $up_down = !$up_down;
            }

            if ($y >= $term_width) {
                $y = $term_width;
                $right_left = !$right_left;
            }
            elsif ($y <= 0) {
                $y = 0;
                $right_left = !$right_left;
            }

            $friction += $mass;

            unless (QUIET) {
                $term->go_to( $term_top + $old_x, $term_left + $old_y )
                     ->put_string( colored( $trail, 'dark blue') )
                     ->go_to( $term_top + $x, $term_left + $y )
                     ->put_string( colored( $sprite, $color ) )
                     #->go_to( $id + 2, 1 )
                     #->put_string( sprintf '%5d : %0.3f %0.3f' => $id, $x, $y )
                     ->go_to( 0, $term_width + 100 )
                unless $old_x == $x && $old_y == $y;
            }

            if ( $friction >= $term_height ) {
                $term->go_to( $term_top + $x, $term_left + $y )
                     ->put_string( colored( $trail, 'dark blue' ) )
                     ->go_to( $term_height+2, $term_left + $y )
                     ->put_string( colored( $sprite, $color ) )
                        unless QUIET;

                $this->exit(0);
            }
        }
    }
}

sub init ($this, $msg) {

    my @ps; # set of particles
    my $i1; # animation interval
    my $i2; # fps/gc interval
    my $t1; # total wait timer

    @ps = map {
        $this->spawn( Particle( $_ ) )
    } 1 .. $NUM_PARTICLES;

    $term->clear_screen;

    my $frame = 0;
    $i1 = interval( $this, 0.013, sub {
        $term->go_to(0, 0)->put_string( sprintf 'frame: %05d', $frame++ );
        $this->send( $_, [ *eTick ] ) foreach @ps;
    });

    my $fps_marker = 0;
    $i2 = interval( $this, 0.985, sub {
        unless (@ps = grep $_->is_alive, @ps) {
            cancel_timer( $this, $_ ) for $i1, $i2;
            cancel_timer( $this, $t1 );
            $term->go_to($term_height+1, 0);
            $this->exit(0);
        }

        $term->go_to(0, 15)
             ->put_string( sprintf '~%3d fps', $frame - $fps_marker )
             ->go_to(0, 30)
             ->put_string( sprintf 'alive: %09d' => scalar @ps );
        $fps_marker = $frame;
    });

    $t1 = timer( $this, $WAIT_TIME, sub {
        cancel_timer( $this, $_ ) for $i1, $i2;
        $this->exit(0);
    });

    $term->go_to(0, 0)
         ->put_string( sprintf 'frame: %05d', $frame )
         ->go_to(0, 15)
         ->put_string( sprintf '~%3d fps', $fps_marker )
         ->go_to(0, 30)
         ->put_string( sprintf 'alive: %09d' => scalar @ps );

}

ELO::Loop->run( \&init );

1;
