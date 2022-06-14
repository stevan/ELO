package EventLoop::IO;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';
use Term::ANSIColor ':constants';

# use EventLoop; ... but not, so as to avoid the circular dep
use EventLoop::Actors;

our $IN;
our $OUT;
our $ERR;

sub err::log ($msg, $caller=$EventLoop::CURRENT_CALLER) {
    $ERR //= EventLoop::spawn('#err');
    my $args = [ $ERR, print => [ $msg, $caller ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub err::logf ($fmt, $msg, $caller=$EventLoop::CURRENT_CALLER) {
    $ERR //= EventLoop::spawn('#err');
    my $args = [ $ERR, printf => [ $fmt, $msg, $caller ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub out::print ($msg=undef) {
    $OUT //= EventLoop::spawn('#out');
    my $args = [ $OUT, print => [ $msg // () ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub out::printf ($fmt, $msg=undef) {
    $OUT //= EventLoop::spawn('#out');
    my $args = [ $OUT, printf => [ $fmt, $msg // () ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub in::read ($prompt=undef) {
    $IN //= EventLoop::spawn('#in');
    my $args = [ $IN, read => [ $prompt // () ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

## ... actors

my %INDENTS;

actor '#err' => sub ($env, $msg) {
    my $prefix = EventLoop::DEBUG()
        ? ON_RED "LOG (".$EventLoop::CURRENT_CALLER.") !!". RESET " "
        : ON_RED "LOG !!". RESET " ";

    match $msg, +{
        printf => sub ($fmt, $values, $caller='') {

            if ($caller) {
                $INDENTS{ $EventLoop::CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $EventLoop::CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $EventLoop::CURRENT_CALLER }).'> '
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
                $INDENTS{ $EventLoop::CURRENT_CALLER } = ($INDENTS{ $caller } // 0) + 1
                    unless exists $INDENTS{ $EventLoop::CURRENT_CALLER };

                $prefix = FAINT
                    RED
                        ('-' x $INDENTS{ $EventLoop::CURRENT_CALLER }).'> '
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
    my $prefix = EventLoop::DEBUG()
        ? ON_GREEN "OUT (".$EventLoop::CURRENT_CALLER.") >>". RESET " "
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
    my $prefix = EventLoop::DEBUG()
        ? ON_CYAN "IN (".$EventLoop::CURRENT_CALLER.") <<". RESET " "
        : ON_CYAN "IN <<". RESET " ";

    match $msg, +{
        read => sub ($prompt) {
            $prompt //= '';

            print( $prefix, $prompt );
            my $input = <>;
            chomp $input;
            EventLoop::return_to( $input );
        }
    };
};

1;

__END__

=pod

=cut
