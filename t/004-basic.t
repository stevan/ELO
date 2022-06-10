#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

use EventLoop;
use EventLoop::Actors;
use EventLoop::IO;

actor counter => sub ($env, $msg) {
    state $count = 0;
    match $msg, +{
        next => sub ($) {
            return_to( ++$count );
        }
    };
};

actor stream => sub ($env, $msg) {
    state $i = 0;

    match $msg, +{
        each => sub ($body) {
            my ($producer, $consumer) = @$body;
            sync( $producer, $consumer );
            $i++;
            send_to( PID, each => $body ) if $i < 10;
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $s = spawn('stream');

    send_to(
        $s,
        each => [
            [ spawn('counter'), next => [] ],
            out::print()
        ]
    );

};

# loop ...
ok loop( 20, 'main' );

done_testing;

