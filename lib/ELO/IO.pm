package ELO::IO;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';

use ELO (); # circular dep
use ELO::Msg;
use ELO::Actors;

our $IN;
our $OUT;
our $ERR;

our $STDIN  = \*STDIN;
our $STDOUT = \*STDOUT;
our $STDERR = \*STDERR;

sub err::log ($msg, $caller=$ELO::CURRENT_CALLER) {
    $ERR //= proc::spawn('#err');
    msg($ERR, print => [ $msg, $caller ]);
}

sub err::logf ($fmt, $msg, $caller=$ELO::CURRENT_CALLER) {
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

## ... actors

sub QUIET () {
    ELO->DEBUG()
        # if we are DEBUG-ing, do not be quiet
        ? 0
        # if we are testing, be quiet
        : $Test::ELO::TESTING
}

my %INDENTS;

actor '#err' => sub ($env, $msg) {
    my $prefix = ON_RED "LOG (".$ELO::CURRENT_CALLER.") !!". RESET " ";

    match $msg, +{
        printf => sub ($fmt, $values, $caller='') {

            if ($caller) {
                $INDENTS{ $ELO::CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $ELO::CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $ELO::CURRENT_CALLER }).'> '
                    . RESET $prefix;
            }

            $STDERR->print(
                $prefix,
                (sprintf $fmt, @$values),
                FAINT " >> [$caller]",
                RESET "\n"
            ) unless QUIET();
        },
        print => sub ($msg, $caller='') {

            if ($caller) {
                $INDENTS{ $ELO::CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $ELO::CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $ELO::CURRENT_CALLER }).'> '
                    . RESET $prefix;
            }

            $STDERR->print(
                $prefix,
                $msg,
                FAINT " >> [$caller]",
                RESET "\n"
            ) unless QUIET();
        }
    };
};

actor '#out' => sub ($env, $msg) {
    my $prefix = ON_GREEN "OUT (".$ELO::CURRENT_CALLER.") >>". RESET " ";

    match $msg, +{
        printf => sub ($fmt, @values) {
            $STDOUT->print( $prefix, (sprintf $fmt, @values), "\n" ) unless QUIET();
        },
        print => sub ($value) {
            $STDOUT->print( $prefix, $value, "\n" ) unless QUIET();
        }
    };
};

actor '#in' => sub ($env, $msg) {
    my $prefix = ON_CYAN "IN (".$ELO::CURRENT_CALLER.") <<". RESET " ";

    match $msg, +{
        read => sub ($prompt, $callback) {
            $prompt //= '';

            print( $prefix, $prompt );
            my $input = <$STDIN>;
            chomp $input;
            $callback->curry( $input )->send;
        }
    };
};

1;

__END__

=pod

=cut
