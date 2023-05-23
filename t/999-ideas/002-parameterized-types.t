#!perl

use v5.36;

use Test::More;
use Test::Differences;

use Data::Dumper;

use ok 'ELO::Types', qw[ :core :types ];

=pod

type *a => sub ($type) { !! lookup_type($type) };
type *b => sub ($type) { !! lookup_type($type) };

datatype { *Option => *a } => sub {
    case None => ();
    case Some => ( *a );
};

typeclass{ *Option => *a } => sub {

    method get => {
        Some => sub ($value) { $value },
        None => sub ()       { due 'Cannot call get on None' },
    };

    method get_or_else => sub ($o, $f) {
        match[ { *Option => *a }, $o ] => {
            Some => sub ($value) { $value },
            None => sub ()       { $f->() },
        }
    };

    method or_else => sub ($o, $f) {
        match[ { *Option => *a }, $o ] => {
            Some => sub ($value) { Some($value) },
            None => sub ()       { $f->() },
        }
    };

    method is_defined => {
        Some => sub ($) { 1 },
        None => sub ()  { 0 },
    };

    method is_empty => {
        Some => sub ($) { 0 },
        None => sub ()  { 1 },
    };

    method map => sub ($o, $f) {
        match[ { *Option => *a }, $o ] => {
            Some => sub ($value) { Some( $f->($value) ) },
            None => sub ()       { None() },
        }
    };

    method filter => sub ($o, $f) {
        match[ { *Option => *a }, $o ] => {
            Some => sub ($value) { Some( $f->($value) ) },
            None => sub ()       { None() },
        }
    };

    method foreach => sub ($o, $f) {
        match[ { *Option => *a }, $o ] => {
            Some => sub ($value) { $f->( $value ) },
            None => sub ()       {},
        }
    };

};

sub get ($req, $key) {
    exists $req->{ $key } ? Some[*Str]->( $req->{ $key } ) : None;
}

my $req = { name => 'Stevan' };

my $upper = request_param($req, 'name') #/ get value from hash
    ->map    (sub ($x) { $x =~ s/\s$//r }) #/ trim any trailing whitespace
    ->filter (sub ($x) { length $x != 0 }) #/ ignore if length == 0
    ->map    (sub ($x) { uc $x          }) #/ uppercase it
;

is($upper->get_or_else(''), 'STEVAN', '... got the result we expected');

=cut

done_testing;



