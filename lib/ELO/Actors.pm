package ELO::Actors;
use v5.36;
use experimental 'try';

use Sub::Util 'set_subname';

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

        if ( $type_checker isa ELO::Core::Type::Event ) {
            $type_checker->check( \@args )
                or die "Event($type) failed to type check (".(join ', ' => @args).")";
            $match = $table->{ $type }
                or die "Unable to find match for Event($type)";
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
