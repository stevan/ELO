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

    receive[*Observer], +{
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete observed');
            $this->send( $subscriber, [ *OnComplete ] );
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
            }
        },
        *OnError => sub ($this, $error) {
            $log->info( $this, '*OnError observed with ('.$error.')');
            $this->send( $subscriber, [ *OnError => $error ] );
        },
    }
}

protocol *Subscription => sub {
    event *Request => (*Int);
    event *Cancel  => ();
};

sub Subscription ($publisher, $subscriber) {


    receive[*Subscription], +{
        *Request => sub ($this, $num_elements) {
            $log->info( $this, '*Request called with ('.$num_elements.')');

            my $observer = $this->spawn(Observer( $num_elements, $subscriber ));

            while ($num_elements--) {
                $this->send( $publisher, [ *GetNext => $observer ]);
            }
        },
        *Cancel => sub ($this) {
            $log->info( $this, '*Cancel called');
            $this->send( $publisher, [ *UnSubscribe => $this ]);
        }
    }
}

protocol *Subscriber => sub {
    event *OnSubscribe       => ( *Process );
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
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete called');
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
    }
}

protocol *Publisher => sub {
    event *Subscribe   => ( *Process );
    event *UnSubscribe => ( *Process );

    event *GetNext => ( *Process );
};

sub Publisher ($source) {

    my @subscriptions;

    receive[*Publisher], +{
        *Subscribe => sub ($this, $subscriber) {
            $log->info( $this, '*Subscribe called with ('.$subscriber->pid.')');

            my $subscription = $this->spawn( Subscription( $this, $subscriber ) );
            push @subscriptions => $subscription;
            $this->send( $subscriber, [ *OnSubscribe => $subscription ]);
        },
        *UnSubscribe => sub ($this, $subscription) {
            $log->info( $this, '*UnSubscribe called with ('.$subscription->pid.')');
            @subscriptions = grep $_->pid ne $subscription->pid, @subscriptions;
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
        _sink => sub { +[] }
    );

    sub drip ($self, $x) {
        push $self->{_sink}->@* => $x;
    }

    sub drain ($self) {
        my @sink = $self->{_sink}->@*;
        $self->{_sink}->@* = ();
        return @sink;
    }
}

my $sink = Sink->new;

sub Init () {

    setup sub ($this) {

        my $publisher   = $this->spawn( Publisher(Source->new( end => 50 )) );
        my @subscribers = (
            $this->spawn( Subscriber(5,  $sink) ),
            $this->spawn( Subscriber(10, $sink) ),
            #$this->spawn( Subscriber(2,  $sink) ),
            #$this->spawn( Subscriber(5,  $sink) ),
        );

        $this->trap( *SIGEXIT );
        $this->link( $publisher );

        $this->send( $publisher, [ *Subscribe => $_ ]) foreach @subscribers;

        $log->info( $this, '... starting' );

        receive +{
            *SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
                $log->info( $this, [ sort { $a <=> $b } $sink->drain ] );
            }
        }
    }
}

ELO::Loop->run( Init(), logger => $log );

is_deeply(
    [ sort { $a <=> $b } $sink->drain ],
    [ 1 .. 50 ],
    '... saw all exepected values'
);

done_testing;

1;

__END__
