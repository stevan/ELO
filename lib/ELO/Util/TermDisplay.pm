package ELO::Util::TermDisplay;
use v5.36;

use POSIX;
use Term::Cap;
use Term::ReadKey   qw[ GetTerminalSize ReadKey ReadMode ];
use Term::ANSIColor qw[ colored uncolor ];

$|++;

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    # private
    _fh        => sub { \*STDOUT },
    _windows   => sub { +[] },
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
    $tc->Trequire(qw/cl cd ce cm ho DO do IC co li/);

    $self->{_term_cap}  = $tc;
    $self->{_term_size} = [ GetTerminalSize() ];
}

sub term_width  ($self) { $self->{_term_size}->[0] }
sub term_height ($self) { $self->{_term_size}->[1] }

# clearing the screen

sub clear_screen ($self, %args) {
    $self->{_term_cap}->Tputs('cl', 1, *STDOUT);

    if ( $args{with_markers} ) {
        foreach my $x ( 1 .. $self->term_height-1 ) {
            $self->go_to( $x, 0 )->put_string( colored((join '' => map {
                ($_ % 5) == 0 ? '+' : '-'
            } (0 .. $self->term_width-1)), 'grey5') );
            $self->go_to( $x, 0 )->put_string( colored((sprintf '%02d', $x), 'dark cyan') );
        }
    }

    $self;
}

sub clear_line ($self) {
    $self->{_term_cap}->Tputs('ce', 1, *STDOUT);
    $self;
}

sub clear_to_end_of_screen ($self) {
    $self->{_term_cap}->Tputs('cd', 1, *STDOUT);
    $self;
}

# move the cursor

sub go_to ($self, $line, $col) {
    $self->{_term_cap}->Tgoto('cm', $col, $line, *STDOUT);
    $self;
}

# output

sub put_string ($self, $string) {
    *STDOUT->print( $string );
    $self;
}

sub print_line ($self, @line) {
    $self->clear_line;
    $self->put_string( join '' => @line );
    $self;
}

sub print_line_at ($self, $line_num, @line) {
    $self->go_to( $line_num, 0 );
    $self->put_string( join '' => @line );
    $self;
}

# windows

package ELO::Util::TermDisplay::Window::Colored {
    use v5.36;

    use Term::ANSIColor qw[ colored uncolor ];

    use parent 'UNIVERSAL::Object::Immutable';
    use slots (
        top    => sub {},
        left   => sub {},

        height => sub {},
        width  => sub {},

        bg_color => sub {},
        fg_color => sub {},

        device => sub {},
    );

    sub BUILD ($self, $) {
        my $h = $self->{height};
        my $w = $self->{width};

        my @background = map { join '' => (' ' x $w) } 0 .. $h;

        my $line = 0;
        foreach (@background) {
            $self->put_at( colored( $_, 'on_'.$self->{bg_color} ),  ++$line, 0 );
        }
    }

    sub hide_cursor ($self) { $self->{device}->go_to( 0, 1000 ) }

    sub put_at ($self, $string, $line=0, $col=0) {
        # TODO: check that length is not longer than window-width
        $line += $self->{top};
        $col  += $self->{left};
        # TODO: check out of bounds ...
        $self->{device}->go_to( $line, $col );
        $self->{device}->put_string( colored( $string, $self->{fg_color} .'on_'.$self->{bg_color} ) );
        $self;
    }
}

sub create_colored_window ($self, $top, $left, $height, $width, $bg_color, $fg_color) {
    ELO::Util::TermDisplay::Window->new(
        device   => $self,
        top      => $top,
        left     => $left,
        height   => $height,
        width    => $width,
        bg_color => $bg_color,
        fg_color => $fg_color,
    )
}

package ELO::Util::TermDisplay::Window {
    use v5.36;

    use Term::ANSIColor qw[ colored uncolor ];

    use parent 'UNIVERSAL::Object::Immutable';
    use slots (
        top    => sub {},
        left   => sub {},

        height => sub {},
        width  => sub {},

        device => sub {},
    );

    sub top    ($self) { $self->{top}  }
    sub left   ($self) { $self->{left} }

    sub height ($self) { $self->{height} }
    sub width  ($self) { $self->{width}  }

    sub draw_window ($self) {
        my $h = $self->{height};
        my $w = $self->{width};

        my $corner = '+';
        my $edge   = '|';

        my $top  = join '' => ('-' x ($w+1));
        my $side = join '' => (' ' x ($w+1));

        $self->put_at( "${corner}${top}${corner}", -1, -1 );
        foreach my $x ( 0 .. $h ) {
            $self->put_at( "${edge}${side}${edge}", $x, -1);
        }
        $self->put_at( "${corner}${top}${corner}", $h+1, -1 );
    }

    sub hide_cursor ($self) { $self->{device}->go_to( 0, 1000 ) }

    sub put_at ($self, $string, $line=0, $col=0) {
        # TODO: check that length is not longer than window-width
        $line += $self->{top};
        $col  += $self->{left};
        # TODO: check out of bounds ...
        $self->{device}->go_to( $line, $col );
        $self->{device}->put_string( $string );
        $self;
    }
}


sub create_window ($self, $top, $left, $height, $width) { #, $bg_color, $fg_color) {
    ELO::Util::TermDisplay::Window->new(
        device   => $self,
        top      => $top,
        left     => $left,
        height   => $height,
        width    => $width,
        #bg_color => $bg_color,
        #fg_color => $fg_color,
    )
}

1;
