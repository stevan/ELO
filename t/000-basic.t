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

my $BOUNCE_COUNT = 0;

actor bounce => sub ($env, $msg) {
    match $msg, +{
        up => sub ($cnt) {
            out::print("bounce(UP) => $cnt")->send;
            msg( PID, down => [$cnt+1] )->send;
            $BOUNCE_COUNT++;
        },
        down => sub ($cnt) {
            out::print("bounce(DOWN) => $cnt")->send;
            msg( PID, up => [$cnt+1] )->send;
            $BOUNCE_COUNT++;
        },
        finish => sub () {
            ok($BOUNCE_COUNT < 15, "... bounce count ($BOUNCE_COUNT) is less than 15");
            sys::kill(PID)->send;
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    my $bounce = proc::spawn( 'bounce' );
    msg( $bounce, up => [1] )->send;

    proc::alarm(
        10,
        sequence(
            msg( $bounce, finish => [] ),
            out::print("JELLO!"),
        )
    );
};

# loop ...
ok loop( 20, 'main' ), '... the event loop exited successfully';

done_testing;

