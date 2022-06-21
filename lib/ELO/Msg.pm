package ELO::Msg;
# ABSTRACT: Event Loop Orchestra

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

# NOTE:
# this depends on ELO::Loop being loaded ...
# so we assume that ELO::Loop loads it ..
# use ELO::Core::Message;

use Exporter 'import';

our @EXPORT = qw[
    msg
];

sub msg ($pid, $action, $msg) { ELO::Core::Message->new( $pid, $action, $msg ) }

1;

__END__

=pod

=cut
