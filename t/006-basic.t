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
            my ($obbserver, $JSON) = @$body;
            send_to(
                spawn('Splitter'),
                split => [
                    [ PID, process_tokens => [ ['process_tokens'] => $obbserver ]],
                    $JSON
                ]
            );
        },
        process_tokens => sub ($body) {
            my $char;
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter process_tokens (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {

                if ( $char eq '{' ) {
                    send_to(PID, start_object => [ $return_to => $obbserver, @chars ]);
                }
                elsif ( $char eq '"' ) {
                    # drop the quote ...
                    send_to(PID, collect_string => [ $return_to => $obbserver, @chars ]);
                }
                elsif ( $char =~ /^\d$/ ) {
                    # but keep the number ...
                    send_to(PID, collect_number => [ $return_to => $obbserver, ($char, @chars) ]);
                }

            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $obbserver ]);
            }
        },

        ## ... complex ...
        start_object => sub ($body) {
            my $char;
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter start_object (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                send_to($obbserver, start_object => []);

                if ( $char eq '}' ) {
                    send_to(PID, end_object => [ $return_to, $obbserver, @chars ]);
                }
                else {
                    push @$return_to => 'process_object';
                    send_to(PID, start_property => [ $return_to, $obbserver, $char, @chars ]);
                }
            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $obbserver ]);
            }
        },
        process_object => sub ($body) {
            my $char;
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter process_object (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                # process tokens
                if ( $char eq '}' ) {
                    send_to(PID, end_object => [ $return_to, $obbserver, @chars ]);
                }
                elsif ( $char eq ',' ) {
                    push @$return_to => 'process_object';
                    send_to(PID, start_property => [ $return_to, $obbserver, @chars ]);
                }
            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $obbserver ]);
            }
        },
        end_object => sub ($body) {
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter end_object (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$return_to;

            send_to($obbserver, end_object   => []);
            send_to(PID, $return_call => [ $return_to, $obbserver, @chars ]);
        },

        # ...
        start_property => sub ($body) {
            my $char;
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter start_property (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq '"' ) {
                    send_to($obbserver, start_property => []);
                    push @$return_to => 'process_property';
                    send_to(PID, collect_string => [ $return_to => $obbserver, @chars ]);
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
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter process_property (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq ':' ) {
                    send_to(PID, start_item => [ $return_to, $obbserver, @chars ]);
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
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter end_property (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$return_to;

            send_to($obbserver, end_property => []);
            send_to(PID, process_object => [ $return_to, $obbserver, @chars ]);
        },


        start_item => sub ($body) {
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter start_item (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            send_to($obbserver, start_item => []);
            push @$return_to => 'end_item';
            send_to(PID, process_tokens => [ $return_to, $obbserver, @chars ]);
        },
        end_item => sub ($body) {
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter end_item (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            send_to($obbserver, end_item => []);
            send_to(PID, end_property => [ $return_to, $obbserver, @chars ]);
        },


        ## ... literals ...
        collect_string => sub ($body) {
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter collect_string (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char ne '"') {
                push @buffer => $char;
                $char = shift @chars;
                die "unterminated string" if not defined $char;
            }

            send_to($obbserver, add_string => [ join '' => @buffer ]);

            my $return_call = pop @$return_to;

            send_to( PID, $return_call => [ $return_to, $obbserver, @chars ]);
        },
        collect_number => sub ($body) {
            my ($return_to, $obbserver, @chars) = @$body;

            err::log("Enter collect_number (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char =~ /^\d$/) {
                push @buffer => $char;
                $char = shift @chars;
                die "unterminated numeric" if not defined $char;
            }

            send_to($obbserver, add_number => [ (join '' => @buffer) + 0 ]);

            my $return_call = pop @$return_to;

            send_to( PID, $return_call => [ $return_to, $obbserver, ($char, @chars) ]);
        },

        # ...
        finish => sub ($body) {
            my ($obbserver) = @$body;

            send_to( $obbserver, finish => []);
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

