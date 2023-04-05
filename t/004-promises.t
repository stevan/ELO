#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors qw[ match ];

use constant DEBUG => $ENV{DEBUG} // 0;

package Promise {
    use v5.24;
    use warnings;
    use experimental qw[ signatures lexical_subs postderef ];

    use parent 'UNIVERSAL::Object';
    use slots (
        value   => sub {},
        error   => sub {},
        then    => sub {},
        catch   => sub {},
    );

    sub then ($self, $then, $catch=undef) {
        $self->{then}  = $then;
        $self->{catch} = $catch // sub {};
        $self;
    }

    sub resolve ($self, $value) {
        $self->{value}   = $value;
        $self->{then}->($value);
    }

    sub reject ($self, $error) {
        $self->{error}   = $error;
        $self->{catch}->($error);
    }
}

sub Service ($this, $msg) {

    warn Dumper +{ $this->pid => $msg } if DEBUG;

    match $msg, state $handlers = +{
        # $request  = eServiceRequest  [ action : Str, args : [Int, Int], caller : PID ]
        # $response = eServiceResponse [ Int ]
        # $error    = eServiceError    [ error : Str ]
        eServiceRequest => sub ($action, $args, $promise) {
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

    warn Dumper +{ $this->pid => $msg } if DEBUG;

    match $msg, state $handlers = +{

        # Requests ...
        eServiceClientRequest => sub ($service, $action, $args) {

            my $promise1 = Promise->new;
            my $promise2 = Promise->new;

            $this->send( $service, [
                eServiceRequest => (
                    $action,
                    $args,
                    $promise1
                )
            ]);

            $promise1->then(
                sub ($msg) {
                    my ($etype, $response) = @$msg;
                    $this->send( $service, [
                        eServiceRequest => (
                            $action,
                            [ $response, $response ],
                            $promise2
                        )
                    ]);
                },
                sub ($error) { warn Dumper { request => 1, error => $error } }
            );

            $promise2->then(
                sub ($msg)   { warn Dumper { request => 2, response => $msg   } },
                sub ($error) { warn Dumper { request => 2, error    => $error } }
            );
        },
    }
}

sub init ($this, $msg=[]) {
    my $service = $this->spawn( Service  => \&Service       );
    my $client  = $this->spawn( Client   => \&ServiceClient );

    $this->send( $client, [
        eServiceClientRequest => (
            $service, add => [ 2, 2 ]
        )
    ]);

    $this->send( $client, [
        eServiceClientRequest => (
            $service, add => [ 5, 5 ]
        )
    ]);


}

ELO::Loop->new->run( \&init );


__END__

