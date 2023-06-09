<!-------------------------------------------------------->
# ELO - Proposal for Typed Promises
<!-------------------------------------------------------->

## Typed Promises

Promises should expect to get events when resolved and rejected.

```perl
my $p = promise[ *eResponse, *eError ];
```

This would expect an `*eResponse` event if resolved, and an `*eError`
if rejected.

This would get checked with `resolve` or `reject` are called.

> QUESTION:
> What would happen if the promise got an exception during its
> execution and then called `reject` with that non-event error?

> QUESTION:
> Also, when `then` is called another promise is created. This then
> wraps stuff and calls `resolve` and `reject`, etc. Should we
> propogate the event-types here? or let this part just handle
> the return values as regular stuff?
>
> If we didn't pass down the event-type, the first problem would
> probably not happen.
>
> But not passing down the values might get messy, who knows.

> NOTE: How this relates to `collect` is undetermined, a lot will
> depend on if we pass the types down the promise-chain.

## Alternate to `then`

The `then` method of the Promise interface is a bit odd, it will
accept up to 2 handlers, first for `resolve` and the second for
`reject`.  Honestly, I never liked this interface.

Since we know the types, we can re-use the `match` style and
match on the event-types. Here is an example.

```perl

my $p = promise[ *eResponse, *eError ];

# instead of ...
# $p->then(sub { ... }, sub { ... });

$p->match(
    *eResponse => sub { ... },
    *eError    => sub { ... },
);

```

This has the added benefit of giving us a way to handle the issues
described above with regard to exceptions and the like.

So perhaps something like this would work:

```perl

my $p = promise[ *eResponse, *eError ];

# ...

$p->match(
    *eResponse => sub { ... },
    *eError    => sub { ... },
    _          => sub { ... }, # catch all for other events
);

```

> NOTE: I am not a huge fan of the `_` catch all, it is nice in
> other languages, but kind looks gross in Perl.

Here is another idea:

```perl

my $p = promise[ *eResponse, *eError ];

# ...

$p->match(
    *eResponse => sub { ... },
    *eError    => sub { ... },
    default {
        ...
    }
);

```

> NOTE: Since we are not enforcing a HASH ref, we can have
> this `default` handler style approach, which is more aligned
> with the `switch` syntax in most languages.










