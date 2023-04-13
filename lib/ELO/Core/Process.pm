package ELO::Core::Process;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

my $PIDS = 0;

use ELO::Core::Constants qw[ $SIGEXIT ];

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    name   => sub { die 'A `name` is required'   },
    func   => sub { die 'A `func` is required'   },
    loop   => sub { die 'A `loop` is required'   },
    parent => sub { die 'A `parent` is required' },
    # ...
    _pid           => sub {},
    _trap_signals  => sub {},
    _msg_inbox     => sub {},
    _environment   => sub {},
);

sub BUILD ($self, $params) {
    $self->{_pid}          = sprintf '%03d:%s' => ++$PIDS, $self->{name};
    $self->{_trap_signals} = {};
    $self->{_msg_inbox}    = [];
    $self->{_environment}  = { ($params->{env} // $params->{ENV} // {})->%* };
}

sub pid ($self) { $self->{_pid} }

sub env ($self, $key) {
    $self->{_environment}->{ $key };
    # XXX - should we check the parent
    # if we find nothing in the local?
}

# ...

sub name   ($self) { $self->{name}   }
sub func   ($self) { $self->{func}   }
sub parent ($self) { $self->{parent} }

# ...

sub loop ($self) { $self->{loop} }

sub spawn ($self, $name, $f, $env=undef) {
    $self->{loop}->create_process( $name, $f, $env, $self );
}

sub kill ($self, $proc) {
    $self->signal( $proc, $SIGEXIT, [ $self ] );
}

sub exit ($self, $status=0) {
    #warn "EXITING FOR ".$self->pid;
    $self->{loop}->notify_links( $self );
    $self->{loop}->destroy_process( $self );
    #warn "FINSIHED EXITING FOR ".$self->pid;
}

# ...

sub signal ($self, $proc, $signal, $event) {
    $self->{loop}->enqueue_signal([ $proc, $signal, $event ]);
}

sub trap ($self, $signal) {
    $self->{_trap_signals}->{ $signal }++;
}

sub is_trapped ($self, $signal) {
    !! exists $self->{_trap_signals}->{ $signal };
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

# ...

sub accept ($self, $event) {
    push $self->{_msg_inbox}->@* => $event;
}

sub tick ($self) {
    my $event = shift $self->{_msg_inbox}->@*;
    # XXX
    # should we add a trampoline here to catch
    # the exits and turn them into signals?
    $self->{func}->( $self, $event );
}

1;

__END__

=pod

=cut
