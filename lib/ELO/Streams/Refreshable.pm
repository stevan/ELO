package ELO::Streams::Refreshable;
use v5.36;

sub should_refresh; # () -> bool
sub refresh;        # () -> ()

1;

__END__
