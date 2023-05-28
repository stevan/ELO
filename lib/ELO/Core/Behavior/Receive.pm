package ELO::Core::Behavior::Receive;
use v5.36;

use Carp 'confess';

use ELO::Types qw[ *SIGEXIT ];

use parent 'ELO::Core::Behavior';

sub new ($class, %args) {
    my $self = {};

    $self->{name}      = $args{name}      // confess 'A `name` must be provided';
    $self->{receivers} = $args{receivers} // confess 'A `receivers` must be provided';
    $self->{protocol}  = $args{protocol}  // confess 'A `protocol` must be provided';

    return bless $self => $class;
}

sub name ($self) { $self->{name} }

sub apply ($self, $this, $event) {
    return unless keys $self->{receivers}->%*;

    # allow SIGEXIT to be an exception
    # FIXME: this could be done better
    unless( $event->[0] eq *SIGEXIT ) {
        $self->{protocol}->check( $event )
            or die "Event::Protocol(".($self->{protocol}->symbol//'__ANON__').") failed to type check event(".(join ', ' => @$event).")";;
    }

    my ($type, @payload) = @$event;
    my $f = $self->{receivers}->{ $type }
        or die "Unable to find match for Event::Protocol(".($self->{protocol}->symbol//'__ANON__').")) with event($type)";

    $f->( $this, @payload );
}

1;

__END__

=pod

=cut
