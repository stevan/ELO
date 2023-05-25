package ELO::JSON::Token::Source;
use v5.36;

use Data::Dumper;

use ELO::Actors qw[ match ];
use ELO::Types  qw[
    :core
    :types
    :typeclasses
];

datatype *Source => sub {
    case FromList      => ( *ArrayRef );
    case FromGenerator => ( *CodeRef );
};

typeclass[*Source] => sub {
    method 'get_next' => {
        FromList      => sub ($list) { shift $list->@* },
        FromGenerator => sub ($gen)  { $gen->()        },
    };
};

1;
