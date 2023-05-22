package ELO::Stream::Sink;
use v5.36;

# ELO Streams API

sub on_complete;  # ()             -> ()
sub on_error;     # (Error)        -> ()
sub on_next;      # (T)            -> ()

1;

__END__

