package ELO::Core::ActorRef;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Scalar::Util 'blessed';
use Carp         'confess';

use ELO::Constants qw[ $SIGEXIT ];

use parent 'ELO::Core::Abstract::Process';
use slots (
    actor_class => sub {},
    actor_args  => sub { +[] },
    # ...
    _actor    => sub {},      # the instance of the actor_class, with the actor_args
    _children => sub { +[] }, # any child processes created
);

sub BUILD ($self, $params) {
    $self->trap( $SIGEXIT );

    eval {
        $self->{_actor} = $self->{actor_class}->new( +{ $self->{actor_args}->%* } );
        1;
    } or do {
        my $e = $@;
        confess 'Could not instantiate actor('.$self->{actor_class}.') because: '.$e;
    };

    # we want to call the on-start event, but we want
    # it to be sure to take place in next available
    # tick of the loop. This is expecially important
    # in the root Actor, which will get created very
    # early in the lifetime of the system
    $self->loop->next_tick(sub {
        $self->{_actor}->on_start( $self )
    });
}

sub env ($self, $key) {
    my $value = $self->next::method( $key );
    if ( $self->parent && not defined $value) {
        $value = $self->parent->env( $key );
    }
    return $value;
}

# ...

sub spawn_actor ($self, $actor_class, $actor_args={}, $env=undef) {
    my $child = $self->next::method( $actor_class, $actor_args, $env );
    push $self->{_children}->@* => $child;
    $self->link( $child );
    return $child;
}

# ...

sub name ($self) { $self->{actor_class} }

sub tick ($self) {
    my $event = shift $self->{_msg_inbox}->@*;
    $self->{_actor}->apply( $self, $event );
}

1;

__END__

=pod

=cut
