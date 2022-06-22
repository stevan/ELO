package ELO::Control;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Carp         'croak';
use Scalar::Util 'blessed';
use Data::Dumper 'Dumper';

use ELO::VM qw[ PID CALLER msg ];

use ELO::Actors;
use ELO::IO;
use ELO::Debug;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Exporter 'import';

our @EXPORT = qw[
    ident
    sequence
    parallel
];

## ----------------------------------------------------------------------------
## currency control
## ----------------------------------------------------------------------------

sub ident ($val, $callback=undef) {
    msg( proc::spawn( '!ident' ), id => [ $val, $callback // () ] );
}

sub sequence (@statements) {
    (blessed $_ && $_->isa('ELO::Core::Message'))
        || croak 'You must supply a sequence of msg()s, not '.$_
            foreach @statements;
    msg( proc::spawn( '!sequence' ), next => [ @statements ] );
}

sub parallel (@statements) {
    (blessed $_ && $_->isa('ELO::Core::Message'))
        || croak 'You must supply a sequence of msg()s, not '.$_
            foreach @statements;
    msg( proc::spawn( '!parallel' ), all => [ @statements ] );
}

## ----------------------------------------------------------------------------
## Core Actors
## ----------------------------------------------------------------------------

# will just return the input given ...
actor '!ident' => sub ($env, $msg) {
    match $msg, +{
        id => sub ($val, $callback=undef) {
            sys::err::log("*/ !ident /* returning val($val)") if DEBUG_ACTORS;
            $callback->curry($val)->send;
            proc::despawn( PID() );
        },
    };
};

# ... runnnig muliple statements

actor '!sequence' => sub ($env, $msg) {
    match $msg, +{
        next => sub (@statements) {
            if ( my $statement = shift @statements ) {
                sys::err::log("*/ !sequence /* calling, ".(scalar @statements)." remain" ) if DEBUG_ACTORS;
                $statement->send_from( CALLER() );
                msg(PID(), next => \@statements)->send_from( CALLER() );
            }
            else {
                sys::err::log("*/ !sequence /* finished") if DEBUG_ACTORS;
                proc::despawn( PID() );
            }
        },
    };
};

actor '!parallel' => sub ($env, $msg) {
    match $msg, +{
        all => sub (@statements) {
            sys::err::log("*/ !parallel /* sending ".(scalar @statements)." messages" ) if DEBUG_ACTORS;
            foreach my $statement ( @statements ) {
                $statement->send_from( CALLER() );
            }
            sys::err::log("*/ !parallel /* finished") if DEBUG_ACTORS;
            proc::despawn( PID() );
        },
    };
};

1;

__END__
