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
use ok 'ELO::Timers', qw[ timer interval cancel_interval ];
use ok 'ELO::Actors';
use ok 'ELO::Actors::Actor';

my $log = Test::ELO->create_logger;

package Greeter {
    use v5.24;
    use warnings;
    use experimental 'signatures';

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Actors::Actor';
    use slots (
        greeting => sub { 'Hello' }
    );

    sub receive ($self, $this) {
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

    $this->send( $en, [ Greet => 'World' ] );
    $this->send( $nl, [ Greet => 'Werld' ] );
    $this->send( $fr, [ Greet => 'Monde' ] );

    $log->warn( $this, '... starting' );

    timer( $this, 1, sub {
        $_->exit foreach $en, $nl, $fr, $this
    });
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



