#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Term::ANSIColor ':constants';

#use Test::More;
use Data::Dumper;

use ELO;
use ELO::Mailbox;

warn "INIT $$\n";

my $mbox = ELO::Mailbox->new;

actor 'bounce' => sub ($env, $msg) {

    my $me = $env->{parent} ? CYAN('parent') : YELLOW('child');
    $me .= RESET;

    match $msg, +{
        send => sub ($msg) {
            sys::out::print(PID." sending(".$msg->{count}.") in $$ $me");
            $mbox->outbox->send( $msg );
            msg(PID, recv => [])->send; # go back to listening ...
        },
        recv => sub () {
            my $data = $mbox->inbox->recv;
            unless (defined $data) {
                if (my $retries = $mbox->inbox->should_try_again) {
                    sys::err::log(PID." try again in $$ $me // # attempts : $retries //");
                    msg(PID, recv => [])->send;
                }
                else {
                    msg(PID, finish => [])->send;
                }
            }
            else {
                sys::out::print(PID." got(".$data->{count}.") in $$ $me");
                $data->{count}++;
                msg(PID, send => [ $data ])->send;
            }
        },
        finish => sub () {
            sys::out::print(PID." finishing in $$ $me");
            sig::kill(PID)->send;
            $mbox->outbox->close;
        }
    };
};

actor 'parent_main' => sub ($env, $msg) {
    sys::out::print("-> starting parent main $$");

    my $bounce = proc::spawn('bounce', parent => 1);

    msg($bounce, recv => [])->send;

    sig::timer( 100, msg($bounce, finish => []))->send;
};

actor 'child_main' => sub ($env, $msg) {
    sys::out::print("-> starting child main $$");

    my $bounce = proc::spawn('bounce', child => 1);

    msg($bounce, send => [ { count => 0 } ])->send;
    msg($bounce, recv => [])->send;
};

if(my $pid = fork()) {
    warn RED "Parent $$", RESET "\n";

    my $log = IO::File->new('>parent.log') or die "Could not open log because: $!";
    $ELO::IO::STDOUT = $log;
    $ELO::IO::STDERR = $log;

    loop(100_000, 'parent_main');

    exit;
}
elsif(defined $pid) {
    warn GREEN "Child $$", RESET "\n";

    my $log = IO::File->new('>child.log') or die "Could not open log because: $!";
    $ELO::IO::STDOUT = $log;
    $ELO::IO::STDERR = $log;

    loop(100_000, 'child_main');

    exit;
}


1;
