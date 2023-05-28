package ELO::Core::Behavior::Ignore;
use v5.36;

sub new ($, %) { bless +{} => __PACKAGE__ }
sub name ($) { __PACKAGE__ };
sub apply ($, $, $) {}

1;

__END__

=pod

=cut
