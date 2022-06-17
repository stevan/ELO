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
    my $prefix = ELO::DEBUG()
        ? ON_RED "LOG (".$ELO::CURRENT_CALLER.") !!". RESET " "
        : ON_RED "LOG !!". RESET " ";

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

            warn(
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

            warn(
                $prefix,
                $msg,
                FAINT " >> [$caller]",
                RESET "\n"
            ) unless QUIET();
        }
    };
};

actor '#out' => sub ($env, $msg) {
    my $prefix = ELO::DEBUG()
        ? ON_GREEN "OUT (".$ELO::CURRENT_CALLER.") >>". RESET " "
        : ON_GREEN "OUT >>". RESET " ";

    match $msg, +{
        printf => sub ($fmt, @values) {
            say( $prefix, sprintf $fmt, @values ) unless QUIET();
        },
        print => sub ($value) {
            say( $prefix, $value ) unless QUIET();
        }
    };
};

actor '#in' => sub ($env, $msg) {
    my $prefix = ELO::DEBUG()
        ? ON_CYAN "IN (".$ELO::CURRENT_CALLER.") <<". RESET " "
        : ON_CYAN "IN <<". RESET " ";

    match $msg, +{
        read => sub ($prompt) {
            $prompt //= '';

            print( $prefix, $prompt );
            my $input = <>;
            chomp $input;
            ELO::return_to( $input );
        }
    };
};

1;

__END__

=pod

=cut
