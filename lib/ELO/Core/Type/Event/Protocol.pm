package ELO::Core::Type::Event::Protocol;
use v5.36;

use parent 'ELO::Core::Type';
use slots (
    events => sub {},
);

sub events ($self) { $self->{events}->@* }

1;

__END__

=pod

=cut
