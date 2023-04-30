package ELO::Core::Type;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    symbol  => sub {},
    checker => sub {},
    # NOTE: maybe add something related to
    # being able to use the type locally
    # only, ... or to not be able to be
    # distributed/network-portable. But we
    # do not need this for now, so we can
    # leave it off.
);

sub symbol  ($self) { $self->{symbol} }

sub check ($self, $value) {
    #warn "INSIDE CHECK: ",B::svref_2object( \$value );
    $self->{checker}->( $value ) }

1;

__END__

=pod

=cut
