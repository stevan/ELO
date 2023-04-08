#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;
use ELO::Actors qw[ match ];
use ELO::Promise;

use constant DEBUG => $ENV{DEBUG} || 0;

# NOTE:
# We need to add tests that verify
# the hex address of certain things
# match

sub StateTester ($this, $msg) {

    state $id = 0; # shared across all instances
    $id++;

    my    $bar = [0]; # created on every request
    state $foo = [0]; # shared across all instances

    # since this closes over a `state` var
    # it can be a `state` sub ...
    state sub update_foo() { ++$foo->[0] }

    # since this closes over the `my` var
    # it needs to be a `my` sub. But it should
    # be noted that this sub gets re-created
    # every request, so is not ideal
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

1;
