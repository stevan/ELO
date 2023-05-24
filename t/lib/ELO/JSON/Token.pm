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

    case Error         => ( *Str ); # error
};

typeclass[*JSONToken] => sub {
    # TODO ...
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

    #warn Dumper ref($t), $acc;
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

            Error         => sub ( $error ) { },
        };
    } catch ($e) {
        die 'JSON token processing failed: '.$e;
    };
}

1;
