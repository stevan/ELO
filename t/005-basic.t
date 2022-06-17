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

actor MapObserver => sub ($env, $msg) {

    my $observer = $env->{observer};
    my $f        = $env->{f};

    match $msg, +{
        on_next => sub ($val) {
            out::print(PID." got val($val)")->send;
            msg( $observer, on_next => [ $f->($val) ])->send;
        },
        on_error => sub ($e) {
            err::log("MapObserver got error($e)")->send if DEBUG;
            msg( $observer, on_error => [ $e ])->send;
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            err::log("MapObserver completed")->send if DEBUG;
            msg( $observer, on_completed => [])->send;
            sig::kill(PID)->send;
        }
    };
};

actor DebugObserver => sub ($env, $msg) {

    my $got = $env->{got} //= {};

    match $msg, +{
        on_next => sub ($val) {
            out::print(PID." got val($val)")->send;
            $got->{$val}++;
        },
        on_error => sub ($e) {
            err::log("Observer got error($e)")->send if DEBUG;
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            err::log("Observer completed")->send if DEBUG;
            err::log("Observed values: [" . (join ', ' => map { "$_/".$got->{$_} }sort { $a <=> $b } keys $got->%*) . "]")->send if DEBUG;
            sig::kill(PID)->send;
            eq_or_diff( [ sort { $a <=> $b } keys %$got ], $env->{expected}, '... got the expected values');
            eq_or_diff( [ values %$got ], [ map 1, $env->{expected}->@* ], '... got the expected value counts (all 1)');
        }
    };
};

actor SimpleObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($observer) {
            err::log("SimpleObserveable started, calling ($observer)")->send if DEBUG;
            # A simple example
            sequence(
                (map msg( $observer, on_next => [ $_ ] ), 0 .. 10),
                msg( $observer, on_completed => [] ),
                sig::kill(PID)
            )->send;
        },
    };
};

actor PidExitObserver => sub ($env, $msg) {

    my $pids         = $env->{pids}         // die 'PidExitObserver requires `pids`';
    my $on_completed = $env->{on_completed} // die 'PidExitObserver requires `on_completed`';

    match $msg, +{
        on_next => sub ($pid) {
            @$pids = grep $_ ne $pid, @$pids;
            if (!@$pids) {
                msg(PID, on_completed => [])->send;
            }
        },
        on_completed => sub () {
            my ($caller, $callback) = @$on_completed;
            $callback->send_from($caller);
            sig::kill(PID)->send;
        }
    }
};

actor PidExitObservable => sub ($env, $msg) {

    match $msg, +{
        waitpids => sub ($pids, $callback) {

            my $observer = proc::spawn('PidExitObserver',
                pids         => $pids,
                on_completed => [
                    CALLER,
                    parallel( $callback, sig::kill(PID) )
                ]
            );

            foreach my $pid ( @$pids ) {
                #warn PID." WATCHING PID: $pid";
                sys::waitpid( $pid, msg($observer, on_next => [ $pid ]) )->send;
            }
        },
    };
};

actor ComplexObservable => sub ($env, $msg) {

    match $msg, +{
        subscribe => sub ($observer) {
            err::log("ComplexObserveable started, calling ($observer)") if DEBUG;

            my @pids = map {
                timeout( int(rand(9)), msg( $observer, on_next => [ $_ ] ))->send->pid
            } 0 .. 10;

            msg(
                proc::spawn('PidExitObservable'),
                waitpids => [
                    \@pids,
                    parallel(
                        msg( $observer, on_completed => []),
                        sig::kill(PID)
                    )
                ]
            )->send;
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

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

