#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Timers', qw[ timer interval cancel_interval ];

my $log = Test::ELO->create_logger;

sub ActorFactory (%args) {

    return sub ($this, $msg) {

        # `state` variables allow you to track state between calls
        state $counter  = 0;
        state $greeting = $args{greeting} // 'Hello';

        match $msg, +{
            eHello => sub ( $name ) {
                $counter++;
                $log->info( $this, "$greeting $name ($counter)" );
                if ( $counter == 2 && $greeting eq 'Hello' ) {
                    $counter  = 10;
                    $greeting = 'Greetings';
                }
            }
        };
    }
}

sub init ($this, $msg=[]) {

    my $a1 = $this->spawn( Actor => ActorFactory() );
    my $a2 = $this->spawn( Actor => ActorFactory( greeting => "Bonjour" ) );

    $this->link( $_ ) foreach $a1, $a2;

    my $i = interval( $this, 2, sub {
        $this->send( $a1, [ eHello => 'World' ] );
        $this->send( $a2, [ eHello => 'Monde' ] );
    });

    timer( $this, 10, sub {
        $log->warn( $this, '... exiting' );
        cancel_interval( $i );
        $this->exit(0);
    });

    # async control flow ;)
    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



