package SAM::IO;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';

use SAM (); # circular dep
use SAM::Actors;

sub QUIET () {
    SAM->DEBUG()
        # if we are DEBUG-ing, do not be quiet
        ? 0
        # if we are testing, be quiet
        : $Test::SAM::TESTING
}

our $IN;
our $OUT;
our $ERR;

sub err::log ($msg, $caller=$SAM::CURRENT_CALLER) {
    $ERR //= sys::spawn('#err');
    SAM::msg($ERR, print => [ $msg, $caller ])
        ->return_or_send( wantarray );
}

sub err::logf ($fmt, $msg, $caller=$SAM::CURRENT_CALLER) {
    $ERR //= sys::spawn('#err');
    SAM::msg($ERR, printf => [ $fmt, $msg, $caller ])
        ->return_or_send( wantarray );
}

sub out::print ($msg=undef) {
    $OUT //= sys::spawn('#out');
    SAM::msg($OUT, print => [ $msg // () ])
        ->return_or_send( wantarray );
}

sub out::printf ($fmt, $msg=undef) {
    $OUT //= sys::spawn('#out');
    SAM::msg($OUT, printf => [ $fmt, $msg // () ])
        ->return_or_send( wantarray );
}

sub in::read ($prompt=undef) {
    $IN //= sys::spawn('#in');
    SAM::msg($IN, read => [ $prompt // () ])
        ->return_or_send( wantarray );
}

## ... actors

my %INDENTS;

actor '#err' => sub ($env, $msg) {
    my $prefix = SAM::DEBUG()
        ? ON_RED "LOG (".$SAM::CURRENT_CALLER.") !!". RESET " "
        : ON_RED "LOG !!". RESET " ";

    match $msg, +{
        printf => sub ($fmt, $values, $caller='') {

            if ($caller) {
                $INDENTS{ $SAM::CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $SAM::CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $SAM::CURRENT_CALLER }).'> '
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
                $INDENTS{ $SAM::CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $SAM::CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $SAM::CURRENT_CALLER }).'> '
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
    my $prefix = SAM::DEBUG()
        ? ON_GREEN "OUT (".$SAM::CURRENT_CALLER.") >>". RESET " "
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
    my $prefix = SAM::DEBUG()
        ? ON_CYAN "IN (".$SAM::CURRENT_CALLER.") <<". RESET " "
        : ON_CYAN "IN <<". RESET " ";

    match $msg, +{
        read => sub ($prompt) {
            $prompt //= '';

            print( $prefix, $prompt );
            my $input = <>;
            chomp $input;
            SAM::return_to( $input );
        }
    };
};

1;

__END__

=pod

=cut
