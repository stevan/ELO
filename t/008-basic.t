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

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    loop::timer( 10, out::print("hello 2") );
    loop::timer( 9,  out::print("hello 1") );
    loop::timer( 5,  out::print("hello 0") );
};

# loop ...
ok loop( 20, 'main' ), '... the event loop exited successfully';

done_testing;

