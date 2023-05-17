#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :events ];
use ok 'ELO::Timers', qw[ :tickers ];
use ok 'ELO::Actors', qw[ receive ];

my $log = Test::ELO->create_logger;

protocol *Greeter => sub {
    event *eHello => ( *Str );
};

sub Greeter ($greeting='Hello') {

    my $counter = 0;

    receive[*Greeter] => +{
        *eHello => sub ( $this, $name ) {
            $counter++;
            $log->info( $this, "$greeting $name ($counter)" );
            if ( $counter == 2 && $greeting eq 'Hello' ) {
                $counter  = 10;
                $greeting = 'Greetings';
            }
        }
    };
}

sub init ($this, $msg=[]) {

    my $a1 = $this->spawn( Greeter() );
    my $a2 = $this->spawn( Greeter( "Bonjour" ) );
    my $a3 = $this->spawn( Greeter( "Hallo" ) );

    $this->link( $_ ) foreach $a1, $a2, $a3;

    my $i = interval_ticker( $this, 2, sub {
        state $x = 0;
        $x++;
        $this->send( $a1, [ *eHello => 'World interval('.$x.')' ] );
        $this->send( $a2, [ *eHello => 'Monde interval('.$x.')' ] );
        $this->send( $a3, [ *eHello => 'Werld interval('.$x.')' ] );
    });

    ticker( $this, 10, sub {
        $log->warn( $this, '... exiting' );
        cancel_ticker( $i );
        $this->exit(0);
    });

    # async control flow ;)
    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



