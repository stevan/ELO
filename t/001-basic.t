#!perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use JSON 'encode_json';
use Data::Dumper;

use ok 'EventLoop';
use ok 'EventLoop::Process';

my $loop = EventLoop->new;

my ($proc1, $proc2);

$proc1 = EventLoop::Process->new(
    callback => sub ($proc, $loop, $env, $msg) {
        warn "In Proc1 :" . ($msg // 'undef') . ' => ' . encode_json($env);
        if (not $msg) {
            $env->{count}++ if $env->{started};
        }
        elsif ( $msg eq 'start' ) {
            $env->{started}++;
        }
        elsif ( $msg eq 'stop' ) {
            $loop->enqueue_message_for( $proc2->pid, 'exit' );
            delete $env->{started};
            $proc->exit;
        }
    }
);

$proc2 = EventLoop::Process->new(
    callback => sub ($proc, $loop, $env, $msg) {
        warn "In Proc2 :" . ($msg // 'undef') . ' => ' . encode_json($env);
        if ($msg && $msg eq 'exit') {
            $proc->exit;
        }
        else {
            $loop->enqueue_message_for( $proc1->pid, 'start' );
            $proc->sleep_for(10, sub {
                $loop->enqueue_message_for( $proc1->pid, 'stop' )
            });
        }
    }
);


$loop->add_process( $proc2 );
$loop->add_process( $proc1 );

my $env = $loop->run;

warn Dumper $env;

done_testing;
