package ELO::Actors::Actor;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Hash::Util qw[ fieldhash ];

# we specifically use inside-out
# objects here because this is
# really private data for the
# role and there is no need for
# the consumers of this role to
# care about it. It also allows
# the comsuming class to be Immutable
# or even a different REPR type if
# so desired, basically we do not
# force our implementation choice
# on the consumer :)
fieldhash my %receivers;

sub receive; # ($self, ActorRef $this) -> %{ eventType => sub (@eventArgs) :Unit { ... } }

sub apply ($self, $this, $event) {
    eval {
        die 'event must be an ARRAY ref'
            unless ref $event eq 'ARRAY';

        my ($e, @body) = @$event;

        # cache the receivers to
        # avoid having to re-create
        # the subs, and since they
        # are object scoped, they
        # match the lifetime of the
        # actor itself
        my $receivers = $receivers{$self} //= do {
            my $receivers = $self->receive( $this );
            die 'receive did not return a HASH ref'
                unless ref $receivers eq 'HASH';
            $receivers;
        };

        my $receiver = $receivers->{ $e };
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
