package ELO::Util::TermDisplay;
use v5.36;
use warnings;
use experimental 'signatures', 'postderef';

use POSIX;
use Term::Cap;
use Term::ReadKey qw[ GetTerminalSize ReadKey ReadMode ];

$|++;

use parent 'UNIVERSAL::Object';
use slots (
    # private
    _term_cap  => sub {},
    _term_size => sub {},
);

sub BUILD ($self, $) {

    # init the term
    my $termios = POSIX::Termios->new;
    $termios->getattr;
    my $ospeed = $termios->getospeed;
    my $tc = Term::Cap->Tgetent({ TERM => undef, OSPEED => $ospeed });

    # require the following capabilities
    $tc->Trequire(qw/cl cd ce cm co li/);

    $self->{_term_cap}  = $tc;
    $self->{_term_size} = [ GetTerminalSize() ];
}

sub term_width  ($self) { $self->{_term_size}->[0] }
sub term_height ($self) { $self->{_term_size}->[1] }

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

1;
