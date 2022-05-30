package EventLoop;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Carp         'confess';
use Scalar::Util 'blessed';
use List::Util   ();

my $PIDS = 1;

use parent 'UNIVERSAL::Object';
use slots (
    _proc_tbl   => sub { +{} },
    _msg_queues => sub { +{} },
    _ticks      => sub { 0 },
);

sub add_process ($self, $process) {
    $process->assign_pid( ++$PIDS );
    $self->{_proc_tbl}->{ $process->pid } = $process;
}

sub get_process_list ($self) {
    sort { $a->pid <=> $b->pid } values $self->{_proc_tbl}->%*;
}

sub get_process_table ($self) {
    $self->{_proc_tbl}->%*;
}

sub enqueue_message_for ($self, $pid, $msg) {
    push $self->{_msg_queues}->{ $pid }->@* => $msg;
}

sub dequeue_message_for ($self, $proc) {
    shift $self->{_msg_queues}->{ $proc->pid }->@*;
}

sub handle_error ($self, $proc, $error) {
    die join '' => $proc->pid, $error;
}

sub num_ticks ($self) {   $self->{_ticks} }
sub next_tick ($self) { ++$self->{_ticks} }

sub run ($self) {

    my $env = {};

    my @procs = $self->get_process_list;

    while (@procs) {
        $self->next_tick;
        #warn "tick(".$self->num_ticks.")";

        @procs = grep {
            my $msg = $self->dequeue_message_for( $_ );

            eval {
                $_->call( $self, $env, $msg );
                1;
            } or do {
                my $error = $@;
                $self->handle_error( $_, $error );
                $_->is_done;
            };

            !$_->is_done;
        } @procs;
    }

    return $env;

}

1;

__END__

=pod

=cut
