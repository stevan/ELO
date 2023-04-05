#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;

sub init ($this, $msg) {
    say "[".$this->pid."] hello world";

    my $greeter = $this->spawn('greeter' => \&greeting);
    $this->send( $greeter, ['everyone']);
    $this->send( $greeter, ['alemaal']);

    my $bounce1 = $this->spawn('bounce' => \&bounce);
    $this->send( $bounce1, [5] );

    my $bounce2 = $this->spawn('bounce' => \&bounce);
    $this->send( $bounce2, [3] );

    my $bounce_cb = $this->spawn('bounce_cb' => \&bounce_cb);
    $this->send( $bounce_cb, [7, $greeter] );

    #warn Dumper $this;
}

sub greeting ($this, $msg) {
    my ($name) = @$msg;

    say "[".$this->pid."] hello $name"
}

sub bounce ($this, $msg) {
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
    my ($bounces, $cb) = @$msg;

    if ($bounces) {
        $this->send( $cb, ["bounce CB($bounces)"] );
        $this->send_to_self( [ $bounces - 1, $cb ] );
    }
    else {
        $this->send( $cb, ["plop($bounces)"] );
    }
}

ELO::Loop->new->run( \&init );

1;
