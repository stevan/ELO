#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :signals :events :types :typeclasses ];
use ok 'ELO::Timers', qw[ :tickers ];
use ok 'ELO::Actors', qw[ receive match setup ];

use lib 't/lib';

use ELO::JSON;
use ELO::JSON::Token;
use ELO::JSON::Token::Source;

my $log = Test::ELO->create_logger;

# -----------------------------------------------------------------------------
# Actors and Protocol
# -----------------------------------------------------------------------------
# JSONTokenObservable
#   - callback based Actor that serves as a bridge between two actors who speak
#     the basic protocol specified
# JSONTokenSubscription
#   - connection between subscriber and publisher
# JSONTokenSubscriber
#   - mostly just pushes to a Sink, but also handle refreshing stuff
# JSONTokenPublisher
#   - given a Souce, this can publish the contents of it
# -----------------------------------------------------------------------------

sub CreateObserver ($symbol, $T) {
    protocol $symbol => sub {
        event *OnComplete  => ();
        event *OnNext      => ( $T );
        event *OnError     => ( *Str );
    };

    my $actor = "$symbol";
       $actor =~ s/^\*//;

    no strict 'refs';
    *{$actor} = sub (%callbacks) {

        receive[$symbol], +{
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
    };
}

CreateObserver( *JSONTokenObserver, *ELO::JSON::Token::JSONToken );

# protocol *JSONTokenObserver => sub {
#     event *OnComplete  => ();
#     event *OnNext      => ( *ELO::JSON::Token::JSONToken );
#     event *OnError     => ( *Str );
# };
#
# sub JSONTokenObserver (%callbacks) {
#
#     receive[*JSONTokenObserver], +{
#         *OnComplete => sub ($this) {
#             $log->info( $this, '*OnComplete observed');
#             $callbacks{*OnComplete}->($this) if $callbacks{*OnComplete};
#         },
#         *OnNext => sub ($this, $value) {
#             $log->info( $this, '*OnNext observed with ('.$value.')');
#             $callbacks{*OnNext}->($this, $value) if $callbacks{*OnNext};
#
#         },
#         *OnError => sub ($this, $error) {
#             $log->info( $this, '*OnError observed with ('.$error.')');
#             $callbacks{*OnError}->($this, $error) if $callbacks{*OnError};
#         },
#     }
# }

protocol *JSONTokenSubscription => sub {
    event *Request => (*Int);
    event *Cancel  => ();
};

sub JSONTokenSubscription ($publisher, $subscriber) {

    receive[*JSONTokenSubscription], +{
        *Request => sub ($this, $num_elements) {
            $log->info( $this, '*Request called with ('.$num_elements.')');

            my $observer = $this->spawn(JSONTokenObserver(
                *OnComplete => sub ($this)         { $this->send( $subscriber, [ *OnComplete ]        )},
                *OnNext     => sub ($this, $value) { $this->send( $subscriber, [ *OnNext  => $value ] )},
                *OnError    => sub ($this, $error) { $this->send( $subscriber, [ *OnError => $error ] )},
            ));

            while ($num_elements--) {
                #timer( $this, rand(2), sub {
                    $this->send( $publisher, [ *GetNext => $observer ]);
                #});
            }
        },
        *Cancel => sub ($this) {
            $log->info( $this, '*Cancel called');
            $this->send( $publisher, [ *UnSubscribe => $this ]);
        }
    }
}

protocol *JSONTokenSubscriber => sub {
    event *OnSubscribe => ( *Process );
    event *OnComplete  => ();
    event *OnNext      => ( *ELO::JSON::Token::JSONToken );
    event *OnError     => ( *Str );
};

# TODO:
# move the token processing ot the Sink, then this is pretty generic
# and needs to know very little about stuff

sub JSONTokenSubscriber ($request_size, $sink) {

    my $_subscription;
    my $_seen = 0;
    my $_acc  = [];
    my $_done = 0;

    receive[*JSONTokenSubscriber], +{
        *OnSubscribe => sub ($this, $subscription) {
            $log->info( $this, '*OnSubscribe called with ('.$subscription->pid.')');

            $_subscription = $subscription;
            $this->send( $_subscription, [ *Request => $request_size ]);

            $_acc = [];
            ELO::JSON::Token::process_token( ELO::JSON::Token::StartArray(), $_acc );
        },
        *OnComplete => sub ($this) {
            $log->info( $this, '*OnComplete called');
            unless ($_done) {
                $log->info( $this, '*OnComplete called first time, doing wrapup');

                unless ($_acc->[-1] isa ELO::JSON::JSON::Item) {
                    ELO::JSON::Token::process_token( ELO::JSON::Token::EndItem(), $_acc );
                }

                ELO::JSON::Token::process_token( ELO::JSON::Token::EndArray(), $_acc );

                $sink->fill( $_acc->@* );
                $_acc->@* = ();
                $_done++;
            }
        },
        *OnNext => sub ($this, $token) {
            $log->info( $this, '*OnNext called with ('.$token.')');

            ELO::JSON::Token::process_token( $token, $_acc );

            $_seen++;
            if ( $_seen == $request_size ) {
                $log->info( $this, '... *OnNext requesting more from subscription('.$_subscription->pid.')');
                $this->send( $_subscription, [ *Request => $request_size ]);
                $_seen = 0;
            }

        },
        *OnError => sub ($this, $error) {
            $log->info( $this, '*OnError called with ('.$error.')');

        },
    }
}

protocol *JSONTokenPublisher => sub {
    event *Subscribe   => ( *Process );
    event *UnSubscribe => ( *Process );

    event *GetNext => ( *Process );
};

sub JSONTokenPublisher ($source) {

    my @subscriptions;

    receive[*JSONTokenPublisher], +{
        *Subscribe => sub ($this, $subscriber) {
            $log->info( $this, '*Subscribe called with ('.$subscriber->pid.')');

            my $subscription = $this->spawn( JSONTokenSubscription( $this, $subscriber ) );
            push @subscriptions => $subscription;
            $this->send( $subscriber, [ *OnSubscribe => $subscription ]);
        },
        *UnSubscribe => sub ($this, $subscription) {
            $log->info( $this, '*UnSubscribe called with ('.$subscription->pid.')');
            @subscriptions = grep $_->pid ne $subscription->pid, @subscriptions;
        },
        *GetNext => sub ($this, $subscriber) {
            $log->info( $this, '*GetNext called with ('.$subscriber->pid.')');

            my $next;
            try {
                $next = $source->get_next;
            } catch ($e) {
                $this->send( $subscriber, [ *OnError => $e ]);
                return;
            }

            if ( $next ) {
                $log->info( $this, '... *GetNext sending ('.$next.')');
                $this->send( $subscriber, [ *OnNext => $next ]);
            }
            else {
                $this->send( $subscriber, [ *OnComplete ]);
            }
        },
    }
}

# -----------------------------------------------------------------------------

my $Source = ELO::JSON::Token::Source::FromGenerator(sub {
    state $counter = 1;
    state @buffer  = ();

    unless (@buffer) {
        if ($counter <= 10) {
            #warn "BEGIN $counter";
            @buffer = (
                ELO::JSON::Token::StartItem( $counter ),
                    ELO::JSON::Token::AddInt( $counter++ ),
                ELO::JSON::Token::EndItem(),
            );
        }
    }

    #warn Dumper \@buffer;
    shift @buffer;
});

# -----------------------------------------------------------------------------


# NOTE:
# we could likely move all the process_token calls into this
# instaed of being in the subscriber

# fill  - this could take a list of tokens, and process each one
# drip  - this could take one token and process it
# drain - this could process and EndItem if needed, and wrap it in an Array()

package JSONTokenSink {
    use v5.36;
    use parent 'UNIVERSAL::Object';
    use slots (
        _sink => sub { +[] }
    );

    sub fill ($self, $x) {
        push $self->{_sink}->@* => $x;

        #use Data::Dumper;
        #warn Dumper $self->{_sink};
    }

    sub drain ($self) {
        my @sink = $self->{_sink}->@*;
        $self->{_sink}->@* = ();
        return @sink;
    }
}

my $Sink = JSONTokenSink->new;

# -----------------------------------------------------------------------------

sub Init () {

    setup sub ($this) {

        my $publisher   = $this->spawn( JSONTokenPublisher($Source) );
        my @subscribers = (
            $this->spawn( JSONTokenSubscriber(1, $Sink) ),
        );

        $this->trap( *SIGEXIT );
        $this->link( $publisher );

        $this->send( $publisher, [ *Subscribe => $_ ]) foreach @subscribers;

        $log->info( $this, '... starting' );

        receive +{
            *SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
                $log->info( $this, [ sort { $a <=> $b } $Sink->drain ] );
            }
        }
    }
}

ELO::Loop->run( Init(), logger => $log );

# -----------------------------------------------------------------------------

my @result = $Sink->drain;

is_deeply(
    $result[0]->to_perl,
    [ 1 .. 10 ],
    '... saw all exepected values'
);

done_testing;



