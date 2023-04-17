package ELO::Loop;
use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use ELO::Core::Loop;

# static method/functions ...

sub run ($class, $f, %options) {

    my $args;
    my $logger;
    my $env;

    my $loop = ELO::Core::Loop->new;

    # process options ...

    if ( $options{with_promises} ) {
        require ELO::Core::Promise;
        $ELO::Core::Promise::LOOP = $loop;
    }

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

    my $loop = ELO::Core::Loop->new;

    # process options ...

    if ( $options{with_promises} ) {
        require ELO::Core::Promise;
        $ELO::Core::Promise::LOOP = $loop;
    }

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
