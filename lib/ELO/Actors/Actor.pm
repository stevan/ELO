package ELO::Actors::Actor;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

sub receive; # ($self, ActorRef $this) -> %{ eventType => sub (@eventArgs) :Unit { ... } }

sub apply ($self, $this, $event) {
    eval {
        die 'event must be an ARRAY ref'
            unless ref $event eq 'ARRAY';

        my ($e, @body) = @$event;

        my $receive = $self->receive( $this );

        die 'receive did not return a HASH ref'
            unless ref $receive eq 'HASH';

        my $receiver = $receive->{ $e };
        die 'could not find receiver for event('.$e.')'
            unless defined $receiver
                    && ref $receiver eq 'CODE';

        $receiver->( @body );
        1;
    } or do {
        my $e = $@;
        die 'Receive failed because: '.$e;
    };
}

1;

__END__

=pod

=cut
