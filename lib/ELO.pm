package ELO;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Carp 'croak';
use Data::Dumper 'Dumper';

use ELO::VM;
use ELO::Actors;
use ELO::Loop;

use ELO::IO;
use ELO::Control;

use ELO::Debug;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Exporter 'import';

our @EXPORT = (
    @ELO::VM::EXPORT,
    @ELO::Actors::EXPORT,
    @ELO::Loop::EXPORT,
    @ELO::Control::EXPORT,
    @ELO::Debug::EXPORT,
);

1;

__END__

=pod

# ----------------------------------------
# Building Actors
# ----------------------------------------

actor match

# ----------------------------------------
# VM
# ----------------------------------------

# Loop start

loop

# messaging ...

msg

# Loop context constants

TICK PID CALLER

# Loop process functions

proc::exists
proc::lookup
proc::spawn
proc::despawn

# ----------------------------------------
# Build in Message builders ...
# ----------------------------------------

# Flow Control messages

ident
sequence
parallel

# SIGNAL messages

sig::kill
sig::waitpid
sig::timer

# Aysnc I/O messages

err::log
err::logf

out::print
out::printf

in::read

# ----------------------------------------
# System Interface
# ----------------------------------------

# Sync I/0 functions

sys::err::log
sys::err::logf

sys::out::print
sys::out::printf

sys::in::read


=cut

