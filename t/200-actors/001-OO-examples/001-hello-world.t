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
use ok 'ELO::Timers', qw[ ticker interval_ticker cancel_ticker ];
use ok 'ELO::Actors';
use ok 'ELO::Actors::Actor';

my $log = Test::ELO->create_logger;

package Greeter {
    use v5.24;
    use warnings;
    use experimental 'signatures';

    use parent 'UNIVERSAL::Object::Immutable';
    use roles  'ELO::Actors::Actor';
    use slots (
        greeting => sub { 'Hello' }
    );

    sub receive ($self, $this) {
        $log->warn( $this, '... receive has been called' );
        # all the handlers close over $self and $this

        # XXX:
        # do we need to weaken these references?
        return +{
            Greet => sub ($name) {
                $log->info( $this, join ' ' => $self->{greeting}, $name );
            }
        }
    }
}


sub init ($this, $msg=[]) {

    my $en = $this->spawn_actor( 'Greeter' );
    my $nl = $this->spawn_actor( 'Greeter', { greeting => 'Hallo'   } );
    my $fr = $this->spawn_actor( 'Greeter', { greeting => 'Bonjour' } );

    my $i = interval_ticker( $this, 2, sub {
        $this->send( $en, [ Greet => 'World' ] );
        $this->send( $nl, [ Greet => 'Werld' ] );
        $this->send( $fr, [ Greet => 'Monde' ] );
    });

    $log->warn( $this, '... starting' );

    ticker( $this, 10, sub {
        cancel_ticker( $i );
        $_->exit foreach $en, $nl, $fr, $this
    });
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



