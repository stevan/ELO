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

use Exporter 'import';

our @EXPORT = qw[
    msg

    recv_from
    return_to

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

# FIXME: remove these
use constant INBOX  => 0;
use constant OUTBOX => 1;

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

# NOTE : this needs to be here because of recv_from,
# if we remove that, or move that, we can move this
# down lower with the spawn/despawn code (where it belongs)

## ----------------------------------------------------------------------------
## Messages and delivery
## ----------------------------------------------------------------------------

my @msg_inbox;
my @msg_outbox;

sub _send_to ($msg) {
    push @msg_inbox => [ $CURRENT_PID, $msg ];
}

sub _send_from ($from, $msg) {
    push @msg_inbox => [ $from, $msg ];
}

sub recv_from () {
    my $msg = shift $PROCESS_TABLE{$CURRENT_PID}->[OUTBOX]->@*;
    return unless $msg;
    return $msg->[1];
}

sub return_to ($msg) {
    push @msg_outbox => [ $CURRENT_PID, $CURRENT_CALLER, $msg ];
}

## messages ..

sub msg        ($pid, $action, $msg) { bless [$pid, $action, $msg] => 'SAM::Msg' }
sub msg::curry ($pid, $action, $msg) { bless [$pid, $action, $msg] => 'SAM::Msg::Curryable' }

package SAM::Msg {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    sub pid    ($self) { $self->[0] }
    sub action ($self) { $self->[1] }
    sub body   ($self) { $self->[2] }

    sub curry ($self, @args) {
        msg::curry(@$self)->curry( @args )
    }

    sub send ($self) { SAM::_send_to( $self ); $self }
    sub send_from ($self, $caller) { SAM::_send_from($caller, $self); $self }

    sub return_or_send ($self, $wantarray) {
        if (not defined $wantarray) {
            # foo(); -- will send message, return nothing
            $self->send;
            return;
        }
        elsif (not $wantarray) {
            # my $foo_pid = foo(); -- will send message, return msg pid
            $self->send;
            return $self->pid
        }
        else {
            # sync(foo(), bar()); -- will just return message
            return $self;
        }
    }
}

package SAM::Msg::Curryable {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    our @ISA; BEGIN { @ISA = ('SAM::Msg') };

    sub curry ($self, @args) {
        my ($pid, $action, $body) = @$self;
        bless [ $pid, $action, [ @$body, @args ] ] => 'SAM::Msg::Curryable';
    }
}

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

sub sys::despawn_all () {
    foreach my $pid (keys %to_be_despawned) {
        @msg_inbox  = grep { $_->[1]->pid ne $pid } @msg_inbox;
        @msg_outbox = grep { $_->[1] ne $pid } @msg_outbox;

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

        warn Dumper \@msg_inbox  if DEBUG >= 4;
        warn Dumper \@msg_outbox if DEBUG >= 4;

        my $has_inbox_messages  = !! scalar @msg_inbox;
        my $has_outbox_messages = !! scalar @msg_outbox;

        # deliver all the messages in the queue
        while (@msg_inbox) {
            my $next = shift @msg_inbox;
            #warn Dumper $next;
            my ($from, $msg) = $next->@*;
            unless (exists $PROCESS_TABLE{$msg->pid}) {
                warn "Got message for unknown pid(".$msg->pid.")";
                next;
            }
            push $PROCESS_TABLE{$msg->pid}->[INBOX]->@* => [ $from, $msg ];
        }

        # deliver all the messages in the queue
        while (@msg_outbox) {
            my $next = shift @msg_outbox;

            my $from = shift $next->@*;
            my ($to, $m) = $next->@*;
            unless (exists $PROCESS_TABLE{$to}) {
                warn "Got message for unknown pid($to)";
                next;
            }
            push $PROCESS_TABLE{$to}->[OUTBOX]->@* => [ $from, $m ];
        }

        #
        if ( DEBUGGER ) {

            my @pids = sort keys %PROCESS_TABLE;

            my $longest_pid = max( map length, @pids );

            warn FAINT '-' x $TERM_SIZE, RESET "\n";
            warn FAINT ON_MAGENTA " << MESSAGES >> " . RESET "\n";
            warn FAINT '-' x $TERM_SIZE, RESET "\n";
            foreach my $pid ( @pids ) {
                my @inbox  = $PROCESS_TABLE{$pid}->[INBOX]->@*;
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

        sys::despawn_all();

        warn Dumper \%PROCESS_TABLE if DEBUG >= 4;

        my @active_processes =
            grep !/^\d\d\d:\#/,     # ignore I/O pids
            grep $_ ne $start,     # ignore start pid
            grep $_ ne $INIT_PID,  # ignore init pid
            keys %PROCESS_TABLE;

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

=cut
