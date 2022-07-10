#!/usr/bin/perl

package ELO::UI::Terminal;
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use POSIX;
use Term::Cap;
use Term::ReadKey 'GetTerminalSize';

$|++;

use parent 'UNIVERSAL::Object';
use slots (
    # private
    _term_cap   => sub {},
    _term_width => sub {},
);

sub BUILD ($self, $) {

    # init the term
    my $termios = POSIX::Termios->new;
    $termios->getattr;
    my $ospeed = $termios->getospeed;
    my $tc = Tgetent Term::Cap { TERM => undef, OSPEED => $ospeed };

    # require the following capabilities
    $tc->Trequire(qw/cl cd ce cm co li/);

    $self->{_term_cap} = $tc;
    $self->{_term_width} = (GetTerminalSize())[0];
}

sub term_width ($self) { $self->{_term_width} }

sub clear_screen ($self) {
    $self->{_term_cap}->Tputs('cl', 1, *STDOUT);
    $self;
}

sub clear_line ($self) {
    $self->{_term_cap}->Tputs('ce', 1, *STDOUT);
    $self;
}

sub clear_to_end ($self) {
    $self->{_term_cap}->Tputs('cd', 1, *STDOUT);
    $self;
}


# move the cursor
sub go_to ($self, $line, $col) {
    $self->{_term_cap}->Tgoto('cm', $col, $line, *STDOUT);
    $self;
}

sub put_string ($self, @string) {
    print @string;
    $self;
}

sub print_line ($self, @line) {
    $self->clear_line;
    print @line;
    $self;
}

sub print_line_at ($self, $line_num, @line) {
    $self->go_to( $line_num, 0 );
    $self->put_string( @line );
    $self;
}

package main;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Term::ANSIColor qw[ :constants color colored ];
use Time::HiRes 'sleep';

$|++;

my $ui = ELO::UI::Terminal->new;

my $faint_line  = FAINT('-' x $ui->term_width).RESET;
my $max_value   = 35;
my $max_numbers = $ui->term_width - 6;
my @numbers     = map { int(rand($max_value)) } 0 .. $max_numbers;

$ui->clear_screen;
$ui->print_line_at(0, 'init(-1)');
$ui->print_line_at(1, $faint_line);
$ui->print_line_at($_ + 2, sprintf("%2d : " => $max_value - $_))
    foreach 0 .. $max_value;
$ui->print_line_at($max_value + 3, $faint_line);
$ui->go_to( $max_value + 4, 3 )->put_string( ':' );

sleep(1);

my $start = 52;
my @graph_colors = map
    sprintf("ansi%d" => $start++),
0 .. $max_value;

my $tick = 0;
while (1) {
    $tick++;

    $ui->go_to(0, 0)
       ->print_line("tick($tick) ", ('>' x $tick) );

    map {
        my $line = $_;
        $ui->go_to( (($max_value - $_) + 2), 5 )
           ->put_string(
                colored(
                    (join '' => map {
                        $_ <= $line
                            ? ' '
                            : $line < 10 ? '*' :
                              $line < 20 ? '|' :
                              $line < 30 ? ':' :
                                           '.'
                        } @numbers),
                    $graph_colors[ $_ ]
                )
            );
    } 0 .. $max_value;

    $ui->go_to( $max_value + 4, 5 )->put_string( join '' => map /^(\d)/, @numbers );

    shift @numbers if @numbers > $max_numbers;

    push @numbers => int(rand($max_value));

    sleep(0.5);
}







