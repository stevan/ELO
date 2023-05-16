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

    # would mostly be used in this way ...

    receive[*Ping] => {
        *eStartPing => sub ($p) {},
        *ePong      => sub ($p) {},
    };

    # in theory this should work too
    # assuming we tell match how to do it

    match [ *Ping, $msg ] => {
        *eStartPing => sub ($p) {},
        *ePong      => sub ($p) {},
    };

};

=cut

ok(1);

done_testing;

1;

__END__

