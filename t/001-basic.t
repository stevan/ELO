#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

use EventLoop;

# ... userland ...
add_process( env => [
    [],[],
    {},
    sub ($env, $msg) {
        match $msg, +{
            get => sub ($body) {
                my ($key) = @$body;
                if ( exists $env->{$key} ) {
                    send_to( ERR ,=> [ print => ["fetching {$key}"]]) if DEBUG;
                    return_to( $env->{$key} );
                }
                else {
                    send_to( ERR ,=> [ print => ["not found {$key}"]]) if DEBUG;
                }
            },
            set => sub ($body) {
                my ($key, $value) = @$body;
                send_to( ERR ,=> [ print => ["storing $key => $value"]]) if DEBUG;
                $env->{$key} = $value;

                send_to( ERR ,=> [ print => ["ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }"]])
                    if DEBUG;
            }
        };
    },
]);

add_process( main => [
    [],[],
    {},
    sub ($env, $msg) {
        send_to( OUT ,=> [ print => ["-> main starting ..."]] );

        my $e1 = spawn( 'env' );
        my $e2 = spawn( 'env' );

        # ...

        sync(
            [ IN ,=> [ read => ["$_: "] ]],
            [ $e1,   [ set  => [ $_   ] ]]
        ) foreach qw[ foo bar baz ];

        # ...

        sync(
            timeout( 2 => [ $e1 => [ get => ['baz'] ]] ),
            [ $e2, [ set => ['baz'] ]]);

        sync(
            timeout( 3 => [ $e1 => [ get => ['bar'] ]] ),
            [ $e2, [ set => ['bar'] ]]);

        sync(
            timeout( 4 => [ $e1 => [ get => ['foo'] ]] ),
            [ $e2, [ set => ['foo'] ]]);

        # ...

        await( [ $e2 => [ get => ['foo'] ]], [ OUT ,=> [ printf => [ 'foo(%s)' ] ]] );
        await( [ $e2 => [ get => ['bar'] ]], [ OUT ,=> [ printf => [ 'bar(%s)' ] ]] );
        await( [ $e2 => [ get => ['baz'] ]], [ OUT ,=> [ printf => [ 'baz(%s)' ] ]] );

    },
]);

# loop ...
loop( 20, 'main' );

done_testing;
