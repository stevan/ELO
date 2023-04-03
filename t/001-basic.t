#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;

sub init ($this) {
    say "[".$this->pid."] hello world";

    my $greeter = $this->spawn('greeter' => \&greeting);
    $this->send( $greeter, 'everyone');
    $this->send( $greeter, 'alemaal');

    $greeter->call("y'all");

    my $bounce1 = $this->spawn('bounce' => \&bounce);
    $this->send( $bounce1, 5 );

    $bounce1->call( 10 );

    my $bounce2 = $this->spawn('bounce' => \&bounce);
    $this->send( $bounce2, 3 );

    my $bounce_cb = $this->spawn('bounce_cb' => \&bounce_cb);
    $this->send( $bounce_cb, 7, $greeter );

    #warn Dumper $this;
}

sub greeting ($this, $name) {
    say "[".$this->pid."] hello $name"
}

sub bounce ($this, $bounces) {
    if ($bounces) {
        say "[".$this->pid."] boing! $bounces";
        $this->send_to_self( $bounces - 1 );
    }
    else {
        say "[".$this->pid."] plop!";
    }
}

sub bounce_cb ($this, $bounces, $cb) {
    if ($bounces) {
        $cb->call( "bounce CB($bounces)" );
        $this->send_to_self( $bounces - 1, $cb );
    }
    else {
        $cb->call( "plop($bounces)" );
    }
}

ELO::Loop->new->run( \&init, () );

1;
