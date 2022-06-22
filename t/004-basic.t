#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::Differences;
use Test::ELO;

use List::Util 'first';
use Data::Dumper;

use ELO;

actor collector => sub ($env, $msg) {
    state $values = [];
    match $msg, +{
        on_next => sub ($value) {
            err::log(PID." got value($value)")->send if DEBUG;
            push @$values => $value;
        },
        finish => sub () {
            err::log(PID." finished")->send if DEBUG;
            sig::kill(PID)->send;
            eq_or_diff([ sort { $a <=> $b } @$values ], $env->{expected}, '... got the expected values');
        }
    };
};

actor counter => sub ($env, $msg) {
    state $count = 0;
    match $msg, +{
        next => sub ($callback) {
            $count++;
            err::log(PID." sending value ($count) to (".$callback->pid.")")->send if DEBUG;
            $callback->curry( $count )->send;
        },
        finish => sub () {
            sig::kill(PID)->send;
        }
    };
};

actor take_10_and_sync => sub ($env, $msg) {
    state $i = 0;

    match $msg, +{
        each => sub ($producer, $consumer) {
            sig::timer( 11 - $i, msg($producer, next => [ msg($consumer, on_next => []) ]) )->send;
            $i++;
            msg( PID, each => [ $producer, $consumer ] )->send if $i < 10;
        },
        finish => sub () {
            sig::kill(PID)->send;
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $s = proc::spawn('take_10_and_sync');
    my $p = proc::spawn('counter');
    my $c = proc::spawn('collector', expected =>  [ 1 .. 10 ] );

    msg( $s, each => [ $p, $c ] )->send;

    # cheap hack ...
    sig::timer( 20,
        parallel(
            msg($s, finish => []),
            msg($p, finish => []),
            msg($c, finish => []),
        )
    )->send;
};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

