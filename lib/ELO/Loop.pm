package ELO::Loop;
# ABSTRACT: Event Loop Orchestra

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

use ELO::Actors; # to get actors for process creation, and one use of `match` ...

use ELO::Core::Message;
use ELO::Core::ProcessRecord;

use ELO::Debug;

use Exporter 'import';

our @EXPORT = qw[
    msg

    loop

    TICK PID CALLER
];

## ----------------------------------------------------------------------------
## msg interface
## ----------------------------------------------------------------------------

sub msg ($pid, $action, $msg) { ELO::Core::Message->new( $pid, $action, $msg ) }

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
## Message Queue
## ----------------------------------------------------------------------------

my @MSG_INBOX;

sub enqueue_msg ($msg) {
    push @MSG_INBOX => [ $CURRENT_PID, $msg ];
}

sub enqueue_msg_from ($from, $msg) {
    push @MSG_INBOX => [ $from, $msg ];
}

## ----------------------------------------------------------------------------
## process table
## ----------------------------------------------------------------------------

use constant READY   => 1; # can accept arguments
use constant EXITING => 2; # waiting to exit at the end of the loop
use constant DONE    => 3; # the end

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
    my $process = ELO::Core::ProcessRecord->new(
        $pid, READY, \%env, ELO::Actors::get_actor($name)
    );
    $PROCESS_TABLE{ $pid } = $process;
    $pid;
}

sub proc::despawn ($pid) {
    croak 'You must supply a pid to despawn' unless $pid;
    $PROCESS_TABLE{ $pid }->set_status(EXITING);
}

sub proc::despawn_all_exiting_pids ( $on_exit ) {
    foreach my $pid (keys %PROCESS_TABLE) {
        my $proc = $PROCESS_TABLE{$pid};
        if ( $proc->status == EXITING ) {
            @MSG_INBOX = grep { $_->[1]->pid ne $pid } @MSG_INBOX;

            (delete $PROCESS_TABLE{ $pid })->set_status(DONE);
            $on_exit->( $pid );
        }
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
    croak 'You must supply a timeout value' unless defined $timeout;
    croak 'You must supply a callback msg()'
        unless blessed $callback && $callback->isa('ELO::Core::Message');
    msg( $INIT_PID, timer => [ $timeout, $callback ] );
}

sub sig::waitpid($pid, $callback) {
    croak 'You must supply a pid value' unless $pid;
    croak 'You must supply a callback msg()'
        unless blessed $callback && $callback->isa('ELO::Core::Message');
    msg( $INIT_PID, waitpid => [ $pid, $callback ] );
}

## ----------------------------------------------------------------------------
## teh loop
## ----------------------------------------------------------------------------

my %TIMERS;   # HASH< $tick_to_fire_at > = [ $msg, ... ]
my %WAITPIDS; # HASH< $pid > = [ $msg, ... ]

sub loop ( $MAX_TICKS, $start_pid ) {

    # initialise the system pid singleton
    $PROCESS_TABLE{ $INIT_PID } = ELO::Core::ProcessRecord->new($INIT_PID, READY, {}, sub ($env, $msg) {
        my $prefix = ON_MAGENTA "SYS ($CURRENT_CALLER) ::". RESET " ";

        match $msg, +{
            kill => sub ($pid) {
                warn( $prefix, "killing ... {$pid}\n" ) if DEBUG_SIGS;
                proc::despawn($pid);
            },
            waitpid => sub ($pid, $callback) {
                if (proc::exists($pid)) {
                    warn( $prefix, "setting watcher for ($pid) ...\n" ) if DEBUG_SIGS;
                    push @{ $WAITPIDS{$pid} //=[] } => [
                        $CURRENT_CALLER,
                        $callback
                    ];
                }
                else {
                    $callback->send_from($CURRENT_CALLER);
                }
            },
            timer => sub ($timeout, $callback) {
                warn( $prefix, "setting timer for($timeout) ...\n" ) if DEBUG_SIGS;

                $timeout--; # subtrack one for this tick ...

                if ( $timeout <= 0 ) {
                    $callback->send_from($CURRENT_CALLER);
                }
                else {
                    push @{ $TIMERS{ $CURRENT_TICK + $timeout } //= [] } => [
                        $CURRENT_CALLER,
                        $callback
                    ];
                }
            }
        };
    });

    # initialise ...
    my $start = proc::spawn( $start_pid );

    msg($start => '_' => [])->send_from( $INIT_PID );

    my $should_exit = 0;
    my $has_exited  = 0;

    my $tick = 0;

    _loop_log_line("start(%d)", $tick) if DEBUG_LOOP;
    while ($tick < $MAX_TICKS) {
        $tick++;
        _loop_log_line("tick(%d)", $tick) if DEBUG_LOOP;

        local $CURRENT_TICK = $tick;

        if ( exists $TIMERS{ $CURRENT_TICK } ) {
            my $alarms = delete $TIMERS{ $CURRENT_TICK };
            foreach my $alarm ($alarms->@*) {
                my ($caller, $callback) = @$alarm;
                $callback->send_from( $caller );
            }
        }

        warn Dumper {
            msg              => 'Inbox before delivery',
            msg_inbox        => \@MSG_INBOX,
        } if DEBUG_MSGS;

        my @inbox = @MSG_INBOX;
        @MSG_INBOX = ();

        while (@inbox) {
            my ($from, $msg) = (shift @inbox)->@*;

            my $active = $PROCESS_TABLE{ $msg->pid };

            local $CURRENT_PID    = $active->pid;
            local $CURRENT_CALLER = $from;

            say BLUE " >>> calling : ", CYAN $msg->to_string, RESET
                if DEBUG_CALLS;

            $active->actor->($active->env, $msg);
        }

        proc::despawn_all_exiting_pids(sub ($pid) {
            if ( exists $WAITPIDS{$pid} ) {
                my $watchers = delete $WAITPIDS{$pid};
                foreach my $watcher ($watchers->@*) {
                    my ($caller, $callback) = @$watcher;
                    $callback->send_from( $caller );
                }
            }
        });

        warn Dumper \%PROCESS_TABLE if DEBUG_PROCS;
        warn Dumper \%TIMERS        if DEBUG_TIMERS;

        my @active_processes =
            grep !/^\d\d\d:\#/,    # ignore I/O pids
            grep $_ ne $start,     # ignore start pid
            grep $_ ne $INIT_PID,  # ignore init pid
            keys %PROCESS_TABLE;

        warn Dumper {
            msg              => 'Active Procsses and Inbox after tick',
            active_processes => \@active_processes,
            msg_inbox        => \@MSG_INBOX,
        } if DEBUG_MSGS;

        if ($should_exit) {
            $has_exited++;
            last;
        }

        # at least do one tick before shutting things down ...
        if ( $tick > 1 && scalar @active_processes == 0 && scalar(keys %TIMERS) == 0 ) {
            # loop one last time to flush any I/O
            if ( scalar @MSG_INBOX == 0 ) {
                $has_exited++;
                last;
            }
            else {
                _loop_log_line("flushing(%d)", $tick) if DEBUG_LOOP;
                $should_exit++;
            }
        }
    }

    warn Dumper \%WAITPIDS if DEBUG_WAITPIDS;

    if ( $has_exited ) {
        _loop_log_line("exit(%d)", $tick) if DEBUG_LOOP;
    } else {
        _loop_log_line("halt(%d)", $tick) if DEBUG_LOOP;
    }

    my @zombies = grep !/^\d\d\d:\#/,    # ignore I/O pids
                  grep $_ ne $start,     # ignore start pid
                  grep $_ ne $INIT_PID,  # ignore init pid
                  keys %PROCESS_TABLE;

    if ( @zombies ) {
        warn("GOT ZOMBIES: ", Dumper(\@zombies)) if DEBUG_LOOP;
        return;
    }

    return 1;
}

# XXX - put this into a module along with other similar stuff?
our $TERM_SIZE = (GetTerminalSize())[0];

sub _loop_log_line ( $fmt, $tick ) {
    state $init_pid_prefix = '('.$INIT_PID.')';
    state $term_width = $TERM_SIZE - (length $init_pid_prefix) - 2;

    say FAINT
        (join ' ' => $init_pid_prefix,
            map { ('-' x ($term_width - length $_)) . " $_" }
                (sprintf $fmt, $tick)),
                    RESET;
}

1;

__END__

