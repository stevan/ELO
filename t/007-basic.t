#!perl

use v5.24;
use warnings;
use experimental 'lexical_subs', 'signatures', 'postderef';

use Test::More;
use Test::SAM;

use List::Util 'first';
use Data::Dumper;

use SAM;
use SAM::Actors;
use SAM::IO;

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

