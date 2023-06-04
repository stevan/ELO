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
use ELO::Types    qw[ :core :events ];
use ELO::Actors   qw[ receive match ];
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

And it is fairly performant as well, here is an example creating 1_000_000 actors. On my machine this will take just under a minute, and consumer just over 1.5GB of memory. Not too bad, and according to [this very artificial benchmark](https://pkolaczk.github.io/memory-consumption-of-async/), it puts `ELO` ahead of Go, Python and Elixir ... and pretty darn close to Java.

```perl
use v5.36;

use ELO::Loop;
use ELO::Actors qw[ setup IGNORE ];

sub Actor ($id) {
    state $loop; # the loop is always the same, ....

    setup sub ($this) {
        # so we save some time and effectively
        # turn it into a constant here ;)
        $loop //= $this->loop;

        # create a timer for sleep for 10 seconds and exit
        $loop->add_timer( 10, sub { $this->exit(0) });

        # we will have no messages to `match`, so
        # why waste an instance here, use IGNORE
        # so have a `receive` that does nothing
        IGNORE;
    };
}

sub init ($this, $) {
    my $countdown = 1_000_000;
    $this->spawn( Actor( $countdown-- ) ) while $countdown;
}

ELO::Loop->run( \&init );

```

And of course, this is perl, so we can do this all in one line. If you want to see timing info, use `/usr/bin/time` and watch the memory your preferred way. And yes, this fits in a tweet ;)
```
perl -Ilib -MELO::Loop -MELO::Actors=setup,IGNORE -E 'my$a=0;sub A($i){state$l;setup sub($t){print++$a,"\r";($l//=$t->loop)->add_timer(2,sub{print$a--,"\r";$t->exit(0)});IGNORE}};ELO::Loop->run(sub($t,$){say"START";my$x=10**6;$t->spawn(A($x))while$x--;say"\nEXIT"});say"\nDONE";'
```







