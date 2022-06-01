#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;

#use ok 'EventLoop';
#use ok 'EventLoop::Handler';

my $PID       = 0;
my $MAX_TICKS = 10;

my @msg_queue;

sub send_to ($pid, $msg) {
    #say "SENT($pid, $msg)";
    push @msg_queue => [ $pid, $msg ];
}

my %processes = (
    ping => [
        [],
        {},
        sub ($env, $msg) {
            say( "/ping/ => $msg" );
            send_to( pong => $msg + 1 );
        },
    ],
    pong => [
        [],
        {},
        sub ($env, $msg) {
            say( "\\pong\\ => $msg" );
            send_to( ping => $msg + 1 );
        },
    ],
    main => [
        [],
        {},
        sub ($env, $msg) {
            say( "main starting ..." );
            send_to( ping => $msg * 0 );
            send_to( ping => $msg * 10 );
            send_to( ping => $msg * 100 );
        },
    ],
);

# initialise ...
send_to( main => 1 );

# loop ...
my $tick = 0;
while ($tick < $MAX_TICKS) {
    $tick++;

    # deliver all the messages in the queue
    while (@msg_queue) {
        my $next = shift @msg_queue;
        my ($pid, $m) = $next->@*;
        push $processes{$pid}->[0]->@* => $m;
    }

    my @active = values %processes;
    while (@active) {
        my $active = shift @active;
        my ($mbox, $env, $f) = $active->@*;

        if ( $mbox->@* ) {
            $f->($env, shift $mbox->@* );
            # if we still have messages
            if ( $mbox->@* ) {
                # handle them in the next loop ...
                push @active => $active;
            }
        }
    }

    say "---------------------------- tick($tick)";
}



done_testing;
