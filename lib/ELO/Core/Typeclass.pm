package ELO::Core::Typeclass;
use v5.36;
use experimental 'try';

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    type               => sub {},
    method_definitions => sub { +{} },
);

sub type ($self) { $self->{type} }

sub method_definitions ($self) { $self->{method_definitions} }

1;

__END__

=pod

=cut
