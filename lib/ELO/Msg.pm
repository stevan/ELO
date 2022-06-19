package ELO::Msg;

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

my @MSG_OUTBOX;

sub _message_outbox () { @MSG_OUTBOX }

sub recv_from () {
    my $process = proc::lookup( $ELO::CURRENT_PID );
    my $msg = shift $process->outbox->@*;
    return unless $msg;
    return $msg->[1];
}

sub return_to ($msg) {
    push @MSG_OUTBOX => [ $ELO::CURRENT_PID, $ELO::CURRENT_CALLER, $msg ];
}

sub _accept_all_messages () {
    warn Dumper \@MSG_OUTBOX if DEBUG >= 4;

    # accept all the messages in the queue
    while (@MSG_OUTBOX) {
        my $next = shift @MSG_OUTBOX;

        my $from = shift $next->@*;
        my ($to, $m) = $next->@*;
        my $process = proc::lookup( $to );
        if ( !$process ) {
            warn "Got message for unknown pid($to)";
            next;
        }
        push $process->outbox->@* => [ $from, $m ];
    }
}

sub _remove_all_outbox_messages_for_pid ($pid) {
    @MSG_OUTBOX = grep { $_->[1] ne $pid } @MSG_OUTBOX;
}

my @MSG_INBOX;

sub _message_inbox () { @MSG_INBOX }

sub _has_inbox_messages () { scalar @MSG_INBOX == 0 }

sub _send_to ($msg) {
    push @MSG_INBOX => [ $ELO::CURRENT_PID, $msg ];
}

sub _send_from ($from, $msg) {
    push @MSG_INBOX => [ $from, $msg ];
}

sub _deliver_all_messages () {
    warn Dumper \@MSG_INBOX  if DEBUG >= 4;

    # deliver all the messages in the queue
    while (@MSG_INBOX) {
        my $next = shift @MSG_INBOX;
        #warn Dumper $next;
        my ($from, $msg) = $next->@*;
        my $process = proc::lookup( $msg->pid );
        if ( !$process ) {
            warn "Got message for unknown pid(".$msg->pid.")";
            next;
        }
        push $process->inbox->@* => [ $from, $msg ];
    }
}

sub _remove_all_inbox_messages_for_pid ($pid) {
    @MSG_INBOX = grep { $_->[1]->pid ne $pid } @MSG_INBOX;
}

# ....

sub msg        ($pid, $action, $msg) { bless [$pid, $action, $msg] => 'ELO::Msg::Message' }
sub msg::curry ($pid, $action, $msg) { bless [$pid, $action, $msg] => 'ELO::Msg::CurriedMessage' }

package ELO::Msg::Message {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    use Scalar::Util ();

    sub pid    ($self) { $self->[0] }
    sub action ($self) { $self->[1] }
    sub body   ($self) { $self->[2] }

    sub curry ($self, @args) {
        msg::curry(@$self)->curry( @args )
    }

    sub send ($self) { ELO::Msg::_send_to( $self ); $self }
    sub send_from ($self, $caller) { ELO::Msg::_send_from($caller, $self); $self }

    sub to_string ($self) {
        join '' =>
            $self->pid, ' -> ',
                $self->action, ' [ ',
                    (join ', ' => map {
                        Scalar::Util::blessed($_)
                            ? ('('.$_->to_string.')')
                            : (ref $_
                                ? (ref $_ eq 'ARRAY'
                                    ? ('['.(join ', ' => map { Scalar::Util::blessed($_) ? $_->to_string : $_ } @$_).']')
                                    : ('{',(join ', ' => %$_),'}')) # XXX - do better
                                : $_)
                    } $self->body->@*),
                ' ]';
    }
}

package ELO::Msg::CurriedMessage {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    our @ISA; BEGIN { @ISA = ('ELO::Msg::Message') };

    sub curry ($self, @args) {
        my ($pid, $action, $body) = @$self;
        bless [ $pid, $action, [ @$body, @args ] ] => 'ELO::Msg::CurriedMessage';
    }
}

1;

__END__

=pod

=cut