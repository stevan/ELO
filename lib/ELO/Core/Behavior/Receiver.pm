package ELO::Core::Behavior::Receiver;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use roles  'ELO::Core::Behavior';
use slots (
    name      => sub { die 'A `name` is required' },
    receivers => sub { die 'A `receivers` is required' },
);

sub name ($self) { $self->{name} }

sub apply ($self, $this, $event) {
    my ($type, @payload) = @$event;
    my $f = $self->{receivers}->{ $type } // do {
        die 'Could not find receiver for type('.$type.')';
    };
    $f->( $this, @payload );
}

1;

__END__

=pod

=cut
