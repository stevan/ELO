package ELO::Mailbox::Inbox;
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use POSIX qw(:errno_h);

use parent 'UNIVERSAL::Object';
use slots (
    handle => sub {}, # IO::Handle
    serde  => sub {}, # ...
    # private
    _try_again => sub { 0 }
);

sub recv ($self) {

    my $line = $self->{handle}->getline;

    # if we didn't get anything then ...
    unless (defined $line) {
        # see if the handle is blocked ...
        if ($! == EAGAIN) {
            # and let them know it
            # is safe to try again
            $self->{_try_again}++;
        }
        else {
            # otherwise, it is not safe
            # and reset this one ...
            $self->{_try_again} = 0;
        }

        # no matter what, we return
        # nothing, cause we got nothing
        return;
    }

    # if we got something, we also
    # need to reset this, cause we
    # are no longer blocked ..
    $self->{_try_again} = 0;

    # now process what we got accordingly ...
    chomp($line);

    # when it ends, return zero but true ...
    return 0E0 unless $line;

    # otherwise, decode 'em
    return $self->{serde}->{decode}->( $line );
}

sub should_try_again ($self) { $self->{_try_again} }

sub close ($self) {
    $self->{handle}->close;
}


1;

