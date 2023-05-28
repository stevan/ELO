package ELO::Actors;
use v5.36;
use experimental 'try', 'builtin';

use builtin    qw[ blessed ];
use Sub::Util  qw[ set_subname ];
use List::Util qw[ mesh ];
use Carp       qw[ confess ];

use ELO::Types qw[
    lookup_type
    resolve_event_types
];

use ELO::Core::Type::Event::Protocol;

use ELO::Core::Behavior::Receive;
use ELO::Core::Behavior::Setup;
use ELO::Core::Behavior::Ignore;

use constant DEBUG => $ENV{ACTORS_DEBUG} || 0;

use Exporter 'import';

our @EXPORT_OK = qw[
    match
    build_actor

    setup
    receive

    IGNORE
];

use constant IGNORE => ELO::Core::Behavior::Ignore->new;

sub build_actor ($name, $f) {
    state %counters;
    my $caller = (caller(1))[3];
    set_subname sprintf('%s::%s[%d]' => $caller, $name, $counters{$name}++), $f;
    $f;
}

sub setup (@args) {
    my ($name, $setup);

    if ( scalar @args == 1 ) {
        $name = (caller(1))[3];
        #$name =~ s/^main\:\://; # strip off main::
        $setup = $args[0];
    }
    else {
        ($name, $setup) = @args;
    }

    #set_subname( "${name}::setup" => $setup );

    ELO::Core::Behavior::Setup->new(
        name  => $name,
        setup => $setup,
    );
}

sub receive (@args) {
    my ($name, $receivers, $protocol);

    if ( scalar @args == 1 ) {
        ref $args[0] eq 'HASH'
            || confess 'If you only pass one arg to receive then it must be a HASH ref';
        $name = (caller(1))[3];
        #$name =~ s/^main\:\://; # strip off main::
        $receivers = $args[0];
    }
    else {
        ref $args[0] eq 'ARRAY' && ref $args[1] eq 'HASH'
            || confess 'If you pass two args to receive then it must be an ARRAY ref and a HASH ref';
        $receivers = $args[1];
        if ( scalar $args[0]->@* == 2 ) {
            ($name, $protocol) = $args[0]->@*;
            $protocol = lookup_type( $protocol )
                or confess 'Could not find protocol('.$protocol.')';

        }
        elsif ( scalar $args[0]->@* == 1 ) {
            if ( ref \($args[0]->[0]) eq 'GLOB' ) {
                $protocol = lookup_type( $args[0]->[0] )
                    or confess 'Could not find protocol('.$protocol.')';
                $name = (caller(1))[3];
                #$name =~ s/^main\:\://; # strip off main::
            }
            else {
                $name = $args[0]->[0];
            }
        }
        else {
            confess 'Too many args to receive [@args] +{}, expected 2 @args, got '.scalar $args[0]->@*;
        }
    }

    unless ($protocol) {
        # create a protocol if we need to
        my @events = keys %$receivers;
        my %events = mesh \@events, resolve_event_types( \@events );

        $protocol = ELO::Core::Type::Event::Protocol->new(
            events => \%events
        );
    }

    foreach my $key ( keys %$receivers ) {
        set_subname( "${name}::${key}" => $receivers->{ $key } );
    }

    ELO::Core::Behavior::Receive->new(
        name      => $name,
        receivers => $receivers,
        protocol  => $protocol,
    );
}

# This shoud be moved to ELO::Types
sub match ($target, $table) {
    my ($type, @args) = @$target;

    my $match;
    if ( my $type_checker = lookup_type( $type ) ) {
        warn "Checking $type against $type_checker" if DEBUG;

        # TODO - turn conditionals into polymorphic method calls
        #
        # NOTE:
        # they can be just deconstructable, like event
        # or deconstructable and bounds checkable, like tagged unions
        # or just bounds checkable, like enums
        #
        # bounds checks should be memoized, so we dont
        # have to do them every time match is called

        if ( $type_checker isa ELO::Core::Type::Event ) {
            $type_checker->check( \@args )
                or confess "Event($type) failed to type check (".(join ', ' => @args).")";
            $match = $table->{ $type }
                or confess "Unable to find match for Event($type)";
        }
        elsif ( $type_checker isa ELO::Core::Type::Event::Protocol ) {

            my ($msg) = @args;
            $type_checker->check( $msg )
                or confess "Event::Protocol($type) failed to type check msg(".(join ', ' => @$msg).")";

            my ($event, @_args) = @$msg;
            $match = $table->{ $event }
                or confess "Unable to find match for Event::Protocol($type) with event($event)";
            # fixup the args ...
            @args = @_args;

        }
        elsif ( $type_checker isa ELO::Core::Type::TaggedUnion ) {
            my ($arg) = @args;
            $type_checker->check( $arg )
                or confess "TaggedUnion::Constructor($type) failed to type check instance of ($arg)";
            # TODO: check the members of table as well
            my $tag = $type_checker->cases->{ blessed( $arg ) }->symbol;
            $match = $table->{ $tag }
                or confess "Unable to find match for TaggedUnion::Constructor($type) with tag($tag)";
            # deconstruct the args now ...
            @args = @$arg;
        }
        elsif ( $type_checker isa ELO::Core::Type::Enum ) {
            my ($enum_val) = @args;
            $type_checker->check( $enum_val )
                or confess "Enum($type) failed to type check instance of ($enum_val)";
            # TODO: check the members of table as well
            $match = $table->{ $enum_val }
                or confess "Unable to find match for Enum($type) with value($enum_val)";
            # clear the args now ...
            @args = ();
        }
        else {
            confess "matching on T($type_checker) is not (yet) supported";
        }
    }
    else {
        confess "Could not locate type($type), no match available";
    }
    # check other types as well ...

    try {
        $match->(@args);
    } catch ($e) {
        confess "Match failed because: $e";
    }
}

1;

__END__

=pod

=cut
