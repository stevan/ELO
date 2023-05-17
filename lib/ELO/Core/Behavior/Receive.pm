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

    $self->{protocol}->check( $event )
        or die "Event::Protocol(".($self->{protocol}->symbol//'__ANON__').") failed to type check event(".(join ', ' => @$event).")";;

    my ($type, @payload) = @$event;
    my $f = $self->{receivers}->{ $type }
        or die "Unable to find match for Event::Protocol(".($self->{protocol}->symbol//'__ANON__').")) with event($type)";

    $f->( $this, @payload );
}

1;

__END__

=pod

=cut
