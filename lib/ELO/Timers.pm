package ELO::Timers;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use constant DEBUG => $ENV{TIMER_DEBUG} || 0;

use Exporter 'import';

our @EXPORT_OK = qw[
    timer
    interval
    cancel_timer

    ticker
    interval_ticker
    cancel_ticker
];

# Timers - TODO

sub timer ($this, $timeout, $callback) {

    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $tid = $this->loop->add_timer( $timeout, $cb );

    warn ">> Create Timer($cb) with timeout($timeout) tid($tid)\n" if DEBUG;

    return $tid;
}

sub interval ($this, $duration, $callback) {
    ...
}

sub cancel_timer ($this, $tid) {
    warn "<< Cancelling Timer: $tid\n" if DEBUG;
    $this->loop->cancel_timer( $tid );
}

# Tickers

sub cancel_ticker ($tid) {
    warn "<< Cancelling Ticker: $tid\n" if DEBUG;
    ${$tid}++
}

sub interval_ticker ($this, $duration, $callback) {

    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $tid = \(my $x = 0);

    my $timeout = $duration;

    my $interval;
    $interval = sub {
        warn "!!! Checking TickerInterval($interval) : tid($tid)[".$$tid."]\n" if DEBUG > 2;
        if ($$tid) {
            warn ">> TickerInterval($interval) cancelled!" if DEBUG;
            return;
        }

        warn "!!! TickerInterval($interval) tick ... interval($timeout)\n" if DEBUG > 2;
        if ($timeout <= 1) {
            warn "<< TickerInterval($interval) call!\n" if DEBUG;
            $this->loop->next_tick(sub {
                # just to be sure, check the tid
                $$tid or $cb->()
            });
            $timeout = $duration;
            $this->loop->next_tick($interval);
        }
        else {
            warn ">> TickerInterval($interval) still waiting ...\n" if DEBUG > 2;
            $timeout--;
            $this->loop->next_tick($interval);
        }
    };

    warn ">> Create TickerInterval($interval) with duration($duration) tid($tid)\n" if DEBUG;

    $interval->();

    return $tid;
}

sub ticker ($this, $timeout, $callback) {

    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $tid = \(my $x = 0);

    my $timer;
    $timer = sub {
        warn "!!! Checking Ticker($timer) : tid($tid)[".$$tid."]\n" if DEBUG > 2;
        if ($$tid) {
            warn ">> Ticker($timer) cancelled!" if DEBUG;
            return;
        }

        warn "!!! Ticker($timer) tick ... timeout($timeout)\n" if DEBUG > 2;
        if ($timeout <= 0) {
            warn "<< Ticker($timer) done!\n" if DEBUG;
            $this->loop->next_tick(sub {
                # just to be sure, check the tid
                $$tid or $cb->()
            });
        }
        else {
            warn ">> Ticker($timer) still waiting ...\n" if DEBUG > 2;
            $timeout--;
            $this->loop->next_tick($timer)
        }
    };

    warn ">> Create Ticker($timer) with timeout($timeout) tid($tid)\n" if DEBUG;

    $timer->();

    return $tid;
}

1;

__END__

=pod

=cut

