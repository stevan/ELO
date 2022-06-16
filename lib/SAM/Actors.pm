package SAM::Actors;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';

use Exporter 'import';

our @EXPORT = qw[
    match
    actor
];

my %actors;

sub get_actor ($name) {
    $actors{$name};
}

sub actor ($name, $recieve) {
    $actors{$name} = $recieve;
}

sub match ($msg, $table) {
    #warn Dumper [$msg, $table];
    my $cb = $table->{$msg->action} // die "No match for ".$msg->action;
    eval {
        $cb->($msg->body->@*);
        1;
    } or do {
        warn "Died calling msg(".(join ', ' => map { ref $_ ? '['.(join ', ' => @$_).']' : $_ } @$msg).")";
        die $@;
    };
}


1;

__END__

=pod

=cut
