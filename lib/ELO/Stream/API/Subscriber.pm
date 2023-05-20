package ELO::Stream::Subscriber;
use v5.36;

use roles 'ELO::Stream::Sink';

sub on_complete;  # ()             -> ()
sub on_error;     # (Error)        -> ()
sub on_next;      # (T)            -> ()
sub on_subscribe; # (Subscription) -> ()

1;

__END__
