package ELO::VM;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Carp 'croak';
use Scalar::Util 'blessed';
use Data::Dumper 'Dumper';

use ELO::Core::Message;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Exporter 'import';

our @EXPORT = qw[
    loop
    msg

    PID
    CALLER
];

## Variables ...

our %ACTORS; # HASH< $name > = sub ($env, $msg) {}

## ----------------------------------------------------------------------------
## loop interface
## ----------------------------------------------------------------------------

our $LOOP;
sub loop ( $max_ticks, $start ) {
    $LOOP = ELO::Loop->new(
        actors    => \%ACTORS,
        start     => $start,
        max_ticks => $max_ticks,
    );

    $LOOP->run;
}

## ----------------------------------------------------------------------------
## Loop Context interface
## ----------------------------------------------------------------------------

sub PID    () { $LOOP->active_pid }
sub CALLER () { $LOOP->caller_pid }

## ----------------------------------------------------------------------------
## msg interface
## ----------------------------------------------------------------------------

sub msg ($pid, $action, $msg) { ELO::Core::Message->new( $pid, $action, $msg ) }

## namespaces ...

## ----------------------------------------------------------------------------
## process table
## ----------------------------------------------------------------------------

sub proc::spawn ($name, %env) {
    croak 'You must supply an actor name to spawn' unless $name;
    return $LOOP->spawn_process( $name, %env );
}

sub proc::despawn ($pid) {
    croak 'You must supply a pid to despawn' unless $pid;
    $LOOP->despawn_process( $pid );
}

## ----------------------------------------------------------------------------
## Signals ... see Actor definitions inside ELO::Loop
## ----------------------------------------------------------------------------

sub sig::kill($pid) {
    croak 'You must supply a pid to kill' unless $pid;
    msg( $LOOP->init_pid, kill => [ $pid ] );
}

sub sig::timer($timeout, $callback) {
    croak 'You must supply a timeout value' unless defined $timeout;
    croak 'You must supply a callback msg()'
        unless blessed $callback && $callback->isa('ELO::Core::Message');
    msg( $LOOP->init_pid, timer => [ $timeout, $callback ] );
}

sub sig::waitpid($pid, $callback) {
    croak 'You must supply a pid value' unless $pid;
    croak 'You must supply a callback msg()'
        unless blessed $callback && $callback->isa('ELO::Core::Message');
    msg( $LOOP->init_pid, waitpid => [ $pid, $callback ] );
}

1;

__END__

