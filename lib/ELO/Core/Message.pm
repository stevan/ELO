package ELO::Core::Message;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Scalar::Util 'blessed';
use Data::Dumper 'Dumper';

use ELO::VM ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub new ($class, $pid, $action, $msg) {
    bless [ $pid, $action, $msg ] => $class
}

sub pid    ($self) { $self->[0] }
sub action ($self) { $self->[1] }
sub body   ($self) { $self->[2] }

sub curry ($self, @args) {
    my ($pid, $action, $body) = @$self;
    blessed($self)->new( $pid, $action, [ @$body, @args ] );
}

sub send ($self) { ELO::VM::enqueue_msg($self); $self }
sub send_from ($self, $caller) { ELO::VM::enqueue_msg($self, $caller); $self }

sub to_string ($self) {
    join '' =>
        $self->pid, ' -> ',
            $self->action, ' [ ',
                (join ', ' => map {
                    blessed($_)
                        ? ('('.$_->to_string.')')
                        : (ref $_
                            ? (ref $_ eq 'ARRAY'
                                ? ('['.(join ', ' => map { blessed($_) ? $_->to_string : $_ } @$_).']')
                                : ('{',(join ', ' => %$_),'}')) # XXX - do better
                            : $_)
                } $self->body->@*),
            ' ]';
}

1;

__END__

=pod

=cut
