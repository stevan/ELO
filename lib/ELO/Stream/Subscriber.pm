package ELO::Stream::Subscriber;
use v5.36;

use parent 'UNIVERSAL::Object';
use roles 'ELO::Stream::API::Subscriber';
use slots (
    on_subscribe => sub {},
    on_complete  => sub {},
    on_error     => sub {},
    on_next      => sub {},
    is_completed => sub { 0 },
);

# ...

sub is_completed ($self, $val=undef) {
    $self->{is_completed} = $val if defined $val;
    $self->{is_completed};
}

# ...

sub on_subscribe ($self, $subscription) {
    $self->{on_subscribe}->($self, $subscription) if $self->{on_subscribe};
    return;
}

sub on_complete ($self) {
    $self->{on_complete}->($self) if $self->{on_complete};
    $self->is_completed(1);
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
