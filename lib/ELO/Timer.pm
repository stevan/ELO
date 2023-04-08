package ELO::Timer;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use constant DEBUG => $ENV{DEBUG} || 0;

use Exporter 'import';

our @EXPORT_OK = qw[
    timer
    cancel_timer
    interval
    cancel_interval
];

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

1;

__END__

=pod

=cut

