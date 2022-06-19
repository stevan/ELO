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
use ELO::Msg;
use ELO::Actors;
use ELO::IO;

actor collector => sub ($env, $msg) {
    state $values = [];
    match $msg, +{
        on_next => sub ($value) {
            push @$values => $value;
        },
        finish => sub () {
            sig::kill(PID)->send;
            eq_or_diff([ sort { $a <=> $b } @$values ], $env->{expected}, '... got the expected values');
        }
    };
};

actor counter => sub ($env, $msg) {
    state $count = 0;
    match $msg, +{
        next => sub ($callback) {
            $callback->curry( ++$count )->send;
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
            sig::timer( 10 - $i, msg($producer, next => [ msg($consumer, on_next => []) ]) )->send;
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
    sig::timer( 18,
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

