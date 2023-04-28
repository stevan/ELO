# ELO TODO

-----------------------------------------------------------
## General
-----------------------------------------------------------

### To Do

- implement waking from sleep via signal
    - $SIGWAKE
    - add on_wake, on_sleep to Actors::Actor

- trampoline needs building!
    - in loop? in process?
    - Abstract::Process::tick is the best place probably

- add dead-letter-queue to the loop
    - allow it be configured as a black-hole

- review code to
    - make sure we catch/handle all exceptions properly
    - some should be handleable via user code
        - come up with a mechanism
    - others should terminate the process gracefully

### Questions

- should we add monitors?
    - monitors are uni-directional, and only the monitor receieves from the watched items

- ponder idle callbacks
    - they could be done instead of/in addition to waiting when there is nothing to do


-----------------------------------------------------------
## Messages
-----------------------------------------------------------

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
## Promises
-----------------------------------------------------------

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

- consider a spawn_link() that will
    - immediately link to the new process

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



