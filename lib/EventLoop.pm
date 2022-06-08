package EventLoop;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Carp         'confess';
use Scalar::Util 'blessed';
use List::Util   ();
use Data::Dumper 'Dumper';

use Exporter 'import';

our @EXPORT = qw[
    match
    add_process

    timeout

    send_to
    recv_from
    return_to

    spawn

    sync
    await

    loop

    IN OUT ERR

    $CURRENT_PID
    $CURRENT_CALLER

    DEBUG
];

# flags

use constant INBOX  => 0;
use constant OUTBOX => 1;

use constant DEBUG => $ENV{DEBUG} // 0;

# stuff

## .. process info

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

sub add_process ($pid, $proto) {
    $processes{$pid} = $proto;
}

## ... sugar

sub IN  () { $IN  }
sub OUT () { $OUT }
sub ERR () { $ERR }

sub match ($msg, $table) {
    my ($action, $body) = @$msg;
    my $cb = $table->{$action} // die "No match for $action";
    $cb->($body);
}

sub timeout ($ticks, $callback) {
    [ spawn( '!timeout' ) => [ $ticks, $callback ]];
}

## ... message delivery

sub send_to ($pid, $msg, $from=undef) {
    $from //= $CURRENT_PID;
    push @msg_inbox => [ $from, $pid, $msg ];
}

sub recv_from ($pid=undef) {
    $pid //= $CURRENT_PID;
    my $msg = shift $processes{$pid}->[OUTBOX]->@*;
    return unless $msg;
    return $msg->[1];
}

sub return_to ($msg) {
    push @msg_outbox => [ $CURRENT_PID, $CURRENT_CALLER, $msg ];
}

## ... process creation

my $PID = 0;
sub spawn ($pid, $init=undef) {
    my $process = [ [], [], {}, $processes{$pid}->[-1] ];
    $pid = sprintf '%03d:%s' => ++$PID, $pid;
    $processes{ $pid } = $process;
    send_to( $pid, $init ) if $init;
    $pid;
}

## ... currency control

sub sync ($input, $output) {
    spawn( '!sync' => [ $input, $output ] );
}

sub await ($input, $output) {
    spawn( '!await' => [ $input, $output ] );
}

## ...

sub loop ( $MAX_TICKS, $pid ) {

    local $IN  = spawn( '!in' );
    local $OUT = spawn( '!out' );
    local $ERR = spawn( '!err' );

    # initialise ...
    send_to( main => 1, '(-1):init' );

    my $tick = 0;
    while ($tick < $MAX_TICKS) {
        $tick++;

        warn Dumper \@msg_inbox  if DEBUG >= 3;
        warn Dumper \@msg_outbox if DEBUG >= 1;

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

        my @active = map [ $_, $processes{$_}->@* ], sort { $a cmp $b } keys %processes;
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

        say "---------------------------- tick($tick)" if DEBUG;
    }

}

%processes = (
    '!err' => [
        [],[],
        {},
        sub ($env, $msg) {
            my $prefix = DEBUG ? "ERR ($CURRENT_CALLER) >> " : "ERR >> ";

            match $msg, +{
                printf => sub ($body) {
                    my ($fmt, @values) = @$body;
                    warn( $prefix, sprintf $fmt, @values, "\n" );
                },
                print => sub ($body) {
                    warn( $prefix, @$body, "\n" );
                }
            };
        },
    ],
    '!out' => [
        [],[],
        {},
        sub ($env, $msg) {
            my $prefix = DEBUG ? "OUT ($CURRENT_CALLER) >> " : "OUT >> ";

            match $msg, +{
                printf => sub ($body) {
                    my ($fmt, @values) = @$body;
                    say( $prefix, sprintf $fmt, @values );
                },
                print => sub ($body) {
                    say( $prefix, @$body );
                }
            };
        },
    ],
    '!in' => [
        [],[],
        {},
        sub ($env, $msg) {
            my $prefix = DEBUG ? "IN ($CURRENT_CALLER) << " : "IN << ";

            match $msg, +{
                read => sub ($body) {
                    my ($prompt) = @$body;
                    $prompt //= '';

                    print $prefix, $prompt;
                    my $input = <>;
                    chomp $input;
                    return_to( $input );
                }
            };
        },
    ],
    '!timeout' => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($timer, $event, $caller) = @$msg;

            if ( $timer == 0 ) {
                send_to( $ERR => [ print => ["*/ !timeout! /* : DONE"] ]) if DEBUG;
                send_to( @$event, $caller );
            }
            else {
                send_to( $ERR => [ print => ["*/ !timeout! /* : counting down $timer"] ] ) if DEBUG;
                send_to( $CURRENT_PID => [ $timer - 1, $event, $caller // $CURRENT_CALLER ] );
            }
        },
    ],
    '!await' => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($command, $callback) = @$msg;

            my $message = recv_from;

            if (defined $message) {
                send_to( $ERR => [ print => ["*/ !await /* : got message($message)"]]) if DEBUG;
                push $callback->[1]->[1]->@*, $message;
                send_to( @$callback );
            }
            else {
                send_to( $ERR => [ print => ["*/ !await /* : no messages"]]) if DEBUG;
                send_to( @$command );
                send_to( $CURRENT_PID => [ $command, $callback ]);
            }
        }
    ],
    '!sync' => [
        [],[],
        {},
        sub ($env, $msg) {
            if ( scalar @$msg == 2 ) {
                my ($command, $callback) = @$msg;
                send_to( $ERR => [ print => ["*/ !sync /* : sending initial message"]]) if DEBUG;
                #warn Dumper $command;
                send_to( @$command );
                send_to( $CURRENT_PID => [ $callback ] );
            }
            else {
                my ($callback) = @$msg;

                my $message = recv_from;

                if (defined $message) {
                    send_to( $ERR => [ print => ["*/ !sync /* : got message($message)"]]) if DEBUG;
                    #warn Dumper $callback;
                    push $callback->[1]->[1]->@*, $message;
                    send_to( @$callback );
                }
                else {
                    send_to( $ERR => [ print => ["*/ !sync /* : no messages"]]) if DEBUG;
                    send_to( $CURRENT_PID => [ $callback ]);
                }
            }
        }
    ],
);

1;

__END__

=pod

=cut
