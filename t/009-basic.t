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

actor TestObserver => sub ($env, $msg) {

    my $got = $env->{got} //= {};

    match $msg, +{
        on_next => sub ($val) {
            sys::out::print(PID." got val($val)");
            $got->{$val}++;
        },
        on_error => sub ($e) {
            sys::err::log(PID." got error($e)") if DEBUG;
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            sys::err::log(PID." completed") if DEBUG;
            sys::err::log(PID." observed values: [" . (join ', ' => map { "$_/".$got->{$_} }sort { $a <=> $b } keys $got->%*) . "]") if DEBUG;
            sig::kill(PID)->send;
            eq_or_diff( [ sort { $a <=> $b } keys %$got ], $env->{expected}, '... got the expected values');
            eq_or_diff( [ values %$got ], [ map 1, $env->{expected}->@* ], '... got the expected value counts (all 1)');
        }
    };
};

actor SimpleObserver => sub ($env, $msg) {

    my $on_next      = $env->{on_next}      // die 'An `on_next` value is required';
    my $on_completed = $env->{on_completed} // die 'An `on_completed` value is required';;
    my $on_error     = $env->{on_error}     // die 'An `on_error` value is required';;

    match $msg, +{
        on_next  => sub ($val) { $on_next->( $val ) },
        on_error => sub ($e) {
            $on_error->( $e );
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            $on_completed->();
            sig::kill(PID)->send;
        },
    };
};

actor MapObservable => sub ($env, $msg) {

    my $sequence = $env->{sequence} // die 'A `sequence` (Observable) is required';
    my $f        = $env->{f} // die 'A `f` (function) is required';

    match $msg, +{
        subscribe => sub ($observer) {

            my $self = PID;

            my $map = proc::spawn('SimpleObserver',
                on_next => sub ($val) {
                    msg($observer, on_next => [ $f->( $val ) ])->send;
                },
                on_error => sub ($e) {
                    msg($observer, on_error => [ $e ])->send;
                },
                on_completed => sub () {
                    msg($observer, on_completed => [])->send;
                    msg($self, on_completed => [] )->send;
                },
            );

            msg( $sequence, subscribe => [ $map ])->send;

            $env->{subscribers}++;
        },
        on_completed => sub () {
            $env->{subscribers}--;
            if ($env->{subscribers} <= 0) {
                sig::kill(PID)->send;
            }
        }
    };
};

actor SimpleObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($observer) {
            sys::err::log("SimpleObserveable started, calling ($observer)") if DEBUG;
            # A simple example
            sequence(
                (map msg( $observer, on_next => [ $_ ] ), 0 .. 10 ),
                msg( $observer, on_completed => [] ),
                msg( PID, on_completed => [] ),
            )->send;

            $env->{subscribers}++;
        },
        on_completed => sub () {
            $env->{subscribers}--;
            if ($env->{subscribers} <= 0) {
                sig::kill(PID)->send;
            }
        }
    };
};

actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

    my $simple = proc::spawn('SimpleObservable');
    my $map    = proc::spawn('MapObservable',
        sequence => $simple,
        f        => sub ($val) { $val + 100 }
    );

    my $tester     = proc::spawn('TestObserver', expected => [ 0 .. 10 ]);
    my $map_tester = proc::spawn('TestObserver', expected => [ map { $_+100 } 0 .. 10 ]);

    msg($simple, 'subscribe' => [ $tester ])->send;
    msg($map,    'subscribe' => [ $map_tester ])->send;
};

# loop ...
ok loop( 1000, 'main' ), '... the event loop exited successfully';

done_testing;

