package ELO::Core::Process;
use v5.36;

use Carp 'confess';

my $PIDS = 0;

use ELO::Types qw[ *SIGEXIT ];

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

sub new ($class, %args) {

    my $self = {};

    $self->{behavior} = $args{behavior} // confess 'A `behavior` is required';
    $self->{loop}     = $args{loop}     // confess 'A `loop` is required';
    $self->{parent}   = $args{parent}   // undef;

    bless $self => $class;

    $self->{_msg_inbox} = [];
    $self->{_flags}     = { trap_signals => {}, sleep_timer => undef, status => 1 };
    $self->{_pid}       = sprintf '%03d:%s' => ++$PIDS, $self->{behavior}->name;

    if ( $self->{behavior} isa ELO::Core::Behavior::Setup ) {
        $self->{behavior} = $self->{behavior}->setup( $self );
    }

    return $self;
}

# ...

sub behavior ($self) { $self->{behavior} }

sub apply ($self, $event) {
    $self->{behavior}->apply( $self, $event );
}

# ...

sub trap ($self, $signal) {
    $self->{_flags}->{trap_signals}->{ $signal }++;
}

sub is_trapping ($self, $signal) {
    !! exists $self->{_flags}->{trap_signals}->{ $signal };
}

sub is_sleeping ($self) { !! $self->{_flags}->{sleep_timer} }

sub is_alive ($self) { !! $self->{_flags}->{status} }

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

# ...

sub parent     ($self) {    $self->{parent} }
sub has_parent ($self) { !! $self->{parent} }

# ...


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


sub loop ($self) { $self->{loop} }

sub spawn ($self, @args) {
    $self->{loop}->create_process( @args, $self );
}

sub kill ($self, $proc) {
    $self->signal( $proc, *SIGEXIT, [ $self ] );
}

sub exit ($self, $status=0) {

    $self->{loop}->destroy_process( $self );

    $self->{_flags}->{status} = $status;
}

# ...

sub signal ($self, $proc, $signal, $event) {
    $self->{loop}->enqueue_signal([ $proc, $signal, $event ]);
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

