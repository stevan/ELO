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
    _pid => sub {},
);

sub BUILD ($self, $) {
    $self->{_pid} = sprintf '%03d:%s' => ++$PIDS, $self->{name}
}

sub pid ($self) { $self->{_pid} }

sub name   ($self) { $self->{name}   }
sub func   ($self) { $self->{func}   }
sub loop   ($self) { $self->{loop}   }
sub parent ($self) { $self->{parent} }

sub call ($self, @args) {
    $self->{func}->( $self, @args );
}

sub spawn ($self, $name, $f) {
    $self->{loop}->create_process( $name, $f, $self );
}

sub send ($self, $proc, @msg) :method {
    $self->{loop}->enqueue_msg([ $proc, @msg ]);
}

sub send_to_self ($self, @msg) {
    $self->{loop}->enqueue_msg([ $self, @msg ]);
}

1;

__END__

=pod

=cut
