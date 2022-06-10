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

    send_to(
        spawn('!cond'),
        if => [
            sync(
                timeout( 2, ident(1)),
                ident(),
            ),
            [
                spawn('!seq'),
                next => [
                    out::print("hello from then"),
                    out::print("hello from then again"),
                    out::print("hello from then last")
                ]
            ]
        ]
    );

};

# loop ...
ok loop( 20, 'main' );

done_testing;

