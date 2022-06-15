#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
use SAM::Msg;
use SAM::Actors;
use SAM::IO;

my @VALUES;

actor TestBuilder => sub ($env, $msg) {
    state $counter = 0;

    match $msg, +{
        ok => sub ($value, $msg) {
            $counter++;
            my $ok = $value ? 'ok' : 'not ok';
            out::print("$ok $counter $msg")->send;
            ok($value, $msg);
            push @VALUES => $value;
        },
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $builder = sys::spawn( 'TestBuilder' );

    timeout( 3, msg( $builder, ok => [ 2, '... it works later' ]) )->send;
    msg( $builder, ok => [ 1, '... it works now' ] )->send;

    timeout( 4, sys::kill($builder) )->send;
};

# loop ...
ok loop( 10, 'main' ), '... the event loop exited successfully';

is_deeply( \@VALUES, [ 1, 2 ], '... values returned in the right order');

done_testing;

