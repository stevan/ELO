package ELO::Types;
use v5.36;

use ELO::Core::Type;

use constant DEBUG => $ENV{TYPES_DEBUG} || 0;

my @PERL_TYPES = (
    *Bool,     # 1, 0 or ''
    *Str,      # pretty much anything
    *Int,      # if it looks like a number and int($_) == $_
    *Float,    # if it looks like a number

    *ArrayRef, # an ARRAY reference
    *HashRef,  # a HASH reference
);

# TODO: The Perl Virtual Types (see if we actually need them).

my @ELO_CORE_TYPES = (
    *PID,     # either a PID string or a Process instance

# NOTE: these are local-only
    *Process, # a Process instance
    *Promise, # a Promise instance
    *TimerId, # a Timer ID value
);

my @ALL_TYPES = ( @PERL_TYPES, @ELO_CORE_TYPES );

my %ALL_TYPES = map { get_type_name($_), $_ } @ALL_TYPES;

sub get_type_name ( $type ) {
    (split /\:\:/ => "$type")[-1]
}

# ...

sub import ($pkg, @args) {
    my $into = caller;

    no strict 'refs';
    foreach my $arg (@args) {
        if ( $arg eq ':core' ) {
            foreach my $type (keys %ALL_TYPES) {
                *{$into.'::'.$type} = $ALL_TYPES{ $type };
            }
        }
        elsif ( $arg eq 'lookup_type' ) {
            *{$into.'::lookup_type'} = \&lookup_type;
        }
        else {
            if (exists $ALL_TYPES{ $arg }) {
                *{$into.'::'.$arg} = $ALL_TYPES{ $arg };
            }
            else {
                die 'No idea what to do with ('.$arg.')';
            }
        }
    }
}

# ...

my %TYPE_REGISTRY;

sub lookup_type ( $type ) {
    #use Data::Dumper;
    #warn Dumper [ $type, \%TYPE_REGISTRY ];

    $TYPE_REGISTRY{ $type }
}

# ...

use B;
use Scalar::Util qw[ looks_like_number ];

$TYPE_REGISTRY{ *Bool } = ELO::Core::Type->new(
    symbol  => \*Bool,
    checker => sub ($bool) {
        return defined($bool)                      # it is defined ...
            && not(ref $bool)                      # ... and it is not a reference
            && ($bool =~ /^[01]$/ || $bool eq '')  # ... and is either 1,0 or an empty string
    }
);

$TYPE_REGISTRY{ *Str } = ELO::Core::Type->new(
    symbol  => \*Str,
    checker => sub ($str) {
        return defined($str)                      # it is defined ...
            && not(ref $str)                      # ... and it is not a reference
            && ref(\$str) eq 'SCALAR'             # ... and its just a scalar
            && B::svref_2object(\$str) isa B::PV  # ... and it is at least `isa` B::PV
    }
);

$TYPE_REGISTRY{ *Int } = ELO::Core::Type->new(
    symbol  => \*Int,
    checker => sub ($int) {
        return defined($int)                      # it is defined ...
            && not(ref $int)                      # if it is not a reference
            && looks_like_number($int)            # ... if it looks like a number
            && int($int) == $int                  # and is the same value when converted to int()
            && B::svref_2object(\$int) isa B::IV  # ... and it is at least `isa` B::IV
    }
);

$TYPE_REGISTRY{ *Float } = ELO::Core::Type->new(
    symbol  => \*Float,
    checker => sub ($float) {
        return defined($float)                      # it is defined ...
            && not(ref $float)                      # if it is not a reference
            && looks_like_number($float)            # ... if it looks like a number
            && $float == ($float + 0.0)             # and is the same value when converted to float()
            && B::svref_2object(\$float) isa B::NV  # ... and it is at least `isa` B::NV
    }
);

$TYPE_REGISTRY{ *ArrayRef } = ELO::Core::Type->new(
    symbol  => \*ArrayRef,
    checker => sub ($array_ref) {
        return defined($array_ref)        # it is defined ...
            && ref($array_ref) eq 'ARRAY' # and it is an ARRAY reference
    }
);

$TYPE_REGISTRY{ *HashRef } = ELO::Core::Type->new(
    symbol  => \*HashRef,
    checker => sub ($hash_ref) {
        return defined($hash_ref)       # it is defined ...
            && ref($hash_ref) eq 'HASH' # and it is a HASH reference
    }
);

# FIXME:
# these type definitions require too much
# knowledge of things, and so therefore
# we end up duplicating stuff, this should
# get fixed at some point

$TYPE_REGISTRY{ *PID } = ELO::Core::Type->new(
    symbol  => \*PID,
    checker => sub ($pid) {
        return defined($pid)             # it is defined ...
            && not(ref $pid)             # ... and it is not a reference
            && ($pid =~ /^\d\d\d\:.*$/)  # ... and is the pid format
            # FIXME: this PID format should not be defined
            # here as well as in Abstract::Process
    }
);

$TYPE_REGISTRY{ *Process } = ELO::Core::Type->new(
    symbol  => \*Process,
    checker => sub ($process) {
        return defined($process)                          # it is defined ...
            && $process isa ELO::Core::Abstract::Process  # ... and is a process object
    }
);

$TYPE_REGISTRY{ *Promise } = ELO::Core::Type->new(
    symbol  => \*Promise,
    checker => sub ($promise) {
        return defined($promise)                # it is defined ...
            && $promise isa ELO::Core::Promise  # ... and is a promise object
    }
);

$TYPE_REGISTRY{ *TimerId } = ELO::Core::Type->new(
    symbol  => \*TimerId,
    checker => sub ($timer_id) {
        return defined($timer_id)         # it is defined ...
            && ref($timer_id) eq 'SCALAR' # and it is a SCALAR reference
            # FIXME: we should probably bless the timed IDs
    }
);

1;

__END__

=pod

=cut
