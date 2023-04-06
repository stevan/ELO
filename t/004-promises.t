#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors qw[ match ];
use ELO::Promise;

use constant DEBUG => $ENV{DEBUG} // 0;

sub Service ($this, $msg) {

    warn Dumper +{ ServiceGotMessage => 1, $this->pid => $msg } if DEBUG > 2;

    match $msg, state $handlers = +{
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

    match $msg, state $handlers = +{

        # Requests ...
        eServiceClientRequest => sub ($service, $action, $args) {
            warn "HELLO FROM ServiceClient :: eServiceClientRequest" if DEBUG;
            warn Dumper { service => $service->pid, action => $action, args => $args } if DEBUG;

            my @promises;
            foreach my $op ( @$args ) {
                my $p = ELO::Promise->new;
                $this->send( $service, [ eServiceRequest => ( @$op, $p ) ]);
                push @promises => $p;
            }

            ELO::Promise::collect( @promises )
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

}

($ELO::Promise::LOOP = ELO::Loop->new)->run( \&init );


__END__

