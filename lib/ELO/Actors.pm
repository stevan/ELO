package ELO::Actors;
use v5.36;
use experimental 'try';

use Sub::Util 'set_subname';

use ELO::Types qw[ :events ];

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

sub match ($msg, $table) {
    my ($event, @args) = @$msg;

    my $cb = $table->{ $event };

    die "No match for $event" unless $cb;

    if ( my $event_type = lookup_event_type( $event ) ) {
        warn "Checking $event against $event_type" if DEBUG;
        $event_type->check( @args )
            or die "Event($event) failed to type check (".(join ', ' => @args).")";
    }

    try {
        $cb->(@args);
    } catch ($e) {
        die $e;
    }
}

1;

__END__

=pod

=cut
