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

protocol *Observer => sub {
    event *OnComplete  => ();
    event *OnNext      => ( *Scalar );
    event *OnError     => ( *Str );
};

sub Observer ($num_elements, $subscriber) {

    my $seen = 0;
    my $done = 0;

    receive[*Observer], +{
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete observed');

            if (!$done) {
                $log->info( $this, '*OnComplete circuit breaker tripped');
                $done = 1;
            }

            $seen++;
            if ( $num_elements <= $seen ) {
                $log->info( $this, '*OnComplete observed seen('.$seen.') of ('.$num_elements.') sending *OnComplete to ('.$subscriber->pid.')');
                $this->send( $subscriber, [ *OnComplete ] );
                $seen = 0;
            }
        },
        *OnNext => sub ($this, $value) {
            $log->info( $this, '*OnNext observed with ('.$value.')');
            $this->send( $subscriber, [ *OnNext => $value ] );
            $seen++;
            if ( $num_elements <= $seen ) {
                $log->info( $this, '*OnNext observed seen('.$seen.') of ('.$num_elements.') sending *OnRequestComplete to ('.$subscriber->pid.')');
                $this->send( $subscriber, [ *OnRequestComplete ] );
                $seen = 0;
                $done = 1;
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

    my $subscription;

    receive[*Subscriber], +{
        *OnSubscribe => sub ($this, $s) {
            $log->info( $this, '*OnSubscribe called with ('.$s->pid.')');
            $subscription = $s;
            $this->send( $subscription, [ *Request => $request_size ]);
        },
        *OnUnsubscribe => sub ($this) {
            $log->info( $this, '*OnUnsubscribe called');
        },
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete called');
            $sink->done;
            $this->send( $subscription, [ *Cancel ] );
        },
        *OnRequestComplete => sub ($this) {
            $log->info( $this, '*OnRequestComplete called');
            $this->send( $subscription, [ *Request => $request_size ]);
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

    my $observer;

    receive[*Subscription], +{
        *Request => sub ($this, $num_elements) {
            $log->info( $this, '*Request called with ('.$num_elements.')');

            if ( $observer ) {
                $log->info( $this, '*Request called, killing old observer ('.$observer->pid.')');
                $this->kill( $observer );
            }

            $observer = $this->spawn(Observer( $num_elements, $subscriber ));
            $observer->trap( *SIGEXIT );

            while ($num_elements--) {
                timer( $this, rand(3), sub {
                    $this->send( $publisher, [ *GetNext => $observer ]);
                });
            }
        },
        *Cancel => sub ($this) {
            $log->info( $this, '*Cancel called');
            $this->send( $publisher, [ *Unsubscribe => $this ]);
        },
        *OnUnsubscribe => sub ($this) {
            $log->info( $this, '*OnUnsubscribe called');
            $this->send( $subscriber, [ *OnUnsubscribe ]);
            $this->kill( $observer );
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

            my $next;
            try {
                $next = $source->get_next;
            } catch ($e) {
                $this->send( $observer, [ *OnError => $e ]);
                return;
            }

            if ( $next ) {
                $log->info( $this, '... *GetNext sending ('.$next.')');
                timer( $this, rand(3), sub {
                    $this->send( $observer, [ *OnNext => $next ]);
                });
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
        start => sub { 0 },
        end   => sub { 10 },
        # ...
        _count => sub {},
    );

    sub BUILD ($self, $) { $self->{_count} = $self->{start} }

    sub get_next ($self) {
        $self->{_count}++;
        if ( $self->{_count} <= $self->{end} ) {
            return $self->{_count};
        }
        else {
            return;
        }
    }
}

package Sink {
    use v5.36;
    use parent 'UNIVERSAL::Object';
    use slots (
        _sink => sub { +[] },
        _done => sub {  0  },
    );

    sub drip ($self, $x) {
        #warn "---------------------------------> DRIP($x)\n";
        return if $self->{_done}; # the real thing should do more ...
        push $self->{_sink}->@* => $x;
    }

    sub done ($self) {
        #warn "---------------------------------> DONE\n";
        $self->{_done} = 1;
    }

    sub drain ($self) {
        my @sink = $self->{_sink}->@*;
        $self->{_sink}->@* = ();
        return @sink;
    }
}

# ...

my $MAX_ITEMS = 25;

my $Source = Source->new( end => $MAX_ITEMS );
my @Sinks = (
    Sink->new,
    Sink->new,
    Sink->new,
);

# ...

sub Init () {

    setup sub ($this) {

        my $publisher   = $this->spawn( Publisher( $Source ) );
        my @subscribers = (
            $this->spawn( Subscriber( 5,  $Sinks[0] ) ),
            $this->spawn( Subscriber( 10, $Sinks[1] ) ),
            $this->spawn( Subscriber( 2,  $Sinks[2] ) ),
        );

        # trap exits for all
        $_->trap( *SIGEXIT )
            foreach ($this, $publisher, @subscribers);

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

my @results = sort { $a <=> $b } map $_->drain, @Sinks;

is_deeply(
    [ @results ],
    [ 1 .. $MAX_ITEMS ],
    '... saw all exepected values'
);

#warn Dumper \@results;

done_testing;

1;

__END__
