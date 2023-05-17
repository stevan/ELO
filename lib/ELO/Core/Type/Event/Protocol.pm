package ELO::Core::Type::Event::Protocol;
use v5.36;
use experimental 'builtin';

use builtin 'blessed';

use parent 'ELO::Core::Type';
use slots (
    events => sub {},
);

sub BUILD ($self, $) {
    $self->{checker} = sub ( $msg ) {
        return unless ref $msg eq 'ARRAY';
        my ($event_type, @args) = @$msg;
        return unless defined $event_type;
        return unless exists $self->{events}->{ $event_type };
        return unless $self->{events}->{ $event_type } isa ELO::Core::Type;
        return $self->{events}->{ $event_type }->check( \@args );
    };
}

sub events ($self) { $self->{events} }

1;

__END__

=pod

=cut
