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

actor Observer => sub ($env, $msg) {
    state $got = {};

    match $msg, +{
        on_next => sub ($msg) {
            my ($val) = @$msg;
            out::print("Observer got val($val)");
            $got->{$val}++;
        },
        on_error => sub ($msg) {
            my ($e) = @$msg;
            err::log("Observer got error($e)");
        },
        on_completed => sub ($msg) {
            err::log("Observer completed");
            err::log("Observed values: [" . (join ', ' => sort { $a <=> $b } keys $got->%*) . "]");
            send_to( SYS, kill => [PID] );
        }
    };
};

actor Observer => sub ($env, $msg) {
    state $got = {};

    match $msg, +{
        on_next => sub ($msg) {
            my ($val) = @$msg;
            out::print("Observer got val($val)");
            $got->{$val}++;
        },
        on_error => sub ($msg) {
            my ($e) = @$msg;
            err::log("Observer got error($e)");
        },
        on_completed => sub ($msg) {
            err::log("Observer completed");
            err::log("Observed values: [" . (join ', ' => sort { $a <=> $b } keys $got->%*) . "]");
            send_to( SYS, kill => [PID] );
        }
    };
};

actor SimpleObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($msg) {
            my ($observer) = @$msg;
            err::log("SimpleObserveable started, calling ($observer)");
            # A simple example
            sequence(
                (map [ $observer, on_next => [ $_ ] ], 0 .. 10),
                [ $observer, on_completed => [] ]
            );
        },
    };
};

actor Observable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($msg) {
            my ($observer) = @$msg;
            err::log("Observeable started, calling ($observer)");

            my @pids = map {
                scalar timeout( int(rand(9)), [ $observer, on_next => [ $_ ] ])
            } 0 .. 10;

            send_to(
                SYS, waitpids => [
                    \@pids,
                    [ $observer, on_completed => []]
                ]
            );
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $observable = spawn('Observable');
    my $observer   = spawn('Observer');

    send_to($observable, 'subscribe' => [ $observer ]);
};

# loop ...
ok loop( 20, 'main' );

done_testing;

