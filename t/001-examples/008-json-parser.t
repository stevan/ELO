#!perl

use v5.36;
use experimental 'try';

use Data::Dumper;

use Test::More;
use Test::Differences;

use lib 't/lib';

use ok 'ELO::Loop';
use ok 'ELO::Types',  qw[ :core :events :types :typeclasses ];
use ok 'ELO::Timers', qw[ :timers ];
use ok 'ELO::Actors', qw[ match ];

use ELO::JSON;
use ELO::JSON::Token;

subtest '... testing the JSON type' => sub {

    my $json = ELO::JSON::Object([
        ELO::JSON::Property('Foo', ELO::JSON::String("Bar")),
        ELO::JSON::Property('Baz', ELO::JSON::Array([
            ELO::JSON::Item(0, ELO::JSON::Int(10)),
            ELO::JSON::Item(1, ELO::JSON::Float(2.5)),
            ELO::JSON::Item(2, ELO::JSON::Array([ ELO::JSON::Int(1), ELO::JSON::Int(2) ])),
        ])),
    ]);

    ok( lookup_type(*ELO::JSON::JSON)->check( $json ), '... the JSON object type checked correctly' );

    is_deeply(
        $json->to_perl,
        { Foo => "Bar", Baz => [ 10, 2.5, [ 1, 2 ]]},
        '... decode works'
    );

    is(
        $json->to_string,
        '{"Foo" : "Bar", "Baz" : [10, 2.5, [1, 2]]}',
        '... encode works'
    );

};

subtest '... testing the JSON type' => sub {

    my @tokens = (
        ELO::JSON::Token::StartObject(),
            ELO::JSON::Token::StartProperty( "Foo" ),
                ELO::JSON::Token::AddString( "Bar" ),
            ELO::JSON::Token::EndProperty(),
            ELO::JSON::Token::StartProperty( "Baz" ),
                ELO::JSON::Token::StartArray(),
                    ELO::JSON::Token::StartItem( 0 ),
                        ELO::JSON::Token::AddInt( 10 ),
                    ELO::JSON::Token::EndItem(),
                    ELO::JSON::Token::StartItem( 1 ),
                        ELO::JSON::Token::AddFloat( 2.5 ),
                    ELO::JSON::Token::EndItem(),
                    ELO::JSON::Token::StartItem( 2 ),
                        ELO::JSON::Token::StartArray(),
                            ELO::JSON::Token::StartItem( 0 ),
                                ELO::JSON::Token::AddInt( 1 ),
                            ELO::JSON::Token::EndItem(),
                            ELO::JSON::Token::StartItem( 1 ),
                                ELO::JSON::Token::AddInt( 2 ),
                            ELO::JSON::Token::EndItem(),
                        ELO::JSON::Token::EndArray(),
                    ELO::JSON::Token::EndItem(),
                ELO::JSON::Token::EndArray(),
            ELO::JSON::Token::EndProperty(),
        ELO::JSON::Token::EndObject()
    );

    my $acc = [];
    foreach my $token (@tokens) {
        ok( lookup_type(*ELO::JSON::Token::JSONToken)->check( $token ), '... the JSONToken object type checked correctly' );
        ELO::JSON::Token::process_token( $token, $acc );
    }

    #warn Dumper \@tokens;

    my ($json1) = @$acc;
    my $json2 = ELO::JSON::Token::process_tokens( \@tokens );

    foreach my $json ($json1, $json2) {
        isa_ok($json, '*ELO::JSON::JSON::Object');

        is_deeply(
            $json->to_perl,
            { Foo => "Bar", Baz => [ 10, 2.5, [ 1, 2 ]]},
            '... decode works'
        );

        is(
            $json->to_string,
            '{"Foo" : "Bar", "Baz" : [10, 2.5, [1, 2]]}',
            '... encode works'
        );
    }

    try {
        ELO::JSON::Token::process_tokens( [ @tokens[ 0 .. ($#tokens - 5) ] ] );
        fail('... this should have thrown an exception');
    } catch ($e) {
        like( $e, qr/^More tokens needed/, '... this throws an expection');
    }

    try {
        ELO::JSON::Token::process_tokens( [ @tokens[ 3 .. ($#tokens - 5) ] ] );
        fail('... this should have thrown an exception');
    } catch ($e) {
        like( $e, qr/^JSON token processing failed/, '... this throws an expection');
    }
};

done_testing;

1;

__END__

