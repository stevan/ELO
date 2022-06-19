package ELO::Msg;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';

use Exporter 'import';

our @EXPORT = qw[
    msg
];

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

    sub send ($self) { ELO::enqueue_msg( $self ); $self }
    sub send_from ($self, $caller) { ELO::enqueue_msg_from($caller, $self); $self }

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
