#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors   qw[ match ];
use ELO::Promises qw[ promise collect ];

use constant DEBUG => $ENV{DEBUG} || 0;

# Could we do this??
# sub Service ($this, $msg) : Promise( eServiceResponse, eServiceError ) {

sub Service ($this, $msg) {

    warn Dumper +{ ServiceGotMessage => 1, $this->pid => $msg } if DEBUG > 2;

    # NOTE:
    # this is basically a stateless service,
    # and uses Promises instead of the callback
    # format used in other tests.

    match $msg, +{
        # $request  = eServiceRequest  [ action : Str, args : [Int, Int], caller : PID ]
        # $response = eServiceResponse [ Int ]
        # $error    = eServiceError    [ error : Str ]
        eServiceRequest => sub ($action, $args, $promise) {
            warn "HELLO FROM Service :: eServiceRequest" if DEBUG;
            warn Dumper { action => $action, args => $args, promise => "$promise" } if DEBUG;

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

    warn Dumper +{ ServiceClientGotMessage => 1, $this->pid => $msg } if DEBUG > 2;

    match $msg, +{

        # Requests ...
        eServiceClientRequest => sub ($service, $action, $args) {
            warn "HELLO FROM ServiceClient :: eServiceClientRequest" if DEBUG;
            warn Dumper { service => $service->pid, action => $action, args => $args } if DEBUG;

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
                    sub ($result) { warn Dumper { result => $result } },
                    sub ($error)  { warn Dumper { error  => $error } },
                );
        },
    }
}

sub init ($this, $msg=[]) {
    my $service = $this->spawn( Service  => \&Service       );
    my $client  = $this->spawn( Client   => \&ServiceClient );

    $this->send( $client, [
        eServiceClientRequest => (
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
        eServiceClientRequest => (
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

ELO::Loop->run( \&init, with_promises => 1  );

__END__

