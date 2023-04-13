
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
use ok 'ELO::Timers', qw[ timer ];

use ok 'ELO::Core::Constants', qw[ $SIGEXIT ];

my $log = Test::ELO->create_logger;

sub Worker ($this, $msg) {

    $log->debug( $this, $msg );

    match $msg, +{
        eStartWork => sub ($timeout) {
            $log->info( $this, "... started work ($timeout)" );

            pass('... got eStartWork message in '.$this->pid);

            timer( $this, $timeout, sub {
                $log->info( $this, "... finished work ($timeout)" );
                $this->exit;
            })
        },
    };
}

sub Supervisor ($this, $msg) {

    $log->debug( $this, $msg );

    fieldhash state %active_workers;

    match $msg, +{
        eStartWorkers => sub (@timeouts) {
            pass('... got eStartWorkers message in '.$this->pid);

            my %workers;
            foreach my $timeout (@timeouts) {
                my $worker = $this->spawn((sprintf 'Worker%02d' => scalar keys %workers), \&Worker);
                isa_ok($worker, 'ELO::Core::Process', $worker->pid);

                $workers{ $worker->pid } = $worker;

                $this->link( $worker );
                $this->send( $worker, [ eStartWork => $timeout ]);
            }

            $active_workers{$this} = \%workers;
        },
        $SIGEXIT => sub ($from) {
            isa_ok($from, 'ELO::Core::Process', 'SIGEXIT($from='.$from->pid.')');
            pass('... trapped SIGEXIT from '.$from->pid.' in '.$this->pid);

            delete $active_workers{$this}->{ $from->pid };

            $this->exit(0) if not scalar keys $active_workers{$this}->%*;
        }
    };
}

sub init ($this, $msg) {

    # the initial message is empty or undef
    # this kinda gross hack
    unless ($msg && @$msg) {
        # so we can use as an entry point
        my $supervisor = $this->spawn( Supervisor => \&Supervisor );
        isa_ok($supervisor, 'ELO::Core::Process', $supervisor->pid);

        # trap the exit signal
        $_->trap( $SIGEXIT ) foreach ($this, $supervisor);

        $this->send( $supervisor, [ eStartWorkers => 20, 10, 5, 15 ] );
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
        $SIGEXIT => sub ($from) {
            isa_ok($from, 'ELO::Core::Process', 'SIGEXIT($from='.$from->pid.')');
            $log->info( $this, '... trapped EXIT from Supervisor' );

            pass('... trapped SIGEXIT from '.$from->pid.' in '.$this->pid);
        }
    };
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;
