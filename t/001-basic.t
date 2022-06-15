#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::Differences;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
use SAM::Msg;
use SAM::Actors;
use SAM::IO;

# ... userland ...
actor env => sub ($env, $msg) {
    match $msg, +{
        init => sub ($new_env) {
            $env->{$_} = $new_env->{$_} foreach keys %$new_env;
            err::log("env initialized to => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }")->send
                if DEBUG;
        },
        get => sub ($key) {
            if ( exists $env->{$key} ) {
                err::log("fetching {$key}")->send if DEBUG;
                return_to( $env->{$key} );
            }
            else {
                err::log("not found {$key}")->send if DEBUG;
            }
        },
        set => sub ($key, $value) {
            err::log("storing $key => $value")->send if DEBUG;
            $env->{$key} = $value;

            err::log("env is now => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }")->send
                if DEBUG;
        },
        finish => sub ($expected_env) {
            err::log("finishing env and testing output")->send if DEBUG;
            sys::kill(PID)->send;
            eq_or_diff($expected_env, $env, '... got the env we expected');
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    my $e1 = proc::spawn( 'env' );
    my $e2 = proc::spawn( 'env' );

    # ...

    msg( $e1, init => [{ foo => 100, bar => 200, baz => 300 }] )->send;

    my $val = 0;
    sync(
        # in:read( "$_ : " ),
        ident($val += 10),
        msg::curry( $e1, set => [$_])
    )->send foreach qw[ foo bar baz ];

    # ...

    my $timout_length = 2;
    sync(
        timeout( $timout_length++ => msg( $e1, get => [$_] ) ),
        msg::curry( $e2, set => [$_])
    )->send foreach qw[ baz bar foo ];

    ## ...

    sync(
        timeout( 10, msg( $e2, get => [$_] ) ),
        out::printf("$_(%s)")
    )->send foreach qw[ foo bar baz ];

    proc::alarm( 12,
        parallel(
            msg($e1, finish => [ { foo => 10, bar => 20, baz => 30 } ]),
            msg($e2, finish => [ { foo => 10, bar => 20, baz => 30 } ])
        )
    );
};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;
