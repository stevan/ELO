#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Time::HiRes 'time';
use List::Util 'sum';

use constant FIB_DEBUG => $ENV{FIB_DEBUG} // 0;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :events :signals ];
use ok 'ELO::Timers', qw[ :timers :tickers ];
use ok 'ELO::Actors', qw[ receive setup ];

our $SEED;

my $log = Test::ELO->create_logger;

protocol *Adder => sub {
    event *Result => ( *Int );
};

sub Adder ($respondant, $sequence_number, $target) {

    my ($left, $right);

    receive[*Adder] => +{
        *Result => sub ( $this, $number ) {
            $log->info( $this, '*Result received for number('.$number.') has left('.($left//'undef').') right('.($right//'undef').')' ) if FIB_DEBUG;

            if ($left) {
                $log->info( $this, '*Result setting right to ('.$number.')') if FIB_DEBUG;
                $right = $number;
            }
            else {
                $log->info( $this, '*Result setting left to ('.$number.')') if FIB_DEBUG;
                $left = $number;
            }

            if (defined $left && defined $right) {
                $log->info( $this, '*Result has both left('.($left//'undef').') right('.($right//'undef').'),  responding with {*Result, '.($left + $right).'}' ) if FIB_DEBUG;
                $this->send( $respondant, [ *Return => $sequence_number, $left + $right, $target ] );
                $log->warn( $this, '... my job is done here') if FIB_DEBUG;
                $this->exit(0);
            }
        }
    };
}


protocol *Fibonacci => sub {
    event *Calculate => ( *Int, *Process );
    event *Return    => ( *Int, *Int, *Process );
};

sub Fibonacci () {

    my %breakers;
    my @cache;
    my %stats = ( hits => [], misses => [] );

    receive[*Fibonacci] => +{
        *Calculate => sub ( $this, $number, $respondant ) {
            $log->info( $this, '*Calculate received for number('.$number.') for respondant('.$respondant->pid.')' ) if FIB_DEBUG;

            if ( defined $cache[$number] ) {
                $log->warn( $this, '*Calculate returning cached result for number('.$number.' = '.$cache[$number].') to respondant('.$respondant->pid.')' ) if FIB_DEBUG;
                $this->send( $respondant, [ *Result => $cache[$number] ] );
                $stats{hits}->[$number]++;
            }
            else {
                $stats{misses}->[$number]++;
                if ( $number < 2 ) {
                    $log->info( $this, '... *Calculate number('.$number.') is less than 2, responding to respondant('.$respondant->pid.') with {*Result, '.$number.'}' ) if FIB_DEBUG;
                    $this->send( $respondant, [ *Result => $number ] );
                    $cache[ $number ] = $number;
                }
                else {
                    my $adder = $this->spawn( Adder($this, $number, $respondant) );
                    $log->info( $this, '>>> *Calculate creating Adder('.$adder->pid.') and recursing ...' ) if FIB_DEBUG;

                    ticker( $this, int(rand($number)), sub{
                        $this->send( $this, [ *Calculate => ($number - 1, $adder) ] );
                        $this->send( $this, [ *Calculate => ($number - 2, $adder) ] );
                    });

                }
            }
        },
        *Return => sub ( $this, $number, $result, $target ) {
            $log->info( $this, '*Return received for result('.$number.' = '.$result.') for delivery to target('.$target->pid.')' ) if FIB_DEBUG;
            $cache[$number] = $result;
            if ($target->pid ne $this->pid) {
                $this->send( $target, [ *Result => $result ] );
            }
        },
        *SIGEXIT => sub ($this, $from) {
            $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            $log->warn( $this,
                join "\n" => 'CACHE:', ('SEED: '.$SEED), map {
                    sprintf '%9s = [%d] = (%s)' => (
                        $_,
                        sum( map { $_//0 } $stats{$_}->@* ),
                        (join ', ' => map { $_//'~' } $stats{$_}->@*),
                    )
                } sort { $a cmp $b } keys %stats
             );
            $this->exit(0);
        }
    };
}

my $num = $ARGV[0] // 10;

my @good_seeds = (
    869318942,
    903645731,
    1617973718,
);

if ($ARGV[1]) {
    warn "SETTING SEED TO ".$ARGV[1];
    $SEED = srand( $ARGV[1] );
}
else {
    warn "SETTING SEED RANDOMLY";
    $SEED = srand;
}
warn "GOT SEED: $SEED";
#die;

sub Init () {

    setup sub ($this) {

        my $fib = $this->spawn( Fibonacci() );

        $fib->trap( *SIGEXIT );
        $fib->link( $this );

        $this->send( $fib, [ *Calculate => $num, $this ] );

        # async control flow ;)
        $log->warn( $this, '... starting' );

        receive +{
            *Result => sub ($this, $result) {
                $log->info( $this, '*Result received for result('.$result.')' );
                $this->kill( $fib );
            },
            *SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            }
        }
    }
}

ELO::Loop->run( Init(), logger => $log );

# Perl

sub fibonacci ($number) {
    if ($number < 2) { # base case
        return $number;
    }
    return fibonacci($number-1) + fibonacci($number-2);
}

my $start = time;
say(join ' = ', $_, fibonacci($_)) foreach ($num);
say("took: ".(scalar(time)- $start));

done_testing;



