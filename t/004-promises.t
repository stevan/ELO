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

    use Scalar::Util 'blessed';

    use constant IN_PROGRESS => 'in progress';
    use constant RESOLVED    => 'resolved';
    use constant REJECTED    => 'rejected';

    use parent 'UNIVERSAL::Object';
    use slots (
        result => sub {},
        error  => sub {},
        # ...
        _status   => sub { IN_PROGRESS },
        _resolved => sub { +[] },
        _rejected => sub { +[] },
    );

    sub is_in_progress ($self) { $self->{_status} eq IN_PROGRESS }
    sub is_resolved    ($self) { $self->{_status} eq RESOLVED }
    sub is_rejected    ($self) { $self->{_status} eq REJECTED }

    sub then ($self, $then, $catch=undef) {
        my $p = Promise->new;
        push $self->{_resolved}->@* => $self->_wrap( $p, $then );
        push $self->{_rejected}->@* => $self->_wrap( $p, $catch // sub {} );
        $p;
    }

    sub resolve ($self, $result) {
        $self->{_status} = RESOLVED;
        $self->{result} = $result;
        $self->_notify( $result, $self->{_resolved} );
        $self;
    }

    sub reject ($self, $error) {
        $self->{_status} = REJECTED;
        $self->{error}  = $error;
        $self->_notify( $error, $self->{_rejected} );
        $self;
    }

    sub _notify ($self, $value, $cbs) {
        # NOTE: should be happening in next_tick()
        $_->($value) foreach $cbs->@*;
    }

    sub _wrap ($self, $p, $then) {
        return sub ($value) {
            my ($result, $error);
            eval {
                $result = $then->( $value );
                1;
            } or do {
                my $e = $@;
                chomp $e;
                $error = $e;
            };

            if ($error) {
                $p->reject( $error );
            }
            if ( blessed $result && $result->isa(__PACKAGE__) ) {
                $result->then(
                    sub { $p->resolve(@_); () },
                    sub { $p->reject(@_);  () },
                );
            }
            else {
                $p->resolve( $result );
            }
            return;
        };
    }
}

sub Service ($this, $msg) {

    warn Dumper +{ ServiceGotMessage => 1, $this->pid => $msg } if DEBUG;

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

    warn Dumper +{ ServiceClientGotMessage => 1, $this->pid => $msg } if DEBUG;

    match $msg, state $handlers = +{

        # Requests ...
        eServiceClientRequest => sub ($service, $action, $args) {

            my $p = Promise->new;
            $this->send( $service, [ eServiceRequest => ( $action, $args, $p ) ]);
            $p->then(
                sub ($result) {
                    my ($etype, $value) = @$result;

                    warn Dumper { result1 => $result };

                    my $p = Promise->new;
                    $this->send( $service, [ eServiceRequest => ( $action, [ $value, $value ], $p ) ]);
                    $p;
                },
                sub ($error) { warn Dumper { error1 => $error } }
            )->then(
                sub ($result) { warn Dumper { result2 => $result } },
                sub ($error) { warn Dumper { error2 => $error } }
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
            #sum => [
            #    [ add => [ 2, 2 ] ],
            #    [ add => [ 3, 3 ] ],
            #]
        )
    ]);

}

ELO::Loop->new->run( \&init );


__END__

