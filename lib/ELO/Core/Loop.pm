package ELO::Core::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Carp         'confess';
use Scalar::Util 'blessed';
use List::Util   'uniq';

use ELO::Core::Process;
use ELO::Constants qw[ $SIGEXIT ];

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    # ...
    _process_table  => sub { +{} },
    _process_links  => sub { +{} },

    _message_queue  => sub { +[] },
    _signal_queue   => sub { +[] },
    _callback_queue => sub { +[] },
);

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

sub tick ($self) {

    # Signals are handled first, as they
    # are meant to be async interrupts
    # (ala unix signals) but we wont
    # interrupt any other code, so we
    # do the next best-ish thing by
    # handling the signals first
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

sub loop ($self, $logger=undef) {
    my $tick = 0;

    $logger->tick( $logger->INFO,  $self, $tick, 'START' ) if $logger;

    while ( $self->{_signal_queue}->@*   ||
            $self->{_callback_queue}->@* ||
            $self->{_message_queue}->@*  ){

        $logger->tick( $logger->INFO,  $self, $tick ) if $logger;
        $self->tick;
        $tick++
    }

    $logger->tick( $logger->INFO,  $self, $tick, 'END'  ) if $logger;

    return;
}

sub run ($self, $f, $args=[], $logger=undef, $env=undef) {
    my $main = $self->create_process( main => $f, $env );
    $self->enqueue_msg([ $main, $args ]);
    $self->loop( $logger );
    return;
}

1;

__END__

=pod

=cut

