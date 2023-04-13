
#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Timers', qw[ timer interval cancel_interval ];

use ok 'ELO::Core::Constants', qw[ $SIGEXIT ];

my $log = Test::ELO->create_logger;

sub SigExitCatcher ($this, $msg) {

    match $msg, +{
        $SIGEXIT => sub ($from) {
            $log->info( $this, "Got $SIGEXIT from (".$from->pid."), ignoring");
        }
    }
}

sub SigExitIgnore ($this, $msg) {

    $log->info( $this, '... got message, ignoring');

    match $msg, +{};
}

sub init ($this, $msg) {

    unless ($msg && @$msg) {


        my $t1 = $this->spawn( SigExitCatcher => \&SigExitCatcher );
        my $t2 = $this->spawn( SigExitIgnore => \&SigExitIgnore );

        $this->trap( $SIGEXIT );
        $t1->trap( $SIGEXIT );

        $log->info( $this, '... linking to '.$t1->pid);
        $this->link( $t1 );
        $log->info( $this, '... linking to '.$t2->pid);
        $this->link( $t2 );

        $log->info( $this, '... sending SIGEXIT to '.$t1->pid);
        $this->signal( $t1, $SIGEXIT, [ $this ] );

        $this->loop->next_tick(sub {
            $log->info( $this, '... sending kill to '.$t1->pid);
            $this->kill( $t1 );

            $this->loop->next_tick(sub {
                $log->info( $this, '... calling exit for '.$t1->pid);
                $t1->exit(0);
            });
        });

        $log->info( $this, '... sending SIGEXIT to '.$t2->pid);
        $this->signal( $t2, $SIGEXIT, [ $this ] );

        return;
    }

    match $msg, +{
        $SIGEXIT => sub ($from) {
            $log->info( $this, '... got SIGEXIT from ('.$from->pid.')');
        }
    }
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
