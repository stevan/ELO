<!-------------------------------------------------------->
# Proposal for Expanded Promises
<!-------------------------------------------------------->

## Typed Promises

Promises should expect to get events when resolved and rejected.

```perl
my $p = promise[ *eResponse, *eError ];
```

This would expect an `*eResponse` event if resolved, and an `*eError`
if rejected.

This would get checked with `resolve` or `reject` are called.

```perl
my $p = collect( [ *eResponse, *eError ], @promises );
```

The same could be done for `collect` and it would just expect to
get a bunch of `*eResponse` events.

> QUESTION:
> What would happen if the promise got an exception during its
> execution and then called `reject` with that non-event error?
>
> Also, when `then` is called another promise is created. This then
> wraps stuff and calls `resolve` and `reject`, etc. Should we
> propogate the event-types here? or let this part just handle
> the return values as regular stuff?
>
> If we didn't pass down the event-type, the first problem would
> probably not happen.
>
> But not passing down the values might get messy, who knows.

## Alternate to `then`

```perl

my $p = promise[ *eResponse, *eError ];

# instead of ...
# $p->then(sub { ... }, sub { ... });

$p->match(
    *eResponse => sub { ... },
    *eError    => sub { ... },
);

```
