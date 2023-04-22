#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Actors',    qw[ match build_actor ];
use ok 'ELO::Constants', qw[ $SIGEXIT ];

my $log = Test::ELO->create_logger;

sub PingFactory (%args) {

    my $max_pings = $args{max_pings} // 5;

    return build_actor Ping => sub ($this, $msg) {

        state $count = 0;

        $log->debug( $this, $msg );

        match $msg, state $handler //= +{
            eStartPing => sub ( $pong ) {
                isa_ok($pong, 'ELO::Core::Process');

                $count++;
                $log->info( $this, " Starting with ($count) and max-pings($max_pings)" );
                $this->send( $pong, [ ePing => $this ]);

                pass('... '.$this->name.' started with '.$max_pings.' max pings');
            },
            ePong => sub ( $pong ) {
                isa_ok($pong, 'ELO::Core::Process');

                $count++;
                $log->info( $this, " Pong with ($count)" );
                if ( $count >= $max_pings ) {
                    $log->info( $this, " ... Stopping Ping" );
                    $this->send( $pong, [ 'eStop' ]);

                    pass('... '.$this->name.' finished with '.$count.' pings');
                    $this->exit(0);
                }
                else {
                    $this->send( $pong, [ ePing => $this ]);
                }
            },
        }
    }
}

sub PongFactory () {

    # NOTE:
    # this is a stateless actor, so
    # a factory is not technically
    # needed. The only benefit is
    # that we can capture the handlers
    # with the `state` var, which
    # should save memory.

    return build_actor Pong => sub ($this, $msg) {

        $log->debug( $this, $msg );

        match $msg, state $handler //= +{
            ePing => sub ( $ping ) {
                isa_ok($ping, 'ELO::Core::Process');

                $log->info( $this, " ... Ping" );
                $this->send( $ping, [ ePong => $this ]);
            },
            eStop => sub () {
                $log->info( $this, " ... Stopping Pong" );

                pass('... '.$this->name.' finished');
            },
        }
    }
}

sub init ($this, $msg=[]) {

    state $ping = $this->spawn( Ping => PingFactory() );
    state $pong = $this->spawn( Pong => PongFactory() );

    state $ping2 = $this->spawn( Ping2 => PingFactory( max_pings => 10 ) );
    state $pong2 = $this->spawn( Pong2 => PongFactory() );

    unless ($msg && @$msg) {
        isa_ok($ping, 'ELO::Core::Process');
        isa_ok($pong, 'ELO::Core::Process');

        isa_ok($ping2, 'ELO::Core::Process');
        isa_ok($pong2, 'ELO::Core::Process');

        # link the ping/pong pairs ...
        # it doesn't matter which way we link
        # they are bi-directional

        $ping->link( $pong );
        $pong2->link( $ping2 );

        $this->send( $ping,  [ eStartPing => $pong  ]);
        $this->send( $ping2, [ eStartPing => $pong2 ]);

        # set our process up to link to all
        # these processes, so we can see when
        # they exit

        $this->trap( $SIGEXIT );
        $this->link( $_ ) foreach ($ping, $pong, $ping2, $pong2);

        return;
    }

    state $expected = [ $ping, $pong, $ping2, $pong2 ];

    match $msg, +{
        $SIGEXIT => sub ($from) {
            $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');

            is($from, shift(@$expected), '... got the expected process');
        }
    }
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



