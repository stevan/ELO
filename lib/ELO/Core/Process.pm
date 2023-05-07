package ELO::Core::Process;
use v5.36;

use Carp 'confess';

my $PIDS = 0;

use ELO::Constants qw[ $SIGEXIT ];

use overload (
    fallback => 1,
    # some operators to make things interesting ;)
    '<<=' => sub ($self, $event, @) {
        $self->send_to_self( $event );
        $self;
    },
    '>>=' => sub ($self, $msg, @) {
        $self->send( @$msg );
        $self;
    }
);

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    behavior => sub { die 'A `behavior` is required' },
    loop     => sub { die 'A `loop` is required' },
    parent   => sub {},
    # ...
    _pid           => sub {},
    _flags         => sub {},
    _msg_inbox     => sub {},
    _environment   => sub {},
);

sub BUILD ($self, $params) {
    $self->{_msg_inbox}   = [];
    $self->{_flags}       = { trap_signals => {}, sleep_timer => undef };
    $self->{_environment} = { ($params->{env} // $params->{ENV} // {})->%* };
    $self->{_pid}         = sprintf '%03d:%s' => ++$PIDS, $self->{behavior}->name;
}

# XXX - is this neccesary?
# sub DEMOLISH ($self, @args) {
#     delete $self->{loop};
#     delete $self->{parent};
# }

# ...

sub apply ($self, $event) {
    $self->{behavior}->apply( $self, $event );
}

# ...

sub is_sleeping ($self) { !! $self->{_flags}->{sleep_timer} }

sub has_pending_messages ($self) { scalar $self->{_msg_inbox}->@* }

sub get_pending_messages ($self) { $self->{_msg_inbox}->@* }

#use Data::Dumper;

sub accept ($self, $event) {
    push $self->{_msg_inbox}->@* => $event;
    #warn Dumper [ accepted_message => $self->pid => $self->{_msg_inbox} ];
}

sub tick ($self) {
    # if we are sleeping, we just
    # return here until we wake up
    # at which time we will process
    # stuff in the next tick
    return if $self->is_sleeping;

    #warn Dumper [ start_tick => $self->pid => $self->{_msg_inbox} ];

    # process all the messages in the inbox ...
    while ( my $event = shift $self->{_msg_inbox}->@* ) {

        #warn Dumper [ before_apply => $self->pid => $self->{_msg_inbox} ];

        # XXX - add trampoline here
        $self->apply( $event );

        #warn Dumper [ after_apply => $self->pid => $self->{_msg_inbox} ];

        # if we are sleeping again,
        # then stop processing messages
        last if $self->is_sleeping;
    }

    #warn Dumper [ end_tick => $self->pid => $self->{_msg_inbox} ];
}

# ...

sub pid  ($self) { $self->{_pid} }
sub name ($self) { $self->{behavior}->name }

sub env ($self, $key) {
    my $value = $self->{_environment}->{ $key };
    if ( !(defined $value) && $self->parent ) {
        $value = $self->parent->env( $key );
    }
    return $value;
}

# ...

sub parent     ($self) {    $self->{parent} }
sub has_parent ($self) { !! $self->{parent} }

# ...

sub loop ($self) { $self->{loop} }

sub spawn ($self, $name, $f, $env=undef) {
    $self->{loop}->create_process( $name, $f, $env, $self );
}

sub spawn_actor ($self, $actor, $env=undef) {
    $self->{loop}->create_actor( $actor, $env, $self );
}

sub kill ($self, $proc) {
    $self->signal( $proc, $SIGEXIT, [ $self ] );
}

sub sleep ($self, $duration) {
    die 'This should not be possible' if $self->{_flags}->{sleep_timer};

    $self->{_flags}->{sleep_timer} = $self->{loop}->add_timer(
        $duration,
        sub { $self->wakeup }
    );
}

sub wakeup ($self) {
    return unless $self->{_flags}->{sleep_timer};
    $self->{loop}->cancel_timer( $self->{_flags}->{sleep_timer} );
    $self->{_flags}->{sleep_timer} = undef;
    $self->tick;
}

sub exit ($self, $status=0) {

    $self->{loop}->destroy_process( $self );

    $status;
}

# ...

sub signal ($self, $proc, $signal, $event) {
    $self->{loop}->enqueue_signal([ $proc, $signal, $event ]);
}

sub trap ($self, $signal) {
    $self->{_flags}->{trap_signals}->{ $signal }++;
}

sub is_trapping ($self, $signal) {
    !! exists $self->{_flags}->{trap_signals}->{ $signal };
}

# ...

sub send ($self, $proc, $event) {
    $self->{loop}->enqueue_msg([ $proc, $event ]);
}

sub send_to_self ($self, $event) {
    $self->{loop}->enqueue_msg([ $self, $event ]);
}

# ...

sub link ($self, $process) {
    $self->{loop}->link_process( $self, $process );
}

sub unlink ($self, $process) {
    $self->{loop}->unlink_process( $self, $process );
}


1;

__END__

=pod

=cut

