#!perl

use v5.36;

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Actors', qw[ match ];
use ok 'ELO::Types',  qw[
    :core
    :types
    :typeclasses
];

datatype *JSON => sub {
    case Object   => ( *ArrayRef   ); # *Property
    case Property => ( *Str, *JSON );

    case Array    => ( *ArrayRef   ); # *Item
    case Item     => ( *Int, *JSON ); # index, JSON

    case String   => ( *Str        );
    case Int      => ( *Int        );
    case Float    => ( *Float      );
    case True     => ();
    case False    => ();
    case Null     => ();
};

typeclass[*JSON] => sub {

    method decode => {
        Object   => sub ( $ArrayRef   ) { +{ map $_->decode, @$ArrayRef } },
        Property => sub ( $Str, $JSON ) { $Str, $JSON->decode },

        Array    => sub ( $ArrayRef   ) { [ map $_->decode, @$ArrayRef ] },
        Item     => sub ( $Int, $JSON ) { $JSON->decode },

        String   => sub ( $Str        ) { $Str   },
        Int      => sub ( $Int        ) { $Int   },
        Float    => sub ( $Float      ) { $Float },
        True     => sub ()              { !!1    },
        False    => sub ()              { !!0    },
        Null     => sub ()              { undef  },
    };

    method encode => {
        Object   => sub ( $ArrayRef   ) { '{'.(join ', ' => map $_->encode, @$ArrayRef).'}' },
        Property => sub ( $Str, $JSON ) { '"'.$Str.'" : '.$JSON->encode },

        Array    => sub ( $ArrayRef   ) { '['.(join ', ' => map $_->encode, @$ArrayRef).']' },
        Item     => sub ( $Int, $JSON ) { $JSON->encode },

        String   => sub ( $Str        ) { '"'.$Str.'"' },
        Int      => sub ( $Int        ) { "$Int"       },
        Float    => sub ( $Float      ) { "$Float"     },
        True     => sub ()              { 'true'       },
        False    => sub ()              { 'false'      },
        Null     => sub ()              { 'null'       },
    };
};


subtest '... testing the JSON type' => sub {

    my $json = Object([
        Property('Foo', String("Bar")),
        Property('Baz', Array([
            Item(0, Int(10)),
            Item(1, Float(2.5)),
            Item(2, Array([ Int(1), Int(2) ])),
        ])),
    ]);

    is_deeply(
        $json->decode,
        { Foo => "Bar", Baz => [ 10, 2.5, [ 1, 2 ]]},
        '... decode works'
    );

    is(
        $json->encode,
        '{"Foo" : "Bar", "Baz" : [10, 2.5, [1, 2]]}',
        '... encode works'
    );

};

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

    method consume_token => sub ($t, $acc=[]) {
        state $OBJECT_MARKER   = \1;
        state $PROPERTY_MARKER = \2;
        state $ARRAY_MARKER    = \3;
        state $ITEM_MARKER     = \4;

        #warn Dumper ref($t), $acc;

        match[ *JSONToken => $t ], +{
            StartObject   => sub () { push @$acc => $OBJECT_MARKER },
            EndObject     => sub () {
                my @local = drain_until_marker( $acc, $OBJECT_MARKER );
                my $o = Object( [ @local ] );
                push @$acc => $o;
            },

            StartProperty => sub ( $key ) { push @$acc => ($PROPERTY_MARKER, $key) },
            EndProperty   => sub ()       {
                my ($key, $value) = drain_until_marker( $acc, $PROPERTY_MARKER );
                push @$acc => Property( $key, $value );
            },

            StartArray    => sub () { push @$acc => $ARRAY_MARKER },
            EndArray      => sub () {
                my @local = drain_until_marker( $acc, $ARRAY_MARKER );
                my $a = Array([ @local ]);
                push @$acc => $a;
            },

            StartItem     => sub ( $index ) { push @$acc => ($ITEM_MARKER, $index) },
            EndItem       => sub ()         {
                my ($index, $item) = drain_until_marker( $acc, $ITEM_MARKER );
                push @$acc => Item( $index, $item );
            },

            AddString     => sub ( $Str )   { push @$acc => String($Str)  },
            AddInt        => sub ( $Int )   { push @$acc => Int($Int)     },
            AddFloat      => sub ( $Float ) { push @$acc => Float($Float) },

            AddTrue       => sub () { push @$acc => True()  },
            AddFalse      => sub () { push @$acc => False() },
            AddNull       => sub () { push @$acc => Null()  },

            Error         => sub ( $error ) { },
        };
    };

};


subtest '... testing the JSON type' => sub {

    my @tokens = (
        StartObject(),
            StartProperty( "Foo" ),
                AddString( "Bar" ),
            EndProperty(),
            StartProperty( "Baz" ),
                StartArray(),
                    StartItem( 0 ),
                        AddInt( 10 ),
                    EndItem(),
                    StartItem( 1 ),
                        AddFloat( 2.5 ),
                    EndItem(),
                    StartItem( 2 ),
                        StartArray(),
                            StartItem( 0 ),
                                AddInt( 1 ),
                            EndItem(),
                            StartItem( 1 ),
                                AddInt( 2 ),
                            EndItem(),
                        EndArray(),
                    EndItem(),
                EndArray(),
            EndProperty(),
        EndObject()
    );

    my $acc = [];
    $_->consume_token($acc) foreach @tokens;

    #warn Dumper $acc;

    my ($json) = @$acc;

    is_deeply(
        $json->decode,
        { Foo => "Bar", Baz => [ 10, 2.5, [ 1, 2 ]]},
        '... decode works'
    );

    is(
        $json->encode,
        '{"Foo" : "Bar", "Baz" : [10, 2.5, [1, 2]]}',
        '... encode works'
    );
};


done_testing;

1;

__END__

