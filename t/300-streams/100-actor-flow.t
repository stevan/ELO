#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :events ];
use ok 'ELO::Actors', qw[ receive match setup ];
use ok 'ELO::Timers', qw[ :timers ];

my $log = Test::ELO->create_logger;

protocol *Subscription => sub {
    event *Request => (*Int);
    event *Cancel  => ();
};

sub Subscription ($publisher, $subscriber) {

    receive[*Subscription], +{
        *Request => sub ($this, $num_elements) {
            $log->info( $this, '*Request called with ('.$num_elements.')');
            while ($num_elements--) {
                $this->send( $publisher, [ *GetNext => $subscriber ]);
            }
        },
        *Cancel => sub ($this) {
            $log->info( $this, '*Cancel called');
            $this->send( $publisher, [ *UnSubscribe => $this ]);
        },
    }
}

protocol *Subscriber => sub {
    event *OnSubscribe => ( *Process );
    event *OnComplete  => ();
    event *OnNext      => ( *Scalar );
    event *OnError     => ( *Str );
};

sub Subscriber ($request_size) {

    my @_buffer;
    my $_subscription;
    my $_is_completed;

    receive[*Subscriber], +{
        *OnSubscribe => sub ($this, $subscription) {
            $log->info( $this, '*OnSubscribe called with ('.$subscription->pid.')');
            $_subscription = $subscription;
            $this->send( $_subscription, [ *Request => $request_size ]);
        },
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete called');
            unless ($_is_completed) {
                # NOTE:
                # we will get many messages, but only
                # call cancel once, if we wanted to
                # get confirmation, we could use a
                # promise (I guess)
                $log->info( $this, '... *OnComplete calling *Cancel on subscription('.$_subscription->pid.')');
                $this->send( $_subscription, [ *Cancel ]);
                $_is_completed++;
            }
        },
        *OnNext => sub ($this, $value) {
            $log->info( $this, '*OnNext called with ('.$value.')');

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
            @subscriptions = grep $_ eq $subscription, @subscriptions;
        },
        *GetNext => sub ($this, $subscriber) {
            $log->info( $this, '*GetNext called with ('.$subscriber->pid.')');
            if ( $source->has_next ) {

                my $next;
                try {
                    $next = $source->next;
                } catch ($e) {
                    $this->send( $subscriber, [ *OnError => $e ]);
                }

                timer( $this, rand(2), sub {
                    $this->send( $subscriber, [ *OnNext => $next ]);
                });
            }
            else {
                $this->send( $subscriber, [ *OnComplete ]);
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

sub init ($this, $msg) {

    my $publisher   = $this->spawn( Publisher(Source->new( end => 30 )) );
    my $subscriber1 = $this->spawn( Subscriber(5) );
    my $subscriber2 = $this->spawn( Subscriber(10) );

    $this->send( $publisher, [ *Subscribe => $subscriber1 ]);
    $this->send( $publisher, [ *Subscribe => $subscriber2 ]);

    $log->info( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;

__END__
