package ELO::IO;
use v5.36;

use Term::ReadKey;

use ELO::Timers qw[ :timers ];

use Exporter 'import';

our @EXPORT = qw[
    on_keypress
];


sub on_keypress ($this, $fh, $interval, $callback) {
    ReadMode cbreak => $fh;
    return interval( $this, $interval, sub {
        my $message = ReadKey -1, $fh;
        return unless defined $message;
        if ( $message eq "\e" ) {
            $message .= ReadKey -1, $fh;
            $message .= ReadKey -1, $fh;
        }
        $callback->($message);
    });
    END { ReadMode 'restore' }
}


1;

__END__

=pod

=cut
