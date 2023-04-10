package ELO::Core::Process;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

our $PIDS = 0;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    name   => sub { die 'A `name` is required'   },
    func   => sub { die 'A `func` is required'   },
    loop   => sub { die 'A `loop` is required'   },
    parent => sub { die 'A `parent` is required' },
    # ...
    _pid   => sub {},
    _queue => sub {},
    _env   => sub {},
);

sub BUILD ($self, $params) {
    $self->{_pid}   = sprintf '%03d:%s' => ++$PIDS, $self->{name};
    $self->{_queue} = [];
    $self->{_env}   = { ($params->{env} // $params->{ENV} // {})->%* };
}

sub pid ($self) { $self->{_pid} }

sub env ($self, $key) {
    $self->{_env}->{ $key };
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

sub send ($self, $proc, $event) :method {
    $self->{loop}->enqueue_msg([ $proc, $event ]);
}

sub send_to_self ($self, $event) {
    $self->{loop}->enqueue_msg([ $self, $event ]);
}

# ...

sub accept ($self, $event) {
    push $self->{_queue}->@* => $event;
}

sub tick ($self) {
    my $event = shift $self->{_queue}->@*;
    $self->{func}->( $self, $event );
}

1;

__END__

=pod

=cut
