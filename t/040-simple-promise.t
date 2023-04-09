#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors   qw[ match ];
use ELO::Promises qw[ promise ];

use ELO::Util::Logger;

my $log = ELO::Util::Logger->new;

sub Service ($this, $msg) {

    $log->debug( $this, [ $msg->@[ 0 .. $#{$msg}-1 ], "".$msg->[-1] ] );

    match $msg, state $handlers = +{
        # $request  = eServiceRequest  [ action : Str, args : [Int, Int], caller : PID ]
        # $response = eServiceResponse [ Int ]
        # $error    = eServiceError    [ error : Str ]
        eServiceRequest => sub ($action, $args, $promise) {
            $log->debug( $this, "HELLO FROM Service :: eServiceRequest" );
            $log->debug( $this, +{ action => $action, args => $args, promise => "$promise" });

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

ELO::Loop->run( \&init, with_promises => 1 );


__END__

