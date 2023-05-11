package Test::ELO;
use v5.36;

use ELO::Util::Logger;

use Exporter 'import';

our @EXPORT_OK = qw[

];

sub create_logger ($class) {
    state $logger;
    $logger //= ELO::Util::Logger->new(
        min_level =>
            $ENV{ELO_DEBUG}
                ? ELO::Util::Logger->DEBUG
                : ($ENV{ELO_LOG} || ELO::Util::Logger->TESTING)
    );
}



1;

__END__

=pod

=cut
