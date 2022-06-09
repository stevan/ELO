package EventLoop;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';

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

sub despawn ($pid) {
    @msg_inbox  = grep { $_->[1] ne $pid } @msg_inbox;
    @msg_outbox = grep { $_->[1] ne $pid } @msg_outbox;

    delete $processes{ $pid };
}

## ... currency control

sub timeout ($ticks, $callback) {
    my @args = (spawn( '!timeout' ), start => [ $ticks, $callback ]);
    defined wantarray
        ? \@args
        : send_to( @args );
}

sub sync ($input, $output) {
    my @args = ( spawn( '!sync' ), send => [ $input, $output ] );
    defined wantarray
        ? \@args
        : send_to( @args );
}

sub await ($input, $output) {
    my @args = ( spawn( '!await' ), send => [ $input, $output ] );
    defined wantarray
        ? \@args
        : send_to( @args );
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

    local $IN  = spawn( '!in' );
    local $OUT = spawn( '!out' );
    local $ERR = spawn( '!err' );

    # initialise ...
    my $start = spawn( $start_pid );

    send_from( $INIT_PID, $start => '_' => [] );

    say FAINT '('.$INIT_PID.')', ('-' x 50), "start", RESET if DEBUG;

    my $tick = 0;
    while ($tick < $MAX_TICKS) {
        say FAINT '('.$INIT_PID.')', ('-' x 50), "tick($tick)", RESET if DEBUG;

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

        warn Dumper \%processes if DEBUG >= 3;
    }

    if (DEBUG) {
        warn Dumper [ keys %processes ];
    }

    return 1;
}

## create the core actors

my %INDENTS;

actor '!err' => sub ($env, $msg) {
    my $prefix = DEBUG
        ? ON_RED "ERR ($CURRENT_CALLER) !!". RESET " "
        : ON_RED "ERR !!". RESET " ";

    match $msg, +{
        printf => sub ($body) {
            my ($fmt, $values, $caller) = @$body;

            if ($caller) {
                $INDENTS{ $CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $CURRENT_CALLER }).'> '
                    . RESET $prefix;
            }

            warn( $prefix, (sprintf $fmt, @$values), " from($caller)\n" );
        },
        print => sub ($body) {
            my ($msg, $caller) = @$body;

            if ($caller) {
                $INDENTS{ $CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $CURRENT_CALLER }).'> '
                    . RESET $prefix;
            }

            warn( $prefix, $msg, " from($caller)\n" );
        }
    };
};

actor '!out' => sub ($env, $msg) {
    my $prefix = DEBUG
        ? ON_GREEN "OUT ($CURRENT_CALLER) >>". RESET " "
        : ON_GREEN "OUT >>". RESET " ";

    match $msg, +{
        printf => sub ($body) {
            my ($fmt, @values) = @$body;
            say( $prefix, sprintf $fmt, @values );
        },
        print => sub ($body) {
            say( $prefix, @$body );
        }
    };
};

actor '!in' => sub ($env, $msg) {
    my $prefix = DEBUG
        ? ON_CYAN "IN ($CURRENT_CALLER) <<". RESET " "
        : ON_CYAN "IN <<". RESET " ";

    match $msg, +{
        read => sub ($body) {
            my ($prompt) = @$body;
            $prompt //= '';

            print( $prefix, $prompt );
            my $input = <>;
            chomp $input;
            return_to( $input );
        }
    };
};

## controls ...

actor '!timeout' => sub ($env, $msg) {

    match $msg, +{
        start => sub ($body) {
            my ($timer, $event) = @$body;
            err::log( "*/ !timeout! /* : starting $timer" ) if DEBUG;
            send_to( $CURRENT_PID => countdown => [ $timer - 1, $event, $CURRENT_CALLER ] );
        },
        countdown => sub ($body) {
            my ($timer, $event, $caller) = @$body;

            if ( $timer == 0 ) {
                err::log( "*/ !timeout! /* : timer DONE", $caller) if DEBUG;
                send_from( $caller, @$event );
                despawn( $CURRENT_PID );
            }
            else {
                err::log("*/ !timeout! /* : counting down $timer", $caller ) if DEBUG;
                send_to( $CURRENT_PID => countdown => [ $timer - 1, $event, $caller ] );
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
            return_to $val;
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

actor '!sequence' => sub ($env, $msg) {
    match $msg, +{
        next => sub ($body) {
            if ( my $statement = shift @$body ) {
                err::log("*/ !sequence /* calling statement, ".(scalar @$body)." remain" ) if DEBUG;
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

1;

__END__

=pod

=cut
