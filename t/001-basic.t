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

sub return_to ($msg) {
    push @msg_outbox => [ $CURRENT_PID, $CURRENT_CALLER, $msg ];
}

my $PID = 0;
sub spawn ($pid, $init=undef) {
    my $process = [ [], [], {}, $processes{$pid}->[-1] ];
    $pid = sprintf '%03d:%s' => ++$PID, $pid;
    $processes{ $pid } = $process;
    send_to( $pid, $init ) if $init;
    $pid;
}

sub sync ($input, $output) {
    spawn( pipe => [ $input, $output ] );
}

sub await ($input, $output) {
    spawn( wait => [ $input, $output ] );
}

sub loop ( $MAX_TICKS ) {

    my $tick = 0;
    while ($tick < $MAX_TICKS) {
        $tick++;

        warn Dumper \@msg_inbox  if DEBUG >= 3;
        warn Dumper \@msg_outbox if DEBUG >= 1;

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

            }
        }

        say "---------------------------- tick($tick)" if DEBUG;
    }

}

%processes = (
    out => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($action, $body) = @$msg;

            my $prefix = "OUT >> ";
               $prefix = "OUT ($CURRENT_CALLER) >> " if DEBUG;

            if ( $action eq 'printf' ) {
                my ($fmt, @values) = @$body;
                say( $prefix, sprintf $fmt, @values );
            }
            elsif ( $action eq 'print' ) {
                say( $prefix, @$body );
            }
        },
    ],
    in => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($action, $body) = @$msg;

            die unless $action eq 'read';

            my ($prompt) = @$body;
            $prompt //= '';

            my $prefix = "IN << ";
               $prefix = "IN ($CURRENT_CALLER) << " if DEBUG;

            print $prefix, $prompt;
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
                send_to( out => [ print => ["!timeout! DONE"] ]) if DEBUG;
                send_to( @$event, $caller );
            }
            else {
                send_to( out => [ print => ["!timeout! counting down $timer"] ] ) if DEBUG;
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

            if (defined $message) {
                send_to( out => [ print => ["*/ wait /* : got message($message)"]]) if DEBUG;
                push $callback->[1]->[1]->@*, $message;
                send_to( @$callback );
            }
            else {
                send_to( out => [ print => ["*/ wait /* : no messages"]]) if DEBUG;
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
                send_to( out => [ print => ["*/ pipe /* : sending initial message"]]) if DEBUG;
                send_to( @$command );
                send_to( $CURRENT_PID => [ $callback ] );
            }
            else {
                my ($callback) = @$msg;

                my $message = recv_from;

                if (defined $message) {
                    send_to( out => [ print => ["*/ pipe /* : got message($message)"]]) if DEBUG;
                    #warn Dumper $callback;
                    push $callback->[1]->[1]->@*, $message;
                    send_to( @$callback );
                }
                else {
                    send_to( out => [ print => ["*/ pipe /* : no messages"]]) if DEBUG;
                    send_to( $CURRENT_PID => [ $callback ]);
                }
            }
        }
    ],
    env => [
        [],[],
        {},
        sub ($env, $msg) {
            my ($action, $body) = @$msg;
            if ( $action eq 'get' ) {
                my ($key) = @$body;
                if ( exists $env->{$key} ) {
                    send_to( out => [ print => ["fetching {$key}"]]) if DEBUG;
                    return_to( $env->{$key} );
                }
                else {
                    send_to( out => [ print => ["not found {$key}"]]) if DEBUG;
                }
            }
            if ( $action eq 'set' ) {
                my ($key, $value) = @$body;
                send_to( out => [ print => ["storing $key => $value"]]) if DEBUG;
                $env->{$key} = $value;

                send_to( out => [ print => ["ENV{ ".(join ', ' => map { join ' => ' => $_, $env->{$_} } keys %$env)." }"]])
                    if DEBUG;
            }
        },
    ],
    main => [
        [],[],
        {},
        sub ($env, $msg) {
            send_to( out => [ print => ["-> main starting ..."]] );

            my $e1 = spawn( 'env' );
            my $e2 = spawn( 'env' );

            # ...

            sync(
                [ in => [ read => ['foo: '] ]],
                [ $e1,  [ set  => ['foo']   ]] );

            sync(
                [ in => [ read => ['bar: '] ]],
                [ $e1,  [ set  => ['bar']   ]] );

            sync(
                [ in => [ read => ['baz: '] ]],
                [ $e1,  [ set  => ['baz']   ]] );

            # ...

            sync(
                [ timeout => [ 2, [ $e1 => [ get => ['baz'] ]]]],
                [ $e2, [ set => ['baz'] ]]);

            sync(
                [ timeout => [ 3, [ $e1 => [ get => ['bar'] ]]]],
                [ $e2, [ set => ['bar'] ]]);

            sync(
                [ timeout => [ 4, [ $e1 => [ get => ['foo'] ]]]],
                [ $e2, [ set => ['foo'] ]]);

            # ...

            await( [ $e2 => [ get => ['foo'] ]], [ out => [ printf => [ 'foo(%s)' ] ]] );
            await( [ $e2 => [ get => ['bar'] ]], [ out => [ printf => [ 'bar(%s)' ] ]] );
            await( [ $e2 => [ get => ['baz'] ]], [ out => [ printf => [ 'baz(%s)' ] ]] );

        },
    ],
);

# initialise ...
send_to( main => 1 );
# loop ...
loop( 20 );

done_testing;
