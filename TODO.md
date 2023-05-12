# ELO TODO

<!-------------------------------------------------------->
## General
<!-------------------------------------------------------->

- `protocol` needs to be implemented
    - see sketch in 002-data-feed-problem.t
    - write up `PROTOCOLS.md`


- [ ] See `EVENTS.md`
    - consider type extension
        - `subtype *Foo => *Str => where { ... };`
        - this opens up types to be arbitrarily complex
            - this means we can't control performance :(

    - should we add some kind of generics?

- [ ] See `PROMISES.md`

- [ ] add Akka style `become` to allow for state machines
    - see `200-actors/002-fp-examples/003-producer.t`

<!-------------------------------------------------------->
## Loop
<!-------------------------------------------------------->

- [ ] implement waking from sleep via signal
    - `$SIGWAKE`
    - add on_wake, on_sleep to Actors::Actor

- [ ] add dead-letter-queue to the loop
    - allow it be configured as a black-hole

- should we add `idle` callbacks?
    - they could be done instead of/in addition to waiting when there is nothing to do
    - use the AnyEvent approach and try to consumer no more than 50% of wait time

<!-------------------------------------------------------->
## Process
<!-------------------------------------------------------->

- consider a `spawn_link()` that will
    - immediately link to the new process

- [ ] trampoline needs building!
    - in loop? in process? in behavior?
    - also review code and ...
        - make sure we catch/handle all exceptions properly
        - some should be handleable via user code
            - come up with a mechanism
        - others should terminate the process gracefully

<!-------------------------------------------------------->
## Messages
<!-------------------------------------------------------->

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

<!-------------------------------------------------------->
## Promises
<!-------------------------------------------------------->

- improve the loop/promises integration
    - the ELO::Promise::LOOP is not great since it is global
        - though how often do you have two loops in a single process?
    - either way it is kinda ugly and should be improved

- should we add an `ask` method similar to `send`
    - this will automatically add the promise
    - if so, where should this live?
        - ELO::Process?
        - ELO::Promise?

<!-------------------------------------------------------->
## Actors
<!-------------------------------------------------------->

<!-------------------------------------------------------->
## Links
<!-------------------------------------------------------->

### Actors

https://doc.akka.io/docs/akka/2.5/actors.html#dependency

### Signals

https://man7.org/linux/man-pages/man7/signal.7.html

https://www.erlang.org/doc/reference_manual/processes.html#delivery-of-signals
https://www.erlang.org/doc/reference_manual/processes.html#signals
https://www.erlang.org/doc/man/erlang.html#is_process_alive-1
https://www.erlang.org/doc/reference_manual/processes.html#receiving_exit_signals
https://www.erlang.org/doc/man/erlang.html#process_flag_trap_exit



