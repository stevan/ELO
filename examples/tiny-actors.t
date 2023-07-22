#!perl

use v5.38;

use Time::HiRes qw[ sleep ];

my %TABLE;
my @IDLE;

sub spawn ($builder, @args) {
    state $PIDS = 0;
    my $a = $builder->( @args );
    $TABLE{ ($a->{pid} = ++$PIDS) } = $a;
    say "Spawning (".$a->{pid}.")";
    $a;
}

sub despawn ($a) {
    push @IDLE => sub {
        my $pid = ref $a ? $a->{pid} : $a;
        delete $TABLE{ $pid };
        say "Despawning ($pid)";
    }
}

my @Q, @DLQ;

sub send_msg ($msg) {
    push @Q => $msg;
}

sub loop ($init, $delay=undef) {
    state $tail = ('-' x 60);
    say "start $tail";

    $init->();

    while (1) {
        say "tick $tail";

        my @msgs = @Q;
              @Q = ();

        while (@msgs) {
            my ($to, $label, @msg) = @{ (shift @msgs) // [] };
            if ( my $a = $TABLE{ $to } ) {
                say "... calling ($label) for PID(".$a->{pid}.") with (".(join ', ' => @msg).")";
                if ( my $r = $a->{behavior}->{$label} ) {
                    $r->( $a, @msg );
                }
                else {
                    push @DLQ => [ 'LABEL NOT FOUND', $to, $label, @msg ];
                }
            }
            else {
                push @DLQ => [ 'ACTOR NOT FOUND', $to, $label, @msg ];
            }
        }

        if ( @IDLE ) {
            say "idle $tail";
            (shift @IDLE)->() while @IDLE;
        }

        last unless @Q;
        sleep($delay) if defined $delay;
    }

    if ( @IDLE ) {
        say "cleanup $tail";
        (shift @IDLE)->() while @IDLE;
    }

    say "exit $tail";

    if ( @DLQ ) {
        say "Dead Letter Queue";
        foreach my $msg ( @DLQ ) {
            say join ', ' => @$msg;
        }
    }

    if ( %TABLE ) {
        say "Zombies";
        say join ", " => sort { $a <=> $b } keys %TABLE;
    }
}

sub PingPong ($state) {

    return +{
        state    => $state,
        behavior => {
            'ping' => sub ($a, $caller) {
                if ($a->{state}->{ping} < $a->{state}->{max}) {
                    say "got ping(".$a->{state}->{name}.")[".$a->{state}->{ping}."] <= ".$a->{state}->{max};
                    send_msg([ $caller, pong => $a->{pid} ]);
                    $a->{state}->{ping}++;
                }
                else {
                    say "!!! ending at(".$a->{state}->{name}.")[".$a->{state}->{ping}."] <= ".$a->{state}->{max};
                    despawn( $a );
                    despawn( $caller );
                }
            },
            'pong' => sub ($a, $caller) {
                if ($a->{state}->{pong} < $a->{state}->{max}) {
                    say "got pong(".$a->{state}->{name}.")[".$a->{state}->{pong}."] <= ".$a->{state}->{max};
                    send_msg([ $caller, ping => $a->{pid} ]);
                    $a->{state}->{pong}++;
                }
                else {
                    say "!!! ending at(".$a->{state}->{name}.")[".$a->{state}->{pong}."] <= ".$a->{state}->{max};
                    despawn( $a );
                    despawn( $caller );
                }
            },
        }
    }
}

sub init () {
    foreach ( 1 .. 100 ) {
        my $max = int(rand(10));
        my $Ping = spawn( \&PingPong, { name => "Ping($_)", pong => 0, max => $max } );
        my $Pong = spawn( \&PingPong, { name => "Pong($_)", ping => 0, max => $max } );

        send_msg([ $Ping->{pid}, pong => $Pong->{pid} ]);
    }
}

loop( \&init, 0.5 );








