#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :events :signals ];
use ok 'ELO::Actors', qw[ receive match setup ];
use ok 'ELO::Timers', qw[ :timers ];
use ok 'ELO::Types',  qw[ *SIGEXIT ];

my $log = Test::ELO->create_logger;

diag "... this one takes a bit";

# TODO:
# Implement Refresh in the Subscription, it should
# drive the process, not the Subscription here.

protocol *Observer => sub {
    event *OnComplete  => ();
    event *OnNext      => ( *Scalar );
    event *OnError     => ( *Str );
};

sub Observer ($num_elements, $subscriber) {

    my $_seen = 0;
    my $_done = 0;

    receive[*Observer], +{
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete observed');
            unless ($_done) {
                $log->info( $this, '*OnComplete circuit breaker tripped sending *OnComplete to ('.$subscriber->pid.')');
                $this->send( $subscriber, [ *OnComplete ] );
                $_done = 1;
            }
        },
        *OnNext => sub ($this, $value) {
            $log->info( $this, '*OnNext observed with ('.$value.')');
            $this->send( $subscriber, [ *OnNext => $value ] );
            $_seen++;
            if ( $num_elements <= $_seen ) {
                $log->info( $this, '*OnNext observed seen('.$_seen.') of ('.$num_elements.') sending *OnRequestComplete to ('.$subscriber->pid.')');
                # FIXME:
                # Should this be in the next tick?
                $this->send( $subscriber, [ *OnRequestComplete ] );
                $_seen = 0;
                $_done = 1;
            }
        },
        *OnError => sub ($this, $error) {
            $log->info( $this, '*OnError observed with ('.$error.')');
            $this->send( $subscriber, [ *OnError => $error ] );
        },
        *SIGEXIT => sub ($this, $from) {
            $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            $this->exit(0)
        }
    }
}


protocol *Subscriber => sub {
    event *OnSubscribe       => ( *Process );
    event *OnUnsubscribe     => ();
    event *OnComplete        => ();
    event *OnRequestComplete => ();
    event *OnNext            => ( *Scalar );
    event *OnError           => ( *Str );
};

sub Subscriber ($request_size, $sink) {

    my $_subscription;

    receive[*Subscriber], +{
        *OnSubscribe => sub ($this, $subscription) {
            $log->info( $this, '*OnSubscribe called with ('.$subscription->pid.')');
            $_subscription = $subscription;
            $this->send( $_subscription, [ *Request => $request_size ]);
        },
        *OnUnsubscribe => sub ($this) {
            $log->info( $this, '*OnUnsubscribe called');
        },
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete called');
            $sink->done;
            $this->send( $_subscription, [ *Cancel ] );
        },
        *OnRequestComplete => sub ($this) {
            $log->info( $this, '*OnRequestComplete called');
            $this->send( $_subscription, [ *Request => $request_size ]);
        },
        *OnNext => sub ($this, $value) {
            $log->info( $this, '*OnNext called with ('.$value.')');
            $sink->drip( $value );
        },
        *OnError => sub ($this, $error) {
            $log->info( $this, '*OnError called with ('.$error.')');
        },
        *SIGEXIT => sub ($this, $from) {
            $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            $this->exit(0);
        }
    }
}

protocol *Subscription => sub {
    event *Request       => (*Int);
    event *Cancel        => ();
    event *OnUnsubscribe => ();
};

sub Subscription ($publisher, $subscriber) {

    my $_observer;

    receive[*Subscription], +{
        *Request => sub ($this, $num_elements) {
            $log->info( $this, '*Request called with ('.$num_elements.')');

            if ( $_observer ) {
                $log->info( $this, '*Request called, killing old observer ('.$_observer->pid.')');
                $this->kill( $_observer );
            }

            $_observer = $this->spawn(Observer( $num_elements, $subscriber ));
            $_observer->trap( *SIGEXIT );

            while ($num_elements--) {
                $this->send( $publisher, [ *GetNext => $_observer ]);
            }
        },
        *Cancel => sub ($this) {
            $log->info( $this, '*Cancel called');
            $this->send( $publisher, [ *Unsubscribe => $this ]);
        },
        *OnUnsubscribe => sub ($this) {
            $log->info( $this, '*OnUnsubscribe called');
            $this->send( $subscriber, [ *OnUnsubscribe ]);
            $this->kill( $_observer );
            $this->exit(0);
        },
        *SIGEXIT => sub ($this, $from) {
            $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            $this->exit(0);
        }
    }
}

protocol *Publisher => sub {
    event *Subscribe   => ( *Process );
    event *Unsubscribe => ( *Process );

    event *GetNext => ( *Process );
};

sub Publisher ($source) {

    my @subscriptions;
    my %unsubscribed;

    receive[*Publisher], +{
        *Subscribe => sub ($this, $subscriber) {
            $log->info( $this, '*Subscribe called with ('.$subscriber->pid.')');

            my $subscription = $this->spawn( Subscription( $this, $subscriber ) );
            $subscriber->trap( *SIGEXIT );

            push @subscriptions => $subscription;
            $this->send( $subscriber, [ *OnSubscribe => $subscription ]);
        },
        *Unsubscribe => sub ($this, $subscription) {
            $log->info( $this, '*Unsubscribe called with ('.$subscription->pid.')');
            @subscriptions = grep $_->pid ne $subscription->pid, @subscriptions;
            $this->send( $subscription, [ *OnUnsubscribe ]);

            if (scalar @subscriptions == 0) {
                $log->info( $this, '*Unsubscribe called and no more subscrptions, exiting');
                # TODO: this should be more graceful, sending
                # a shutdown message or something, **shrug**
                $this->exit(0);
            }
        },
        *GetNext => sub ($this, $observer) {
            $log->info( $this, '*GetNext called with ('.$observer->pid.')');
            if ( $source->has_next ) {

                my $next;
                try {
                    $next = $source->next;
                } catch ($e) {
                    $this->send( $observer, [ *OnError => $e ]);
                }

                $log->info( $this, '... *GetNext sending ('.$next.')');
                $this->send( $observer, [ *OnNext => $next ]);
            }
            else {
                $this->send( $observer, [ *OnComplete ]);
            }
        },
        *SIGEXIT => sub ($this, $from) {
            $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            $this->exit(0);
        }
    }
}

package Source {
    use v5.36;
    use parent 'UNIVERSAL::Object';
    use slots (
        start => sub { 1 },
        end   => sub { 10 },
        # ...
        _count => sub {},
    );

    sub BUILD ($self, $) { $self->{_count} = $self->{start} }

    sub has_next ($self) { $self->{_count} <= $self->{end} }
    sub next     ($self) { $self->{_count}++ }
}

package Sink {
    use v5.36;
    use parent 'UNIVERSAL::Object';
    use slots (
        _sink => sub { +[] },
        _done => sub {  0  },
    );

    sub drip ($self, $x) {
        return if $self->{_done}; # the real thing should do more ...
        push $self->{_sink}->@* => $x;
    }

    sub done ($self) {
        $self->{_done} = 1;
    }

    sub drain ($self) {
        my @sink = $self->{_sink}->@*;
        $self->{_sink}->@* = ();
        return @sink;
    }
}

my $Sink   = Sink->new;
my $Source = Source->new( end => 50 );

sub Init () {

    setup sub ($this) {

        my $publisher   = $this->spawn( Publisher( $Source ) );
        my @subscribers = (
            $this->spawn( Subscriber( 5,  $Sink ) ),
            $this->spawn( Subscriber( 10, $Sink ) ),
        );

        # trap exits for all
        $this->trap( *SIGEXIT );
        $publisher->trap( *SIGEXIT );
        $_->trap( *SIGEXIT ) foreach @subscribers;

        # link this to the publisher
        $this->link( $publisher );
        # and the publisher to the subsribers
        $publisher->link( $_ ) foreach @subscribers;

        $this->send( $publisher, [ *Subscribe => $_ ]) foreach @subscribers;

        $log->info( $this, '... starting' );

        receive +{
            *SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
                $this->exit(0);
            }
        }
    }
}

ELO::Loop->run( Init(), logger => $log );

is_deeply(
    [ sort { $a <=> $b } $Sink->drain ],
    [ 1 .. 50 ],
    '... saw all exepected values'
);

done_testing;

1;

__END__
