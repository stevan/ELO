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
use ELO::JSON::Token::Source;


subtest '... testing the JSON Token Source type' => sub {
    my $from_list = ELO::JSON::Token::Source::FromList([ 1 .. 10 ]);
    my $from_gen  = ELO::JSON::Token::Source::FromGenerator(sub { state $x = 1; $x <= 10 ? $x++ : undef });

    foreach (1 .. 10) {
        is($from_list->get_next, $_, '... got the expected value from FromList');
        is($from_gen->get_next, $_, '... got the expected value from FromGenerator');
    }

    ok(! defined $from_list->get_next, '... got the expected value (undef) from FromList');
    ok(! defined $from_gen->get_next, '... got the expected value (undef) from FromGenerator');

    ok(! defined $from_list->get_next, '... got the expected value (undef) from FromList');
    ok(! defined $from_gen->get_next, '... got the expected value (undef) from FromGenerator');
};


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

    isa_ok($json, 'ELO::JSON::JSON::Object');
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

    my $source = ELO::JSON::Token::Source::FromList( [ @tokens ] );

    my $acc = [];
    foreach my $token (@tokens) {
        ok( lookup_type(*ELO::JSON::Token::JSONToken)->check( $token ), '... the JSONToken object type checked correctly' );
        ELO::JSON::Token::process_token( $token, $acc );
    }

    try {
        ELO::JSON::Token::process_token( $_, $acc ) foreach (
            ELO::JSON::Token::StartObject(),
                ELO::JSON::Token::StartProperty( "Foo" ),
                    ELO::JSON::Token::AddString( "Bar" ),
            ELO::JSON::Token::EndObject()
        );
        fail('... this should have thrown an exception');
    } catch ($e) {
        like($e, qr/marker\(OBJECT\) but got marker\(PROPERTY\)/, '... got the expected error');
    }

    #warn Dumper \@tokens;

    my ($json1) = @$acc;
    my $json2 = ELO::JSON::Token::process_tokens( \@tokens );

    my $_acc = [];
    my $t;
    while ($t = $source->get_next) {
        ELO::JSON::Token::process_token( $t, $_acc );
    }
    my ($json3) = @$_acc;

    foreach my $json ($json1, $json2, $json3) {
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

subtest '... testing the JSON Source type' => sub {
    my $source = ELO::JSON::Token::Source::FromGenerator(sub {
        state $counter = 1;
        state @buffer  = (ELO::JSON::Token::StartArray());

        unless (@buffer) {
            if ($counter <= 10) {
                #warn "BEGIN $counter";
                @buffer = (
                    ELO::JSON::Token::StartItem( $counter ),
                        ELO::JSON::Token::AddInt( $counter++ ),
                    ELO::JSON::Token::EndItem(),
                );

                if ($counter % 2 == 0) {
                    #warn "START $counter";
                    unshift @buffer => ELO::JSON::Token::StartArray();
                }
                elsif ($counter > 0) {
                    #warn "END $counter";
                    push @buffer => ELO::JSON::Token::EndArray();
                }

                if ($counter > 10) {
                    #warn "ENDALL $counter";
                    push @buffer => ELO::JSON::Token::EndArray();
                }
            }
        }

        #warn Dumper \@buffer;
        shift @buffer;
    });

    my $acc = [];
    my $t;
    while ($t = $source->get_next) {
        ELO::JSON::Token::process_token( $t, $acc );
    }
    my ($json) = @$acc;

    is(
        $json->to_string,
        '[[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]]',
        '... encode works'
    );

};

done_testing;

1;

__END__

