#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::ELO;

use List::Util 'first';
use Data::Dumper;

use ELO;

actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

    sig::timer( 0,  out::print("hello -2") )->send;
    sig::timer( 1,  out::print("hello -1") )->send;
    sig::timer( 5,  out::print("hello 0") )->send;
    sig::timer( 9,  out::print("hello 1") )->send;
    sig::timer( 10, out::print("hello 2") )->send;
};

# loop ...
ok loop( 20, 'main' ), '... the event loop exited successfully';

done_testing;

