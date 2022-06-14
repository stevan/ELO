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
        next => sub () {
            return_to( ++$count );
        }
    };
};

actor take_10_and_sync => sub ($env, $msg) {
    state $i = 0;

    match $msg, +{
        each => sub ($producer, $consumer) {
            sync( timeout( 10 - $i, [$producer, next => []] ), $consumer );
            $i++;
            send_to( PID, each => [ $producer, $consumer ] ) if $i < 10;
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $s = spawn('take_10_and_sync');

    send_to(
        $s,
        each => [
            spawn('counter'),
            out::print()
        ]
    );

};

# loop ...
ok loop( 20, 'main' );

done_testing;

