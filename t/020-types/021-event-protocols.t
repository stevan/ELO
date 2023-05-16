#!perl

use v5.36;
no warnings 'once';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Types',  qw[
    :core
    :events
    :types
];


protocol *Ping => sub {
    event *eStartPing => ( *Process );
    event *ePong      => ( *Process );
};

protocol *Pong => sub {
    event *eStopPong  => ();
    event *ePing      => ( *Process );
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

# subtest '... check the protocol instance with receive' => sub {
#
#     my $this = bless {} => 'ELO::Core::Process';
#     my $msg  = [ *StartPing, $this ];
#
#     # would mostly be used in this way ...
#
#     my $behavior = receive[ *Ping ] => {
#         *eStartPing => sub ($this, $p) { 'Started Ping' },
#         *ePong      => sub ($this, $p) { 'Pong'},
#     };
#
#     my $result = $behavior->apply( $this, $msg );
# };

subtest '... check the protocol instance with match' => sub {

    my $this = bless {} => 'ELO::Core::Process';
    my @msgs = ([ *eStartPing, $this ], [ *ePong, $this ]);
    my @exp  = ('Started Ping', 'Pong');

    foreach my $msg ( @msgs ) {

        my $result = match [ *Ping, $msg ] => {
            *eStartPing => sub ($p) { 'Started Ping' },
            *ePong      => sub ($p) { 'Pong' },
        };

        is($result, shift(@exp), '... got the expected result');
    }
};

done_testing;

1;

__END__

