package ELO::Stream::Refreshable;
use v5.36;

# ELO Streams API

sub should_refresh; # () -> bool
sub refresh;        # () -> ()

1;

__END__