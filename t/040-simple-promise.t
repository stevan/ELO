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
use ok 'ELO::Promises', qw[ promise ];

my $log = Test::ELO->create_logger;

sub Service ($this, $msg) {

    $log->debug( $this, $msg );

    match $msg, state $handlers = +{
        # $request  = eServiceRequest  [ action : Str, args : [Int, Int], caller : PID ]
        # $response = eServiceResponse [ Int ]
        # $error    = eServiceError    [ error : Str ]
        eServiceRequest => sub ($action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => $promise });

            my ($x, $y) = @$args;

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
    }
}

sub init ($this, $msg=[]) {
    my $service = $this->spawn( Service  => \&Service );

    my $promise = promise;

    $this->send( $service,
        [ eServiceRequest => ( add => [ 2, 2 ], $promise ) ]
    );

    $promise->then(
        sub ($event) { $log->info( $this, $event ) },
        sub ($error) { $log->error( $this, $error ) }
    );
}

ELO::Loop->run( \&init, with_promises => 1, logger => $log );

done_testing;

__END__

