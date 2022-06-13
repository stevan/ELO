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

use constant DEBUG_TOKENIZER => DEBUG >= 2 ? DEBUG - 1 : 0;
use constant DEBUG_DECODER   => DEBUG >= 2 ? DEBUG - 1 : 0;

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

        error => sub ($body) {
            out::print("ERROR!!!! (@$body)");
            @$stack = ();
        },
        finish     => sub ($body) {
            out::print( (Dumper $stack->[0]) =~ s/^\$VAR1\s/JSON /r ) #/
                if @$stack == 1;
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

    my $stack = $env->{stack} //= [];

    err::log(Dumper { stack => $stack }) if DEBUG_TOKENIZER >= 2;

    match $msg, +{
        tokenize => sub ($body) {
            my ($observer, $JSON) = @$body;
            push @$stack => 'process_tokens';
            send_to(
                spawn('Splitter'),
                split => [
                    [ PID, process_tokens => [ $observer ]],
                    $JSON
                ]
            );
        },
        process_tokens => sub ($body) {
            my $char;
            my ($observer, @chars) = @$body;

            err::log("Enter process_tokens (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {

                if ( $char eq '{' ) {
                    send_to(PID, start_object => [ $observer, @chars ]);
                }
                elsif ( $char eq '"' ) {
                    # drop the quote ...
                    send_to(PID, collect_string => [ $observer, @chars ]);
                }
                elsif ( $char =~ /^\d$/ ) {
                    # but keep the number ...
                    send_to(PID, collect_number => [ $observer, ($char, @chars) ]);
                }
                else {
                    send_to(PID, error => [ $observer, "Unexpected token `$char` in process_tokens, expected `{`, `\"`, or a digit"]);
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
            my ($observer, @chars) = @$body;

            err::log("Enter start_object (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                send_to($observer, start_object => []);

                if ( $char eq '}' ) {
                    send_to(PID, end_object => [ $observer, @chars ]);
                }
                else {
                    push @$stack => 'process_object';
                    send_to(PID, start_property => [ $observer, $char, @chars ]);
                }
            }
            else {
                send_to(PID, error => [ $observer, "Ran out of tokens in start_object"]);
            }
        },
        process_object => sub ($body) {
            my $char;
            my ($observer, @chars) = @$body;

            err::log("Enter process_object (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                # process tokens
                if ( $char eq '}' ) {
                    send_to(PID, end_object => [ $observer, @chars ]);
                }
                elsif ( $char eq ',' ) {
                    push @$stack => 'process_object';
                    send_to(PID, start_property => [ $observer, @chars ]);
                }
                else {
                    send_to(PID, error => [ $observer, "Unexpected token `$char` in process_object, expected `}` or `,`"]);
                }
            }
            else {
                send_to(PID, error => [ $observer, "Ran out of tokens in process_object"]);
            }
        },
        end_object => sub ($body) {
            my ($observer, @chars) = @$body;

            err::log("Enter end_object (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$stack;

            send_to($observer, end_object   => []);
            send_to(PID, $return_call, [ $observer, @chars ]);
        },

        # ...
        start_property => sub ($body) {
            my $char;
            my ($observer, @chars) = @$body;

            err::log("Enter start_property (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq '"' ) {
                    send_to($observer, start_property => []);
                    push @$stack => 'process_property';
                    send_to(PID, collect_string => [ $observer, @chars ]);
                }
                else {
                    send_to(PID, error => [ $observer, "Unexpected token `$char` in start_property, property must start with a quote"]);
                }
            }
            else {
                send_to(PID, error => [ $observer, "Unterminated object property : ran out of tokens in start_property"]);
            }
        },
        process_property => sub ($body) {
            my $char;
            my ($observer, @chars) = @$body;

            err::log("Enter process_property (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq ':' ) {
                    send_to(PID, start_item => [ $observer, @chars ]);
                }
                else {
                    send_to(PID, error => [ $observer, "Unexpected token `$char` in process_property, expected `:`"]);
                }
            }
            else {
                send_to(PID, error => [ $observer, "Unterminated object property : ran out of tokens in process_property"]);
            }
        },
        end_property => sub ($body) {
            my ($observer, @chars) = @$body;

            err::log("Enter end_property (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$stack;

            send_to($observer, end_property => []);
            send_to(PID, process_object => [ $observer, @chars ]);
        },


        start_item => sub ($body) {
            my ($observer, @chars) = @$body;

            err::log("Enter start_item (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            send_to($observer, start_item => []);
            push @$stack => 'end_item';
            send_to(PID, process_tokens => [ $observer, @chars ]);
        },
        end_item => sub ($body) {
            my ($observer, @chars) = @$body;

            err::log("Enter end_item (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            send_to($observer, end_item => []);
            send_to(PID, end_property => [ $observer, @chars ]);
        },


        ## ... literals ...
        collect_string => sub ($body) {
            my ($observer, @chars) = @$body;

            err::log("Enter collect_string (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char ne '"') {
                push @buffer => $char;
                $char = shift @chars;
                if (not defined $char) {
                    send_to(PID, error => [ $observer, "Unterminated string : ran out of tokens in collect_string"]);
                    return; # jump outta here
                }
            }

            send_to($observer, add_string => [ join '' => @buffer ]);

            my $return_call = pop @$stack;

            send_to( PID, $return_call, [ $observer, @chars ]);
        },
        collect_number => sub ($body) {
            my ($observer, @chars) = @$body;

            err::log("Enter collect_number (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char =~ /^\d$/) {
                push @buffer => $char;
                $char = shift @chars;
                if (not defined $char) {
                    send_to(PID, error => [ $observer, "Unterminated numeric : ran out of tokens in collect_string"]);
                    return; # jump outta here
                }
            }

            send_to($observer, add_number => [ (join '' => @buffer) + 0 ]);

            my $return_call = pop @$stack;

            send_to( PID, $return_call, [ $observer, ($char, @chars) ]);
        },

        # ...
        error => sub ($body) {
            my ($observer, $error) = @$body;

            err::log("Enter error (@$stack)") if DEBUG_TOKENIZER;

            @$stack = (); # clear stack ...

            send_to( $observer, error => [ $error ]);
            send_to( PID, finish => [ $observer ]);
        },
        finish => sub ($body) {
            my ($observer) = @$body;

            err::log("Enter finish (@$stack)") if DEBUG_TOKENIZER;

            send_to( $observer, finish => []);
            send_to( SYS, kill => [PID]);
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    send_to(spawn('Tokenizer'), tokenize => [
        spawn('Decoder'),
        '{ "foo" : 10 :'
    ]);

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

