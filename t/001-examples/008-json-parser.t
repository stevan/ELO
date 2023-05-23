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

type *Location => [ *Str, *Int, *Int ];

datatype *JSONToken => sub {
    case NotAvailable  => ();
    case NoToken       => ();

    case StartObject   => ( *Location );
    case EndObject     => ( *Location );

    case StartProperty => ( *Location, *Str ); # key
    case EndProperty   => ( *Location );

    case StartArray    => ( *Location );
    case EndArray      => ( *Location );

    case StartItem     => ( *Location, *Int ); # index
    case EndItem       => ( *Location );

    case AddString     => ( *Location, *Str );
    case AddInt        => ( *Location, *Int );
    case AddFloat      => ( *Location, *Float );
    case AddTrue       => ( *Location );
    case AddFalse      => ( *Location );
    case AddNull       => ( *Location );
    case Error         => ( *Location, *Str ); # error
};


use constant START_OBJECT   => 'START_OBJECT';
use constant START_PROPERTY => 'START_PROPERTY';
use constant START_ARRAY    => 'START_ARRAY';
use constant START_ITEM     => 'START_ITEM';

typeclass[*JSONToken] => sub {

    my sub drain_until_marker ($acc, $marker) {
        my @local;
        while (@$acc) {
            if ( $acc->[-1] eq $marker ) {
                pop @$acc;
                last;
            }
            else {
                push @local => pop @$acc;
            }
        }
        reverse @local;
    }

    method consume_token => sub ($t, $acc=[]) {
        #warn Dumper ref($t), $acc;

        match[ *JSONToken => $t ], +{
            NotAvailable  => sub () { },
            NoToken       => sub () { },

            StartObject   => sub ( $l ) { push @$acc => START_OBJECT },
            EndObject     => sub ( $l ) {
                my @local = drain_until_marker( $acc, START_OBJECT );
                my $o = Object( [ @local ] );
                push @$acc => $o;
            },

            StartProperty => sub ( $l, $key ) { push @$acc => (START_PROPERTY, $key) },
            EndProperty   => sub ( $l )       {
                my ($key, $value) = drain_until_marker( $acc, START_PROPERTY );
                push @$acc => Property( $key, $value );
            },

            StartArray    => sub ( $l ) { push @$acc => START_ARRAY },
            EndArray      => sub ( $l ) {
                my @local = drain_until_marker( $acc, START_ARRAY );
                my $a = Array([ @local ]);
                push @$acc => $a;
            },

            StartItem     => sub ( $l, $index ) { push @$acc => (START_ITEM, $index) },
            EndItem       => sub ( $l )         {
                my ($index, $item) = drain_until_marker( $acc, START_ITEM );
                push @$acc => Item( $index, $item );
            },

            AddString     => sub ( $l, $Str )   { push @$acc => String($Str)  },
            AddInt        => sub ( $l, $Int )   { push @$acc => Int($Int)     },
            AddFloat      => sub ( $l, $Float ) { push @$acc => Float($Float) },

            AddTrue       => sub ( $l ) { },
            AddFalse      => sub ( $l ) { },
            AddNull       => sub ( $l ) { },

            Error         => sub ( $l ) { },
        };
    };

};


subtest '... testing the JSON type' => sub {

    my $l = ['eval',0,0];

    my @tokens = (
        StartObject( $l ),
            StartProperty( $l, "Foo" ),
                AddString( $l, "Bar" ),
            EndProperty( $l ),
            StartProperty( $l, "Baz" ),
                StartArray( $l ),
                    StartItem( $l, 0 ),
                        AddInt($l, 10),
                    EndItem( $l ),
                    StartItem( $l, 1 ),
                        AddFloat($l, 2.5),
                    EndItem( $l ),
                    StartItem( $l, 2 ),
                        StartArray( $l ),
                            StartItem( $l, 0 ),
                                AddInt($l, 1 ),
                            EndItem( $l ),
                            StartItem( $l, 1 ),
                                AddInt($l, 2 ),
                            EndItem( $l ),
                        EndArray( $l ),
                    EndItem( $l ),
                EndArray( $l ),
            EndProperty( $l ),
        EndObject( $l )
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

