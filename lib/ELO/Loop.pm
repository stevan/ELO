package ELO::Loop;
use v5.36;

use ELO::Core::Loop;
use ELO::Core::Promise;

# static method/functions ...

my sub build_loop (%options) {
    my $loop = ELO::Core::Loop->new(
        (exists $options{tick_delay} || $ENV{ELO_TICK_DELAY}
            ? (tick_delay => $options{tick_delay} // $ENV{ELO_TICK_DELAY})
            : ())
    );

    if ( $options{with_promises} ) {
        $ELO::Core::Promise::LOOP = $loop;
    }

    return $loop;
}

sub run ($class, $b, %options) {

    my $args;
    my $logger;

    my $loop = build_loop( %options );

    # process options ...
    $args   = $options{args}   if $options{args};
    $logger = $options{logger} if $options{logger};

    # run the loop
    $loop->run( $b, $args, $logger );

    return;
}

1;

__END__

=pod

=cut
