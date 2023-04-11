#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;
use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match ];

my $log = Test::ELO->create_logger;

# See Akka Example:
# https://alvinalexander.com/scala/scala-akka-actors-ping-pong-simple-example/

sub Ping ($this, $msg) {
    isa_ok($this, 'ELO::Core::Process');

    $log->debug( $this, $msg );

    # NOTE:
    # it would be nicer if we could
    # just do `state $count` and it
    # would have one `$count` per
    # instance of the Actor.
    #
    # Instead we need to use inside-out
    # objects with `$this` being our
    # object-id key.

    fieldhash state %count;

    match $msg, +{
        eStartPing => sub ( $pong ) {
            isa_ok($pong, 'ELO::Core::Process');

            $count{$this}++;
            $log->info( $this, " Starting with (".$count{$this}.")" );
            $this->send( $pong, [ ePing => $this ]);

            pass('... '.$this->name.' started with '.$this->env('max_pings').' max pings');
        },
        ePong => sub ( $pong ) {
            isa_ok($pong, 'ELO::Core::Process');

            $count{$this}++;
            $log->info( $this, " Pong with (".$count{$this}.")" );
            if ( $count{$this} >= $this->env('max_pings') ) {
                $log->info( $this, " ... Stopping Ping" );
                $this->send( $pong, [ 'eStop' ]);

                pass('... '.$this->name.' finished with '.$count{$this}.' pings');
            }
            else {
                $this->send( $pong, [ ePing => $this ]);
            }
        },
    };
}

sub Pong ($this, $msg) {
    isa_ok($this, 'ELO::Core::Process');

    $log->debug( $this, $msg );

    # NOTE:
    # this is a stateless actor, so
    # nothing going on here :)

    match $msg, +{
        ePing => sub ( $ping ) {
            isa_ok($ping, 'ELO::Core::Process');

            $log->info( $this, " ... Ping" );
            $this->send( $ping, [ ePong => $this ]);
        },
        eStop => sub () {
            $log->info( $this, " ... Stopping Pong" );

            pass('... '.$this->name.' finished');
        },
    };
}

sub init ($this, $msg=[]) {
    isa_ok($this, 'ELO::Core::Process');

    my $ping = $this->spawn( Ping  => \&Ping, { max_pings => 5 } );
    my $pong = $this->spawn( Pong  => \&Pong );

    isa_ok($ping, 'ELO::Core::Process');
    isa_ok($pong, 'ELO::Core::Process');

    $this->send( $ping, [ eStartPing => $pong ]);

    my $ping2 = $this->spawn( Ping2  => \&Ping, { max_pings => 10 });
    my $pong2 = $this->spawn( Pong2  => \&Pong );

    isa_ok($ping2, 'ELO::Core::Process');
    isa_ok($pong2, 'ELO::Core::Process');

    $this->send( $ping2, [ eStartPing => $pong2 ]);
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



