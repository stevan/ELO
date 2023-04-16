package ELO::Core::ActorRef;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Scalar::Util 'blessed';
use Carp         'confess';

our $ACTOR_ID = 0;

use ELO::Constants qw[ $SIGEXIT ];

use parent 'UNIVERSAL::Object';
use slots (
    actor_class => sub { die 'An `actor_class` is required' },
    actor_args  => sub { die 'An `actor_args` is required'  },
    loop        => sub { die 'A `loop` is required'         },
    parent      => sub { die 'A `parent` is required'       },
    # ...
    _pid           => sub {}, # actor ID
    _actor         => sub {}, # the instance of the actor_class, with the actor_args
    _children      => sub {}, # any child processes created
    _trap_signals  => sub {}, # signals trapped by this Actor
    _msg_inbox     => sub {}, # message inbox
    _environment   => sub {}, # actors environment
);

sub BUILD ($self, $params) {
    $self->{_pid}          = sprintf '%03d:%s' => ++$ACTOR_ID, $self->{actor_class};
    $self->{_children}     = [];
    $self->{_trap_signals} = { $SIGEXIT => 1 };
    $self->{_msg_inbox}    = [];
    $self->{_environment}  = { ($params->{env} // $params->{ENV} // {})->%* };

    eval {
        $self->{_actor} = $self->{actor_class}->new( $self->{actor_args}->%* );
        1;
    } or do {
        my $e = $@;
        confess 'Could not build actor('.$self->{actor_class}.') because: '.$e;
    };
}

sub pid ($self) { $self->{_pid} }

sub env ($self, $key) {
    my $value = $self->{_environment}->{ $key };
    if ( $self->parent && not defined $value) {
        $value = $self->parent->env( $key );
    }
    return $value;
}

# ...

sub name   ($self) { $self->{name}   }
sub parent ($self) { $self->{parent} }

sub _add_child ($self, $child) {
    push $self->{_children}->@* => $child;
    $self->link( $child );
}

# ...

sub loop ($self) { $self->{loop} }

sub spawn_actor ($self, $actor_class, $actor_args={}, $env=undef) {
    my $child = $self->{loop}->create_actor( $actor_class, $actor_args, $env, $self );
    $self->_add_child( $child );
    return $child;
}

sub kill ($self, $actor) {
    $self->signal( $actor, $SIGEXIT, [ $self ] );
}

sub exit ($self, $status=0) {
    $self->{loop}->destroy_actor( $self );

    # NOTE:
    # this will trigger the link's for the
    # children and send $SIGEXIT to all of them

    # XXX: do I need to unlink? I don't think so, it should clean itself up

    # XXX: perhaps send the inbox to a dead-letter queue?

    return $status;
}

# ...

sub signal ($self, $actor, $signal, $event) {
    $self->{loop}->enqueue_signal([ $actor, $signal, $event ]);
}

sub trap ($self, $signal) {
    $self->{_trap_signals}->{ $signal }++;
}

sub is_trapping ($self, $signal) {
    !! exists $self->{_trap_signals}->{ $signal };
}

# ...

sub send ($self, $actor, $event) : method {
    $self->{loop}->enqueue_msg([ $actor, $event ]);
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

sub apply ($self, $actor, $event) {

    eval {
        die 'event must be an ARRAY ref'
            unless ref $event eq 'ARRAY';

        my ($e, @body) = @$event;

        my $receive = $actor->receive( $self );

        die 'receive did not return a HASH ref'
            unless ref $receive eq 'HASH';

        my $receiver = $receive->{ $e };
        die 'could not find receiver for event('.$e.')'
            unless defined $receiver
                    && ref $receiver eq 'CODE';

        $receiver->( @body );
        1;
    } or do {
        my $e = $@;
        die 'Receive failed because: '.$e;
    };
}

sub tick ($self) {
    my $event = shift $self->{_msg_inbox}->@*;
    $self->apply( $self->{_actor}, $event );
}

1;

__END__

=pod

=cut
