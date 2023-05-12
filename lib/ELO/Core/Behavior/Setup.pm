package ELO::Core::Behavior::Setup;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use roles  'ELO::Core::Behavior';
use slots (
    name     => sub { die 'A `name` is required' },
    setup    => sub { die 'A `setup` is required' },
);

sub name ($self) { $self->{name} }

sub setup ($self, $this) {
    $self->{setup}->( $this )
}

# FIXME: this is gross ...
sub apply ($self, $this, $event) {
    die "Apply is not applicable to $self";
}

1;

__END__

=pod

=cut
