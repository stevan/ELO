# ELO

### Event Loop Orchestra

This is an experiment in adding simple co-operative message passing style concurrency for Perl. 

```perl
use ELO::Loop;

sub HelloWorld ($this, $msg) {
    my ($name) = @$msg;

    say "Hello $name from ".$this->pid;
}

sub main ($this, $msg) {
    my $hello = $this->spawn('HelloWorld' => \&HelloWorld);

    $this->send( $hello, ['World']);
    # or use the operator syntax
    $this >>= [ $hello, ['World']];
}

ELO::Loop->run( \&init );
```

With an Actor system implemented on top.

```perl
use ELO::Loop;
use ELO::Actors qw[ match ];
use Hash::Util  qw[ fieldhash ];

sub Ping ($this, $msg) {

    # use inside-out objects
    # for per-Actor state
    fieldhash state %count;

    match $msg, +{
        eStartPing => sub ( $pong ) {
            $count{$this}++;
            say $this->pid." Starting with (".$count{$this}.")";
            $this->send( $pong, [ ePing => $this ]);
        },
        ePong => sub ( $pong ) {
            $count{$this}++;
            say $this->pid." Pong with (".$count{$this}.")";
            if ( $count{$this} >= 5 ) {
                say $this->pid." ... Stopping Ping";
                $this->send( $pong, [ 'eStop' ]);
            }
            else {
                $this->send( $pong, [ ePing => $this ]);
            }
        },
    };
}

sub Pong ($this, $msg) {

    match $msg, +{
        ePing => sub ( $ping ) {
            say "... Ping";
            $this->send( $ping, [ ePong => $this ]);
        },
        eStop => sub () {
            say "... Stopping Pong";
        },
    };
}

sub init ($this, $msg=[]) {
    my $ping = $this->spawn( Ping  => \&Ping );
    my $pong = $this->spawn( Pong  => \&Pong );

    $this->send( $ping, [ eStartPing => $pong ]);

}

ELO::Loop->run( \&init );
```

And a Promise mechanism to coordinate between Actors.

```perl
use ELO::Loop;
use ELO::Actors   qw[ match ];
use ELO::Promises qw[ promise ];

sub Service ($this, $msg) {

    match $msg, state $handlers = +{
        eServiceRequest => sub ($action, $args, $promise) {
            eval {
                my ($x, $y) = @$args;

                $promise->resolve([
                    eServiceResponse => (
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
                $promise->reject([ eServiceError => ( $e ) ]);
            };
        }
    }
}

sub init ($this, $msg=[]) {
    my $service = $this->spawn( Service  => \&Service );

    my $promise = promise;

    $this->send( $service,
        [ eServiceRequest => ( add => [ 2, 2 ], $promise ) ]
    );

    $promise->then(
        sub ($event) {
            my ($etype, $result) = @$event;
            say "Got Result: $result";
        }
    );
}

ELO::Loop->run( \&init, with_promises => 1 );
```
