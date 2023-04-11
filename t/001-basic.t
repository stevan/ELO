#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';

# TODO: remove this test, or improve it somehow

sub init ($this, $msg) {
    isa_ok($this, 'ELO::Core::Process');

    say "[".$this->pid."] hello world";

    my $greeter = $this->spawn('greeter' => \&greeting);
    isa_ok($greeter, 'ELO::Core::Process');

    $this->send( $greeter, ['everyone']);
    $this->send( $greeter, ['alemaal']);

    my $bounce1 = $this->spawn('bounce' => \&bounce);
    isa_ok($bounce1, 'ELO::Core::Process');

    $this->send( $bounce1, [5] );

    my $bounce2 = $this->spawn('bounce' => \&bounce);
    isa_ok($bounce2, 'ELO::Core::Process');

    $this->send( $bounce2, [3] );

    my $bounce_cb = $this->spawn('bounce_cb' => \&bounce_cb);
    isa_ok($bounce_cb, 'ELO::Core::Process');

    $this->send( $bounce_cb, [7, $greeter] );

    #warn Dumper $this;
}

sub greeting ($this, $msg) {
    isa_ok($this, 'ELO::Core::Process');

    my ($name) = @$msg;

    say "[".$this->pid."] hello $name"
}

sub bounce ($this, $msg) {
    isa_ok($this, 'ELO::Core::Process');

    my ($bounces) = @$msg;

    if ($bounces) {
        say "[".$this->pid."] boing! $bounces";
        $this->send_to_self( [ $bounces - 1 ] );
    }
    else {
        say "[".$this->pid."] plop!";
    }
}

sub bounce_cb ($this, $msg) {
    isa_ok($this, 'ELO::Core::Process');

    my ($bounces, $cb) = @$msg;

    if ($bounces) {
        $this->send( $cb, ["bounce CB($bounces)"] );
        $this->send_to_self( [ $bounces - 1, $cb ] );
    }
    else {
        $this->send( $cb, ["plop($bounces)"] );
    }
}

ELO::Loop->run( \&init );

done_testing;

1;
