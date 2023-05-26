#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Hash::Util qw[fieldhash];

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :events :signals ];
use ok 'ELO::Timers', qw[ :timers ];
use ok 'ELO::Actors', qw[ receive setup ];

my $log = Test::ELO->create_logger;

protocol *Adder => sub {
    event *Result => ( *Int );
};

sub Adder ($respondant) {

    my ($left, $right);

    receive[*Adder] => +{
        *Result => sub ( $this, $number ) {
            $log->info( $this, '*Result received for number('.$number.') has left('.($left//'undef').') right('.($right//'undef').')' );

            if ($left) {
                $log->info( $this, '*Result setting right to ('.$number.')');
                $right = $number;
            }
            else {
                $log->info( $this, '*Result setting left to ('.$number.')');
                $left = $number;
            }

            if (defined $left && defined $right) {
                $log->info( $this, '*Result has both left('.($left//'undef').') right('.($right//'undef').'),  responding with {*Result, '.($left + $right).'}' );
                $this->send( $respondant, [ *Result => $left + $right ] );
                $this->exit(0)
            }
        }
    };
}


protocol *Fibonacci => sub {
    event *Calculate => ( *Int, *Process );
};

sub Fibonacci () {


    receive[*Fibonacci] => +{
        *Calculate => sub ( $this, $number, $respondant ) {
            $log->info( $this, '*Calculate received for number('.$number.')' );

            if ( $number < 2 ) {
                $log->info( $this, '... *Calculate number('.$number.') is less than 2, responding with {*Result, '.$number.'}' );
                $this->send( $respondant, [ *Result => $number ] );
            }
            else {
                my $adder = $this->spawn( Adder($respondant) );
                $log->info( $this, '>>> *Calculate creating Adder('.$adder->pid.')' );
                $log->info( $this, '... *Calculate recursing' );
                $this->send( $this, [ *Calculate => ($number - 1, $adder) ] );
                $this->send( $this, [ *Calculate => ($number - 2, $adder) ] );
            }
        },
    };
}

## Perl

sub fibonacci ($number) {
    if ($number < 2) { # base case
        return $number;
    }
    return fibonacci($number-1) + fibonacci($number-2);
}

sub cached_fibonacci ($number) {
    state %calculated;

    if (exists $calculated{$number}) {
        return $calculated{$number} ;
    }

    if ($number < 2) { # base case
        return $calculated{$number} = $number;
    }
    return $calculated{$number} = (cached_fibonacci($number-1) + cached_fibonacci($number-2));
}

print((join ' = ', $_, fibonacci($_)),"\n") foreach (1 .. 10);
#print (cached_fibonacci($_),"\n") foreach (1 .. 10);


sub Init () {

    setup sub ($this) {

        my $fib = $this->spawn( Fibonacci() );

        $this->send( $fib, [ *Calculate => 10, $this ] );

        # async control flow ;)
        $log->warn( $this, '... starting' );

        receive +{
            *Result => sub ($this, $result) {
                $log->info( $this, '*Result received for result('.$result.')' );
            },
            *SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            }
        }
    }
}


ELO::Loop->run( Init(), logger => $log );

done_testing;



