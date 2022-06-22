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

actor MapObserver => sub ($env, $msg) {

    my $observer = $env->{observer};
    my $f        = $env->{f};

    match $msg, +{
        on_next => sub ($val) {
            sys::out::print(PID." got val($val)");
            msg( $observer, on_next => [ $f->($val) ])->send;
        },
        on_error => sub ($e) {
            sys::err::log("MapObserver got error($e)") if DEBUG;
            msg( $observer, on_error => [ $e ])->send;
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            sys::err::log("MapObserver completed") if DEBUG;
            msg( $observer, on_completed => [])->send;
            sig::kill(PID)->send;
        }
    };
};

actor DebugObserver => sub ($env, $msg) {

    my $got = $env->{got} //= {};

    match $msg, +{
        on_next => sub ($val) {
            sys::out::print(PID." got val($val)");
            $got->{$val}++;
        },
        on_error => sub ($e) {
            sys::err::log("Observer got error($e)") if DEBUG;
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            sys::err::log("Observer completed") if DEBUG;
            sys::err::log("Observed values: [" . (join ', ' => map { "$_/".$got->{$_} }sort { $a <=> $b } keys $got->%*) . "]") if DEBUG;
            sig::kill(PID)->send;
            eq_or_diff( [ sort { $a <=> $b } keys %$got ], $env->{expected}, '... got the expected values');
            eq_or_diff( [ values %$got ], [ map 1, $env->{expected}->@* ], '... got the expected value counts (all 1)');
        }
    };
};

actor SimpleObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($observer) {
            sys::err::log("SimpleObserveable started, calling ($observer)") if DEBUG;
            # A simple example
            sequence(
                (map msg( $observer, on_next => [ $_ ] ), 0 .. 10),
                msg( $observer, on_completed => [] ),
                sig::kill(PID)
            )->send;
        },
    };
};

actor ComplexObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($observer) {
            sys::err::log("ComplexObserveable started, calling ($observer)") if DEBUG;

            map {
                sig::timer( int(rand(9)), msg( $observer, on_next => [ $_ ] ))->send
            } 0 .. 10;

            sig::timer( 10, parallel(
                msg( $observer, on_completed => []),
                sig::kill(PID)
            ))->send;
        },
    };
};

actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

    my $complex = proc::spawn('ComplexObservable');
    my $simple  = proc::spawn('SimpleObservable');

    my $debug   = proc::spawn('DebugObserver', expected => [ 0 .. 10 ]);
    my $map     = proc::spawn('MapObserver',
        observer => proc::spawn('DebugObserver', , expected => [ map $_+100, 0 .. 10 ]),
        f        => sub ($x) { $x + 100 },
    );

    msg($complex, 'subscribe' => [ $map ])->send;
    msg($simple,  'subscribe' => [ $debug ])->send;
};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

