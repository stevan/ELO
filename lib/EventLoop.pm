package EventLoop;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use List::Util 'max';
use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants', 'color';
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

    ident
    sequence
    cond

    loop

    SYS

    PID CALLER

    DEBUG
];

# flags

use constant INBOX  => 0;
use constant OUTBOX => 1;

use constant DEBUG    => $ENV{DEBUG} // 0;
use constant DEBUGGER => $ENV{DEBUGGER} // 0;

# stuff

our $TERM_SIZE = (GetTerminalSize())[0];

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

# TODO:
# Make Sys into Signals

sub SYS () { $INIT_PID }

## ... message delivery

sub copy_msg ($msg, @additional_args) {
    my ($pid, $action, $body) = @$msg;
    [ $pid, $action, [ @$body, @additional_args ] ]
}

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
sub spawn ($name, %env) {
    my $process = [ [], [], { %env }, EventLoop::Actors::get_actor($name) ];
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
    my $pid  = spawn( '!timeout' );
    my $args = [ $pid, countdown => [ $ticks, $callback ] ];
    defined wantarray
        ? (wantarray
            ? $args
            : do { send_to( @$args ); $pid })
        : send_to( @$args );
}

sub sync ($input, $output) {
    my $pid  = spawn( '!sync' );
    my $args = [ $pid, send => [ $input, $output ] ];
    defined wantarray
        ? (wantarray
            ? $args
            : do { send_to( @$args ); $pid })
        : send_to( @$args );
}

sub ident ($val=undef) {
    my $pid  = spawn( '!ident' );
    my $args = [ $pid, id => [ $val // () ] ];
    defined wantarray
        ? (wantarray
            ? $args
            : do { send_to( @$args ); $pid })
        : send_to( @$args );
}

sub sequence (@statements) {
    my $pid  = spawn( '!sequence' );
    my $args = [ $pid, next => [ @statements ] ];
    defined wantarray
        ? (wantarray
            ? $args
            : do { send_to( @$args ); $pid })
        : send_to( @$args );
}

sub parallel (@statements) {
    my $pid  = spawn( '!parallel' );
    my $args = [ $pid, all => [ @statements ] ];
    defined wantarray
        ? (wantarray
            ? $args
            : do { send_to( @$args ); $pid })
        : send_to( @$args );
}

sub cond ($cond, $then) {
    my $pid  = spawn( '!cond' );
    my $args = [ $pid, if => [ $cond, $then ] ];
    defined wantarray
        ? (wantarray
            ? $args
            : do { send_to( @$args ); $pid })
        : send_to( @$args );
}

## ...

sub loop ( $MAX_TICKS, $start_pid ) {

    # initialise the system pid singleton
    $processes{ $INIT_PID } = [ [], [], {}, sub ($env, $msg) {
        my $prefix = DEBUG
            ? ON_MAGENTA "SYS ($CURRENT_CALLER) ::". RESET " "
            : ON_MAGENTA "SYS ::". RESET " ";

        match $msg, +{
            kill => sub ($body) {
                my ($pid) = @$body;
                warn( $prefix, "killing ... {$pid}\n" ) if DEBUG;
                despawn($pid);
            },
            waitpids => sub ($body) {
                my ($pids, $callback) = @$body;

                my @active = grep { exists $processes{$_} } @$pids;

                if (@active) {
                    warn( $prefix, "waiting for ".(scalar @$pids)." pids, found ".(scalar @active)." active" ) if DEBUG;
                    send_from( $CURRENT_CALLER, $CURRENT_PID, waitpids => [ \@active, $callback ] );
                }
                else {
                    warn( $prefix, "no more active pids" ) if DEBUG;
                    send_from( $CURRENT_CALLER, @$callback );
                }

            },
        };
    }];

    # initialise ...
    my $start = spawn( $start_pid );

    send_from( $INIT_PID, $start => '_' => [] );

    my $should_exit = 0;
    my $has_exited  = 0;

    my $tick = 0;

    _loop_log_line("start(%d)", $tick) if DEBUG;
    while ($tick < $MAX_TICKS) {
        $tick++;
        _loop_log_line("tick(%d)", $tick) if DEBUG;

        warn Dumper \@msg_inbox  if DEBUG >= 4;
        warn Dumper \@msg_outbox if DEBUG >= 4;

        my $has_inbox_messages  = !! scalar @msg_inbox;
        my $has_outbox_messages = !! scalar @msg_outbox;

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

        #
        if ( DEBUGGER ) {

            my @pids = sort keys %processes;

            my $longest_pid = max( map length, @pids );

            warn FAINT '-' x $TERM_SIZE, RESET "\n";
            warn FAINT ON_MAGENTA " << MESSAGES >> " . RESET "\n";
            warn FAINT '-' x $TERM_SIZE, RESET "\n";
            foreach my $pid ( @pids ) {
                my @inbox  = $processes{$pid}->[INBOX]->@*;
                my ($num, $name) = split ':' => $pid;

                my $pid_color = 'black on_ansi'.((int($num)+3) * 8);

                warn '  '.
                    color($pid_color).
                        sprintf("> %-${longest_pid}s ", $pid).
                    RESET " (".
                    CYAN (join ' / ' =>
                        map {
                            my $pid    = $_->[0];
                            my $action = $_->[1]->[0];
                            my $msgs   = join ', ' => $_->[1]->[1]->@*;
                            "${action}![${msgs}]";
                        } @inbox).
                    RESET ")\n";
            }
            warn FAINT '-' x $TERM_SIZE, RESET "\n";
            my $proceed = <>;
        }

        my @active = map [ $_, $processes{$_}->@* ], keys %processes;

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

        warn Dumper \%processes if DEBUG >= 4;

        my @active_processes =
            grep !/^\d\d\d:\#/,     # ignore I/O pids
            grep $_ ne $start,     # ignore start pid
            grep $_ ne $INIT_PID,  # ignore init pid
            keys %processes;

        warn Dumper {
            active_processes => \@active_processes,
            msg_inbox        => \@msg_inbox,
        } if DEBUG >= 3;

        if ($should_exit) {
            $has_exited++;
            last;
        }

        if ( scalar @active_processes == 0 ) {
            # loop one last time to flush any I/O
            if ( scalar @msg_inbox == 0 ) {
                $has_exited++;
                last;
            }
            else {
                _loop_log_line("flushing(%d)", $tick) if DEBUG;
                $should_exit++;
            }
        }
    }

    if ( $has_exited ) {
        _loop_log_line("exit(%d)", $tick) if DEBUG;
    } else {
        _loop_log_line("halt(%d)", $tick) if DEBUG;
    }

    if (DEBUG >= 3) {
        warn Dumper [ keys %processes ];
    }

    return 1;
}

sub _loop_log_line ( $fmt, $tick ) {
    state $init_pid_prefix = '('.$INIT_PID.')';
    state $term_width = $TERM_SIZE - (length $init_pid_prefix) - 2;

    say FAINT
        (join ' ' => $init_pid_prefix,
            map { ('-' x ($term_width - length $_)) . " $_" }
                (sprintf $fmt, $tick)),
                    RESET;
}


## controls ...

# will just return the input given ...
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

# wait, then call statement
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

# send a message, and loop on recv ...
# then call statement with recv values appended to statement args
actor '!sync' => sub ($env, $msg) {

    match $msg, +{
        send => sub ($body) {
            my ($input, $output) = @$body;
            err::log("*/ !sync /* : sending message") if DEBUG;
            send_to( @$input );
            send_from( $CURRENT_CALLER, $CURRENT_PID => recv => [ $output ] );
        },
        recv => sub ($body) {
            my ($output) = @$body;

            my $message = recv_from;

            if (defined $message) {
                err::log("*/ !sync /* : recieve message($message)") if DEBUG;
                #warn Dumper $output;
                $output = copy_msg($output, $message);
                send_from( $CURRENT_CALLER, @$output );
                despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !sync /* : no messages") if DEBUG;
                send_from( $CURRENT_CALLER, $CURRENT_PID => recv => $body );
            }
        }
    };
};

# ... runnnig muliple statements

actor '!sequence' => sub ($env, $msg) {
    match $msg, +{
        next => sub ($body) {
            if ( my $statement = shift @$body ) {
                err::log("*/ !sequence /* calling, ".(scalar @$body)." remain" ) if DEBUG;
                send_from( $CURRENT_CALLER, @$statement );
                send_from( $CURRENT_CALLER, $CURRENT_PID, next => $body );
            }
            else {
                err::log("*/ !sequence /* finished") if DEBUG;
                despawn( $CURRENT_PID );
            }
        },
    };
};

actor '!parallel' => sub ($env, $msg) {
    match $msg, +{
        all => sub ($body) {
            err::log("*/ !parallel /* sending ".(scalar @$body)." messages" ) if DEBUG;
            foreach my $statement ( @$body ) {
                send_from( $CURRENT_CALLER, @$statement );
            }
            err::log("*/ !parallel /* finished") if DEBUG;
            despawn( $CURRENT_PID );
        },
    };
};

1;

__END__

=pod

=cut
