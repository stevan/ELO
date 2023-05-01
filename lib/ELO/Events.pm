package ELO::Events;
use v5.36;

use ELO::Core::Event;

use ELO::Types 'lookup_type';

use constant DEBUG => $ENV{EVENTS_DEBUG} || 0;

use Exporter 'import';

our @EXPORT_OK = qw[
    event

    lookup_event_type
];

our %EXPORT_TAGS = ();

my %EVENT_REGISTRY;

sub lookup_event_type ($type) {
    warn "Looking up $type" if DEBUG;
    $EVENT_REGISTRY{ $type }
}

sub event ($type, @definition) {
    warn "Creating event $type" if DEBUG;
    $EVENT_REGISTRY{ $type } = ELO::Core::Event->new(
        symbol     => $type,
        definition => \@definition,
        types      => [ map lookup_type( $_ ), @definition ],
    );
}

1;

__END__

=pod

=cut
