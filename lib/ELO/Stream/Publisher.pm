package ELO::Stream::Publisher;
use v5.36;

use parent 'UNIVERSAL::Object';
use roles 'ELO::Stream::API::Publisher', 'ELO::Stream::API::Source';
use slots (
    source               => sub { die 'You must pass a `source` to an ELO::Stream::Publisher' },
    subscription_builder => sub { die 'You must pass a `subscription_builder` to an ELO::Stream::Publisher' },
    # ...
    _subscriptions        => sub { [] },
);

# TODO: test the values in the slots in BUILD

sub create_subscription_for ($self, $subscriber, %args) {
    $self->{subscription_builder}->new(
        publisher  => $self,
        subscriber => $subscriber,
        %args
    );
}

sub subscriptions ($self) { $self->{_subscriptions}->@* }

sub subscribe ($self, $subscriber) {
    my $subscription = $self->create_subscription_for( $subscriber );

    push $self->{_subscriptions}->@* => $subscription;

    $subscriber->on_subscribe( $subscription );
    return;
}

sub unsubscribe ($self, $subscription) {
    $self->{_subscriptions}->@* = grep $_ eq $subscription, $self->{_subscriptions}->@*;
    return;
}

# ...

sub is_exhausted ($self) { $self->{source}->has_next }

sub has_next ($self) { $self->{source}->has_next }
sub next     ($self) { $self->{source}->next     }

1;

__END__
