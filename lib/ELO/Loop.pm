package ELO::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

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

sub run ($class, $f, %options) {

    my $args;
    my $logger;
    my $env;

    my $loop = build_loop( %options );

    # process options ...
    $args   = $options{args}   if $options{args};
    $logger = $options{logger} if $options{logger};
    $env    = $options{env}    if $options{env};

    # run the loop
    $loop->run( $f, $args // +[], $logger, $env );

    return;
}

sub run_actor ($class, $actor_class, %options) {

    my $actor_args;
    my $logger;
    my $env;

    my $loop = build_loop( %options );

    # process options ...
    $actor_args  = $options{actor_args}  if $options{actor_args};
    $logger      = $options{logger}      if $options{logger};
    $env         = $options{env}         if $options{env};

    # run the loop
    $loop->run_actor( $actor_class, $actor_args // +{}, $logger, $env );

    return;
}

1;

__END__

=pod

=cut
