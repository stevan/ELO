package SAM::IO;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';

# use SAM; ... but not, so as to avoid the circular dep
use SAM::Actors;

our $IN;
our $OUT;
our $ERR;

sub err::log ($msg, $caller=$SAM::CURRENT_CALLER) {
    $ERR //= SAM::spawn('#err');
    my $args = [ $ERR, print => [ $msg, $caller ]];
    defined wantarray ? $args : SAM::send_to( @$args );
}

sub err::logf ($fmt, $msg, $caller=$SAM::CURRENT_CALLER) {
    $ERR //= SAM::spawn('#err');
    my $args = [ $ERR, printf => [ $fmt, $msg, $caller ]];
    defined wantarray ? $args : SAM::send_to( @$args );
}

sub out::print ($msg=undef) {
    $OUT //= SAM::spawn('#out');
    my $args = [ $OUT, print => [ $msg // () ]];
    defined wantarray ? $args : SAM::send_to( @$args );
}

sub out::printf ($fmt, $msg=undef) {
    $OUT //= SAM::spawn('#out');
    my $args = [ $OUT, printf => [ $fmt, $msg // () ]];
    defined wantarray ? $args : SAM::send_to( @$args );
}

sub in::read ($prompt=undef) {
    $IN //= SAM::spawn('#in');
    my $args = [ $IN, read => [ $prompt // () ]];
    defined wantarray ? $args : SAM::send_to( @$args );
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
            );
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
            );
        }
    };
};

actor '#out' => sub ($env, $msg) {
    my $prefix = SAM::DEBUG()
        ? ON_GREEN "OUT (".$SAM::CURRENT_CALLER.") >>". RESET " "
        : ON_GREEN "OUT >>". RESET " ";

    match $msg, +{
        printf => sub ($fmt, @values) {
            say( $prefix, sprintf $fmt, @values );
        },
        print => sub ($value) {
            say( $prefix, $value );
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
