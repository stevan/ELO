#!perl

use v5.36;
no warnings 'once';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Types',  qw[
    :core
    :events
    :types
];

=pod

protocol *Ping => sub {
    event *eStartPing => ( *Process );
    event *ePong      => ( *Process );
};

protocol *Pong => sub {
    event *eStopPong  => ();
    event *ePing      => ( *Process );
};

subtest '... check the protocol instance' => sub {


    receive[*Ping] => {
        *eStartPing => sub ($p) {},
        *ePong      => sub ($p) {},
    };

};

=cut

ok(1);

done_testing;

1;

__END__

