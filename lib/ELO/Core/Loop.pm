package ELO::Core::Loop;
use v5.36;
use experimental 'try', 'builtin';
use builtin 'blessed';

use Carp         'confess';
use List::Util   'uniq';
use Time::HiRes  ();

use ELO::Core::Process;

use ELO::Core::Behavior::FunctionWrapper;

use ELO::Types qw[ *SIGEXIT ];

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    tick_delay => sub {},
    # ...
    _time           => sub { +[] },
    _process_table  => sub { +{} },
    _process_links  => sub { +{} },

    _timers         => sub { +[] },
    _message_queue  => sub { +[] },
    _signal_queue   => sub { +[] },
    _callback_queue => sub { +[] },
);

sub create_process ($self, @args) {

    my ($behavior, $parent);
    if ( blessed $args[0] && $args[0]->roles::DOES('ELO::Core::Behavior') ) {
        $behavior = shift @args;
    }
    else {
        my $name = shift @args;
        my $f    = shift @args;

        ($name)
            || confess 'You must specify a name as the first parameter to spawn';
        ($f && ref $f eq 'CODE')
            || confess 'You must specify a function as the second parameter to spawn';

        $behavior = ELO::Core::Behavior::FunctionWrapper->new(
            name => $name,
            func => $f,
        );
    }

    $parent = shift @args if @args;

    my $process = ELO::Core::Process->new(
        behavior => $behavior,
        loop     => $self,
        parent   => $parent,
    );
    $self->{_process_table}->{ $process->pid } = $process;
    return $process;
}

sub destroy_process ($self, $process) {

    my $pid = $process->pid;

    # tell everyone bye
    $self->notify_links( $process )
        # and remove the process links as well ..
        && delete $self->{_process_links}->{ $pid }
            # if we need to ...
            if exists $self->{_process_links}->{ $pid };

    # remove self from the process table ...
    delete $self->{_process_table}->{ $pid };

    # remove any other references to
    # the process in other links
    foreach my $links ( values $self->{_process_links}->%* ) {
        @$links = grep $_->pid ne $pid, @$links;
    }

    # remove signals for this process currently in the queue
    $self->{_signal_queue}->@* = grep {
        (blessed $_->[0] ?  $_->[0]->pid : $_->[0]) ne $pid
    } $self->{_signal_queue}->@*;

    # remove messages for this process currently in the queue
    $self->{_message_queue}->@* = grep {
        (blessed $_->[0] ?  $_->[0]->pid : $_->[0]) ne $pid
    } $self->{_message_queue}->@*;
}

sub notify_links ($self, $process) {

    # handle any links that exist ...
    if ( my $links = $self->{_process_links}->{ $process->pid } ) {
        #warn "links found for ".$process->pid;
        #use Data::Dumper; warn Dumper { links_for_pid => $process->pid };
        foreach my $link (@$links) {
            #use Data::Dumper; warn Dumper { sending_SIGEXIT_to_link => $link->pid };
            # let link know we exited
            $process->kill( $link );
            # is the same as
            # $process->signal( $link, *SIGEXIT, [ $process ] );
        }
    }
    #else {
       #warn "NO links found for ".$process->pid;
    #}

    #use Data::Dumper; warn Dumper { links => +{ map {
    #        $_ => [ map { $_->pid } $self->{_process_links}->{$_}->@* ]
    #} keys $self->{_process_links}->%* } };

    return;
}

sub link_process ($self, $to_process, $from_process) {

    my $to_links = $self->{_process_links}->{ $from_process->pid } //= [];
    # make sure the list is uniq ...
    $to_links->@* = uniq( $to_process, $to_links->@* );

    # make sure the list is uniq ...
    my $from_links = $self->{_process_links}->{ $to_process->pid } //= [];
    $from_links->@* = uniq( $from_process, $from_links->@* );

    #use Data::Dumper; warn Dumper { links => +{ map {
    #        $_ => [ map { $_->pid } $self->{_process_links}->{$_}->@* ]
    #} keys $self->{_process_links}->%* } };

    return;
}

sub unlink_process ($self, $to_process, $from_process) {

    #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid });
    if ( my $links = $self->{_process_links}->{ $from_process->pid } ) {
        #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid, links => [ map { $_->pid } @$links ] });
        @$links = grep { $_->pid ne $to_process->pid } @$links;
        #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid, links => [ map { $_->pid } @$links ] });
    }

    #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid });
    if ( my $links = $self->{_process_links}->{ $to_process->pid } ) {
        #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid, links => [ map { $_->pid } @$links ] });
        @$links = grep { $_->pid ne $from_process->pid } @$links;
        #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid, links => [ map { $_->pid } @$links ] });
    }

    return;
}

# ...

sub next_tick ($self, $f) {
    # F = sub () -> ();
    push $self->{_callback_queue}->@* => $f;
    return;
}

sub add_timer ($self, $timeout, $f) {
    # XXX - should we optimize timeout of 0 and
    # just translate it into next_tick?

    my $tid = \(my $x = 0);

    # Timer = [ $time, $f ]
    push $self->{_timers}->@* => [ $self->now + $timeout, $f, $tid ];
    # ... always keep them sorted
    $self->{_timers}->@* = sort { $a->[0] <=> $b->[0] } $self->{_timers}->@*;
    return $tid;
}

sub cancel_timer ($self, $tid) {
    ${$tid}++;
    return;
}

sub enqueue_signal ($self, $sig) {
    # Sig = [ $to_process, $signal, $event ]
    push $self->{_signal_queue}->@* => $sig;
    return;
}

sub enqueue_msg ($self, $msg) {
    # Msg = [ $to_process, $event ]
    push $self->{_message_queue}->@* => $msg;
    return;
}

# ...

sub is_process_alive ($self, $proc) {
    $self->lookup_active_process( $proc ) ? 1 : 0;
}

sub lookup_active_process ($self, $to_proc) {
    $self->{_process_table}->{ blessed $to_proc ? $to_proc->pid : $to_proc };
}

# ...

my $TIMERS_RUN         = 0;
my $CALLBACKS_RUN      = 0;
my $SIGNALS_HANDLED    = 0;
my $MESSAGES_PROCESSED = 0;

sub TICK ($self) {

    # Signals are handled first, as they
    # are meant to be async interrupts
    # (ala unix signals) but we wont
    # interrupt any other code, so we
    # do the next best-ish thing by
    # handling the signals first, even before
    # the timers, even though they are
    # time sensitive. It should be noted
    # that this will only run the internal
    # handlers now, if the signal is trapped
    # then the message is enqueued and
    # will be handled as a normal message
    # during this tick
    my @sig_queue = $self->{_signal_queue}->@*;
    $self->{_signal_queue}->@* = ();

    while (@sig_queue) {
        my $sig = shift @sig_queue;
        my ($to_proc, $signal, $event) = @$sig;

        $to_proc = $self->lookup_active_process( $to_proc );

        # if the process is not active, ignore all signals
        # XXX - maybe add a dead signal queue here
        next unless $to_proc;

        $SIGNALS_HANDLED++;

        # is the signal trapped?
        if ( $to_proc->is_trapping( $signal ) ) {
            # then convert this into a message
            $self->enqueue_msg( [ $to_proc, [ $signal, @$event ]] );
        }
        else {
            # run the immediate handlers
            # XXX - this should be done better, but works for now
            if ( $signal eq *SIGEXIT ) {
                # exit is a terminal signal,
                $to_proc->exit(1);
            }
            else {
                # everything else would be ignore
            }
        }

    }

    # next thing we do is process the timers
    # since they are time sensitive and we
    # cannot guarentee that they will fire
    # at the exact time, only that they will
    # fire /after/ the time specified
    my $now    = $self->now;
    my $timers = $self->{_timers};
    while (@$timers && $timers->[0]->[0] <= $now) {
        my $timer = shift @$timers;
        next if ${$timer->[2]}; # skip if the timer has been cancelled
        try {
            $timer->[1]->();
            $TIMERS_RUN++;
        } catch ($e) {
            die "Timer callback failed ($timer) because: $e";
        }
    }

    # next comes the Callback queue, these are
    # meant to be kind of internal events, and
    # so they need some priority, though not as
    # much as the signals, hence their place in
    # this ordering.
    my @cb_queue = $self->{_callback_queue}->@*;
    $self->{_callback_queue}->@* = ();

    while (@cb_queue) {
        my $f = shift @cb_queue;
        try {
            $f->();
            $CALLBACKS_RUN++
        } catch ($e) {
            die "Callback failed ($f) because: $e";
        }
    }

    # last is the message queue, which will process
    # all messages recieved in previous ticks and
    # followed by any messages enqueued during the
    # previous phases of this tick. The prime example
    # being signals, which can be turned into
    # messages that are executed in this same tick.

    my @msg_queue = $self->{_message_queue}->@*;
    $self->{_message_queue}->@* = ();

    while (@msg_queue) {
        my $msg = shift @msg_queue;
        my ($to_proc, $event) = @$msg;

        $to_proc = $self->lookup_active_process( $to_proc );

        # if the process is not active, ignore all messages
        # XXX - maybe add a dead letter queue here
        next unless $to_proc;

        $MESSAGES_PROCESSED++;

        try {
            $to_proc->accept( $event );
            $to_proc->tick;
        } catch ($e) {
            #use Data::Dumper;
            #warn Dumper { msg => $msg, queue => \@msg_queue };
            die "Message to (".$to_proc->pid.") failed with msg(".(join ', ' => @{ $event // []}).") because: $e";
        }
    }

    return;
}

# NOTE:
# currently this is basically loop-once, or loop-to-completion since
# we will stop once we have nothing in the queue. In a loop-forever
# scenario, we would simply sleep the loop until we got something
# but since we currently cannot get outside input, that really is
# not a concern at the moment.

sub _init_time ($self) {
    $self->{_time}->[0] = 0;
    $self->{_time}->[1] = 0;
}

sub _update_tick  ($self) { ++$self->{_time}->[0] }
sub _update_clock ($self) {
    $self->{_time}->[1] = Time::HiRes::clock_gettime( Time::HiRes::CLOCK_MONOTONIC() )
}

sub tick ($self) { $self->{_time}->[0]  }
sub now  ($self) { $self->_update_clock } # always stay up to date ...

sub sleep ($self, $wait) { Time::HiRes::sleep( $wait ) }

sub _poll ($self) {
    $self->{_timers}->@* || $self->_poll_queues
}

sub _poll_queues ($self) {
    $self->{_signal_queue}->@*   ||
    $self->{_callback_queue}->@* ||
    $self->{_message_queue}->@*
}

sub LOOP ($self, $logger=undef) {
    $self->_init_time;

    my $tick       = $self->tick;
    my $start_loop = $self->now;

    $logger->log_tick( $logger->INFO, $self, $tick, 'START' ) if $logger;

    my $tick_delay    = $self->{tick_delay};
    my $total_elapsed = 0;
    my $total_slept   = 0;
    my $total_waited  = 0;

    my $early_timers = 0;
    my $late_timers  = 0;

    while ( $self->_poll ){
        $tick = $self->_update_tick;

        my $start_tick = $self->now;
        $logger->log_tick( $logger->INFO, $self, $tick ) if $logger;

        $self->TICK;

        my $elapsed = $self->now - $start_tick;
        $logger->log_tick_stat( $logger->DEBUG, $self, sprintf 'elapsed  = %f' => $elapsed ) if $logger;

        my $waited = 0;
        # if we have timers, but nothing in the queues ...
        if ( $self->{_timers}->@* && !$self->_poll_queues ) {

            my $timers     = $self->{_timers};
            my $next_timer = $timers->[0];
            # if the timer is no active ...
            while ( $next_timer && ${$next_timer->[2]} ) {
                shift @$timers; # get rid of it
                # and try the next one
                $next_timer = $timers->[0];
            }

            if ( $next_timer ) {
                my $now        = $self->now;
                my $wait       = $next_timer->[0] - $now;
                # do not wait for negative values ...
                # typically this is timeouts of 0 being
                # set in the previous tick, which means
                # that the timer is essentially already
                # late.
                if ($wait > 0) {
                    $early_timers++;
                    # XXX - should have some kind of max-timeout here
                    $logger->log_tick_wait( $logger->INFO, $self, sprintf 'WAITING(%f)' => $wait ) if $logger;
                    $self->sleep( $wait );
                    $total_waited += $wait;
                    $waited = $wait;
                }
                else {
                    # XXX - should we fire the timers if we
                    # find they're late? or let the next loop
                    # handle it? I am inclinded towards the
                    # next loop as it should at least be in
                    # the next tick if it is a timeout of 0
                    # but if it was just a long running tick
                    # then maybe we should run them. Hmmm??
                    $late_timers++;
                    #warn "next-timer: $next_timer now: $now wait: $wait\n";
                    #use Data::Dumper;
                    #warn $self->{_timers}->[0]->[1];
                }
            }
        }

        # support tick_delay parameter
        if ( defined $tick_delay && ($elapsed + $waited) < $tick_delay ) {
            my $wait = $tick_delay - ($elapsed + $waited);
            $logger->log_tick_pause( $logger->DEBUG, $self, sprintf 'PAUSING(%f)' => $wait ) if $logger;
            $self->sleep( $wait );
            $total_slept += $wait;
        }

        $total_elapsed += $elapsed;

        $logger->log_tick_stat( $logger->DEBUG, $self, sprintf 'uptime   = %f' => ($total_elapsed + $total_slept + $total_waited) ) if $logger;
        $logger->log_tick_loop_stat( $logger->DEBUG, $self, 'running  =' ) if $logger;
    }

    $self->_update_tick;
    my $elapsed      = $self->now - $start_loop;
    my $total_system = ($elapsed - ($total_elapsed + $total_slept + $total_waited));

    if ($logger) {
        $logger->log_tick( $logger->INFO, $self, $tick, 'END' );
        $logger->log_tick_loop_stat( $logger->DEBUG, $self, 'ZOMBIES:' );
        my $format = join "\n" =>
                        'TOTALS:',
                        '    timers_run         : %d  (early: %d, late: %d = loss: ~%0.3f%%)',
                        '    callbacks_run      : %d',
                        '    signals_handled    : %d',
                        '    messages_processed : %d',
                        'TIMINGS:',
                        '    %6s = (%f)',
                        '    %6s = (%f) %5.2f%%',
                        '    %6s = (%f) %5.2f%%',
                        '    %6s = (%f) %5.2f%%',
                        '    %6s = (%f) %5.2f%%';
        $logger->log_tick_stat( $logger->DEBUG, $self,
            sprintf $format => (
                $TIMERS_RUN,
                    $early_timers,
                    $late_timers,
                    ($late_timers && $TIMERS_RUN ? (($late_timers / $TIMERS_RUN) * 100) : 0),
                $CALLBACKS_RUN,
                $SIGNALS_HANDLED,
                $MESSAGES_PROCESSED,
                total => $elapsed,
                map  { $_->@* }
                sort { $b->[-1] <=> $a->[-1] }
                [ system => $total_system,  (($total_system  / $elapsed) * 100) ],
                [ user   => $total_elapsed, (($total_elapsed / $elapsed) * 100) ],
                [ slept  => $total_slept,   (($total_slept   / $elapsed) * 100) ],
                [ waited => $total_waited,  (($total_waited  / $elapsed) * 100) ],
            )
        );
    }

    if ( $ENV{ELO_LOOP_DUMP_STATS} ) {
        my $format = join "\n" =>
                            'TOTALS:',
                            '    timers_run         : %d  (early: %d, late: %d = loss: ~%0.3f%%)',
                            '    callbacks_run      : %d',
                            '    signals_handled    : %d',
                            '    messages_processed : %d',
                            'TIMINGS:',
                            '    %6s = (%f)',
                            '    %6s = (%f) %5.2f%%',
                            '    %6s = (%f) %5.2f%%',
                            '    %6s = (%f) %5.2f%%',
                            '    %6s = (%f) %5.2f%%','';

                                 ;
        warn sprintf $format => (
            $TIMERS_RUN,
                $early_timers,
                $late_timers,
                (($late_timers / ($TIMERS_RUN || 1)) * 100),
            $CALLBACKS_RUN,
            $SIGNALS_HANDLED,
            $MESSAGES_PROCESSED,
            total => $elapsed,
            map  { $_->@* }
            sort { $b->[-1] <=> $a->[-1] }
            [ system => $total_system,  (($total_system  / ($elapsed || 1)) * 100) ],
            [ user   => $total_elapsed, (($total_elapsed / ($elapsed || 1)) * 100) ],
            [ slept  => $total_slept,   (($total_slept   / ($elapsed || 1)) * 100) ],
            [ waited => $total_waited,  (($total_waited  / ($elapsed || 1)) * 100) ],
        );
    }

    return;
}

sub run ($self, $f, $args=undef, $logger=undef) {
    # NOTE:
    # we support both the old style $f behavior for init
    # where it is expected to run like any other process
    # AND
    # the better version which is an Actor usually with a
    # setup behavior that will just work where needed

    my $init = $self->create_process( blessed $f ? $f : init => $f );
    $self->enqueue_msg([ $init, $args // [] ]) if not blessed $f;
    $self->LOOP( $logger );
    return;
}

1;

__END__

=pod

=cut

