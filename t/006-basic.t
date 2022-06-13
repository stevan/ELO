#!perl

use v5.24;
use warnings;
use experimental 'lexical_subs', 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

use EventLoop;
use EventLoop::Actors;
use EventLoop::IO;

use constant DEBUG_TOKENIZER => 1;
use constant DEBUG_DECODER   => 1;

actor Splitter => sub ($env, $msg) {

    match $msg, +{
        split => sub ($body) {
            my ($return_pid, $string) = @$body;
            send_to( EventLoop::copy_msg( $return_pid, split '' => $string)->@* );
            send_to( SYS, kill => [PID]);
        }
    };
};

actor Decoder => sub ($env, $msg) {

    my $stack = $env->{stack} //= [];

    err::log(Dumper { stack => $stack }) if DEBUG_DECODER >= 2;

    match $msg, +{
        start_object => sub ($body) {
            err::log("START OBJECT") if DEBUG_DECODER;
            push @$stack => {};
        },

        end_object => sub ($body) {
            err::log("END OBJECT") if DEBUG_DECODER;
        },

        start_property => sub ($body) {
            err::log("START PROPERTY") if DEBUG_DECODER;
        },

        end_property   => sub ($body) {
            my $value = pop @$stack;
            my $key   = pop @$stack;
            err::log("ADD PROPERTY $key => $value") if DEBUG_DECODER;
            $stack->[-1]->{$key} = $value;
            err::log("END PROPERTY") if DEBUG_DECODER;
        },

        start_array => sub ($body) { err::log("START ARRAY") if DEBUG_DECODER; },
        end_array   => sub ($body) { err::log("END ARRAY") if DEBUG_DECODER; },

        start_item => sub ($body) {
            err::log("START ITEM") if DEBUG_DECODER;
        },
        end_item   => sub ($body) {
            err::log("END ITEM") if DEBUG_DECODER;
        },

        add_string => sub ($body) {
            err::log("ADD STRING (@$body)") if DEBUG_DECODER;
            push @$stack => $body->[0];
        },
        add_number => sub ($body) {
            err::log("ADD NUMBER (@$body)") if DEBUG_DECODER;
            push @$stack => $body->[0];
        },

        add_true   => sub ($body) { err::log("ADD TRUE") if DEBUG_DECODER; },
        add_false  => sub ($body) { err::log("ADD FALSE") if DEBUG_DECODER; },
        add_null   => sub ($body) { err::log("ADD NULL") if DEBUG_DECODER; },

        error      => sub ($body) { err::log("ERROR!!!! (@$body)") if DEBUG_DECODER; },
        finish     => sub ($body) {
            out::print(Dumper $stack->[0]);
            send_to( SYS, kill => [PID]);
        },
    };
};

actor Tokenizer => sub ($env, $msg) {

    my sub stip_whitespace ($chars) {
        my $char = shift @$chars;
        while (defined $char && $char =~ /^\s$/) {
            $char = shift @$chars;
        }
        return $char, @$chars;
    }

    match $msg, +{
        tokenize => sub ($body) {
            my ($observer, $JSON) = @$body;
            send_to(
                spawn('Splitter'),
                split => [
                    [ PID, process_tokens => [ ['process_tokens'] => $observer ]],
                    $JSON
                ]
            );
        },
        process_tokens => sub ($body) {
            my $char;
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter process_tokens (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {

                if ( $char eq '{' ) {
                    send_to(PID, start_object => [ $callstack, $observer, @chars ]);
                }
                elsif ( $char eq '"' ) {
                    # drop the quote ...
                    send_to(PID, collect_string => [ $callstack, $observer, @chars ]);
                }
                elsif ( $char =~ /^\d$/ ) {
                    # but keep the number ...
                    send_to(PID, collect_number => [ $callstack, $observer, ($char, @chars) ]);
                }

            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $observer ]);
            }
        },

        ## ... complex ...
        start_object => sub ($body) {
            my $char;
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter start_object (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                send_to($observer, start_object => []);

                if ( $char eq '}' ) {
                    send_to(PID, end_object => [ $callstack, $observer, @chars ]);
                }
                else {
                    push @$callstack => 'process_object';
                    send_to(PID, start_property => [ $callstack, $observer, $char, @chars ]);
                }
            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $observer ]);
            }
        },
        process_object => sub ($body) {
            my $char;
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter process_object (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                # process tokens
                if ( $char eq '}' ) {
                    send_to(PID, end_object => [ $callstack, $observer, @chars ]);
                }
                elsif ( $char eq ',' ) {
                    push @$callstack => 'process_object';
                    send_to(PID, start_property => [ $callstack, $observer, @chars ]);
                }
            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $observer ]);
            }
        },
        end_object => sub ($body) {
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter end_object (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$callstack;

            send_to($observer, end_object   => []);
            send_to(PID, $return_call, [ $callstack, $observer, @chars ]);
        },

        # ...
        start_property => sub ($body) {
            my $char;
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter start_property (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq '"' ) {
                    send_to($observer, start_property => []);
                    push @$callstack => 'process_property';
                    send_to(PID, collect_string => [ $callstack, $observer, @chars ]);
                }
                else {
                    die "Property must start with a quoted string";
                }
            }
            else {
                die "Unterminated object property";
            }
        },
        process_property => sub ($body) {
            my $char;
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter process_property (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq ':' ) {
                    send_to(PID, start_item => [ $callstack, $observer, @chars ]);
                }
                else {
                    die "Expected : got $char";
                }
            }
            else {
                die "Unterminated object property";
            }
        },
        end_property => sub ($body) {
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter end_property (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$callstack;

            send_to($observer, end_property => []);
            send_to(PID, process_object => [ $callstack, $observer, @chars ]);
        },


        start_item => sub ($body) {
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter start_item (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            send_to($observer, start_item => []);
            push @$callstack => 'end_item';
            send_to(PID, process_tokens => [ $callstack, $observer, @chars ]);
        },
        end_item => sub ($body) {
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter end_item (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            send_to($observer, end_item => []);
            send_to(PID, end_property => [ $callstack, $observer, @chars ]);
        },


        ## ... literals ...
        collect_string => sub ($body) {
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter collect_string (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char ne '"') {
                push @buffer => $char;
                $char = shift @chars;
                die "unterminated string" if not defined $char;
            }

            send_to($observer, add_string => [ join '' => @buffer ]);

            my $return_call = pop @$callstack;

            send_to( PID, $return_call, [ $callstack, $observer, @chars ]);
        },
        collect_number => sub ($body) {
            my ($callstack, $observer, @chars) = @$body;

            err::log("Enter collect_number (@$callstack) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char =~ /^\d$/) {
                push @buffer => $char;
                $char = shift @chars;
                die "unterminated numeric" if not defined $char;
            }

            send_to($observer, add_number => [ (join '' => @buffer) + 0 ]);

            my $return_call = pop @$callstack;

            send_to( PID, $return_call, [ $callstack, $observer, ($char, @chars) ]);
        },

        # ...
        finish => sub ($body) {
            my ($observer) = @$body;

            send_to( $observer, finish => []);
            send_to( SYS, kill   => [PID]);
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");


    send_to(spawn('Tokenizer'), tokenize => [
        spawn('Decoder'),
        '{ "foo" : { "bar" : 10, "baz" : { "gorch" : 100 } } }'
    ]);

    send_to(spawn('Tokenizer'), tokenize => [
        spawn('Decoder'),
        '{ "bling" : { "baz" : {}, "boo" : 10, "foo" : { "gorch" : 100 } }, "foo" : 500 }'
    ]);

};

# loop ...
ok loop( 100, 'main' );

done_testing;

