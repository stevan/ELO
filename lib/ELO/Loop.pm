package ELO::Loop;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Carp            'croak';
use Scalar::Util    'blessed';
use List::Util      'max';
use Data::Dumper    'Dumper';
use Time::HiRes     'time';
use Term::ANSIColor ':constants';
use Term::ReadKey   'GetTerminalSize';

use ELO::VM qw[ $INIT_PID ];
use ELO::Actors; # one use of `match` in the INIT_PID setup
use ELO::Core::ProcessRecord;
use ELO::Debug;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use constant STATS => $ENV{STATS} // 0;

use parent 'UNIVERSAL::Object';
use slots (
    process_table => sub {}, # HASH< $pid > = ELO::Core::ProcessRecord
    start         => sub {},
    max_ticks     => sub {},
    # private
    _tick      => sub { 0 },
    _msg_inbox => sub { +[] }, # ARRAY [ [ $caller, $msg ], ... ]
    _timers    => sub { +{} }, # HASH< $tick_to_fire_at > = [ [ $caller, $msg ], ... ]
    _waitpids  => sub { +{} }, # HASH< $pid > = [ [ $caller, $msg ], ... ]
    _stats     => sub { +{} },
    # ...
    _start_pid   => sub {}, # the $pid created by calling start
    _active_pid  => sub {}, # the $pid that is currently being called with $msg
    _caller_pid  => sub {}, # the $pid that sent the current $msg
    # ...
    _should_exit => sub { 0 }, # are we almost ready to exit, just need to flush I/O
    _has_exited  => sub { 0 }, # we are ready to exit cleanly now
);

sub enqueue_msg ( $self, $msg, $from=undef ) {
    push $self->{_msg_inbox}->@* => [ $from // $self->{_active_pid}, $msg ];
}

## ----------------------------------------------------------------------------

sub run_loop ( $self ) {
    $self->create_init_pid;

    $self->{_stats}->{start} = time if STATS;
    $self->create_start_pid;
    debug_loop_log("start(%d)", $self->{_tick}) if DEBUG_LOOP;

    while ($self->{_tick} < $self->{max_ticks}) {
        $self->{_tick}++;
        debug_loop_log("tick(%d)", $self->{_tick}) if DEBUG_LOOP;
        $self->handle_timers;
        $self->handle_inbox;
        $self->handle_waitpids;
        last if $self->should_exit;
    }

    $self->exit_loop;

    if (STATS) {
        $self->{_stats}->{end} = time;
        $self->display_stats;
    }

    return 1;
}

## ----------------------------------------------------------------------------

sub create_init_pid ($self) {
        # initialise the system pid singleton
    $self->{process_table}->{ $INIT_PID } //= ELO::Core::ProcessRecord->new($INIT_PID, {}, sub ($env, $msg) {
        my $prefix = ON_MAGENTA "SYS (".$self->{_caller_pid}.") ::". RESET " ";

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
                    push @{ $self->{_waitpids}->{$pid} //=[] } => [
                        $self->{_caller_pid},
                        $callback
                    ];
                }
                else {
                    # the proc has died, so just call it ...
                    $callback->send_from($self->{_caller_pid});
                }
            },
            timer => sub ($timeout, $callback) {
                sys::err::raw( $prefix, "setting timer for($timeout) ...\n" ) if DEBUG_SIGS;

                $timeout--; # subtrack one for this tick ...

                if ( $timeout <= 0 ) {
                    $callback->send_from($self->{_caller_pid});
                }
                else {
                    push @{ $self->{_timers}->{ $self->{_tick} + $timeout } //= [] } => [
                        $self->{_caller_pid},
                        $callback
                    ];
                }
            }
        };
    });
}

sub create_start_pid ( $self ) {
    # initialise ...
    $self->{_start_pid} = proc::spawn( $self->{start} );
    $self->enqueue_msg(
        ELO::Core::Message->new( $self->{_start_pid} => '_' => [] ),
        $INIT_PID
    );
}

sub handle_timers ( $self ) {
    if ( exists $self->{_timers}->{ $self->{_tick} } ) {
        my $alarms = delete $self->{_timers}->{ $self->{_tick} };
        foreach my $alarm ($alarms->@*) {
            my ($caller, $callback) = @$alarm;
            $callback->send_from( $caller );
        }
    }
}

sub handle_inbox ( $self ) {

    warn Dumper {
        msg              => 'Inbox before delivery',
        msg_inbox        => $self->{_msg_inbox},
    } if DEBUG_MSGS;

    my @inbox = $self->{_msg_inbox}->@*;
    $self->{_msg_inbox}->@* = ();

    $self->{_stats}->{ticks}->{$self->{_tick}}->{start} = time if STATS;
    $self->{_stats}->{ticks}->{$self->{_tick}}->{inbox} = scalar @inbox if STATS;

    while (@inbox) {
        my ($from, $msg) = (shift @inbox)->@*;

        my $active = $self->{process_table}->{ $msg->pid };

        if (DEBUG_CALLS && !$active) {
            say BLUE " !!! no pid(",
                    CYAN $msg->pid, RESET,
                BLUE ") for msg(",
                    CYAN $msg->to_string, RESET,
                BLUE ") skipping ...",
            RESET;
        }
        next unless $active;

        local $ELO::VM::CURRENT_PID    = $self->{_active_pid} = $active->pid;
        local $ELO::VM::CURRENT_CALLER = $self->{_caller_pid} = $from;

        say BLUE " >>> calling : ", CYAN $msg->to_string, RESET
            if DEBUG_CALLS;

        $active->actor->($active->env, $msg);

        $self->{_active_pid} = undef;
        $self->{_caller_pid} = undef;
    }

    $self->{_stats}->{ticks}->{$self->{_tick}}->{end} = time if STATS;
}

sub handle_waitpids ( $self  ) {
    proc::despawn_all_exiting_pids(sub ($pid) {
        if ( exists $self->{_waitpids}->{$pid} ) {
            my $watchers = delete $self->{_waitpids}->{$pid};
            foreach my $watcher ($watchers->@*) {
                my ($caller, $callback) = @$watcher;
                $callback->send_from( $caller );
            }
        }
    });
}

sub should_exit ( $self ) {

    warn Dumper $self->{process_table} if DEBUG_PROCS;
    warn Dumper $self->{_timers}       if DEBUG_TIMERS;

    my @active_processes =
        grep !/^\d\d\d:\#/,    # ignore I/O pids
        grep $_ ne $self->{_start_pid}, # ignore start pid
        grep $_ ne $INIT_PID,  # ignore init pid
        keys $self->{process_table}->%*;

    warn Dumper {
        msg              => 'Active Procsses and Inbox after tick',
        active_processes => \@active_processes,
        msg_inbox        => $self->{_msg_inbox},
    } if DEBUG_MSGS;

    if ($self->{_should_exit}) {
        $self->{_has_exited}++;
        return 1;
    }

    # at least do one tick before shutting things down ...
    if ( $self->{_tick} > 1
            && scalar @active_processes == 0
                && scalar(keys $self->{_timers}->%*) == 0
    ) {
        # loop one last time to flush any I/O
        if ( scalar $self->{_msg_inbox}->@* == 0 ) {
            $self->{_has_exited}++;
            return 1;
        }
        else {
            debug_loop_log("flushing(%d)", $self->{_tick}) if DEBUG_LOOP;
            $self->{_should_exit}++;
        }
    }

    return 0;
}

sub exit_loop ( $self ) {
    warn Dumper $self->{_waitpids} if DEBUG_WAITPIDS;

    if ( $self->{_has_exited} ) {
        debug_loop_log("exit(%d)", $self->{_tick}) if DEBUG_LOOP;
    } else {
        debug_loop_log("halt(%d)", $self->{_tick}) if DEBUG_LOOP;
    }

    my @zombies = grep !/^\d\d\d:\#/,             # ignore I/O pids
                  grep $_ ne $self->{_start_pid}, # ignore start pid
                  grep $_ ne $INIT_PID,           # ignore init pid
                  keys $self->{process_table}->%*;

    if ( @zombies ) {
        warn("GOT ZOMBIES: ", Dumper(\@zombies)) if DEBUG_LOOP;
    }
}

my $TERM_SIZE = (GetTerminalSize())[0];

sub display_stats ( $self ) {

    state $line_prefix = '== (stats)';
    state $term_width = $TERM_SIZE - (length $line_prefix) - 2;

    state $graph_scale = 20;

    say "\n", BLUE (join ' ' => $line_prefix, ('=' x $term_width)), RESET;

    my $header = "| inbox | tick  | wallclock | graph (~ = 0.$graph_scale)";
    say CYAN(
        UNDERLINE($header . (" " x ($TERM_SIZE - length($header) - 1)))
    ), RESET;
    my $stats = $self->{_stats};
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

sub debug_loop_log ( $fmt, $tick ) {
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

