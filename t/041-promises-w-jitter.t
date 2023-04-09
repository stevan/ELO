#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors   qw[ match ];
use ELO::Timers   qw[ timer ];
use ELO::Promises qw[ promise collect ];

use constant DEBUG => $ENV{DEBUG} || 0;

sub jitter { int(rand(25)) }

sub Service ($this, $msg) {

    warn Dumper +{ ServiceGotMessage => 1, $this->pid => $msg } if DEBUG > 3;

    match $msg, state $handlers = +{
        # $request  = eServiceRequest  [ action : Str, args : [Int, Int], caller : PID ]
        # $response = eServiceResponse [ Int ]
        # $error    = eServiceError    [ error : Str ]
        eServiceRequest => sub ($action, $args, $promise) {
            warn "HELLO FROM Service :: eServiceRequest" if DEBUG;
            warn Dumper { action => $action, args => $args, promise => "$promise" } if DEBUG;

            my $timeout = jitter();
            timer(
                $this,
                $timeout,
                sub {
                    my ($x, $y) = @$args;
                    say "Resolving Promise[$x] : ($promise) after timeout($timeout)";
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
                say "Sending Promise[$i] : ($promise) after timeout($timeout)";
                $this->send( $service, [ eServiceRequest => ( add => [ $i, $i ], $promise ) ] );
            }
        );
        $promise->then(
            sub ($event) {
                my ($etype, $result) = @$event;
                say "Got Result Promise[$i] : ($promise) with result($result)";
            }
        );

        push @promises => $promise;
    }

    collect( @promises )
        ->then(
            sub ($events) {
                my @values = map $_->[1], @$events;
                say "GOT FINAL RESULTS:[ " . (join ", " => @values)." ]";
            },
            sub ($error) { warn Dumper +{ error => $error } }
        );
}

ELO::Loop->run( \&init, with_promises => 1 );


__END__

