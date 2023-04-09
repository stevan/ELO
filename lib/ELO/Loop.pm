package ELO::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use ELO::Core::Loop;

# static method/functions ...

sub run ($class, $f, %options) {
    my $loop = ELO::Core::Loop->new;
    if ( keys %options ) {
        if ( $options{with_promises} ) {
            require ELO::Core::Promise;
            $ELO::Core::Promise::LOOP = $loop;
        }
    }
    $loop->run( $f );
    return $loop;
}

1;

__END__

=pod

=cut
