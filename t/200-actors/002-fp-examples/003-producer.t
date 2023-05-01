#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use List::Util qw[ max min ];

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core event ];
use ok 'ELO::Actors', qw[ match build_actor ];
use ok 'ELO::Timers', qw[ :timers ];

my $log = Test::ELO->create_logger;

sub jitter ($max, $multipler=1) { rand($max) * rand($multipler) }

our $POLL_TICK_INTERVAL           = 2;
our $POLL_TICK_INTERVAL_MULTIPLER = 1;

our $MAX_WORK_TIME           = 2;
our $MAX_WORK_TIME_MULTIPLER = 1.5;

our $NUM_WORKERS = 5;

our @DATASOURCE = 0 .. 20;
#die Dumper \@DATASOURCE;

event *eStartProducer    => ( *Process );
event *eShutdownProducer => ( *Process );
    event *ePollTick     => ();

event *eStartRouter    => ( *Process );
event *eShutdownRouter => ( *Process );
    event *eRegister   => ( *Process );

event *eContinue      => ( *Process );
event *eCompleted     => ( *Process );

event *eStartWorker    => ( *Process );
event *eShutdownWorker => ( *Process );

event *eItem => ( *Process, *Int );

event *eCollectShutdownData => ( *Process, *HashRef );

sub ProducerFactory (%args) {

    my $debugger   = $args{debugger};
    my $datasource = $args{datasource} // die 'You must specify a `datasource` for a Producer';

    return build_actor Producer => sub ($this, $msg) {

        state $router;
        state $interval_id;
        state @intervals;

        state $active_state = 'init';
        state @state_history = ($active_state);
        state $states = +{

            init => {
                *eStartProducer => sub ($r) {
                    $log->info( $this, '... starting Producer with router('.$r->pid.') ... become(standby)' );
                    $router //= $r;
                    push @state_history => $active_state = 'standby';

                    # this is just to pump the datasource for non-null values
                    push @intervals => jitter($POLL_TICK_INTERVAL, $POLL_TICK_INTERVAL_MULTIPLER);
                    $interval_id = timer( $this, $intervals[-1], sub {
                        $log->warn( $this, '... sending ePollTick to self' );
                        $this->send_to_self([ *ePollTick => () ]);
                        push @intervals => jitter($POLL_TICK_INTERVAL, $POLL_TICK_INTERVAL_MULTIPLER);
                        $interval_id = timer( $this, $intervals[-1], __SUB__ );
                    });
                }
            },

            standby => {
                *ePollTick => sub () {
                    $log->info( $this, '... Producer.standby got ePollTick' );
                },
                *eContinue => sub ($sender) {
                    $log->info( $this, '... Producer.standby got eContinue from sender('.$sender->pid.')' );
                    my $item = shift @$datasource;
                    if ( defined $item ) {
                        $log->info( $this, '... Producer.standby[eContinue] sending eItem('.$item.') to router('.$router->pid.')' );
                        $this->send( $router, [ *eItem => $this, $item ] );
                    }
                    elsif ( scalar @$datasource == 0 ) {
                        $log->info( $this, '... Producer.standy[eContinue] no more items, sending eCompleted to router('.$router->pid.')' );
                        $this->send( $router, [ *eCompleted => ($this) ]);
                        cancel_timer( $this, $interval_id );
                        push @state_history => $active_state = 'empty';
                    }
                    else {
                        $log->info( $this, '... Producer.standby[eContinue] no item found, ... become(polling)' );
                        push @state_history => $active_state = 'polling';
                    }
                },
            },

            polling => {
                *ePollTick => sub () {
                    $log->info( $this, '... Producer.polling got ePollTick' );
                    my $item = shift @$datasource;
                    if ( defined $item ) {
                        $log->info( $this, '... Producer.polling[ePollTick] sending eItem('.$item.') to router('.$router->pid.') ... become(standby)' );
                        $this->send( $router, [ *eItem => $this, $item ] );
                        push @state_history => $active_state = 'standby';
                    }
                    elsif ( scalar @$datasource == 0 ) {
                        $log->info( $this, '... Producer.polling[ePollTick] no more items, sending eCompleted to router('.$router->pid.')' );
                        $this->send( $router, [ *eCompleted => ($this) ]);
                        cancel_timer( $this, $interval_id );
                        push @state_history => $active_state = 'empty';
                    }
                    else {
                        $log->info( $this, '... Producer.polling[ePollTick] got undefined item from Datasoure' );
                    }
                },
                *eContinue => sub ($sender) {
                    $log->info( $this, '... Producer.polling got eContinue from sender('.$sender->pid.')' );
                },
            },

            empty => {
                *ePollTick         => sub ()        { die Dumper [ "Cannot call ePollTick on an empty producer", $datasource, @intervals ] },
                *eContinue         => sub ($sender) { die "Cannot call eContinue on an empty producer" },
                *eShutdownProducer => sub ($sender) {
                    $log->warn( $this, '... eShutdownProducer => got shutdown from sender('.$sender->pid.')');
                    $this->send( $debugger, [ *eCollectShutdownData => $this, { *eShutdownProducer => {
                        state_transitions => \@state_history,
                        intervals         => \@intervals,
                    } } ] );
                    $this->exit(0);
                }
            }
        };

        match $msg, ($states->{ $active_state } // die 'Could not find active state('.$active_state.')');
    }
}

sub RouterFactory (%args) {

    my $debugger = $args{debugger};

    return build_actor Router => sub ($this, $msg) {

        state %registered_workers;
        state $producer;
        state $producer_completed;
        state @upstream_queue;   # items
        state @downstream_queue; # workers

        match $msg, state $handler //= +{
            *eStartRouter => sub ($p) {
                $log->info( $this, '... starting Router with producer('.$p->pid.')' );
                $producer //= $p;
                $this->loop->next_tick(sub {
                    $this->send( $producer, [ *eContinue => ($this) ] )
                });
            },
            *eShutdownRouter => sub ($sender) {
                $log->warn( $this, '... eShutdownRouter => got shutdown from sender('.$sender->pid.')');
                $log->warn( $this, '... eShutdownRouter => sending shutdown to producer('.$producer->pid.')');
                $this->send( $producer, [ *eShutdownProducer => ($this) ] );
                $log->warn( $this, '... eShutdownWorker => sending shutdown to workers('.(join ', ' => map { $_->pid } @downstream_queue).')');
                $this->send( $_, [ *eShutdownWorker => ($this) ] ) foreach  @downstream_queue;
                $this->send( $debugger, [ *eCollectShutdownData => $this, {
                    *eShutdownRouter => {
                        upstream_queue   => \@upstream_queue,
                        downstream_queue => [ map { $_->pid } @downstream_queue ],
                        workers          => \%registered_workers,
                    }
                }]);
                $this->exit(0);
            },

            *eRegister => sub ($worker) {
                $log->info( $this, '... got eRegister from worker('.$worker->pid.')' );
                $registered_workers{ $worker->pid }++;
                $this->send_to_self([ *eContinue => ($worker) ] );
            },

            *eContinue => sub ($sender) {
                $log->info( $this, '... got eContinue from sender('.$sender->pid.')' );
                if ( scalar @upstream_queue == 0 ) {
                    $log->info( $this, '... eContinue => nothing in the upstream, adding sender('.$sender->pid.') to downstream');
                    push @downstream_queue => $sender;

                    # if the producer has completed, and all the workers have reported back, we can start shutdown ..
                    if ( $producer_completed && scalar @downstream_queue == scalar keys %registered_workers ) {
                        $log->warn( $this, '... eContinue => no more items to process, and all workers have reported back and producer('.$producer->pid.') is Completed');
                        $this->send_to_self([ *eShutdownRouter => ($this) ]);
                    }
                    elsif ( $producer_completed ) {
                        $log->warn( $this, '... eContinue => no more items to process, some workers are still busy, and producer('.$producer->pid.') is Completed');
                    }
                }
                else {
                    my $item = shift @upstream_queue;
                    $log->info( $this, '... eContinue => got item('.$item.') from upstream, sending eItem to sender('.$sender->pid.') and eContinue to producer('.$producer->pid.')');
                    $this->send( $sender,   [ *eItem     => ($this, $item) ] );
                    $this->send( $producer, [ *eContinue => ($this)        ] );
                }
            },

            *eItem => sub ($sender, $item) {
                $log->info( $this, '... got eItem from sender('.$sender->pid.')' );
                if ( scalar @downstream_queue == 0 ) {
                    $log->info( $this, '... eItem => nothing in the downstream, adding item('.$item.') to upstream');
                    push @upstream_queue => $item;
                }
                else {
                    my $consumer = shift @downstream_queue;
                    $log->info( $this, '... eItem => got consumer('.$consumer->pid.') from downstream, sending eItem to consumer('.$consumer->pid.') and eContinue to producer('.$producer->pid.')');
                    $this->send( $consumer, [ *eItem     => ($this, $item) ] );
                    $this->send( $producer, [ *eContinue => ($this)        ] );
                }
            },

            *eCompleted => sub ($sender) {
                $log->warn( $this, '... got eCompleted from sender('.$sender->pid.')' );
                $producer_completed = 1;
            }
        };
    }
}

sub WorkerFactory (%args) {

    my $debugger = $args{debugger};

    return build_actor Worker => sub ($this, $msg) {

        state $router;
        state @processing;
        state @processed;

        state @timers;

        match $msg, state $handler //= +{
            *eStartWorker => sub ($r) {
                $log->info( $this, '... eStartWorker : starting Worker with router('.$r->pid.')' );
                $router //= $r;
                $this->loop->next_tick(sub {
                    $log->info( $this, '... eStartWorker : sending eContinue to router('.$router->pid.')' );
                    $this->send( $router, [ *eRegister => ($this) ] );
                });
            },
            *eShutdownWorker => sub ($sender) {
                $log->warn( $this, '... eShutdownWorker => got shutdown from sender('.$sender->pid.')');
                $this->send( $debugger, [ *eCollectShutdownData => $this, {
                    processing => \@processing,
                    processed  => \@processed,
                    timers     => \@timers
                }]);
                $this->exit(0);
            },
            *eItem => sub ($sender, $item) {
                $log->info( $this, '... eItem : starting job with item('.$item.') from sender('.$sender->pid.')' );
                $log->warn( $this, '... eItem : sleeping instead of working ;)' );
                push @processing => $item;
                push @timers => jitter($MAX_WORK_TIME, $MAX_WORK_TIME_MULTIPLER);
                timer( $this, $timers[-1], sub {
                    $log->warn( $this, '... eItem : waking up and sending eContinue to router('.$router->pid.')' );
                    $this->send( $router, [ *eContinue => ($this) ] );
                    push @processed => pop @processing;

                    $log->info( $this, { pid => $this->pid, processing => \@processing, processed => \@processed, } );
                });
            }
        }
    }
}

sub Debugger ($this, $msg) {
    state $counter;

    state %data;

    state sub average (@numbers) {
      my $total;
      $total += $_ for @numbers;
      return $total / scalar @numbers;
    }

    match $msg, state $handler //= +{
        *eCollectShutdownData => sub ($sender, $data) {
            my $dataset = $data{ $sender->pid } //= [];
            $data->{pid} = $sender->pid;
            push @$dataset => $data;
            $counter++;
            if ( $counter == $NUM_WORKERS + 2 ) {

                my ($producer) = grep /\d\d\d\:Producer/, keys %data;
                $producer = $data{$producer};

                #say 'Poll Intervals:';
                #say sprintf ' %.05f' => $_ foreach $producer->[0]->{eShutdownProducer}->{intervals}->@*;
                #say '';

                my @workers = map $data{$_}->@*, grep /\d\d\d\:Worker/, keys %data;
                   @workers = sort { $a->{pid} cmp $b->{pid} } @workers;

                my @by_time;
                foreach my $worker (@workers) {
                    push @by_time => [
                        $worker->{pid},
                        (sprintf '%.06f' => max($worker->{timers}->@*)),
                        (sprintf '%.06f' => min($worker->{timers}->@*)),
                        (sprintf '%.06f' => average($worker->{timers}->@*)),
                        (join ', ' => $worker->{processed}->@*)
                    ];
                }

                @by_time = sort { $a->[3] <=> $b->[3] } @by_time;

                say '+------------+-----------+-----------+-----------+';
                say '|        pid | max(time) | min(time) | avg(time) |';
                say '+------------+-----------+-----------+-----------+';
                say sprintf '| %s | %9s | %9s | %9s | (%s) ' => @$_ foreach @by_time;
                say '+------------+-----------+-----------+-----------+';

            }
        }
    }
}

sub init ($this, $msg=[]) {

    # this is a singleton ...
    my $debugger = $this->spawn( Debugger => \&Debugger );
    my $router   = $this->spawn( Router   => RouterFactory( debugger => $debugger ) );
    my $producer = $this->spawn( Producer => ProducerFactory(
        datasource => \@DATASOURCE,
        debugger   => $debugger,
    ));

    my @workers  = map {
        $this->spawn( Worker => WorkerFactory( debugger => $debugger ) );
    } (1 .. $NUM_WORKERS);

    $this->send( $producer, [ *eStartProducer => $router   ] );
    $this->send( $router,   [ *eStartRouter   => $producer ] );

    # start workers ...
    $this->send( $_, [ *eStartWorker => $router ] ) foreach @workers;

    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;

__END__

Here is the example we copied:

 https://github.com/alexandru/scala-best-practices/blob/master/sections/5-actors.md

```scala
/**
 * Message signifying acknowledgement that upstream can send the next
 * item.
 */
case object Continue

/**
 * Message used by the producer for continuously polling the
 * data-source, while in the polling state.
 */
case object PollTick

/**
 * State machine with 2 states:
 *
 *  - Standby, which means there probably is a pending queue of items waiting to
 *    be sent downstream, but the actor is waiting for demand to be signaled
 *
 *  - Polling, which means that there is demand from downstream, but the
 *    actor is waiting for items to happen
 *
 * IMPORTANT: as a matter of protocol, this actor must not receive multiple
 *            Continue events - downstream Router should wait for an item
 *            to be delivered before sending the next Continue event to this
 *            actor.
 */
class Producer(source: DataSource, router: ActorRef) extends Actor {
  import Producer.PollTick

  override def preStart(): Unit = {
    super.preStart()
    // this is ignoring another rule I care about (actors should evolve
    // only in response to external messages), but we'll let that be
    // for didactical purposes
    context.system.scheduler.schedule(1.second, 1.second, self, PollTick)
  }

  // actor starts in standby state
  def receive = standby

  def standby: Receive = {
    case PollTick =>
      // ignore

    case Continue =>
      // demand signaled, so try to send the next item
      source.next() match {
        case None =>
          // no items available, go in polling mode
          context.become(polling)

        case Some(item) =>
          // item available, send it downstream,
          // and stay in standby state
          router ! item
      }
  }

  def polling: Receive = {
    case PollTick =>
      source.next() match {
        case None =>
          () // ignore - stays in polling
        case Some(item) =>
          // item available, demand available
          router ! item
          // go in standby
          context.become(standby)
      }
  }
}

/**
 * The Router is the middleman between the upstream Producer and
 * the Workers, keeping track of demand (to keep the producer simpler).
 *
 * NOTE: the protocol of Producer needs to be respected - so
 *       we are signaling a Continue to the upstream Producer
 *       after and only after a item has been sent downstream
 *       for processing to a worker.
 */
class Router(producer: ActorRef) extends Actor {
  var upstreamQueue = Queue.empty[Item]
  var downstreamQueue = Queue.empty[ActorRef]

  override def preStart(): Unit = {
    super.preStart()
    // signals initial demand to upstream
    producer ! Continue
  }

  def receive = {
    case Continue =>
      // demand signaled from downstream, if we have items to send
      // then send, otherwise enqueue the downstream consumer
      if (upstreamQueue.isEmpty) {
        downstreamQueue = downstreamQueue.enqueue(sender)
      }
      else {
        // no need to signal demand upstream, since we've got queued
        // items, just send them downstream
        val (item, newQueue) = upstreamQueue.dequeue
        upstreamQueue = newQueue
        sender ! item

        // signal demand upstream for another item
        producer ! Continue
      }

    case item: Item =>
      // item signaled from upstream, if we have queued consumers
      // then signal it downstream, otherwise enqueue it
      if (downstreamQueue.isEmpty) {
        upstreamQueue = upstreamQueue.enqueue(item)
      }
      else {
        val (consumer, newQueue) = downstreamQueue.dequeue
        downstreamQueue = newQueue
        consumer ! item

        // signal demand upstream for another item
        producer ! Continue
      }
  }
}

class Worker(router: ActorRef) extends Actor {
  override def preStart(): Unit = {
    super.preStart()
    // signals initial demand to upstream
    router ! Continue
  }

  def receive = {
    case item: Item =>
      process(item)
      router ! Continue
  }
}
```


