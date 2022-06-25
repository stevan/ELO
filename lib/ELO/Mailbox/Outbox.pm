package ELO::Mailbox::Outbox;
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use parent 'UNIVERSAL::Object';
use slots (
    handle => sub {}, # IO::Handle
    serde  => sub {}, # ...
);

sub send ($self, $msg) {
    my $packet = $self->{serde}->{encode}->( $msg );
    $self->{handle}->print( $packet, "\n" );
}

sub close ($self) {
    $self->{handle}->close;
}

1;
