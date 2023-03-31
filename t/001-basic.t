#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

sub init () {
    say "hello world";

    my $greet_pid = __spawn__('greet' => \&greeting);
    __send__($greet_pid, 'everyone');
    __send__($greet_pid, 'alemaal');

    my $bounce1_pid = __spawn__('bounce' => \&bounce);
    __send__($bounce1_pid, ($bounce1_pid, 5));

    my $bounce2_pid = __spawn__('bounce' => \&bounce);
    __send__($bounce2_pid, ($bounce2_pid, 3));

    my $bounce_cb_pid = __spawn__('bounce_cb' => \&bounce_cb);
    __send__($bounce_cb_pid, ($bounce_cb_pid, 7, [ $greet_pid ]));
}

sub greeting ($name) {
    say "hello $name"
}

sub bounce ($pid, $bounces) {
    if ($bounces) {
        say "boing! $bounces";
        __send__($pid, ($pid, $bounces - 1));
    }
    else {
        say "plop!";
    }
}

sub bounce_cb ($pid, $bounces, $cb) {
    if ($bounces) {
        say "boing CB! $bounces";
        __send__(@$cb, "bounce($bounces)");
        __send__($pid, ($pid, $bounces - 1, $cb));
    }
    else {
        __send__(@$cb, "plop($bounces)");
    }
}

# ...

my $PID = 0;

my @msg_queue;
my %proc_tbl;

sub __mkpid__ ($name) { sprintf '%03d:%s' => ++$PID, $name }

sub __send__ ($to_pid, @body) {
    push @msg_queue => [ $to_pid, @body ];
}

sub __spawn__ ($name, $f) {
    my $pid = __mkpid__($name);
    $proc_tbl{ $pid } = $f;
    return $pid;
}

sub __loop__ () {
    my $tick = 0;

LOOP:
    warn sprintf '- tick(%03d)' => $tick;

    my @inbox = @msg_queue;
    @msg_queue = ();

    while (@inbox) {

        my $msg = shift @inbox;

        my ($to_pid, @body) = @$msg;

        if ( my $proc = $proc_tbl{ $to_pid } ) {
            eval {
                $proc->( @body );
                1;
            } or do {
                my $e = $@;
                die "Message to ($to_pid) failed with msg(".(join ", " => @body).") because: $e";
            };
        }
    }

    $tick++;

    goto LOOP if @msg_queue;

    warn sprintf '- tick(%03d) : exiting' => $tick;
}

sub main () {
    my $init_pid = __spawn__('init', \&init);
    __send__($init_pid, ());
    __loop__();
}

main();

1;
