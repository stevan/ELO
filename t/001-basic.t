#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

sub init ($this) {
    say "hello world";

    my $greeter = $this->loop->spawn('greet' => \&greeting);
    $this->send_to( $greeter, 'everyone');
    $this->send_to( $greeter, 'alemaal');

    my $bounce1 = $this->loop->spawn('bounce' => \&bounce);
    $this->send_to( $bounce1, 5 );

    my $bounce2 = $this->loop->spawn('bounce' => \&bounce);
    $this->send_to( $bounce2, 3 );

    my $bounce_cb = $this->loop->spawn('bounce_cb' => \&bounce_cb);
    $this->send_to( $bounce_cb, 7, [ $greeter ] );
}

sub greeting ($this, $name) {
    say "hello $name"
}

sub bounce ($this, $bounces) {
    if ($bounces) {
        say "boing! $bounces";
        $this->send_to_self( $bounces - 1 );
    }
    else {
        say "plop!";
    }
}

sub bounce_cb ($this, $bounces, $cb) {
    if ($bounces) {
        say "boing CB! $bounces";
        $this->send_to( @$cb, "bounce($bounces)" );
        $this->send_to_self( $bounces - 1, $cb );
    }
    else {
        $this->send_to( @$cb, "plop($bounces)" );
    }
}

sub main () {
    my $loop = Loop->new;
    my $init = $loop->spawn('init', \&init);
    $loop->enqueue_msg([ $init, () ]);
    $loop->loop;
}

main();

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

    sub name ($self) { $self->{name} }
    sub func ($self) { $self->{func} }
    sub loop ($self) { $self->{loop} }

    sub pid ($self) { $self->{_pid} }

    sub call ($self, @args) {
        $self->{func}->( $self, @args );
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

    sub spawn ($self, $name, $f) {
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

    sub loop ($self) {
        my $tick = 0;

    LOOP:
        warn sprintf '- tick(%03d)' => $tick;

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

        $tick++;

        goto LOOP if $self->{_msg_queue}->@*;

        warn sprintf '- tick(%03d) : exiting' => $tick;
    }

}

1;
