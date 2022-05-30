package EventLoop::Process;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Carp         'confess';
use Scalar::Util 'blessed';
use List::Util   ();

use constant IDLE  => 1;
use constant DONE  => 4;

use parent 'UNIVERSAL::Object';
use slots (
    pid      => sub {},
    callback => sub {},
    # private
    _state   => sub { IDLE },
    _error   => sub {},
    _timer   => sub { 0 },
    _alarm   => sub {},
);

sub pid ($self) { $self->{pid} }

sub assign_pid ($self, $pid) { $self->{pid} = $pid }

# ...

sub set_idle  ($self) { $self->{_state} = IDLE  }
sub set_done  ($self) { $self->{_state} = DONE  }

sub is_idle  ($self) { $self->{_state} == IDLE  }
sub is_done  ($self) { $self->{_state} == DONE  }

# ...

sub sleep_for ($self, $ticks=0, $callback=undef) {
    $self->{_timer} = $ticks;
    $self->{_alarm} = $callback;
}

sub is_asleep ($self) { $self->{_timer} != 0 }

# ...

sub has_error ($self) { !! $self->{_error} }
sub get_error ($self) {    $self->{_error} }

sub set_error ($self, $error) {
    $self->{_error} = $error;
}

sub exit ($self) { $self->set_done }

sub call ($self, $loop, $env, $msg) {
    if ( $self->is_asleep ) {
        $self->{_timer}--;
        return;
    }
    else {
        if ( $self->{_alarm} ) {
            $self->{_alarm}->();
            $self->{_alarm} = undef;
            return;
        }
    }

    $self->{callback}->( $self, $loop, $env, $msg );
}

1;

__END__

=pod

=cut
