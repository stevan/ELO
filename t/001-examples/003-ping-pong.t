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

my $log = Test::ELO->create_logger;

# See Akka Example:
# https://alvinalexander.com/scala/scala-akka-actors-ping-pong-simple-example/

sub Ping ($this, $msg) {

    $log->debug( $this, $msg );

    # NOTE:
    # it would be nicer if we could
    # just do `state $count` and it
    # would have one `$count` per
    # instance of the Actor.
    #
    # Instead we need to use inside-out
    # objects with `$this` being our
    # object-id key.

    fieldhash state %count;

    # NOTE:
    # The fieldhash function will be
    # called for each message, but since
    # %count will already be registered
    # it will do nothing more.

    # An alternate approach, if you want
    # to avoid that call is to do something
    # like this:
    #
    # `state $ready = fieldhashes( \state %count );`
    #
    # In this scendario, `fieldhashes` will only
    # be called once, to initialize `$ready`, and
    # when it does that will register %count.
    #
    # The value of $ready in this case should be
    # treated as a boolean, but it will actually
    # be an integer representing the number of
    # hashes thay were registered as fieldhashes.
    # If this number were to be 0 (false) that would
    # mean that it was unable to convert the hashes
    # and so we should die because something has
    # gone wrong. Something like this:
    #
    # `die "Actor Initialization Failed" unless $ready;`
    #
    # but I will be honest, it would be overkill
    # the extra call to `fieldhash` is minimal and
    # we are already paying the price of `match`
    # being called at runtime, as well as the
    # creation of the HASHref for `match` and all
    # the subroutines in them.
    #
    # So if this kind of "delicate" slot management
    # is not to your liking, the OO approach would
    # be better (once I actually write it).

    match $msg, +{
        eStartPing => sub ( $pong ) {
            isa_ok($pong, 'ELO::Core::Process');

            $count{$this}++;
            $log->info( $this, " Starting with (".$count{$this}.")" );
            $this->send( $pong, [ ePing => $this ]);

            pass('... '.$this->name.' started with '.$this->env('max_pings').' max pings');
        },
        ePong => sub ( $pong ) {
            isa_ok($pong, 'ELO::Core::Process');

            $count{$this}++;
            $log->info( $this, " Pong with (".$count{$this}.")" );
            if ( $count{$this} >= $this->env('max_pings') ) {
                $log->info( $this, " ... Stopping Ping" );
                $this->send( $pong, [ 'eStop' ]);

                pass('... '.$this->name.' finished with '.$count{$this}.' pings');
                $this->exit(0);
            }
            else {
                $this->send( $pong, [ ePing => $this ]);
            }
        },
    };
}

sub Pong ($this, $msg) {

    $log->debug( $this, $msg );

    # NOTE:
    # this is a stateless actor, so
    # nothing going on here :)

    match $msg, +{
        ePing => sub ( $ping ) {
            isa_ok($ping, 'ELO::Core::Process');

            $log->info( $this, " ... Ping" );
            $this->send( $ping, [ ePong => $this ]);
        },
        eStop => sub () {
            $log->info( $this, " ... Stopping Pong" );

            pass('... '.$this->name.' finished');
        },
    };
}

sub init ($this, $msg=[]) {

    state $ping = $this->spawn( Ping  => \&Ping, { max_pings => 5 } );
    state $pong = $this->spawn( Pong  => \&Pong );

    state $ping2 = $this->spawn( Ping2  => \&Ping, { max_pings => 10 });
    state $pong2 = $this->spawn( Pong2  => \&Pong );

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



