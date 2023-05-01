package ELO::Core::Event;
use v5.36;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    symbol     => sub {},
    definition => sub {},
    # ...
    _type_lookup => sub {},
);

sub symbol  ($self) { $self->{symbol} }

sub definition ($self) { $self->{definition}->@* }

sub check ($self, @values) {
    my @types  = $self->{definition}->@*;
    my $lookup = $self->{_type_lookup};

    # check arity base first ...
    return unless scalar @types == scalar @values; # XXX - should this throw an error?

    my sub check_types ($types, $values) {
        #use Data::Dumper;
        #warn Dumper [ $types, $values ];

        foreach my $i ( 0 .. $#{$types} ) {
            my $type  = $types->[$i];
            my $value = $values->[$i];

            # if we encounter a tuple ...
            if ( ref $type eq 'ARRAY' ) {
                # make sure the values are a tuple as well
                return unless ref $value eq 'ARRAY'; # XXX - should this throw an error?

                # otherwise recurse and check the tuple ...
                return unless __SUB__->( $type, $value );
            }
            else {
                my $t = $lookup->($type);

                return unless $t; # XXX - this should likely throw an exception

                return unless $t->check( $value );
            }
        }
        return 1;
    }

    return check_types( \@types, \@values );
}

1;

__END__

=pod

=cut
