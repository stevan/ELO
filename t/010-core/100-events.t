#!perl

use v5.36;
no warnings 'once';

use Test::More;
use Test::Differences;

use B;
use Scalar::Util qw[ looks_like_number ];

use ok 'ELO::Core::Type';

my $Bool = ELO::Core::Type->new(
    symbol  => \*Bool,
    checker => sub ($bool) {
        return defined($bool)                      # it is defined ...
            && not(ref $bool)                      # ... and it is not a reference
            && ($bool =~ /^[01]$/ || $bool eq '')  # ... and is either 1,0 or an empty string
    }
);

my $Str = ELO::Core::Type->new(
    symbol  => \*Str,
    checker => sub ($str) {
        return defined($str)                      # it is defined ...
            && not(ref $str)                      # ... and it is not a reference
            && ref(\$str) eq 'SCALAR'             # ... and its just a scalar
            && B::svref_2object(\$str) isa B::PV  # ... and it is at least `isa` B::PV
    }
);

my $Int = ELO::Core::Type->new(
    symbol  => \*Int,
    checker => sub ($int) {
        return not(ref $int)                      # if it is not a reference
            && looks_like_number($int)            # ... if it looks like a number
            && int($int) == $int                  # and is the same value when converted to int()
            && B::svref_2object(\$int) isa B::IV  # ... and it is at least `isa` B::IV
    }
);

my $Float = ELO::Core::Type->new(
    symbol  => \*Float,
    checker => sub ($float) {
        return not(ref $float)                      # if it is not a reference
            && looks_like_number($float)            # ... if it looks like a number
            && $float == ($float + 0.0)             # and is the same value when converted to float()
            && B::svref_2object(\$float) isa B::NV  # ... and it is at least `isa` B::NV
    }
);

subtest '... checking *Bool' => sub {
    ok( $Bool->check( !!1 ),   '... this type checked for Bool with !!1' );
    ok( $Bool->check( !!0 ),   '... this type checked for Bool with !!0' );
    ok( $Bool->check( 1 ),   '... this type checked for Bool with 1' );
    ok( $Bool->check( 0 ),   '... this type checked for Bool with 0' );
    ok( $Bool->check( '' ),   '... this type checked for Bool with empty-string' );

    ok( !$Bool->check( "Foo" ), '... this failed the type check for Bool with an Str' );
    ok( !$Bool->check( 100 ),   '... this failed the type check for Bool with an Int' );
    ok( !$Bool->check( 0.01 ),  '... this failed the type check for Bool with an Float' );
    ok( !$Bool->check( [] ),    '... this failed the type check for Bool with an ArrayRef' );
    ok( !$Bool->check( {} ),    '... this failed the type check for Bool with an HashRef' );
};

subtest '... checking *Str' => sub {
    ok( $Str->check( 'foo' ),   '... this type checked for Str with a single-quoted Str' );
    ok( $Str->check( "foo" ),   '... this type checked for Str with a double-quoted Str' );
    ok( $Str->check( q[foo] ),  '... this type checked for Str with a q[] Str' );
    ok( $Str->check( qq[foo] ), '... this type checked for Str with a qq[] Str' );
    ok( $Str->check( '1000' ), '... this type checked for Str with a quoted number Str' );

    ok( $Str->check( !!1 ),  '... this type checked for Str with an Bool (see also - Perl)' );
    ok( $Str->check( 100 ),  '... this type checked for Str with an Int (see also - Perl)' );
    ok( $Str->check( 0.01 ), '... this type checked for Str with an Float (see also - Perl)' );

    ok( !$Str->check( [] ),   '... this failed the type check for Str with an ArrayRef' );
    ok( !$Str->check( {} ),   '... this failed the type check for Str with an HashRef' );
};

subtest '... checking *Int' => sub {
    ok( $Int->check( 1 ),   '... this type checked for Int with a single-digit Int' );
    ok( $Int->check( 100 ),   '... this type checked for Int with a regular Int' );
    ok( $Int->check( 1_000_000 ),  '... this type checked for Int with a _ seperated Int' );
    ok( $Int->check( int("256") ),  '... this type checked for Int with a Str converted via int()' );

    ok( $Int->check( !!1 ),  '... this type checked for Int with a Bool (see also - Perl)' );
    ok( $Int->check( "256" ),  '... this type checked for Int with a Str containing numbers (see also - Perl)' );

    ok( !$Int->check( 'foo' ),   '... this failed the type check for Int with a single-quoted Str' );
    ok( !$Int->check( "foo" ),   '... this failed the type check for Int with a double-quoted Str' );
    ok( !$Int->check( q[foo] ),  '... this failed the type check for Int with a q[] Str' );
    ok( !$Int->check( qq[foo] ), '... this failed the type check for Int with a qq[] Str' );
    ok( !$Int->check( 0.01 ), '... this failed the type check for Int with an Float' );
    ok( !$Int->check( [] ),   '... this failed the type check for Int with an ArrayRef' );
    ok( !$Int->check( {} ),   '... this failed the type check for Int with an HashRef' );
};

subtest '... checking *Float' => sub {
    ok( $Float->check( 1.0 ),   '... this type checked for Float with a simple Float' );
    ok( $Float->check( 0.0001 ),   '... this type checked for Float with a simple Float' );

    ok( $Float->check( int("256") ),  '... this type checked for a Float with a Str converted via int() (see also - Perl)' );
    ok( $Float->check( 100 ),   '... this type checked for Float with with an Int (see also - Perl)' );
    ok( $Float->check( !!1 ),  '... this type checked for Float with a Bool (see also - Perl)' );
    ok( $Float->check( '3.14' ),  '... this type checked for a Float with a Str containing a float (see also - Perl)' );

    ok( !$Float->check( 'foo' ),   '... this failed the type check for Float with a single-quoted Str' );
    ok( !$Float->check( "foo" ),   '... this failed the type check for Float with a double-quoted Str' );
    ok( !$Float->check( q[foo] ),  '... this failed the type check for Float with a q[] Str' );
    ok( !$Float->check( qq[foo] ), '... this failed the type check for Float with a qq[] Str' );
    ok( !$Float->check( [] ),   '... this failed the type check for Float with an ArrayRef' );
    ok( !$Float->check( {} ),   '... this failed the type check for Float with an HashRef' );
};

done_testing;

1;

__END__
