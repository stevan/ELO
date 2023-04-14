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
use ok 'ELO::Actors',    qw[ match ];
use ok 'ELO::Timers',    qw[ timer ];
use ok 'ELO::Constants', qw[ $SIGEXIT ];

my $log = Test::ELO->create_logger;

sub Cat ($this, $msg) {

    match $msg, +{
        meow => sub () {
            $log->info( $this, 'meow');
            $this->send_to_self([ 'meow' ]);
        },
        $SIGEXIT => sub ($from) {
            $log->fatal( $this, 'Oh no, you ('.$from->pid.') got me!');
            $this->exit(0);
        }
    }
}

#
# $cat1 -> link -> $init   : link the fate of $cat1 to $init
# $init -> link -> $cat2   : link the fate of $init to $cat2
#
# $init -> kill -> $cat2   : try to kill the cat2
# exit($cat2)              : it dies and exits
# $init <- EXIT <- $cat2   : this triggers $cat2 link to send EXIT back to $init
# exit($init)              : $init exits after getting signal from $cat2
# $cat1 <- EXIT <- $init   : this triggers $init link to send EXIT back to $cat1
# exit($cat1)              : $cat1 exits after getting signal from $init
#

sub init ($this, $msg) {

    unless ($msg && @$msg) {
        my $cat1 = $this->spawn( Cat => \&Cat );
        my $cat2 = $this->spawn( Cat => \&Cat );

        $cat1->link( $this );
        $this->link( $cat2 );

        $cat1->trap( $SIGEXIT );
        $cat2->trap( $SIGEXIT );
        $this->trap( $SIGEXIT );

        $this->send( $cat1, [ 'meow' ] );
        $this->send( $cat2, [ 'meow' ] );

        timer( $this, 10, sub {
            $log->warn( $this, 'I can not take it anymore!');
            $this->kill( $cat2 );
        });

        return;
    }

    match $msg, +{
        $SIGEXIT => sub ($from) {
            $log->error( $this, '... one of our kitty died! ('.$from->pid.')');
            $log->fatal( $this, 'Goodbye cruel world!');
            $this->exit(0);
        }
    }
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
