package ELO::Core::Event;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    symbol     => sub {},
    definition => sub {},
    types      => sub {},
);

sub symbol  ($self) { $self->{symbol} }

sub definition ($self) { $self->{definition}->@* }

sub check ($self, @values) {
    my @types = $self->{types}->@*;

    # check arity first ...
    return unless scalar @types == scalar @values;

    # now check each item ...
    foreach my $i ( 0 .. $#types ) {
        return unless $types[$i]->check( $values[$i] );
    }

    return !!1;
}

1;

__END__

=pod

=cut
