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
            eq_or_diff($pids, [], '... no more pids left');
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
                sig::waitpid( $pid, msg($observer, on_next => [ $pid ]) )->send;
            }
        },
    };
};

actor BusySpinner => sub ($env, $msg) {

    $env->{until} // die 'BusySpinner requires `until`';

    match $msg, +{
        next => sub () {
            sys::err::log(PID." counting down until ".$env->{until}) if DEBUG;
            $env->{until}--;
            if ($env->{until} <= 0) {
                msg(PID, finish => [])->send;
            }
            else {
                msg(PID, next => [])->send;
            }
        },
        finish => sub () {
            sys::err::log(PID." finished countdown") if DEBUG;
            sig::kill(PID)->send;
        }
    }
};


actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

    my @spinners = map {
        proc::spawn('BusySpinner', until => int(rand(25)))
    } 0 .. 10;

    msg($_, next => [])->send foreach @spinners;

    msg(
        proc::spawn('PidExitObservable'),
        waitpids => [
            \@spinners,
            parallel(
                out::print("ALL DONE!"),
            )
        ]
    )->send;

};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

