package ELO::Stream::Subscription;
use v5.36;

# Reactive Streams API

sub request; # (Int) -> () # max number of elements the producer can send
sub cancel;  # ()    -> ()

1;

__END__
