#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;

use constant DEBUG => $ENV{DEBUG} || 0;

sub cancel_interval ($tid) {
    warn "<< Cancelling Interval: $tid\n" if DEBUG;
    ${$tid}++
}

sub interval ($this, $duration, $callback) {

    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $tid = \(my $x = 0);

    my $timeout = $duration;

    my $interval;
    $interval = sub {
        warn "!!! Checking Interval($interval) : tid($tid)[".$$tid."]\n" if DEBUG > 2;
        if ($$tid) {
            warn ">> Interval($interval) cancelled!" if DEBUG;
            return;
        }

        warn "!!! Interval($interval) tick ... interval($timeout)\n" if DEBUG > 2;
        if ($timeout <= 1) {
            warn "<< Interval($interval) done!\n" if DEBUG;
            $this->loop->next_tick($cb);
            $timeout = $duration;
            $this->loop->next_tick($interval);
        }
        else {
            warn ">> Interval($interval) still waiting ...\n" if DEBUG > 2;
            $timeout--;
            $this->loop->next_tick($interval);
        }
    };

    warn ">> Create Interval($interval) with duration($duration) tid($tid)\n" if DEBUG;

    $interval->();

    return $tid;
}

sub cancel_timer ($tid) {
    warn "<< Cancelling Timer: $tid\n" if DEBUG;
    ${$tid}++
}

sub timer ($this, $timeout, $callback) {

    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $tid = \(my $x = 0);

    my $timer;
    $timer = sub {
        warn "!!! Checking Timer($timer) : tid($tid)[".$$tid."]\n" if DEBUG > 2;
        if ($$tid) {
            warn ">> Timer($timer) cancelled!" if DEBUG;
            return;
        }

        warn "!!! Timer($timer) tick ... timeout($timeout)\n" if DEBUG > 2;
        if ($timeout <= 0) {
            warn "<< Timer($timer) done!\n" if DEBUG;
            $this->loop->next_tick($cb);
        }
        else {
            warn ">> Timer($timer) still waiting ...\n" if DEBUG > 2;
            $timeout--;
            $this->loop->next_tick($timer)
        }
    };

    warn ">> Create Timer($timer) with timeout($timeout) tid($tid)\n" if DEBUG;

    $timer->();

    return $tid;
}

sub Responder ($this, $msg) {
    warn $this->pid.' : ENTERED' if DEBUG;

    warn Dumper $msg;
}

sub init ($this, $msg) {
    warn $this->pid.' : ENTERED' if DEBUG;
    my $r = $this->spawn( Responder => \&Responder );

    my $t0 = timer( $this, 0, [ $r, ['Hello ... timeout(0)'] ] );
    my $t1 = timer( $this, 1, [ $r, ['Hello ... timeout(1)'] ] );
    my $t2 = timer( $this, 2, [ $r, ['Hello ... timeout(2)'] ] );

    my $t5 = timer( $this, 5, [ $r, ['Hello ... timeout(5)'] ] );
    my $t3 = timer( $this, 3, sub { cancel_timer( $t5 ) } );

    my $i0 = interval( $this, 3, [ $r, ['Hello ... interval(3)'] ] );
    my $i2 = timer( $this, 10, sub { cancel_interval( $i0 ) } );

}

ELO::Loop->new->run( \&init );

1;
