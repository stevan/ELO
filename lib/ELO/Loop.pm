package ELO::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Scalar::Util 'blessed';

use ELO::Process;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    # ...
    _process_table  => sub { +{} },
    _message_queue  => sub { +[] },
    _callback_queue => sub { +[] },
);

sub create_process ($self, $name, $f, $parent=undef) {
    my $proc = ELO::Process->new(
        name   => $name,
        func   => $f,
        loop   => $self,
        parent => $parent,
    );
    $self->{_process_table}->{ $proc->pid } = $proc;
    return $proc;
}

sub enqueue_msg ($self, $msg) {
    push $self->{_message_queue}->@* => $msg;
}

sub next_tick ($self, $f) {
    push $self->{_callback_queue}->@* => $f;
}

sub tick ($self) {

    my @cb_queue = $self->{_callback_queue}->@*;
    $self->{_callback_queue}->@* = ();

    while (@cb_queue) {
        my $f = shift @cb_queue;
        eval {
            $f->(); 1;
        } or do {
            my $e = $@;
            die "Callback failed ($f) because: $e";
        };
    }

    my @msg_queue = $self->{_message_queue}->@*;
    $self->{_message_queue}->@* = ();

    while (@msg_queue) {
        my $msg = shift @msg_queue;
        my ($to_proc, $event) = @$msg;

        # if we have a PID, then look it up
        if (not blessed $to_proc) {
            die "Unable to find process for PID($to_proc)"
                unless exists $self->{_process_table}->{ $to_proc };
            $to_proc = $self->{_process_table}->{ $to_proc };
        }

        #use Data::Dumper;
        #warn Dumper { MessageToBeDelivered => 1, event => $event, proc => $to_proc->pid };

        eval {
            $to_proc->accept( $event );
            $to_proc->tick;
            1;
        } or do {
            my $e = $@;
            die "Message to (".$to_proc->pid.") failed with msg(".(join ', ' => @$event).") because: $e";
        };
    }
}

sub loop ($self) {
    my $tick = 0;

    warn sprintf "-- tick(%03d) : starting\n" => $tick;

    while ( $self->{_message_queue}->@* || $self->{_callback_queue}->@* ) {
        warn sprintf "-- tick(%03d)\n" => $tick;
        $self->tick;
        $tick++
    }

    warn sprintf "-- tick(%03d) : exiting\n" => $tick;
}

sub run ($self, $f, $args=[]) {
    my $main = $self->create_process( main => $f );
    $self->enqueue_msg([ $main, $args ]);
    $self->loop;
}


1;

__END__

=pod

=cut

