#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;

#use ok 'EventLoop';
#use ok 'EventLoop::Handler';

my @msg_queue;

sub send_to ($pid, $msg) {
    push @msg_queue => [ $pid, $msg ];
}

sub loop ( $MAX_TICKS, $process_table ) {

    my $tick = 0;
    while ($tick < $MAX_TICKS) {
        $tick++;

        # deliver all the messages in the queue
        while (@msg_queue) {
            my $next = shift @msg_queue;
            my ($pid, $m) = $next->@*;
            push $process_table->{$pid}->[0]->@* => $m;
        }

        my @active = values %$process_table;
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

}

my %processes = (
    out => [
        [],
        {},
        sub ($env, $msg) {
            say( "OUT => $msg" );
        },
    ],
    alarm => [
        [],
        {},
        sub ($env, $msg) {
            my ($timer, $event) = @$msg;
            if ( $timer == 0 ) {
                send_to( out => "!alarm! DONE");
                send_to( @$event );
            }
            else {
                send_to( out => "!alarm! counting down $timer" );
                send_to( alarm => [ $timer - 1, $event ] );
            }
        },
    ],
    ping => [
        [],
        {},
        sub ($env, $msg) {
            send_to( out => "/ping/ => $msg" );
            send_to( pong => $msg + 1 );
        },
    ],
    pong => [
        [],
        {},
        sub ($env, $msg) {
            send_to( out => "\\pong\\ => $msg" );
            send_to( ping => $msg + 1 );
        },
    ],
    main => [
        [],
        {},
        sub ($env, $msg) {
            send_to( out => "main starting ..." );
            send_to( alarm => [ 3, [ ping => 0 ] ]);
            send_to( alarm => [ 2, [ ping => 10 ] ]);
            send_to( alarm => [ 1, [ ping => 100 ] ]);
            send_to( ping => 1000 );
        },
    ],
);

# initialise ...
send_to( main => 1 );
# loop ...
loop( 20, \%processes );

done_testing;
