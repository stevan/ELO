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

actor bounce => sub ($env, $msg) {
    match $msg, +{
        up => sub ($cnt) {
            out::print("bounce(UP) => $cnt");
            msg( PID, down => [$cnt+1] )->send;
        },
        down => sub ($cnt) {
            out::print("bounce(DOWN) => $cnt");
            msg( PID, up => [$cnt+1] )->send;
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

    my $bounce = spawn( 'bounce' );
    msg( $bounce, up => [1] )->send;

    timeout( 10,
        sequence(
            sys::kill($bounce),
            out::print("JELLO!"),
        ));
};

# loop ...
ok loop( 20, 'main' );

done_testing;

