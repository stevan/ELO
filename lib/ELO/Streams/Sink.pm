package ELO::Streams::Sink;
use v5.36;

sub on_complete;  # ()             -> ()
sub on_error;     # (Error)        -> ()
sub on_next;      # (T)            -> ()

1;

__END__
