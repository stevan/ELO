#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
use SAM::Actors;
use SAM::IO;

actor TestBuilder => sub ($env, $msg) {
    state $counter = 0;

    match $msg, +{
        ok => sub ($value, $msg) {
            $counter++;
            my $ok = $value ? 'ok' : 'not ok';
            out::print("$ok $counter $msg");
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $builder = spawn( 'TestBuilder' );

    timeout( 3, msg( $builder, ok => [ 1, '... it works!' ]) );

    msg( $builder, ok => [ 1, '... it works!' ] )->send;
    msg( $builder, ok => [ 0, '... it still works!' ] )->send;

    timeout( 4, sys::kill($builder) );
};

# loop ...
ok loop( 10, 'main' );

done_testing;

