package ELO::Stream::Source::FromList;
use v5.36;

use parent 'UNIVERSAL::Object';
use roles 'ELO::Stream::API::Source';
use slots (
    list => sub { [] },
    idx  => sub { 0 },
);

sub has_next ($self) {
    $self->{idx} <= scalar $self->{list}->@*
}

sub next ($self) {
    return $self->{list}->[ $self->{idx}++ ];
}

1;

__END__
