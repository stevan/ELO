package ELO::JSON::Token;
use v5.36;
use experimental 'try';

use Data::Dumper;

use ELO::JSON;

use ELO::Actors qw[ match ];
use ELO::Types  qw[
    :core
    :types
    :typeclasses
];

datatype *JSONToken => sub {
    case StartObject   => ();
    case EndObject     => ();

    case StartProperty => ( *Str ); # key
    case EndProperty   => ();

    case StartArray    => ();
    case EndArray      => ();

    case StartItem     => ( *Int ); # index
    case EndItem       => ();

    case AddString     => ( *Str );
    case AddInt        => ( *Int );
    case AddFloat      => ( *Float );
    case AddTrue       => ();
    case AddFalse      => ();
    case AddNull       => ();
};

typeclass[*JSONToken] => sub {

    # can this token be the end of a sequence
    method is_terminal => {
        StartObject   => sub ( ) { 0 },
        EndObject     => sub ( ) { 1 },

        StartProperty => sub ($) { 0 },
        EndProperty   => sub ( ) { 1 },

        StartArray    => sub ( ) { 0 },
        EndArray      => sub ( ) { 1 },

        StartItem     => sub ($) { 0 },
        EndItem       => sub ( ) { 1 },

        AddString     => sub ($) { 1 },
        AddInt        => sub ($) { 1 },
        AddFloat      => sub ($) { 1 },
        AddTrue       => sub ( ) { 1 },
        AddFalse      => sub ( ) { 1 },
        AddNull       => sub ( ) { 1 },
    };

    # can this token be the start of sequence
    method is_start => {
        StartObject   => sub ( ) { 1 },
        EndObject     => sub ( ) { 0 },

        StartProperty => sub ($) { 1 },
        EndProperty   => sub ( ) { 0 },

        StartArray    => sub ( ) { 1 },
        EndArray      => sub ( ) { 0 },

        StartItem     => sub ($) { 1 },
        EndItem       => sub ( ) { 0 },

        AddString     => sub ($) { 1 },
        AddInt        => sub ($) { 1 },
        AddFloat      => sub ($) { 1 },
        AddTrue       => sub ( ) { 1 },
        AddFalse      => sub ( ) { 1 },
        AddNull       => sub ( ) { 1 },
    };

};

# ...

my sub drain_until_marker ($acc, $marker) {
    my @local;
    while (@$acc) {
        if ( $acc->[-1] eq $marker ) {
            pop @$acc;
            last;
        }
        else {
            unshift @local => pop @$acc;
        }
    }
    @local;
}


sub process_tokens ($tokens) {
    state $json_type = lookup_type( *ELO::JSON::JSON );

    # TODO:
    # - verify that the start token is is_start
    # - verify that the last token is is_terminal

    my $acc = [];
    foreach my $token (@$tokens) {
        process_token( $token, $acc );
    }

    if ( scalar @$acc == 1 && $json_type->check( $acc->[0] ) ) {
        #warn "WOOT!" . Dumper $acc->[0];
        return $acc->[0];
    }
    else {
        die 'More tokens needed! '.Dumper($acc);
    }
    return $acc;
}

sub process_token ($token, $acc=[]) {
    state $OBJECT_MARKER   = \1;
    state $PROPERTY_MARKER = \2;
    state $ARRAY_MARKER    = \3;
    state $ITEM_MARKER     = \4;

    try {
        match[ *JSONToken => $token ], +{
            StartObject   => sub () { push @$acc => $OBJECT_MARKER },
            EndObject     => sub () {
                my @local = drain_until_marker( $acc, $OBJECT_MARKER );
                my $o = ELO::JSON::Object( [ @local ] );
                push @$acc => $o;
            },

            StartProperty => sub ( $key ) { push @$acc => ($PROPERTY_MARKER, $key) },
            EndProperty   => sub ()       {
                my ($key, $value) = drain_until_marker( $acc, $PROPERTY_MARKER );
                push @$acc => ELO::JSON::Property( $key, $value );
            },

            StartArray    => sub () { push @$acc => $ARRAY_MARKER },
            EndArray      => sub () {
                my @local = drain_until_marker( $acc, $ARRAY_MARKER );
                my $a = ELO::JSON::Array([ @local ]);
                push @$acc => $a;
            },

            StartItem     => sub ( $index ) { push @$acc => ($ITEM_MARKER, $index) },
            EndItem       => sub ()         {
                my ($index, $item) = drain_until_marker( $acc, $ITEM_MARKER );
                push @$acc => ELO::JSON::Item( $index, $item );
            },

            AddString     => sub ( $Str )   { push @$acc => ELO::JSON::String($Str)  },
            AddInt        => sub ( $Int )   { push @$acc => ELO::JSON::Int($Int)     },
            AddFloat      => sub ( $Float ) { push @$acc => ELO::JSON::Float($Float) },

            AddTrue       => sub () { push @$acc => ELO::JSON::True()  },
            AddFalse      => sub () { push @$acc => ELO::JSON::False() },
            AddNull       => sub () { push @$acc => ELO::JSON::Null()  },
        };
    } catch ($e) {
        die 'JSON token processing failed: '.$e;
    };
}

1;
