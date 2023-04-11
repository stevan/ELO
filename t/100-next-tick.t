#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Timers', qw[ timer ];

my $log = Test::ELO->create_logger;

sub init ($this, $msg) {
    isa_ok($this, 'ELO::Core::Process');

    my $x = 0;

    timer( $this, 0, sub { is($x, 0, '... x should be equal to 0') });
    timer( $this, 1, sub { is($x, 1, '... x should be equal to 1 by now') });
    timer( $this, 2, sub { is($x, 2, '... x should be equal to 2 by now') });
    timer( $this, 3, sub { is($x, 2, '... x should still be 2 by now') });

    $log->info( $this, "Hello World" );
    $this->loop->next_tick(sub {
        $log->info( $this, "Goodbye World" );
        $x++;
        $this->loop->next_tick(sub {
            $log->info( $this, "I'm really going now" );
            $x++;
        });
    });

    timer( $this, 0, sub { is($x, 1, '... x should be equal to 1 because it runs after the x++ ticks') });
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
