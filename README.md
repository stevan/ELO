# ELO

### Event Loop Orchestra

This is an experiment in adding simple co-operative message passing style concurrency for Perl. 

```
use ELO::Loop;

sub HelloWorld ($this, $msg) {
    my ($name) = @$msg;

    say "Hello $name from ".$this->pid;
}

sub main ($this, $msg) {
    my $hello = $this->spawn('HelloWorld' => \&HelloWorld);
    $this->send( $hello, ['World']);
}

ELO::Loop->new->run( \&main );

```

With an Actor system implemented on top.

```
use ELO::Loop;
use ELO::Actors qw[ match ];

sub Ping ($this, $msg) {

    state $count = 0;

    match $msg, state $handlers = +{
        eStartPing => sub ( $pong ) {
            $count++;
            say "Starting with ($count)";
            $this->send( $pong, [ ePing => $this ]);
        },
        ePong => sub ( $pong ) {
            $count++;
            say "Pong with ($count)";
            if ( $count > 10 ) {
                say "... Stopping Ping";
                $this->send( $pong, [ 'eStop' ]);
            }
            else {
                $this->send( $pong, [ ePing => $this ]);
            }
        },
    };
}

sub Pong ($this, $msg) {

    match $msg, state $handlers = +{
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

ELO::Loop->new->run( \&init );
```

