#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :types :events :signals :typeclasses ];
use ok 'ELO::Actors', qw[ receive setup ];
use ok 'ELO::Timers', qw[ :timers ];
use ok 'ELO::Types',  qw[ *SIGEXIT ];
use ok 'ELO::Streams';

my $log = Test::ELO->create_logger;

# connect the logger
$ELO::Streams::log = $log;

diag "... this one takes a bit";

# ...

my $MAX_ITEMS = 20;

my $Source = SourceFromGenerator(sub {
    state $count = 0;
    return $count if ++$count <= $MAX_ITEMS;
    return;
});

my @Sinks = (
    SinkToBuffer([]),
    SinkToBuffer([]),
    SinkToCallback(sub ($item, $marker) {
        state @sink;
        state $done;

        match [ *SinkMarkers, $marker ], +{
            *SinkDrop  => sub () { push @sink => $item unless $done; },
            *SinkDone  => sub () { $done++ },
            *SinkDrain => sub () { my @d = @sink; @sink = (); $done--; @d; },
        };
    })
);

# ...

sub Init () {

    setup sub ($this) {

        my $publisher   = $this->spawn( Publisher( $Source ) );
        my @subscribers = (
            $this->spawn( Subscriber( 5,  $Sinks[0] ) ),
            $this->spawn( Subscriber( 10, $Sinks[1] ) ),
            $this->spawn( Subscriber( 2,  $Sinks[2] ) ),
        );

        # trap exits for all
        $_->trap( *SIGEXIT )
            foreach ($this, $publisher, @subscribers);

        # link this to the publisher
        $this->link( $publisher );
        # and the publisher to the subsribers
        $publisher->link( $_ ) foreach @subscribers;


        $this->send( $publisher, [ *Subscribe => $_ ]) foreach @subscribers;

        $log->info( $this, '... starting' );

        receive +{
            *SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
                $this->exit(0);
            }
        }
    }
}

ELO::Loop->run( Init(), logger => $log );

my @results = sort { $a <=> $b } map $_->drain, @Sinks;


is_deeply(
    [ @results ],
    [ 1 .. $MAX_ITEMS ],
    '... saw all exepected values'
);

done_testing;

1;

__END__
