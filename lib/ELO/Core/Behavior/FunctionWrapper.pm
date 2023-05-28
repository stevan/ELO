package ELO::Core::Behavior::FunctionWrapper;
use v5.36;

use Carp 'confess';

use parent 'ELO::Core::Behavior';

sub new ($class, %args) {
    my $self = {};

    $self->{name} = $args{name} // confess 'A `name` must be provided';
    $self->{func} = $args{func} // confess 'A `func` must be provided';

    return bless $self => $class;
}

sub name ($self) { $self->{name} }
sub func ($self) { $self->{func} }

sub apply ($self, $this, $event) {
    $self->{func}->( $this, $event );
}

1;

__END__

=pod

=cut
