package ELO::Core::Type::Tuple;
use v5.36;

use parent 'ELO::Core::Type';
use slots (
    definition  => sub {},
    constructor => sub {},
);

sub definition ($self) { $self->{definition}->@* }

sub has_constructor ($self) { !! $self->{constructor} }
sub constructor     ($self) {    $self->{constructor} }

1;

__END__

=pod

=cut
