#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

sub init ($this) {
    say "[".$this->pid."] hello world";

    my $greeter = $this->spawn('greet' => \&greeting);
    $this->send_to( $greeter, 'everyone');
    $this->send_to( $greeter, 'alemaal');

    $greeter->call("y'all");

    my $bounce1 = $this->spawn('bounce' => \&bounce);
    $this->send_to( $bounce1, 5 );

    $bounce1->call( 10 );

    my $bounce2 = $this->spawn('bounce' => \&bounce);
    $this->send_to( $bounce2, 3 );

    my $bounce_cb = $this->spawn('bounce_cb' => \&bounce_cb);
    $this->send_to( $bounce_cb, 7, $greeter );
}

sub greeting ($this, $name) {
    say "[".$this->pid."] hello $name"
}

sub bounce ($this, $bounces) {
    if ($bounces) {
        say "[".$this->pid."] boing! $bounces";
        $this->send_to_self( $bounces - 1 );
    }
    else {
        say "[".$this->pid."] plop!";
    }
}

sub bounce_cb ($this, $bounces, $cb) {
    if ($bounces) {
        $cb->call( "bounce CB($bounces)" );
        $this->send_to_self( $bounces - 1, $cb );
    }
    else {
        $cb->call( "plop($bounces)" );
    }
}

Loop->new->start( \&init, () );

# ...

package Process {
    use v5.24;
    use warnings;
    use experimental qw[ signatures lexical_subs postderef ];

    our $PIDS = 0;

    use parent 'UNIVERSAL::Object::Immutable';
    use slots (
        name => sub {},
        func => sub {},
        loop => sub {},
        # ...
        _pid => sub {},
    );

    sub BUILD ($self, $) {
        $self->{_pid} = sprintf '%03d:%s' => ++$PIDS, $self->{name}
    }

    sub pid ($self) { $self->{_pid} }

    sub call ($self, @args) {
        $self->{func}->( $self, @args );
    }

    sub spawn ($self, $name, $f) {
        $self->{loop}->create_process( $name, $f );
    }

    sub send_to ($self, $proc, @msg) {
        $self->{loop}->enqueue_msg([ $proc, @msg ]);
    }

    sub send_to_self ($self, @msg) {
        $self->{loop}->enqueue_msg([ $self, @msg ]);
    }
}

package Loop {
    use v5.24;
    use warnings;
    use experimental qw[ signatures lexical_subs postderef ];

    use parent 'UNIVERSAL::Object::Immutable';
    use slots (
        _proc_table => sub { +{} },
        _msg_queue  => sub { +[] },
    );

    sub create_process ($self, $name, $f) {
        my $proc = Process->new(
            name => $name,
            func => $f,
            loop => $self,
        );
        $self->{_proc_table}->{ $proc->pid } = $proc;
        return $proc;
    }

    sub enqueue_msg ($self, $msg) {
        push $self->{_msg_queue}->@* => $msg;
    }

    sub tick ($self) {

        my @inbox = $self->{_msg_queue}->@*;
        $self->{_msg_queue}->@* = ();

        while (@inbox) {
            my $msg = shift @inbox;
            my ($to_proc, @body) = @$msg;

            eval {
                $to_proc->call( @body );
                1;
            } or do {
                my $e = $@;
                die "Message to (".$to_proc->pid.") failed with msg(".(join ", " => @body).") because: $e";
            };
        }
    }

    sub loop ($self) {
        my $tick = 0;

        warn sprintf "-- tick(%03d) : starting\n" => $tick;

        while ( $self->{_msg_queue}->@* ) {
            warn sprintf "-- tick(%03d)\n" => $tick;
            $self->tick;
            $tick++
        }

        warn sprintf "-- tick(%03d) : exiting\n" => $tick;
    }

    sub start ($self, $f, @args) {
        my $main = $self->create_process('main', $f);
        $self->enqueue_msg([ $main, @args ]);
        $self->loop;
    }
}

1;
