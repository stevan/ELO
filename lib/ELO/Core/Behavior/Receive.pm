package ELO::Core::Behavior::Receive;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use roles  'ELO::Core::Behavior';
use slots (
    name      => sub { die 'A `name` is required' },
    receivers => sub { die 'A `receivers` is required' },
    protocol  => sub { die 'A `protocol` is required' },
);

sub name ($self) { $self->{name} }

sub apply ($self, $this, $event) {

    my ($type, @payload) = @$event;

    if ( my $event_type = $self->{protocol}->{ $type } ) {
        $event_type->check( \@payload )
            or die "Event($type) failed to type check (".(join ', ' => @payload).")";
    }
    else {
        die "Event($type) does not have a receiver in ".$self->name;
    }

    my $f = $self->{receivers}->{ $type };

    $f->( $this, @payload );
}

1;

__END__

=pod

=cut
