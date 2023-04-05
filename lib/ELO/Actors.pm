package ELO::Actors;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Exporter 'import';

our @EXPORT = qw[
    match
];

sub match ($msg, $table) {
    my ($event, @args) = @$msg;
    #warn "$event : $table";

    # TODO:
    # add support for `_` as a catch all event handler

    my $cb = $table->{ $event } // die "No match for $event";
    eval {
        $cb->(@args);
        1;
    } or do {
        warn "!!! Died calling msg(".(join ', ' => map { ref $_ ? '['.(join ', ' => @$_).']' : $_ } @$msg).")";
        die $@;
    };
}

1;

__END__

=pod

=cut
