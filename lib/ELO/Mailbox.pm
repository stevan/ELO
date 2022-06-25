package ELO::Mailbox;
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use JSON;

use ELO::Mailbox::Pipe;

use parent 'UNIVERSAL::Object';
use slots (
    name  => sub {},
    serde => sub {}, # { encode => sub {}, decode => sub {} }
    # private
    _start_pid => sub { $$ },
    _pipes     => sub {},
);

sub BUILD ($self, $) {
    $self->{serde} = +{
        encode => \&JSON::encode_json,
        decode => \&JSON::decode_json,
    } unless $self->{serde};

    my $pipe1 = ELO::Mailbox::Pipe->new( serde => $self->{serde} );
    my $pipe2 = ELO::Mailbox::Pipe->new( serde => $self->{serde} );

    $self->{_pipes} = [ $pipe1, $pipe2 ];
}

sub inbox  ($self) { ($self->mailboxes)[0] }
sub outbox ($self) { ($self->mailboxes)[1] }

sub mailboxes ($self) {
    if ($$ == $self->{_start_pid}) {
        return (
            $self->{_pipes}->[0]->reader,
            $self->{_pipes}->[1]->writer
        );
    }
    else {
        return (
            $self->{_pipes}->[1]->reader,
            $self->{_pipes}->[0]->writer
        );
    }
}

1;
