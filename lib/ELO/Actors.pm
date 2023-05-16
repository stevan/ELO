package ELO::Actors;
use v5.36;
use experimental 'try', 'builtin';

use builtin   qw[ blessed ];
use Sub::Util qw[ set_subname ];

use ELO::Types qw[
    lookup_type
    resolve_event_types
];

use ELO::Core::Behavior::Receive;
use ELO::Core::Behavior::Setup;

use constant DEBUG => $ENV{ACTORS_DEBUG} || 0;

use Exporter 'import';

our @EXPORT_OK = qw[
    match
    build_actor

    setup
    receive
];

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
        $name =~ s/^main\:\://; # strip off main::
        $setup = $args[0];
    }
    else {
        ($name, $setup) = @args;
    }

    ELO::Core::Behavior::Setup->new(
        name  => $name,
        setup => $setup,
    );
}

sub receive (@args) {
    my ($name, $receivers);

    if ( scalar @args == 1 ) {
        $name = (caller(1))[3];
        $name =~ s/^main\:\://; # strip off main::
        $receivers = $args[0];
    }
    else {
        ($name, $receivers) = @args;
    }

    my $protocol = resolve_event_types( [ keys %$receivers ] );
    my %protocol = map { $_->symbol => $_ } @$protocol;

    ELO::Core::Behavior::Receive->new(
        name      => $name,
        receivers => $receivers,
        protocol  => \%protocol,
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
                or die "Event($type) failed to type check (".(join ', ' => @args).")";
            $match = $table->{ $type }
                or die "Unable to find match for Event($type)";
        }
        elsif ( $type_checker isa ELO::Core::Type::TaggedUnion ) {
            my ($arg) = @args;
            $type_checker->check( $arg )
                or die "TaggedUnion::Constructor($type) failed to type check instance of ($arg)";
            # TODO: check the members of table as well
            my $tag = $type_checker->cases->{ blessed( $arg ) }->symbol;
            $match = $table->{ $tag }
                or die "Unable to find match for TaggedUnion::Constructor($type) with tag($tag)";
            # deconstruct the args now ...
            @args = @$arg;
        }
        elsif ( $type_checker isa ELO::Core::Type::Enum ) {
            my ($enum_val) = @args;
            $type_checker->check( $enum_val )
                or die "Enum($type) failed to type check instance of ($enum_val)";
            # TODO: check the members of table as well
            $match = $table->{ $enum_val }
                or die "Unable to find match for Enum($type) with value($enum_val)";
            # clear the args now ...
            @args = ();
        }
        else {
            die "matching on T($type_checker) is not (yet) supported";
        }
    }
    # check other types as well ...

    try {
        $match->(@args);
    } catch ($e) {
        die "Match failed because: $e";
    }
}

1;

__END__

=pod

=cut
