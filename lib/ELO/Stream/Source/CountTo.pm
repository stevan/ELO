package ELO::Stream::Source::CountTo;
use v5.36;

use parent 'UNIVERSAL::Object';
use roles 'ELO::Stream::API::Source';
use slots (
    max_value => sub { 10 },
    counter   => sub { 0 },
);

sub has_next ($self) {
    $self->{counter} <= $self->{max_value}
}

sub next ($self) {
    return $self->{counter}++;
}

1;

__END__
