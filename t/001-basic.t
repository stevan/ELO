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


# ... userland ...
actor env => sub ($env, $msg) {
    match $msg, +{
        init => sub ($body) {
            my ($new_env) = @$body;
            $env->{$_} = $new_env->{$_} foreach keys %$new_env;
            err::log("env initialized to => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }")
                if DEBUG;
        },
        get => sub ($body) {
            my ($key) = @$body;
            if ( exists $env->{$key} ) {
                err::log("fetching {$key}") if DEBUG;
                return_to( $env->{$key} );
            }
            else {
                err::log("not found {$key}") if DEBUG;
            }
        },
        set => sub ($body) {
            my ($key, $value) = @$body;
            err::log("storing $key => $value") if DEBUG;
            $env->{$key} = $value;

            err::log("env is now => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }")
                if DEBUG;
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $e1 = spawn( 'env' );
    my $e2 = spawn( 'env' );

    # ...

    send_to( $e1, init => [{ foo => 100, bar => 200, baz => 300 }] );

    my $val = 0;
    sync(
        # in:read( "$_ : " ),
        ident($val += 10),
        [ $e1, set => [$_]]
    ) foreach qw[ foo bar baz ];

    # ...

    my $timout_length = 2;
    sync(
        timeout( $timout_length++ => [ $e1, get => [$_]] ),
        [ $e2, set => [$_]]
    ) foreach qw[ baz bar foo ];

    ## ...

    sync(
        timeout( 10, [ $e2, get => [$_]] ),
        out::printf( $_.'(%s)' )
    ) foreach qw[ foo bar baz ];

    # ...
};

# loop ...
ok loop( 20, 'main' );

done_testing;
