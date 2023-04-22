#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dump;

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match ];

my $log = Test::ELO->create_logger;

sub Service ($this, $msg) {

    $log->debug( $this, $msg );

    #warn Dumper +{ $this->pid => $msg } if DEBUG;

    # NOTE:
    # this is basically a state-less actor, which
    # is actually kind of the ideal form, it keeps
    # it less complex.

    match $msg, +{
        # $request  = eServiceRequest  [ sid : SID, action : Str, args : <Any>, caller : PID ]
        # $response = eServiceResponse [ sid : SID, return : <Any> ]
        # $error    = eServiceError    [ sid : SID, error : Str ]
        eServiceRequest => sub ($sid, $action, $args, $caller) {
            my ($x, $y) = @$args;

            eval {
                $this->send( $caller, [
                    eServiceResponse => (
                        $sid,
                        ($action eq 'add') ? ($x + $y) :
                        ($action eq 'sub') ? ($x - $y) :
                        ($action eq 'mul') ? ($x * $y) :
                        ($action eq 'div') ? ($x / $y) :
                        die "Invalid Action: $action"
                    )
                ]);
                1;
            } or do {
                my $e = $@;
                chomp $e;
                $this->send( $caller, [ eServiceError => ( $sid, $e ) ] );
            };
        }
    }
}

sub ServiceRegistry ($this, $msg) {

    $log->debug( $this, $msg );

    #warn Dumper +{ $this->pid => $msg } if DEBUG;

    # NOTE:
    # this is an actor which has shared state
    # across all instances. This is no need for
    # locks because all message-sends will
    # happen in sequence during the loop->tick
    #
    # you can think of this as a
    # shared in-memory data base
    # if you want to, but it is
    # a bit of a stretch ;)

    # NOTE:
    # all these variables below are shared
    # across all instances of the ServiceRegistry
    # see NOTE in the ServiceClient for more
    # details

    state $foo = $this->spawn( FooService => \&Service );
    state $bar = $this->spawn( BarService => \&Service );

    state $services = +{
        'foo.example.com' => $foo,
        'bar.example.com' => $bar,
    };

    state sub lookup ($name)           { $services->{ $name } }
    state sub update ($name, $service) { $services->{ $name } = $service }

    match $msg, +{

        # Requests ...

        # $request  = eServiceRegistryUpdateRequest  [ sid : SID, name : Str, service : Process, caller : PID ]]
        # $response = eServiceRegistryUpdateResponse [ sid : SID, name : Str, service : Str ]
        # $error    = eServiceRegistryUpdateError    [ sid : SID, error : Str ]
        eServiceRegistryUpdateRequest => sub ($sid, $name, $service, $caller) {
            update( $name, $service );
            $this->send( $caller, [ eServiceRegistryUpdateResponse => $sid, $name, $service ] );
        },

        # $request  = eServiceRegistryLookupRequest  [ sid : SID, name : Str, caller : PID ]]
        # $response = eServiceRegistryLookupResponse [ sid : SID, service : Str ]
        # $error    = eServiceRegistryLookupError    [ sid : SID, error   : Str ]
        eServiceRegistryLookupRequest => sub ($sid, $name, $caller) {
            if ( my $service = lookup( $name ) ) {
                $this->send( $caller, [ eServiceRegistryLookupResponse => $sid, $service ] );
            }
            else {
                $log->warn( $this, +{
                    msg => "Could not find service",
                    name => $name, sid => $sid
                });
                $this->send( $caller, [
                    eServiceRegistryLookupError => (
                        $sid,  'Could not find service('.$name.')'
                    )
                ]);
            }
        }
    }
}

sub ServiceClient ($this, $msg) {

    $log->debug( $this, $msg );

    #warn Dumper +{ $this->pid => $msg } if DEBUG;

    # NOTE:
    # This is another example of a shared state
    # across all instances, in this case it is
    # to create a session system that will allow
    # for the client to handle multiple concurrent
    # requests.

    # NOTE:
    # all these variables below are shared
    # across all instances of the ServiceClient
    state $registry = $this->spawn( ServiceRegistry => \&ServiceRegistry );
    state $sessions = +{};
    state $next_sid = 0;

    # NOTE:
    # Careful not to close over any values
    # other than the `state` variables created
    # above, otherwise issues will come up
    #
    # For instance, closing over $this will
    # end up closing over the first instance
    # that is created. This is not what you want.
    # If you need to use $this inside these, then
    # it should be passed in to these subs
    state sub session_get    ($id)   {        $sessions->{ $id } }
    state sub session_delete ($id)   { delete $sessions->{ $id } }
    state sub session_create ($data) {
        $sessions->{ ++$next_sid } = $data;
        $next_sid;
    }

    match $msg, +{

        # Requests ...

        # $request  = eServiceClientRequest  [ url : Str, action : Str, args : <Any> ]]
        # $response = eServiceClientResponse [ <Any> ]
        # $error    = eServiceClientError    [ error : Str ]
        eServiceClientRequest => sub ($url, $action, $args) {

            my $sid = session_create([ $url, $action, $args ]);

            $this->send( $registry, [
                eServiceRegistryLookupRequest => (
                    $sid,  # my session id
                    $url,  # the url of the service
                    $this  # where to send the response
                )
            ]);
        },


        # Responses ...

        # Ideally these should not be part of the
        # protocol of the Actor, but it needs to
        # happen with the $caller style that
        # we are using.
        #
        # It is possible to do all this with Promises
        # instead, but this is a different test :)

        eServiceRegistryLookupResponse => sub ($sid, $service) {
            my $s = session_get( $sid );
            my ($url, $action, $args) = $s->@*;
            # update the service
            $s->[0] = [ $url, $service ];

            my %expected = (
                1 => 'FooService',
                2 => 'BarService',
                4 => 'FooService',
            );
            ok($expected{$sid}, '... got the expected session id with lookup response');
            is($service->name, $expected{$sid}, '... got the expected lookup response');

            $this->send( $service, [
                eServiceRequest => ( $sid, $action, $args, $this )
            ]);
        },

        eServiceResponse => sub ($sid, $return) {
            my $request = session_get( $sid );

            $log->info( $this, +{ eServiceResponse => $return, sid => $sid } );

            my %expected = (
                1 => 4,
                2 => 20,
            );

            ok($expected{$sid}, '... got the expected session id with service response');
            is($return, $expected{$sid}, '... got the expected service response');
        },

        # Errors ...

        eServiceError => sub ($sid, $error) {
            my $request = session_get( $sid );

            $log->error( $this, +{ eServiceError => $error, sid => $sid } );

            like($error, qr/^Invalid Action\: multiply/, '... got the expected service error');
            is($sid, 4, '... got the expected session id for service error');
        },

        eServiceRegistryLookupError => sub ($sid, $error) {
            my $request = session_get( $sid );

            $log->error( $this, +{ eServiceRegistryLookupError => $error, sid => $sid } );

            is($error, 'Could not find service(baz.example.com)', '... got the expected lookup error');
            is($sid, 3, '... got the expected session id for lookup error');
        },

    }
}

sub init ($this, $msg=[]) {

    my $client = $this->spawn( ServiceClient  => \&ServiceClient );
    isa_ok($client, 'ELO::Core::Process');

    $this->send( $client, [
        eServiceClientRequest => (
            'foo.example.com', add => [ 2, 2 ]
        )
    ]);

    $this->send( $client, [
        eServiceClientRequest => (
            'bar.example.com', mul => [ 10, 2 ]
        )
    ]);

    $this->send( $client, [
        eServiceClientRequest => (
            'baz.example.com', mul => [ 10, 2 ]
        )
    ]);

    $this->send( $client, [
        eServiceClientRequest => (
            'foo.example.com', multiply => [ 10, 2 ]
        )
    ]);
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

__END__
