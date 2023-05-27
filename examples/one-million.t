#!perl

use v5.36;

$|++;

use Data::Dumper;
use Time::HiRes qw[ time ];

use ELO::Loop;
use ELO::Types  qw[ :signals ];
use ELO::Timers qw[ :timers ];
use ELO::Actors qw[ setup receive ];

use ELO::Util::Logger;

my $log = ELO::Util::Logger->new;

my $NUM_ACTORS  = $ARGV[0] // 100;
my $PAUSE_FOR   = $ARGV[1] // 10;

say "Got Request for $NUM_ACTORS, will pause $PAUSE_FOR seconds before exiting.";

sub Actor ($id) {
    setup sub ($this) {

        $this->loop->next_tick(sub {
            #$log->info( $this, "Starting timer ..." );
            $this->loop->add_timer( $PAUSE_FOR, sub { $this->exit(0) });
        });

        receive +{};
    };
}

my $exit_start;

sub Init () {

    setup sub ($this) {
        my $actor_count = 0;

        my $start = time;
        $log->info( $this, "Creating ($NUM_ACTORS) actors" );

        my $count = 0;
        $this->spawn(Actor($count++)) while $count < $NUM_ACTORS;

        my $duration = scalar time - $start;
        $log->info( $this, "($count) actors created in $duration seconds" );

        receive +{};
    };
}

ELO::Loop->run( Init(), logger => $log );

#my $duration = scalar time - $exit_start;
#say "\nExiting took $duration seconds";

1;
