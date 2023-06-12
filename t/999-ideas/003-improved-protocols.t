#!perl

use v5.36;
no warnings 'once';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Actors', qw[ receive ];
use ok 'ELO::Types',  qw[
    :core
    :events
    :types
];

# Events ...

# the basic Observer interface, shared by many ...

event *OnComplete => ();
event *OnNext     => ( *Scalar );
event *OnError    => ( *Str );

# Subscription related events ...

event *Subscribe     => ( *Process );
event *OnSubscribe   => ( *Process );

event *Unsubscribe   => ( *Process );
event *OnUnsubscribe => ();


# Request related events ...

event *Request           => (*Int);
event *OnRequestComplete => ();
event *Cancel            => ();

# Publisher related events ..

event *GetNext     => ( *Process );

# Protocols ...

=poc

protocol *Observer => sub {
    accepts *OnNext,
            *OnComplete,
            *OnError;
};

protocol *Subscriber => sub {
    accepts *OnSubscribe,
            *OnUnsubscribe,
            *OnRequestComplete,
            *OnNext,
            *OnComplete,
            *OnError;
};

protocol *Subscription => sub {
    accepts *Request,
            *Cancel,
            *OnUnsubscribe;
};


protocol *Publisher => sub {
    accepts *Subscribe,   returns *OnSubscribe;
    accepts *Unsubscribe, returns *OnUnsubscribe;
    accepts *GetNext,
        returns *OnNext, *OnComplete,
        raises *OnError;
};

subtest '... checking *Ping' => sub {
    my $this = bless {} => 'ELO::Core::Process';

    ok( lookup_type(*Ping)->check( [*eStartPing, $this] ), '... this passed the type check for Ping with an eStartPing' );
    ok( lookup_type(*Ping)->check( [*ePong,      $this] ), '... this passed the type check for Ping with an ePing' );

    ok( !lookup_type(*Ping)->check( "Ops" ), '... this failed the type check for Ping with an Str(Ops)' );
    ok( !lookup_type(*Ping)->check( 100 ),   '... this failed the type check for Ping with an Int' );
    ok( !lookup_type(*Ping)->check( 0.01 ),  '... this failed the type check for Ping with an Float' );
    ok( !lookup_type(*Ping)->check( [] ),    '... this failed the type check for Ping with an ArrayRef' );
    ok( !lookup_type(*Ping)->check( {} ),    '... this failed the type check for Ping with an HashRef' );
};

subtest '... check the protocol instance with receive' => sub {

    my $this = bless {} => 'ELO::Core::Process';
    my @msgs = ([ *eStartPing, $this ], [ *ePong, $this ]);
    my @exp  = ('Started Ping', 'Pong');

    # would mostly be used in this way ...

    my $behavior = receive[ *Ping ] => {
        *eStartPing => sub ($this, $p) { '...' },
    };

    foreach my $msg ( @msgs ) {
        my $result = $behavior->apply( $this, $msg );
        is($result, shift(@exp), '... got the expected result');
    }

};

subtest '... check the protocol instance with match' => sub {

    my $this = bless {} => 'ELO::Core::Process';
    my @msgs = ([ *eStartPing, $this ], [ *ePong, $this ]);
    my @exp  = ('Started Ping', 'Pong');

    foreach my $msg ( @msgs ) {

        my $result = match [ *Ping, $msg ] => {
            *eStartPing => sub ($p) { '...' },
        };

        is($result, shift(@exp), '... got the expected result');
    }
};

=cut

done_testing;

1;

__END__

