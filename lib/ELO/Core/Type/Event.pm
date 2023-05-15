package ELO::Core::Type::Event;
use v5.36;

use parent 'ELO::Core::Type';
use slots (
    definition => sub {},
);

sub definition ($self) { $self->{definition}->@* }

1;

__END__

=pod

=cut
