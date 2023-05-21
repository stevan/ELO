#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match receive ];
use ok 'ELO::Types',  qw[ *SIGEXIT ];

my $log = Test::ELO->create_logger;

sub SigExitCatcher () {

    receive +{
        *SIGEXIT => sub ($this, $from) {
            $log->info( $this, "Got *SIGEXIT from (".$from->pid."), ignoring");
            pass('... got the SIGEXIT in SigExitCatcher, as we expected');
        }
    }
}

sub SigExitIgnore ($this, $msg) {
    # this will not trap exits so it
    # will simply be killed and not
    # get any SIGEXIT messages

    $log->error( $this, '... got message in SigExitIgnore, this should not happen');
    fail('... we should never get a message here');
}

sub init ($this, $msg) {

    state $t1 = $this->spawn( SigExitCatcher() );
    state $t2 = $this->spawn( SigExitIgnore => \&SigExitIgnore );

    unless ($msg && @$msg) {

        isa_ok($t1, 'ELO::Core::Process');
        isa_ok($t2, 'ELO::Core::Process');

        $this->trap( *SIGEXIT );
        $t1->trap( *SIGEXIT );

        ok($this->is_trapping( *SIGEXIT ), '... init can trap SIGEXIT');
        ok($t1->is_trapping( *SIGEXIT ), '... t1 can trap SIGEXIT');

        $log->info( $this, '... linking to '.$t1->pid);
        $this->link( $t1 );
        $log->info( $this, '... linking to '.$t2->pid);
        $this->link( $t2 );

        $log->info( $this, '... sending SIGEXIT to '.$t1->pid);
        $this->signal( $t1, *SIGEXIT, [ $this ] );

        $this->loop->next_tick(sub {
            $log->info( $this, '... sending kill to '.$t1->pid);
            $this->kill( $t1 );

            $this->loop->next_tick(sub {
                $log->info( $this, '... calling exit for '.$t1->pid);
                $t1->exit(0);
            });
        });

        $log->info( $this, '... sending SIGEXIT to '.$t2->pid);
        $this->signal( $t2, *SIGEXIT, [ $this ] );

        return;
    }

    state $expected = [ $t2, $t1 ];

    match $msg, +{
        *SIGEXIT => sub ($from) {
            $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');

            is($from, shift(@$expected), '... got the expected process');
        }
    }
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
