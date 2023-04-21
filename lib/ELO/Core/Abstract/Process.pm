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
    $self->{_pid}         = sprintf '%03d:%s' => ++$PIDS, $self->name;
    $self->{_flags}       = { trap_signals => {} };
    $self->{_msg_inbox}   = [];
    $self->{_environment} = { ($params->{env} // $params->{ENV} // {})->%* };
}

sub tick ($self) {
    my $event = shift $self->{_msg_inbox}->@*;
    # XXX - add trampoline here
    $self->apply( $event );
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

sub exit ($self, $status=0) {
    #warn "EXITING FOR ".$self->pid;
    $self->{loop}->destroy_process( $self );
    #warn "FINSIHED EXITING FOR ".$self->pid;
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

# ...

sub accept ($self, $event) {
    push $self->{_msg_inbox}->@* => $event;
}

1;

__END__

=pod

=cut

