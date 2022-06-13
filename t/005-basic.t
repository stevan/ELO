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

actor MapObserver => sub ($env, $msg) {

    my $observer = $env->{observer};
    my $f        = $env->{f};

    match $msg, +{
        on_next => sub ($msg) {
            my ($val) = @$msg;
            out::print("MapObserver got val($val)");
            send_to( $observer, on_next => [ $f->($val) ]);
        },
        on_error => sub ($msg) {
            my ($e) = @$msg;
            err::log("MapObserver got error($e)");
            send_to( $observer, on_error => [ $e ]);
        },
        on_completed => sub ($msg) {
            err::log("MapObserver completed");
            send_to( $observer, on_completed => []);
            send_to( SYS, kill => [PID] );
        }
    };
};

actor DebugObserver => sub ($env, $msg) {

    my $got = $env->{got} //= {};

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
            err::log("Observed values: [" . (join ', ' => map { "$_/".$got->{$_} }sort { $a <=> $b } keys $got->%*) . "]");
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

actor ComplexObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($msg) {
            my ($observer) = @$msg;
            err::log("ComplexObserveable started, calling ($observer)");

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

    my $complex = spawn('ComplexObservable');
    my $simple  = spawn('SimpleObservable');

    my $debug   = spawn('DebugObserver');
    my $map     = spawn('MapObserver',
        observer => spawn('DebugObserver'),
        f        => sub ($x) { $x + 100 },
    );

    send_to($complex, 'subscribe' => [ $map ]);
    send_to($simple,  'subscribe' => [ $debug ]);
};

# loop ...
ok loop( 20, 'main' );

done_testing;

