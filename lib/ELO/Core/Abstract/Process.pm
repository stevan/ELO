package ELO::Core::Abstract::Process;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Carp 'confess';

my $PIDS = 0;

use ELO::Constants qw[ $SIGEXIT ];

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    loop   => sub {},
    parent => sub {},
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
    $self->{_pid}         = sprintf '%03d:%s' => ++$PIDS, $self->name;
}

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

sub apply ($self) {
    confess 'The method `apply` must be overriden for ('.$self->{_pid}.')';
}

sub name ($self) {
    confess 'The method `name` must be overriden for ('.$self.')';
}

# ...

sub pid ($self) { $self->{_pid} }

sub env ($self, $key) {
    $self->{_environment}->{ $key };
    # XXX - should we check the parent
    # if we find nothing in the local?
}

# ...

sub parent     ($self) {    $self->{parent} }
sub has_parent ($self) { !! $self->{parent} }

# ...

sub loop ($self) { $self->{loop} }

sub spawn ($self, $name, $f, $env=undef) {
    $self->{loop}->create_process( $name, $f, $env, $self );
}

sub spawn_actor ($self, $actor_class, $actor_args={}, $env=undef) {
    $self->{loop}->create_actor( $actor_class, $actor_args, $env, $self );
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

sub send ($self, $proc, $event) : method {
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

