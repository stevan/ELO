#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',    qw[ :core :types :events ];
use ok 'ELO::Actors',   qw[ match receive ];
use ok 'ELO::Promises', qw[ promise collect ];

my $log = Test::ELO->create_logger;

enum *ListOps   => ( *Sum );
enum *ScalarOps => ( *Add, *Sub, *Mul, *Div );

protocol *ServiceProtocol => sub {
    event *eServiceRequest   => ( *ScalarOps, [ *Int, *Int ], *Promise ); # action : Str, args : [Int, Int], promise
    event *eServiceResponse  => ( *Num );                                 # Int
    event *eServiceError     => ( *Str );                                 # error : Str
};

protocol *ServiceClientProtocol => sub {
    event *eServiceClientRequest => ( *Process, *ListOps, *ArrayRef ); # service, action, args
};

sub Service () {

    receive[*ServiceProtocol], +{
        *eServiceRequest => sub ($this, $action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => $promise });

            isa_ok($promise, 'ELO::Core::Promise');

            my ($x, $y) = @$args;

            try {
                no warnings 'once';
                $promise->resolve([
                    *eServiceResponse => (
                        match [ *ScalarOps, $action ] => {
                            *Add => sub () { $x + $y },
                            *Sub => sub () { $x - $y },
                            *Mul => sub () { $x * $y },
                            *Div => sub () { $x / $y },
                        }
                    )
                ]);
            } catch ($e) {
                chomp $e;
                $log->fatal( $this, "Got error: eServiceRequest => $e" );
                $promise->reject([ *eServiceError => ( $e ) ]);
            }
        }
    }
}

sub ServiceClient () {

    state $expected = [ 28, 108 ];

    receive[*ServiceClientProtocol], +{

        # Requests ...
        *eServiceClientRequest => sub ($this, $service, $action, $args) {
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
                    },
                    sub ($error)  {
                        $log->error( $this, $error );

                        fail('... got an unexpected error: '.$error);
                    },
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

    my $service = $this->spawn( Service()       );
    my $client  = $this->spawn( ServiceClient() );

    isa_ok($service, 'ELO::Core::Process');
    isa_ok($client, 'ELO::Core::Process');

    $this->send( $client, [
        *eServiceClientRequest => (
            $service,
            *Sum, [
                [ *Add, [ 2, 2 ] ],
                [ *Add, [ 3, 3 ] ],
                [ *Add, [ 4, 4 ] ],
                [ *Add, [ 5, 5 ] ],
            ]
        )
    ]);

    $this->send( $client, [
        *eServiceClientRequest => (
            $service,
            *Sum, [
                [ *Add, [ 12, 12 ] ],
                [ *Add, [ 13, 13 ] ],
                [ *Add, [ 14, 14 ] ],
                [ *Add, [ 15, 15 ] ],
            ]
        )
    ]);

}

ELO::Loop->run( \&init, with_promises => 1, logger => $log  );

done_testing;

__END__

