#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
use SAM::Actors;
use SAM::IO;

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
            sync( timeout( 10 - $i, msg($producer, next => []) ), $consumer );
            $i++;
            msg( PID, each => [ $producer, $consumer ] )->send if $i < 10;
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $s = sys::spawn('take_10_and_sync');

    msg(
        $s,
        each => [
            sys::spawn('counter'),
            out::print()
        ]
    )->send;

};

# loop ...
ok loop( 20, 'main' );

done_testing;

