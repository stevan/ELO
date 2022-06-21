package ELO;
# ABSTRACT: Event Loop Orchestra

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Carp 'croak';
use Data::Dumper 'Dumper';

use ELO::Actors;
use ELO::Msg;
use ELO::Loop;

use ELO::IO;
use ELO::Control;

use ELO::Debug;

use Exporter 'import';

our @EXPORT = (
    @ELO::Actors::EXPORT,
    @ELO::Msg::EXPORT,
    @ELO::Loop::EXPORT,
    @ELO::Control::EXPORT,
    @ELO::Debug::EXPORT,
);

1;

__END__

=pod

use Term::ANSIColor 'color';

# re-implement later ...
if ( DEBUGGER ) {

    my @pids = sort keys %PROCESS_TABLE;

    my $longest_pid = max( map length, @pids );

    warn FAINT '-' x $TERM_SIZE, RESET "\n";
    warn FAINT ON_MAGENTA " << MESSAGES >> " . RESET "\n";
    warn FAINT '-' x $TERM_SIZE, RESET "\n";
    foreach my $pid ( @pids ) {
        my @inbox  = $PROCESS_TABLE{$pid}->[0]->@*;
        my ($num, $name) = split ':' => $pid;

        my $pid_color = 'black on_ansi'.((int($num)+3) * 8);

        warn '  '.
            color($pid_color).
                sprintf("> %-${longest_pid}s ", $pid).
            RESET " (".
            CYAN (join ' / ' =>
                map {
                    my $action = $_->[1]->action;
                    my $body   = join ', ' => $_->[1]->body->@*;
                    "${action}![${body}]";
                } @inbox).
            RESET ")\n";
    }
    warn FAINT '-' x $TERM_SIZE, RESET "\n";
    my $proceed = <>;
}

=cut
