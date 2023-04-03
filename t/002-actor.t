#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;

use constant DEBUG => $ENV{DEBUG} // 0;

sub match ($msg, $table) {
    my ($event, @args) = @$msg;
    my $cb = $table->{ $event } // die "No match for $event";
    eval {
        $cb->(@args);
        1;
    } or do {
        warn "!!! Died calling msg(".(join ', ' => map { ref $_ ? '['.(join ', ' => @$_).']' : $_ } @$msg).")";
        die $@;
    };
}

sub Service ($this, $msg) {

    warn Dumper +{ $this->pid => $msg } if DEBUG;

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

    warn Dumper +{ $this->pid => $msg } if DEBUG;

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

    warn Dumper +{ $this->pid => $msg } if DEBUG;

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

            $this->send( $registry, [
                eServiceRegistryLookupRequest => (
                    $sid,  # my session id
                    $url,  # the url of the service
                    $this  # where to send the response
                )
            ]);
        },


        # Responses ...

        eServiceRegistryLookupResponse => sub ($sid, $service) {
            my $s = session_get( $sid );
            my ($url, $action, $args) = $s->@*;
            # update the service
            $s->[0] = [ $url, $service ];

            $this->send( $service, [
                eServiceRequest => ( $sid, $action, $args, $this )
            ]);
        },

        eServiceResponse => sub ($sid, $return) {
            my $request = session_get( $sid );
            # Horray ... where do we sent this??
            warn Dumper +{ eServiceResponse => $return, sid => $sid };
        },

        # Errors ...

        eServiceError => sub ($sid, $error) {
            my $request = session_get( $sid );
            # ...
            warn Dumper +{ eServiceError => $error, sid => $sid };
        },

        eServiceRegistryLookupError => sub ($sid, $error) {
            my $request = session_get( $sid );
            # ...
            warn Dumper +{ eServiceRegistryLookupError => $error, sid => $sid };
        },

    }
}

sub init ($this, $msg=[]) {
    my $client = $this->spawn( Service  => \&ServiceClient );

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

ELO::Loop->new->run( \&init, () );


__END__

    # Registry - lookup

    $this->send( $registry,
        [ eServiceRegistryLookupRequest => ( 'ID:001', 'foo.example.com', $debugger ) ]
    );

    $this->send( $registry,
        [ eServiceRegistryLookupRequest => ( 'ID:001', 'bar.example.com', $debugger ) ]
    );

    # Registry - lookup fail, update and lookup

    my $baz = $this->spawn( BazService  => \&Service );

    $this->send( $registry,
        [ eServiceRegistryLookupRequest => ( 'ID:001', 'baz.example.com', $debugger ) ]
    );
    $this->send( $registry,
        [ eServiceRegistryUpdateRequest => ( 'ID:001', 'baz.example.com', $baz->pid, $debugger ) ]
    );

    my $registry_2 = $this->spawn( Registry2 => \&ServiceRegistry );

    $this->send( $registry_2,
        [ eServiceRegistryLookupRequest => ( 'ID:001', 'baz.example.com', $debugger ) ]
    );

    # Service - test

    $this->send( $service,
        [ eServiceRequest => ( 'ID:001', add => [2, 2], $debugger->pid ) ]
    );

    # Service - error

    $this->send( $service->pid,
        [ eServiceRequest => ( 'ID:001', addd => [2, 2], $debugger ) ]
    );
