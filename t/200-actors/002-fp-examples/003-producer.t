#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match build_actor ];
use ok 'ELO::Timers', qw[ timer cancel_timer interval ];

my $log = Test::ELO->create_logger;

sub jitter ($max, $multipler=1) { rand($max) * $multipler }

our $POLL_TICK_INTERVAL           = 2;
our $POLL_TICK_INTERVAL_MULTIPLER = 2;

our $MAX_WORK_TIME           = 3;
our $MAX_WORK_TIME_MULTIPLER = 1.5;

our $NUM_WORKERS = 5;

our @DATASOURCE = 0 .. 15;
#die Dumper \@DATASOURCE;

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
                eStartProducer => sub ($r) {
                    $log->info( $this, '... starting Producer with router('.$r->pid.') ... become(standby)' );
                    $router //= $r;
                    push @state_history => $active_state = 'standby';

                    # this is just to pump the datasource for non-null values
                    push @intervals => jitter($POLL_TICK_INTERVAL, $POLL_TICK_INTERVAL_MULTIPLER);
                    $interval_id = timer( $this, $intervals[-1], sub {
                        $log->warn( $this, '... sending ePollTick to self' );
                        $this->send_to_self([ ePollTick => () ]);
                        push @intervals => jitter($POLL_TICK_INTERVAL, $POLL_TICK_INTERVAL_MULTIPLER);
                        $interval_id = timer( $this, $intervals[-1], __SUB__ );
                    });
                }
            },

            standby => {
                ePollTick => sub () {
                    $log->info( $this, '... Producer.standby got ePollTick' );
                },
                eContinue => sub ($sender) {
                    $log->info( $this, '... Producer.standby got eContinue from sender('.$sender->pid.')' );
                    my $item = shift @$datasource;
                    if ( defined $item ) {
                        $log->info( $this, '... Producer.standby[eContinue] sending eItem('.$item.') to router('.$router->pid.')' );
                        $this->send( $router, [ eItem => $this, $item ] );
                    }
                    elsif ( scalar @$datasource == 0 ) {
                        $log->info( $this, '... Producer.standy[eContinue] no more items, sending eCompleted to router('.$router->pid.')' );
                        $this->send( $router, [ eCompleted => ($this) ]);
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
                ePollTick => sub () {
                    $log->info( $this, '... Producer.polling got ePollTick' );
                    my $item = shift @$datasource;
                    if ( defined $item ) {
                        $log->info( $this, '... Producer.polling[ePollTick] sending eItem('.$item.') to router('.$router->pid.') ... become(standby)' );
                        $this->send( $router, [ eItem => $this, $item ] );
                        push @state_history => $active_state = 'standby';
                    }
                    elsif ( scalar @$datasource == 0 ) {
                        $log->info( $this, '... Producer.polling[ePollTick] no more items, sending eCompleted to router('.$router->pid.')' );
                        $this->send( $router, [ eCompleted => ($this) ]);
                        cancel_timer( $this, $interval_id );
                        push @state_history => $active_state = 'empty';
                    }
                    else {
                        $log->info( $this, '... Producer.polling[ePollTick] got undefined item from Datasoure' );
                    }
                },
                eContinue => sub ($sender) {
                    $log->info( $this, '... Producer.polling got eContinue from sender('.$sender->pid.')' );
                },
            },

            empty => {
                ePollTick         => sub ()        { die Dumper [ "Cannot call ePollTick on an empty producer", $datasource, @intervals ] },
                eContinue         => sub ($sender) { die "Cannot call eContinue on an empty producer" },
                eShutdownProducer => sub ($sender) {
                    $log->warn( $this, '... eShutdownProducer => got shutdown from sender('.$sender->pid.')');
                    $this->send( $debugger, [ eCollectShutdownData => $this, { eShutdownProducer => {
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
            eStartRouter => sub ($p) {
                $log->info( $this, '... starting Router with producer('.$p->pid.')' );
                $producer //= $p;
                $this->loop->next_tick(sub {
                    $this->send( $producer, [ eContinue => ($this) ] )
                });
            },
            eShutdownRouter => sub ($sender) {
                $log->warn( $this, '... eShutdownRouter => got shutdown from sender('.$sender->pid.')');
                $log->warn( $this, '... eShutdownRouter => sending shutdown to producer('.$producer->pid.')');
                $this->send( $producer, [ eShutdownProducer => ($this) ] );
                $log->warn( $this, '... eShutdownWorker => sending shutdown to workers('.(join ', ' => map { $_->pid } @downstream_queue).')');
                $this->send( $_, [ eShutdownWorker => ($this) ] ) foreach  @downstream_queue;
                $this->send( $debugger, [ eCollectShutdownData => $this, {
                    eShutdownRouter => {
                        upstream_queue   => \@upstream_queue,
                        downstream_queue => [ map { $_->pid } @downstream_queue ],
                        workers          => \%registered_workers,
                    }
                }]);
                $this->exit(0);
            },

            eRegister => sub ($worker) {
                $log->info( $this, '... got eRegister from worker('.$worker->pid.')' );
                $registered_workers{ $worker->pid }++;
                $this->send_to_self([ eContinue => ($worker) ] );
            },

            eContinue => sub ($sender) {
                $log->info( $this, '... got eContinue from sender('.$sender->pid.')' );
                if ( scalar @upstream_queue == 0 ) {
                    $log->info( $this, '... eContinue => nothing in the upstream, adding sender('.$sender->pid.') to downstream');
                    push @downstream_queue => $sender;

                    # if the producer has completed, and all the workers have reported back, we can start shutdown ..
                    if ( $producer_completed && scalar @downstream_queue == scalar keys %registered_workers ) {
                        $log->warn( $this, '... eContinue => no more items to process, and all workers have reported back and producer('.$producer->pid.') is Completed');
                        $this->send_to_self([ eShutdownRouter => ($this) ]);
                    }
                    elsif ( $producer_completed ) {
                        $log->warn( $this, '... eContinue => no more items to process, some workers are still busy, and producer('.$producer->pid.') is Completed');
                    }
                }
                else {
                    my $item = shift @upstream_queue;
                    $log->info( $this, '... eContinue => got item('.$item.') from upstream, sending eItem to sender('.$sender->pid.') and eContinue to producer('.$producer->pid.')');
                    $this->send( $sender,   [ eItem     => ($this, $item) ] );
                    $this->send( $producer, [ eContinue => ($this)        ] );
                }
            },

            eItem => sub ($sender, $item) {
                $log->info( $this, '... got eItem from sender('.$sender->pid.')' );
                if ( scalar @downstream_queue == 0 ) {
                    $log->info( $this, '... eItem => nothing in the downstream, adding item('.$item.') to upstream');
                    push @upstream_queue => $item;
                }
                else {
                    my $consumer = shift @downstream_queue;
                    $log->info( $this, '... eItem => got consumer('.$consumer->pid.') from downstream, sending eItem to consumer('.$consumer->pid.') and eContinue to producer('.$producer->pid.')');
                    $this->send( $consumer, [ eItem     => ($this, $item) ] );
                    $this->send( $producer, [ eContinue => ($this)        ] );
                }
            },

            eCompleted => sub ($sender) {
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
            eStartWorker => sub ($r) {
                $log->info( $this, '... eStartWorker : starting Worker with router('.$r->pid.')' );
                $router //= $r;
                $this->loop->next_tick(sub {
                    $log->info( $this, '... eStartWorker : sending eContinue to router('.$router->pid.')' );
                    $this->send( $router, [ eRegister => ($this) ] );
                });
            },
            eShutdownWorker => sub ($sender) {
                $log->warn( $this, '... eShutdownWorker => got shutdown from sender('.$sender->pid.')');
                $this->send( $debugger, [ eCollectShutdownData => $this, {
                    processing => \@processing,
                    processed  => \@processed,
                    timers     => \@timers
                }]);
                $this->exit(0);
            },
            eItem => sub ($sender, $item) {
                $log->info( $this, '... eItem : starting job with item('.$item.') from sender('.$sender->pid.')' );
                $log->warn( $this, '... eItem : sleeping instead of working ;)' );
                push @processing => $item;
                push @timers => jitter($MAX_WORK_TIME, $MAX_WORK_TIME_MULTIPLER);
                timer( $this, $timers[-1], sub {
                    $log->warn( $this, '... eItem : waking up and sending eContinue to router('.$router->pid.')' );
                    $this->send( $router, [ eContinue => ($this) ] );
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

    match $msg, state $handler //= +{
        eCollectShutdownData => sub ($sender, $data) {
            my $dataset = $data{ $sender->pid } //= [];
            $data->{pid} = $sender->pid;
            push @$dataset => $data;
            $counter++;
            if ( $counter == $NUM_WORKERS + 2 ) {

                my ($producer) = grep /\d\d\d\:Producer/, keys %data;
                $producer = $data{$producer};

                say 'Poll Intervals:';
                say foreach $producer->[0]->{eShutdownProducer}->{intervals}->@*;
                say '';

                my @workers;
                my @stats;
                foreach my $worker ( grep /\d\d\d\:Worker/, keys %data ) {
                    my $stats = $data{ $worker };

                    push @workers => @$stats;
                    #warn Dumper $stats;
                    foreach my $stat ( @$stats ) {
                        foreach my $i ( 0 .. $stat->{processed}->$#* ) {
                            push @stats => [
                                $stat->{processed}->[$i],
                                $stat->{timers}->[$i],
                                $worker,
                            ]
                        }
                    }
                }

                #foreach my $sort (0, 1) {
                #    # sort them ...
                #    @stats = sort { $a->[$sort] <=> $b->[$sort] } @stats;
                #    {
                #        my $divider = '+------+-------+------------+';
                #        say $divider;
                #        say '|  id  | timer | pid        |';
                #        say $divider;
                #        foreach my $stat (@stats) {
                #            say sprintf '| %4d | %.03f | %s |' => @$stat;
                #        }
                #        say $divider;
                #    }
                #}

                @workers = sort { $a->{pid} cmp $b->{pid} } @workers;

                {
                    say '+------------+';
                    say '| pid->items |';
                    say '+------------+';
                    foreach my $worker (@workers) {
                        say sprintf '| %s | (%s) ' => $worker->{pid}, (join ', ' => $worker->{processed}->@*);
                    }
                    say '+------------+';
                }

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

    $this->send( $producer, [ eStartProducer => $router   ] );
    $this->send( $router,   [ eStartRouter   => $producer ] );

    # start workers ...
    $this->send( $_, [ eStartWorker => $router ] ) foreach @workers;

    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;


