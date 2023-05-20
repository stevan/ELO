package ELO::Stream::Subscriber::AutoRefresh;
use v5.36;

# TODO: Rename this Behavior::AutoRefresh or something

use roles 'ELO::Stream::API::Refreshable';
use slots (
    request_size => sub {},
);

sub request_size ($self) { $self->{request_size} }

sub should_refresh;
sub on_refresh;

sub refresh ($self, $subscription) {
    $self->on_refresh( $subscription );
    $subscription->request( $self->{request_size} );
    return;
}

1;

__END__
