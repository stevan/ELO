package EventLoop::IO;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::Dumper 'Dumper';

## ... i/o

sub err::log ($msg, $caller=$EventLoop::CURRENT_CALLER) {
    my $args = [ $EventLoop::ERR, print => [ $msg, $caller ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub err::logf ($fmt, $msg, $caller=$EventLoop::CURRENT_CALLER) {
    my $args = [ $EventLoop::ERR, printf => [ $fmt, $msg, $caller ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub out::print ($msg=undef) {
    my $args = [ $EventLoop::OUT, print => [ $msg // () ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub out::printf ($fmt, $msg=undef) {
    my $args = [ $EventLoop::OUT, printf => [ $fmt, $msg // () ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

sub in::read ($prompt=undef) {
    my $args = [ $EventLoop::IN, read => [ $prompt // () ]];
    defined wantarray ? $args : EventLoop::send_to( @$args );
}

1;

__END__

=pod

=cut
