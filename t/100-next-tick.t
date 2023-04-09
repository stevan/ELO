#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;

sub init ($this, $msg) {
    say "Hello world";
    $this->loop->next_tick(sub {
        say "Goodbye World";
        $this->loop->next_tick(sub {
            say "I mean it this time!";
        });
    });
}

ELO::Loop->run( \&init );

1;
