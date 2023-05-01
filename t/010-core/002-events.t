#!perl

use v5.36;
no warnings 'once';

use Test::More;
use Test::Differences;

use ok 'ELO::Types',  qw[
    :core
    event
    lookup_event_type
];

subtest '... define an event' => sub {
    event *eHelloWorld => ( *Str, *Int, *ArrayRef, *Float );
    pass('... event has been defined');

};

subtest '... retrieve an event' => sub {
    eq_or_diff(
        [ lookup_event_type(*eHelloWorld)->definition ],
        [ *Str, *Int, *ArrayRef, *Float ],
        '... got the event definition'
    );
};

subtest '... check an event instance' => sub {
    ok( lookup_event_type(*eHelloWorld)->check( 'hello', 10, [], 0.001 ), '... we type checked an event instance' );

    ok( !lookup_event_type(*eHelloWorld)->check( [] ), '... the type check failed with a single ArrayRef' );
    ok( !lookup_event_type(*eHelloWorld)->check( 'foo', 10, [] ), '... the type check failed with bad arity' );

    ok( !lookup_event_type(*eHelloWorld)->check( 'foo', 'bar', [], 0.001 ), '... the type check failed with bad data' );
    ok( !lookup_event_type(*eHelloWorld)->check( {}, 'bar', [], 0.001 ), '... the type check failed with bad data' );
    ok( !lookup_event_type(*eHelloWorld)->check( 'foo', 100, {}, 0.001 ), '... the type check failed with bad data' );
    ok( !lookup_event_type(*eHelloWorld)->check( 'foo', 0.22, [], 0.001 ), '... the type check failed with bad data' );
    ok( !lookup_event_type(*eHelloWorld)->check( 'foo', 22, [], 'baz' ), '... the type check failed with bad data' );
    ok( !lookup_event_type(*eHelloWorld)->check( 'foo', 22, [], {}, 100 ), '... the type check failed with bad data' );
    ok( !lookup_event_type(*eHelloWorld)->check( 'foo', 22, [], 0.0001, 100 ), '... the type check failed with bad data' );
};


done_testing;

1;

__END__

