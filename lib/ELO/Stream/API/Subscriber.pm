package ELO::Stream::Subscriber;
use v5.36;

use roles 'ELO::Stream::Sink';

# Reactive Streams API

sub on_complete;  # ()             -> ()
sub on_error;     # (Error)        -> ()
sub on_next;      # (T)            -> ()
sub on_subscribe; # (Subscription) -> ()

# ELO Streams API

sub is_full;      # () -> Bool

1;

__END__



