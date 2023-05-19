#!perl

use v5.36;
use experimental 'try';

=pod

THis is the "cold" stream example in the
001-basic.t test, but made async.

Note that the Subscription drives the
async-ness of this example. This retains
the back-pressure since it still relies
on the subscriber to signal need.

=cut

use ELO::Stream;

# ...

package MySubscription {
    use v5.36;

    my $log = Test::ELO->create_logger;

    use parent 'UNIVERSAL::Object::Immutable';
    use roles 'ELO::Stream::Subscription';
    use slots (
        ctx        => sub {},
        publisher  => sub {},
        subscriber => sub {},
    );

    sub BUILD ($self, $) {
        $self->{publisher}->roles::DOES('ELO::Stream::Iterator')
            || die 'The `publisher` must do the `ELO::Stream::Iterator` role ('.$self->{publisher}.')';

        $self->{subscriber}->roles::DOES('ELO::Stream::Refreshable')
            || die 'The `subscriber` must do the `ELO::Stream::Refreshable` role ('.$self->{subscriber}.')';
    }

    sub request ($self, $num_elements) {
        #$self->{ctx}->loop->next_tick(sub {
            $log->info( $self->{ctx}, "MySubscription::request($num_elements) called" );
            for (1 .. $num_elements) {
                if ( $self->{publisher}->has_next ) {
                    $self->{subscriber}->on_next(
                        $self->{publisher}->next
                    );
                }
                else {
                    $self->{subscriber}->on_complete;
                    return;
                }
            }

            $log->info( $self->{ctx}, "/// MySubscription::request($num_elements) should we refresh ????" );
            if ( $self->{subscriber}->should_refresh ) {
                $self->{subscriber}->refresh;
            }
        #});
    }

    sub cancel ($self) {
        $log->info( $self->{ctx}, "MySubscription::cancel called" );
        $self->{publisher}->unsubscribe( $self );
    }
}

package MySubscriber {
    use v5.36;

    my $log = Test::ELO->create_logger;

    use parent 'UNIVERSAL::Object';
    use roles 'ELO::Stream::Subscriber',
              'ELO::Stream::Refreshable';

    use slots (
        ctx          => sub {},
        subscription => sub {},
        total_seen   => sub { 0 },
        frame_seen   => sub { 0 },
        frame_size   => sub { 1 },
        completed    => sub { 0 },
        error        => sub {},
    );

    # ...

    sub should_refresh ($self) {
        $log->info( $self->{ctx}, "${self}::should_refresh called" );
        return if $self->{completed};
        return $self->{frame_seen} == $self->{frame_size}
    }

    sub refresh ($self) {
        $log->info( $self->{ctx}, "${self}::refresh called" );
        $self->{frame_size} = $self->{frame_size};
        $self->{frame_seen} = 0;
        $self->{ctx}->loop->next_tick(sub {
            $self->{subscription}->request( $self->{frame_size});
        });
    }

    # ...

    sub has_subscription ($self) { !! $self->{subscription} }
    sub is_completed     ($self) { !! $self->{completed} }
    sub has_error        ($self) { !! $self->{error} }

    sub on_subscribe ($self, $subscription) {
        $log->info( $self->{ctx}, "${self}::on_subscribe called with ($subscription)" );
        $self->{subscription} = $subscription;
        $self->refresh;
    }

    sub on_complete ($self) {
        $log->error( $self->{ctx}, "${self}::on_complete called" );
        $self->{completed} = 1;
    }

    sub on_error ($self, $e) {
        $log->info( $self->{ctx}, "${self}::on_error called with ($e)" );
    }

    sub on_next ($self, $i) {
        $log->warn( $self->{ctx}, "${self}::on_next called with arg($i)" );
        $self->{total_seen}++;
        $self->{frame_seen}++;
    }
}

package MyPublisher {
    use v5.36;

    my $log = Test::ELO->create_logger;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Stream::Publisher',
               'ELO::Stream::Iterator';

    use slots (
        ctx          => sub {},
        counter       => sub { 0 },
        max_value     => sub { 300 },
        subscriptions => sub { [] },
    );

    sub subscribe ($self, $subscriber) {
        $log->info( $self->{ctx}, "MyPublisher::subscribe called with subscriber($subscriber)" );
        my $subscription = MySubscription->new(
            ctx       => $self->{ctx},
            publisher  => $self,
            subscriber => $subscriber,
        );

        push $self->{subscriptions}->@* => $subscription;

        $subscriber->on_subscribe( $subscription );
    }

    sub unsubscribe ($self, $subscription) {
        $log->info( $self->{ctx}, "MyPublisher::unsubscribe called with subscription($subscription)");
        $self->{subscriptions}->@* = grep $_ eq $subscription, $self->{subscriptions}->@*;
    }

    sub has_next ($self) {
        $log->info( $self->{ctx}, "MyPublisher::has_next called");
        $self->{counter} <= $self->{max_value}
    }

    sub next ($self) {
        $log->warn( $self->{ctx}, "MyPublisher::next called" );
        return $self->{counter}++;
    }
}

package main;
use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Timers', qw[ ticker ];

my $log = Test::ELO->create_logger;

sub init ($this, $msg) {

    my $p = MyPublisher->new(
        ctx       => $this,
        max_value => 300
    );

    my $s1 = MySubscriber->new( ctx => $this, frame_size => 1 );
    my $s2 = MySubscriber->new( ctx => $this, frame_size => 4 );
    my $s3 = MySubscriber->new( ctx => $this, frame_size => 2 );

    $p->subscribe( $s1 );
    ticker( $this, 10, sub { $p->subscribe( $s2 ) });
    ticker( $this, 50, sub { $p->subscribe( $s3 ) });

    ticker( $this, 70, sub {
        $log->fatal( $this, $s1->{total_seen} );
        $log->fatal( $this, $s2->{total_seen} );
        $log->fatal( $this, $s3->{total_seen} );
        $log->fatal( $this, $s1->{total_seen} + $s2->{total_seen} + $s3->{total_seen} );
        $log->fatal( $this, $p->{counter} );
    });
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;

__END__
