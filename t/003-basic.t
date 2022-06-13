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

actor CharacterStream => sub ($env, $msg) {

    my $chars = $env->{chars} //= [ split '' => $env->{string} ];

    match $msg, +{
        next => sub ($body) {
            return_to shift @$chars;
        }
    };
};

actor Tokenizer => sub ($env, $msg) {

    my $stack = $env->{stack} //= [];

    match $msg, +{
        process_tokens => sub ($body) {
            my ($producer) = @$body;
            out::print("process tokens (@$stack)");

            sync(
                [ $producer, next => []],
                [ PID, process_token => [$producer]],
            );
        },
        process_token => sub ($body) {
            my ($producer, $token) = @$body;
            out::print("process token (@$stack)");

            if ($token eq '(') {
                send_to( PID, open_parens => [ $producer ] );
            }
            else {
                sync(
                    [ $producer, next => []],
                    [ PID, process_token => [$producer]],
                );
            }
        },

        # ..
        open_parens => sub ($body) {
            my ($producer) = @$body;
            out::print("open parens (@$stack)");
            push @$stack => 'process_parens';
            sync(
                [ $producer, next => []],
                [ PID, process_parens => [$producer]],
            );
        },
        process_parens => sub ($body) {
            my ($producer, $token) = @$body;
            out::print("process parens (@$stack) with `$token`");
            if ($token eq '(') {
                send_to( PID, open_parens => [ $producer ] );
            }
            elsif ($token eq ')') {
                send_to( PID, close_parens => [ $producer ] );
            }
            else {
                out::print("Loop process parens (@$stack) with `$token`");
                sync(
                    [ $producer, next => []],
                    [ PID, process_parens => [$producer]],
                );
            }
        },
        close_parens => sub ($body) {
            my ($producer) = @$body;
            out::print("close parens (@$stack)");
            my $frame = pop @$stack;
            sync(
                [ $producer, next => []],
                [ PID, $frame => [$producer]],
            );
        },

    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $chars = spawn('CharacterStream', string => '(())' );
    my $tokenizer = spawn('Tokenizer');

    send_to($tokenizer, process_tokens => [ $chars ] );

};

# loop ...
ok loop( 100, 'main' );

done_testing;

