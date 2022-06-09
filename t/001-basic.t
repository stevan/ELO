#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

use EventLoop;
use Actors;


# ... userland ...
actor env => sub ($env, $msg) {
    match $msg, +{
        init => sub ($body) {
            my ($new_env) = @$body;
            $env->{$_} = $new_env->{$_} foreach keys %$new_env;
            send_to( ERR, print => ["env initialized to => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." } from (".CALLER.")", CALLER])
                if DEBUG;
        },
        get => sub ($body) {
            my ($key) = @$body;
            if ( exists $env->{$key} ) {
                send_to( ERR, print => ["fetching {$key} from (".CALLER.")", CALLER]) if DEBUG;
                return_to( $env->{$key} );
            }
            else {
                send_to( ERR, print => ["not found {$key} from (".CALLER.")", CALLER]) if DEBUG;
            }
        },
        set => sub ($body) {
            my ($key, $value) = @$body;
            send_to( ERR, print => ["storing $key => $value from (".CALLER.")", CALLER]) if DEBUG;
            $env->{$key} = $value;

            send_to( ERR, print => ["env is now => ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." } from (".CALLER.")", CALLER])
                if DEBUG;
        }
    };
};

actor main => sub ($env, $msg) {
    send_to( OUT, print => ["-> main starting ..."] );

    my $e1 = spawn( 'env' );
    my $e2 = spawn( 'env' );

    # ...

    send_to( $e1, init => [{ foo => 100, bar => 200, baz => 300 }] );

    sync(
        [ IN, read => ["$_: "]],
        [ $e1, set => [$_]]
    ) foreach qw[ foo bar baz ];

    # ...

    my $timout_length = 2;
    sync(
        timeout( $timout_length++ => [ $e1, get => [$_]] ),
        [ $e2, set => [$_]]
    ) foreach qw[ baz bar foo ];

    ## ...

    await(
        [ $e2,    get => [$_]],
        [ OUT, printf => [ $_.'(%s)' ]]
    ) foreach qw[ foo bar baz ];

    # ...
};

# loop ...
ok loop( 20, 'main' );

done_testing;
