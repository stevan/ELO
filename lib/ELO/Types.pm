package ELO::Types;
use v5.36;

use ELO::Core::Type;
use ELO::Core::Type::Alias;
use ELO::Core::Type::Event;

use constant DEBUG => $ENV{TYPES_DEBUG} || 0;

my @PERL_TYPES = (
    *Bool,     # 1, 0 or ''
    *Str,      # pretty much anything
    *Num,      # any numeric value
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

my @ALL_TYPES      = ( @PERL_TYPES, @ELO_CORE_TYPES );
my @ALL_TYPE_NAMES = map   get_type_name($_),      @ALL_TYPES;
my @ALL_TYPE_GLOBS = map   '*'.$_,                 @ALL_TYPE_NAMES;
my %ALL_TYPES      = map { get_type_name($_), $_ } @ALL_TYPES;

sub get_type_name ( $type ) {
    (split /\:\:/ => "$type")[-1]
}

# ...

use Exporter 'import';

our @EXPORT_OK = (qw[
    enum

    type
    event

    lookup_event_type
    lookup_type

    resolve_event_types
    resolve_types
    ],
    @ALL_TYPE_GLOBS,
);

our %EXPORT_TAGS = (
    core   => [ @ALL_TYPE_GLOBS ],
    types  => [qw[ enum type lookup_type       resolve_types       ]],
    events => [qw[ event     lookup_event_type resolve_event_types ]],
);

# ...

my %EVENT_REGISTRY;
my %TYPE_REGISTRY;

sub enum ($enum, @values) {
    warn "Creating enum $enum" if DEBUG;
    my $i = 0;
    my %enum_map;
    {
        no strict 'refs';
        foreach my $value (@values) {
            my $glob = *{"${enum}::${value}"}; # create the GLOB
            *{$glob} = \(my $x = $i);          # assign it the value
            $enum_map{ $glob } = $i;           # note in the map
            $i++;
        }
    }
    $TYPE_REGISTRY{ $enum } = ELO::Core::Type->new(
        symbol  => $enum,
        checker => sub ($enum_value) {

            #use Data::Dumper;
            #warn Dumper [ $enum_value, \%enum_map ];

            return defined($enum_value)
                && exists $enum_map{ $enum_value }
        },
    );
}

sub event ($type, @definition) {
    warn "Creating event $type" if DEBUG;
    $EVENT_REGISTRY{ $type } = ELO::Core::Type::Event->new(
        symbol       => $type,
        definition   => resolve_types( \@definition ),
    );
}

sub type ($type, $checker) {
    warn "Creating type $type" if DEBUG;

    if ( ref $checker eq 'CODE' ) {
        $TYPE_REGISTRY{ $type } = ELO::Core::Type->new(
            symbol  => $type,
            checker => $checker,
        );
    }
    else {
        my $alias = $TYPE_REGISTRY{ $checker }
            || die "Unable to alias type($type) to alias($checker): alias type not found";

        $TYPE_REGISTRY{ $type } = ELO::Core::Type::Alias->new(
            symbol => $type,
            alias  => $alias,
        );
    }
}

# ...

sub lookup_event_type ($type) {
    warn "Looking up event($type)" if DEBUG;
    $EVENT_REGISTRY{ $type }
}

sub lookup_type ( $type ) {
    warn "Looking up type($type)" if DEBUG;
    $TYPE_REGISTRY{ $type }
}

sub resolve_types ( $types ) {
    my @resolved;
    foreach my $t ( @$types ) {
        # if we encounter a tuple ...
        if ( ref $t eq 'ARRAY' ) {
            # otherwise recurse and check the tuple ...
            push @resolved => __SUB__->( $t );
        }
        else {
            my $type = $TYPE_REGISTRY{ $t }
                || die "Could not resolve type($t) in registry";

            push @resolved => $type;
        }
    }

    return \@resolved;
}

sub resolve_event_types ( $events ) {
    my @resolved;
    foreach my $e ( @$events ) {
        my $type = $EVENT_REGISTRY{ $e }
            || die "Could not resolve event($e) in registry";
        push @resolved => $type;
    }

    return \@resolved;
}

# ...

use Scalar::Util qw[ looks_like_number ];

# XXX - consider using the builtin functions here:
# - true, false, is_bool
# - created_as_{string,number}

type *Bool, sub ($bool) {
    return defined($bool)                      # it is defined ...
        && not(ref $bool)                      # ... and it is not a reference
        && ($bool =~ /^[01]$/ || $bool eq '')  # ... and is either 1,0 or an empty string
};

type *Str, sub ($str) {
    return defined($str)                      # it is defined ...
        && not(ref $str)                      # ... and it is not a reference
        && ref(\$str) eq 'SCALAR'             # ... and its just a scalar
};

type *Num, sub ($num) {
    return defined($num)                      # it is defined ...
        && not(ref $num)                      # if it is not a reference
        && looks_like_number($num)            # ... if it looks like a number
};

type *Int, sub ($int) {
    return defined($int)                      # it is defined ...
        && not(ref $int)                      # if it is not a reference
        && looks_like_number($int)            # ... if it looks like a number
        && int($int) == $int                  # and is the same value when converted to int()
};

type *Float, sub ($float) {
    return defined($float)                      # it is defined ...
        && not(ref $float)                      # if it is not a reference
        && looks_like_number($float)            # ... if it looks like a number
        && $float == ($float + 0.0)             # and is the same value when converted to float()
};

type *ArrayRef, sub ($array_ref) {
    return defined($array_ref)        # it is defined ...
        && ref($array_ref) eq 'ARRAY' # and it is an ARRAY reference
};

type *HashRef, sub ($hash_ref) {
    return defined($hash_ref)       # it is defined ...
        && ref($hash_ref) eq 'HASH' # and it is a HASH reference
};

# FIXME:
# these type definitions require too much
# knowledge of things, and so therefore
# we end up duplicating stuff, this should
# get fixed at some point

type *PID, sub ($pid) {
    return defined($pid)             # it is defined ...
        && not(ref $pid)             # ... and it is not a reference
        && ($pid =~ /^\d\d\d\:.*$/)  # ... and is the pid format
        # FIXME: this PID format should not be defined
        # here as well as in Abstract::Process
};

type *Process, sub ($process) {
    return defined($process)                # it is defined ...
        && $process isa ELO::Core::Process  # ... and is a process object
};

type *Promise, sub ($promise) {
    return defined($promise)                # it is defined ...
        && $promise isa ELO::Core::Promise  # ... and is a promise object
};

type *TimerId, sub ($timer_id) {
    return defined($timer_id)         # it is defined ...
        && ref($timer_id) eq 'SCALAR' # and it is a SCALAR reference
        # FIXME: we should probably bless the timed IDs
};

1;

__END__

=pod

=cut
