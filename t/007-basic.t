#!perl

use v5.24;
use warnings;
use experimental 'lexical_subs', 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

use EventLoop;
use EventLoop::Actors;
use EventLoop::IO;

actor main => sub ($env, $msg) {
    out::print("-> main starting ...");

};

# loop ...
ok loop( 100, 'main' );

done_testing;

