package ELO::Core::Behavior::Setup;
use v5.36;

use parent 'UNIVERSAL::Object';
use roles  'ELO::Core::Behavior';
use slots (
    name     => sub { die 'A `name` is required' },
    setup    => sub { die 'A `setup` is required' },
    behavior => sub {},
);

sub name ($self) { $self->{name} }

sub apply ($self, $this, $event) {
    unless ( $self->{behavior} ) {
        $self->{behavior} = $self->{setup}->( $this );
    }

    $self->{behavior}->apply( $this, $event );
}

1;

__END__

=pod

=cut
