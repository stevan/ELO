#!perl

use v5.24;
use warnings;
use experimental 'lexical_subs', 'signatures', 'postderef';

use Test::More;
use Test::Differences;
use Test::ELO;

use List::Util 'first';
use Data::Dumper;

use ELO;

actor SExpParser => sub ($env, $msg) {

    my $stack = $env->{stack} //= [[]];

    #warn Dumper $stack;

    match $msg, +{
        on_next => sub ($val) {
            if ($val eq '(') {
                sys::err::log(PID." on_sexp_start") if DEBUG;
                push @$stack => [];
            }
            elsif ($val eq ')') {
                sys::err::log(PID." on_sexp_end") if DEBUG;
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
            sys::out::print( "ERROR: $e" );
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            sys::out::print( (Dumper $stack->[0]) =~ s/^\$VAR1\s/SEXP /r ) #/
                if @$stack == 1;
            sig::kill(PID)->send;
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
            sys::out::print(PID." got val($val)");
            msg($observer, on_next => [ $val ])->send;
            push @$got => $val if $val eq '(' or $val eq ')';
        },
        on_error => sub ($e) {
            sys::err::log(PID." got error($e)") if DEBUG;
            msg($observer, error => [ $e ])->send;
            sig::kill(PID)->send;
        },
        on_completed => sub () {
            sys::err::log( (Dumper $got) =~ s/^\$VAR1\s/VALS /r ) #/
                if @$got == 1;
            msg($observer, on_completed => [])->send;
            sig::kill(PID)->send;
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
            sys::err::log(PID." started, calling ($observer)") if DEBUG;

            sequence(
                (map msg( $observer, on_next => [ $_ ] ), split '' => $string),
                msg( $observer, on_completed => [] ),
                sig::kill(PID)
            )->send;
        },
    };
};

actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

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

