package ELO::Streams;
use v5.36;
use experimental 'try';

use ELO::Types  qw[ :core :types :events :signals :typeclasses ];
use ELO::Actors qw[ receive setup ];
use ELO::Timers qw[ :timers ];


## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

my @EVENTS = qw[
    *OnComplete
    *OnNext
    *OnError

    *OnSubscribe
    *OnUnsubscribe

    *OnRequestComplete

    *Request
    *Cancel

    *Subscribe
    *Unsubscribe
    *GetNext
];

my @TYPECLASSES = qw[
    *Source
        SourceFromList
        SourceFromGenerator

    *SinkMarkers
        *SinkDrop
        *SinkDone
        *SinkDrain

    *Sink
        SinkToCallback
        SinkToBuffer
];

our @PROTOCOLS = qw[
    *Observer
    *Subscription
    *Subscriber
    *Publisher
];

our @ACTORS = qw[
    Observer
    Subscription
    Subscriber
    Publisher
];

use Exporter 'import';

our @EXPORT = (
    @EVENTS,
    @PROTOCOLS,
    @ACTORS,
    @TYPECLASSES,
);

our $log;

## ----------------------------------------------------------------------------
## Source
## ----------------------------------------------------------------------------

datatype *Source => sub {
    case SourceFromList      => ( *ArrayRef );
    case SourceFromGenerator => ( *CodeRef );
};

typeclass[*Source] => sub {
    method get_next => {
        SourceFromList      => sub ($list) { shift $list->@* },
        SourceFromGenerator => sub ($gen)  { $gen->()        },
    };
};

## ----------------------------------------------------------------------------
## Sink
## ----------------------------------------------------------------------------

enum *SinkMarkers => (
    *SinkDrop,
    *SinkDone,
    *SinkDrain
);

datatype *Sink => sub {
    case SinkToBuffer   => ( *ArrayRef );
    case SinkToCallback => ( *CodeRef );
};

typeclass[*Sink] => sub {

    # FIXME: conver to arg checking form
    method drip => sub ($s, $drop) {
        match[ *Sink => $s ], +{
            SinkToCallback => sub ($callback) { $callback->($drop, *SinkDrop) },
            SinkToBuffer   => sub ($buffer)   {
                return if @$buffer
                       && $buffer->[-1] eq *SinkDone;
                push @$buffer => $drop;

            },
        }
    };

    method done => +{
        SinkToCallback => sub ($callback) { $callback->(undef, *SinkDone) },
        SinkToBuffer   => sub ($buffer)   { push @$buffer =>   *SinkDone  },
    };

    method drain => +{
        SinkToCallback => sub ($callback) { $callback->(undef, *SinkDrain) },
        SinkToBuffer   => sub ($buffer)   {
            my @sink = @$buffer;
            @$buffer = ();
            pop @sink if $sink[-1] eq *SinkDone;
            @sink;
        },
    };
};


## ----------------------------------------------------------------------------
## Observer
## ----------------------------------------------------------------------------

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

## ----------------------------------------------------------------------------
## Subscriber
## ----------------------------------------------------------------------------

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
            $sink->done();
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

## ----------------------------------------------------------------------------
## Subscription
## ----------------------------------------------------------------------------

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

## ----------------------------------------------------------------------------
## Publisher
## ----------------------------------------------------------------------------

protocol *Publisher => sub {
    event *Subscribe   => ( *Process );
    event *Unsubscribe => ( *Process );
    event *GetNext     => ( *Process );
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

            # XXX:
            # If the source returned an option type
            #
            # match [ *Option => $next ] => {
            #     Some => sub ($value) {
            #         $this->send( $observer, [ *OnNext => $next ]);
            #     },
            #     None => sub () {
            #         $this->send( $observer, [ *OnComplete ]);
            #     }
            # };

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


1;
