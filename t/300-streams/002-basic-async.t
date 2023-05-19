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
    use roles 'ELO::Stream::Core::Subscription';
    use slots (
        ctx        => sub {},
    );

    sub BUILD ($self, $) {
        $self->publisher->roles::DOES('ELO::Stream::Iterator')
            || die 'The `publisher` must do the `ELO::Stream::Iterator` role ('.$self->publisher.')';

        $self->subscriber->roles::DOES('ELO::Stream::Refreshable')
            || die 'The `subscriber` must do the `ELO::Stream::Refreshable` role ('.$self->subscriber.')';
    }

    sub request ($self, $num_elements) {
        $self->{ctx}->loop->next_tick(sub {
            $log->info( $self->{ctx}, "MySubscription::request($num_elements) called" );
            for (1 .. $num_elements) {
                if ( $self->publisher->has_next ) {
                    $self->subscriber->on_next(
                        $self->publisher->next
                    );
                }
                else {
                    $self->subscriber->on_complete;
                    return;
                }
            }

            $log->info( $self->{ctx}, "/// MySubscription::request($num_elements) should we refresh ????" );
            if ( $self->subscriber->should_refresh ) {
                $self->subscriber->refresh( $self );
            }
        });
    }
}

package MySubscriber {
    use v5.36;

    my $log = Test::ELO->create_logger;

    use parent 'UNIVERSAL::Object';
    use roles 'ELO::Stream::Core::Subscriber',
              'ELO::Stream::Core::Subscriber::AutoRefresh';

    use slots (
        ctx          => sub {},
        total_seen   => sub { 0 },
        seen         => sub { 0 },
        completed    => sub { 0 },
    );

    # ...

    sub should_refresh ($self) {
        $log->info( $self->{ctx}, "${self}::should_refresh called" );
        return if $self->{completed};
        return $self->{seen} == $self->request_size
    }

    sub on_refresh ($self, $subscription) {
        $log->info( $self->{ctx}, "${self}::refresh called with ($subscription)" );
        $self->{seen} = 0;
    }

    # ...

    sub is_completed ($self) { !! $self->{completed} }

    sub on_subscribe ($self, $subscription) {
        $log->info( $self->{ctx}, "${self}::on_subscribe called with ($subscription)" );
        $self->refresh( $subscription );
    }

    sub on_complete ($self) {
        $log->error( $self->{ctx}, "${self}::on_complete called" );
        $self->{completed} = 1;
    }

    sub on_next ($self, $i) {
        $log->warn( $self->{ctx}, "${self}::on_next called with arg($i)" );
        $self->{total_seen}++;
        $self->{seen}++;
    }
}

package MyPublisher {
    use v5.36;

    my $log = Test::ELO->create_logger;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Stream::Core::Publisher',
               'ELO::Stream::Iterator';

    use slots (
        ctx          => sub {},
        counter       => sub { 0 },
        max_value     => sub { 300 },
    );

    sub create_subscription_for ($self, $subscriber) {
        MySubscription->new(
            ctx        => $self->{ctx},
            publisher  => $self,
            subscriber => $subscriber
        )
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

    my $s1 = MySubscriber->new( ctx => $this, request_size => 1 );
    my $s2 = MySubscriber->new( ctx => $this, request_size => 4 );
    my $s3 = MySubscriber->new( ctx => $this, request_size => 2 );

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
