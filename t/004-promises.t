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
        $self->_notify unless $self->is_in_progress;
        $p;
    }

    sub resolve ($self, $result) {
        #warn "RESOLVED! $self";
        $self->{_status} = RESOLVED;
        $self->{result} = $result;
        $self->_notify;
        $self;
    }

    sub reject ($self, $error) {
        #warn "REJECTED! $self";
        $self->{_status} = REJECTED;
        $self->{error}  = $error;
        $self->_notify;
        $self;
    }

    sub _notify ($self) {

        my ($value, $cbs);

        if ($self->is_resolved) {
            $value = $self->{result};
            $cbs   = $self->{_resolved};
        }
        elsif ($self->is_rejected) {
            $value = $self->{error};
            $cbs   = $self->{_rejected};
        }
        else {
            die "Bad Notify State";
        }

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

    # ...

    sub collect (@promises) {
        my $collector = Promise->new->resolve([]);

        foreach my $p ( @promises ) {
            my @results;
            $collector = $collector
                ->then(sub ($result) {
                    #warn Dumper { p => "$p", state => 1, collector => [ @results ], result => $result };
                    push @results => @$result;
                    #warn Dumper { p => "$p", state => 1.5, collector => [ @results ] };
                    $p;
                })
                ->then(sub ($result) {
                    #warn Dumper { p => "$p", state => 2, collector => [ @results ], result => $result };
                    my $r = [ @results, $result ];
                    #warn Dumper { p => "$p", state => 2.5, collector => $r };
                    return $r;
                })
        }

        return $collector;
    }
}

sub Service ($this, $msg) {

    warn Dumper +{ ServiceGotMessage => 1, $this->pid => $msg } if DEBUG;

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

    warn Dumper +{ ServiceClientGotMessage => 1, $this->pid => $msg } if DEBUG;

    match $msg, state $handlers = +{

        # Requests ...
        eServiceClientRequest => sub ($service, $action, $args) {
            warn "HELLO FROM ServiceClient :: eServiceClientRequest" if DEBUG;
            warn Dumper { service => $service->pid, action => $action, args => $args } if DEBUG;

            my @promises;
            foreach my $op ( @$args ) {
                my $p = Promise->new;
                $this->send( $service, [ eServiceRequest => ( @$op, $p ) ]);
                push @promises => $p;
            }

            Promise::collect( @promises )
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
            $service, # add => [ 2, 2 ]
            sum => [
                [ add => [ 2, 2 ] ],
                [ add => [ 3, 3 ] ],
                [ add => [ 4, 4 ] ],
                [ add => [ 5, 5 ] ],
            ]
        )
    ]);

}

ELO::Loop->new->run( \&init );


__END__

