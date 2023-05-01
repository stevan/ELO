package ELO::Actors;
use v5.36;

use Sub::Util 'set_subname';

use ELO::Events 'lookup_event_type';

use constant DEBUG => $ENV{ACTORS_DEBUG} || 0;

use Exporter 'import';

our @EXPORT_OK = qw[
    match
    build_actor
];

sub build_actor ($name, $f) {
    state %counters;
    my $caller = (caller(1))[3];
    set_subname sprintf('%s::%s[%d]' => $caller, $name, $counters{$name}++), $f;
    $f;
}

sub match ($msg, $table) {
    my ($event, @args) = @$msg;

    my $cb = $table->{ $event };

    # NOTE:
    # I want to support this, but _ doesn't
    # really fit in Perl, it already has meaning
    # and we need something better.
    #
    # $cb = $table->{'_'}
    #     if not defined $cb
    #     && exists $table->{'_'};

    die "No match for $event" unless $cb;

    if ( my $event_type = lookup_event_type( $event ) ) {
        warn "Checking $event against $event_type" if DEBUG;
        $event_type->check( @args )
            or die "Event($event) failed to type check (".(join ', ' => @args).")";
    }

    eval {
        $cb->(@args);
        1;
    } or do {
        #warn "!!! Died calling msg(".(join ', ' => map { ref $_ ? '['.(join ', ' => @$_).']' : $_ } @$msg).")";
        die $@;
    };
}

1;

__END__

=pod

=cut
