package ELO::Core::Type::Alias;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    symbol  => sub {},
    alias   => sub {},
);

sub symbol  ($self) { $self->{symbol} }

sub check ($self, $value) {
    $self->{alias}->check( $value )
}

1;

__END__

=pod

=cut
