package ELO::Stream::Core::Publisher;
use v5.36;

use roles 'ELO::Stream::Publisher';
use slots (
    subscriptions => sub { [] },
);

sub create_subscription_for;

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

1;

__END__
