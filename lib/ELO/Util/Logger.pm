package ELO::Util::Logger;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use JSON;
use Sub::Util       qw[ subname ];
use Term::ANSIColor qw[ colored ];

use constant LEVELS => [qw[
    DEBUG
    INFO
    WARN
    ERROR
    FATAL
]];

use constant DEBUG => 0;
use constant INFO  => 1;
use constant WARN  => 2;
use constant ERROR => 3;
use constant FATAL => 4;

sub debug;
sub info;
sub warn;
sub error;
sub fatal;

my @METHODS = (
    \&debug,
    \&info,
    \&warn,
    \&error,
    \&fatal,
);

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    min_level => sub { INFO  },
    max_level => sub { FATAL },
);

sub log ($self, $level, $process, $msg) {
    my $method = $METHODS[ $level ] || die "Unknown log level($level) : " . LEVELS->[$level];
    $self->$method( $process, $msg );
}

# ...

my sub pad    ($string) { " $string " }
my sub rpad   ($string) {  "$string " }
my sub lpad   ($string) { " $string"  }

my sub level  ($level)  { sprintf '[%5s]' => LEVELS->[$level] }

my sub dump_msg ($msg) {
    my $out;
    eval {
        $out = JSON->new->canonical->encode( $msg );
        1;
    } or do {
        my $e = $@;
        CORE::die(Data::Dumper::Dumper({ ERROR => $e, MSG => $msg }));
    };
    return $out;
}

my sub colored_pid ($pid) {
    state %pid_colors;

    $pid_colors{$pid} //= 'on_ansi'.int($pid =~ s/^(\d+)\:.*$/$1/r);

    lpad( colored( pad($pid), $pid_colors{$pid} ) );
}

# ...

sub debug ($self, $process, $msg) {

    return if $self->{min_level} > DEBUG
           || $self->{max_level} < DEBUG;

    CORE::warn(
        join '' => (
            colored( level(DEBUG), 'blue' ),
            colored_pid( $process->pid ),
            colored( lpad(dump_msg($msg)), 'italic blue on_black' )
        ), "\n"
    );
}

sub info ($self, $process, $msg) {

    return if $self->{min_level} > INFO
           || $self->{max_level} < INFO;

    CORE::warn(
        join '' => (
            colored( level(INFO), 'cyan' ),
            colored_pid( $process->pid ),
            colored( lpad(dump_msg($msg)), 'italic cyan on_black' )
        ), "\n"
    );
}

sub warn ($self, $process, $msg) {

    return if $self->{min_level} > WARN
           || $self->{max_level} < WARN;

    CORE::warn(
        join '' => (
            colored( level(WARN), 'yellow' ),
            colored_pid( $process->pid ),
            colored( lpad(dump_msg($msg)), 'italic yellow on_black' )
        ), "\n"
    );
}

sub error ($self, $process, $msg) {

    return if $self->{min_level} > ERROR
           || $self->{max_level} < ERROR;

    CORE::warn(
        join '' => (
            colored( level(ERROR), 'red' ),
            colored_pid( $process->pid ),
            colored( lpad(dump_msg($msg)), 'italic red on_black' )
        ), "\n"
    );
}

sub fatal ($self, $process, $msg) {

    return if $self->{min_level} > FATAL
           || $self->{max_level} < FATAL;

    CORE::warn(
        join '' => (
            colored( level(FATAL), 'red on_white' ),
            colored_pid( $process->pid ),
            colored( lpad(dump_msg($msg)), 'italic red on_white' )
        ), "\n"
    );
}

1;

__END__

=pod

=cut
