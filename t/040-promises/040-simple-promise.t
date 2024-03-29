#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',    qw[ :core event ];
use ok 'ELO::Actors',   qw[ receive ];
use ok 'ELO::Promises', qw[ promise ];

my $log = Test::ELO->create_logger;

event *eServiceRequest   => ( *Str, [ *Int, *Int ], *Promise ); # action : Str, args : [Int, Int], promise
event *eServiceResponse  => ( *Int );                           # Int
event *eServiceError     => ( *Str );                           # error : Str

sub Service () {

    receive +{
        *eServiceRequest => sub ($this, $action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => $promise });

            isa_ok($promise, 'ELO::Core::Promise');

            my ($x, $y) = @$args;

            try {
                $promise->resolve([
                    *eServiceResponse => (
                        ($action eq 'add') ? ($x + $y) :
                        ($action eq 'sub') ? ($x - $y) :
                        ($action eq 'mul') ? ($x * $y) :
                        ($action eq 'div') ? ($x / $y) :
                        die "Invalid Action: $action"
                    )
                ]);
            } catch ($e) {
                chomp $e;
                $promise->reject([ *eServiceError => ( $e ) ]);
            }
        }
    }
}

sub init ($this, $msg=[]) {

    my $service = $this->spawn( Service() );
    isa_ok($service, 'ELO::Core::Process');

    my $promise = promise;
    isa_ok($promise, 'ELO::Core::Promise');

    $this->send( $service,
        [ *eServiceRequest => ( add => [ 2, 2 ], $promise ) ]
    );

    $promise->then(
        sub ($result) {
            $log->info( $this, $result );

            is($result->[1], 4, '... got the expected result');
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

