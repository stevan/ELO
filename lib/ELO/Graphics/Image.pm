package ELO::Graphics::Image;
use v5.36;

use ELO::Types  qw[ :core :types :typeclasses ];
use ELO::Actors qw[ match ];

# we only need this one ...
use ELO::Graphics::Color qw[ *Palette ];

use Exporter 'import';

my @TYPES = (
    *Image,
    *ImageData
);

my @CONSTRUCTORS = qw(
    Image
    ImageData
);

my @TYPE_GLOBS = map { '*'.((split /\:\:/ => "$_")[-1]) } @TYPES;

sub get_type_name ( $type ) {
    (split /\:\:/ => "$type")[-1]
}

our @EXPORT_OK = (
    @CONSTRUCTORS,
    @TYPE_GLOBS
);

our %EXPORT_TAGS = (
    all          => [ @CONSTRUCTORS, @TYPE_GLOBS ],
    constructors => [ @CONSTRUCTORS              ],
    types        => [                @TYPE_GLOBS ],
);

# ...

datatype *Image => sub {
    case Image => ( *ArrayRef ); # [ *Color, ... ]
};

typeclass[*Image] => sub {

    method height => { Image => sub ($data) { $data->$#*      } };
    method width  => { Image => sub ($data) { $data->[0]->$#* } };

    method get_all_rows => { Image => sub ($data) { $data->@* } };

    method mirror => { Image => sub ($data) {
        Image([ map { [ reverse @$_ ] } $data->@* ])
    }};

    method flip => { Image => sub ($data) {
        # copy everything except for the pixels
        # we do not own the rows ... :)
        Image([ map { [ @$_ ] } reverse $data->@* ])
    }};
};

# ...

type *Rows => *ArrayRef; # [ *Str, ... ]

datatype *ImageData => sub {
    case ImageData => ( *Palette, *Rows );
};

typeclass[*ImageData] => sub {

    method create_image => {
        ImageData => sub ($p, $rows) {
            Image([ map [ $p->map( split //, $_ ) ], @$rows ])
        }
    };
};

1;

__END__

=pod

=cut
