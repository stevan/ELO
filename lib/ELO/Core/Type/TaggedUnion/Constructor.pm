package ELO::Core::Type::TaggedUnion::Constructor;
use v5.36;

use parent 'ELO::Core::Type';
use slots (
    constructor => sub {},
    definition  => sub {},
);

sub definition ($self) { $self->{definition}->@* }

1;

__END__

=pod

=cut
