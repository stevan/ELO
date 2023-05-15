package ELO::Util::Logger;
use v5.36;
use experimental 'try';

use Data::Dump ();
use Sub::Util  ();
use Term::ANSIColor qw[ colored ];
use Term::ReadKey   qw[ GetTerminalSize ];

use constant LEVELS => [qw[
    DEBUG
    INFO
    WARN
    ERROR
    FATAL
]];

use constant DEBUG   => 0;
use constant INFO    => 1;
use constant WARN    => 2;
use constant ERROR   => 3;
use constant FATAL   => 4;
use constant TESTING => 5; # internal state

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

my $MAX_LINE_WIDTH = (GetTerminalSize())[0];
my $MAX_DUMP_WIDTH = 90;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    filehandle => sub { \*STDERR },
    max_level  => sub { FATAL },
    min_level  => sub { $ENV{ELO_DEBUG} ? DEBUG : ($ENV{ELO_LOG} || INFO) },
);

sub BUILD ($self, $) {
    # if the filehandle is not connected to
    # a TTY (terminal) then we want to turn
    # off the colors
    $ENV{ANSI_COLORS_DISABLED} = 1 unless -t $self->{filehandle};
}

# ...

my sub pad    ($string) { " $string " }
my sub rpad   ($string) {  "$string " }
my sub lpad   ($string) { " $string"  }

my sub level  ($level)  { sprintf '[%-5s]' => LEVELS->[$level] }

my sub dump_msg ($msg) {
    local $Data::Dump::INDENT    = '    ';
    local $Data::Dump::LINEWIDTH = $MAX_DUMP_WIDTH;

    my $out;
    try {
        $out = Data::Dump::dumpf( $msg, sub ($ctx, $obj) {

            # NOTE:
            # we flatten some of our internal
            # information into these structs
            # and pass on useful data but not
            # expose the internal state of
            # the system.

            return +{
                object  => [ sort keys $obj->{_process_table}->%* ]
            } if $ctx->object_isa('ELO::Core::Loop');

            return +{
                object  => {
                    pid      => $obj->pid,
                    behavior => $obj->behavior,
                }
            } if $ctx->object_isa('ELO::Core::Process');

            return +{
                object  => {
                    status => $obj->status,
                    result => $obj->result,
                    error  => $obj->error,
                }
            } if $ctx->object_isa('ELO::Core::Promise');

            return;
        } );
    } catch ($e) {
        die Data::Dump::dump({ ERROR => $e, MSG => $msg });
    }
    return $out;
}

my sub colored_pid ($pid) {
    state %pid_colors_cache;

    $pid = $pid->pid if $pid isa ELO::Core::Process;

    $pid_colors_cache{$pid} //= 'on_ansi'.int($pid =~ s/^(\d+)\:.*$/$1/r);

    lpad( colored( pad($pid), $pid_colors_cache{$pid} ) );
}

# ...

sub log_tick ($self, $level, $loop, $tick, $msg=undef) {

    return if $self->{min_level} > $level
           || $self->{max_level} < $level;

    my $out = '-- '.(sprintf 'tick(%03d)' => $tick);
    $out .= ':'.$msg if $msg;
    $out .= ' ';
    $out .= ('-' x ($MAX_LINE_WIDTH - length($out)));

    $self->{filehandle}->print(
        colored( $out, 'grey15' ),
        "\n"
    );
}

sub log_tick_wait ($self, $level, $loop, $msg) {

    return if $self->{min_level} > $level
           || $self->{max_level} < $level;

    my $out = '-- '.$msg;
    $out .= ' ';
    $out .= ('-' x ($MAX_LINE_WIDTH - length($out)));

    $self->{filehandle}->print(
        colored( $out, 'black on_green' ),
        "\n"
    );
}

sub log_tick_pause ($self, $level, $loop, $msg) {

    return if $self->{min_level} > $level
           || $self->{max_level} < $level;

    my $out = '-- '.$msg;
    $out .= ' ';
    $out .= ('-' x ($MAX_LINE_WIDTH - length($out)));

    $self->{filehandle}->print(
        colored( $out, 'black on_magenta' ),
        "\n"
    );
}

sub log_tick_loop_stat ($self, $level, $loop, $msg) {

    return if $self->{min_level} > $level
           || $self->{max_level} < $level;

    my $out = '-- '.$msg;

    $self->{filehandle}->print(
        colored( $out . lpad(dump_msg($loop)), 'grey10' ),
        "\n"
    );
}

sub log_tick_stat ($self, $level, $loop, $msg) {

    return if $self->{min_level} > $level
           || $self->{max_level} < $level;

    my $out = '-- '.$msg;

    $self->{filehandle}->print(
        colored( $out, 'grey10' ),
        "\n"
    );
}

sub log ($self, $level, $process, $msg) {
    my $method = $METHODS[ $level ] || die "Unknown log level($level) : " . LEVELS->[$level];
    $self->$method( $process, $msg );
}

sub debug ($self, $process, $msg) {

    return if $self->{min_level} > DEBUG
           || $self->{max_level} < DEBUG;

    $self->{filehandle}->print(
        join '' => (
            colored( level(DEBUG), 'blue' ),
            colored_pid( $process ),
            colored( lpad(dump_msg($msg)), 'italic blue on_black' )
        ), "\n"
    );
}

sub info ($self, $process, $msg) {

    return if $self->{min_level} > INFO
           || $self->{max_level} < INFO;

    $self->{filehandle}->print(
        join '' => (
            colored( level(INFO), 'cyan' ),
            colored_pid( $process ),
            colored( lpad(dump_msg($msg)), 'italic cyan on_black' )
        ), "\n"
    );
}

sub warn ($self, $process, $msg) {

    return if $self->{min_level} > WARN
           || $self->{max_level} < WARN;

    $self->{filehandle}->print(
        join '' => (
            colored( level(WARN), 'yellow' ),
            colored_pid( $process ),
            colored( lpad(dump_msg($msg)), 'italic yellow on_black' )
        ), "\n"
    );
}

sub error ($self, $process, $msg) {

    return if $self->{min_level} > ERROR
           || $self->{max_level} < ERROR;

    $self->{filehandle}->print(
        join '' => (
            colored( level(ERROR), 'red' ),
            colored_pid( $process ),
            colored( lpad(dump_msg($msg)), 'italic red on_black' )
        ), "\n"
    );
}

sub fatal ($self, $process, $msg) {

    return if $self->{min_level} > FATAL
           || $self->{max_level} < FATAL;

    $self->{filehandle}->print(
        join '' => (
            colored( level(FATAL), 'white on_magenta' ),
            colored_pid( $process ),
            colored( lpad(dump_msg($msg)), 'italic white on_magenta' )
        ), "\n"
    );
}

1;

__END__

=pod

=cut
