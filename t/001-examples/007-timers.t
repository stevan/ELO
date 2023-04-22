#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Timers', qw[
    timer
    interval
    cancel_timer
];

my $log = Test::ELO->create_logger;

sub Responder ($this, $msg) {
    state $counter = 0;

    $log->debug( $this, "ENTERED" );

    $log->info( $this, $msg );
    if ( $counter < 10 ) {
        pass('... got messages('.++$counter.') in Responder');
    } else {
        fail('... we only expected 10 messages, got '.++$counter);
    }
}

sub init ($this, $msg) {

    $log->debug( $this, "ENTERED" );

    my $r = $this->spawn( Responder => \&Responder );
    isa_ok($r, 'ELO::Core::Process');

    my $i1 = interval( $this, 0.3, [ $r, ['Hello again ... interval(0.3)']] );

    my $t0 = timer( $this, 0, [ $r, ['Hello ... timeout(0)'] ] );
    my $t1 = timer( $this, 1, [ $r, ['Hello ... timeout(1)'] ] );
    my $t2 = timer( $this, 2, sub {
        $this->send( $r, ['Hello ... timeout(2) >> killing interval(0.5)'] );
        cancel_timer( $this, $i1 );
    });

    my $t5 = timer( $this, 5, [ $r, ['Hello ... timeout(5)'] ] );

    my $t3 = timer( $this, 3, sub {
        cancel_timer( $this, $t5 );
        $this->send( $r, ['Hello ... timeout(3) >> killing timeout(5)'] );
    });
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
