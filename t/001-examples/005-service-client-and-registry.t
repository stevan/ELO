#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :types :events ];
use ok 'ELO::Actors', qw[ match receive setup ];

my $log = Test::ELO->create_logger;

type *SID, sub ($sid) { (state $Int = lookup_type(*Int))->check( $sid ) && $sid < 255 };

enum *Ops => (
    *Ops::Add,
    *Ops::Sub,
    *Ops::Mul,
    *Ops::Div,
);

protocol *ServiceProtocol => sub {
    event *eServiceRequest  => ( *SID, *Ops, [ *Int, *Int ], *Process ); # sid : SID, action : Str, args : <Any>, caller : PID
    event *eServiceResponse => ( *SID, *Num );                           # sid : SID, return : <Any>
    event *eServiceError    => ( *SID, *Str );                           # sid : SID, error : Str
};

protocol *ServiceRegistryProtocol => sub {
    event *eServiceRegistryUpdateRequest  => ( *SID, *Str, *Process, *Process ); # sid : SID, name : Str, service : Process, caller : PID
    event *eServiceRegistryUpdateResponse => ( *SID, *Str, *Str );              # sid : SID, name : Str, service : Str
    event *eServiceRegistryUpdateError    => ( *SID, *Str );                    # sid : SID, error : Str

    event *eServiceRegistryLookupRequest  => ( *SID, *Str, *Process ); # sid : SID, name : Str, caller : PID
    event *eServiceRegistryLookupResponse => ( *SID, *Process );       # sid : SID, service : PID
    event *eServiceRegistryLookupError    => ( *SID, *Str );           # sid : SID, error   : Str
};

# NOTE:
# the service client needs to
# accept many different responses
# from above, so we just dont bother
# to put this in a protcol right now
#
# a possible soltuion is to use the Akka
# technique of wrapping the event in
# another event, which can then be easily
# handled by the protocol
event *eServiceClientRequest  => ( *Str, *Ops, [ *Int, *Int ] ); #  url : Str, action : Str, args : <Any>

sub Service ($service_name) {

    receive [$service_name => *ServiceProtocol], +{
        *eServiceRequest => sub ($this, $sid, $action, $args, $caller) {
            my ($x, $y) = @$args;

            try {
                $this->send( $caller, [
                    *eServiceResponse => (
                        $sid,
                        match [ *Ops, $action ] => {
                            *Ops::Add => sub () { $x + $y },
                            *Ops::Sub => sub () { $x - $y },
                            *Ops::Mul => sub () { $x * $y },
                            *Ops::Div => sub () { $x / $y },
                        }
                    )
                ]);
            } catch ($e) {
                chomp $e;
                $this->send( $caller, [ *eServiceError => ( $sid, $e ) ] );
            }
        }
    }
}

sub ServiceRegistry () {

    setup sub ($ctx) {
        my $foo = $ctx->spawn( Service('FooService') );
        my $bar = $ctx->spawn( Service('BarService') );

        my $services = +{
            'foo.example.com' => $foo,
            'bar.example.com' => $bar,
        };

        my sub lookup ($name)           { $services->{ $name } }
        my sub update ($name, $service) { $services->{ $name } = $service }

        receive[*ServiceRegistryProtocol], +{
            *eServiceRegistryUpdateRequest => sub ($this, $sid, $name, $service, $caller) {
                try {
                    update( $name, $service );
                    $this->send( $caller, [ *eServiceRegistryUpdateResponse => $sid, $name, $service ] );
                } catch ($e) {
                    $this->send( $caller, [ *eServiceRegistryUpdateError => $sid, $e ] );
                }
            },

            *eServiceRegistryLookupRequest => sub ($this, $sid, $name, $caller) {
                if ( my $service = lookup( $name ) ) {
                    $this->send( $caller, [ *eServiceRegistryLookupResponse => $sid, $service ] );
                }
                else {
                    $log->warn( $this, +{
                        msg => "Could not find service",
                        name => $name, sid => $sid
                    });
                    $this->send( $caller, [
                        *eServiceRegistryLookupError => (
                            $sid,  'Could not find service('.$name.')'
                        )
                    ]);
                }
            }
        }
    }
}

sub ServiceClient () {

    setup sub ($ctx) {

        my $registry = $ctx->spawn( ServiceRegistry() );
        my $sessions = +{};
        my $next_sid = 0;

        my sub session_get    ($id)   {        $sessions->{ $id } }
        my sub session_delete ($id)   { delete $sessions->{ $id } }
        my sub session_create ($data) {
            $sessions->{ ++$next_sid } = $data;
            $next_sid;
        }

        receive +{
            # Requests ...

            *eServiceClientRequest => sub ($this, $url, $action, $args) {

                my $sid = session_create([ $url, $action, $args ]);

                $this->send( $registry, [
                    *eServiceRegistryLookupRequest => (
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

            *eServiceRegistryLookupResponse => sub ($this, $sid, $service) {
                my $s = session_get( $sid );
                my ($url, $action, $args) = $s->@*;
                # update the service
                $s->[0] = [ $url, $service ];

                my %expected = (
                    1 => 'FooService',
                    2 => 'BarService',
                    4 => 'BarService',
                    5 => 'FooService',
                );
                ok($expected{$sid}, '... got the expected session id with lookup response');
                is($service->name, $expected{$sid}, '... got the expected lookup response');

                $this->send( $service, [
                    *eServiceRequest => ( $sid, $action, $args, $this )
                ]);
            },

            *eServiceResponse => sub ($this, $sid, $return) {
                my $request = session_get( $sid );

                my %expected = (
                    1 => 4,
                    2 => 20,
                    4 => 0.2,
                    5 => -8,
                );

                ok($expected{$sid}, '... got the expected session id with service response');
                is($return, $expected{$sid}, '... got the expected service response');
            },

            # Errors ...

            *eServiceError => sub ($this, $sid, $error) {
                my $request = session_get( $sid );

                like($error, qr/^Invalid Action\: multiply/, '... got the expected service error');
                is($sid, 4, '... got the expected session id for service error');
            },

            *eServiceRegistryLookupError => sub ($this, $sid, $error) {
                my $request = session_get( $sid );

                is($error, 'Could not find service(baz.example.com)', '... got the expected lookup error');
                is($sid, 3, '... got the expected session id for lookup error');
            },

        }
    }
}

sub init ($this, $msg=[]) {

    my $client = $this->spawn( ServiceClient() );
    isa_ok($client, 'ELO::Core::Process');

    $this->send( $client, [
        *eServiceClientRequest => (
            'foo.example.com', *Ops::Add => [ 2, 2 ]
        )
    ]);

    $this->send( $client, [
        *eServiceClientRequest => (
            'bar.example.com', *Ops::Mul => [ 10, 2 ]
        )
    ]);

    $this->send( $client, [
        *eServiceClientRequest => (
            'baz.example.com', *Ops::Mul => [ 10, 2 ]
        )
    ]);

    $this->send( $client, [
        *eServiceClientRequest => (
            'bar.example.com', *Ops::Div => [ 2, 10 ]
        )
    ]);

    $this->send( $client, [
        *eServiceClientRequest => (
            'foo.example.com', *Ops::Sub => [ 2, 10 ]
        )
    ]);
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

__END__
