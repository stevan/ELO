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

use constant DEBUG_TOKENIZER => 0;

actor Splitter => sub ($env, $msg) {

    match $msg, +{
        split => sub ($body) {
            my ($to, $string) = @$body;
            send_to( EventLoop::copy_msg( $to, split '' => $string)->@* );
            send_to( SYS, kill => [PID]);
        }
    };
};

actor Printer => sub ($env, $msg) {

    my $stack = $env->{stack} //= [];

    #warn Dumper $stack;

    match $msg, +{
        start_object => sub ($body) {
            out::print("START OBJECT");
            push @$stack => {};
        },

        end_object => sub ($body) {
            out::print("END OBJECT");
        },

        start_property => sub ($body) {
            out::print("START PROPERTY");
        },

        end_property   => sub ($body) {
            out::print("END PROPERTY");
            my $value = pop @$stack;
            my $key   = pop @$stack;
            $stack->[-1]->{$key} = $value;
        },

        start_array => sub ($body) { out::print("START ARRAY") },
        end_array   => sub ($body) { out::print("END ARRAY") },

        start_item => sub ($body) {
            out::print("START ITEM");
        },
        end_item   => sub ($body) {
            out::print("END ITEM");
        },

        add_string => sub ($body) {
            out::print("ADD STRING (@$body)");
            push @$stack => $body->[0];
        },
        add_number => sub ($body) {
            out::print("ADD NUMBER (@$body)");
            push @$stack => $body->[0];
        },

        add_true   => sub ($body) { out::print("ADD TRUE") },
        add_false  => sub ($body) { out::print("ADD FALSE") },
        add_null   => sub ($body) { out::print("ADD NULL") },

        error      => sub ($body) { out::print("ERROR!!!! (@$body)") },
        finish     => sub ($body) {

            err::log(Dumper $stack->[0]);
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
            my ($to, $JSON) = @$body;
            send_to(
                spawn('Splitter'),
                split => [
                    [ PID, process_tokens => [ ['process_tokens'] => $to ]],
                    $JSON
                ]
            );
        },
        process_tokens => sub ($body) {
            my $char;
            my ($return_to, $to, @chars) = @$body;

            warn("Enter process_tokens (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            #warn Dumper [ "AAAHHHHH!", $char, \@chars ];

            if (defined $char) {

                if ( $char eq '{' ) {
                    send_to(PID, start_object => [ $return_to => $to, @chars ]);
                }
                elsif ( $char eq '"' ) {
                    # drop the quote ...
                    send_to(PID, collect_string => [ $return_to => $to, @chars ]);
                }
                elsif ( $char =~ /^\d$/ ) {
                    # but keep the number ...
                    send_to(PID, collect_number => [ $return_to => $to, ($char, @chars) ]);
                }

            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $to ]);
            }
        },

        ## ... complex ...
        start_object => sub ($body) {
            my $char;
            my ($return_to, $to, @chars) = @$body;

            warn("Enter start_object (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                send_to($to, start_object => []);
                push @$return_to => 'process_object';
                send_to(PID, start_property => [ $return_to, $to, ($char, @chars) ]);
            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $to ]);
            }
        },
        process_object => sub ($body) {
            my $char;
            my ($return_to, $to, @chars) = @$body;

            warn("Enter process_object (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                # process tokens
                if ( $char eq '}' ) {
                    send_to(PID, end_object => [ $return_to, $to, @chars ]);
                }
                elsif ( $char eq ',' ) {
                    push @$return_to => 'process_object';
                    send_to(PID, start_property => [ $return_to, $to, @chars ]);
                }
            }
            else {
                # end parsing ...
                send_to(PID, finish => [ $to ]);
            }
        },
        end_object => sub ($body) {
            my ($return_to, $to, @chars) = @$body;

            warn("Enter end_object (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$return_to;

            send_to($to, end_object   => []);
            send_to(PID, $return_call => [ $return_to, $to, @chars ]);
        },

        # ...
        start_property => sub ($body) {
            my $char;
            my ($return_to, $to, @chars) = @$body;

            warn("Enter start_property (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq '"' ) {
                    send_to($to, start_property => []);
                    push @$return_to => 'process_property';
                    send_to(PID, collect_string => [ $return_to => $to, @chars ]);
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
            my ($return_to, $to, @chars) = @$body;

            warn("Enter process_property (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq ':' ) {
                    send_to(PID, start_item => [ $return_to, $to, @chars ]);
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
            my ($return_to, $to, @chars) = @$body;

            warn("Enter end_property (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$return_to;

            send_to($to, end_property => []);
            send_to(PID, process_object => [ $return_to, $to, @chars ]);
        },


        start_item => sub ($body) {
            my ($return_to, $to, @chars) = @$body;

            warn("Enter start_item (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            send_to($to, start_item => []);
            push @$return_to => 'end_item';
            send_to(PID, process_tokens => [ $return_to, $to, @chars ]);
        },
        end_item => sub ($body) {
            my ($return_to, $to, @chars) = @$body;

            warn("Enter end_item (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            send_to($to, end_item => []);
            send_to(PID, end_property => [ $return_to, $to, @chars ]);
        },


        ## ... literals ...
        collect_string => sub ($body) {
            my ($return_to, $to, @chars) = @$body;

            warn("Enter collect_string (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char ne '"') {
                push @buffer => $char;
                $char = shift @chars;
                die "unterminated string" if not defined $char;
            }

            send_to($to, add_string => [ join '' => @buffer ]);

            my $return_call = pop @$return_to;

            send_to( PID, $return_call => [ $return_to, $to, @chars ]);
        },
        collect_number => sub ($body) {
            my ($return_to, $to, @chars) = @$body;

            warn("Enter collect_number (@$return_to) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char =~ /^\d$/) {
                push @buffer => $char;
                $char = shift @chars;
                die "unterminated numeric" if not defined $char;
            }

            send_to($to, add_number => [ (join '' => @buffer) + 0 ]);

            my $return_call = pop @$return_to;

            send_to( PID, $return_call => [ $return_to, $to, ($char, @chars) ]);
        },

        # ...
        finish => sub ($body) {
            my ($to) = @$body;

            send_to( $to, finish => []);
            send_to( SYS, kill   => [PID]);
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");


    #send_to(spawn('Tokenizer'), tokenize => [
    #    spawn('Printer'),
    #    '{ "foo" : { "bar" : 10, "baz" : { "gorch" : 100 } } }'
    #]);

    send_to(spawn('Tokenizer'), tokenize => [
        spawn('Printer'),
        '{ "bling" : {} }'
    ]);

};

# loop ...
ok loop( 100, 'main' );

done_testing;

