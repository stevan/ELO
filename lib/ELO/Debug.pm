package ELO::Debug;
# ABSTRACT: Event Loop Orchestra

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Exporter 'import';

our @EXPORT = qw[
    DEBUG

    DEBUG_LOOP
    DEBUG_SIGS
    DEBUG_ACTORS
    DEBUG_CALLS
    DEBUG_PROCS
    DEBUG_MSGS
    DEBUG_TIMERS
    DEBUG_WAITPIDS
];

## ...

use constant DEBUG => $ENV{DEBUG} // '';

# -------------------------------------------------
# DEBUG FLAGS
# -------------------------------------------------
# These are the most useful ...
#
# LOOP   - this will show ticks, start, exit, etc.
# SIGS   - any signals sent to the INIT-PID
# ACTORS - the core actors ...
# -------------------------------------------------
# CALLS - prints out the message calls, which is
#         useful, but a lot of information
# -------------------------------------------------
# PROCS, MSGS, TIMERS, WAITPIDS
#       - heavy duty debugging, and a bit rough,
#         mostly DataDumper stuff
# -------------------------------------------------

use constant DEBUG_LOOP     => DEBUG() =~ m/LOOP/     ? 1 : 0 ;
use constant DEBUG_SIGS     => DEBUG() =~ m/SIGS/     ? 1 : 0 ;
use constant DEBUG_ACTORS   => DEBUG() =~ m/ACTORS/   ? 1 : 0 ;

use constant DEBUG_CALLS    => DEBUG() =~ m/CALLS/    ? 1 : 0 ;

use constant DEBUG_PROCS    => DEBUG() =~ m/PROCS/    ? 1 : 0 ;
use constant DEBUG_MSGS     => DEBUG() =~ m/MSGS/     ? 1 : 0 ;
use constant DEBUG_TIMERS   => DEBUG() =~ m/TIMERS/   ? 1 : 0 ;
use constant DEBUG_WAITPIDS => DEBUG() =~ m/WAITPIDS/ ? 1 : 0 ;


1;

__END__

