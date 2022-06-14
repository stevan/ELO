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

actor MapObserver => sub ($env, $msg) {

    my $observer = $env->{observer};
    my $f        = $env->{f};

    match $msg, +{
        on_next => sub ($val) {
            out::print(PID." got val($val)");
            send_to( $observer, on_next => [ $f->($val) ]);
        },
        on_error => sub ($e) {
            err::log("MapObserver got error($e)") if DEBUG;
            send_to( $observer, on_error => [ $e ]);
        },
        on_completed => sub () {
            err::log("MapObserver completed") if DEBUG;
            send_to( $observer, on_completed => []);
            sys::kill(PID);
        }
    };
};

actor DebugObserver => sub ($env, $msg) {

    my $got = $env->{got} //= {};

    match $msg, +{
        on_next => sub ($val) {
            out::print(PID." got val($val)");
            $got->{$val}++;
        },
        on_error => sub ($e) {
            err::log("Observer got error($e)") if DEBUG;
        },
        on_completed => sub () {
            err::log("Observer completed") if DEBUG;
            err::log("Observed values: [" . (join ', ' => map { "$_/".$got->{$_} }sort { $a <=> $b } keys $got->%*) . "]") if DEBUG;
            sys::kill(PID);
        }
    };
};

actor SimpleObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($observer) {
            err::log("SimpleObserveable started, calling ($observer)") if DEBUG;
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
        subscribe => sub ($observer) {
            err::log("ComplexObserveable started, calling ($observer)") if DEBUG;

            my @pids = map {
                scalar timeout( int(rand(9)), [ $observer, on_next => [ $_ ] ])
            } 0 .. 10;

            sys::waitpids(
                \@pids,
                [ $observer, on_completed => []]
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

