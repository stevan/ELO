package ELO::Core::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Carp         'confess';
use Scalar::Util 'blessed';
use List::Util   'uniq';
use Time::HiRes  ();

use ELO::Core::Process;
use ELO::Core::ActorRef;
use ELO::Constants qw[ $SIGEXIT ];

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

sub create_actor ($self, $actor_class, $actor_args, $env=undef, $parent=undef) {
    my $actor_ref = ELO::Core::ActorRef->new(
        actor_class => $actor_class,
        actor_args  => $actor_args,
        loop        => $self,
        parent      => $parent,
        env         => $env,
    );
    $self->{_process_table}->{ $actor_ref->pid } = $actor_ref;
    return $actor_ref;
}

sub destroy_actor ($self, $actor) {
    $self->destroy_process( $actor );
}

sub create_process ($self, $name, $f, $env=undef, $parent=undef) {
    my $process = ELO::Core::Process->new(
        name   => $name,
        func   => $f,
        loop   => $self,
        parent => $parent,
        env    => $env,
    );
    $self->{_process_table}->{ $process->pid } = $process;
    return $process;
}

sub destroy_process ($self, $process) {
    # tell everyone bye
    $self->notify_links( $process );

    # remove self from the process table ...
    delete $self->{_process_table}->{ $process->pid };

    # remove the process links as well ..
    delete $self->{_process_links}->{ $process->pid };

    # remove any other references to
    # the process in other links
    foreach my $links ( values $self->{_process_links}->%* ) {
        @$links = grep { $_->pid ne $process->pid } @$links;
    }

    # remove signals for this process currently in the queue
    $self->{_signal_queue}->@* = grep {
        (blessed $_->[0] ?  $_->[0]->pid : $_->[0]) ne $process->pid
    } $self->{_signal_queue}->@*;

    # remove messages for this process currently in the queue
    $self->{_message_queue}->@* = grep {
        (blessed $_->[0] ?  $_->[0]->pid : $_->[0]) ne $process->pid
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
            # $process->signal( $link, $SIGEXIT, [ $process ] );
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
    # Timer = [ $time, $f ]
    push $self->{_timers}->@* => [ $self->now + $timeout, $f ];
    # ... always keep them sorted
    $self->{_timers}->@* = sort { $a->[0] <=> $b->[0] } $self->{_timers}->@*;
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
    # FIXME:
    # this is gross, do better ...

    my $is_alive = 0;
    eval {
        # this will lookup the process
        $proc = $self->lookup_process( $proc );
        # and mark success for it
        $is_alive = 1;
    } or do {
        my $e = $@;
        # do nothing here ...
    };
    # it either worked and got set
    # or it did not so is false
    return $is_alive;
}

sub lookup_process ($self, $to_proc) {

    # if we have a PID, then look it up
    if (not blessed $to_proc) {
        die "Unable to find process for PID($to_proc)"
            unless exists $self->{_process_table}->{ $to_proc };

        # we know it is active, so we can just return it
        return $self->{_process_table}->{ $to_proc };
    }

    # otherwise we have a Process object ...
    confess "The process PID(".$to_proc->pid.") is not active"
        # so make sure it is active
        unless exists $self->{_process_table}->{ $to_proc->pid };

    # and return it
    return $to_proc;
}

# ...

sub TICK ($self) {

    # Signals are handled first, as they
    # are meant to be async interrupts
    # (ala unix signals) but we wont
    # interrupt any other code, so we
    # do the next best-ish thing by
    # handling the signals first, even before
    # the timers, even though they are
    # time sensitive ...
    my @sig_queue = $self->{_signal_queue}->@*;
    $self->{_signal_queue}->@* = ();

    while (@sig_queue) {
        my $sig = shift @sig_queue;
        my ($to_proc, $signal, $event) = @$sig;

        # XXX - this can die ... catch it?
        eval {
            $to_proc = $self->lookup_process( $to_proc );
            1;
        } or do {
            my $e = $@;
            use Data::Dumper;
            warn Dumper { e => $e, sig => $sig, queue => \@sig_queue };
            die $e;
        };

        # is the signal trapped?
        if ( $to_proc->is_trapping( $signal ) ) {

            # convert this into a message
            $to_proc->accept( [ $signal, @$event ] );

            # run the tick
            eval {
                $to_proc->tick;
                1;
            } or do {
                my $e = $@;
                die "Unhandled signal for (".$to_proc->pid.") failed with sig($signal, ".(join ', ' => @{ $event // []}).") because: $e";
            };
        }
        else {
            if ( $signal eq $SIGEXIT ) {
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
        eval {
            $timer->[1]->(); 1;
        } or do {
            my $e = $@;
            die "Timer callback failed ($timer) because: $e";
        };
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
        eval {
            $f->(); 1;
        } or do {
            my $e = $@;
            die "Callback failed ($f) because: $e";
        };
    }

    my @msg_queue = $self->{_message_queue}->@*;
    $self->{_message_queue}->@* = ();

    while (@msg_queue) {
        my $msg = shift @msg_queue;
        my ($to_proc, $event) = @$msg;

        eval {
            $to_proc = $self->lookup_process( $to_proc );
            $to_proc->accept( $event );
            $to_proc->tick;
            1;
        } or do {
            my $e = $@;

            use Data::Dumper;
            warn Dumper { msg => $msg, queue => \@msg_queue };

            die "Message to (".$to_proc->pid.") failed with msg(".(join ', ' => @{ $event // []}).") because: $e";
        };
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
            my $wait = $self->{_timers}->[0]->[0] - $self->now;
            # XXX - should have some kind of max-timeout here
            $logger->log_tick_wait( $logger->INFO, $self, sprintf 'WAITING(%f)' => $wait ) if $logger;
            $self->sleep( $wait );
            $total_waited += $wait;
            $waited = $wait;
        }

        # support tick_delay parameter
        if ( defined $tick_delay && ($elapsed + $waited) < $tick_delay ) {
            my $wait = $tick_delay - ($elapsed + $waited);
            $logger->log_tick_pause( $logger->DEBUG, $self, sprintf 'PAUSING(%f)' => $wait ) if $logger;
            $self->sleep( $wait );
            $total_slept += $wait;
        }

        $total_elapsed += $elapsed;

        $logger->log_tick_loop_stat( $logger->DEBUG, $self, 'running  =' ) if $logger;
    }

    $self->_update_tick;
    my $elapsed      = $self->now - $start_loop;
    my $total_system = ($elapsed - ($total_elapsed + $total_slept + $total_waited));

    if ($logger) {
        $logger->log_tick( $logger->INFO, $self, $tick, 'END' );
        $logger->log_tick_loop_stat( $logger->DEBUG, $self, 'ZOMBIES:' );
        my $format = join "\n   " =>
                        'TIMINGS:',
                            '%6s = (%f)',
                            '%6s = (%f) %5.2f%%',
                            '%6s = (%f) %5.2f%%',
                            '%6s = (%f) %5.2f%%',
                            '%6s = (%f) %5.2f%%';
        $logger->log_tick_stat( $logger->DEBUG, $self,
            sprintf $format => (
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

    return;
}

sub run ($self, $f, $args=[], $logger=undef, $env=undef) {
    my $main = $self->create_process( main => $f, $env );
    $self->enqueue_msg([ $main, $args ]);
    $self->LOOP( $logger );
    return;
}

sub run_actor ($self, $actor_class, $actor_args={}, $logger=undef, $env=undef) {
    my $root = $self->create_actor( $actor_class, $actor_args, $env );
    $self->LOOP( $logger );
    return;
}

1;

__END__

=pod

=cut

