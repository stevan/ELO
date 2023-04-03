package ELO::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Scalar::Util 'blessed';

use ELO::Process;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    # ...
    _proc_table => sub { +{} },
    _msg_queue  => sub { +[] },
);

sub create_process ($self, $name, $f, $parent=undef) {
    my $proc = ELO::Process->new(
        name   => $name,
        func   => $f,
        loop   => $self,
        parent => $parent,
    );
    $self->{_proc_table}->{ $proc->pid } = $proc;
    return $proc;
}

sub enqueue_msg ($self, $msg) {
    push $self->{_msg_queue}->@* => $msg;
}

sub tick ($self) {

    my @inbox = $self->{_msg_queue}->@*;
    $self->{_msg_queue}->@* = ();

    while (@inbox) {
        my $msg = shift @inbox;
        my ($to_proc, @body) = @$msg;

        # if we have a PID, then look it up
        if (not blessed $to_proc) {
            die "Unable to find process for PID($to_proc)"
                unless exists $self->{_proc_table}->{ $to_proc };
            $to_proc = $self->{_proc_table}->{ $to_proc };
        }

        eval {
            $to_proc->call( @body );
            1;
        } or do {
            my $e = $@;
            die "Message to (".$to_proc->pid.") failed with msg(".(join ", " => map { ref ? @$_ : $_ } @body).") because: $e";
        };
    }
}

sub loop ($self) {
    my $tick = 0;

    warn sprintf "-- tick(%03d) : starting\n" => $tick;

    while ( $self->{_msg_queue}->@* ) {
        warn sprintf "-- tick(%03d)\n" => $tick;
        $self->tick;
        $tick++
    }

    warn sprintf "-- tick(%03d) : exiting\n" => $tick;
}

sub run ($self, $f, @args) {
    my $main = $self->create_process( main => $f );
    $self->enqueue_msg([ $main, @args ]);
    $self->loop;
}


1;

__END__

=pod

=cut

