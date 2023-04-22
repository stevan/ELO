package ELO::Promises;
use v5.36;

use ELO::Core::Promise;

use Exporter 'import';

our @EXPORT_OK = qw[
    promise
    collect
];

sub promise () { ELO::Core::Promise->new }

sub collect (@promises) {
    my $collector = ELO::Core::Promise->new->resolve([]);

    foreach my $p ( @promises ) {
        my @results;
        $collector = $collector
            ->then(sub ($result) {
                #warn "hello from 1 for $p";
                #warn Dumper { p => "$p", state => 1, collector => [ @results ], result => $result };
                push @results => @$result;
                #warn Dumper { p => "$p", state => 1.5, collector => [ @results ] };
                $p;
            })
            ->then(sub ($result) {
                #warn "hello from 2 for $p";
                #warn Dumper { p => "$p", state => 2, collector => [ @results ], result => $result };
                my $r = [ @results, $result ];
                #warn Dumper { p => "$p", state => 2.5, collector => $r };
                return $r;
            })
    }

    return $collector;
}

1;

__END__

=pod

=cut
