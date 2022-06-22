package ELO::Core::ProcessRecord;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use constant READY   => 1; # can accept arguments
use constant EXITING => 2; # waiting to exit at the end of the loop
use constant DONE    => 3; # the end

sub new ($class, $pid, $start_env, $actor) {
    bless [
        $pid,
        READY,
        +{ %$start_env },
        $actor
    ] => $class;
}

sub pid    ($self) { $self->[0] }
sub status ($self) { $self->[1] }
sub env    ($self) { $self->[2] }
sub actor  ($self) { $self->[3] }

sub is_ready   ($self) { $self->[1] == READY   }
sub is_exiting ($self) { $self->[1] == EXITING }
sub is_done    ($self) { $self->[1] == DONE    }

sub set_to_exiting ($self) { $self->[1] = EXITING }
sub set_to_done    ($self) { $self->[1] = DONE    }

1;

__END__
