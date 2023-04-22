package ELO::Core::Process;
use v5.36;

use parent 'ELO::Core::Abstract::Process';
use slots (
    name   => sub { die 'A `name` is required' },
    func   => sub { die 'A `func` is required' },
);

sub name ($self) { $self->{name} }
sub func ($self) { $self->{func} }

sub apply ($self, $event) {
    $self->{func}->( $self, $event );
}

1;

__END__

=pod

=cut
