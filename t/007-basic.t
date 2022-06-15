#!perl

use v5.24;
use warnings;
use experimental 'lexical_subs', 'signatures', 'postderef';

use Test::More;
use Test::Differences;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
use SAM::Msg;
use SAM::Actors;
use SAM::IO;

actor SExpParser => sub ($env, $msg) {

    my $stack = $env->{stack} //= [[]];

    #warn Dumper $stack;

    match $msg, +{
        on_next => sub ($val) {
            if ($val eq '(') {
                err::log(PID." on_sexp_start")->send if DEBUG;
                push @$stack => [];
            }
            elsif ($val eq ')') {
                err::log(PID." on_sexp_end")->send if DEBUG;
                my $child = pop @$stack;
                if ( $child && @$stack ) {
                    push $stack->[-1]->@* => $child;
                }
                elsif ( $child && !@$stack ) {
                    msg(PID, error => ["Pop-ed the final element, stack exhausted"]);
                }
                elsif ( !$child && !@$stack ) {
                    msg(PID, error => ["Stack completely exhausted"]);
                }
            }
            elsif ($val =~ /^\s$/) {
                # skip whitespace
            }
        },
        on_error => sub ($e) {
            out::print( "ERROR: $e" )->send;
            sys::kill(PID)->send;
        },
        on_completed => sub () {
            out::print( (Dumper $stack->[0]) =~ s/^\$VAR1\s/SEXP /r )->send #/
                if @$stack == 1;
            sys::kill(PID)->send;
            if (my $expected = $env->{expected}) {
                eq_or_diff( $stack, $expected, '... got the expected values in '.PID);
            }
        }
    };
};

actor DebugObserver => sub ($env, $msg) {

    my $observer = $env->{observer};
    my $got      = $env->{got} //= [];

    match $msg, +{
        on_next => sub ($val) {
            out::print(PID." got val($val)")->send;
            msg($observer, on_next => [ $val ])->send;
            push @$got => $val if $val eq '(' or $val eq ')';
        },
        on_error => sub ($e) {
            err::log(PID." got error($e)")->send if DEBUG;
            msg($observer, error => [ $e ])->send;
            sys::kill(PID)->send;
        },
        on_completed => sub () {
            err::log( (Dumper $got) =~ s/^\$VAR1\s/VALS /r )->send #/
                if @$got == 1;
            msg($observer, on_completed => [])->send;
            sys::kill(PID)->send;
            if (my $expected = $env->{expected}) {
                eq_or_diff( $got, $expected, '... got the expected values in '.PID);
            }
        }
    };
};

actor SimpleObservable => sub ($env, $msg) {

    my $string = $env->{string};

    match $msg, +{
        subscribe => sub ($observer) {
            err::log(PID." started, calling ($observer)")->send if DEBUG;

            sequence(
                (map msg( $observer, on_next => [ $_ ] ), split '' => $string),
                msg( $observer, on_completed => [] ),
                sys::kill(PID)
            )->send;
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    my $parser = proc::spawn('SExpParser', expected => [[ [[], [[]]], [], [[[]]] ]] );
    my $simple = proc::spawn('SimpleObservable', string => '(() (())) () ((()))');
    my $debug  = proc::spawn('DebugObserver',
                    observer => $parser,
                    expected => [qw[ ( ( ) ( ( ) ) ) ( ) ( ( ( ) ) ) ]]
                );

    msg($simple, subscribe => [ $debug ])->send;
};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

