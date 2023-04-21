#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use List::Util 'uniq';
use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Timers', qw[
    timer
    cancel_timer
];

my $log = Test::ELO->create_logger;

sub LazyWorker ($this, $msg) {
    state $counter = 0;

    $counter++;
    $log->info( $this, [ msg => $msg, counter => $counter ] );

    if ( $counter % 3 == 0 ) {
        $log->info( $this, '... oh, I am tired gimme 0.5s' );
        $this->sleep( 0.5 );
        pass('... we are sleeping after 3 jobs');
        # do this in the next tick so that
        # the loop can deliver all the other
        # messages to this process
        $this->loop->next_tick(sub {
            $log->warn(
                $this,
                sprintf '/next-tick/ has %d pending messages for (%s)' => (
                    $this->has_pending_messages,
                    join ", " => sort { $a cmp $b } uniq( map $_->[1], $this->get_pending_messages )
                )
            );
        });
    }
}

sub init ($this, $msg) {

    my $l1 = $this->spawn( LazyWorker  => \&LazyWorker );
    my $l2 = $this->spawn( LazyWorker  => \&LazyWorker );

    $log->warn( $this, '... adding 5 messages to LazyWorker(1)');
    $this->send( $l1, [ $_, 'root(1)' ] ) for 1 .. 5;
    $log->warn( $this, '... adding 10 messages to LazyWorker(2)');
    $this->send( $l2, [ $_, 'root(2)' ] ) for 1 .. 10;
    $log->warn( $this, '... adding 12 messages to LazyWorker(1)');
    $this->send( $l1, [ $_, 'root(1)' ] ) for 1 .. 12;

    my $t1 = timer( $this, 0.2, sub {
        $log->info( $this, '... timer1 went off after 0.2 second(s)');
        $log->warn( $this, '... adding 12 messages to LazyWorker(1)');
        $this->send( $l1, [ $_, 'timer1(1)' ] ) for 1 .. 12;
        $log->warn( $this, '... adding 5 messages to LazyWorker(2)');
        $this->send( $l2, [ $_, 'timer1(2)' ] ) for 1 .. 5;
    });

    my $t2 = timer( $this, 0.7, sub {
        $log->info( $this, '... timer2 went off after 0.7 second(s)');
        $log->warn( $this, '... adding 10 messages to LazyWorker(1)');
        $this->send( $l1, [ $_, 'timer2(1)' ] ) for 1 .. 10;
    });

    my $t3 = timer( $this, 1.2, sub {
        $log->info( $this, '... timer3 went off after 1.2 second(s)');
        $log->warn( $this, '... adding 7 messages to LazyWorker(2)');
        $this->send( $l2, [ $_, 'timer3(2)' ] ) for 1 .. 7;
    });

}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;