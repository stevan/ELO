package ELO::Core::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Scalar::Util 'blessed';

use ELO::Core::Process;

use constant SIGEXIT => 'SIGEXIT';
use constant SIGTERM => 'SIGTERM';

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    # ...
    _process_table  => sub { +{} },
    _process_links  => sub { +{} },
    _message_queue  => sub { +[] },
    _callback_queue => sub { +[] },
);

sub create_process ($self, $name, $f, $env=undef, $parent=undef) {
    my $process = ELO::Core::Process->new(
        name   => $name,
        func   => $f,
        loop   => $self,
        parent => $parent,
        env    => $env,
    );
    $self->{_process_table}->{ $process->pid } = $process;
    return $process;
}

sub destroy_process ($self, $process, $status) {
    # NOTE: ignore if the PID does not exist (for now)
    delete $self->{_process_table}->{ $process->pid };

    if ( my $links = $self->{_process_links}->{ $process->pid } ) {
        foreach my $link (@$links) {
            $link->send_to_self([ SIGEXIT, $process, $status ]);
        }
    }

    return;
}

sub link_process ($self, $to_process, $from_process) {
    my $links = $self->{_process_links}->{ $from_process->pid } //= [];
    push @$links => $to_process;
    return;
}

sub unlink_process ($self, $to_process, $from_process) {
    #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid });
    if ( my $links = $self->{_process_links}->{ $from_process->pid } ) {
        #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid, links => [ map { $_->pid } @$links ] });
        @$links = grep { $_->pid ne $to_process->pid } @$links;
        #use Data::Dump; Data::Dump::dump( { unlink => $to_process->pid, from => $from_process->pid, links => [ map { $_->pid } @$links ] });
    }
    return;
}

sub enqueue_msg ($self, $msg) {
    push $self->{_message_queue}->@* => $msg;
    return;
}

sub next_tick ($self, $f) {
    push $self->{_callback_queue}->@* => $f;
    return;
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
            die "Message to (".$to_proc->pid.") failed with msg(".(join ', ' => @{ $event // []}).") because: $e";
        };
    }

    return;
}

sub loop ($self, $logger=undef) {
    my $tick = 0;

    $logger->tick( $logger->DEBUG, $self, $tick, 'INIT' )  if $logger;
    $logger->tick( $logger->INFO,  $self, $tick, 'START' ) if $logger;

    while ( $self->{_message_queue}->@* || $self->{_callback_queue}->@* ) {
        $logger->tick( $logger->INFO, $self, $tick ) if $logger;
        $self->tick;
        $tick++
    }

    $logger->tick( $logger->INFO,  $self, $tick, 'END'  ) if $logger;
    $logger->tick( $logger->DEBUG, $self, $tick, 'EXIT' ) if $logger;

    return;
}

sub run ($self, $f, $args=[], $logger=undef, $env=undef) {
    my $main = $self->create_process( main => $f, $env );
    $self->enqueue_msg([ $main, $args ]);
    $self->loop( $logger );
    return;
}

1;

__END__

=pod

=cut

