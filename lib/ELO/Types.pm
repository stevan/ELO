package ELO::Types;
use v5.36;
use experimental 'builtin';

use builtin      qw[ blessed ];
use Scalar::Util qw[ looks_like_number ];

use ELO::Core::Type;
use ELO::Core::Type::Alias;
use ELO::Core::Type::Event;
use ELO::Core::Type::Event::Protocol;
use ELO::Core::Type::Enum;
use ELO::Core::Type::TaggedUnion;
use ELO::Core::Type::TaggedUnion::Constructor;

use ELO::Core::Typeclass;

use constant DEBUG => $ENV{TYPES_DEBUG} || 0;

# -----------------------------------------------------------------------------
# Setup the Core Types
# -----------------------------------------------------------------------------

my @PERL_TYPES = (
    *Any,      # any value
    *Scalar,   # a defined value

    *Bool,     # 1, 0 or ''
    *Str,      # pretty much anything
    *Num,      # any numeric value
    *Int,      # if it looks like a number and int($_) == $_
    *Float,    # if it looks like a number

    *ArrayRef, # an ARRAY reference
    *HashRef,  # a HASH reference

    # TODO: we need an object type
    # *Blessed is too simple, but might
    # work for now, but then again it
    # should be serializable, so maybe
    # this is just a bad idea
);

# TODO: The Perl Virtual Types (see if we actually need them).

my @ELO_CORE_TYPES = (
    *PID,     # either a PID string or a Process instance

# NOTE: these are local-only
    *Process, # a Process instance
    *Promise, # a Promise instance
    *TimerId, # a Timer ID value
);

my @ELO_CORE_SIGNALS = (
    *SIGEXIT
);

# -----------------------------------------------------------------------------
# Collect types
# -----------------------------------------------------------------------------

my @ALL_SIGNALS      = ( @ELO_CORE_SIGNALS );
my @ALL_SIGNAL_NAMES = map   get_type_name($_),      @ALL_SIGNALS;
my @ALL_SIGNAL_GLOBS = map   '*'.$_,                 @ALL_SIGNAL_NAMES;
my %ALL_SIGNALS      = map { get_type_name($_), $_ } @ALL_SIGNALS;

my @ALL_TYPES      = ( @PERL_TYPES, @ELO_CORE_TYPES );
my @ALL_TYPE_NAMES = map   get_type_name($_),      @ALL_TYPES;
my @ALL_TYPE_GLOBS = map   '*'.$_,                 @ALL_TYPE_NAMES;
my %ALL_TYPES      = map { get_type_name($_), $_ } @ALL_TYPES;

sub get_type_name ( $type ) {
    (split /\:\:/ => "$type")[-1]
}

# -----------------------------------------------------------------------------
# Setup Exporter
# -----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT_OK = (qw[
    enum
    datatype case
    typeclass method

    type
    event protocol

    lookup_event_type
    lookup_type
    lookup_typeclass

    resolve_event_types
    resolve_types
    ],
    @ALL_TYPE_GLOBS,
    @ALL_SIGNAL_GLOBS
);

our %EXPORT_TAGS = (
    core        => [ @ALL_TYPE_GLOBS ],
    signals     => [ @ALL_SIGNAL_GLOBS ],
    types       => [qw[ enum type datatype case lookup_type resolve_types ]],
    events      => [qw[ event lookup_event_type resolve_event_types protocol ]],
    typeclasses => [qw[ typeclass method lookup_typeclass ]],
);

# -----------------------------------------------------------------------------
# Type Checkers (INTERNAL USE ONLY)
# -----------------------------------------------------------------------------

my sub check_types ($types, $values) {

    #use Data::Dumper;
    #warn Dumper [ $types, $values ];

    #warn "START";

    # check arity base first ...
    return unless scalar @$types == scalar @$values; # XXX - should this throw an error?

    #warn "HERE";

    foreach my $i ( 0 .. $#{$types} ) {
        my $type  = $types->[$i];
        my $value = $values->[$i];

        #warn Dumper [ $type, $value ];

        # if we encounter a tuple ...
        if ( ref $type eq 'ARRAY' ) {
            # make sure the values are a tuple as well
            return unless ref $value eq 'ARRAY'; # XXX - should this throw an error?

            # otherwise recurse and check the tuple ...
            return unless __SUB__->( $type, $value );
        }
        else {
            return unless $type->check( $value );
        }
    }

    return 1;
}

# -----------------------------------------------------------------------------
# Tyoeclass Builders
# -----------------------------------------------------------------------------

my %TYPECLASS_REGISTRY;

sub method ($, $) { die 'You cannot call `method` outside of a `typeclass`' }

sub typeclass ($t, $body) {
    my $caller = caller;
    my $type   = lookup_type($t->[0]);
    my $symbol = $type->symbol;
    my %cases  = $type->cases->%*;

    warn "Calling typeclass ($symbol) from $caller" if DEBUG;

    my $typeclass = ELO::Core::Typeclass->new( type => $type );

    my $method;

    if ( $type isa ELO::Core::Type::TaggedUnion ) {
        $method = sub ($name, $table) {

            if ( ref $table eq 'CODE' ) {
                foreach my $constructor_symbol ( keys %cases ) {
                    no strict 'refs';
                    #warn "[CODE] ${constructor_symbol}::${name}\n";
                    *{"${constructor_symbol}::${name}"} = $table;
                }
            }
            elsif ( ref $table eq 'HASH' ) {
                foreach my $type_name ( keys %$table ) {
                    my $constructor_symbol = "${symbol}::${type_name}";
                       $constructor_symbol =~ s/main//;

                    #warn "[HASH] SYMBOL: ${constructor_symbol}\n";

                    my $constructor = $cases{ $constructor_symbol };
                    ($constructor)
                        || die "The case($constructor_symbol) is not found the type($symbol)".Dumper(\%cases);

                    my $handler = $table->{$type_name};
                    no strict 'refs';

                    #warn "[HASH] &: ${constructor_symbol}::${name}\n";
                    *{"${constructor_symbol}::${name}"} = sub ($self) { $handler->( @$self ) };
                }
            }
            else {
                die 'Unsupported method type, only CODE and HASH supported';
            }

            $typeclass->method_definitions->{ $name } = $table;
        };
    }
    else {
        die "Unsupported typeclass type($symbol), only datatype(Type::TaggedUnion) is supported";
    }

    no strict 'refs';
    local *{"${caller}::method"} = $method;

    $body->();

    $TYPECLASS_REGISTRY{$symbol} = $typeclass;

    return;
}

# -----------------------------------------------------------------------------
# Tyoe Builders
# -----------------------------------------------------------------------------

my %TYPE_REGISTRY;

sub case ($, @) { die 'You cannot call `case` outside of `datatype`' }

sub datatype ($symbol, $cases) {
    my $caller = caller;
    warn "Calling datatype ($symbol) from $caller" if DEBUG;

    # FIXME - use the MOP here

    no strict 'refs';

    my %cases;
    local *{"${caller}::case"} = sub ($constructor, @definition) {

        my $definition = resolve_types( \@definition );

        my $constructor_tag = "${symbol}::${constructor}";
           $constructor_tag =~ s/main//;

        # TODO:
        # this could be done much nicer, and we can
        # do better in the classes as well. The empty
        # constructor can use a bless scalar (perhaps the constructor name)
        # and we could make them proper classes that use
        # U::O::Imuttable as a base class.
        *{"${caller}::${constructor}"} = scalar @definition == 0
            ? sub ()      { bless [] => $constructor_tag }
            : sub (@args) {
                check_types( $definition, \@args )
                    || die "Typecheck failed for $constructor_tag with (".(join ', ' => @args).')';
                bless [ @args ] => $constructor_tag;
            };

        $cases{$constructor_tag} = ELO::Core::Type::TaggedUnion::Constructor->new(
            symbol      => $constructor,
            constructor => \&{"${caller}::${constructor}"},
            definition  => $definition,
        );
    };

    # first register the type ...
    $TYPE_REGISTRY{ $symbol } = ELO::Core::Type::TaggedUnion->new(
        symbol => $symbol,
        cases  => \%cases,
        checker => sub ( $instance ) {
            my $type = blessed($instance);
            return unless $type;
            return exists $cases{ $type };
        }
    );

    # now create the cases ...
    $cases->();

    # to allow for recurisve types :)
}

sub protocol ($symbol, $events) {
    my $caller = caller;

    no strict 'refs';

    my $orig = \&{"${caller}::event"};

    my %events;
    local *{"${caller}::event"} = sub ($type, @definition) {
        $events{$type} = $orig->($type, @definition);
    };

    $events->();

    #use Data::Dumper;
    #warn Dumper \%events;

    $TYPE_REGISTRY{ $symbol } = ELO::Core::Type::Event::Protocol->new(
        symbol => $symbol,
        events => \%events
    );
}

# TODO:
# move other checkers to the classes

sub event ($type, @definition) {
    warn "Creating event $type" if DEBUG;
    my $definition = resolve_types( \@definition );
    $TYPE_REGISTRY{ $type } = ELO::Core::Type::Event->new(
        symbol     => $type,
        definition => $definition,
        checker    => sub ($values) {
            check_types( $definition, $values );
        }
    );
}

sub enum ($enum, @values) {
    warn "Creating enum $enum" if DEBUG;
    my $i = 0;
    my %enum_map;
    {
        no strict 'refs';
        foreach my $glob (@values) {
            *$glob = \(my $x = $i);  # assign it the value
            $enum_map{ $glob } = $i; # note in the map
            $i++;
        }
    }

    $TYPE_REGISTRY{ $enum } = ELO::Core::Type::Enum->new(
        symbol  => $enum,
        values  => \%enum_map,
        checker => sub ($enum_value) {

            #use Data::Dumper;
            #warn Dumper [ $enum_value, \%enum_map ];

            return defined($enum_value)
                && exists $enum_map{ $enum_value }
        },
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
            symbol  => $type,
            alias   => $alias,
            checker => sub ($value) { $alias->check( $value ) }
        );
    }
}

# -----------------------------------------------------------------------------
# Type Lookup and Resolution
# -----------------------------------------------------------------------------

sub lookup_event_type ($type) {
    warn "Looking up event($type)" if DEBUG;
    $TYPE_REGISTRY{ $type };
    # TODO: make sure the type is an ELO::Core::Type::Event
}

sub lookup_type ( $type ) {
    warn "Looking up type($type)" if DEBUG;
    $TYPE_REGISTRY{ $type };
}

sub lookup_typeclass ($type) {
    warn "Looking up typeclass($type)" if DEBUG;
    $TYPECLASS_REGISTRY{ $type };
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
        my $type = $TYPE_REGISTRY{ $e }
            || die "Could not resolve event($e) in registry";
        # TODO: make sure the type is an ELO::Core::Type::Event
        push @resolved => $type;
    }

    return \@resolved;
}

# -----------------------------------------------------------------------------
# Define Core Types
# -----------------------------------------------------------------------------

# XXX - consider using the builtin functions here:
# - true, false, is_bool
# - created_as_{string,number}

type *Any, sub ($) { return 1 };                # anything ...

type *Scalar, sub ($scalar) {
    return defined($scalar);                    # it is defined ...
};

type *Bool, sub ($bool) {
    return defined($bool)                       # it is defined ...
        && not(ref $bool)                       # ... and it is not a reference
        && ($bool =~ /^[01]$/ || $bool eq '')   # ... and is either 1,0 or an empty string
};

type *Str, sub ($str) {
    return defined($str)                        # it is defined ...
        && not(ref $str)                        # ... and it is not a reference
        && ref(\$str) eq 'SCALAR'               # ... and its just a scalar
};

type *Num, sub ($num) {
    return defined($num)                        # it is defined ...
        && not(ref $num)                        # if it is not a reference
        && looks_like_number($num)              # ... if it looks like a number
};

type *Int, sub ($int) {
    return defined($int)                        # it is defined ...
        && not(ref $int)                        # if it is not a reference
        && looks_like_number($int)              # ... if it looks like a number
        && int($int) == $int                    # and is the same value when converted to int()
};

type *Float, sub ($float) {
    return defined($float)                      # it is defined ...
        && not(ref $float)                      # if it is not a reference
        && looks_like_number($float)            # ... if it looks like a number
        && $float == ($float + 0.0)             # and is the same value when converted to float()
};

type *ArrayRef, sub ($array_ref) {
    return defined($array_ref)                  # it is defined ...
        && ref($array_ref) eq 'ARRAY'           # and it is an ARRAY reference
};

type *HashRef, sub ($hash_ref) {
    return defined($hash_ref)                   # it is defined ...
        && ref($hash_ref) eq 'HASH'             # and it is a HASH reference
};

# -----------------------------------------------------------------------------
# ELO Core Types
# -----------------------------------------------------------------------------

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

# Signals as Events

event *SIGEXIT => (*Process);

# -----------------------------------------------------------------------------

1;

__END__

=pod

=cut
