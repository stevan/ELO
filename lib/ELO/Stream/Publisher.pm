package ELO::Stream::Publisher;
use v5.36;

use parent 'UNIVERSAL::Object';
use roles 'ELO::Stream::API::Publisher', 'ELO::Stream::API::Source';
use slots (
    source               => sub {},
    subscriptions        => sub { [] },
    subscription_builder => sub {},
);

# TODO: test the slots in BUILD

sub create_subscription_for ($self, $subscriber) {
    $self->{subscription_builder}->new(
        publisher  => $self,
        subscriber => $subscriber,
    );
}

sub subscriptions ($self) { $self->{subscriptions} }

sub subscribe ($self, $subscriber) {
    my $subscription = $self->create_subscription_for( $subscriber );

    push $self->{subscriptions}->@* => $subscription;
    $subscriber->on_subscribe( $subscription );
    return;
}

sub unsubscribe ($self, $subscription) {
    $self->{subscriptions}->@* = grep $_ eq $subscription, $self->{subscriptions}->@*;
    return;
}

# ...

sub is_exhausted ($self) { $self->{source}->has_next }

sub has_next ($self) { $self->{source}->has_next }
sub next     ($self) { $self->{source}->next     }

1;

__END__
