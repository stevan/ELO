package SAM;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use List::Util 'max';
use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants', 'color';
use Term::ReadKey 'GetTerminalSize';

use SAM::Actors;
use SAM::IO;
use SAM::Msg;

use Exporter 'import';

our @EXPORT = qw[
    sync
    timeout
    ident
    sequence
    parallel

    loop

    PID CALLER DEBUG
];

## ----------------------------------------------------------------------------
## ENV flags
## ----------------------------------------------------------------------------

use constant DEBUG    => $ENV{DEBUG} // 0;
use constant DEBUGGER => $ENV{DEBUGGER} // 0;

## ----------------------------------------------------------------------------
## Misc. stuff
## ----------------------------------------------------------------------------

# XXX - put this into a module along with other similar stuff?
our $TERM_SIZE = (GetTerminalSize())[0];

## ----------------------------------------------------------------------------
## call context info
## ----------------------------------------------------------------------------

our $CURRENT_PID;
our $CURRENT_CALLER;

# to be exported
sub PID    () { $CURRENT_PID    }
sub CALLER () { $CURRENT_CALLER }

## ----------------------------------------------------------------------------
## process table
## ----------------------------------------------------------------------------

my %PROCESS_TABLE;

sub PROCESS_TABLE () { \%PROCESS_TABLE }

sub _lookup_process ($pid) { $PROCESS_TABLE{$pid} }

## ----------------------------------------------------------------------------
## system interface ... see Actor definitions inside &loop
## ----------------------------------------------------------------------------

our $INIT_PID = '000:<init>';

sub sys::kill($pid) {
    msg( $INIT_PID, kill => [ $pid ] )
        ->return_or_send( wantarray );
}

sub sys::waitpids($pids, $callback) {
    msg( $INIT_PID, waitpids => [ $pids, $callback ] )
        ->return_or_send( wantarray );
}

my $PID = 0;
sub sys::spawn ($name, %env) {
    my $process = [ [], [], { %env }, SAM::Actors::get_actor($name) ];
    my $pid = sprintf '%03d:%s' => ++$PID, $name;
    $PROCESS_TABLE{ $pid } = $process;
    $pid;
}

my %to_be_despawned;
sub sys::despawn ($pid) {
    $to_be_despawned{$pid}++;
}

sub sys::despawn_waiting_pids () {
    foreach my $pid (keys %to_be_despawned) {
        SAM::Msg::_remove_all_inbox_messages_for_pid($pid);
        SAM::Msg::_remove_all_outbox_messages_for_pid($pid);

        delete $PROCESS_TABLE{ $pid };
    }

    %to_be_despawned = ();
}

## ----------------------------------------------------------------------------
## currency control
## ----------------------------------------------------------------------------

sub timeout ($ticks, $callback) {
    msg( sys::spawn( '!timeout' ), countdown => [ $ticks, $callback ] )
        ->return_or_send( wantarray );
}

sub sync ($input, $output) {
    msg( sys::spawn( '!sync' ), send => [ $input, $output ] )
        ->return_or_send( wantarray );
}

sub ident ($val=undef) {
    msg( sys::spawn( '!ident' ), id => [ $val // () ] )
        ->return_or_send( wantarray );
}

sub sequence (@statements) {
    msg( sys::spawn( '!sequence' ), next => [ @statements ] )
        ->return_or_send( wantarray );
}

sub parallel (@statements) {
    msg( sys::spawn( '!parallel' ), all => [ @statements ] )
        ->return_or_send( wantarray );
}

## ----------------------------------------------------------------------------
## teh loop
## ----------------------------------------------------------------------------

sub loop ( $MAX_TICKS, $start_pid ) {

    # initialise the system pid singleton
    $PROCESS_TABLE{ $INIT_PID } = [ [], [], {}, sub ($env, $msg) {
        my $prefix = DEBUG
            ? ON_MAGENTA "SYS ($CURRENT_CALLER) ::". RESET " "
            : ON_MAGENTA "SYS ::". RESET " ";

        match $msg, +{
            kill => sub ($pid) {
                warn( $prefix, "killing ... {$pid}\n" ) if DEBUG;
                sys::despawn($pid);
            },
            waitpids => sub ($pids, $callback) {

                my @active = grep { exists $PROCESS_TABLE{$_} } @$pids;

                if (@active) {
                    warn( $prefix, "waiting for ".(scalar @$pids)." pids, found ".(scalar @active)." active" ) if DEBUG;
                    msg($CURRENT_PID, waitpids => [ \@active, $callback ])->send_from( $CURRENT_CALLER );
                }
                else {
                    warn( $prefix, "no more active pids" ) if DEBUG;
                    $callback->send_from( $CURRENT_CALLER );
                }

            },
        };
    }];

    # initialise ...
    my $start = sys::spawn( $start_pid );

    msg($start => '_' => [])->send_from( $INIT_PID );

    my $should_exit = 0;
    my $has_exited  = 0;

    my $tick = 0;

    _loop_log_line("start(%d)", $tick) if DEBUG;
    while ($tick < $MAX_TICKS) {
        $tick++;
        _loop_log_line("tick(%d)", $tick) if DEBUG;

        SAM::Msg::_deliver_all_messages();
        SAM::Msg::_accept_all_messages();

        my @active = map [ $_, $PROCESS_TABLE{$_}->@* ], keys %PROCESS_TABLE;

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

        sys::despawn_waiting_pids();

        warn Dumper \%PROCESS_TABLE if DEBUG >= 4;

        my @active_processes =
            grep !/^\d\d\d:\#/,     # ignore I/O pids
            grep $_ ne $start,     # ignore start pid
            grep $_ ne $INIT_PID,  # ignore init pid
            keys %PROCESS_TABLE;

        warn Dumper {
            active_processes => \@active_processes,
            msg_inbox        => [ SAM::Msg::_message_inbox() ],
        } if DEBUG >= 3;

        if ($should_exit) {
            $has_exited++;
            last;
        }

        if ( scalar @active_processes == 0 ) {
            # loop one last time to flush any I/O
            if ( SAM::Msg::_has_inbox_messages() ) {
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
        warn Dumper [ keys %PROCESS_TABLE ];
    }

    my @zombies = grep !/^\d\d\d:\#/,    # ignore I/O pids
                  grep $_ ne $start,     # ignore start pid
                  grep $_ ne $INIT_PID,  # ignore init pid
                  keys %PROCESS_TABLE;

    if ( @zombies ) {
        warn("GOT ZOMBIES: ", Dumper(\@zombies)) if DEBUG;
        return;
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

## ----------------------------------------------------------------------------
## Core Actors
## ----------------------------------------------------------------------------

# will just return the input given ...
actor '!ident' => sub ($env, $msg) {
    match $msg, +{
        id => sub ($val) {
            err::log("*/ !ident /* returning val($val)") if DEBUG;
            return_to $val;
            sys::despawn( $CURRENT_PID );
        },
    };
};

# wait, then call statement
actor '!timeout' => sub ($env, $msg) {
    match $msg, +{
        countdown => sub ($timer, $event) {

            if ( $timer == 0 ) {
                err::log( "*/ !timeout! /* : timer DONE") if DEBUG;
                $event->send_from( $CURRENT_CALLER );
                sys::despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !timeout! /* : counting down $timer") if DEBUG;
                msg($CURRENT_PID => countdown => [ $timer - 1, $event ])->send_from( $CURRENT_CALLER );
            }
        }
    };
};

# send a message, and loop on recv ...
# then call statement with recv values appended to statement args
actor '!sync' => sub ($env, $msg) {

    match $msg, +{
        send => sub ($input, $output) {
            err::log("*/ !sync /* : sending message") if DEBUG;
            $input->send;
            msg($CURRENT_PID => recv => [ $output ])->send_from( $CURRENT_CALLER );
        },
        recv => sub ($output) {

            my $message = recv_from;

            if (defined $message) {
                err::log("*/ !sync /* : recieve message($message)") if DEBUG;
                #warn Dumper $output;
                msg(@$output)
                    ->curry( $message )
                    ->send_from( $CURRENT_CALLER );
                sys::despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !sync /* : no messages") if DEBUG;
                msg($CURRENT_PID => recv => [ $output ])->send_from( $CURRENT_CALLER );
            }
        }
    };
};

# ... runnnig muliple statements

actor '!sequence' => sub ($env, $msg) {
    match $msg, +{
        next => sub (@statements) {
            if ( my $statement = shift @statements ) {
                err::log("*/ !sequence /* calling, ".(scalar @statements)." remain" ) if DEBUG;
                $statement->send_from( $CURRENT_CALLER );
                msg($CURRENT_PID, next => \@statements)->send_from( $CURRENT_CALLER );
            }
            else {
                err::log("*/ !sequence /* finished") if DEBUG;
                sys::despawn( $CURRENT_PID );
            }
        },
    };
};

actor '!parallel' => sub ($env, $msg) {
    match $msg, +{
        all => sub (@statements) {
            err::log("*/ !parallel /* sending ".(scalar @statements)." messages" ) if DEBUG;
            foreach my $statement ( @statements ) {
                $statement->send_from( $CURRENT_CALLER );
            }
            err::log("*/ !parallel /* finished") if DEBUG;
            sys::despawn( $CURRENT_PID );
        },
    };
};

1;

__END__

=pod

# re-implement later ...
if ( DEBUGGER ) {

    my @pids = sort keys %PROCESS_TABLE;

    my $longest_pid = max( map length, @pids );

    warn FAINT '-' x $TERM_SIZE, RESET "\n";
    warn FAINT ON_MAGENTA " << MESSAGES >> " . RESET "\n";
    warn FAINT '-' x $TERM_SIZE, RESET "\n";
    foreach my $pid ( @pids ) {
        my @inbox  = $PROCESS_TABLE{$pid}->[0]->@*;
        my ($num, $name) = split ':' => $pid;

        my $pid_color = 'black on_ansi'.((int($num)+3) * 8);

        warn '  '.
            color($pid_color).
                sprintf("> %-${longest_pid}s ", $pid).
            RESET " (".
            CYAN (join ' / ' =>
                map {
                    my $action = $_->[1]->action;
                    my $body   = join ', ' => $_->[1]->body->@*;
                    "${action}![${body}]";
                } @inbox).
            RESET ")\n";
    }
    warn FAINT '-' x $TERM_SIZE, RESET "\n";
    my $proceed = <>;
}

=cut
