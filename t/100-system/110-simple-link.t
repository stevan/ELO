#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors',    qw[ match receive ];
use ok 'ELO::Types',     qw[ :events ];
use ok 'ELO::Timers',    qw[ :tickers ];
use ok 'ELO::Constants', qw[ $SIGEXIT ];

my $log = Test::ELO->create_logger;

# NOTE:
# the Cat is a linked process, we try to kill it
# many times, and when it actually does die, it
# will send the SIGEXIT to our init process, where
# we handle it and stop the Cat Killing Interval.

# this shows uni-directional link signals, here
# the Cat gets triggered and sends to init.

event *Meow;

sub Cat () {

    my $lives = 0;

    receive {
        *Meow => sub ($this) {
            $log->info( $this, *Meow );
        },
        $SIGEXIT => sub ($this, $from) {
            $lives++;
            if ( $lives < 9 ) {
                $log->error( $this, '... you cannot kill me ('.$lives.')');
            }
            else {
                $log->fatal( $this, 'Oh no! you got me ('.$lives.')');
                $this->exit(0);
            }
        }
    }
}

#
# $init -> link -> $cat   : link the fate of $init to $cat
# $init -> kill -> $cat   : try to kill the cat
# exit($cat)              : eventually it dies and exits
# $init <- EXIT <- $cat   : this triggers $cat link to send EXIT back to $init
# exit($init)             : $init exits after getting signal from $cat
#

sub init ($this, $msg) {

    state $interval;

    unless ($msg && @$msg) {
        my $cat = $this->spawn( Cat() );

        $this->link( $cat );

        $cat->trap( $SIGEXIT );
        $this->trap( $SIGEXIT );

        $this->send( $cat, [ *Meow ] );

        # keep trying to kill the cat
        $interval = interval_ticker( $this, 2, sub {
            $log->warn( $this, '... take this you darn cat!');
            $this->kill( $cat );
        });

        return;
    }

    match $msg, +{
        $SIGEXIT => sub ($from) {
            ok(!$this->loop->is_process_alive( $from ), '... the process has died as expected');
            $log->error( $this, '... our kitty died! ('.$from->pid.')');
            cancel_ticker( $interval );
            $this->exit(0);
        }
    }
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
