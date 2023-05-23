#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';

my $log = Test::ELO->create_logger;

diag "... this one takes a few seconds";

sub init ($this, $msg) {

    my $count = 0;

    my $t0 = $this->loop->add_timer( 0, sub {
        is($count, 0, '... timer after 0 seconds (counter = 0)');
        $log->info( $this, '... after 0 seconds' );
        $count++;
    });

    my $t1 = $this->loop->add_timer( 1, sub {
        is($count, 1, '... timer after 1 seconds (counter = 1)');
        $log->info( $this, '... after 1 second' );
        $count++;
    });

    my $t2 = $this->loop->add_timer( 2, sub {
        is($count, 2, '... timer after 2 seconds (counter = 2)');
        $log->info( $this, '... after 2 seconds' );
        $count++;
    });

    my $t4 = $this->loop->add_timer( 4, sub {
        is($count, 4, '... timer after 4 seconds (counter = 4)');
        $log->info( $this, '... after 4 seconds' );
        $count++;
    });

    my $t5 = $this->loop->add_timer( 5, sub {
        fail('... we should not have the 5 second timeout');
        $log->info( $this, '... after 5 seconds' );
    });

    my $t6 = $this->loop->add_timer( 6, sub {
        is($count, 5, '... timer after 6 seconds (counter = 5 because timer(5) was canceled )');
        $log->info( $this, '... after 6 seconds' );
    });

    my $t3 = $this->loop->add_timer( 3, sub {
        is($count, 3, '... timer after 3 seconds (counter = 3)');
        $log->info( $this, '... canceling timer for timer(5)' );
        $this->loop->cancel_timer( $t5 );
        $log->info( $this, '... after 3 seconds' );
        $count++;
    });

    $log->info( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
