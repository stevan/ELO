#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::Differences;
use Test::ELO;

use List::Util 'first';
use Data::Dumper;

use ELO;

# ... userland ...
actor env => sub ($env, $msg) {
    match $msg, +{
        init => sub ($new_env) {
            $env->{$_} = $new_env->{$_} foreach keys %$new_env;
            sys::err::log("env initialized to => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }")
                if DEBUG;
        },
        get => sub ($key, $callback=undef) {
            if ( exists $env->{$key} ) {
                sys::err::log("fetching {$key}") if DEBUG;
                $callback->curry( $env->{$key} )->send;
            }
            else {
                sys::err::log("not found {$key}") if DEBUG;
            }
        },
        set => sub ($key, $value) {
            sys::err::log("storing $key => $value") if DEBUG;
            $env->{$key} = $value;

            sys::err::log("env is now => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }")
                if DEBUG;
        },
        finish => sub ($expected_env) {
            sys::err::log("finishing env and testing output") if DEBUG;
            sig::kill(PID)->send;
            eq_or_diff($expected_env, $env, '... got the env we expected');
        }
    };
};

actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

    my $e1 = proc::spawn( 'env' );
    my $e2 = proc::spawn( 'env' );

    # ...

    msg( $e1, init => [{ foo => 100, bar => 200, baz => 300 }] )->send;

    my $val = 0;
    ident($val += 10, msg( $e1, set => [$_]))->send
        foreach qw[ foo bar baz ];

    # ...

    my $timout_length = 2;
    sig::timer(
        $timout_length++,
        msg( $e1, get => [ $_, msg( $e2, set => [$_]) ] ),
    )->send foreach qw[ baz bar foo ];

    ## ...

    sig::timer(
        10,
        msg( $e2, get => [ $_, out::printf("$_(%s)") ] ),
    )->send foreach qw[ foo bar baz ];

    sig::timer( 12,
        parallel(
            msg($e1, finish => [ { foo => 10, bar => 20, baz => 30 } ]),
            msg($e2, finish => [ { foo => 10, bar => 20, baz => 30 } ])
        )
    )->send;
};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;
