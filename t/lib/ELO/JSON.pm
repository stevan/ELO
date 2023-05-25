package ELO::JSON;
use v5.36;

use Data::Dumper;

use ELO::Actors qw[ match ];
use ELO::Types  qw[
    :core
    :types
    :typeclasses
];

type *PropertyKey => *Str;
type *ArrayIndex  => *Int;

datatype *JSON => sub {
    case Object   => ( *ArrayRef           ); # *Property
    case Property => ( *PropertyKey, *JSON );

    case Array    => ( *ArrayRef          ); # *Item
    case Item     => ( *ArrayIndex, *JSON ); # index, JSON

    case String   => ( *Str   );
    case Int      => ( *Int   );
    case Float    => ( *Float );
    case True     => ();
    case False    => ();
    case Null     => ();
};

typeclass[*JSON] => sub {

    method to_perl => {
        Object   => sub ( $ArrayRef   ) { +{ map $_->to_perl, @$ArrayRef } },
        Property => sub ( $Str, $JSON ) { $Str, $JSON->to_perl },

        Array    => sub ( $ArrayRef   ) { [ map $_->to_perl, @$ArrayRef ] },
        Item     => sub ( $Int, $JSON ) { $JSON->to_perl },

        String   => sub ( $Str        ) { $Str   },
        Int      => sub ( $Int        ) { $Int   },
        Float    => sub ( $Float      ) { $Float },
        True     => sub ()              { 1      },
        False    => sub ()              { 0      },
        Null     => sub ()              { undef  },
    };

    method to_string => {
        Object   => sub ( $ArrayRef   ) { '{'.(join ', ' => map $_->to_string, @$ArrayRef).'}' },
        Property => sub ( $Str, $JSON ) { '"'.$Str.'" : '.$JSON->to_string },

        Array    => sub ( $ArrayRef   ) { '['.(join ', ' => map $_->to_string, @$ArrayRef).']' },
        Item     => sub ( $Int, $JSON ) { $JSON->to_string },

        String   => sub ( $Str        ) { '"'.$Str.'"' },
        Int      => sub ( $Int        ) { "$Int"       },
        Float    => sub ( $Float      ) { "$Float"     },
        True     => sub ()              { 'true'       },
        False    => sub ()              { 'false'      },
        Null     => sub ()              { 'null'       },
    };
};

1;
