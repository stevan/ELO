package ELO::Process;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

our $PIDS = 0;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    name => sub {},
    func => sub {},
    loop => sub {},
    # ...
    _pid => sub {},
    # TODO: add _parent_pid here, it should be
    # resolvable at contruction, so we are
    # still immutable ;)
);

sub BUILD ($self, $) {
    $self->{_pid} = sprintf '%03d:%s' => ++$PIDS, $self->{name}
}

sub pid ($self) { $self->{_pid} }

sub call ($self, @args) {
    $self->{func}->( $self, @args );
}

sub spawn ($self, $name, $f) {
    # TODO:
    # we should set the parent process here
    # so that we have a process hierarchy
    $self->{loop}->create_process( $name, $f );
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
