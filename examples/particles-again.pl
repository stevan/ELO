#!perl

use v5.36;
use experimental 'builtin';

use Data::Dumper;

use ELO::Loop;
use ELO::Actors    qw[ receive ];
use ELO::Timers    qw[ :timers :tickers ];
use ELO::Types     qw[ :core :events ];

use Term::ANSIColor qw[ colored uncolor ];

use constant QUIET => $ENV{QUIET} // 0;

use ELO::Util::TermDisplay;

my $term = ELO::Util::TermDisplay->new;

my $NUM_PARTICLES = shift(@ARGV) // 100;
my $WAIT_TIME     = shift(@ARGV) // 30;
my $GRAVITY       = shift(@ARGV) // 5;

event *eTick;

sub Particle ($id, $window, $capture_window) {

    state $height = $window->height;
    state $width  = $window->width;

     # ○ ● ◎ ◍

    my $sprite = '●'; # chr(int(rand( 126 - 32 )) + 32);
    my $trail  = '○'; # chr(int(rand( 126 - 32 )) + 32);

    my $color = 'ansi'.($id % 255);

    my $up_down    = 1;                         # 1 = DOWN,  0 = UP
    my $right_left = (int(rand(10)) % 2) ? 1 : 0; # 1 = RIGHT, 0 = LEFT

    my $x_weight = rand;
    my $y_weight = rand;

    my $x_seed = rand;
    my $y_seed = rand;

    my $x = rand($height);
    my $y = rand($width);

    my $mass = rand() / $GRAVITY;

    my $friction = 0;

    receive +{
        *eTick => sub ($this) {

            my ($old_x, $old_y) = ($x, $y);

            my $_x = ($up_down    ? $x_seed : -$x_seed );
            my $_y = ($right_left ? $y_seed : -$x_seed );

            $x += $_x * $x_weight;
            $y += $_y * $y_weight;

            if ($x >= $height) {
                $x = $height;
                $up_down = !$up_down;
            }
            elsif ($x <= $friction) {
                $x = $friction;
                $up_down = !$up_down;
            }

            if ($y >= $width) {
                $y = $width;
                $right_left = !$right_left;
            }
            elsif ($y <= 0) {
                $y = 0;
                $right_left = !$right_left;
            }

            $friction += $mass;

            unless (QUIET) {
                $window->put_at( colored( $trail,  'dark '.$color), $old_x, $old_y )
                       ->put_at( colored( $sprite, 'bold '.$color ), $x, $y )
                       ->hide_cursor
                unless $old_x == $x && $old_y == $y;
            }

            if ( $friction >= $window->height ) {
                $window->put_at( colored( $trail,  'dark '.$color), $x, $y );
                $capture_window->put_at(
                    colored( $sprite, 'bold '.$color ),
                    (int($id / $width) % ($capture_window->height+1)),
                    ($id % $width)
                ) unless QUIET;

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

    $term->clear_screen( with_markers => 1 );

    my $particle_window  = $term->create_window( 3, 5, $term->term_height-20, $term->term_width-10 );
    my $capture_window   = $term->create_window(
        ($particle_window->height + 6),
        5,
        ($term->term_height - ($particle_window->height + $particle_window->top + 6)),
        $term->term_width - 10
    );
    my $frame_cnt_window = $term->create_window( 0, 0, 1, 15 );
    my $fps_window       = $term->create_window( 0, 15, 1, 15 );
    my $alive_window     = $term->create_window( 0, 30, 1, 15 );

    @ps = map {
        $this->spawn( Particle( $_, $particle_window, $capture_window ) )
    } 1 .. $NUM_PARTICLES;

    $particle_window->draw_window;
    $capture_window->draw_window;

    my $frame = 0;
    $i1 = interval( $this, 0.013, sub {
        $frame_cnt_window->put_at((sprintf 'frame: %05d', $frame++ ), 0, 0 );
        $this->send( $_, [ *eTick ] ) foreach @ps;
    });

    my $fps_marker = 0;
    $i2 = interval( $this, 0.985, sub {
        unless (@ps = grep $_->is_alive, @ps) {
            cancel_timer( $this, $_ ) for $i1, $i2;
            cancel_timer( $this, $t1 );
            $term->go_to($term->term_height+1, 0);
            $this->exit(0);
        }

        $fps_window->put_at((sprintf '~%3d fps', $frame - $fps_marker), 0, 0 );
        $alive_window->put_at((sprintf 'alive: %09d' => scalar @ps), 0, 0 );
        $fps_marker = $frame;
    });

    $t1 = timer( $this, $WAIT_TIME, sub {
        cancel_timer( $this, $_ ) for $i1, $i2;
        $this->exit(0);
    });

    $frame_cnt_window->put_at((sprintf 'frame: %05d', $frame ), 0, 0 );
    $fps_window->put_at((sprintf '~%3d fps', $fps_marker), 0, 0 );
    $alive_window->put_at((sprintf 'alive: %09d' => scalar @ps), 0, 0 );
}

ELO::Loop->run( \&init );

1;
