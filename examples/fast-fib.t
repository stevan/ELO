#!perl

use v5.36;

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use Term::ANSIColor 'colored';
use Time::HiRes 'time';
use List::Util 'sum', 'min', 'max';

use constant FIB_DEBUG => $ENV{FIB_DEBUG} // 0;

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :events :signals ];
use ok 'ELO::Timers', qw[ :timers :tickers ];
use ok 'ELO::Actors', qw[ receive setup ];

# TODO:
# turn this into something that can test different seeds automatically
# also improve the display with:
#  - the fib sequence itself
#  - the order in which they were called
# make the graph display a generic thing



our $SEED;

my $log = Test::ELO->create_logger;

protocol *Adder => sub {
    event *Result => ( *Int );
};

my $EVENT_ID;
my @EVENTS;

my @adder_ordering;

sub Adder ($respondant, $sequence_number, $target) {

    my ($left, $right);

    receive[*Adder] => +{
        *Result => sub ( $this, $number ) {
            $log->info( $this, '*Result received for number('.$number.') has left('.($left//'undef').') right('.($right//'undef').')' ) if FIB_DEBUG;

            if ($left) {
                $log->info( $this, '*Result setting right to ('.$number.')') if FIB_DEBUG;
                push @adder_ordering => [ left => $number ];
                $right = $number;
            }
            else {
                $log->info( $this, '*Result setting left to ('.$number.')') if FIB_DEBUG;
                push @adder_ordering => [ right => $number ];
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
    event *DumpStats => ( *HashRef );
};

my %stats = ( hits => [], misses => [], ordering => [] );

sub Fibonacci () {

    my %breakers;
    my @cache;

    receive[*Fibonacci] => +{
        *Calculate => sub ( $this, $number, $respondant ) {
            $log->info( $this, '*Calculate received for number('.$number.') for respondant('.$respondant->pid.')' ) if FIB_DEBUG;

            push @EVENTS => {
                id    => ++$EVENT_ID,
                enter => *Calculate,
                args  => [ $number, $respondant->pid ]
            };

            if ( defined $cache[$number] ) {
                $log->warn( $this, '*Calculate returning cached result for number('.$number.' = '.$cache[$number].') to respondant('.$respondant->pid.')' ) if FIB_DEBUG;
                $this->send( $respondant, [ *Result => $cache[$number] ] );
                $stats{hits}->[$number]++;
                $EVENTS[-1]->{hit}++;
            }
            else {
                $stats{misses}->[$number]++;
                $EVENTS[-1]->{miss}++;
                if ( $number < 2 ) {
                    $log->info( $this, '... *Calculate number('.$number.') is less than 2, responding to respondant('.$respondant->pid.') with {*Result, '.$number.'}' ) if FIB_DEBUG;
                    $this->send( $respondant, [ *Result => $number ] );
                    $cache[ $number ] = $number;
                }
                else {
                    my $adder = $this->spawn( Adder($this, $number, $respondant) );
                    $log->info( $this, '>>> *Calculate creating Adder('.$adder->pid.') and recursing ...' ) if FIB_DEBUG;

                    $EVENTS[-1]->{adder} = $adder->pid;

                    my $ticks = int(rand($number));

                    push @adder_ordering => [ calc => $number, $ticks ];

                    ticker( $this, $ticks, sub{
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
            $this->send( $from, [ *DumpStats => \%stats ]);
            $this->exit(0);
        }
    };
}

my $num   = $ARGV[0] // 10;
my $SCALE = $ENV{SCALE} // 2;

my @good_seeds = (
    869318942,
    903645731,
    1617973718,
    3089290199,
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


my sub scale_value_to_range ($val, $max, $min) {
    my ($old_max, $old_min) = (1000, 0);
    my $scaled    = $val * 1000;

    my $old_range = ($old_max - $old_min);
    my $new_range = ($max - $min);

    return int(((($scaled - $old_min) * $new_range) / $old_range) + $min);
}

sub Init () {

    setup sub ($this) {

        my $fib = $this->spawn( Fibonacci() );

        $fib->trap( *SIGEXIT );
        #$fib->link( $this );

        $this->send( $fib, [ *Calculate => $num, $this ] );

        # async control flow ;)
        $log->warn( $this, '... starting' );

        receive +{
            *Result => sub ($this, $result) {
                $log->info( $this, '*Result received for result('.$result.')' );
                $this->kill( $fib );
            },
            *DumpStats => sub ($this, $stats) {
                $log->info( $this, '*DumpStats received' );

                # TODO:
                # move this out of the actor, into a util
                # function or something, anywhere is better
                # than here.

                my $hits   = $stats{hits};
                my $misses = $stats{misses};
                my $order  = $stats{ordering};

                my $total_hits   = sum( map { $_//0 } $hits->@* );
                my $total_misses = sum( map { $_//0 } $misses->@* );

                say(('SEED  : '.$SEED));
                say(('SCALE : '.$SCALE));

=pod
                my @sequence = sort { $a <=> $b } $order->@*;
                my @out;
                foreach my $i ( 0 .. $order->$#* ) {
                    my $o = $order->[ $i ];
                    if ( $i == 0 ) {
                        push @out => [ $o, 1 ];
                    }
                    elsif ( @out && $out[-1]->[0] == $o ) {
                        $out[-1]->[1]++;
                    }
                    else {
                        push @out => [ $o, 1 ];
                    }
                }

                say join "\n" => map {
                    sprintf '%2d %d (%s)' => shift(@sequence), $_->[0], join '' => ('=' x $_->[1])
                } @out;
=cut

                my $hit_color  = 'blue';
                my $miss_color = 'red';

                my $term_width = $log->max_line_width - 15;

                say('           |'.join '|' => map { (join '' => ('-' x 9)) } (1 .. int($term_width / 10)));
                say('           |'.join '|' => map { (join '' => (sprintf '%9d' => ($_ * 10 * $SCALE))) } (1 .. int($term_width / 10)));
                say(colored(' hit ', 'black on_'.$hit_color)
                   .colored(' miss ', 'black on_'.$miss_color)
                             .'|'.join '|' => map { (join '' => ('-' x 9)) } (1 .. int($term_width / 10)));

                my sub scale ($x) {
                    my $size = int($x / $SCALE);
                       $size = 0 if $size < 1;
                       $size;
                }

                #say('HITS ['.$total_hits.']');
                foreach my $i ( 0 .. max( $hits->$#*, $misses->$#* ) ) {
                    my $hit  = $hits  ->[$i] // 0;
                    my $miss = $misses->[$i] // 0;

                    my $hit_size  = scale($hit);
                    my $miss_size = scale($miss);

                    my @out;
                    foreach my $x ( 0 .. max( $hit_size, $miss_size )) {
                        my $mark = '▄';
                        my ($fg_color, $bg_color);

                        if ($x <= $hit_size) {
                            $fg_color = 'black';
                            $bg_color = 'on_'.$hit_color;
                        }

                        if ($x <= $miss_size) {
                            $fg_color = $miss_color;
                            $bg_color //= 'on_black';
                        }

                        push @out => colored($mark, "$fg_color $bg_color");

                        last if $x == $term_width;
                    }
                    say((sprintf ' %4d %4d' => ($hit, $miss)).' |'.join '' => @out);

                }
=pod
                say join "\n" => map {
                    $_->[0] eq 'calc'
                        ? sprintf '%6s %d ticks(%d)' => @$_
                        : sprintf '%6s %d'           => @$_
                } @adder_ordering;


                my %tree;
                my %index;
                foreach my $event (@EVENTS) {
                    $index{$event->{id}} = $event;

                    if ( $event->{adder} ) {
                        $tree{$event->{adder}} = {
                            id       => $event->{id},
                            adder    => $event->{adder},
                            event    => $event,
                            children => []
                        };
                    }
                    #else {
                        my $node = $tree{ $event->{args}->[1] };
                        push $node->{children}->@* => {
                            id       => $event->{id},
                            caller   => $event->{args}->[1],
                            event    => $event,
                            children => []
                        };
                    #}

                    warn Dumper \%tree;

                }

                say Dumper( \@EVENTS );
                say Dumper( \%tree );
                say Dumper( $tree{ $EVENTS[0]->{adder} } );

=cut
                $this->exit(0);
            },
            *SIGEXIT => sub ($this, $from) {
                $log->warn( $this, '... got SIGEXIT from ('.$from->pid.')');
            }
        }
    }
}

ELO::Loop->run( Init(), logger => $log );

# Perl

sub fibonacci2 ($number) {
    if ($number < 2) { # base case
        return $number;
    }
    return fibonacci($number-1) + fibonacci($number-2);
}

sub fibonacci ($number) {
    state %calculated;

    if (exists $calculated{$number}) {
        #print '<SKIP>';
        return $calculated{$number} ;
    }

    if ($number < 2) { # base case
        return $calculated{$number} = $number;
    }
    #print "-";
    return $calculated{$number} = (fibonacci($number-1) + fibonacci($number-2));
}

my $start = time;
say(join ' = ', $_, fibonacci($_)) foreach ($num);
say("took: ".(scalar(time)- $start));

done_testing;

