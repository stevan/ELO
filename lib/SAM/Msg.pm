package SAM::Msg;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';

use constant DEBUG => $ENV{DEBUG} // 0;

use Exporter 'import';

our @EXPORT = qw[
    msg

    recv_from
    return_to
];

## ----------------------------------------------------------------------------
## Message Queue
## ----------------------------------------------------------------------------

my @msg_outbox;

sub _message_outbox () { @msg_outbox }

sub recv_from () {
    my $process = SAM::_lookup_process( $SAM::CURRENT_PID );
    my $msg = shift $process->[1]->@*;
    return unless $msg;
    return $msg->[1];
}

sub return_to ($msg) {
    push @msg_outbox => [ $SAM::CURRENT_PID, $SAM::CURRENT_CALLER, $msg ];
}

sub _accept_all_messages () {
    warn Dumper \@msg_outbox if DEBUG >= 4;

    # accept all the messages in the queue
    while (@msg_outbox) {
        my $next = shift @msg_outbox;

        my $from = shift $next->@*;
        my ($to, $m) = $next->@*;
        my $process = SAM::_lookup_process( $to );
        if ( !$process ) {
            warn "Got message for unknown pid($to)";
            next;
        }
        push $process->[1]->@* => [ $from, $m ];
    }
}

sub _remove_all_outbox_messages_for_pid ($pid) {
    @msg_outbox = grep { $_->[1] ne $pid } @msg_outbox;
}

my @msg_inbox;

sub _message_inbox () { @msg_inbox }

sub _has_inbox_messages () { scalar @msg_inbox == 0 }

sub _send_to ($msg) {
    push @msg_inbox => [ $SAM::CURRENT_PID, $msg ];
}

sub _send_from ($from, $msg) {
    push @msg_inbox => [ $from, $msg ];
}

sub _deliver_all_messages () {
    warn Dumper \@msg_inbox  if DEBUG >= 4;

    # deliver all the messages in the queue
    while (@msg_inbox) {
        my $next = shift @msg_inbox;
        #warn Dumper $next;
        my ($from, $msg) = $next->@*;
        my $process = SAM::_lookup_process( $msg->pid );
        if ( !$process ) {
            warn "Got message for unknown pid(".$msg->pid.")";
            next;
        }
        push $process->[0]->@* => [ $from, $msg ];
    }
}

sub _remove_all_inbox_messages_for_pid ($pid) {
    @msg_inbox  = grep { $_->[1]->pid ne $pid } @msg_inbox;
}

# ....

sub msg        ($pid, $action, $msg) { bless [$pid, $action, $msg] => 'SAM::Msg' }
sub msg::curry ($pid, $action, $msg) { bless [$pid, $action, $msg] => 'SAM::Msg::Curryable' }

package SAM::Msg {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    sub pid    ($self) { $self->[0] }
    sub action ($self) { $self->[1] }
    sub body   ($self) { $self->[2] }

    sub curry ($self, @args) {
        msg::curry(@$self)->curry( @args )
    }

    sub send ($self) { SAM::Msg::_send_to( $self ); $self }
    sub send_from ($self, $caller) { SAM::Msg::_send_from($caller, $self); $self }

    sub return_or_send ($self, $wantarray) {
        if (not defined $wantarray) {
            # foo(); -- will send message, return nothing
            $self->send;
            return;
        }
        elsif (not $wantarray) {
            # my $foo_pid = foo(); -- will send message, return msg pid
            $self->send;
            return $self->pid
        }
        else {
            # sync(foo(), bar()); -- will just return message
            return $self;
        }
    }
}

package SAM::Msg::Curryable {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    our @ISA; BEGIN { @ISA = ('SAM::Msg') };

    sub curry ($self, @args) {
        my ($pid, $action, $body) = @$self;
        bless [ $pid, $action, [ @$body, @args ] ] => 'SAM::Msg::Curryable';
    }
}

1;

__END__

=pod

=cut
