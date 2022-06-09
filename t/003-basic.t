#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

use EventLoop;
use Actors;

actor main => sub ($env, $msg) {
    send_to( OUT, print => ["-> main starting ..."] );

    my $ident = spawn('!ident');

    send_to(
        spawn('!cond'),
        if => [
            sync(
                timeout( 2, [ $ident, id => [ 1 ] ]),
                [ $ident, id => [] ]
            ),
            [ OUT, print => ["hello from then"]]
        ]
    );

};

# loop ...
ok loop( 20, 'main' );

done_testing;

