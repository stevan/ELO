#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::ELO;

use List::Util 'first';
use Data::Dumper;

use ELO;

my $CURRENT_CNT = 0;

actor bounce => sub ($env, $msg) {
    match $msg, +{
        up => sub ($cnt) {
            sys::out::print("bounce(UP) => $cnt");
            msg( PID, down => [$cnt+1] )->send;
            $CURRENT_CNT = $cnt;
        },
        down => sub ($cnt) {
            sys::out::print("bounce(DOWN) => $cnt");
            msg( PID, up => [$cnt+1] )->send;
            $CURRENT_CNT = $cnt;
        },
        peek => sub ($expected) {
            ok($CURRENT_CNT == $expected, "... peek bounce count ($CURRENT_CNT) is $expected");
        },
        finish => sub ($expected) {
            ok($CURRENT_CNT == $expected, "... bounce count ($CURRENT_CNT) is $expected");
            sig::kill(PID)->send;
        }
    };
};

actor main => sub ($env, $msg) {
    sys::out::print("-> main starting ...");

    my $bounce = proc::spawn( 'bounce' );

    msg( $bounce, up => [1] )->send;

    sig::timer( 5,  msg( $bounce, peek => [ 5 ] ) )->send;
    sig::timer( 3,  msg( $bounce, peek => [ 3 ] ) )->send;

    sig::timer( 10, msg( $bounce, finish => [ 10 ] ) )->send;
};

# loop ...
ok loop( 20, 'main' ), '... the event loop exited successfully';

done_testing;

=pod

actor Bounce => sub ($env) {

    has count => sub { 0 };

    action up => sub ($self) {
        sys::out::print("$self(UP) => ".$self->count );
        $self->count( $self->count + 1 );
        $self->send( down => [] );
    };

    action down => sub ($self) {
        sys::out::print("$self(DOWN) => ".$self->count);
        $self->count( $self->count + 1 );
        $self->send( up => [] );
    };

    action finish => sub ($self, $expected) {
        is($self->count, $expected, "... bounce count (".$self->count.") is $expected");
        $self->exit(1);
    };

};

actor main => sub ($env) {

    action _ => sub ($self) {
        sys::out::print("-> main starting ...");

        my $bounce = proc::spawn( 'Bounce' );

        $self->send( $bounce, up => [] );

        loop::timer( 10, msg( $bounce, finish => [ 10 ] ) );
    }
};

=cut

