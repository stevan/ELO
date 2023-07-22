#!perl

use v5.38;
use experimental 'class', 'builtin', 'try';
use builtin 'blessed';

use Time::HiRes qw[ sleep ];
use Carp        qw[ confess ];

## -----------------------------------------------------------------------------
## Actors for Perl/Corinna
## -----------------------------------------------------------------------------
## This is a proof of concept of a simple Actor system for Perl using the
## new `class` feature (aka - Corinna).
## -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Event
# -----------------------------------------------------------------------------
# An Event can thought of as a deffered method call. The `$symbol` being the
# name of the method, and the $payload being the an ARRAY ref of arguments to
# the method.
#
# An Event is the primary payload of the Message object.
# -----------------------------------------------------------------------------

class Event {
    field $symbol  :param;
    field $payload :param = [];

    ADJUST {
        defined $symbol         || ::confess 'The `symbol` param must be a defined value';
        ref $payload eq 'ARRAY' || ::confess 'The `payload` param must be an ARRAY ref';
    }

    method symbol  { $symbol  }
    method payload { $payload }
}

# -----------------------------------------------------------------------------
# Message
# -----------------------------------------------------------------------------
# A Message is a container for an Event, which has a sender (`$from`) and a
# recipient (`$to`), both of which are ActorRef instances.
#
# The Message is the primary means of communication between actors, with
# messages being passed via the ActorSystem.
# -----------------------------------------------------------------------------

class Message {
    field $to    :param;
    field $from  :param;
    field $event :param;

    ADJUST {
        $to    isa ActorRef || ::confess 'The `to` param must be an ActorRef';
        $from  isa ActorRef || ::confess 'The `from` param must be an ActorRef';
        $event isa Event    || ::confess 'The `event` param must be an Event';
    }

    method to    { $to    }
    method from  { $from  }
    method event { $event }
}

# -----------------------------------------------------------------------------
# Actor
# -----------------------------------------------------------------------------
# The simplest Actor, it will attempt to apply a Message by looking up
# the Message event's symbol. In this case, the Actor will look for a
# method of the same name within it's dispatch table.
#
# Actor is meant to be subclassed and methods added to enable behaviors
# that can be called via an Event.
# -----------------------------------------------------------------------------

class Actor {
    method apply ($ctx, $message) {
        $ctx     isa ActorRef || ::confess 'The `$ctx` arg must be an ActorRef';
        $message isa Message  || ::confess 'The `$message` arg must be a Message';

        my $symbol = $message->event->symbol;
        my $method = $self->can($symbol);

        defined $method || ::confess "Unable to find message for ($symbol)";

        $self->$method( $ctx, $message );
    }
}

# -----------------------------------------------------------------------------
# ActorRef
# -----------------------------------------------------------------------------
# The ActorRef is a wrapper around the Actor and the ActorSystem that provides
# a number of convenience methods. It is most often used as a "context"
# variable that is passed to all dispatched methods.

# ActorRef can also be seen as an "activation record" of the Actor within the
# ActorSystem, as it is the keeper of the PID value
# -----------------------------------------------------------------------------

class ActorRef {
    field $pid    :param;
    field $system :param;
    field $actor  :param;

    ADJUST {
        defined $pid            || ::confess 'The `$pid` param must defined value';
        $system isa ActorSystem || ::confess 'The `$system` param must be an ActorSystem';
        $actor  isa Actor       || ::confess 'The `$actor` param must be an Actor';
    }

    method pid    { $pid    }
    method system { $system }
    method actor  { $actor  }

    method spawn ($actor) {
        $actor isa Actor || ::confess 'The `$actor` arg must be an Actor';

        $system->spawn( $actor );
    }

    method send ($to, $event) {
        $to    isa ActorRef || ::confess 'The `$to` arg must be an ActorRef';
        $event isa Event    || ::confess 'The `$event` arg must be an Event';

        $system->enqueue_message(
            Message->new( to => $to, from => $self, event => $event )
        );
    }

    method exit { $system->despawn( $self ) }

    method kill ($actor_ref) {
        $actor_ref isa ActorRef || ::confess 'The `$actor_ref` arg must be an ActorRef';

        $system->despawn( $actor_ref );
    }
}

# -----------------------------------------------------------------------------
# ActorSystem
# -----------------------------------------------------------------------------
# The ActorSystem does a number of things:
# - it manages ActorRef instances of spawned Actors
# - it handles the Message delivery queue
# - it manages the loop within which the Actors live
# -----------------------------------------------------------------------------

class ActorSystem {
    my $PIDS = 0;

    field %actor_refs;
    field @deferred;
    field @msg_queue;
    field @dead_letter_queue;

    field $init :param;

    use constant DEBUG => $ENV{DEBUG} // 0;

    my sub LINE ($label) { warn join ' ' => '--', $label, ('-' x (80 - length $label)), "\n" }
    my sub LOG  (@msg)   { warn @msg, "\n" }

    method spawn ($actor) {
        $actor isa Actor || ::confess 'The `$actor` arg must be an Actor';

        my $a = ActorRef->new( pid => ++$PIDS, system => $self, actor => $actor );
        $actor_refs{ $a->pid } = $a;
        $a;
    }

    method despawn ($actor_ref) {
        $actor_ref isa ActorRef || ::confess 'The `$actor_ref` arg must be an ActorRef';

        push @deferred => sub {
            LOG "Despawning ".$actor_ref->pid if DEBUG;
            delete $actor_refs{ $actor_ref->pid };
        };
    }

    method enqueue_message ($message) {
        $message isa Message || ::confess 'The `$message` arg must be a Message';

        push @msg_queue => $message;
    }

    method drain_messages {
        my @msgs   = @msg_queue;
        @msg_queue = ();
        return @msgs;
    }

    method add_to_dead_letter ($reason, $message) {
        push @dead_letter_queue => [ $reason, $message ];
    }


    method run_deferred ($phase) {
        return unless @deferred;
        LOG ">>> deferred[ $phase ]" if DEBUG;
        (shift @deferred)->() while @deferred;
    }

    method exit_loop {
        if (DEBUG) {
            @dead_letter_queue and say "Dead Letter Queue:\n".join "\n" => map { join ', ' => @$_ } @dead_letter_queue;
            %actor_refs        and say "Zombies:\n".join ", " => sort { $a <=> $b } keys %actor_refs;
        }
    }

    method run_init {
        my $init_ctx = $self->spawn( Actor->new );
        $init->( $init_ctx );
        $self->despawn($init_ctx);
    }

    method tick {
        my @msgs = $self->drain_messages;
        while (@msgs) {
            my $msg = shift @msgs;
            if ( my $actor_ref = $actor_refs{ $msg->to->pid } ) {
                try {
                    $actor_ref->actor->apply( $actor_ref, $msg );
                } catch ($e) {
                    $self->add_to_dead_letter( $e => $msg );
                }
            }
            else {
                $self->add_to_dead_letter( ACTOR_NOT_FOUND => $msg );
            }
        }
    }

    method loop ($delay=undef) {

        LINE "init" if DEBUG;
        $self->run_init;

        LINE "start" if DEBUG;
        while (1) {
            LINE "tick" if DEBUG;
            $self->tick;
            $self->run_deferred('idle');
            last unless @msg_queue;
            ::sleep($delay) if defined $delay;
        }
        LINE "exiting" if DEBUG;

        $self->run_deferred('cleanup');
        $self->exit_loop;

        LINE "exited" if DEBUG;
        return;
    }

}

# -----------------------------------------------------------------------------
# PingPong Actor
# -----------------------------------------------------------------------------
# This is an example of a subclasses Actor. It ping/pongs back and forth
# until it reaches it's max, then stops and kills the other.
#
# NOTE:
# I am using GLOBs for the Event symbol, which works out nicely as it will
# warn if we create one that doesn't already exist. They are also already
# namespaced and essentially singletons, so we do not need to manage them.
# -----------------------------------------------------------------------------

class PingPong :isa(Actor) {

    field $name :param;  # so I can identify myself in the logs
    field $max  :param;  # the max number of ping/pong(s) to allow

    # counters for ping/pong(s)
    field $pings = 0;
    field $pongs = 0;

    my sub _exit_both ($ctx, $a) {  $ctx->exit; $ctx->kill( $a ) }

    method Ping ($ctx, $message) {
        if ($pings < $max) {
            say "got Ping($name)[$pings] <= $max";
            $ctx->send( $message->from, Event->new( symbol  => *Pong ) );
            $pings++;
        }
        else {
            say "!!! ending Ping at($name)[$pings] <= $max";
            _exit_both( $ctx, $message->from );
        }
    }

    method Pong ($ctx, $message) {
        if ($pongs < $max) {
            say "got Pong($name)[$pongs] <= $max";
            $ctx->send( $message->from, Event->new( symbol  => *Ping ) );
            $pongs++;
        }
        else {
            say "!!! ending Pong at($name)[$pongs] <= $max";
            _exit_both( $ctx, $message->from );
        }
    }
}

# -----------------------------------------------------------------------------
# `init` function
# -----------------------------------------------------------------------------
# This function is called before the ActorSystem loop starts and it used to
# get the ActorSystem started. The function gets an ActorRef instance as
# context, which can be used to spawn Actors and send Messages.
#
# NOTE:
# This ActorRef actually wraps a plain Actor instance with no methods beyond
# `apply`, so sending messages to it is not useful. This ActorRef will also
# be immediately despawned after the `init` function finishes, so it will not
# be alive long enough to get messages either.
# -----------------------------------------------------------------------------

sub init ($ctx) {
    foreach ( 1 .. 10 ) {
        my $max = int(rand(10));

        my $Ping = $ctx->spawn( PingPong->new( name => "Ping($_)", max => $max ) );
        my $Pong = $ctx->spawn( PingPong->new( name => "Pong($_)", max => $max ) );

        $Ping->send( $Pong, Event->new( symbol => *PingPong::Pong ) );
    }
}

# -----------------------------------------------------------------------------
# Lets-ago!
# -----------------------------------------------------------------------------

ActorSystem->new( init => \&init )->loop( 0.5 );

1;







