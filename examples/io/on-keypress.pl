#!perl

use v5.36;

$|++;

use Test::More;
use Test::Differences;
use Test::ELO;

use Term::ReadKey;

use Data::Dumper;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :types :events ];
use ok 'ELO::Timers', qw[ :tickers :timers ];
use ok 'ELO::Actors', qw[ receive ];

use ELO::Graphics;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point(40, 80) )
);

use ELO::IO;

my $log = Test::ELO->create_logger;

enum *Direction => (
    *Up, *Down, *Left, *Right
);

event *Move => ( *Direction );

sub Turtle (%args) {

    my $location = Point( 10, 10 );

    receive +{
        *Move => sub ( $this, $direction ) {
            $log->info( $this, "got *Move with ($direction)" );
            warn "got *Move with ($direction)\n";

            $d->poke( $location, ColorPixel( Color( 0.1, 0.4, 0.9 ) ) );

            $location = match[*Direction, $direction] => +{
                *Up    => sub { $location->add(Point( 0, -1)) },
                *Down  => sub { $location->add(Point( 0,  1)) },
                *Left  => sub { $location->add(Point(-1,  0)) },
                *Right => sub { $location->add(Point( 1,  0)) },
            };

            $d->poke( $location, ColorPixel( Color( 0.9, 0.4, 0.1 ) ) );
        }
    };
}

sub init ($this, $msg=[]) {

    my $a = $this->spawn( Turtle() );

    on_keypress( $this, *STDIN, 0.03, sub ($key) {

        my $direction;
        $direction = *Up    if $key eq "\e[A";
        $direction = *Left  if $key eq "\e[D";
        $direction = *Down  if $key eq "\e[B";
        $direction = *Right if $key eq "\e[C";

        $this->send( $a => [ *Move => $direction ]) if $direction;
    });

    # async control flow ;)
    $log->warn( $this, '... starting' );
}

ELO::Loop->run( \&init, logger => $log );

done_testing;


__END__


