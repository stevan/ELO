<!-------------------------------------------------------->
# ELO - Types
<!-------------------------------------------------------->

The ELO type system is made up of $n parts:

- Type constrints for Core values
    - Undef, Int, Float, String, Scalar, ArrayRef, HashRef, CodeRef
        - NOTE: no Object types
    - current all instances of a ELO::Core::Type subclass
        - has a `check` method that checks the constraint
    - NOTE: more on type features later

- Types are named using GLOB symbols
    - ex: `type  *Int => sub { ... }` defines the `*Int` type
    - Types must be registered before they can be used
        - this means associating it a name/symbol
            - so anon types are not possible
    - We only associate the GLOB with our type constraint
        - this means we do not alter the glob in any way
            - so it is safe to use an already existing GLOB
            - ex: `sub Foo {}` and `*Foo` are safe to use in the same program
    - GLOBs have several advantages
        - they are always accessible within Perl program
            - and are easily exported using existing tools (ex: `Exporter`)
        - they are already singletons
            - so no scope management is needed
        - they stringify sensibly for HASH keys
            - given `package Bar { *Foo }` the `*Foo` glob will stringify to `*Bar::Foo`
            - this is true even if you import `*Foo` into another package

- new Types can be easily be defined
    - it is possible to define you own types
        - ex: `type  *PositiveInt => sub { ... }`
    - it is possible to alias a type
        - ex: `type  *NumItems => *Int`
        - allows a descriptive name for a type
    - it is possible to create a composite tuple datatype
        - ex: `datatype [Point => *Point] => ( *Int, *Int );`
            - creates a new type `*Point`
            - creates a constructor function `Point`
                - which takes two arguments
                    - which are checked against `*Int`
                - and returns an ARRAY ref blessed into the `Point` class
                    - NOTE: the `Point` class is not explictly defined
                        - we let Perl do this automagically
                            - or done with typeclasses, but more about that later
    - it is possible to create a algebreic version of datatypes
        - ex: `datatype *Option => sub {
                    case None => ();
                    case Some => ( *Scalar );
            }`
            - creates a new type `*Option`
            - creates a constructor for each `case`
                - arguments are checked against the associate tuple
                - returns an ARRAY ref blessed into `Option::{None,Some}` class

- methods can be added to Types
    - this is done with Typeclasses
        - must be associated with existing type
        - currently only datatypes and algebreaic datatypes are supported

- datatype ex:
```perl
type *X => *Int;
type *Y => *Int;

datatype [Point => *Point] => ( *X, *Y );

typeclass[*Point] => sub {
    method x => *X;
    method y => *Y;

    method clear => sub ($) { Point( 0, 0 ) };

    method clone => sub ($p) {
        Point( $p->x, $p->y )
    };
};
```
- accessors can be defined by using aliased types
    - here is where naming types come in handy
        - you are basically giving an index for the accessor to use
        - which means types with the same name, cant be used in the datatype definition
            - but these also then serve as parameter names as well
                - ex: the above `*X` vs. something like `x => *Int`
- methods can be defined and get the type instance as first parameter
    - and any addition parameters you define
    - if it is not used, a `$` can be used to tell perl you will ignore it
        - see `clear` above
- types are immutable as there is no way to define an mutator
    - so new instances are returned instead


- algebreaic datatype ex:
```perl

datatype *Tree => sub {
    case Node => ( *Scalar, *Tree, *Tree );
    case Leaf => ();
};

typeclass[ *Tree ], sub {

    method is_leaf => {
        Node => sub ($, $, $) { 0 },
        Leaf => sub ()        { 1 },
    };

    method is_node => {
        Node => sub ($, $, $) { 1 },
        Leaf => sub ()        { 0 },
    };

    method get_value => {
        Node => *Scalar,
        Leaf => sub () { () },
    };

    method get_left => {
        Node => sub ($, $left, $) { $left },
        Leaf => sub ()            { die "Cannot call get_left on Leaf" },
    };

    method get_right => {
        Node => sub ($, $, $right) { $right },
        Leaf => sub ()             { die "Cannot call get_right on Node" },
    };

    method traverse => sub ($t, $f, $depth=0) {
        match[ *Tree => $t ], +{
            Node => sub ($x, $left, $right) {
                $f     -> ($x, $depth);
                $left  -> traverse ($f, $depth+1);
                $right -> traverse ($f, $depth+1);
            },
            Leaf => sub () {
                $f -> (undef, $depth);
            },
        }
    };

    method dump => +{
        Node => sub ($x, $left, $right) {
            [ $x, $left->dump, $right->dump ];
        },
        Leaf => sub () {
            ()
        },
    };
};
```
- every method must handle all varients
- accessors can still be defined by using aliased types
    - see `get_value` above
- method variants can be defined in two ways
    - using a HASH ref
        - should have a key for each variant
        - and CODE that expects the destructured type as args
            - this is an alternative way to write accessors as well
                - see `get_left` and `get_right` above
    - using a CODE ref
        - these get the type instance as first parameter
            - and any addition parameters you define
        - you must handle the type varients yourself
            - the `match` keyword helps with this


## Other stuff

- the `match` keyword
- enum types
- type parameters

