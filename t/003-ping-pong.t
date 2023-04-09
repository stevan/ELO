#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ELO::Loop;
use ELO::Actors qw[ match ];

use ELO::Util::Logger;

my $log = ELO::Util::Logger->new;

# See Akka Example:
# https://alvinalexander.com/scala/scala-akka-actors-ping-pong-simple-example/

sub Ping ($this, $msg) {

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
            $count{$this}++;
            $log->info( $this, " Starting with (".$count{$this}.")" );
            $this->send( $pong, [ ePing => $this->pid ]);
        },
        ePong => sub ( $pong ) {
            $count{$this}++;
            $log->info( $this, " Pong with (".$count{$this}.")" );
            if ( $count{$this} >= 5 ) {
                $log->info( $this, " ... Stopping Ping" );
                $this->send( $pong, [ 'eStop' ]);
            }
            else {
                $this->send( $pong, [ ePing => $this->pid ]);
            }
        },
    };
}

sub Pong ($this, $msg) {

    # NOTE:
    # this is a stateless actor, so
    # nothing going on here :)

    match $msg, +{
        ePing => sub ( $ping ) {
            $log->info( $this, " ... Ping" );
            $this->send( $ping, [ ePong => $this->pid ]);
        },
        eStop => sub () {
            $log->info( $this, " ... Stopping Pong" );
        },
    };
}

sub init ($this, $msg=[]) {
    my $ping = $this->spawn( Ping  => \&Ping );
    my $pong = $this->spawn( Pong  => \&Pong );

    $this->send( $ping, [ eStartPing => $pong->pid ]);

    my $ping2 = $this->spawn( Ping2  => \&Ping );
    my $pong2 = $this->spawn( Pong2  => \&Pong );

    $this->send( $ping2, [ eStartPing => $pong2->pid ]);
}

ELO::Loop->run( \&init );

