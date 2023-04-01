#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;


sub ServiceRegistry ($this, $msg) {

    state $services = +{};

    match $msg, +{

        # Requests ...

        # $request  = eServiceRegistryLookupRequest  [ sid : SID, name : Str, caller : PID ]]
        # $response = eServiceRegistryLookupResponse [ sid : SID, address : Str ]
        # $error    = eServiceRegistryLookupError    [ sid : SID, error   : Str ]
        eServiceRegistryLookupRequest => sub ($sid, $name, $caller) {
            if ( my $address = $sevices->{ $name } ) {
                $this->send( $caller, eServiceRegistryLookupResponse => $sid, $address );
            }
            else {
                $this->send( $caller,
                    eServiceRegistryLookupError => (
                        $sid,  'Could not find service('.$name.')'
                    )
                );
            }
        }
    }
}


sub Service ($this, $msg) {

    match $msg, +{

        # $request  = eServiceRequest  [ sid : SID, action : Str, args : <Any>, caller : PID ]
        # $response = eServiceResponse [ sid : SID, return : <Any> ]
        # $error    = eServiceError    [ sid : SID, error : Str ]
        eServiceRequest => sub ($sid, $action, $args, $caller) {
            my ($x, $y) = @$args;

            eval {
                $this->send(
                    $caller,
                    eServiceResponse => (
                        $sid,
                        ($action eq 'add') ? ($x + $y) :
                        ($action eq 'sub') ? ($x - $y) :
                        ($action eq 'mul') ? ($x * $y) :
                        ($action eq 'div') ? ($x / $y) :
                        die "Invalid Action: $action"
                    )
                );
                1;
            } or do {
                my $e = $@;
                $this->send( $caller, eServiceError => ( $sid, $e ) );
            };
        }
    }
}


sub ServiceClient ($this, $msg) {

    state $registry = $this->spawn( ServiceRegistry => \&ServiceRegistry );
    state $sessions = +{};
    state $next_sid = 0;

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

            $this->send(
                $registry,
                eServiceRegistryLookupRequest => (
                    $sid,       # my session id
                    $url,       # the url of the service
                    $this->pid  # where to send the response
                )
            );
        },


        # Responses ...

        eServiceRegistryLookupResponse => sub ($sid, $address) {
            my $s = session_get( $sid );
            my ($url, $action, $args) = $s->@*;
            # update the address
            $s->[0] = [ $url, $address ];

            $this->send(
                $address,
                eServiceRequest => ( $sid, $action, $args )
            );
        },

        eServiceResponse => sub ($sid, $return) {
            # Horray ... where do we sent this??
        }

        # Errors ...

        eServiceError => sub ($sid, $error) {
            my $request = session_get( $sid );
            # ...
        },

        eServiceRegistryLookupError => sub ($sid, $error) {
            my $request = session_get( $sid );
            # ...
        }

    }
}


