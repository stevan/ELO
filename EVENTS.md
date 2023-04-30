<!-------------------------------------------------------->
# Proposal for Formal Events
<!-------------------------------------------------------->

An event is the data structure used for communication between two
processes/actors. An event can be thought of consisting of two
parts, the "event-type" and a "payload". An event does not know to
whom it is being sent to or any other meta-info, this will be
handled elsewhere. The event is only concerned with conveying
the payload through the "actor-space".

> NOTE: It is important that events be serializable as much as
> possible, this is to enable cleanly upgradeing to distributed actors.

### Declaring an event

An event declaration incldues the event-type and payload type definiton,
like so:

```perl
event *Foo => [ *Str, ... ];
```

> NOTE: More details about the payload type definiton is below.

### Sending an event

An event instance is what is created and sent to another process. In
the example below `$actor1` is sending the `*eFoo` event to `$actor2`
with the payload shown.

```perl
$actor1->send( $actor2, [ *Foo => "hello world", ... ] );
````

This payload should be able to pass the payload type-constraint found
in the event declaration.

### Recieve an event

In order to recieve an event, an actor can either manually unpack the
`$msg`, or use the supplied `match` function, like so:

```perl
match $msg, +{
    *eFoo => sub ($string, @other_stuff) {
        ...;
    }
}
```

The `match` function is "event-aware" in that it will take the event
into account in what it is doing.


<!-------------------------------------------------------->
## How Actors and Events are implemented/integrated
<!-------------------------------------------------------->

Events can be defined as TYPELGLOBs, this will make it easier to scope
them as they are essentially global.

So a simple event definiton and an Actor definition would work like so:

```perl
event *Foo => [ *Str ];

sub Actor ($this, $msg) {

    match $msg, +{
        *Foo => sub ($bar) { say "Bar ($bar)" }
    };
}
```

A simple Actor Factory also works, and since the TYPEGLOBs are not
scoped like regular variables you can define them anywhere you like
and it doesn't really make any difference.

```perl
# this event is visible to all
event *Foo => [ *Str ];

sub ActorFactory (%args) {

    # this event is also visible to all ...
    event *Bar => [ *Str ];

    build_actor Actor => sub ($this, $msg) {

        match $msg, +{
            *Foo => sub ($bar) { say "Bar($bar)" },
            *Bar => sub ($baz) { say "Baz($baz)" },
        };
    }
}
```

> NOTE: It might be possible to play some tricks with `local` to get some
> level of TYPEGLOB privacy, but the usefulness of that in this context
> is highly suspect. The "event-types" are better as globals then as
> something whose scope we need to manage.

The best (and only) way to manage TYPEGLOBs is to use packages, which
are the natural storage for them. And since TYPEGLOBs can be imported
and aliased, it is possible to share/reuse them easily.

```perl
package My::App::Events {
    use ELO::Types ':core'; # import Core types like *Str

    # make them exportable ...
    our @EXPORT_OK = (
        Foo
        Bar
        Baz
    );

    # define them ...
    event *Foo => [ *Str ];
    event *Bar => [ *Str ];
    event *Baz => [ *Str ];
}
```

It is possible both to fully qualify your event-types, as well as
import them locally. And the best part is that the stringified version
will always refer to the fully qualified name, so it becomes very
easy to find the original TYPEGLOB and any meta info stored there.

```perl
*My::App::Events::Foo # .. this works to address them directly

use My::App::Events qw[ Foo ];

*Foo # ... this works, and when stringified is "*My::App::Events::Foo"

```

The payload type definitions basically give us a level of
signature type checking on the handler/reciever callbacks.

Inside  the `match` keyword the following should happen:

1. look at the `$msg` and determine the event-type
2. lookup the event-type
    - fail loudly if we cannot find it
    - or return the found event payload type-declaration
3. Type check the `$msg` body against the event payload type-declaration
    - throw errors appropriately

```perl
event *Foo => [ *Str ];
event *Bar => [ *Str, *Int ];

sub Actor ($this, $msg) {

    match $msg, +{
    #   *Foo ------> *Str
        *Foo => sub ($bar) {  ...  }

    #   *Bar ------> *Str, *Int
        *Bar => sub ($bar, $baz) { ...  }
    };
}
```

<!-------------------------------------------------------->
## Perl Types
<!-------------------------------------------------------->

The event payload type declarations are best throught of as
type-constraints in that they can only be checked at runtime and
not at compile time. This is similar to other "type constraint"
modules in Perl, the biggest difference being that these types
are just symbols and the type checking is done by interpreting
the symbols, rather than the types being active objects who
know how to check themselves.

### Perl Literal types

As mentoned above, we want events to be as network-portable as possible, which
means we really want to restrict the types to things we can serialize and then
deserialize, possibly on a different machine.

Given this, it makes sense to base our type system on JSON and start out with
the following simple scalar types.

```perl
type *Bool;  # map to Perl's ideal of a boolean (?)
type *Int;   # map to IV (and PVIV)
type *Float; # map to NV (and PVNV)
type *Str;   # map to PV, and PV** varients
```

> NOTE: these are not intended to be stricter than Perl is itself, so using
> internal SV type should work in the expected way, which is to say it matches
> Perl's expectations.

We can add the basic JSON reference scalar types as well.

```perl
type *ArrayRef; # just checks reftype
type *HashRef;  # just checks reftype
```

> NOTE: we do not check the contents of the reference scalar types
> so something like `*ArrayRef[*Int]` is not supported by these types
> but more on that later.

> NOTE: Consider adding `*RegExpRef` as well since they can be serialized as
> a string and would work just fine locally as well.

> NOTE: We do not support things like `*ScalarRef` or `*CodeRef` as they
> are not possible to serialize, but in theory they should be included so
> that they could be used in local actor networks. Both of these would
> need to be used very carefully to avoid sharing data references in a
> way that would cause problems/confusion.

### Perl Virtual types

We also add in some "virtual" types, which are there only to model the event
messages in a way that is meaningful to Perl.

```perl
type *Scalar;  # basically this is the Any type
type *Ref;     # basically this is the Any Ref type
type *List;    # this is a slurpy list ... basically "give me all that remains" in a type declaration
type *Hash;    # same as *List, but for pairs
```

If you wanted to create an event which took any simple scalar type then you
would use the `*Scalar` type. This can be thought of as a union of `*Bool`,
`*Int`, `*Float` and `*Str`.

If you wanted to accept a reference type, use the `*Ref` virtual type which can
be thought of as a union of `*ArrayRef` and `*HashRef`.

If you wanted to accept a variable number of values and did not want to put
them inside of an `*ArrayRef` then you could use `*List` which replicates the
slurpy behavior of Perl's lists. As should be expected, no other types can follow
the `*List` type, that would be an error.

```perl
event *eSlurpy    => [ *Str, *List ];     # [ "foo", 0 .. 10 ]
event *eNonSlurpy => [ *Str, *ArrayRef ]; # [ "foo", [ 0 .. 10 ] ]
```
The same style behavior can be found with `*Hash` but with regards to key-value
pairs instead of just scalar values.

```perl
event *eSlurpyHash    => [ *Str, *Hash ];     # [ "foo", ( one => 1, two => 2, ... ) ]
event *eNonSlurpyHash => [ *Str, *HashRef ]; # [ "foo", { one => 1, two => 2, ... } ]
```

### ELO Core types

Along with the above types we have some core types within ELO that need to be
represented.

It is often that we need to pass some kind of process information in an event.
For example, to provide a return "address" where the reciever can send a response.
So we need some kind of way to represent a Process or an Actor instance, or possibly
just their PID.

```perl
type *Process; # a Process instance
type *Actor;   # an Actor instance
type *PID;     # a PID value (Str) of a Process/Actor instance
```

In some ways the above three types are interchangable since the loop will know how
to handle the Process/Actor instances, and will know how to lookup the PID and get
a Process/Actor instance.

> NOTE: In a distributed setup all Process/Actor instances would be serialized as PIDs
> so they could be easily transported.

In addition to the processes we might need to pass other ELO entities such as
promises and timer IDs.

```perl
type *Promise; # a Promise instance
type *TimerID; # a Timer ID (which is a ScalarRef)
```

> NOTE: The above are both restricted to local actors only since they cannot
> reasonably be serialized.

<!-------------------------------------------------------->
## Implementation Notes
<!-------------------------------------------------------->

- it is possible to use Magic on the TYPEGLOBs we use for events
    - and prevent other slots in the GLOB from being set, effectively locking the GLOB
    - and to store the type definition data via the `data` slot (fetched with `getdata`)

https://metacpan.org/pod/Variable::Magic#wizard
https://metacpan.org/release/VPIT/Variable-Magic-0.63/source/t/34-glob.t

- type checking should call B::svref_2object to inspect the var


<!-------------------------------------------------------->
## Misc.
<!-------------------------------------------------------->

Should we support some kind of generics in the type system?

```perl
sub Ref      ($T) { bless [ *Ref,      $T->[0] ] => 'type::generic' }
sub ArrayRef ($T) { bless [ *ArrayRef, $T->[0] ] => 'type::generic' }
sub HashRef  ($T) { bless [ *HashRef,  $T->[0] ] => 'type::generic' }


event *eFoo => [ ArrayRef[ *Int ], ... ];
```

It opens up a whole can of worms, but it could be helpful.

-----------------------------------------------------------

Just a sketch I did of something, I want to keep it here.

Simple version:
```
type *Method  => [ *GET, *POST ];
type *URL     => *Str;

type *Header  => [ *ContentType, *Accept ];
type *Headers => { *Header => *Str };

type *Request  => [ *Method, *URL,  *Headers ];
type *Response => [ *Status, *Headers, *Body ];
```

Less Simple version:
```
enum *Method  => (*GET, *POST);

type *URL => *Str;

enum *Header => (
    *ContentType,
    *Accept
);

type *Headers => List[ Pair[ *Header => *Str ] ];

struct *Request => {
    method  => *Method,
    url     => *URL,
    headers => *Headers,
};

struct *Response => {
    status  => *Status,
    headers => *Headers,
    body    => *Body
};


```
