#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ELO::Loop;
use ELO::Actors qw[ match ];

use constant DEBUG => $ENV{DEBUG} || 0;

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
            say $this->pid." Starting with (".$count{$this}.")";
            $this->send( $pong, [ ePing => $this ]);
        },
        ePong => sub ( $pong ) {
            $count{$this}++;
            say $this->pid." Pong with (".$count{$this}.")";
            if ( $count{$this} >= 5 ) {
                say $this->pid." ... Stopping Ping";
                $this->send( $pong, [ 'eStop' ]);
            }
            else {
                $this->send( $pong, [ ePing => $this ]);
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
            say $this->pid." ... Ping";
            $this->send( $ping, [ ePong => $this ]);
        },
        eStop => sub () {
            say $this->pid." ... Stopping Pong";
        },
    };
}

sub init ($this, $msg=[]) {
    my $ping = $this->spawn( Ping  => \&Ping );
    my $pong = $this->spawn( Pong  => \&Pong );

    $this->send( $ping, [ eStartPing => $pong ]);

    my $ping2 = $this->spawn( Ping2  => \&Ping );
    my $pong2 = $this->spawn( Pong2  => \&Pong );

    $this->send( $ping2, [ eStartPing => $pong2 ]);
}

ELO::Loop->run( \&init );

