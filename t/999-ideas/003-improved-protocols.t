#!perl

use v5.36;
no warnings 'once';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'ELO::Actors', qw[ receive ];
use ok 'ELO::Types',  qw[
    :core
    :events
    :types
];

# Events ...

# the basic Observer interface, shared by many ...

event *OnComplete => ();
event *OnNext     => ( *Scalar );
event *OnError    => ( *Str );

# Subscription related events ...

event *Subscribe     => ( *Process );
event *OnSubscribe   => ( *Process );

event *Unsubscribe   => ( *Process );
event *OnUnsubscribe => ();


# Request related events ...

event *Request           => (*Int);
event *OnRequestComplete => ();
event *Cancel            => ();

# Publisher related events ..

event *GetNext     => ( *Process );

# Protocols ...


protocol *Observer => sub {
    accepts *OnNext,
            *OnComplete,
            *OnError;
};

protocol *Subscriber => sub {
    accepts *OnSubscribe,
            *OnUnsubscribe,
            *OnRequestComplete,
            *OnNext,
            *OnComplete,
            *OnError;
};

protocol *Subscription => sub {
    accepts *Request,
            *Cancel,
            *OnUnsubscribe;
};


protocol *Publisher => sub {
    accepts *Subscribe,   returns *OnSubscribe;
    accepts *Unsubscribe, returns *OnUnsubscribe;
    accepts *GetNext,
        returns *OnNext, *OnComplete,
        raises *OnError;
};

=pod

=cut

done_testing;

1;

__END__

