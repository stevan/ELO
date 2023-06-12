package ELO::Types;
use v5.36;
use experimental 'builtin';

use builtin      qw[ blessed ];
use Carp         qw[ confess ];
use Scalar::Util qw[ looks_like_number ];
use Sub::Util    qw[ set_subname ];
use List::Util   qw[ first ];

use ELO::Core::Type;
use ELO::Core::Type::Alias;
use ELO::Core::Type::Tuple;
use ELO::Core::Type::Event;
use ELO::Core::Type::Event::Protocol;
use ELO::Core::Type::Enum;
use ELO::Core::Type::TaggedUnion;

use ELO::Core::Type::Tuple::Constructor;
use ELO::Core::Type::TaggedUnion::Constructor;

use ELO::Core::Typeclass;

use constant DEBUG => $ENV{TYPES_DEBUG} || 0;

# -----------------------------------------------------------------------------
# Setup the Core Types
# -----------------------------------------------------------------------------

my @PERL_TYPES = (
    *Any,      # any value
    *Scalar,   # a defined value

    *Undef,    # undef value
    *Bool,     # 1, 0 or ''
    *Char,     # single character
    *Str,      # pretty much anything
    *Num,      # any numeric value
    *Int,      # if it looks like a number and int($_) == $_
    *Float,    # if it looks like a number

    *ArrayRef, # an ARRAY reference
    *HashRef,  # a HASH reference

    # NOT SERIALIZABLE:

    *CodeRef,  # a CODE reference

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

sub method ($, $) { confess 'You cannot call `method` outside of a `typeclass`' }

sub typeclass ($t, $body) {
    my $caller = caller;
    my $type   = lookup_type($t->[0]);
    my $symbol = $type->symbol;

    warn "Calling typeclass ($symbol) from $caller" if DEBUG;

    my $typeclass = ELO::Core::Typeclass->new( type => $type );

    my $method;

    if ( $type isa ELO::Core::Type::TaggedUnion ) {

        my %cases  = $type->cases->%*;

        $method = sub ($name, $table) {

            if ( ref $table eq 'CODE' ) {
                foreach my $constructor_symbol ( keys %cases ) {
                    no strict 'refs';
                    #warn "[CODE] ${constructor_symbol}::${name}\n";
                    *{"${constructor_symbol}::${name}"} = set_subname(
                        "${constructor_symbol}::${name}" => $table
                    );
                }
            }
            elsif ( ref $table eq 'HASH' ) {
                foreach my $type_name ( keys %$table ) {
                    my $constructor_symbol = "${symbol}::${type_name}";
                       $constructor_symbol =~ s/main//;

                    #warn "[HASH] SYMBOL: ${constructor_symbol}\n";

                    my $constructor = $cases{ $constructor_symbol };
                    ($constructor)
                        || confess "In typeclass($symbol) the case($constructor_symbol) is not found, must be one of (".(join ', ' => keys %cases).')';

                    my $body;

                    my $handler = $table->{$type_name};

                    if (ref $handler ne 'CODE') {
                        my @definitions = $constructor->definition;

                        my $i;
                        for ($i = 0; $i < $#definitions; $i++) {
                            #warn "$body ==? ".$definitions[$i]->symbol;
                            last if $handler eq $definitions[$i]->symbol;
                        }

                        confess 'Could not find symbol('.$body.') in type definition tuple['.$type->symbol.']'
                            unless defined $i;

                        # encapsulation ;)
                        $body = sub ($_t) { $_t->[$i] };
                    }
                    else {
                        $body = sub ($_t) { $handler->( @$_t ) }
                    }

                    no strict 'refs';

                    #warn "[HASH] &: ${constructor_symbol}::${name}\n";
                    *{"${constructor_symbol}::${name}"} = set_subname(
                        "${constructor_symbol}::${name}" => $body
                    );
                }
            }
            elsif ( ref((my $x = \$table)) eq 'GLOB' ) {

                foreach my $constructor_symbol ( keys %cases ) {
                    no strict 'refs';

                    my @definitions = $cases{$constructor_symbol}->definition;

                    my $i;
                    for ($i = 0; $i < $#definitions; $i++) {
                        #warn "$body ==? ".$definitions[$i]->symbol;
                        last if $table eq $definitions[$i]->symbol;
                    }

                    confess 'Could not find symbol('.$table.') in type definition tuple['.$type->symbol.']'
                        unless defined $i;

                    # encapsulation ;)
                    my $body = sub ($_t) { $_t->[$i] };

                    *{"${constructor_symbol}::${name}"} = set_subname(
                        "${constructor_symbol}::${name}" => $body
                    );
                }

            }
            else {
                confess 'Unsupported method type, only CODE, GLOB and HASH[CODE], HASH[GLOB] supported';
            }

            $typeclass->method_definitions->{ $name } = $table;
        };
    }
    elsif ( $type isa ELO::Core::Type::Tuple ) {
        confess 'Cannot create typeclass for tuple['.$type->symbol.'] because '.$type->symbol.' does not have a constructor'
            unless $type->has_constructor;

        my $constructor_symbol = $type->constructor->symbol;
           $constructor_symbol =~ s/main//;

        my @definitions = $type->definition;

        $method = sub ($name, $body) {
            no strict 'refs';
            if (ref $body ne 'CODE') {
                my $i;
                for ($i = 0; $i < $#definitions; $i++) {
                    #warn "$body ==? ".$definitions[$i]->symbol;
                    last if $body eq $definitions[$i]->symbol;
                }

                confess 'Could not find symbol('.$body.') in type definition tuple['.$type->symbol.']'
                    unless defined $i;

                # encapsulation ;)
                $body = sub ($_t) { $_t->[$i] };
            }

            #warn "[tuple] &: ${constructor_symbol}::${name}\n";
            *{"${constructor_symbol}::${name}"} = set_subname(
                "${constructor_symbol}::${name}" => $body
            );
            $typeclass->method_definitions->{ $name } = $body;
        };
    }
    else {
        confess "Unsupported typeclass type($symbol), only datatype(Type::TaggedUnion, Type::Tuple) is supported";
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

sub case ($, @) { confess 'You cannot call `case` outside of `datatype`' }

sub datatype ($symbol, @args) {
    my $caller = caller;

    # Tuples with constructor
    if ( ref $symbol eq 'ARRAY' ) {
        my $constructor = $symbol->[0];
                $symbol = $symbol->[1];

        warn "Calling datatype[tuple] [ $constructor => $symbol ] from $caller" if DEBUG;

        my $definition = resolve_types( \@args );

        my $constructor_symbol = "${symbol}"; # ::${constructor}";
           $constructor_symbol =~ s/main//;

        no strict 'refs';

        *{"${caller}::${constructor}"} = set_subname(
            "${caller}::${constructor}",
            (scalar @$definition == 0
                ? sub ()      { bless [] => $constructor_symbol }
                : sub (@args) {
                    check_types( $definition, \@args )
                        || confess "Typecheck failed for $constructor_symbol with (".(join ', ' => map $_//'undef', @args).')';
                    bless [ @args ] => $constructor_symbol;
                }
            )
        );

        $TYPE_REGISTRY{ $symbol } = ELO::Core::Type::Tuple->new(
            symbol      => $symbol,
            definition  => $definition,
            checker     => sub ($values) {
                # we only want to accept blessed values ...
                return unless $values isa $constructor_symbol;
                return check_types( $definition, $values )
            },
            constructor => ELO::Core::Type::Tuple::Constructor->new(
                symbol      => $constructor_symbol,
                constructor => \&{"${caller}::${constructor}"},
                definition  => $definition,
            )
        );

    }
    # Tagged Unions
    else {
        warn "Calling datatype[tagged-union] ($symbol) from $caller" if DEBUG;

        my ($case_builder) = @args;

        # FIXME - use the MOP here

        no strict 'refs';

        my %cases;
        local *{"${caller}::case"} = sub ($constructor, @definition) {

            my $definition = resolve_types( \@definition );

            my $constructor_symbol = "${symbol}::${constructor}";
               $constructor_symbol =~ s/main//;

            # TODO:
            # this could be done much nicer, and we can
            # do better in the classes as well. The empty
            # constructor can use a bless scalar (perhaps the constructor name)
            # and we could make them proper classes that use
            # U::O::Imuttable as a base class.

            # NOTE:
            # It should also be possible to optimize the storage
            # type, using the smallest/smartest type for each, such as:
            # - for constructors with no args, an empty scalar ref
            # - for constructors with 1 arg, a ref of that value
            # - for constructors with n args, use an ARRAY ref
            # This will add some complexity to `typeclass` above
            # because it assumes an ARRAY ref and just de-refs it
            # but that is a solvable problem.
            *{"${caller}::${constructor}"} = set_subname(
                "${caller}::${constructor}",
                (scalar @definition == 0
                    ? sub ()      { bless [] => $constructor_symbol }
                    : sub (@args) {
                        check_types( $definition, \@args )
                            || confess "Typecheck failed for $constructor_symbol with (".(join ', ' => map $_//'undef', @args).')';
                        bless [ @args ] => $constructor_symbol;
                    }
                )
            );

            $cases{$constructor_symbol} = ELO::Core::Type::TaggedUnion::Constructor->new(
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
                # FIXME:
                # this can be improved with a simple `isa` check
                # against all the case classes, OR we could give
                # them a base class instead.
                my $type = blessed($instance);
                return unless $type;
                return exists $cases{ $type };
            }
        );

        # now create the cases ...
        $case_builder->();

        # to allow for recurisve types :)
    }
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
    my %enum_map;
    foreach my $value (@values) {
        $enum_map{ $value }++;
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

sub type ($type, $checker, %params) {
    warn "Creating type $type" if DEBUG;

    if ( ref $checker eq 'CODE' ) {
        $TYPE_REGISTRY{ $type } = ELO::Core::Type->new(
            symbol  => $type,
            checker => $checker,
            params  => \%params, # the definition of the parameters ...
        );
    }
    elsif ( ref $checker eq 'ARRAY' ) {
        my $definition = resolve_types( $checker );
        $TYPE_REGISTRY{ $type } = ELO::Core::Type::Tuple->new(
            symbol     => $type,
            definition => $definition,
            checker    => sub ($values) {
                check_types( $definition, $values );
            }
        );
    }
    else {
        my $alias = $TYPE_REGISTRY{ $checker }
            || confess "Unable to alias type($type) to alias($checker): alias type not found";

        my $param_checker;

        # NOTE: params is a single key/value pair
        if (%params) {
            $param_checker = $alias->build_params_checker( %params );
        }

        $TYPE_REGISTRY{ $type } = ELO::Core::Type::Alias->new(
            symbol  => $type,
            alias   => $alias,
            checker => sub ($value) {
                # TODO:
                # wrap this in try/catch and wrap the
                # error message accordingly, this should
                # cascade down the tree accordingly
                $alias->check( $value )
                    && ($param_checker ? $param_checker->( $value ) : 1)
            }
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
                || confess "Could not resolve type($t) in registry";

            push @resolved => $type;
        }
    }

    return \@resolved;
}

sub resolve_event_types ( $events ) {
    my @resolved;
    foreach my $e ( @$events ) {
        my $type = $TYPE_REGISTRY{ $e }
            || confess "Could not resolve event($e) in registry";
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

type *Undef, sub ($undef) {
    return !defined($undef);                    # it is not defined ...
};

type *Bool, sub ($bool) {
    return defined($bool)                       # it is defined ...
        && not(ref $bool)                       # ... and it is not a reference
        && ($bool =~ /^[01]$/ || $bool eq '')   # ... and is either 1,0 or an empty string
};

type *Char, sub ($char) {
    return defined($char)                        # it is defined ...
        && not(ref $char)                        # ... and it is not a reference
        && ref(\$char) eq 'SCALAR'               # ... and its just a scalar
        # FIXME: this doesn't work for unicode chars
        # and I don't want to figure out why now, so
        # I will leave this here.
        #&& length($char) == 1                    # ... and has a length of one
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
}, (
    # parameters
    range => sub ($min, $max) { # << the arguments passed with parameter
        # a function to be appended to the
        # check for *Int above ...
        sub ($int) { $int >= $min && $int <= $max }
    }
);

type *Float, sub ($float) {
    return defined($float)                      # it is defined ...
        && not(ref $float)                      # if it is not a reference
        && looks_like_number($float)            # ... if it looks like a number
        && $float == ($float + 0.0)             # and is the same value when converted to float()
};

type *ArrayRef, sub ($array_ref) {
    return defined($array_ref)                  # it is defined ...
        && ref($array_ref) eq 'ARRAY'           # and it is an ARRAY reference
}, (
    # parameters
    of => sub ($type) {
        my $t = lookup_type( $type ) // die "Could not find type($type) for ArrayRef of";
        sub ($array_ref) {
            foreach ( @$array_ref ) {
                return unless $t->check( $_ );
            }
            return 1;
        }
    }
);

type *HashRef, sub ($hash_ref) {
    return defined($hash_ref)                   # it is defined ...
        && ref($hash_ref) eq 'HASH'             # and it is a HASH reference
};

type *CodeRef, sub ($code_ref) {
    return defined($code_ref)                   # it is defined ...
        && ref($code_ref) eq 'CODE'             # and it is a CODE reference
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
