#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors',    qw[ match receive ];
use ok 'ELO::Timers',    qw[ ticker ];
use ok 'ELO::Constants', qw[ $SIGEXIT ];

my $log = Test::ELO->create_logger;

sub Cat () {

    state $expected = [ 1, 0 ];

    receive +{
        meow => sub ($this) {
            $log->info( $this, 'meow');
            $this->send_to_self([ 'meow' ]);
        },
        $SIGEXIT => sub ($this, $from) {
            my $e = shift(@$expected);
            is($this->loop->is_process_alive( $from ), $e, '... this('.$this->pid.') got SIGTERM the process('.$from->pid.') and worked as expected('.$e.')');
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
        my $cat1 = $this->spawn( Cat() );
        my $cat2 = $this->spawn( Cat() );

        $cat1->link( $this );
        $this->link( $cat2 );

        $cat1->trap( $SIGEXIT );
        $cat2->trap( $SIGEXIT );
        $this->trap( $SIGEXIT );

        $this->send( $cat1, [ 'meow' ] );
        $this->send( $cat2, [ 'meow' ] );

        ticker( $this, 10, sub {
            $log->warn( $this, 'I can not take it anymore!');
            $this->kill( $cat2 );
        });

        return;
    }

    match $msg, +{
        $SIGEXIT => sub ($from) {
            ok(!$this->loop->is_process_alive( $from ), '... this('.$this->pid.') got SIGTERM from process('.$from->pid.') as expected');
            $log->error( $this, '... one of our kitty died! ('.$from->pid.')');
            $log->fatal( $this, 'Goodbye cruel world!');
            $this->exit(0);
        }
    }
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
