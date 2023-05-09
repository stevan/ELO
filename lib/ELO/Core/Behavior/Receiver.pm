package ELO::Core::Behavior::Receiver;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use roles  'ELO::Core::Behavior';
use slots (
    name      => sub { die 'A `name` is required' },
    receivers => sub { die 'A `receivers` is required' },
    # ...
    _event_lookup => sub {},
);

sub name ($self) { $self->{name} }

sub apply ($self, $this, $event) {

    my ($type, @payload) = @$event;

    if ( my $event_type = $self->{_event_lookup}->( $type ) ) {
        $event_type->check( @payload )
            or die "Event($event) failed to type check (".(join ', ' => @payload).")";
    }

    my $f = $self->{receivers}->{ $type } // do {
        die 'Could not find receiver for type('.$type.')';
    };

    $f->( $this, @payload );
}

1;

__END__

=pod

=cut
