#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors qw[ match ];
use ELO::Promise;

use constant DEBUG => $ENV{DEBUG} // 0;

sub StateTester ($this, $msg) {

    state $id = 0;
    $id++;

    my    $bar = [0];
    state $foo = [0];

    state sub update_foo() { ++$foo->[0] }

    my sub update_counters() {
        update_foo();
        ++$bar->[0];
        #warn '[foo => '.$foo->[0].', bar => '.$bar->[0].']';
    }

    match $msg, +{
        eTest => sub {
            warn $this->pid.' -> eTest = '.$this.' -> [foo => '.$foo.', bar => '.$bar.', id => '.$id.']';
            $this->send_to_self([ eAgain => $this->pid ]);
        },
        eAgain => sub ($from_pid) {
            update_counters();
            warn $this->pid.' -> eAgain (from: '.$from_pid.') = '.$this.' -> [foo => '.$foo.', bar => '.$bar.', id => '.$id.']';
        }
    }
}

sub init ($this, $msg=[]) {

    my $tester1 = $this->spawn( StateTester => \&StateTester );
    my $tester2 = $this->spawn( StateTester => \&StateTester );
    my $tester3 = $this->spawn( StateTester => \&StateTester );

    warn $tester1->pid." -> Tester1 = $tester1";
    warn $tester2->pid." -> Tester2 = $tester2";
    warn $tester3->pid." -> Tester3 = $tester3";

    $this->send( $tester1, [ eTest => () ] );
    $this->send( $tester2, [ eTest => () ] );
    $this->send( $tester3, [ eTest => () ] );
}

ELO::Loop->new->run( \&init );


__END__

=pod

sub Timer ($this, $msg) {

    warn Dumper +{ TimerGotMessage => 1, $this->pid => $msg } if DEBUG > 3;

    state $_active = 0;
    state $_timeout;
    state $_callback;

    state sub handle_timer ($this) {
        return unless $_active;
        if ($_timeout <= 0) {
            $this->send( @$_callback );
        }
        else {
            $this->send_to_self([ eTimerTick => () ]);
        }
    }

    match $msg, +{

        eStartTimer => sub ($timeout, $callback) {
            warn $this->pid."::eStartTimer : $timeout"           if DEBUG;
            warn $this->pid."::eStartTimer : ".Dumper($callback) if DEBUG > 2;
            $_timeout  = $timeout;
            $_callback = $callback;
            $_active   = 1;
            handle_timer( $this );
        },

        eCancelTimer => sub () {
            warn $this->pid."::eCancelTimer" if DEBUG;
            $_active = 0;
        },

        eTimerTick => sub () {
            warn $this->pid."::eTimerTick : $_timeout" if DEBUG;
            $_timeout--;
            handle_timer( $this );
        },

    };
}

=cut
