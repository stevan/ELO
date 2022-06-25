package ELO::Mailbox::Pipe;
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Carp 'confess';

use IO::Pipe;

use ELO::Mailbox::Inbox;
use ELO::Mailbox::Outbox;

use parent 'UNIVERSAL::Object';
use slots (
    serde => sub {}, # { encode => sub {}, decode => sub {} }
    # private
    _handles => sub {},
    _reader  => sub {},
    _writer  => sub {},
);

sub BUILD ($self, $) {
    confess("You must supply `serde` option")
        unless $self->{serde};

    my ($in, $out) = (
        IO::Handle->new,
        IO::Handle->new,
    );

    $in->autoflush(1);
    $out->autoflush(1);

    pipe( $in, $out )
        or die "Could not create pipe beacuse: $!";

    $self->{_handles} = [ $in, $out ];
}

sub reader ($self) {
    $self->{_reader} //= do {
        my ($in, $out) = $self->{_handles}->@*;

        #warn "$$ reader $in, $out \n";

        $out->close;

        $in->fdopen( $in->fileno, "r" )
            unless defined $in->fileno;

        $in->blocking(0);

        ELO::Mailbox::Inbox->new(
            handle => $in,
            serde  => $self->{serde}
        );
    };
}

sub writer ($self) {
    $self->{_writer} //= do {
        my ($in, $out) = $self->{_handles}->@*;

        #warn "$$ writer $in, $out \n";

        $in->close;

        $out->fdopen( $out->fileno, "w" )
            unless defined $out->fileno;

        $out->blocking(0);

        ELO::Mailbox::Outbox->new(
            handle => $out,
            serde  => $self->{serde}
        );
    };
}


1;
