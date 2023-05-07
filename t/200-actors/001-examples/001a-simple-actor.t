#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core event ];
use ok 'ELO::Actors', qw[ match build_actor ];
use ok 'ELO::Timers', qw[ :tickers ];

my $log = Test::ELO->create_logger;

package ELO::Core::Behavior2 {
    use v5.36;

    use ELO::Actors qw[ match ];

    use parent 'UNIVERSAL::Object::Immutable';
    use slots (
        name     => sub { die 'A `name` is required' },
        reactors => sub { die 'A `reactors` is required' },
    );

    sub name ($self) { $self->{name} }

    sub apply ($self, $this, $event) {
        my ($type, @payload) = @$event;
        my $f = $self->{reactors}->{ $type } // do {
            die 'Could not find reactor for type('.$type.')';
        };
        $f->( $this, @payload );
    }
}

sub receive ($reactors) {
    my $name = (caller(1))[3];
    $name =~ s/^main\:\://; # strip off main::
    ELO::Core::Behavior2->new( name => $name, reactors => $reactors );
}

#setup { say "HI!" };


event *eHello => ( *Str );

sub Greeter ($greeting='Hello') {

    my $counter = 0;

    receive {
        *eHello => sub ( $this, $name ) {
            $counter++;
            $log->info( $this, "$greeting $name ($counter)" );
            if ( $counter == 2 && $greeting eq 'Hello' ) {
                $counter  = 10;
                $greeting = 'Greetings';
            }
        }
    };
}

sub init ($this, $msg=[]) {

    my $a1 = $this->spawn_actor( Greeter() );
    my $a2 = $this->spawn_actor( Greeter( "Bonjour" ) );
    my $a3 = $this->spawn_actor( Greeter( "Hallo" ) );

    $this->link( $_ ) foreach $a1, $a2, $a3;

    my $i = interval_ticker( $this, 2, sub {
        state $x = 0;
        $x++;
        $this->send( $a1, [ *eHello => 'World interval('.$x.')' ] );
        $this->send( $a2, [ *eHello => 'Monde interval('.$x.')' ] );
        $this->send( $a3, [ *eHello => 'Werld interval('.$x.')' ] );
    });

    ticker( $this, 10, sub {
        $log->warn( $this, '... exiting' );
        cancel_ticker( $i );
        $this->exit(0);
    });

    # async control flow ;)
    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;



