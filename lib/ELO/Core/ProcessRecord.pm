package ELO::Core::ProcessRecord;
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

sub new ($class, $pid, $status, $start_env, $actor) {
    bless [
        $pid,
        $status,
        [],
        +{ %$start_env },
        $actor
    ] => $class;
}

sub pid    ($self) { $self->[0] }
sub status ($self) { $self->[1] }
sub inbox  ($self) { $self->[2] }
sub env    ($self) { $self->[3] }
sub actor  ($self) { $self->[4] }

sub set_status ($self, $status) {
    $self->[1] = $status;
}

1;

__END__
