# A proposal for formal Events

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

NOTE: It might be possible to play some tricks with `local` to get some
level of TYPEGLOB privacy, but the usefulness of that in this context
is highly suspect. The "types" are better as globals then as something
whose scope we need to manage.

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
It is possible both to fully qualify your types/events, as well as
import them locally. And the best part is that the stringified version
will always refer to the fully qualified name, so it becomes very
easy to find the original TYPEGLOB and any meta info stored there.

```perl
*My::App::Events::Foo # .. this works to address them directly

use My::App::Events qw[ Foo ];

*Foo # ... this works, and when stringified is "*My::App::Events::Foo"

```

The type definitions, or type bodies basically give us a level of
signature type checking on the handler/reciever callbacks.

Inside  the `match` keyword the following should happen:

1. look at the `$msg` and determine the event type
2. lookup the event type
    - fail loudly if we cannot find it
    - or return the found evemt declaration
3. Type check the `$msg` body against the event declaration
    - throw errors appropriately
        - this will be much better than the sig errors

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

### Internal Types

- SV
    - IV = int
    - UV = unsigned int
    - NV = double
    - PV = string
- RV = ref to SV
- AV = list of SVs
- HV = list of pairs of Str to SV
- GV = glob (filehandle, etc)
- CV = subroutine


### Perl Literal types

These are natural Perl data structures, and since we are going for a simple
JSON-like type system, they are core literal types for our system.

```perl
type *Bool;
type *Int;
type *Float;
type *Str;

type *ArrayRef;
type *HashRef;
```

These should map to the values in the "Internals types", though we combine
the IV and UV for brevity and create a Bool that is not technically an SV
form, but which we can detect via the `B` module.

We also add in some "virtual" types, which are there only to model the event
messages in a way that is meaningful to Perl.

```perl
type *Scalar;  # basically this is the Any type
type *List;    # this is a slurpy list ... basically "give me all that remains" in a type declaration
type *Hash;    # same as *List, but for pairs
```

### ELO Core types

We have some types in ELO that we want to model as well since they are often
sent in event bodies.

```perl
type *Process; # a Process instance
type *Actor;   # an Actor instance
type *PID;     # a PID value (Str) of a Process/Actor instance

type *Promise; # a Promise instance
```
