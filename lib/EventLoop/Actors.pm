package EventLoop::Actors;

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
    my ($action, $body) = @$msg;
    #warn Dumper [$msg, $table];
    my $cb = $table->{$action} // die "No match for $action";
    $cb->(@$body);
}


1;

__END__

=pod

=cut
