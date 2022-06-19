#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::Differences;
use Test::ELO;

use List::Util 'first';
use Data::Dumper;

use ELO;
use ELO::Msg;
use ELO::Actors;
use ELO::IO;

package Actor::Base {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    use ELO;

    use parent 'UNIVERSAL::Object';
    use slots;

    sub new_actor ($class) {
        return sub ($env, $msg) {
            my $self = $env->{__SELF__} //= $class->new($env);
            $self->RECIEVE($msg);
        }
    }

    sub RECIEVE ($self, $msg) {
        my $cb = $self->can($msg->action) // die "No match for ".$msg->action;
        eval {
            $cb->($self, $msg->body->@*);
            1;
        } or do {
            warn "Died calling msg(".(join ', ' => map { ref $_ ? '['.(join ', ' => @$_).']' : $_ } @$msg).")";
            die $@;
        };
    }

    sub exit ($reason) {
        sig::kill(PID)->send;
    }
}

package TestObserver {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    use Test::Differences;

    use ELO;
    use ELO::IO;

    our @ISA; BEGIN{ @ISA = ('Actor::Base') }
    use slots (
        got => sub { +{} },
        expected => sub {},
    );

    sub on_next ($self, $val) {
        out::print(PID." got val($val)")->send;
        $self->{got}->{$val}++;
    }

    sub on_error ($self, $e) {
        err::log(PID." got error($e)")->send if DEBUG;
        $self->exit($e);
    }

    sub on_completed ($self) {
        err::log(PID." completed")->send if DEBUG;
        err::log(PID." observed values: [" . (join ', ' => map { "$_/".$self->{got}->{$_} } sort { $a <=> $b } keys $self->{got}->%*) . "]")->send if DEBUG;
        $self->exit();
        eq_or_diff( [ sort { $a <=> $b } keys $self->{got}->%* ], $self->{expected}, '... got the expected values for '.PID);
        eq_or_diff( [ values $self->{got}->%* ], [ map 1, $self->{expected}->@* ], '... got the expected value counts (all 1) for '.PID);
    }
}

package SimpleObserver {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    our @ISA; BEGIN{ @ISA = ('Actor::Base') }
    use slots (
        on_next      => sub{ die 'An `on_next` value is required' },
        on_completed => sub{ die 'An `on_completed` value is required' },
        on_error     => sub{ die 'An `on_error` value is required' },
    );

    sub on_next ($self, $val) { $self->{on_next}->( $val ) }

    sub on_error ($self, $e) {
        $self->{on_error}->( $e );
        $self->exit($e);
    }

    sub on_completed ($self) {
        $self->{on_completed}->();
        $self->exit();
    }
}

package MapObservable {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    use ELO;
    use ELO::Msg;

    our @ISA; BEGIN{ @ISA = ('Actor::Base') }
    use slots (
        sequence => sub { die 'A `sequence` (Observable) is required' },
        f        => sub { die 'A `f` (function) is required' },
        # private ...
        _subscribers => sub {}
    );

    sub subscribe ($self, $observer) {
        my $self_pid = PID;

        my $map = proc::spawn('SimpleObserver',
            on_next => sub ($val) {
                msg($observer, on_next => [ $self->{f}->( $val ) ])->send;
            },
            on_error => sub ($e) {
                msg($observer, on_error => [ $e ])->send;
            },
            on_completed => sub () {
                msg($observer, on_completed => [])->send;
                msg($self_pid, on_completed => [] )->send;
            },
        );

        msg( $self->{sequence}, subscribe => [ $map ])->send;

        $self->{_subscribers}++;
    }

    sub on_completed ($self) {
        $self->{_subscribers}--;
        if ($self->{_subscribers} <= 0) {
            sig::kill(PID)->send;
        }
    }
}

package SimpleObservable {
    use v5.24;
    use warnings;
    use experimental 'signatures', 'postderef';

    use ELO;
    use ELO::Msg;

    our @ISA; BEGIN{ @ISA = ('Actor::Base') }
    use slots (
        # private ...
        _subscribers => sub {}
    );

    sub subscribe ($self, $observer) {

        err::log("SimpleObserveable started, calling ($observer)")->send if DEBUG;

        sequence(
            (map msg( $observer, on_next => [ $_ ] ), 0 .. 10 ),
            msg( $observer, on_completed => [] ),
            msg( PID, on_completed => [] ),
        )->send;

        $self->{_subscribers}++;
    }

    sub on_completed ($self) {
        $self->{_subscribers}--;
        if ($self->{_subscribers} <= 0) {
            sig::kill(PID)->send;
        }
    }
}

actor TestObserver     => TestObserver->new_actor;
actor SimpleObserver   => SimpleObserver->new_actor;
actor MapObservable    => MapObservable->new_actor;
actor SimpleObservable => SimpleObservable->new_actor;

actor main => sub ($env, $msg) {
    out::print("-> main starting ...")->send;

    my $simple = proc::spawn('SimpleObservable');
    my $map    = proc::spawn('MapObservable',
        sequence => $simple,
        f        => sub ($val) { $val + 100 }
    );

    my $tester     = proc::spawn('TestObserver', expected => [ 0 .. 10 ]);
    my $map_tester = proc::spawn('TestObserver', expected => [ map { $_+100 } 0 .. 10 ]);

    msg($simple, 'subscribe' => [ $tester ])->send;
    msg($map,    'subscribe' => [ $map_tester ])->send;
};

# loop ...
ok loop( 100, 'main' ), '... the event loop exited successfully';

done_testing;

