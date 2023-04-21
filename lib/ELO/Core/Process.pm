package ELO::Core::Process;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use parent 'ELO::Core::Abstract::Process';
use slots (
    name   => sub { die 'A `name` is required' },
    func   => sub { die 'A `func` is required' },
);

sub name ($self) { $self->{name} }
sub func ($self) { $self->{func} }

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
