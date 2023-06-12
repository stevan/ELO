package ELO::Core::Type;
use v5.36;
use experimental 'try';

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    symbol  => sub {},
    checker => sub {},
    params  => sub {},
);

sub symbol  ($self) { $self->{symbol}  }
sub checker ($self) { $self->{checker} }

sub build_params_checker ($self, %params) {

    die "Could not apply params(".(keys %params).') to '.$self->{symbol}.' it does not have any params'
        unless $self->{params};

    die "You can only pass one parameter"
        unless 1 == scalar keys %params;

    my ($parameter, $arguments) = %params;

    die "Invalid parameter ($parameter) for ".$self->{symbol}
        unless exists $self->{params}->{$parameter};

    return $self->{params}->{$parameter}->( @$arguments );
}

sub check ($self, $value) {
    try {
        $self->checker->( $value )
    } catch ($e) {
        use Data::Dumper;
        die Dumper [ "TYPE CHECK FAILED!", $e, $self ];
    }
}

1;

__END__

=pod

=cut
