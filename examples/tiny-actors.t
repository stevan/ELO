#!perl

use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Event {
    field $symbol  :param;
    field $payload :param = [];

    method symbol  { $symbol  }
    method payload { $payload }
}

class Message {
    field $to    :param;
    field $from  :param;
    field $event :param;

    method to    { $to    }
    method from  { $from  }
    method event { $event }
}

class Actor {
    method can_apply ($message) {
        !! $self->can($message->event->symbol)
    }

    method apply ($ctx, $message) {
        my $symbol = $message->event->symbol;
        my $method = $self->can($symbol);
        $self->$method( $ctx, $message );
    }
}

class ActorRef {
    field $pid    :param;
    field $system :param;
    field $actor  :param;

    method pid    { $pid    }
    method system { $system }
    method actor  { $actor  }

    method spawn ($actor) {
        $system->spawn( $actor );
    }

    method send ($to, $event) {
        $system->enqueue_message(
            Message->new( to => $to, from => $self, event => $event )
        );
    }

    method exit () {
        $system->despawn( $self );
    }

    method kill ($actor_ref) {
        $system->despawn( $actor_ref );
    }
}

class ActorSystem {
    use Time::HiRes qw[ sleep ];

    my $PIDS = 0;

    field %actor_refs;
    field @deferred;
    field @msg_queue;
    field @dead_letter_queue;

    field $init :param;

    method spawn ($actor) {
        my $a = ActorRef->new(
            pid    => ++$PIDS,
            system => $self,
            actor  => $actor,
        );

        $actor_refs{ $a->pid } = $a;
        $a;
    }

    method despawn ($actor_ref) {
        push @deferred => sub {
            delete $actor_refs{ $actor_ref->pid };
        };
    }

    method enqueue_message ($message) {
        push @msg_queue => $message;
    }

    method loop ($delay=undef) {
        state $tail = ('-' x 60);

        say "init $tail";
        $init->( $self->spawn( Actor->new ) );

        say "start $tail";
        while (1) {
            say "tick $tail";

            my @msgs   = @msg_queue;
            @msg_queue = ();

            while (@msgs) {
                my $msg = shift @msgs;

                if ( my $actor_ref = $actor_refs{ $msg->to->pid } ) {
                    my $a = $actor_ref->actor;
                    if ( $a->can_apply( $msg ) ) {
                        $a->apply( $actor_ref, $msg );
                    }
                    else {
                        push @dead_letter_queue => [ 'LABEL NOT FOUND', $msg ];
                    }
                }
                else {
                    push @dead_letter_queue => [ 'ACTOR NOT FOUND', $msg ];
                }
            }

            if ( @deferred ) {
                say "idle $tail";
                (shift @deferred)->() while @deferred;
            }

            last unless @msg_queue;
            sleep($delay) if defined $delay;
        }

        if ( @deferred ) {
            say "cleanup $tail";
            (shift @deferred)->() while @deferred;
        }

        say "exit $tail";

        if ( @dead_letter_queue ) {
            say "Dead Letter Queue";
            foreach my $msg ( @dead_letter_queue ) {
                say join ', ' => @$msg;
            }
        }

        if ( %actor_refs ) {
            say "Zombies";
            say join ", " => sort { $a <=> $b } keys %actor_refs;
        }
    }

}

class PingPong :isa(Actor) {

    field $name :param;
    field $max  :param;

    field $pings = 0;
    field $pongs = 0;

    method ping ($ctx, $message) {
        if ($pings < $max) {
            say "got ping($name)[$pings] <= $max";

            $ctx->send(
                $message->from,
                Event->new( symbol  => 'pong' )
            );

            $pings++;
        }
        else {
            say "!!! ending ping at($name)[$pings] <= $max";
            $ctx->exit;
            $ctx->kill( $message->from );
        }
    }

    method pong ($ctx, $message) {
        if ($pongs < $max) {
            say "got pong($name)[$pongs] <= $max";

            $ctx->send(
                $message->from,
                Event->new( symbol  => 'ping' )
            );

            $pongs++;
        }
        else {
            say "!!! ending at($name)[$pongs] <= $max";
            $ctx->exit;
            $ctx->kill( $message->from );
        }
    }
}

sub init ($ctx) {
    foreach ( 1 .. 10 ) {
        my $max = int(rand(10));

        my $Ping = $ctx->spawn( PingPong->new( name => "Ping($_)", max => $max ) );
        my $Pong = $ctx->spawn( PingPong->new( name => "Pong($_)", max => $max ) );

        $Ping->send( $Pong, Event->new( symbol => 'pong' ) );
    }
}

ActorSystem->new( init => \&init )->loop( 0.5 );

1;







