package ELO::VM;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Carp 'croak';
use Scalar::Util 'blessed';
use Data::Dumper 'Dumper';

use ELO::Core::ProcessRecord;
use ELO::Core::Message;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Exporter 'import';

our @EXPORT = qw[
    msg

    $INIT_PID

    PID
    CALLER
];

## Variables ...

our $CURRENT_PID;
our $CURRENT_CALLER;

our $INIT_PID;

our %ACTORS;        # HASH< $name > = sub ($env, $msg) {}

our @MSG_INBOX;     # ARRAY [ [ $from, $msg ], ... ]

our %PROCESS_TABLE; # HASH< $pid > = ELO::Core::ProcessRecord

## ----------------------------------------------------------------------------
## Loop Context constants
## ----------------------------------------------------------------------------

sub PID    () { $CURRENT_PID    }
sub CALLER () { $CURRENT_CALLER }

## ----------------------------------------------------------------------------
## functions ...
## ----------------------------------------------------------------------------

sub new_pid ($name) {
    state $PID_ID = -1;
    sprintf '%03d:%s' => ++$PID_ID, $name;
}

## ----------------------------------------------------------------------------
## msg interface
## ----------------------------------------------------------------------------

sub msg ($pid, $action, $msg) { ELO::Core::Message->new( $pid, $action, $msg ) }

sub enqueue_msg ($msg, $from=$CURRENT_PID) {
    push @MSG_INBOX => [ $from, $msg ];
}

## namespaces ...

## ----------------------------------------------------------------------------
## process table
## ----------------------------------------------------------------------------

sub proc::exists ($pid) {
    croak 'You must supply a pid' unless $pid;
    exists $PROCESS_TABLE{$pid}
}

sub proc::lookup ($pid) {
    croak 'You must supply a pid to lookup' unless $pid;
    $PROCESS_TABLE{$pid};
}

sub proc::spawn ($name, %env) {
    croak 'You must supply an actor name to spawn' unless $name;
    my $pid     = new_pid( $name );
    my $process = ELO::Core::ProcessRecord->new( $pid, \%env, $ACTORS{$name} );
    $PROCESS_TABLE{ $pid } = $process;
    $pid;
}

sub proc::despawn ($pid) {
    croak 'You must supply a pid to despawn' unless $pid;
    $PROCESS_TABLE{ $pid }->set_to_exiting;
}

sub proc::despawn_all_exiting_pids ( $on_exit ) {
    foreach my $pid (keys %PROCESS_TABLE) {
        my $proc = $PROCESS_TABLE{$pid};
        if ( $proc->is_exiting ) {
            @MSG_INBOX = grep { $_->[1]->pid ne $pid } @MSG_INBOX;

            (delete $PROCESS_TABLE{ $pid })->set_to_done;
            $on_exit->( $pid );
        }
    }
}

## SETUP ...

UNITCHECK {
    $INIT_PID = new_pid('<init>');
}

1;

__END__

