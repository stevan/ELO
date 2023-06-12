# ELO

### Event Loop Orchestra

Simple co-operative message passing style concurrency for Perl.

```perl
use ELO::Loop;

sub HelloWorld ($this, $msg) {
    my ($name) = @$msg;

    say "Hello $name from ".$this->pid;
}

sub init ($this, $msg) {
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
use ELO::Types  qw[ :core :events ];
use ELO::Actors qw[ receive ];

protocol *Ping => sub {
    event *eStartPing => ( *Process );
    event *ePong      => ( *Process );
};

protocol *Pong => sub {
    event *eStopPong => ();
    event *ePing     => ( *Process );
};

sub Ping () {

    my $count = 0;

    receive[*Ping], +{
        *eStartPing => sub ( $this, $pong ) {
            $count++;
            say $this->pid." Starting with (".$count.")";
            $this->send( $pong, [ *ePing => $this ]);
        },
        *ePong => sub ( $this, $pong ) {
            $count++;
            say $this->pid." Pong with (".$count.")";
            if ( $count >= 5 ) {
                say $this->pid." ... Stopping Ping";
                $this->send( $pong, [ 'eStop' ]);
            }
            else {
                $this->send( $pong, [ *ePing => $this ]);
            }
        },
    };
}

sub Pong () {

    receive[*Pong], +{
        *ePing => sub ( $this, $ping ) {
            say "... Ping";
            $this->send( $ping, [ *ePong => $this ]);
        },
        *eStop => sub ( $this ) {
            say "... Stopping Pong";
        },
    };
}

sub init ($this, $msg=[]) {
    my $ping = $this->spawn( Ping() );
    my $pong = $this->spawn( Pong() );

    $this->send( $ping, [ *eStartPing => $pong ]);
}

ELO::Loop->run( \&init );
```

And a Promise mechanism to coordinate between Actors.

```perl
use experimental 'try';

use ELO::Loop;
use ELO::Types    qw[ :core :events ]; # match is exported with :core
use ELO::Actors   qw[ receive ];
use ELO::Promises qw[ promise ];

enum *MathOps => (
    *MathOps::Add,
    *MathOps::Sub,
    *MathOps::Mul,
    *MathOps::Div,
);

protocol *ServiceProtocol => sub {
    event *eServiceRequest  => ( *MathOps, [ *Int, *Int ], *Promise );
    event *eServiceResponse => ( *Int );
    event *eServiceError    => ( *Str );
};

sub Service () {

    receive[*ServiceProtocol], +{
        *eServiceRequest => sub ($this, $action, $args, $promise) {
            try {
                my ($x, $y) = @$args;

                $promise->resolve([
                    *eServiceResponse => (
                        match [ *MathOps, $action ] => {
                            *MathOps::Add => sub () { $x + $y },
                            *MathOps::Sub => sub () { $x - $y },
                            *MathOps::Mul => sub () { $x * $y },
                            *MathOps::Div => sub () { $x / $y },
                        }
                    )
                ]);
            } catch ($e) {
                chomp $e;
                $promise->reject([ *eServiceError => ( $e ) ]);
            }
        }
    }
}

sub init ($this, $msg=[]) {
    my $service = $this->spawn( Service() );

    my $promise = promise;

    $this->send( $service,
        [ *eServiceRequest => ( add => [ 2, 2 ], $promise ) ]
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

See also `EXAMPLES.md`
