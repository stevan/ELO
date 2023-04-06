package ELO::Process;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

our $PIDS = 0;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    name   => sub {},
    func   => sub {},
    loop   => sub {},
    parent => sub {},
    # ...
    _pid   => sub {},
    _queue => sub {},
);

sub BUILD ($self, $) {
    $self->{_pid}   = sprintf '%03d:%s' => ++$PIDS, $self->{name};
    $self->{_queue} = [];
}

sub pid ($self) { $self->{_pid} }

# ...

sub name   ($self) { $self->{name}   }
sub func   ($self) { $self->{func}   }
sub parent ($self) { $self->{parent} }

# ...

sub loop ($self) { $self->{loop} }

sub spawn ($self, $name, $f) {
    $self->{loop}->create_process( $name, $f, $self );
}

sub send ($self, $proc, $event) :method {
    $self->{loop}->enqueue_msg([ $proc, $event ]);
}

sub send_to_self ($self, $event) {
    $self->{loop}->enqueue_msg([ $self, $event ]);
}

sub next_tick ($self, $f) {
    $self->{loop}->enqueue_callback( $f );
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
