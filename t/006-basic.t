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

actor Printer => sub ($env, $msg) {

    #warn Dumper $env;

    match $msg, +{
        begin => sub ($body) {
            out::print('START PRINTER');
        },

        whitespace => sub ($body) {
            if ( $env->{in_string} ) {
                push $env->{str_buffer}->@* => ' ';
            }
            else {
                out::print('got whitespace');
            }
        },

        open_object => sub ($body) {
            out::print('got {');
        },
        close_object => sub ($body) {
            out::print('got }');
        },

        quote => sub ($body) {
            if ( !$env->{in_string} ) {
                $env->{in_string}++;
            }
            else {
                out::print("got string('".(join '' => $env->{str_buffer}->@*)."')");
                $env->{str_buffer}->@* = ();
                $env->{in_string}--;
            }
        },

        char => sub ($body) {
            if ( $env->{in_string} ) {
                push $env->{str_buffer}->@* => $body->[0];
            }
            else {
                err::print('??? got char (' . $body->[0] . ')');
            }
        },

        digit => sub ($body) {
            if ( $env->{in_string} ) {
                push $env->{str_buffer}->@* => $body->[0];
            }
            else {
                out::print('got num (' . $body->[0] . ')');
            }
        },

        pair => sub ($body) {
            out::print('got :');
        },

        end => sub ($body) {
            out::print('END PRINTER');
        },

        finish => sub ($body) {
            send_to( SYS, kill => [PID]);
        }
    };
};

actor Splitter => sub ($env, $msg) {

    match $msg, +{
        split => sub ($body) {
            my ($to, $string) = @$body;
            send_to( EventLoop::copy_msg( $to, split '' => $string)->@* );
            send_to( SYS, kill => [PID]);
        }
    };
};

actor Tokenizer => sub ($env, $msg) {

    match $msg, +{
        tokenize => sub ($body) {
            my ($to, @chars) = @$body;
            send_to( $to, begin          => []);
            send_to( PID, process_tokens => [ $to, @chars ]);
        },
        process_tokens => sub ($body) {
            my ($to, @chars) = @$body;

            my $char = shift @chars;
            if (defined $char) {
                if ( $char eq ' ' ) {
                    send_to($to, whitespace => []);
                }
                elsif ( $char eq '{' ) {
                    send_to($to, open_object => []);
                }
                elsif ( $char eq '}' ) {
                    send_to($to, close_object => []);
                }
                elsif ( $char eq '"' ) {
                    send_to($to, quote => []);
                }
                elsif ( $char eq ':' ) {
                    send_to($to, pair => []);
                }
                elsif ( $char =~ /\d/ ) {
                    send_to($to, digit => [ $char ]);
                }
                else {
                    send_to($to, char => [ $char ]);
                }

                send_to( PID, process_tokens => [ $to, @chars ]);
            }
            else {
                send_to( $to, end    => []);
                send_to( PID, finish => [ $to ]);
            }
        },
        finish => sub ($body) {
            my ($to) = @$body;

            send_to( $to, finish => []);
            send_to( SYS, kill   => [PID]);
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $printer   = spawn('Printer');
    my $splitter  = spawn('Splitter');
    my $tokenizer = spawn('Tokenizer');


    send_to( $splitter, split => [
        [ $tokenizer, tokenize => [ $printer ]],
        '{ "foo" : "25 bottles of baz" }',
    ]);
};

# loop ...
ok loop( 100, 'main' );

done_testing;

