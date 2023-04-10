package ELO::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use ELO::Core::Loop;

# static method/functions ...

sub run ($class, $f,  %options) {

    my $args;
    my $logger;

    my $loop = ELO::Core::Loop->new;

    # process options ...

    if ( $options{with_promises} ) {
        require ELO::Core::Promise;
        $ELO::Core::Promise::LOOP = $loop;
    }

    $args   = $options{args}   if $options{args};
    $logger = $options{logger} if $options{logger};

    # run the loop

    $loop->run( $f, $args, $logger );

    return;
}

1;

__END__

=pod

=cut
