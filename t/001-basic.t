#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

use constant DEBUG => $ENV{DEBUG} // 0;

use constant INBOX  => 0;
use constant OUTBOX => 1;

my @msg_inbox;
my @msg_outbox;
my %processes;

our $CURRENT_PID;
our $CURRENT_CALLER;

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

my $PID = 0;
sub spawn ($pid, $init=undef) {
    my $process = [ [], [], {}, $processes{$pid}->[-1] ];
    $pid = sprintf '%03d:%s' => ++$PID, $pid;
    $processes{ $pid } = $process;
    send_to( $pid, $init ) if $init;
    $pid;
}

sub return_to ($msg) {
    push @msg_outbox => [ $CURRENT_PID, $CURRENT_CALLER, $msg ];
}

sub loop ( $MAX_TICKS ) {

    my $tick = 0;
    while ($tick < $MAX_TICKS) {
        $tick++;

        #warn Dumper \@msg_inbox;
        warn Dumper \@msg_outbox;

        # deliver all the messages in the queue
        while (@msg_inbox) {
            my $next = shift @msg_inbox;

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

                # if we still have messages
                #if ( $inbox->@* ) {
                #    # handle them in the next loop ...
                #    push @active => $active;
                #}
            }
        }

        say "---------------------------- tick($tick)";
    }

}

%processes = (
    out => [
        [],[],
        {},
        sub ($env, $msg) {

            my $prefix = "OUT >> ";
               $prefix = "OUT ($CURRENT_CALLER) >> " if DEBUG;

            if ( ref $msg ) {
                my ($fmt, @msgs) = @$msg;
                say( $prefix, sprintf $fmt, @msgs );
            }
            else {
                say( $prefix, $msg );
            }
        },
    ],
    in => [
        [],[],
        {},
        sub ($env, $msg) {
            print $msg;
            my $input = <>;
            chomp $input;
            return_to( $input );
        },
    ],
    timeout => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($timer, $event, $caller) = @$msg;
            if ( $timer == 0 ) {
                send_to( out => "!timeout! DONE") if DEBUG;
                send_to( @$event, $caller );
            }
            else {
                send_to( out => "!timeout! counting down $timer" ) if DEBUG;
                send_to( timeout => [ $timer - 1, $event, $caller // $CURRENT_CALLER ] );
            }
        },
    ],
    wait => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($command, $callback) = @$msg;

            my $message = recv_from;

            if ($message) {
                send_to( out => "*/ wait /* : got message($message)") if DEBUG;
                push $callback->[1]->@*, $message;
                send_to( @$callback );
            }
            else {
                send_to( out => "*/ wait /* : no messages") if DEBUG;
                send_to( @$command );
                send_to( $CURRENT_PID => [ $command, $callback ]);
            }
        }
    ],
    pipe => [
        [],[],
        {},
        sub ($env, $msg) {
            if ( scalar @$msg == 2 ) {
                my ($command, $callback) = @$msg;
                send_to( out => "*/ pipe /* : sending initial message") if DEBUG;
                send_to( @$command );
                send_to( $CURRENT_PID => [ $callback ] );
            }
            else {
                my ($callback) = @$msg;

                my $message = recv_from;

                if ($message) {
                    send_to( out => "*/ pipe /* : got message($message)") if DEBUG;
                    push $callback->[1]->@*, $message;
                    send_to( @$callback );
                }
                else {
                    send_to( out => "*/ pipe /* : no messages") if DEBUG;
                    send_to( $CURRENT_PID => [ $callback ]);
                }
            }
        }
    ],
    env => [
        [],[],
        {},
        sub ($env, $msg) {
            if ( scalar @$msg == 1 ) {
                my ($key) = @$msg;
                if ( exists $env->{$key} ) {
                    send_to( out => "fetching {$key}") if DEBUG;
                    return_to( $env->{$key} );
                }
                else {
                    send_to( out => "not found {$key}") if DEBUG;
                }
            }
            elsif ( scalar @$msg == 2 ) {
                my ($key, $value) = @$msg;
                send_to( out => "storing $key => $value") if DEBUG;
                $env->{$key} = $value;

                send_to( out => "ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }")
                    if DEBUG;
            }
        },
    ],
    main => [
        [],[],
        {},
        sub ($env, $msg) {
            send_to( out => "-> main starting ..." );

            my $e1 = spawn( 'env' );
            my $e2 = spawn( 'env' );

            # ...

            spawn( pipe => [
                [ in => 'foo > ' ],
                [ $e1, [ 'foo' ]]
            ]);

            spawn( pipe => [
                [ in => 'bar > ' ],
                [ $e1, [ 'bar' ]]
            ]);

            spawn( pipe => [
                [ in => 'baz > ' ],
                [ $e1, [ 'baz' ]]
            ]);

            # ...

            spawn( pipe => [
                [ timeout => [ 2, [ $e1 => [ 'baz' ]]]],
                [ $e2, [ 'baz' ]]
            ]);

            spawn( pipe => [
                [ timeout => [ 3, [ $e1 => [ 'bar' ]]]],
                [ $e2, [ 'bar' ]]
            ]);

            spawn( pipe => [
                [ timeout => [ 4, [ $e1 => [ 'foo' ]]]],
                [ $e2, [ 'foo' ]]
            ]);

            # ...

            spawn( wait => [
                [ $e2 => [ 'baz' ]],
                [ out => [ 'baz(%s)' ]]
            ]);

            spawn( wait => [
                [ $e2 => [ 'bar' ]],
                [ out => [ 'bar(%s)' ]]
            ]);

            spawn( wait => [
                [ $e2 => [ 'foo' ]],
                [ out => [ 'foo(%s)' ]]
            ]);

        },
    ],
);

# initialise ...
send_to( main => 1 );
# loop ...
loop( 20 );

done_testing;
