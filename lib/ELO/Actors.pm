package ELO::Actors;
use v5.36;
use experimental 'try';

use Sub::Util 'set_subname';

use ELO::Types 'lookup_event_type';

use ELO::Core::Behavior::Receiver;

use constant DEBUG => $ENV{ACTORS_DEBUG} || 0;

use Exporter 'import';

our @EXPORT_OK = qw[
    match
    build_actor

    receive
];

sub build_actor ($name, $f) {
    state %counters;
    my $caller = (caller(1))[3];
    set_subname sprintf('%s::%s[%d]' => $caller, $name, $counters{$name}++), $f;
    $f;
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

    ELO::Core::Behavior::Receiver->new(
        name          => $name,
        receivers     => $receivers,
        _event_lookup => \&lookup_event_type
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
