#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use List::Util 'uniq';
use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Timers', ':timers';

my $log = Test::ELO->create_logger;

diag "... sleeping takes a bit";

sub LazyWorker ($this, $msg) {
    state $counter = 0;

    $counter++;
    $log->info( $this, [ msg => $msg, counter => $counter ] );

    if ( $counter % 5 == 0 ) {
        $log->info( $this, '... oh, I am tired gimme 0.1s' );
        $this->sleep( 0.1 );
        pass('... we are sleeping after 5 jobs');
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

    my $l1 = $this->spawn( LazyWorker1 => \&LazyWorker );
    my $l2 = $this->spawn( LazyWorker2 => \&LazyWorker );

    $log->warn( $this, '... root adding 5 messages to LazyWorker(1)');
    $this->send( $l1, [ $_, 'root(1)' ] ) for 1 .. 5;
    $log->warn( $this, '... root adding 10 messages to LazyWorker(2)');
    $this->send( $l2, [ $_, 'root(2)' ] ) for 1 .. 10;
    $log->warn( $this, '... root adding 12 messages to LazyWorker(1)');
    $this->send( $l1, [ $_, 'root(1)' ] ) for 1 .. 12;

    my $t1 = timer( $this, 0.2, sub {
        $log->info( $this, '... timer1 went off after 0.2 second(s)');
        $log->warn( $this, '... timer1 adding 12 messages to LazyWorker(1)');
        $this->send( $l1, [ $_, 'timer1(1)' ] ) for 1 .. 12;
        $log->warn( $this, '... timer1 adding 5 messages to LazyWorker(2)');
        $this->send( $l2, [ $_, 'timer1(2)' ] ) for 1 .. 5;
    });

    my $t2 = timer( $this, 0.7, sub {
        $log->info( $this, '... timer2 went off after 0.7 second(s)');
        $log->warn( $this, '... timer2 adding 10 messages to LazyWorker(1)');
        $this->send( $l1, [ $_, 'timer2(1)' ] ) for 1 .. 10;
    });

    my $t3 = timer( $this, 1.2, sub {
        $log->info( $this, '... timer3 went off after 1.2 second(s)');
        $log->warn( $this, '... timer3 adding 7 messages to LazyWorker(2)');
        $this->send( $l2, [ $_, 'timer3(2)' ] ) for 1 .. 7;
    });

}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
