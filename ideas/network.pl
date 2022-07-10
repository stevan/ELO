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

sub draw_box_at ($self, $line, $col, $label) {
    state $horz_char   ='-';
    state $vert_char   ='|';
    state $corner_char ='+';

    my $width  = (length $label) + 4;
    my $height = 3;

    my $horz = $corner_char . ($horz_char x ($width - 2)) . $corner_char;
    my $vert = $vert_char   . ' ' . $label . ' ' . $vert_char;

    $self->go_to( $line, $col )->put_string( $horz );
    $self->go_to( $line + $_ + 1, $col )->put_string( $vert )
        foreach 0 .. ($height - 2);
    $self->go_to( $line + ($height - 1), $col )->put_string( $horz );
}

package main;

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Term::ANSIColor qw[ :constants color colored ];
use Time::HiRes 'sleep';

$|++;

my $ui = ELO::UI::Terminal->new;

$ui->draw_box_at( 5, 5, "Hello World" );

$ui->draw_box_at( 5, 45, "WASSUP!" );



1;






