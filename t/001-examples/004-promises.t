#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Types',    qw[ :core ];
use ok 'ELO::Events',   qw[ event ];
use ok 'ELO::Actors',   qw[ match ];
use ok 'ELO::Promises', qw[ promise collect ];

my $log = Test::ELO->create_logger;

# FIXME: this should be this ...
# event *eServiceRequest   => ( *Str, [ *Int, *Int ], *Promise );

event *eServiceRequest   => ( *Str, *ArrayRef, *Promise ); # action : Str, args : [Int, Int], promise
event *eServiceResponse  => ( *Int );                      # Int
event *eServiceError     => ( *Str );                      # error : Str

event *eServiceClientRequest => ( *Process, *Str, *ArrayRef ); # service, action, args

sub Service ($this, $msg) {

    $log->debug( $this, $msg );

    # NOTE:
    # this is basically a stateless service,
    # and uses Promises instead of the callback
    # format used in other tests.

    match $msg, state $handlers //= +{
        *eServiceRequest => sub ($action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => $promise });

            isa_ok($promise, 'ELO::Core::Promise');

            my ($x, $y) = @$args;

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
    }
}

sub ServiceClient ($this, $msg) {

    state $expected = [ 28, 108 ];

    $log->debug( $this, $msg );

    match $msg, state $handlers //= +{

        # Requests ...
        *eServiceClientRequest => sub ($service, $action, $args) {
            isa_ok($service, 'ELO::Core::Process');

            $log->debug( $this, "HELLO FROM ServiceClient :: eServiceClientRequest" );
            $log->debug( $this, +{ service => $service, action => $action, args => $args });

            my @promises;
            foreach my $op ( @$args ) {
                my $p = promise; # [ *eServiceResponse, *eServiceError ]
                isa_ok($p, 'ELO::Core::Promise');
                $this->send( $service, [ *eServiceRequest => ( @$op, $p ) ]);
                push @promises => $p;
            }

            collect( @promises )
                ->then(
                    sub ($results) {
                        my @values = map { $_->[1] } @$results;
                        my $sum = 0;
                        foreach my $value (@values) {
                            $sum += $value;
                        }
                        return $sum;
                    }
                )
                ->then(
                    sub ($result) {
                        $log->info( $this, $result );

                        is($result, (shift @$expected), '... got the expected result');
                    },
                    sub ($error)  {
                        $log->error( $this, $error );

                        fail('... got an unexpected error: '.$error);
                    },
                );
        },
    }
}

sub init ($this, $msg=[]) {

    my $service = $this->spawn( Service  => \&Service       );
    my $client  = $this->spawn( Client   => \&ServiceClient );

    isa_ok($service, 'ELO::Core::Process');
    isa_ok($client, 'ELO::Core::Process');

    $this->send( $client, [
        *eServiceClientRequest => (
            $service,
            sum => [
                [ add => [ 2, 2 ] ],
                [ add => [ 3, 3 ] ],
                [ add => [ 4, 4 ] ],
                [ add => [ 5, 5 ] ],
            ]
        )
    ]);

    $this->send( $client, [
        *eServiceClientRequest => (
            $service,
            sum => [
                [ add => [ 12, 12 ] ],
                [ add => [ 13, 13 ] ],
                [ add => [ 14, 14 ] ],
                [ add => [ 15, 15 ] ],
            ]
        )
    ]);

}

ELO::Loop->run( \&init, with_promises => 1, logger => $log  );

done_testing;

__END__

