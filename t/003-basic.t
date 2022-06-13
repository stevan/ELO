#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

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
ok loop( 20, 'main' );

done_testing;

