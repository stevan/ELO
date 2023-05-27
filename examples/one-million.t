#!perl

use v5.36;

$|++;

use Data::Dumper;
use Time::HiRes qw[ time ];

use ELO::Loop;
use ELO::Types  qw[ :signals ];
use ELO::Timers qw[ :timers ];
use ELO::Actors qw[ setup receive IGNORE ];

use ELO::Util::Logger;

my $log = ELO::Util::Logger->new;

my $NUM_ACTORS  = $ARGV[0] // 100;
my $PAUSE_FOR   = $ARGV[1] // 10;

say "Got Request for $NUM_ACTORS, will pause $PAUSE_FOR seconds before exiting.";

sub Actor ($id) {

    setup sub ($this) {

        # we want this to start when the
        # real loop starts, not here, which
        # is technically in the startup phase
        # and not really the actor lifetime
        $this->loop->next_tick(sub {
            $this->loop->add_timer( $PAUSE_FOR, sub { $this->exit(0) });
        });

        # we have no message to map, so
        # why waste an instance here
        IGNORE;
    };
}

sub Init () {

    setup sub ($this) {
        my $actor_count = 0;

        my $start = time;
        $log->info( $this, "Creating ($NUM_ACTORS) actors" );

        my $count = 0;
        $this->spawn(Actor($count++)) while $count < $NUM_ACTORS;

        my $duration = scalar time - $start;
        $log->info( $this, "($count) actors created in $duration seconds" );

        IGNORE;
    };
}

ELO::Loop->run( Init(), logger => $log );

1;
