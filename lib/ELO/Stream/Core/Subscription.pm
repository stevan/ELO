package ELO::Stream::Core::Subscription;
use v5.36;

use roles 'ELO::Stream::Subscription';
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
