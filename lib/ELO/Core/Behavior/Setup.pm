package ELO::Core::Behavior::Setup;
use v5.36;

use Carp 'confess';

use parent 'ELO::Core::Behavior';

sub new ($class, %args) {
    my $self = {};

    $self->{name}  = $args{name}  // confess 'A `name` must be provided';
    $self->{setup} = $args{setup} // confess 'A `setup` must be provided';

    return bless $self => $class;
}

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
