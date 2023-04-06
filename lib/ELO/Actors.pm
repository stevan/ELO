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
