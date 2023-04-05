#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors qw[ match ];

use constant DEBUG => $ENV{DEBUG} // 0;

# See Akka Example:
# https://alvinalexander.com/scala/scala-akka-actors-ping-pong-simple-example/

sub Ping ($this, $msg) {

    state $count = 0;

    match $msg, state $handlers = +{
        eStartPing => sub ( $pong ) {
            $count++;
            say "Starting with ($count)";
            $this->send( $pong, [ ePing => $this ]);
        },
        ePong => sub ( $pong ) {
            $count++;
            say "Pong with ($count)";
            if ( $count > 10 ) {
                say "... Stopping Ping";
                $this->send( $pong, [ 'eStop' ]);
            }
            else {
                $this->send( $pong, [ ePing => $this ]);
            }
        },
    };
}

sub Pong ($this, $msg) {

    match $msg, state $handlers = +{
        ePing => sub ( $ping ) {
            say "... Ping";
            $this->send( $ping, [ ePong => $this ]);
        },
        eStop => sub () {
            say "... Stopping Pong";
        },
    };
}

sub init ($this, $msg=[]) {
    my $ping = $this->spawn( Ping  => \&Ping );
    my $pong = $this->spawn( Pong  => \&Pong );

    $this->send( $ping, [ eStartPing => $pong ]);

}

ELO::Loop->new->run( \&init );

