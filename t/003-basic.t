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
    print_out("-> main starting ...");

    my $ident = spawn('!ident');

    send_to(
        spawn('!cond'),
        if => [
            sync(
                timeout( 2, [ $ident, id => [ 1 ] ]),
                [ $ident, id => [] ]
            ),
            [
                spawn('!sequence'),
                next => [
                    print_out("hello from then"),
                    print_out("hello from then again"),
                    print_out("hello from then last")
                ]
            ]
        ]
    );

};

# loop ...
ok loop( 20, 'main' );

done_testing;

