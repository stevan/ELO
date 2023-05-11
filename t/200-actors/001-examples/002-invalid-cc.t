#!perl

use v5.36;
use experimental 'try', 'builtin';
use builtin 'ceil';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :types :events ];
use ok 'ELO::Timers', qw[ :timers ];
use ok 'ELO::Actors', qw[ receive ];

my $log = Test::ELO->create_logger;

=pod

# System Features

- Ingest of DataFeed
    - periodic cron job with spread load

- Store of DataFeed
    - keep $n entries, drop old ones

- Query of Stored DataFeed
    1) interactive from outside service (CC -> bool)
    2) get data since -> [[ CC, timestamp], ... ]

- Bulk Check of Reseavations
    1) Query reservations since $n with matching bad CCs
    2) Send bad CC numbers back to Reservation

# Outside entities

- Data Feed
    - sustained rate, but variable querying time

- Interactive tester
    - should be random

- Reservation System
    - gets new data at random intervals
    - query data since $n
    - set CC invalid

=cut

# ...

type *TimeStamp => *Float;

event *eGetLatestDataFeed => (*Process);
event *eDataFeedResponse  => (*TimeStamp, *ArrayRef);

sub DataFeed ($baud=10) {

    my $last_id = 0;
    my $last_epoch;

    my sub format_packet ($packet) { sprintf '0123-4567-8910-%04d' => $packet }

    receive {
        *eGetLatestDataFeed => sub ($this, $caller) {

            my $now        = $this->loop->now;
            my $frame_size = $baud;

            if ( $last_epoch ) {
                my $duration = sprintf '%0.1f' => $now - $last_epoch;
                $frame_size  = ceil( $baud * $duration );
                $log->warn( $this, "It has been $duration since the last request, delivering $frame_size" );
            }
            else {
                $log->warn( $this, "It no last request time, delivering basic frame-size $frame_size" );
            }

            $last_epoch = $now;

            $this->send( $caller =>
                [ *eDataFeedResponse,
                    $last_epoch,
                    [ map format_packet( ++$last_id ), 1 .. $frame_size ]
                ]
            );
        }
    };
}

# ...

event *eInsertData     => (*TimeStamp, *ArrayRef);
event *eQueryDataSince => (*TimeStamp);

#event *eDataExists => (*Str, *Process);

sub FeedDatabase ($window_size=100) {

    my @data;  # [ [ $number, $timestamp ], ... ]

    receive {
        *eInsertData => sub ($this, $timestamp, $data_set) {
            $log->debug( $this, [ "INSERT", (scalar @$data_set), $data_set ] );
            push @data => map [ $_, $timestamp ], @$data_set;
            shift @data until scalar @data <= $window_size;
            $log->info( $this, [ "AFTER INSERT", (scalar @data), $data[0], $data[-1] ] );
        },

        *eQueryDataSince => sub ($this, $since) {
            $log->debug( $this, [ "SELECT LATEST SINCE $since" ] );

            my @results = grep $_->[1] >= $since, @data;

            $log->fatal( $this, \@results );
        },
    };
}

# ...

event *eStartConsumer => (*Float);
event *eStopConsumer;

sub PeriodicConsumer ($feed, $fdb) {

    my $interval_timer;

    receive {
        *eStartConsumer => sub ($this, $interval) {
            $log->info( $this, 'Starting PeriodicConsumer with interval of '.$interval );
            $interval_timer = interval(
                $this,
                $interval,
                [ $feed, [ *eGetLatestDataFeed => $this ] ]
            );
        },
        *eStopConsumer => sub ($this) {
            $log->info( $this, 'Stopping PeriodicConsumer' );
            cancel_timer( $this, $interval_timer );
            undef $interval_timer;
        },

        # responses ...
        *eDataFeedResponse => sub ($this, $timestamp, $data_set) {
            $log->debug( $this, [ "Sending Data Feed Response to DB", $timestamp, scalar @$data_set, $data_set ] );
            $this->send( $fdb, [ *eInsertData => $timestamp, $data_set ] );
        }
    };
}

# ...

sub DataFeed::Debug () {
    receive {
        *eDataFeedResponse => sub ($this, $timestamp, $args) {
            $log->info( $this, [ $timestamp, scalar @$args, $args ] );
        }
    };
}

sub init ($this, $msg=[]) {

    my $fdb  = $this->spawn( FeedDatabase( 250 ) );
    my $feed = $this->spawn( DataFeed() );
    my $cron = $this->spawn( PeriodicConsumer( $feed, $fdb ) );

    $this->send( $cron, [ *eStartConsumer => 1 ] );

    my $last = $this->loop->now;

    my $i1 = interval( $this, 5, sub {
        $this->send( $fdb, [ *eQueryDataSince => $last ]);
        $last = $this->loop->now;
    });

    timer( $this, 20, sub {
        $this->send( $cron, [ *eStopConsumer ] );
        cancel_timer( $this, $i1 );
    });


    # async control flow ;)
    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



