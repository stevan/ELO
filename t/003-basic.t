#!perl

use v5.24;
use warnings;
use experimental 'lexical_subs', 'signatures', 'postderef';

use Test::More;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
use SAM::Msg;
use SAM::Actors;
use SAM::IO;

use constant EMPTY => '!!EMPTY!!';

use constant DEBUG_TOKENIZER => DEBUG >= 2 ? DEBUG - 1 : 0;
use constant DEBUG_DECODER   => DEBUG >= 2 ? DEBUG - 1 : 0;

actor CharacterStream => sub ($env, $msg) {

    my $chars = $env->{chars} //= [ split '' => $env->{string} ];

    match $msg, +{
        next => sub () {
            return_to shift @$chars // EMPTY;
        },
        finish => sub () {
            sig::kill(PID)->send;
        },
    };
};

actor Decoder => sub ($env, $msg) {

    # XXX - add an expected value in the ENV
    # that can be used to test it ...

    my $stack = $env->{stack} //= [[]];

    err::log(Dumper $env)->send if DEBUG_DECODER >= 2;

    match $msg, +{
        start_parens => sub () {
            err::log("START PARENS")->send if DEBUG_DECODER;
            push @$stack => [];
        },
        end_parens => sub () {
            err::log("END PARENS")->send if DEBUG_DECODER;
            my $top = pop @$stack;
            push $stack->[-1]->@* => $top;
        },

        error => sub ($error) {
            out::print("ERROR!!!! ($error)")->send;
            @$stack = ();
        },
        finish     => sub () {
            out::print( (Dumper $stack->[0]) =~ s/^\$VAR1\s/PARENS /r )->send #/
                if @$stack == 1;
            sig::kill(PID)->send;
        },
    };
};

actor Tokenizer => sub ($env, $msg) {

    my $stack = $env->{stack} //= [];

    my sub sync_next ($producer, $observer, $action) {
        sync(
            msg( $producer, next => [] ),
            msg( PID, $action => [$producer, $observer] ),
        );
    }

    match $msg, +{
        finish => sub ($producer, $observer) {
            err::log("Finishing")->send if DEBUG_TOKENIZER;
            msg( $producer, finish => [])->send;
            msg( $observer, finish => [])->send;
            sig::kill(PID)->send;
        },
        error => sub ($producer, $observer, $error) {
            @$stack = ();
            err::log("Got Error ($error)")->send;
            msg(PID, finish => [$producer, $observer])->send;
        },
        process_tokens => sub ($producer, $observer) {
            err::log("process tokens (@$stack)")->send if DEBUG_TOKENIZER;

            sync_next($producer, $observer, 'process_token')->send;
        },
        process_token => sub ($producer, $observer, $token) {
            err::log("process token (@$stack)")->send if DEBUG_TOKENIZER;

            if ($token eq '(') {
                msg( PID, open_parens => [ $producer, $observer ] )->send;
            }
            elsif ($token eq EMPTY) {
                msg( PID, finish => [ $producer, $observer ] )->send;
            }
            else {
                sync_next($producer, $observer, 'process_token')->send;
            }
        },

        # ..
        open_parens => sub ($producer, $observer) {
            err::log("// open parens (@$stack)")->send if DEBUG_TOKENIZER;
            push @$stack => 'process_parens';
            msg($observer, 'start_parens' => [])->send;
            sync_next($producer, $observer, 'process_parens')->send;
        },
        process_parens => sub ($producer, $observer, $token) {
            err::log("process parens (@$stack) with `$token`")->send if DEBUG_TOKENIZER;
            if ($token eq '(') {
                msg( PID, open_parens => [ $producer, $observer ] )->send;
            }
            elsif ($token eq ')') {
                if ( @$stack ) {
                    msg( PID, close_parens => [ $producer, $observer ] )->send;
                }
                else {
                    msg( PID, error => [$producer, $observer, "Illegal close paren"] )->send;
                }
            }
            elsif ($token eq EMPTY) {
                if ( @$stack ) {
                    msg( PID, error => [$producer, $observer, "Ran out of chars, but still had stack (@$stack)"] )->send;
                }
                else {
                    msg( PID, finish => [ $producer, $observer ] )->send;
                }
            }
            else {
                err::log("Loop process parens (@$stack) with `$token`")->send if DEBUG_TOKENIZER;
                sync_next($producer, $observer, 'process_parens')->send;
            }
        },
        close_parens => sub ($producer, $observer) {
            err::log("\\\\ close parens (@$stack)")->send if DEBUG_TOKENIZER;
            msg($observer, 'end_parens' => [])->send;
            my $frame = pop @$stack;
            sync_next($producer, $observer, $frame)->send;
        },

    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    msg(
        proc::spawn('Tokenizer'),
        process_tokens => [
            proc::spawn('CharacterStream', string => '(() (() ()) ())' ),
            proc::spawn('Decoder'),
        ]
    )->send;

    msg(
        proc::spawn('Tokenizer'),
        process_tokens => [
            proc::spawn('CharacterStream', string => '((((()))))' ),
            proc::spawn('Decoder'),
        ]
    )->send;

    msg(
        proc::spawn('Tokenizer'),
        process_tokens => [
            proc::spawn('CharacterStream', string => '(() ())' ),
            proc::spawn('Decoder'),
        ]
    )->send;

    msg(
        proc::spawn('Tokenizer'),
        process_tokens => [
            proc::spawn('CharacterStream', string => '(() ()' ),
            proc::spawn('Decoder'),
        ]
    )->send;

};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

