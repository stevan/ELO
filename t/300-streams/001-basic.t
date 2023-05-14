#!perl

use v5.36;
use experimental 'try';

use ELO::Streams;

# ...

package MySubscription {
    use v5.36;

    use parent 'UNIVERSAL::Object::Immutable';
    use roles 'ELO::Streams::Subscription';
    use slots (
        publisher  => sub {},
        subscriber => sub {},
    );

    sub BUILD ($self, $) {
        $self->{publisher}->roles::DOES('ELO::Streams::Iterator')
            || die 'The `publisher` must do the `ELO::Streams::Iterator` role ('.$self->{publisher}.')';

        $self->{subscriber}->roles::DOES('ELO::Streams::Refreshable')
            || die 'The `subscriber` must do the `ELO::Streams::Refreshable` role ('.$self->{subscriber}.')';
    }

    sub request ($self, $num_elements) {
        warn "MySubscription::request($num_elements) called\n";
        for (1 .. $num_elements) {
            if ( $self->{publisher}->has_next ) {
                $self->{subscriber}->on_next(
                    $self->{publisher}->next
                );
            }
            else {
                $self->{subscriber}->on_complete;
                last;
            }
        }

        warn "/// MySubscription::request($num_elements) should we refresh ????\n";
        if ( $self->{subscriber}->should_refresh ) {
            $self->{subscriber}->refresh;
        }
    }

    sub cancel ($self) {
        warn "MySubscription::cancel called\n";
        $self->{publisher}->unsubscribe( $self );
    }
}

package MySubscriber {
    use v5.36;

    use parent 'UNIVERSAL::Object';
    use roles 'ELO::Streams::Subscriber',
              'ELO::Streams::Refreshable';

    use slots (
        subscription => sub {},
        total_seen   => sub { 0 },
        frame_seen   => sub { 0 },
        frame_size   => sub { 10 },
    );

    # ...

    sub should_refresh ($self) {
        warn "MySubscriber::should_refresh called\n";
        $self->{frame_seen} == $self->{frame_size}
    }

    sub refresh ($self) {
        warn "MySubscriber::refresh called\n";
        $self->{frame_size} = $self->{frame_size};
        $self->{frame_seen} = 0;
        $self->{subscription}->request( $self->{frame_size});
    }

    # ...

    sub on_subscribe ($self, $subscription) {
        warn "MySubscriber::on_subscribe called with ($subscription)\n";
        $self->{subscription} = $subscription;
        $self->refresh;
    }

    sub on_complete ($self) {
        warn "MySubscriber::on_complete called\n";
    }

    sub on_error ($self, $e) {
        warn "MySubscriber::on_error called with ($e)\n";
    }

    sub on_next ($self, $i) {
        warn "MySubscriber::on_next called with arg($i)\n";
        $self->{total_seen}++;
        $self->{frame_seen}++;
    }
}

package MyPublisher {
    use v5.36;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Streams::Publisher',
               'ELO::Streams::Iterator';

    use slots (
        counter       => sub { 0 },
        max_value     => sub { 300 },
        subscriptions => sub { [] },
    );

    sub subscribe ($self, $subscriber) {
        warn "MyPublisher::subscribe called with subscriber($subscriber)\n";
        my $subscription = MySubscription->new(
            publisher  => $self,
            subscriber => $subscriber,
        );

        push $self->{subscriptions}->@* => $subscription;
        $subscriber->on_subscribe( $subscription );
    }

    sub unsubscribe ($self, $subscription) {
        warn "MyPublisher::unsubscribe called with subscription($subscription)\n";
        $self->{subscriptions}->@* = grep $_ eq $subscription, $self->{subscriptions}->@*;
    }

    sub has_next ($self) {
        warn "MyPublisher::has_next called\n";
        $self->{counter} <= $self->{max_value}
    }

    sub next ($self) {
        warn "MyPublisher::next called\n";
        return $self->{counter}++;
    }
}

my $s = MySubscriber->new;
my $p = MyPublisher
            ->new( max_value => 50 )
            ->subscribe( $s );

1;

__END__
