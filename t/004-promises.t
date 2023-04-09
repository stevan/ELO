#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors   qw[ match ];
use ELO::Promises qw[ promise collect ];

use ELO::Util::Logger;

my $log = ELO::Util::Logger->new;

# Could we do this??
# sub Service ($this, $msg) : Promise( eServiceResponse, eServiceError ) {

sub Service ($this, $msg) {

    $log->debug( $this, [ $msg->@[ 0 .. $#{$msg}-1 ], "".$msg->[-1] ] );

    # NOTE:
    # this is basically a stateless service,
    # and uses Promises instead of the callback
    # format used in other tests.

    match $msg, +{
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

sub ServiceClient ($this, $msg) {

    $log->debug( $this, $msg );

    match $msg, +{

        # Requests ...
        eServiceClientRequest => sub ($service, $action, $args) {
            $log->debug( $this, "HELLO FROM ServiceClient :: eServiceClientRequest" );
            $log->debug( $this, +{ service => $service, action => $action, args => $args });

            my @promises;
            foreach my $op ( @$args ) {
                my $p = promise;
                $this->send( $service, [ eServiceRequest => ( @$op, $p ) ]);
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
                    sub ($result) { $log->info( $this, $result ) },
                    sub ($error)  { $log->error( $this, $error ) },
                );
        },
    }
}

sub init ($this, $msg=[]) {
    my $service = $this->spawn( Service  => \&Service       );
    my $client  = $this->spawn( Client   => \&ServiceClient );

    $this->send( $client, [
        eServiceClientRequest => (
            $service->pid,
            sum => [
                [ add => [ 2, 2 ] ],
                [ add => [ 3, 3 ] ],
                [ add => [ 4, 4 ] ],
                [ add => [ 5, 5 ] ],
            ]
        )
    ]);

    $this->send( $client, [
        eServiceClientRequest => (
            $service->pid,
            sum => [
                [ add => [ 12, 12 ] ],
                [ add => [ 13, 13 ] ],
                [ add => [ 14, 14 ] ],
                [ add => [ 15, 15 ] ],
            ]
        )
    ]);

}

ELO::Loop->run( \&init, with_promises => 1  );

__END__

