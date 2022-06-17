#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::ELO;

use List::Util 'first';
use Data::Dumper;

use ELO;
use ELO::Msg;
use ELO::Actors;
use ELO::IO;

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    sig::timer( 10, out::print("hello 2") )->send;
    sig::timer( 9,  out::print("hello 1") )->send;
    sig::timer( 5,  out::print("hello 0") )->send;
};

# loop ...
ok loop( 20, 'main' ), '... the event loop exited successfully';

done_testing;

