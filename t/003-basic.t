#!perl

use v5.24;
use warnings;
use experimental 'lexical_subs', 'signatures', 'postderef';

use Test::More;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
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
            sys::kill(PID);
        },
    };
};

actor Decoder => sub ($env, $msg) {

    my $stack = $env->{stack} //= [[]];

    err::log(Dumper $env) if DEBUG_DECODER >= 2;

    match $msg, +{
        start_parens => sub () {
            err::log("START PARENS") if DEBUG_DECODER;
            push @$stack => [];
        },
        end_parens => sub () {
            err::log("END PARENS") if DEBUG_DECODER;
            my $top = pop @$stack;
            push $stack->[-1]->@* => $top;
        },

        error => sub ($error) {
            out::print("ERROR!!!! ($error)");
            @$stack = ();
        },
        finish     => sub () {
            out::print( (Dumper $stack->[0]) =~ s/^\$VAR1\s/PARENS /r ) #/
                if @$stack == 1;
            sys::kill(PID);
        },
    };
};

actor Tokenizer => sub ($env, $msg) {

    my $stack = $env->{stack} //= [];

    my sub sync_next ($producer, $observer, $action) {
        sync(
            msg[ $producer, next => []],
            msg[ PID, $action => [$producer, $observer]],
        );
    }

    match $msg, +{
        finish => sub ($producer, $observer) {
            err::log("Finishing") if DEBUG_TOKENIZER;
            send_to( $producer, finish => []);
            send_to( $observer, finish => []);
            sys::kill(PID);
        },
        error => sub ($producer, $observer, $error) {
            @$stack = ();
            err::log("Got Error ($error)");
            send_to(PID, finish => [$producer, $observer]);
        },
        process_tokens => sub ($producer, $observer) {
            err::log("process tokens (@$stack)") if DEBUG_TOKENIZER;

            sync_next($producer, $observer, 'process_token');
        },
        process_token => sub ($producer, $observer, $token) {
            err::log("process token (@$stack)") if DEBUG_TOKENIZER;

            if ($token eq '(') {
                send_to( PID, open_parens => [ $producer, $observer ] );
            }
            elsif ($token eq EMPTY) {
                send_to( PID, finish => [ $producer, $observer ] );
            }
            else {
                sync_next($producer, $observer, 'process_token');
            }
        },

        # ..
        open_parens => sub ($producer, $observer) {
            err::log("// open parens (@$stack)") if DEBUG_TOKENIZER;
            push @$stack => 'process_parens';
            send_to($observer, 'start_parens' => []);
            sync_next($producer, $observer, 'process_parens');
        },
        process_parens => sub ($producer, $observer, $token) {
            err::log("process parens (@$stack) with `$token`") if DEBUG_TOKENIZER;
            if ($token eq '(') {
                send_to( PID, open_parens => [ $producer, $observer ] );
            }
            elsif ($token eq ')') {
                if ( @$stack ) {
                    send_to( PID, close_parens => [ $producer, $observer ] );
                }
                else {
                    send_to( PID, error => [$producer, $observer, "Illegal close paren"] );
                }
            }
            elsif ($token eq EMPTY) {
                if ( @$stack ) {
                    send_to( PID, error => [$producer, $observer, "Ran out of chars, but still had stack (@$stack)"] );
                }
                else {
                    send_to( PID, finish => [ $producer, $observer ] );
                }
            }
            else {
                err::log("Loop process parens (@$stack) with `$token`") if DEBUG_TOKENIZER;
                sync_next($producer, $observer, 'process_parens');
            }
        },
        close_parens => sub ($producer, $observer) {
            err::log("\\\\ close parens (@$stack)") if DEBUG_TOKENIZER;
            send_to($observer, 'end_parens' => []);
            my $frame = pop @$stack;
            sync_next($producer, $observer, $frame);
        },

    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    send_to(
        spawn('Tokenizer'),
        process_tokens => [
            spawn('CharacterStream', string => '(() (() ()) ())' ),
            spawn('Decoder'),
        ]
    );

    send_to(
        spawn('Tokenizer'),
        process_tokens => [
            spawn('CharacterStream', string => '((((()))))' ),
            spawn('Decoder'),
        ]
    );

    send_to(
        spawn('Tokenizer'),
        process_tokens => [
            spawn('CharacterStream', string => '(() ())' ),
            spawn('Decoder'),
        ]
    );

    send_to(
        spawn('Tokenizer'),
        process_tokens => [
            spawn('CharacterStream', string => '(() ()' ),
            spawn('Decoder'),
        ]
    );

};

# loop ...
ok loop( 100, 'main' );

done_testing;

