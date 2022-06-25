#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Term::ANSIColor ':constants';

#use Test::More;
use Data::Dumper;

package Mario::Pipe::Reader {
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
}

package Mario::Pipe::Writer {
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
}

package Mario::Pipe {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    use Carp 'confess';

    use IO::Pipe;
    use JSON;

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

            Mario::Pipe::Reader->new(
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

            Mario::Pipe::Writer->new(
                handle => $out,
                serde  => $self->{serde}
            );
        };
    }

}

package Mario::Mailbox {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    use JSON;

    use parent 'UNIVERSAL::Object';
    use slots (
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

        my $pipe1 = Mario::Pipe->new( serde => $self->{serde} );
        my $pipe2 = Mario::Pipe->new( serde => $self->{serde} );

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
}

use ELO;

warn "INIT $$\n";

my $mbox = Mario::Mailbox->new;

actor 'bounce' => sub ($env, $msg) {

    my $me = $env->{parent} ? CYAN('parent') : YELLOW('child');
    $me .= RESET;

    match $msg, +{
        send => sub ($msg) {
            sys::out::print(PID." sending(".$msg->{count}.") in $$ $me");
            $mbox->outbox->send( $msg );
            msg(PID, recv => [])->send; # go back to listening ...
        },
        recv => sub ($backoff=0) {
            my $data = $mbox->inbox->recv;
            unless (defined $data) {
                if ($mbox->inbox->should_try_again) {
                    sys::err::log(PID." ########## in $$ $me with $backoff");
                    msg(PID, recv => [ ++$backoff ])->send;
                }
                else {
                    msg(PID, finish => [])->send;
                }
            }
            else {
                sys::out::print(PID." got(".$data->{count}.") in $$ $me");
                $data->{count}++;
                msg(PID, send => [ $data ])->send;
            }
        },
        finish => sub () {
            sys::out::print(PID." finishing in $$ $me");
            sig::kill(PID)->send;
            $mbox->outbox->close;
        }
    };
};

actor 'parent_main' => sub ($env, $msg) {
    sys::out::print("-> starting parent main $$");

    my $bounce = proc::spawn('bounce', parent => 1);

    msg($bounce, recv => [])->send;

    sig::timer( 100, msg($bounce, finish => []))->send;
};

actor 'child_main' => sub ($env, $msg) {
    sys::out::print("-> starting child main $$");

    my $bounce = proc::spawn('bounce', child => 1);

    msg($bounce, send => [ { count => 0 } ])->send;
    msg($bounce, recv => [])->send;
};

if(my $pid = fork()) {
    warn RED "Parent $$", RESET "\n";

    my $log = IO::File->new('>parent.log') or die "Could not open log because: $!";
    $ELO::IO::STDOUT = $log;
    $ELO::IO::STDERR = $log;

    loop(100_000, 'parent_main');

    exit;
}
elsif(defined $pid) {
    warn GREEN "Child $$", RESET "\n";

    my $log = IO::File->new('>child.log') or die "Could not open log because: $!";
    $ELO::IO::STDOUT = $log;
    $ELO::IO::STDERR = $log;

    loop(100_000, 'child_main');

    exit;
}


1;
