#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Timers', qw[ timer interval cancel_interval ];

my $log = Test::ELO->create_logger;

package Actor::Base {
    use v5.24;
    use warnings;
    use experimental qw[ signatures postderef ];

    use parent 'UNIVERSAL::Object';
    use slots (
        # core slots ...
        _process => sub {},
    );

    sub new_actor_ref ($class, %args) {
        my $self = $class->new( %args );
        sub ($this, $msg) {
            $self->{_process} //= $this;
            $self->receive( $msg );
        }
    }

    sub pid  ($self)            { $self->{_process}->pid               }
    sub send ($self, $to, $msg) { $self->{_process}->send( $to, $msg ) }

    sub receive ($self, $msg) {
        my ($type, @body) = @$msg;
        my $receiver = $self->can( $type );
        die "Cannot handle msg type($type)" unless $receiver;
        $receiver->( $self, @body );
    }
}

package My::Actor {
    use v5.24;
    use warnings;
    use experimental qw[ signatures ];

    our @ISA; BEGIN { @ISA = ('Actor::Base') };
    use slots (
        counter  => sub { 0 },
        greeting => sub { 'Hello' },
    );

    sub eHello ($self, $name) {
        $self->{counter}++;

        $log->info( $self->pid, sprintf "%s %s (%d)" => $self->{greeting}, $name, $self->{counter} );

        if ( $self->{counter} == 2 && $self->{greeting} eq 'Hello' ) {
            $self->{counter}  = 10;
            $self->{greeting} = 'Greetings';
        }
    }
}

sub init ($this, $msg=[]) {

    my $a1 = $this->spawn( Actor => My::Actor->new_actor_ref );
    my $a2 = $this->spawn( Actor => My::Actor->new_actor_ref( greeting => "Bonjour" ) );

    $this->link( $_ ) foreach $a1, $a2;

    my $i = interval( $this, 2, sub {
        $this->send( $a1, [ eHello => 'World' ] );
        $this->send( $a2, [ eHello => 'Monde' ] );
    });

    timer( $this, 10, sub {
        $log->warn( $this, '... exiting' );
        cancel_interval( $i );
        $this->exit(0);
    });

    # async control flow ;)
    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



