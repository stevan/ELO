package ELO::Loop;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Carp 'croak';
use Scalar::Util 'blessed';
use List::Util 'max';
use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';
use Term::ReadKey 'GetTerminalSize';

use ELO::VM qw[ $INIT_PID PID CALLER msg ];

use ELO::Actors; # one use of `match` in the INIT_PID setup
use ELO::Core::ProcessRecord;
use ELO::Debug;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Exporter 'import';

our @EXPORT = qw[
    loop
];

## ----------------------------------------------------------------------------
## Signals ... see Actor definitions inside &loop
## ----------------------------------------------------------------------------

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

our $CURRENT_TICK; # localized context for TIMERS
our %TIMERS;       # HASH< $tick_to_fire_at > = [ [ $from, $msg ], ... ]
our %WAITPIDS;     # HASH< $pid > = [ [ $from, $msg ], ... ]

use Time::HiRes 'time';

use constant STATS => $ENV{STATS} // 0;

sub loop ( $MAX_TICKS, $start_pid ) {

    my %STATS;

    # initialise the system pid singleton
    $ELO::VM::PROCESS_TABLE{ $INIT_PID } = ELO::Core::ProcessRecord->new($INIT_PID, {}, sub ($env, $msg) {
        my $prefix = ON_MAGENTA "SYS (".CALLER.") ::". RESET " ";

        match $msg, +{
            kill => sub ($pid) {
                my $proc = proc::lookup($pid);
                if ($proc && !$proc->is_exiting) {
                    sys::err::raw( $prefix, "killing ... {$pid}\n" ) if DEBUG_SIGS;
                    proc::despawn($pid);
                }
                else {
                    sys::err::raw( $prefix, "attempted to kill dead process {$pid}\n" ) if DEBUG_SIGS;
                }
            },
            waitpid => sub ($pid, $callback) {
                if (proc::exists($pid)) {
                    sys::err::raw( $prefix, "setting watcher for ($pid) ...\n" ) if DEBUG_SIGS;
                    push @{ $WAITPIDS{$pid} //=[] } => [
                        CALLER,
                        $callback
                    ];
                }
                else {
                    # the proc has died, so just call it ...
                    $callback->send_from(CALLER);
                }
            },
            timer => sub ($timeout, $callback) {
                sys::err::raw( $prefix, "setting timer for($timeout) ...\n" ) if DEBUG_SIGS;

                $timeout--; # subtrack one for this tick ...

                if ( $timeout <= 0 ) {
                    $callback->send_from(CALLER);
                }
                else {
                    push @{ $TIMERS{ $CURRENT_TICK + $timeout } //= [] } => [
                        CALLER,
                        $callback
                    ];
                }
            }
        };
    });

    $STATS {start} = time if STATS;

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

        $STATS {ticks} {$tick} {start} = time if STATS;

        local $CURRENT_TICK = $tick;

        if ( exists $TIMERS{ $tick } ) {
            my $alarms = delete $TIMERS{ $tick };
            foreach my $alarm ($alarms->@*) {
                my ($caller, $callback) = @$alarm;
                $callback->send_from( $caller );
            }
        }

        warn Dumper {
            msg              => 'Inbox before delivery',
            msg_inbox        => \@ELO::VM::MSG_INBOX,
        } if DEBUG_MSGS;

        my @inbox = @ELO::VM::MSG_INBOX;
        @ELO::VM::MSG_INBOX = ();

        $STATS {ticks} {$tick} {inbox} = scalar @inbox if STATS;

        while (@inbox) {
            my ($from, $msg) = (shift @inbox)->@*;

            my $active = $ELO::VM::PROCESS_TABLE{ $msg->pid };

            local $ELO::VM::CURRENT_PID    = $active->pid;
            local $ELO::VM::CURRENT_CALLER = $from;

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

        $STATS {ticks} {$tick} {end} = time if STATS;

        warn Dumper \%ELO::VM::PROCESS_TABLE if DEBUG_PROCS;
        warn Dumper \%TIMERS        if DEBUG_TIMERS;

        my @active_processes =
            grep !/^\d\d\d:\#/,    # ignore I/O pids
            grep $_ ne $start,     # ignore start pid
            grep $_ ne $INIT_PID,  # ignore init pid
            keys %ELO::VM::PROCESS_TABLE;

        warn Dumper {
            msg              => 'Active Procsses and Inbox after tick',
            active_processes => \@active_processes,
            msg_inbox        => \@ELO::VM::MSG_INBOX,
        } if DEBUG_MSGS;

        if ($should_exit) {
            $has_exited++;
            last;
        }

        # at least do one tick before shutting things down ...
        if ( $tick > 1 && scalar @active_processes == 0 && scalar(keys %TIMERS) == 0 ) {
            # loop one last time to flush any I/O
            if ( scalar @ELO::VM::MSG_INBOX == 0 ) {
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
                  keys %ELO::VM::PROCESS_TABLE;

    if ( @zombies ) {
        warn("GOT ZOMBIES: ", Dumper(\@zombies)) if DEBUG_LOOP;
        return;
    }

    if (STATS) {
        $STATS {end} = time;

        #print_stats( \%STATS );
        print_stats( \%STATS );

        #warn Dumper \%STATS;

    }

    return 1;
}

# XXX - put this into a module along with other similar stuff?
our $TERM_SIZE = (GetTerminalSize())[0];

sub print_stats ($stats) {
    state $line_prefix = '== (stats)';
    state $term_width = $TERM_SIZE - (length $line_prefix) - 2;

    state $graph_scale = 20;

    say "\n", BLUE (join ' ' => $line_prefix, ('=' x $term_width)), RESET;

    my $header = "| inbox | tick  | wallclock | graph (~ = 0.$graph_scale)";
    say CYAN(
        UNDERLINE($header . (" " x ($TERM_SIZE - length($header) - 1)))
    ), RESET;
    my $ticks = $stats->{ticks};
    my $total_ticks = 0;
    foreach my $tick ( sort { $a <=> $b } keys %$ticks ) {

        my $stat   = $ticks->{$tick};
        my $dur    = $stat->{end} - $stat->{start};
        my $dur_ms = ($dur * 1_000);

        $total_ticks += $dur;

        say(
            FAINT('| '), RESET,
            BLUE(sprintf ("@ %03d" => $stat->{inbox})), RESET,
            FAINT(' | '), RESET,
            CYAN(sprintf ("%-5d" => $tick)), RESET,
            FAINT(' | '), RESET,
            MAGENTA(sprintf("%6s ms" => sprintf ("%.2f" => $dur_ms))), RESET,
            FAINT(' | '), RESET,
            GREEN('~' x (int(($dur_ms * 100) / $graph_scale) || 1)), RESET,
        );
    }
    say(CYAN('-' x $TERM_SIZE), RESET);
    say(
        CYAN(sprintf("Elapsed ticks(%d) -> " => scalar keys %$ticks)), RESET,
        '[ ', (join ' / ' =>
            map { (RED($_).RESET) }
            (sprintf("ticks %.3f ms" => ($total_ticks  * 1_000))),
            (sprintf("loop %.3f ms" => (($stats->{end} - $stats->{start}) * 1_000))),
        ), RESET, ' ]',
    );
    say BLUE ('=' x $TERM_SIZE), RESET "\n";
}

sub _loop_log_line ( $fmt, $tick ) {
    state $init_pid_prefix = '('.$INIT_PID.')';
    state $term_width = $TERM_SIZE - (length $init_pid_prefix) - 2;

    sys::err::raw( FAINT
        (join ' ' => $init_pid_prefix,
            map { ('-' x ($term_width - length $_)) . " $_" }
                (sprintf $fmt, $tick)),
                    RESET "\n" );
}

1;

__END__

