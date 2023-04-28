package ELO::Timers;
use v5.36;

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

our %EXPORT_TAGS = (
    timers  => [qw[ timer interval cancel_timer ]],
    tickers => [qw[ ticker interval_ticker cancel_ticker ]],
);

# Timers - TODO

sub timer ($this, $timeout, $callback) {

    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $tid = $this->loop->add_timer( $timeout, $cb );

    warn ">> Create Timer($cb) with timeout($timeout) tid($tid)\n" if DEBUG;

    return \$tid;
}

sub interval ($this, $duration, $callback) {
    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $iid = \(my $x = 0);

    my $interval = sub {
        $cb->();
        my $tid = $this->loop->add_timer( $duration, __SUB__ );
        #warn "t_ID: $tid (refresh) ".$$tid;
        ${$iid} = $tid;
        #warn "i_ID: $iid (refresh) ".$$iid;
        warn ">> Refreshing Inverval($cb) with duration($duration) and iid($iid) -> tid($tid)\n" if DEBUG;
    };

    my $tid = $this->loop->add_timer( $duration, $interval );
    #warn "t_ID: $tid ".$$tid;
    $iid = \$tid;
    #warn "i_ID: $iid ".$$iid;

    warn ">> Create Inverval($cb) with duration($duration) iid($iid) -> tid($iid)\n" if DEBUG;

    return $iid;
}

sub cancel_timer ($this, $tid) {
    warn "<< Cancelling Timer: $tid for $$tid\n" if DEBUG;
    $this->loop->cancel_timer( $$tid );
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

    my $timeout  = $duration;
    my $interval = sub {
        warn "!!! Checking TickerInterval($cb) : tid($tid)[".$$tid."]\n" if DEBUG > 2;
        if ($$tid) {
            warn ">> TickerInterval($cb) cancelled!" if DEBUG;
            return;
        }

        warn "!!! TickerInterval($cb) tick ... interval($timeout)\n" if DEBUG > 2;
        if ($timeout <= 1) {
            warn "<< TickerInterval($cb) call!\n" if DEBUG;
            $this->loop->next_tick(sub {
                # just to be sure, check the tid
                $$tid or $cb->()
            });
            $timeout = $duration;
            $this->loop->next_tick(__SUB__);
        }
        else {
            warn ">> TickerInterval($cb) still waiting ...\n" if DEBUG > 2;
            $timeout--;
            $this->loop->next_tick(__SUB__);
        }
    };

    warn ">> Create TickerInterval($cb) with duration($duration) tid($tid)\n" if DEBUG;

    $interval->();

    return $tid;
}

sub ticker ($this, $timeout, $callback) {

    my $cb = ref $callback eq 'CODE'
        ? $callback
        : sub { $this->send( @$callback ) };

    my $tid = \(my $x = 0);

    my $timer = sub {
        warn "!!! Checking Ticker($cb) : tid($tid)[".$$tid."]\n" if DEBUG > 2;
        if ($$tid) {
            warn ">> Ticker($cb) cancelled!" if DEBUG;
            return;
        }

        warn "!!! Ticker($cb) tick ... timeout($timeout)\n" if DEBUG > 2;
        if ($timeout <= 0) {
            warn "<< Ticker($cb) done!\n" if DEBUG;
            $this->loop->next_tick(sub {
                # just to be sure, check the tid
                $$tid or $cb->()
            });
        }
        else {
            warn ">> Ticker($cb) still waiting ...\n" if DEBUG > 2;
            $timeout--;
            $this->loop->next_tick(__SUB__)
        }
    };

    warn ">> Create Ticker($cb) with timeout($timeout) tid($tid)\n" if DEBUG;

    $timer->();

    return $tid;
}

1;

__END__

=pod

=cut

