
# ELO

### Event Loop Orchestra

```
use ELO;
use ELO::Msg;
use ELO::Actors;
use ELO::IO;

actor Bounce => sub ($env, $msg) {
    match $msg, +{
        up => sub ($count=0) {
            out::print("bounce(UP) => $count")->send;
            msg( PID, down => [$count+1] )->send;
        },
        down => sub ($count=0) {
            out::print("bounce(DOWN) => $count")->send;
            msg( PID, up => [$count+1] )->send;
        },
        finish => sub ($expected) {
            sig::kill(PID)->send;
        }
    };
};

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    # spawn a Bounce actor
    my $bounce = proc::spawn( 'Bounce' );

    # tell it to start bouncing from
    msg( $bounce, down => [] )->send;

    # set a timer signal to finish after 10 ticks ...
    sig::timer( 10, msg( $bounce, finish => [ 10 ] ) )->send;
};

# loop ...
loop( 20, 'main' );

```

