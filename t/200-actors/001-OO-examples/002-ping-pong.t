#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;
use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors',    qw[ match ];
use ok 'ELO::Constants', qw[ $SIGEXIT ];
use ok 'ELO::Actors::Actor';

my $log = Test::ELO->create_logger;

# See Akka Example:
# https://alvinalexander.com/scala/scala-akka-actors-ping-pong-simple-example/

package Ping {
    use v5.36;

    use Test::More;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Actors::Actor';
    use slots (
        num_pings => sub { 1 },
        count     => sub { 0 },
    );

    sub receive ($self, $this) {
        return +{
            eStartPing => sub ( $pong ) {
                isa_ok($pong, 'ELO::Core::ActorRef');

                $self->{count}++;
                $log->info( $this, " Starting with (".$self->{count}.")" );
                $this->send( $pong, [ ePing => $this ]);

                pass('... '.$this->name.' started with '.$self->{num_pings}.' pings');
            },
            ePong => sub ( $pong ) {
                isa_ok($pong, 'ELO::Core::ActorRef');

                $self->{count}++;
                $log->info( $this, " Pong with (".$self->{count}.")" );

                if ( $self->{count} >= $self->{num_pings} ) {
                    $log->info( $this, " ... Stopping Ping" );
                    $this->send( $pong, [ 'eStop' ]);

                    pass('... '.$this->name.' finished with '.$self->{count}.' pings');
                    $this->exit(0);
                }
                else {
                    $this->send( $pong, [ ePing => $this ]);
                }
            },
        }
    }
}

package Pong {
    use v5.36;

    use Test::More;

    use parent 'UNIVERSAL::Object::Immutable';
    use roles  'ELO::Actors::Actor';

    sub receive ($self, $this) {
        return +{
            ePing => sub ( $ping ) {
                isa_ok($ping, 'ELO::Core::ActorRef');

                $log->info( $this, " ... Ping" );
                $this->send( $ping, [ ePong => $this ]);
            },
            eStop => sub () {
                $log->info( $this, " ... Stopping Pong" );

                pass('... '.$this->name.' finished');
            },
        };
    }

=pod
    sub ePing ( $this, $ping ) : handler {
        isa_ok($ping, 'ELO::Core::ActorRef');

        $log->info( $this, " ... Ping" );
        $this->send( $ping, [ ePong => $this ]);
    }

    sub eStop ( $this ) : handler {
        $log->info( $this, " ... Stopping Pong" );

        pass('... '.$this->name.' finished');
    }

    sub recieve : Behavior[HandlerDispatch];

This could loop over all the methods and find
the ones with a :handler tag and collect them
into a &recieve block
=cut

}

package Init {
    use v5.36;

    use Test::More;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Actors::Actor';
    use slots (
        expected => sub { +[] },
    );

    sub on_start ($self, $this) {

        my $ping = $this->spawn_actor( 'Ping', { num_pings => 5 } );
        my $pong = $this->spawn_actor( 'Pong' );
        $ping->link( $pong );

        my $ping2 = $this->spawn_actor( 'Ping', { num_pings => 10 } );
        my $pong2 = $this->spawn_actor( 'Pong' );
        $ping2->link( $pong2 );

        $this->send( $ping,  [ eStartPing => $pong  ]);
        $this->send( $ping2, [ eStartPing => $pong2 ]);

        $self->{expected} = [ $ping, $pong, $ping2, $pong2 ];
    }

    sub on_exit ($self, $this, $from) {

        $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');

        is($from, shift( $self->{expected}->@* ), '... got the expected process');

        $this->exit(0) if scalar $self->{expected}->@* == 0;
    }
}

ELO::Loop->run_actor( 'Init', logger => $log );

done_testing;



