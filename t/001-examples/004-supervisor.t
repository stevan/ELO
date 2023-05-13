#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Types',     qw[ :core :events *SIGEXIT ];
use ok 'ELO::Actors',    qw[ match receive ];
use ok 'ELO::Timers',    qw[ :tickers ];

my $log = Test::ELO->create_logger;

event *eStartWorkers => ( *ArrayRef ); # \@timeouts
event *eStartWork    => ( *Int );      # timeout

sub Worker ($name) {

    receive $name, +{
        *eStartWork => sub ($this, $timeout) {
            $log->info( $this, "... started work ($timeout)" );

            pass('... got eStartWork message in '.$this->pid);

            ticker( $this, $timeout, sub {
                $log->info( $this, "... finished work ($timeout)" );
                $this->exit;
            })
        }
    }
}

sub Supervisor () {

    my %active_workers;

    receive +{
        *eStartWorkers => sub ($this, $timeouts) {
            pass('... got eStartWorkers message in '.$this->pid);

            foreach my $timeout (@$timeouts) {
                my $worker = $this->spawn( Worker(sprintf 'Worker%02d' => scalar keys %active_workers) );
                isa_ok($worker, 'ELO::Core::Process', $worker->pid);

                $active_workers{ $worker->pid } = $worker;

                $this->link( $worker );
                $this->send( $worker, [ *eStartWork => $timeout ]);
            }
        },
        *SIGEXIT => sub ($this, $from) {
            isa_ok($from, 'ELO::Core::Process', 'SIGEXIT($from='.$from->pid.')');
            pass('... trapped SIGEXIT from '.$from->pid.' in '.$this->pid);

            delete $active_workers{ $from->pid };

            $this->exit(0) if not scalar keys %active_workers;
        }
    };
}

sub init ($this, $msg) {

    # the initial message is empty or undef
    # this kinda gross hack
    unless ($msg && @$msg) {
        # so we can use as an entry point
        my $supervisor = $this->spawn( Supervisor() );
        isa_ok($supervisor, 'ELO::Core::Process', $supervisor->pid);

        # trap the exit signal
        $_->trap( *SIGEXIT ) foreach ($this, $supervisor);

        $this->send( $supervisor, [ *eStartWorkers => [ 20, 10, 5, 15 ] ] );
        $this->link( $supervisor );
        # is equvalent to this ...
        # $supervisor->link( $this );

        # just besure to return here
        # so that we don't try to match
        # our empty message ...
        return;
    }

    # catch the trapped exits
    match $msg, +{
        *SIGEXIT => sub ($from) {
            isa_ok($from, 'ELO::Core::Process', 'SIGEXIT($from='.$from->pid.')');
            $log->info( $this, '... trapped EXIT from Supervisor' );

            pass('... trapped SIGEXIT from '.$from->pid.' in '.$this->pid);
        }
    };
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
