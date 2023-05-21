package ELO::Stream::Sink;
use v5.36;

# ELO Streams API

sub on_complete;  # ()             -> ()
sub on_error;     # (Error)        -> ()
sub on_next;      # (T)            -> ()

1;

__END__

role Source {
    has_next;
    next;
}

role Sink {
    on_complete;
    on_error;
    on_next;
}


$loop->next_tick(sub {
    if ( Source.has_next ) {
        try {
            Sink.on_next( Source.next );
        } catch ($e) {
            Sink.on_error( $e );
        }

        $loop->next_tick( \&__SUB__ );
    }
    else {
        Sink.on_complete();
    }
})


while ( Source.has_next ) {
    try {
        Sink.on_next( Source.next )
    } catch ($e) {
        Sink.on_error( $e )
    }
}

Sink.on_complete;
