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
use ELO::Loop;

use ELO::IO;
use ELO::Control;

use ELO::Debug;

use Exporter 'import';

our @EXPORT = (
    @ELO::Actors::EXPORT,
    @ELO::Loop::EXPORT,
    @ELO::Control::EXPORT,
    @ELO::Debug::EXPORT,
);

1;

__END__

=pod

# Building Actors

actor match

# Flow Controls

ident sequence parallel

# Loop

loop msg
TICK
PID CALLER

# PROCESSES

proc::exists
proc::lookup
proc::spawn
proc::despawn

# SIGNALS

sig::kill
sig::waitpid
sig::timer

# I/O

err::log
err::logf

out::print
out::printf

in::read

=cut

