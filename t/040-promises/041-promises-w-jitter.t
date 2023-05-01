#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Types',    qw[ :core event ];
use ok 'ELO::Actors',   qw[ match ];
use ok 'ELO::Promises', qw[ promise collect ];
use ok 'ELO::Timers',   qw[ ticker ];

my $log = Test::ELO->create_logger;

event *eServiceRequest   => ( *Str, [ *Int, *Int ], *Promise ); # action : Str, args : [Int, Int], promise
event *eServiceResponse  => ( *Int );                           # Int
event *eServiceError     => ( *Str );                           # error : Str

sub jitter { int(rand(25)) }

sub Service ($this, $msg) {

    $log->debug( $this, $msg );

    match $msg, state $handlers = +{
        *eServiceRequest => sub ($action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => $promise });

            isa_ok($promise, 'ELO::Core::Promise');

            my $timeout = jitter();
            ticker(
                $this,
                $timeout,
                sub {
                    my ($x, $y) = @$args;
                    $log->info( $this, "Resolving Promise[$x] : ($promise) after timeout($timeout)" );
                    eval {
                        $promise->resolve([
                            *eServiceResponse => (
                                ($action eq 'add') ? ($x + $y) :
                                ($action eq 'sub') ? ($x - $y) :
                                ($action eq 'mul') ? ($x * $y) :
                                ($action eq 'div') ? ($x / $y) :
                                die "Invalid Action: $action"
                            )
                        ]);
                        1;
                    } or do {
                        my $e = $@;
                        chomp $e;
                        $promise->reject([ *eServiceError => ( $e ) ]);
                    };
                }
            );
        }
    }
}

sub init ($this, $msg=[]) {

    my $service = $this->spawn( Service  => \&Service );
    isa_ok($service, 'ELO::Core::Process');

    my @promises;
    foreach my $i (0 .. 10) {
        my $promise = promise;
        isa_ok($promise, 'ELO::Core::Promise');

        my $timeout = jitter();
        ticker(
            $this,
            $timeout,
            sub {
                $log->info( $this, "Sending Promise[$i] : ($promise) after timeout($timeout)" );
                $this->send( $service, [ *eServiceRequest => ( add => [ $i, $i ], $promise ) ] );
            }
        );
        $promise->then(
            sub ($event) {
                my ($etype, $result) = @$event;
                $log->info( $this, "Got Result Promise[$i] : ($promise) with result($result)" );
            }
        );

        push @promises => $promise;
    }

    collect( @promises )
        ->then(
            sub ($events) {
                my @values = map $_->[1], @$events;
                $log->info( $this, +{ results => \@values } );
                eq_or_diff(
                    \@values,
                    [ 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20 ],
                    '... got the expected response values'
                );
            },
            sub ($error)  {
                $log->error( $this, $error );

                fail('... got an unexpected error: '.$error);
            },
        );
}

ELO::Loop->run( \&init, with_promises => 1, logger => $log );

done_testing;

__END__

