package ELO::Promise;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Scalar::Util 'blessed';

our $LOOP;

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
    my $p = __PACKAGE__->new;
    push $self->{_resolved}->@* => $self->_wrap( $p, $then );
    push $self->{_rejected}->@* => $self->_wrap( $p, $catch // sub {} );
    $self->_notify unless $self->is_in_progress;
    $p;
}

sub resolve ($self, $result) {
    die "Cannot resolve. Already  " . $self->status
        unless $self->is_in_progress;

    #warn "RESOLVED $self";
    $self->{_status} = RESOLVED;
    $self->{result} = $result;
    $self->_notify;
    $self;
}

sub reject ($self, $error) {
    die "Cannot reject. Already  " . $self->status
        unless $self->is_in_progress;

    #warn "REJECTED $self";
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

    $self->{_resolved} = [];
    $self->{_rejected} = [];

    if ($LOOP) {
        $LOOP->next_tick(sub { $_->($value) foreach $cbs->@* });
    }
    else {
        $_->($value) foreach $cbs->@*;
    }
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
    my $collector = __PACKAGE__->new->resolve([]);

    foreach my $p ( @promises ) {
        my @results;
        $collector = $collector
            ->then(sub ($result) {
                #warn "hello from 1 for $p";
                #warn Dumper { p => "$p", state => 1, collector => [ @results ], result => $result };
                push @results => @$result;
                #warn Dumper { p => "$p", state => 1.5, collector => [ @results ] };
                $p;
            })
            ->then(sub ($result) {
                #warn "hello from 2 for $p";
                #warn Dumper { p => "$p", state => 2, collector => [ @results ], result => $result };
                my $r = [ @results, $result ];
                #warn Dumper { p => "$p", state => 2.5, collector => $r };
                return $r;
            })
    }

    return $collector;
}

1;

__END__

=pod

=cut
