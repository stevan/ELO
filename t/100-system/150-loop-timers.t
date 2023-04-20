#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';

my $log = Test::ELO->create_logger;

sub init ($this, $msg) {

    $this->loop->add_timer( 1, sub {
        $log->info( $this, '... after 1 second' );
    });

    $this->loop->add_timer( 2, sub {
        $log->info( $this, '... after 2 seconds' );
    });

    $this->loop->add_timer( 3, sub {
        $log->info( $this, '... after 3 seconds' );
    });

    $log->info( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
