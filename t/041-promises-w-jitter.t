#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors   qw[ match ];
use ELO::Timers   qw[ timer ];
use ELO::Promises qw[ promise collect ];

use ELO::Util::Logger;

my $log = ELO::Util::Logger->new;

sub jitter { int(rand(25)) }

sub Service ($this, $msg) {

    $log->debug( $this, [ $msg->@[ 0 .. $#{$msg}-1 ], "".$msg->[-1] ] );

    match $msg, state $handlers = +{
        # $request  = eServiceRequest  [ action : Str, args : [Int, Int], caller : PID ]
        # $response = eServiceResponse [ Int ]
        # $error    = eServiceError    [ error : Str ]
        eServiceRequest => sub ($action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => "$promise" });

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

    my @promises;
    foreach my $i (0 .. 10) {
        my $promise = promise;
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
            },
            sub ($error) { $log->error( $this, $error ) }
        );
}

ELO::Loop->run( \&init, with_promises => 1 );


__END__

