package ELO::IO;
# ABSTRACT: Event Loop Orchestra

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';

use ELO::Actors;

use ELO::Loop;

use ELO::Debug;

our $STDIN  = \*STDIN;
our $STDOUT = \*STDOUT;
our $STDERR = \*STDERR;

sub QUIET () {
    ELO->DEBUG()
        # if we are DEBUG-ing, do not be quiet
        ? 0
        # if we are testing, be quiet
        : $Test::ELO::TESTING
}

sub sys::err::logf ($fmt, $values, $caller=CALLER()) {
    my $prefix = ON_RED "LOG (".PID().") !!". RESET " ";
    $STDERR->print(
        $prefix,
        (sprintf $fmt, @$values),
        FAINT " >> [$caller]\n",
        RESET
    ) unless QUIET();
}

sub sys::err::log ($msg, $caller=CALLER()) {
    my $prefix = ON_RED "LOG (".PID().") !!". RESET " ";
    $STDERR->print(
        $prefix,
        $msg,
        FAINT " >> [$caller]\n",
        RESET
    ) unless QUIET();
}

sub sys::out::printf ($fmt, @values) {
    my $prefix = ON_GREEN "OUT (".PID().") >>". RESET " ";
    $STDOUT->print( $prefix, (sprintf $fmt, @values), "\n" ) unless QUIET();
}

sub sys::out::print ($value) {
    my $prefix = ON_GREEN "OUT (".PID().") >>". RESET " ";
    $STDOUT->print( $prefix, $value, "\n" ) unless QUIET();
}

sub sys::in::read ($prompt, $callback) {
    my $prefix = ON_CYAN "IN (".PID().") <<". RESET " ";

    $prompt //= '';

    print( $prefix, $prompt );
    my $input = <$STDIN>;
    chomp $input;
    $callback->curry( $input )->send;
}

## message interface ...

# process singletons ...
our $IN;
our $OUT;
our $ERR;

sub err::log ($msg, $caller=CALLER()) {
    $ERR //= proc::spawn('#err');
    msg($ERR, print => [ $msg, $caller ]);
}

sub err::logf ($fmt, $msg, $caller=CALLER()) {
    $ERR //= proc::spawn('#err');
    msg($ERR, printf => [ $fmt, $msg, $caller ]);
}

sub out::print ($msg=undef) {
    $OUT //= proc::spawn('#out');
    msg($OUT, print => [ $msg // () ]);
}

sub out::printf ($fmt, $msg=undef) {
    $OUT //= proc::spawn('#out');
    msg($OUT, printf => [ $fmt, $msg // () ]);
}

sub in::read ($prompt=undef) {
    $IN //= proc::spawn('#in');
    msg($IN, read => [ $prompt // () ]);
}

## actors ...

actor '#err' => sub ($env, $msg) {
    match $msg, +{
        printf => \&sys::err::logf,
        print  => \&sys::err::log,
    };
};

actor '#out' => sub ($env, $msg) {
    match $msg, +{
        printf => \&sys::out::printf,
        print  => \&sys::out::print,
    };
};

actor '#in' => sub ($env, $msg) {
    match $msg, +{
        read => \&sys::in::read,
    };
};

1;

__END__

=pod

=cut
