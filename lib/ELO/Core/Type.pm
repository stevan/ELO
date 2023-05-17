package ELO::Core::Type;
use v5.36;
use experimental 'try';

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    symbol  => sub {},
    checker => sub {},
);

sub symbol  ($self) { $self->{symbol}  }
sub checker ($self) { $self->{checker} }

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
