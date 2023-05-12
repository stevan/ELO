#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Types',     qw[ :core :events ];
use ok 'ELO::Actors',    qw[ receive match setup ];
use ok 'ELO::Constants', qw[ $SIGEXIT ];

my $log = Test::ELO->create_logger;

event *eStartPing => ( *Process );
event *eStopPong  => ();
event *ePong      => ( *Process );
event *ePing      => ( *Process );

sub Ping (%args) {

    my $max_pings = $args{max_pings} // 5;
    my $count     = 0;

    receive {
        *eStartPing => sub ( $this, $pong ) {
            isa_ok($pong, 'ELO::Core::Process');

            $count++;
            $log->info( $this, " Starting with ($count) and max-pings($max_pings)" );
            $this >>= [ $pong, [ *ePing => $this ]];

            pass('... '.$this->name.' started with '.$max_pings.' max pings');
        },

        *ePong => sub ( $this, $pong ) {
            isa_ok($pong, 'ELO::Core::Process');

            $count++;
            $log->info( $this, " Pong with ($count)" );
            if ( $count >= $max_pings ) {
                $log->info( $this, " ... Stopping Ping" );
                $this >>= [ $pong, [ *eStopPong => () ]];

                pass('... '.$this->name.' finished with '.$count.' pings');
                $this->exit(0);
            }
            else {
                $this >>= [ $pong, [ *ePing => $this ]];
            }
        }
    }
}

sub Pong () {

    receive {
        *ePing => sub ( $this, $ping ) {
            isa_ok($ping, 'ELO::Core::Process');

            $log->info( $this, " ... Ping" );
            $this >>= [ $ping, [ *ePong => $this ]];
        },
        *eStopPong => sub ( $this ) {
            $log->info( $this, " ... Stopping Pong" );

            pass('... '.$this->name.' finished');
        }
    }
}

sub Init () {

    setup sub ($this) {
        my $ping = $this->spawn( Ping() );
        my $pong = $this->spawn( Pong() );

        my $ping2 = $this->spawn( Ping( max_pings => 10 ) );
        my $pong2 = $this->spawn( Pong() );

        isa_ok($ping, 'ELO::Core::Process');
        isa_ok($pong, 'ELO::Core::Process');

        isa_ok($ping2, 'ELO::Core::Process');
        isa_ok($pong2, 'ELO::Core::Process');

        # link the ping/pong pairs ...
        # it doesn't matter which way we link
        # they are bi-directional

        $ping->link( $pong );
        $pong2->link( $ping2 );

        $this >>= [ $ping,  [ *eStartPing => $pong  ]];
        $this >>= [ $ping2, [ *eStartPing => $pong2 ]];

        # set our process up to link to all
        # these processes, so we can see when
        # they exit

        $this->trap( $SIGEXIT );
        $this->link( $_ ) foreach ($ping, $pong, $ping2, $pong2);

        # ...

        my $expected = [ $ping, $pong, $ping2, $pong2 ];

        receive +{
            $SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');

                is($from, shift(@$expected), '... got the expected process');
            }
        }
    }
}

ELO::Loop->run( Init(), logger => $log );

done_testing;



