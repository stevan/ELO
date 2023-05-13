#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Timers', ':tickers';

my $log = Test::ELO->create_logger;

sub Responder ($this, $msg) {

    $log->debug( $this, "ENTERED" );

    $log->info( $this, $msg );
}

sub init ($this, $msg) {

    $log->debug( $this, "ENTERED" );

    my $r = $this->spawn( Responder => \&Responder );
    isa_ok($r, 'ELO::Core::Process');

    my $t0 = ticker( $this, 0, [ $r, ['Hello ... timeout(0)'] ] );
    my $t1 = ticker( $this, 1, [ $r, ['Hello ... timeout(1)'] ] );
    my $t2 = ticker( $this, 2, [ $r, ['Hello ... timeout(2)'] ] );

    my $t5 = ticker( $this, 5, [ $r, ['Hello ... timeout(5)'] ] );
    my $t3 = ticker( $this, 3, sub { cancel_ticker( $t5 ) } );

    my $i0 = interval_ticker( $this, 3, [ $r, ['Hello ... interval(3)'] ] );
    my $i2 = ticker( $this, 10, sub { cancel_ticker( $i0 ) } );

}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
