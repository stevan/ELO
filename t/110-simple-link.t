
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

sub Cat ($this, $msg) {

    fieldhash state %lives;

    match $msg, +{
        meow => sub () {
            $log->info( $this, 'meow');
        },
        $SIGEXIT => sub ($from) {
            $lives{$this}++;
            if ( $lives{$this} < 9 ) {
                $log->info( $this, '... you cannot kill me ('.$lives{$this}.')');
            }
            else {
                $log->info( $this, 'Oh no! you got me ('.$lives{$this}.')');
                $this->exit(0);
            }
        }
    }
}

sub init ($this, $msg) {

    state $interval;

    unless ($msg && @$msg) {
        my $cat = $this->spawn( Cat => \&Cat );

        $this->link( $cat );

        $cat->trap( $SIGEXIT );
        $this->trap( $SIGEXIT );

        $this->send( $cat, [ 'meow' ] );

        # keep trying to kill the cat
        $interval = interval( $this, 2, sub {
            $this->signal( $cat, $SIGEXIT, [ $this ] );
        });

        return;
    }

    match $msg, +{
        $SIGEXIT => sub ($from) {
            $log->info( $this, '... our kitty died! ('.$from->pid.')');
            cancel_interval( $interval );
        }
    }
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
