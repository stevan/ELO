#!perl

use v5.36;
no warnings 'once';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Types',  qw[
    :core
    :events
    :types
];

my %REG;

sub case ($, @) { die 'Not Allowed'; }

sub datatype ($symbol, $cases) {
    warn "HERE!";

    my %cases;
    local *case = sub ($constructor, @definitions) {

        my $constructor_tag = "${symbol}::${constructor}";
           $constructor_tag =~ s/main//;

        no strict 'refs';
        *{"$constructor"} = scalar @definitions == 0
            ? sub ()      { bless [] => $constructor_tag }
            : sub (@args) {
                # TODO - check args against definition
                bless [ @args ] => $constructor_tag;
            };

        $cases{$constructor_tag} = bless {
            constructor => \&{"$constructor"},
            definitions => [ @definitions ]
        } => 'ELO::Core::Type::TaggedUnion::Constuctor';
    };

    $cases->();

    $REG{ $symbol } = bless {
        symbol => $symbol,
        cases  => \%cases,
    } => 'ELO::Core::Type::TaggedUnion';
}

datatype *Tree => sub {
    case Node => ( *Int, *Tree, *Tree );
    case Leaf => ();
};

subtest '... check an event instance' => sub {

    my $tree = Node( 1, Leaf(), Leaf() );

    # match looks at the arg and
    # based on the type of the first
    # value, it will do the right
    # thing for that type's "type"
=pod

    match [ *Tree => $tree ] => {
        Node => sub ($val, $tree, $tree) {},
        Leaf => sub () {},
    };

    match [ *Option => $val ] => {
        Some => sub ($val) {},
        None => sub () {},
    };

    # promises ...

    match [ *Promise => $promise ] => {
        *eResolve => sub () {}
        *eReject  => sub () {}
    };

    # the old events works fine ...

    my $msg = [ *eVent, ... ];

    match $msg => {
        *eVent => sub { ... },
    };

    # strings could work fine too ...
=cut

   #warn Dumper $tree;

   #warn Dumper $REG{ *Tree };

=pod

check datatype
    - is value blessed
        - is it blessed into one of the varients?

construct datatype varient
    - check values against definition

=cut

    ok(1);

};


done_testing;

1;

__END__

