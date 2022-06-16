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

my $CURRENT_CNT = 0;

actor bounce => sub ($env, $msg) {
    match $msg, +{
        up => sub ($cnt) {
            out::print("bounce(UP) => $cnt")->send;
            msg( PID, down => [$cnt+1] )->send;
            $CURRENT_CNT = $cnt;
        },
        down => sub ($cnt) {
            out::print("bounce(DOWN) => $cnt")->send;
            msg( PID, up => [$cnt+1] )->send;
            $CURRENT_CNT = $cnt;
        },
        peek => sub ($expected) {
            ok($CURRENT_CNT == $expected, "... peek bounce count ($CURRENT_CNT) is $expected");
        },
        finish => sub ($expected) {
            ok($CURRENT_CNT == $expected, "... bounce count ($CURRENT_CNT) is $expected");
            sig::kill(PID)->send;
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    my $bounce = proc::spawn( 'bounce' );

    msg( $bounce, up => [1] )->send;

    loop::timer( 5,  msg( $bounce, peek => [ 5 ] ) );
    loop::timer( 3,  msg( $bounce, peek => [ 3 ] ) );

    loop::timer( 10, msg( $bounce, finish => [ 10 ] ) );
};

# loop ...
ok loop( 20, 'main' ), '... the event loop exited successfully';

done_testing;

