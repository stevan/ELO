package ELO::Stream::Subscription;
use v5.36;

use parent 'UNIVERSAL::Object';
use roles 'ELO::Stream::API::Subscription';
use slots (
    publisher  => sub {},
    subscriber => sub {},
);

sub publisher  ($self) { $self->{publisher}  }
sub subscriber ($self) { $self->{subscriber} }

sub request;

sub cancel ($self) {
    $self->{publisher}->unsubscribe( $self );
    $self->{subscriber}->on_complete;
    return;
}

1;

__END__
