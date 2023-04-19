# ELO TODO


## Time based Timers

- MAXWAIT (max wait time) - 3600
- MNOW (monotonic time) - use Time::HiRes::clock_gettime( Time::HiRes::CLOCK_MONOTONIC() )
- TIMERS sorted list of timers (Time, Callback)
- WAITTIME - possible time to wait if no events exist

if TIMERS && the first time is less than or equal to MNOW
    run timer callbacks

if TIMERS
    find the next wait time
        if less than MAXWAIT
            WAITTIME = next timer value + roundup a millisecond (??? see AnyEvent, not sure why)
        else
            WAITTIME is MAXWAIT

process for events from msg/sig/cb queues

if no more events
    sleep for WAITTIME


-----------------------------------------------------------
## General
-----------------------------------------------------------

### To Do

- trampoline needs building!

- review code to
    - make sure we catch/handle all exceptions

- monitors
    - monitors are uni-directional, and only the monitor receieves from the watched items

- make SIGNALS into bitmask
    - use dualvar to make string/int combos

- make FLAGS for the process, also with bitmask style
    - TRAP_EXIT

- store process flags in an array
    -

-----------------------------------------------------------
## Messages
-----------------------------------------------------------

### TODO

- make a Message class

- should messages have headers?
    - they are a great way to control messaging
    - we could pass things like:
        - session ids
        - PID to call back
        - promises

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

- actor state is complex, the sub versions have limits
    - ideally it is stateless
        - or passes state via messages & self calls
    - shared state works with `state` variables
    - instance state works with inside-out object on the `$this` value
    - a proper class based Actor would give the most flexibility
        - and be more comfortable to users

- make a way to mark a given Actor as accepting Promises
    - `sub SomeActor ($this, $msg) : Promise { ... }`
    - this could be used to implement `ask` like behavior perhaps
        - `ask` could create and return the promise
            - but throw an exception of the recieving Actor doesn't do `Promise` trait

- currently there is no way to pass constructor arguments to Actors
    - this maybe needs a Factory?
    - or maybe make a proper OO Actor to support this style
        - and let the functional style stay as is

- does it make sense to try and type the actors?
    - `sub SomeActor ($this, $msg) : Promise(eResponse, eError) { ... }`
        - this tells the system, that actor wants promises
        - it can also say the events is expects to get back
    - `sub SomeActor ($this, $msg) : Callback { ... }`
        - this tells it it needs a PID callback
    - `sub SomeActor ($this, $msg) : SessionId { ... }`
        - this tells that a session ID is expected

-----------------------------------------------------------
## Process
-----------------------------------------------------------

### TODO

- consider a spawn_link() that will
    - immediately link to the new process

- should we support blocking behavior at all?
    - this will almost be needed for Futures

-----------------------------------------------------------
## Futures
-----------------------------------------------------------

Futures can be thought of as the read-side of Promises,
and in most systems can be used in a blocking manner.
However, we don't want to allow blocking, so this really
is not what we want. It is better if we stick with
promises only.

It causes issues with distributed Actors, since Promises
don't serialize, but we can deal with this when we get
to the distributed part anyway.

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

-----------------------------------------------------------
## Links
-----------------------------------------------------------

### Actors

https://doc.akka.io/docs/akka/2.5/actors.html#dependency

### Signals

https://man7.org/linux/man-pages/man7/signal.7.html

https://www.erlang.org/doc/reference_manual/processes.html#delivery-of-signals
https://www.erlang.org/doc/reference_manual/processes.html#signals
https://www.erlang.org/doc/man/erlang.html#is_process_alive-1
https://www.erlang.org/doc/reference_manual/processes.html#receiving_exit_signals
https://www.erlang.org/doc/man/erlang.html#process_flag_trap_exit



