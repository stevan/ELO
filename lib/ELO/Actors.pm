package ELO::Actors;
# ABSTRACT: Event Loop Orchestra
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Data::Dumper 'Dumper';
use Sub::Util 'set_subname';

use ELO::VM ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Exporter 'import';

our @EXPORT = qw[
    match
    actor
];

sub get_actor ($name) {
    $ELO::VM::ACTORS{$name};
}

sub actor ($name, $recieve) {
    $ELO::VM::ACTORS{$name} = set_subname( $name, $recieve );
}

sub match ($msg, $table) {
    #warn Dumper [$msg, $table];
    my $cb = $table->{$msg->action} // die "No match for ".$msg->action;
    eval {
        $cb->($msg->body->@*);
        1;
    } or do {
        warn "Died calling msg(".(join ', ' => map { ref $_ ? '['.(join ', ' => @$_).']' : $_ } @$msg).")";
        die $@;
    };
}


1;

__END__

=pod

=cut
