#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Timer;

use constant DEBUG => $ENV{DEBUG} || 0;

sub Responder ($this, $msg) {
    warn $this->pid.' : ENTERED' if DEBUG;

    warn Dumper $msg;
}

sub init ($this, $msg) {
    warn $this->pid.' : ENTERED' if DEBUG;
    my $r = $this->spawn( Responder => \&Responder );

    my $t0 = ELO::Timer::timer( $this, 0, [ $r, ['Hello ... timeout(0)'] ] );
    my $t1 = ELO::Timer::timer( $this, 1, [ $r, ['Hello ... timeout(1)'] ] );
    my $t2 = ELO::Timer::timer( $this, 2, [ $r, ['Hello ... timeout(2)'] ] );

    my $t5 = ELO::Timer::timer( $this, 5, [ $r, ['Hello ... timeout(5)'] ] );
    my $t3 = ELO::Timer::timer( $this, 3, sub { ELO::Timer::cancel_timer( $t5 ) } );

    my $i0 = ELO::Timer::interval( $this, 3, [ $r, ['Hello ... interval(3)'] ] );
    my $i2 = ELO::Timer::timer( $this, 10, sub { ELO::Timer::cancel_interval( $i0 ) } );

}

ELO::Loop->new->run( \&init );

1;
