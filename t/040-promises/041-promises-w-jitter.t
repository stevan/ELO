#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Actors',   qw[ match ];
use ok 'ELO::Promises', qw[ promise collect ];
use ok 'ELO::Timers',   qw[ timer ];

my $log = Test::ELO->create_logger;

sub jitter { int(rand(25)) }

sub Service ($this, $msg) {

    $log->debug( $this, $msg );

    match $msg, state $handlers = +{
        # $request  = eServiceRequest  [ action : Str, args : [Int, Int], caller : PID ]
        # $response = eServiceResponse [ Int ]
        # $error    = eServiceError    [ error : Str ]
        eServiceRequest => sub ($action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => $promise });

            isa_ok($promise, 'ELO::Core::Promise');

            my $timeout = jitter();
            timer(
                $this,
                $timeout,
                sub {
                    my ($x, $y) = @$args;
                    $log->info( $this, "Resolving Promise[$x] : ($promise) after timeout($timeout)" );
                    eval {
                        $promise->resolve([
                            eServiceResponse => (
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
                        $promise->reject([ eServiceError => ( $e ) ]);
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
        timer(
            $this,
            $timeout,
            sub {
                $log->info( $this, "Sending Promise[$i] : ($promise) after timeout($timeout)" );
                $this->send( $service, [ eServiceRequest => ( add => [ $i, $i ], $promise ) ] );
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

