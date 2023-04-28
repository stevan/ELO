#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match build_actor ];
use ok 'ELO::Timers', qw[ :tickers ];

my $log = Test::ELO->create_logger;

sub ActorFactory (%args) {
    # NOTE:
    # This appoach is superior just creating a sub
    #    `sub Actor ($this, $msg) {...}`
    # because it has better control over the state
    # of the Actor and provides a means for
    # initiallizing the actor instance in the
    # body of the Factory, while still keeping
    # the Actor code simple.
    #
    # However, if you do not have state, then
    # just the simple `sub` approach is just
    # fine.

    my $greeting = $args{greeting} // 'Hello'; # set a default

    return build_actor SimpleActor => sub ($this, $msg) {

        # `state` variables allow you to track state between calls
        state $counter = 0;

        # it is also possible to make the handlers into a `state`
        # variable and prevent the re-complilation of the
        # subroutines, since they close over the other `state`
        # variables, it works out well.
        match $msg, state $handler //= +{
            eHello => sub ( $name ) {
                $counter++;
                $log->info( $this, "$greeting $name ($counter)" );
                if ( $counter == 2 && $greeting eq 'Hello' ) {
                    $counter  = 10;
                    $greeting = 'Greetings';
                }
                #warn "eHello ($this)";
            },
            #do { warn "this -> $this"; (); },
        };
    }
}

sub init ($this, $msg=[]) {

    my $a1 = $this->spawn( Actor => ActorFactory() );
    my $a2 = $this->spawn( Actor => ActorFactory( greeting => "Bonjour" ) );
    my $a3 = $this->spawn( Actor => ActorFactory( greeting => "Hallo" ) );

    $this->link( $_ ) foreach $a1, $a2, $a3;

    my $i = interval_ticker( $this, 2, sub {
        state $x = 0;
        $x++;
        $this->send( $a1, [ eHello => 'World interval('.$x.')' ] );
        $this->send( $a2, [ eHello => 'Monde interval('.$x.')' ] );
        $this->send( $a3, [ eHello => 'Werld interval('.$x.')' ] );
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



