package EventLoop;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';
use Term::ReadKey 'GetTerminalSize';

use EventLoop::Actors;
use EventLoop::IO;

use Exporter 'import';

our @EXPORT = qw[
    timeout

    send_to
    recv_from
    return_to

    spawn
    quit

    sync
    await
    ident

    loop

    SYS

    PID CALLER

    DEBUG
];

# flags

use constant INBOX  => 0;
use constant OUTBOX => 1;

use constant DEBUG => $ENV{DEBUG} // 0;

# stuff

## .. process info

our $INIT_PID = '000:<init>';

our $CURRENT_PID;
our $CURRENT_CALLER;

## .. i/o

our $IN;
our $OUT;
our $ERR;

## ...

my @msg_inbox;
my @msg_outbox;

my %processes;

## ... sugar

sub PID    () { $CURRENT_PID    }
sub CALLER () { $CURRENT_CALLER }

sub SYS () { $INIT_PID }

## ... message delivery

sub send_to ($pid, $action, $msg) {
    push @msg_inbox => [ $CURRENT_PID, $pid, [ $action, $msg ] ];
}

sub send_from ($from, $pid, $action, $msg) {
    push @msg_inbox => [ $from, $pid, [ $action, $msg ] ];
}

sub recv_from () {
    my $msg = shift $processes{$CURRENT_PID}->[OUTBOX]->@*;
    return unless $msg;
    return $msg->[1];
}

sub return_to ($msg) {
    push @msg_outbox => [ $CURRENT_PID, $CURRENT_CALLER, $msg ];
}

## ... process creation

my $PID = 0;
sub spawn ($name) {
    my $process = [ [], [], {}, EventLoop::Actors::get_actor($name) ];
    my $pid = sprintf '%03d:%s' => ++$PID, $name;
    $processes{ $pid } = $process;
    $pid;
}

my %to_be_despawned;
sub despawn ($pid) {
    $to_be_despawned{$pid}++;
}

sub despawn_all () {
    foreach my $pid (keys %to_be_despawned) {
        @msg_inbox  = grep { $_->[1] ne $pid } @msg_inbox;
        @msg_outbox = grep { $_->[1] ne $pid } @msg_outbox;

        delete $processes{ $pid };
    }

    %to_be_despawned = ();
}

## ... currency control

sub timeout ($ticks, $callback) {
    my $args = [ spawn( '!timeout' ), countdown => [ $ticks, $callback ] ];
    defined wantarray ? $args : send_to( @$args );
}

sub sync ($input, $output) {
    my $args = [ spawn( '!sync' ), send => [ $input, $output ] ];
    defined wantarray ? $args : send_to( @$args );
}

sub await ($input, $output) {
    my $args = [ spawn( '!await' ), send => [ $input, $output ] ];
    defined wantarray ? $args : send_to( @$args );
}

sub ident ($val=undef) {
    my $args = [ spawn( '!ident' ), id => [ $val // () ] ];
    defined wantarray ? $args : send_to( @$args );
}

## ...

sub loop ( $MAX_TICKS, $start_pid ) {

    $processes{ $INIT_PID } = [ [], [], {}, sub ($env, $msg) {
        my $prefix = DEBUG
            ? ON_MAGENTA "SYS ($CURRENT_CALLER) ::". RESET " "
            : ON_MAGENTA "SYS ::". RESET " ";

        match $msg, +{
            kill => sub ($body) {
                my ($pid) = @$body;
                warn( $prefix, "killing {$pid}\n" ) if DEBUG;
                despawn($pid);
            }
        };
    }];

    # initialise ...
    my $start = spawn( $start_pid );

    send_from( $INIT_PID, $start => '_' => [] );

    my ($term_width) = GetTerminalSize();
    my $init_pid_prefix = '('.$INIT_PID.')';
    $term_width -= length $init_pid_prefix;
    $term_width -= 2 ;

    say FAINT (join ' ' => $init_pid_prefix, map { (' ' x ($term_width - length $_)) . " $_" } ("start(0)")), RESET if DEBUG;

    my $tick = 0;
    while ($tick < $MAX_TICKS) {
        say FAINT (join ' ' => $init_pid_prefix, map { ('-' x ($term_width - length $_)) . " $_" } ("tick($tick)")), RESET if DEBUG;

        $tick++;

        warn Dumper \@msg_inbox  if DEBUG >= 3;
        warn Dumper \@msg_outbox if DEBUG >= 2;

        # deliver all the messages in the queue
        while (@msg_inbox) {
            my $next = shift @msg_inbox;
            #warn Dumper $next;
            my $from = shift $next->@*;
            my ($to, $m) = $next->@*;
            unless (exists $processes{$to}) {
                warn "Got message for unknown pid($to)";
                next;
            }
            push $processes{$to}->[INBOX]->@* => [ $from, $m ];
        }

        # deliver all the messages in the queue
        while (@msg_outbox) {
            my $next = shift @msg_outbox;

            my $from = shift $next->@*;
            my ($to, $m) = $next->@*;
            unless (exists $processes{$to}) {
                warn "Got message for unknown pid($to)";
                next;
            }
            push $processes{$to}->[OUTBOX]->@* => [ $from, $m ];
        }

        my @active =
            map  [ $_, $processes{$_}->@* ],
            sort { $a cmp $b } keys %processes;

        while (@active) {
            my $active = shift @active;

            my ($pid, $inbox, $outbox, $env, $f) = $active->@*;

            while ( $inbox->@* ) {

                my ($from, $msg) = @{ shift $inbox->@* };

                local $CURRENT_PID    = $pid;
                local $CURRENT_CALLER = $from;

                $f->($env, $msg);
            }
        }

        despawn_all;

        warn Dumper \%processes if DEBUG >= 3;

        my @active_processes =
            grep !/^\d\d\d:\#/,     # ignore I/O pids
            grep $_ ne $start,     # ignore start pid
            grep $_ ne $INIT_PID,  # ignore init pid
            keys %processes;

        warn Dumper { active_processes => \@active_processes } if DEBUG >= 3;

        if ( scalar @active_processes == 0 ) {
            say FAINT (join ' ' => $init_pid_prefix, map { ('-' x ($term_width - length $_)) . " $_" } ("exit(0)")), RESET if DEBUG;
            last;
        }
    }

    if (DEBUG) {
        warn Dumper [ keys %processes ];
    }

    return 1;
}

## controls ...

actor '!timeout' => sub ($env, $msg) {

    match $msg, +{
        countdown => sub ($body) {
            my ($timer, $event) = @$body;

            if ( $timer == 0 ) {
                err::log( "*/ !timeout! /* : timer DONE") if DEBUG;
                send_from( $CURRENT_CALLER, @$event );
                despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !timeout! /* : counting down $timer") if DEBUG;
                send_from( $CURRENT_CALLER, $CURRENT_PID => countdown => [ $timer - 1, $event ] );
            }
        }
    };
};


# NOTE:
# this is a bit redundant with sync ... consider
# removing it and rethinking
#
# THIS DOES: send a message, if ! recv, loop resend the message ...
actor '!await' => sub ($env, $msg) {

    match $msg, +{
        send => sub ($body) {
            my ($command, $callback, $caller) = @$body;
            $caller //= $CURRENT_CALLER;
            err::log("*/ !await /* : sending message", $caller) if DEBUG;
            send_to( @$command );
            send_to( $CURRENT_PID => recv => [ $command, $callback, $caller ]);
        },
        recv => sub ($body) {
            my ($command, $callback, $caller) = @$body;

            my $message = recv_from;

            if (defined $message) {
                err::log("*/ !await /* : recieve message($message)", $caller) if DEBUG;
                push $callback->[-1]->@*, $message;
                send_from( $caller, @$callback );
                despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !await /* : no messages", $caller) if DEBUG;
                send_to( $CURRENT_PID => send => $body );
            }
        }
    };
};

# THIS DOES: send a message, and loop on recv ...
actor '!sync' => sub ($env, $msg) {

    match $msg, +{
        send => sub ($body) {
            my ($command, $callback) = @$body;
            err::log("*/ !sync /* : sending message") if DEBUG;
            send_to( @$command );
            send_to( $CURRENT_PID => recv => [ $callback, $CURRENT_CALLER ] );
        },
        recv => sub ($body) {
            my ($callback, $caller) = @$body;

            my $message = recv_from;

            if (defined $message) {
                err::log("*/ !sync /* : recieve message($message)", $caller) if DEBUG;
                #warn Dumper $callback;
                push $callback->[-1]->@*, $message;
                send_from( $caller, @$callback );
                despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !sync /* : no messages", $caller) if DEBUG;
                send_to( $CURRENT_PID => recv => $body );
            }
        }
    };
};

actor '!ident' => sub ($env, $msg) {
    match $msg, +{
        id => sub ($body) {
            my ($val) = @$body;
            err::log("*/ !ident /* returning val($val)") if DEBUG;
            return_to $val;
            despawn( $CURRENT_PID );
        },
    };
};

actor '!cond' => sub ($env, $msg) {
    match $msg, +{
        if => sub ($body) {
            my ($if, $then) = @$body;
            err::log("*/ !cond /* entering if condition") if DEBUG;
            sync( $if, [ $CURRENT_PID, cond => [ $then, $CURRENT_CALLER ]] );
        },
        cond => sub ($body) {
            my ($then, $caller, $result) = @$body;
            if ( $result ) {
                err::log("*/ !cond /* condition successful", $caller ) if DEBUG;
                send_to( $CURRENT_PID, then => [ $then, $caller ] );
            }
            else {
                err::log("*/ !cond /* condition failed", $caller ) if DEBUG;
                despawn( $CURRENT_PID );
            }
        },
        then => sub ($body) {
            my ($then, $caller) = @$body;
            err::log("*/ !cond /* entering then", $caller ) if DEBUG;
            send_from( $caller, @$then );
            despawn( $CURRENT_PID );
        }
    };
};

actor '!seq' => sub ($env, $msg) {
    match $msg, +{
        next => sub ($body) {
            if ( my $statement = shift @$body ) {
                err::log("*/ !seq /* calling, ".(scalar @$body)." remain" ) if DEBUG;
                send_from( $CURRENT_CALLER, @$statement );
                send_from( $CURRENT_CALLER, $CURRENT_PID, next => $body );
            }
            else {
                err::log("*/ !seq /* finished") if DEBUG;
                despawn( $CURRENT_PID );
            }
        },
    };
};

1;

__END__

=pod

=cut
