package ELO::Actors::Actor;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

sub receive; # ($self, ActorRef $this) -> %{ eventType => sub (@eventArgs) :Unit { ... } }

1;

__END__

=pod

=cut
