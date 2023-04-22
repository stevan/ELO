package ELO::Constants;
use v5.36;

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
