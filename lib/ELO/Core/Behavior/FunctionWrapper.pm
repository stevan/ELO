package ELO::Core::Behavior::FunctionWrapper;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use roles  'ELO::Core::Behavior';
use slots (
    name   => sub { die 'A `name` is required' },
    func   => sub { die 'A `func` is required' },
);

sub name ($self) { $self->{name} }
sub func ($self) { $self->{func} }

sub apply ($self, $this, $event) {
    $self->{func}->( $this, $event );
}

1;

__END__

=pod

=cut
