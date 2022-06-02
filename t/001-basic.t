#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use List::Util 'first';
use Data::Dumper;

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

sub return_to ($msg) {
    push @msg_outbox => [ $CURRENT_PID, $CURRENT_CALLER, $msg ];
}

sub recv_from ($pid=undef) {
    $pid //= $CURRENT_PID;
    shift $processes{$pid}->[OUTBOX]->@*
}

sub loop ( $MAX_TICKS ) {

    my $tick = 0;
    while ($tick < $MAX_TICKS) {
        $tick++;

        #warn Dumper \@msg_inbox;
        #warn Dumper \@msg_outbox;

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

        my @active = map [ $_, $processes{$_}->@* ], keys %processes;
        while (@active) {
            my $active = shift @active;

            my ($pid, $inbox, $outbox, $env, $f) = $active->@*;

            if ( $inbox->@* ) {

                my ($from, $msg) = @{ shift $inbox->@* };

                local $CURRENT_PID    = $pid;
                local $CURRENT_CALLER = $from;

                $f->($env, $msg);

                # if we still have messages
                if ( $inbox->@* ) {
                    # handle them in the next loop ...
                    push @active => $active;
                }
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
            say( "OUT => $msg" );
        },
    ],
    timeout => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($timer, $event, $caller) = @$msg;
            if ( $timer == 0 ) {
                send_to( out => "!timeout! DONE");
                send_to( @$event, $caller );
            }
            else {
                send_to( out => "!timeout! counting down $timer" );
                send_to( timeout => [ $timer - 1, $event, $caller // $CURRENT_CALLER ] );
            }
        },
    ],
    env => [
        [],[],
        {},
        sub ($env, $msg) {
            if ( scalar @$msg == 1 ) {
                my ($key) = @$msg;
                send_to( out => "fetching {$key}");
                return_to( $env->{$key} );
            }
            elsif ( scalar @$msg == 2 ) {
                my ($key, $value) = @$msg;
                send_to( out => "storing $key => $value");
                $env->{$key} = $value;

                send_to( out => "ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }");
            }
        },
    ],
    select => [
        [], [],
        {},
        sub ($env, $msg) {

            if ( scalar @$msg == 2 ) {
                my ($command, $callback) = @$msg;
                send_to( @$command );
                send_to( select => [ $callback ] );
            }
            else {
                my ($callback) = @$msg;

                my $envelope = recv_from;

                if ($envelope) {

                    my $sender_pid = shift @$envelope;
                    my $message    = shift @$envelope;

                    send_to( out => "*/ select /* : got message($message) for pid($sender_pid)");
                    send_to( @$callback, $message );
                }
                else {
                    send_to( out => "*/ select /* : no messages");
                    send_to( select => [ $callback ]);
                }
            }
        }
    ],
    main => [
        [],[],
        {},
        sub ($env, $msg) {
            send_to( out => "->main starting ..." );
            send_to( env => [ foo => 10 ] );
            send_to( env => [ bar => 20 ] );
            send_to( select => [
                [ timeout => [ 5, [ env => [ 'foo' ]]]],
                [ 'out' ]
            ] );
            send_to( select => [
                [ timeout => [ 3, [ env => [ 'bar' ]]]],
                [ 'out' ]
            ] );
        },
    ],
);

# initialise ...
send_to( main => 1 );
# loop ...
loop( 50 );

done_testing;
