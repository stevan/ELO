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

protocol *Observer => sub {
    event *OnComplete  => ();
    event *OnNext      => ( *Scalar );
    event *OnError     => ( *Str );
};

sub Observer (%callbacks) {

    receive[*Subscription], +{
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete observed');
            $callbacks{*OnComplete}->($this) if $callbacks{*OnComplete};
        },
        *OnNext => sub ($this, $value) {
            $log->info( $this, '*OnNext observed with ('.$value.')');
            $callbacks{*OnNext}->($this, $value) if $callbacks{*OnNext};

        },
        *OnError => sub ($this, $error) {
            $log->info( $this, '*OnError observed with ('.$error.')');
            $callbacks{*OnError}->($this, $error) if $callbacks{*OnError};
        },
    }
}

protocol *Subscription => sub {
    event *Request => (*Int);
    event *Cancel  => ();

    event *OnComplete  => ();
    event *OnNext      => ( *Scalar );
    event *OnError     => ( *Str );
};

sub Subscription ($publisher, $subscriber) {


    receive[*Subscription], +{
        *Request => sub ($this, $num_elements) {
            $log->info( $this, '*Request called with ('.$num_elements.')');

            my $observer = $this->spawn(Observer(
                *OnComplete => sub ($this)         { $this->send( $subscriber, [ *OnComplete ]        )},
                *OnNext     => sub ($this, $value) { $this->send( $subscriber, [ *OnNext  => $value ] )},
                *OnError    => sub ($this, $error) { $this->send( $subscriber, [ *OnError => $error ] )},
            ));

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
    event *OnSubscribe => ( *Process );
    event *OnComplete  => ();
    event *OnNext      => ( *Scalar );
    event *OnError     => ( *Str );
};

sub Subscriber ($request_size, $sink) {

    my @_buffer;
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
        *OnNext => sub ($this, $value) {
            $log->info( $this, '*OnNext called with ('.$value.')');

            $sink->fill( $value );

            push @_buffer => $value;
            $log->info( $this, ['... *OnNext buffering: ', \@_buffer]);

            if ( scalar(@_buffer) == $request_size ) {
                # NOTE:
                # We refresh when the buffer is full
                @_buffer = sort { $a <=> $b } @_buffer;
                $log->info( $this, ['... *OnNext buffer is full: ', [$request_size, scalar(@_buffer)], \@_buffer]);
                @_buffer = ();
                $log->info( $this, '... *OnNext requesting more from subscription('.$_subscription->pid.')');
                $this->send( $_subscription, [ *Request => $request_size ]);
            }

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
        *GetNext => sub ($this, $subscription) {
            $log->info( $this, '*GetNext called with ('.$subscription->pid.')');
            if ( $source->has_next ) {

                my $next;
                try {
                    $next = $source->next;
                } catch ($e) {
                    $this->send( $subscription, [ *OnError => $e ]);
                }

                $log->info( $this, '... *GetNext sending ('.$next.')');
                #timer( $this, rand(5), sub {
                    $this->send( $subscription, [ *OnNext => $next ]);
                #});
            }
            else {
                $this->send( $subscription, [ *OnComplete ]);
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

    sub fill ($self, $x) {
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
            $this->spawn( Subscriber(2,  $sink) ),
            $this->spawn( Subscriber(5,  $sink) ),
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

my @contents = $sink->drain;
warn join ', ' => @contents;
warn join ', ' => sort { $a <=> $b } @contents;

done_testing;

1;

__END__
