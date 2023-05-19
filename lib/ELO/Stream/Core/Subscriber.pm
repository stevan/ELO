package ELO::Stream::Core::Subscriber;
use v5.36;

use roles 'ELO::Stream::Subscriber';
use slots (
    on_subscribe => sub {},
    on_complete  => sub {},
    on_error     => sub {},
    on_next      => sub {},
);

# ...

sub on_subscribe ($self, $subscription) {
    $self->{on_subscribe}->($self, $subscription) if $self->{on_subscribe};
    return;
}

sub on_complete ($self) {
    $self->{on_complete}->($self) if $self->{on_complete};
    return;
}

sub on_error ($self, $e) {
    $self->{on_error}->($self, $e) if $self->{on_error};
    return;
}

sub on_next ($self, $v) {
    $self->{on_next}->($self, $v) if $self->{on_next};
    return;
}

1;

__END__
