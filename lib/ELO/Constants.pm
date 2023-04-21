package ELO::Constants;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Exporter 'import';

our @EXPORT_OK = qw[
    $SIGEXIT
    $SIGWAKE
];

# signals ...

our $SIGEXIT = 'SIGEXIT';
our $SIGWAKE = 'SIGWAKE';

1;

__END__

=pod

=cut
