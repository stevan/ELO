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

use constant DEBUG_TOKENIZER => DEBUG() =~ m/TOKENIZER/ ? 1 : 0;
use constant DEBUG_DECODER   => DEBUG() =~ m/DECODER/   ? 1 : 0;

actor Splitter => sub ($env, $msg) {

    match $msg, +{
        split => sub ($return_pid, $string) {
            $return_pid->curry( split '' => $string )->send;
            sig::kill(PID)->send;
        }
    };
};

actor Decoder => sub ($env, $msg) {

    my $stack = $env->{stack} //= [];

    sys::err::log(Dumper { stack => $stack }) if DEBUG_DECODER >= 2;

    match $msg, +{
        start_object => sub () {
            sys::err::log("START OBJECT") if DEBUG_DECODER;
            push @$stack => {};
        },

        end_object => sub () {
            sys::err::log("END OBJECT") if DEBUG_DECODER;
        },

        start_property => sub () {
            sys::err::log("START PROPERTY") if DEBUG_DECODER;
        },

        end_property   => sub () {
            my $value = pop @$stack;
            my $key   = pop @$stack;
            sys::err::log("ADD PROPERTY $key => $value") if DEBUG_DECODER;
            $stack->[-1]->{$key} = $value;
            sys::err::log("END PROPERTY") if DEBUG_DECODER;
        },

        start_array => sub () { sys::err::log("START ARRAY") if DEBUG_DECODER; },
        end_array   => sub () { sys::err::log("END ARRAY") if DEBUG_DECODER; },

        start_item => sub () {
            sys::err::log("START ITEM") if DEBUG_DECODER;
        },
        end_item   => sub () {
            sys::err::log("END ITEM") if DEBUG_DECODER;
        },

        add_string => sub ($string) {
            sys::err::log("ADD STRING ($string)") if DEBUG_DECODER;
            push @$stack => $string;
        },
        add_number => sub ($number) {
            sys::err::log("ADD NUMBER ($number)") if DEBUG_DECODER;
            push @$stack => $number;
        },

        add_true   => sub () { sys::err::log("ADD TRUE") if DEBUG_DECODER; },
        add_false  => sub () { sys::err::log("ADD FALSE") if DEBUG_DECODER; },
        add_null   => sub () { sys::err::log("ADD NULL") if DEBUG_DECODER; },

        error => sub ($error) {
            sys::out::print("ERROR!!!! ($error)");
            @$stack = ();
            sig::kill(PID)->send;
            is($error, $env->{error}, '... got the error we expected');
        },
        finish     => sub () {
            sys::out::print( (Dumper $stack->[0]) =~ s/^\$VAR1\s/JSON /r ) #/
                if @$stack == 1;
            sig::kill(PID)->send;
            eq_or_diff($stack->[0], $env->{expected}, '... got the expected values');
        },
    };
};

actor Tokenizer => sub ($env, $msg) {

    state sub stip_whitespace ($chars) {
        my $char = shift @$chars;
        while (defined $char && $char =~ /^\s$/) {
            $char = shift @$chars;
        }
        return $char, @$chars;
    }

    my $stack = $env->{stack} //= [];

    sys::err::log(Dumper { stack => $stack }) if DEBUG_TOKENIZER >= 2;

    match $msg, +{
        tokenize => sub ($observer, $JSON) {
            push @$stack => 'process_tokens';
            msg(
                proc::spawn('Splitter'),
                split => [
                    msg( PID, process_tokens => [ $observer ] ),
                    $JSON
                ]
            )->send;
        },
        process_tokens => sub ($observer, @chars) {
            my $char;

            sys::err::log("Enter process_tokens (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {

                if ( $char eq '{' ) {
                    msg(PID, start_object => [ $observer, @chars ])->send;
                }
                elsif ( $char eq '"' ) {
                    # drop the quote ...
                    msg(PID, collect_string => [ $observer, @chars ])->send;
                }
                elsif ( $char =~ /^\d$/ ) {
                    # but keep the number ...
                    msg(PID, collect_number => [ $observer, ($char, @chars) ])->send;
                }
                else {
                    msg(PID, error => [ $observer, "Unexpected token `$char` in process_tokens, expected `{`, `\"`, or a digit"])->send;
                }

            }
            else {
                # end parsing ...
                msg(PID, finish => [ $observer ])->send;
            }
        },

        ## ... complex ...
        start_object => sub ($observer, @chars) {
            my $char;

            sys::err::log("Enter start_object (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                msg($observer, start_object => [])->send;

                if ( $char eq '}' ) {
                    msg(PID, end_object => [ $observer, @chars ])->send;
                }
                else {
                    push @$stack => 'process_object';
                    msg(PID, start_property => [ $observer, $char, @chars ])->send;
                }
            }
            else {
                msg(PID, error => [ $observer, "Ran out of tokens in start_object"])->send;
            }
        },
        process_object => sub ($observer, @chars) {
            my $char;

            sys::err::log("Enter process_object (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                # process tokens
                if ( $char eq '}' ) {
                    msg(PID, end_object => [ $observer, @chars ])->send;
                }
                elsif ( $char eq ',' ) {
                    push @$stack => 'process_object';
                    msg(PID, start_property => [ $observer, @chars ])->send;
                }
                else {
                    msg(PID, error => [ $observer, "Unexpected token `$char` in process_object, expected `}` or `,`"])->send;
                }
            }
            else {
                msg(PID, error => [ $observer, "Ran out of tokens in process_object"])->send;
            }
        },
        end_object => sub ($observer, @chars) {

            sys::err::log("Enter end_object (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$stack;

            msg($observer, end_object   => [])->send;
            msg(PID, $return_call, [ $observer, @chars ])->send;
        },

        # ...
        start_property => sub ($observer, @chars) {
            my $char;

            sys::err::log("Enter start_property (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq '"' ) {
                    msg($observer, start_property => [])->send;
                    push @$stack => 'process_property';
                    msg(PID, collect_string => [ $observer, @chars ])->send;
                }
                else {
                    msg(PID, error => [ $observer, "Unexpected token `$char` in start_property, property must start with a quote"])->send;
                }
            }
            else {
                msg(PID, error => [ $observer, "Unterminated object property : ran out of tokens in start_property"])->send;
            }
        },
        process_property => sub ($observer, @chars) {
            my $char;

            sys::err::log("Enter process_property (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            ($char, @chars) = stip_whitespace \@chars;

            if (defined $char) {
                if ( $char eq ':' ) {
                    msg(PID, start_item => [ $observer, @chars ])->send;
                }
                else {
                    msg(PID, error => [ $observer, "Unexpected token `$char` in process_property, expected `:`"])->send;
                }
            }
            else {
                msg(PID, error => [ $observer, "Unterminated object property : ran out of tokens in process_property"])->send;
            }
        },
        end_property => sub ($observer, @chars) {

            sys::err::log("Enter end_property (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $return_call = pop @$stack;

            msg($observer, end_property => [])->send;
            msg(PID, process_object => [ $observer, @chars ])->send;
        },


        start_item => sub ($observer, @chars) {

            sys::err::log("Enter start_item (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            msg($observer, start_item => [])->send;
            push @$stack => 'end_item';
            msg(PID, process_tokens => [ $observer, @chars ])->send;
        },
        end_item => sub ($observer, @chars) {

            sys::err::log("Enter end_item (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            msg($observer, end_item => [])->send;
            msg(PID, end_property => [ $observer, @chars ])->send;
        },


        ## ... literals ...
        collect_string => sub ($observer, @chars) {

            sys::err::log("Enter collect_string (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char ne '"') {
                push @buffer => $char;
                $char = shift @chars;
                if (not defined $char) {
                    msg(PID, error => [ $observer, "Unterminated string : ran out of tokens in collect_string"])->send;
                    return; # jump outta here
                }
            }

            msg($observer, add_string => [ join '' => @buffer ])->send;

            my $return_call = pop @$stack;

            msg( PID, $return_call, [ $observer, @chars ])->send;
        },
        collect_number => sub ($observer, @chars) {

            sys::err::log("Enter collect_number (@$stack) : (@chars)") if DEBUG_TOKENIZER;

            my $char = shift @chars;

            my @buffer;
            while ($char =~ /^\d$/) {
                push @buffer => $char;
                $char = shift @chars;
                if (not defined $char) {
                    msg(PID, error => [ $observer, "Unterminated numeric : ran out of tokens in collect_string"])->send;
                    return; # jump outta here
                }
            }

            msg($observer, add_number => [ (join '' => @buffer) + 0 ])->send;

            my $return_call = pop @$stack;

            msg( PID, $return_call, [ $observer, ($char, @chars) ])->send;
        },

        # ...
        error => sub ($observer, $error) {

            sys::err::log("Enter error (@$stack)") if DEBUG_TOKENIZER;

            @$stack = (); # clear stack ...

            msg( $observer, error => [ $error ])->send;
            sig::kill(PID)->send;
        },
        finish => sub ($observer) {

            sys::err::log("Enter finish (@$stack)") if DEBUG_TOKENIZER;

            msg( $observer, finish => [])->send;
            sig::kill(PID)->send;
        }
    };
};

actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

    msg(proc::spawn('Tokenizer'), tokenize => [
        proc::spawn('Decoder', error => 'Unexpected token `:` in process_object, expected `}` or `,`'),
        '{ "foo" : 10 :'
    ])->send;

    msg(proc::spawn('Tokenizer'), tokenize => [
        proc::spawn('Decoder', expected =>
            { foo => { bar => 10, baz => { gorch => 100 } } }
        ),
        '{ "foo" : { "bar" : 10, "baz" : { "gorch" : 100 } } }'
    ])->send;

    msg(proc::spawn('Tokenizer'), tokenize => [
        proc::spawn('Decoder', expected =>
            { bling => { boo => 10, baz => {}, foo => { gorch => 100 } }, foo => 500 }
        ),
        '{ "bling" : { "baz" : {}, "boo" : 10, "foo" : { "gorch" : 100 } }, "foo" : 500 }'
    ])->send;

};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

