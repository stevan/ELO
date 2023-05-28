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
    state $loop;

    setup sub ($this) {
        $loop //= $this->loop; # the loop is always the same, so optimize it ;)

        # NOTE:
        # these will start immediately upon `spawn`,
        # which means that if you are starting a lot
        # it is possible that the first timer has expired
        # before the last time is created (assuming a
        # short timer of course). Previously we scheduled
        # all these through a `next_tick` which would
        # then mean that timers were not be affected by
        # the `spawn` calls, but only by the callbacks
        # setting up the timers. To be honest, I think
        # this approach is better, and more honest.
        $loop->add_timer( $PAUSE_FOR, sub { $this->exit(0) });

        # we have no message to map, so
        # why waste an instance here
        IGNORE;
    };
}

sub init ($this, $) {

    my $actor_count = 0;

    my $start = time;
    $log->info( $this, "Creating ($NUM_ACTORS) actors" );

    my $count = 0;
    $this->spawn(Actor($count++)) while $count < $NUM_ACTORS;

    my $duration = scalar time - $start;
    $log->info( $this, "($count) actors created in $duration seconds" );
}

ELO::Loop->run( \&init, logger => $log );

1;
