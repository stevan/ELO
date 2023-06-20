package ELO::Graphics::Images;
use v5.36;

use ELO::Types qw[ :core :types :typeclasses ];

use ELO::Graphics::Colors;
use ELO::Graphics::Pixels;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = qw[
    Palette

    ImageData
    Image

    *Palette

    *ImageData
    *Image
];

## ----------------------------------------------------------------------------
## Image
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *BitRow => *ArrayRef, of => [ *Pixel  ];
type *BitMap => *ArrayRef, of => [ *BitRow ];

datatype [ Image => *Image ] => ( *BitMap );

typeclass[*Image] => sub {

    method bitmap => *BitMap;

    method height => sub ($i) { scalar $i->bitmap->@*      };
    method width  => sub ($i) { scalar $i->bitmap->[0]->@* };

    method get_all_rows => sub ($i)        { $i->bitmap->@* };
    method get_row      => sub ($i, $idx)  { $i->bitmap->[ $idx ]->@* };

    # NOTE:
    # the below methods will copy the
    # full bitmap as these are immutable
    # references

    method mirror => sub ($i) {
        Image([ map { [ reverse @$_ ] } $i->get_all_rows ])
    };

    method flip => sub ($i) {
        Image([ map { [ @$_ ] } reverse $i->get_all_rows ])
    };

    method map => sub ($i, $f) {
        Image([ map { [ map $f->($_), @$_ ] } $i->get_all_rows ])
    };

    method lighten => sub ($i, $lighten_by) {
        my $lightener = Color( $lighten_by, $lighten_by, $lighten_by );
        Image([
            map { [
                map $_->lighten( $lightener ), @$_
            ] } $i->get_all_rows
        ])
    };

    method darken => sub ($i, $darken_by) {
        my $darkener = Color( $darken_by, $darken_by, $darken_by );
        Image([
            map { [
                map $_->darken( $darkener ), @$_
            ] } $i->get_all_rows
        ])
    };
};

## ----------------------------------------------------------------------------
## Palette
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *ColorMap => *HashRef, of => [ *Pixel ];

datatype [ Palette => *Palette ] => ( *ColorMap );

typeclass[*Palette] => sub {

    method color_map => *ColorMap;
    method colors    => sub ($p) { values $p->color_map->%* };

    method map => sub ($p, @chars) {
        my $map = $p->color_map;
        my @out = map { $map->{ $_ } // die 'Could not find color for ('.$_.')' } @chars;
        return @out;
    };
};


## ----------------------------------------------------------------------------
## ImageData
## ----------------------------------------------------------------------------
##
## ----------------------------------------------------------------------------

type *RawImageData => *ArrayRef, of => [ *Str ]; # lines of image data stored as *Str

datatype [ ImageData => *ImageData ] => ( *Palette, *RawImageData );

typeclass[ *ImageData ] => sub {

    method palette  => *Palette;
    method raw_data => *RawImageData;

    method get_all_rows => sub ($i)        { $i->raw_data->@* };
    method get_row      => sub ($i, $idx)  { $i->raw_data->[ $idx ]->@* };

    method create_image => sub ($img) {
        my $p = $img->palette;
        Image([ map [ $p->map( split //, $_ ) ], $img->get_all_rows ])
    };
};


1;

__END__

