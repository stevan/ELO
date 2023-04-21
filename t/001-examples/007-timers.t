#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Timers', qw[
    timer
    cancel_timer
];

my $log = Test::ELO->create_logger;

sub Responder ($this, $msg) {

    $log->debug( $this, "ENTERED" );

    $log->info( $this, $msg );
}

sub init ($this, $msg) {

    $log->debug( $this, "ENTERED" );

    my $r = $this->spawn( Responder => \&Responder );
    isa_ok($r, 'ELO::Core::Process');

    my $t0 = timer( $this, 0, [ $r, ['Hello ... timeout(0)'] ] );
    my $t1 = timer( $this, 1, [ $r, ['Hello ... timeout(1)'] ] );
    my $t2 = timer( $this, 2, [ $r, ['Hello ... timeout(2)'] ] );

    my $t5 = timer( $this, 5, [ $r, ['Hello ... timeout(5)'] ] );

    my $t3 = timer( $this, 3, sub {
        cancel_timer( $this, $t5 );
        $this->send( $r, ['Hello ... timeout(3) >> killing timeout(5)'] );
    });
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;