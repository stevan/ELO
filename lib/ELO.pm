package ELO;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Carp 'croak';
use Scalar::Util 'blessed';
use List::Util 'max';
use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';
use Term::ReadKey 'GetTerminalSize';

use ELO::Actors;
use ELO::IO;
use ELO::Msg;

use Exporter 'import';

our @EXPORT = qw[
    sync
    timeout
    ident
    sequence
    parallel

    loop

    TICK PID CALLER DEBUG
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

our $CURRENT_TICK;
our $CURRENT_PID;
our $CURRENT_CALLER;

# to be exported
sub TICK   () { $CURRENT_TICK   }
sub PID    () { $CURRENT_PID    }
sub CALLER () { $CURRENT_CALLER }

## ----------------------------------------------------------------------------
## process table
## ----------------------------------------------------------------------------

use constant READY   => 1; # can accept arguments
use constant WAITING => 2; # waiting for a time to end
use constant BLOCKED => 3; # blocked on input
use constant EXITING => 4; # waiting to exit at the end of the loop
use constant DONE    => 5; # the end

my $PID_ID = 0;
my %PROCESS_TABLE;

sub proc::exists ($pid) {
    croak 'You must supply a pid' unless $pid;
    exists $PROCESS_TABLE{$pid}
}

sub proc::lookup ($pid) {
    croak 'You must supply a pid to lookup' unless $pid;
    $PROCESS_TABLE{$pid};
}

sub proc::spawn ($name, %env) {
    croak 'You must supply an actor name to spawn' unless $name;
    my $pid     = sprintf '%03d:%s' => ++$PID_ID, $name;
    my $process = bless [ $pid, READY, [], [], { %env }, ELO::Actors::get_actor($name) ] => 'ELO::Process::Record';
    $PROCESS_TABLE{ $pid } = $process;
    $pid;
}

my %to_be_despawned;
sub proc::despawn ($pid) {
    croak 'You must supply a pid to despawn' unless $pid;
    $to_be_despawned{$pid}++;
    $PROCESS_TABLE{ $pid }->set_status(EXITING);
}

sub proc::despawn_all_exiting_pids ( $on_exit ) {
    foreach my $pid (keys %to_be_despawned) {
        ELO::Msg::_remove_all_inbox_messages_for_pid($pid);
        ELO::Msg::_remove_all_outbox_messages_for_pid($pid);

        (delete $PROCESS_TABLE{ $pid })->set_status(DONE);
        $on_exit->( $pid );
    }

    %to_be_despawned = ();
}

package ELO::Process::Record {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    sub pid    ($self) { $self->[0] }
    sub status ($self) { $self->[1] }
    sub inbox  ($self) { $self->[2] }
    sub outbox ($self) { $self->[3] }
    sub env    ($self) { $self->[4] }
    sub actor  ($self) { $self->[5] }

    sub set_status ($self, $status) {
        $self->[1] = $status;
    }
}

## ----------------------------------------------------------------------------
## system interface ... see Actor definitions inside &loop
## ----------------------------------------------------------------------------

our $INIT_PID = '000:<init>';

sub sig::kill($pid) {
    croak 'You must supply a pid to kill' unless $pid;
    msg( $INIT_PID, kill => [ $pid ] );
}

sub sig::timer($timeout, $callback) {
    croak 'You must supply a timeout value'.(defined $timeout ? ' and it must be greater than 0' : '')
        unless $timeout;
    croak 'You must supply a callback msg()'
        unless blessed $callback && $callback->isa('ELO::Msg::Message');
    msg( $INIT_PID, timer => [ $timeout, $callback ] );
}

sub sys::waitpid($pid, $callback) {
    croak 'You must supply a pid value' unless $pid;
    croak 'You must supply a callback msg()'
        unless blessed $callback && $callback->isa('ELO::Msg::Message');
    msg( $INIT_PID, waitpid => [ $pid, $callback ] );
}

## ----------------------------------------------------------------------------
## currency control
## ----------------------------------------------------------------------------

sub timeout ($ticks, $callback) {
    croak 'You must supply a ticks value'.(defined $ticks ? ' and it must be greater than 0' : '')
        unless $ticks;
    croak 'You must supply a callback msg()'
        unless blessed $callback && $callback->isa('ELO::Msg::Message');
    msg( proc::spawn( '!timeout' ), countdown => [ $ticks, $callback ] );
}

sub sync ($input, $output) {
    croak 'You must supply a input msg()'
        unless blessed $input && $input->isa('ELO::Msg::Message');
    croak 'You must supply a output msg()'
        unless blessed $output && $output->isa('ELO::Msg::Message');
    msg( proc::spawn( '!sync' ), send => [ $input, $output ] );
}

sub ident ($val=undef) {
    msg( proc::spawn( '!ident' ), id => [ $val // () ] );
}

sub sequence (@statements) {
    (blessed $_ && $_->isa('ELO::Msg::Message'))
        || croak 'You must supply a sequence of msg()s, not '.$_
            foreach @statements;
    msg( proc::spawn( '!sequence' ), next => [ @statements ] );
}

sub parallel (@statements) {
    (blessed $_ && $_->isa('ELO::Msg::Message'))
        || croak 'You must supply a sequence of msg()s, not '.$_
            foreach @statements;
    msg( proc::spawn( '!parallel' ), all => [ @statements ] );
}

## ----------------------------------------------------------------------------
## teh loop
## ----------------------------------------------------------------------------

my %TIMERS;       # HASH< $tick_to_fire_at > = [ $msg, ... ]
my %PID_WATCHERS; # HASH< $pid > = [ $msg, ... ]

sub loop ( $MAX_TICKS, $start_pid ) {

    # initialise the system pid singleton
    $PROCESS_TABLE{ $INIT_PID } = bless [ $INIT_PID, READY, [], [], {}, sub ($env, $msg) {
        my $prefix = DEBUG
            ? ON_MAGENTA "SYS ($CURRENT_CALLER) ::". RESET " "
            : ON_MAGENTA "SYS ::". RESET " ";

        match $msg, +{
            kill => sub ($pid) {
                warn( $prefix, "killing ... {$pid}\n" ) if DEBUG;
                proc::despawn($pid);
            },
            waitpid => sub ($pid, $callback) {
                if (proc::exists($pid)) {
                    warn( $prefix, "setting watcher for ($pid) ...\n" ) if DEBUG;
                    push @{ $PID_WATCHERS{$pid} //=[] } => [
                        $CURRENT_CALLER,
                        $callback
                    ];
                }
                else {
                    $callback->send_from($CURRENT_CALLER);
                }
            },
            timer => sub ($timeout, $callback) {
                warn( $prefix, "setting timer for($timeout) ...\n" ) if DEBUG;

                $timeout--; # subtrack one for this tick ...

                push @{ $TIMERS{ $CURRENT_TICK + $timeout } //= [] } => [
                    $CURRENT_CALLER,
                    $callback
                ];
            }
        };
    }] => 'ELO::Process::Record';

    # initialise ...
    my $start = proc::spawn( $start_pid );

    msg($start => '_' => [])->send_from( $INIT_PID );

    my $should_exit = 0;
    my $has_exited  = 0;

    my $tick = 0;

    _loop_log_line("start(%d)", $tick) if DEBUG;
    while ($tick < $MAX_TICKS) {
        $tick++;
        _loop_log_line("tick(%d)", $tick) if DEBUG;

        local $CURRENT_TICK = $tick;

        if ( exists $TIMERS{ $CURRENT_TICK } ) {
            my $alarms = delete $TIMERS{ $CURRENT_TICK };
            foreach my $alarm ($alarms->@*) {
                my ($caller, $callback) = @$alarm;
                $callback->send_from( $caller );
            }
        }

        ELO::Msg::_deliver_all_messages();
        ELO::Msg::_accept_all_messages();

        my @ready = grep scalar $_->inbox->@*,
                    grep $_->status == READY,
                    map $PROCESS_TABLE{$_},
                    sort keys %PROCESS_TABLE;

        while (@ready) {
            my $active = shift @ready;

            while ( $active->inbox->@* ) {

                my ($from, $msg) = @{ shift $active->inbox->@* };

                local $CURRENT_PID    = $active->pid;
                local $CURRENT_CALLER = $from;

                say BLUE " >>> calling : ", CYAN $msg->to_string, RESET if DEBUG >= 3;

                $active->actor->($active->env, $msg);
            }
        }

        proc::despawn_all_exiting_pids(sub ($pid) {
            #warn "!!!! DESPAWNED ($pid)";
            if ( exists $PID_WATCHERS{$pid} ) {
                my $watchers = delete $PID_WATCHERS{$pid};
                foreach my $watcher ($watchers->@*) {
                    my ($caller, $callback) = @$watcher;
                    #warn "!!!! CALLING WATCHER HANDLER ($pid)";
                    $callback->send_from( $caller );
                }
            }
        });

        warn Dumper \%PROCESS_TABLE if DEBUG >= 4;
        warn Dumper \%TIMERS        if DEBUG >= 4;

        my @active_processes =
            grep !/^\d\d\d:\#/,    # ignore I/O pids
            grep $_ ne $start,     # ignore start pid
            grep $_ ne $INIT_PID,  # ignore init pid
            keys %PROCESS_TABLE;

        warn Dumper {
            active_processes => \@active_processes,
            msg_inbox        => [ ELO::Msg::_message_inbox() ],
        } if DEBUG >= 3;

        if ($should_exit) {
            $has_exited++;
            last;
        }

        #warn "TIMER COUNTER: " . scalar(keys %TIMERS);
        #warn "ACTIVE : " . scalar(@active_processes);
        #warn "TICK : " . $tick;
        #warn "INBOX : " . Dumper [ ELO::Msg::_message_inbox() ];

        # at least do one tick before shutting things down ...
        if ( $tick > 1 && scalar @active_processes == 0 && scalar(keys %TIMERS) == 0 ) {
            #warn "gonna exit ...";
            # loop one last time to flush any I/O
            if ( ELO::Msg::_has_inbox_messages() ) {
                $has_exited++;
                last;
            }
            else {
                _loop_log_line("flushing(%d)", $tick) if DEBUG;
                $should_exit++;
            }
        }
    }

    warn Dumper \%PID_WATCHERS if DEBUG >= 4;

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
            err::log("*/ !ident /* returning val($val)")->send if DEBUG;
            return_to $val;
            proc::despawn( $CURRENT_PID );
        },
    };
};

# wait, then call statement
actor '!timeout' => sub ($env, $msg) {
    match $msg, +{
        countdown => sub ($timer, $event) {

            if ( $timer == 0 ) {
                err::log( "*/ !timeout! /* : timer DONE")->send if DEBUG;
                $event->send_from( $CURRENT_CALLER );
                proc::despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !timeout! /* : counting down $timer")->send if DEBUG;
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
            err::log("*/ !sync /* : sending message")->send if DEBUG;
            $input->send;
            msg($CURRENT_PID => recv => [ $output ])->send_from( $CURRENT_CALLER );
        },
        recv => sub ($output) {

            my $message = recv_from;

            if (defined $message) {
                err::log("*/ !sync /* : recieve message($message)")->send if DEBUG;
                #warn Dumper $output;
                msg(@$output)
                    ->curry( $message )
                    ->send_from( $CURRENT_CALLER );
                proc::despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !sync /* : no messages")->send if DEBUG;
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
                err::log("*/ !sequence /* calling, ".(scalar @statements)." remain" )->send if DEBUG;
                $statement->send_from( $CURRENT_CALLER );
                msg($CURRENT_PID, next => \@statements)->send_from( $CURRENT_CALLER );
            }
            else {
                err::log("*/ !sequence /* finished")->send if DEBUG;
                proc::despawn( $CURRENT_PID );
            }
        },
    };
};

actor '!parallel' => sub ($env, $msg) {
    match $msg, +{
        all => sub (@statements) {
            err::log("*/ !parallel /* sending ".(scalar @statements)." messages" )->send if DEBUG;
            foreach my $statement ( @statements ) {
                $statement->send_from( $CURRENT_CALLER );
            }
            err::log("*/ !parallel /* finished")->send if DEBUG;
            proc::despawn( $CURRENT_PID );
        },
    };
};

1;

__END__

=pod

use Term::ANSIColor 'color';

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
