# ELO TODO

-----------------------------------------------------------
## General
-----------------------------------------------------------

### To Do

- convert tests into proper perl tests
- review code to
    - make sure we catch/handle all exceptions

-----------------------------------------------------------
## Messages
-----------------------------------------------------------

### TODO

- make a Message class

### Questions

- should messages have headers?
    - they are a great way to control messaging

- should we add `from`?
    - and should it be exposed to the Actors?

- should we add a "stack" of some kind?
    - this could remove the need for `from`
    - and would allow for "stack" traces

-----------------------------------------------------------
## Events
-----------------------------------------------------------

### TODO

- make Event class
- make syntactic sugar
    - to define events    ... `state $eFoo = event( eFoo => Str, Int);`
    - to create instances ... `Event[ $eFoo, "bar", 10 ]`

### Questions

- should we make an Error class as well?
    - this would help with Error handling

- should we support both typed and untyped?
    - [ 10 ]             # untyped
    - [ eRequest => 10 ] # typed

-----------------------------------------------------------
## Promises
-----------------------------------------------------------

### To Do

- improve the loop/promises integration
    - the ELO::Promise::LOOP is not great since it is global
        - though how often do you have two loops in a single process?
    - either way it is kinda ugly and should be improved

### Questions

- should we add an `ask` method similar to `send`
    - this will automatically add the promise
    - if so, where should this live?
        - ELO::Process?
        - ELO::Promise?

- alternately we could use a `Promise[]` constructor
    - that works similar to `Event[]` described above
    - it will create a Promise and pass it along as well

-----------------------------------------------------------
## Actors
-----------------------------------------------------------

### ToDo

- make a way to mark a given Actor as accepting Promises
    - `sub SomeActor ($this, $msg) : Promise { ... }`
    - this could be used to implement `ask` like behavior perhaps
        - `ask` could create and return the promise
            - but throw an exception of the recieving Actor doesn't do `Promise` trait

### Questions

- currently there is no way to pass constructor arguments to Actors
    - this maybe needs a Factory?
    - or maybe make a proper OO Actor to support this style
        - and let the functional style stay as is

-----------------------------------------------------------
## Process
-----------------------------------------------------------

### TODO

- add despawn
    - Whenever an actor is stopped ...
        - all of its children are recursively stopped too.

### Questions

- should we support blocking behavior at all?
    - this will almost be needed for Futures

-----------------------------------------------------------
## Futures
-----------------------------------------------------------

### Questions

- should we add them?
    - if so, would they block?
        - do we want that?

- think about Futures
    - they could be typed to the event type
    - if there was an active future for a process
        - it would watch for that event
            - and when it found it
                - call the callbacks
        - this could happen within `accept` perhaps??

