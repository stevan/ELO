<!-------------------------------------------------------->
# ELO Streams
<!-------------------------------------------------------->

## Concepts

- `Source`
    - this is a syncronous component
    - provides a feed of values via a `next` method
        - typically to a `Publisher`
    - the feed is over when `undef` is returned
        - FIXME: This should be an `Option` type
- `Sink`
    - this is a syncronous component
    - this captures a feed of values via `drip` method
        - typically from a `Subscriber`
    - these values can be accessed via a `drain` method


- `Publisher`
    - this is a asyncronous component
    - given a `Source` publish values via a `Subscription` to a `Subscriber`
    - will passively wait until need is signalled
- `Subscriber`
    - this is a asyncronous component
    - given a `Subscription` can request values from a `Publisher` and pass them onto a `Sink`
    - this must signal for need to accommodate back-pressure
- `Subscription`
    - this is a asyncronous component
    - given a `Subscriber` and `Publisher` can handle manage the flow via an `Observer`
    - this is the engine of this system, it drives the flow
- `Observer`
    - this is a asyncronous component
    - This serves as a bridge between a `Publisher` and `Subscriber`
    - it watches for a specific amount of requests from a `Publisher`
        - and forwards to a `Subscriber`
        - an event is sent to the `Subscriber` when all requests have been seen

<!-------------------------------------------------------->
## Phase 1 - CONNECT
<!-------------------------------------------------------->

### Step 1.

- `Publisher`
    - is connected to a `Source`
- `Subscriber`
    - is connected to a `Sink`

> NOTE:
> This step is mostly syncronous, as `Source` & `Sink` are sync components
> but there is nothing stopping you from doing it asyncronously via events
> if you wanted.

### Step 2.

- `Subscriber`
    - subscribes to a `Publisher` by sending a `*Subscribe` event

### Step 3.

- `Publisher`
    - receieves the `*Subscribe` events from `Subscriber`
        - spawns a new `Subscription`
        - sends `*OnSubscribe` to `Subscriber` with newly spawned `Subscription`

### Status

At this point the `Publisher` and `Subscriber` are both connected via the
`Subscription` all that is left is for the `Subscriber` to signal a need
for values.

```

              :
              :
              :              +-------------(3)------------+--(3.a)--<spawn>-->[Subscription]
              :              |                            |
[ Source ]----:-------> [Publisher]                     (3.b)
              :              ^                            |
              :              |                            |
              :  {*Subscribe, $subscriber}   {*OnSubscribe, $subscription}
              :              |                            |
              :             (2)                           |
              :              |                            |
  [ Sink ]----:-------> [Subscriber] <--------------------+
              :
              :
              :

Legend:
 :  - async boundary
( ) - Step
[ ] - Actor
{ } - Event
< > - action

```

<!-------------------------------------------------------->
## Phase 2 - RUN
<!-------------------------------------------------------->

### Step 1.

- `Subscriber`
    - sends `*Request` event to `*Subscription` signifying need

> NOTE:
> This will often happen when the `Publisher` sends the `*OnSubscribe`
> event to the `Subscriber`, but it may not, so we use it as a dividing
> line between the phases.

### Step 2.

- `Subscription`
    - receives the `*Request` event
        - spawns a new `Observer` that is connected the `Subscriber`
            - the observer watches for a specific number of requests
        - sends the requested amount of `*GetNext` events to the `Publisher`
            - with the `Observer` as the return address

### Step 3.

- `Publisher`
    - receives the `*GetNext` events
        - requests the `next` value from the `Source`
            - responds to return address (the `Observer`) with:
                - `*OnNext` if it has a value
                - `*OnComplete` if it has no more values
                - `*OnError` if it has an error

### Step 4.

- `Observer`
    - receives the `*OnNext`, `*OnComplete` & `*OnError` events response from `Publisher`
        - forwards event to `Subscriber`
        - if `Observer` has seen all requests it sends `*OnRequestComplete` to `Subscriber`

### Step 5.

- `Subscriber`
    - receives the `*OnNext`, `*OnComplete` & `*OnError` events response from `Observer`
        - `drip` values into the `Sink`

### Status

This represents on request cycle for a `Subscriber`, where `$n` values can be requested
from the `Publisher` which are then subsequently delivered to the `Observer`. When all
values are delivered to the `Observer` it will signal the `Subscriber` accordingly. At
this point the `Subscriber` must choose if it wants to singal for more need.

```

                :            +------------------{*OnRequestComplete}----<if $n seen>----(4.b)--+
                :            |                                                                 |
                :            |                  {*OnNext,      $val}                           |
                :            |   +--------------{*OnComplete       }--------------------(4.a)--+
                :            |   |              {*OnError,       $e}                           |
                :            |   |                                                            (4)
                :            V   V                                                             |
  [Sink] <---<drip>--(5)--[Subscriber]     [Subscription]--(2)--(2.a)--<spawns>--> [Observer]--+
                :              |                  ^         |                          ^
                :             (1)                 |       (2.b)                        |
                :              |                  |         |                          |
                :              +--{*Request, $n}--+    <repeat $n>                     |
                :                                           |                   {*OnNext, $next}
                :                                  {*GetNext, $observer}        {*OnComplete   }
                :                                           |                   {*OnError,   $e}
                :                                           V                          |
                :                                       [Publisher]                    |
                :                                           |                          |
[Source] <--<get_next>------------------------------(3.a)--(3)--(3.b)------------------+
                :
                :


Legend:
:  - async boundary
() - Step
[] - Actor
{} - Event
<> - action

```

<!-------------------------------------------------------->
## Phase 3 - COMPLETE
<!-------------------------------------------------------->

### Step 1.

- `Publisher`
    - sends an `*OnComplete` to the `Observer`

### Step 2.

- `Observer`
    - forwards the `*OnComplete` to the `Subscriber`
        - trips a circuit breaker in `Observer` to only send this once

### Step 3.

- `Subscriber`
    - receievs the `*OnComplete` event
        - sends syncronous `done` call to `Sink` to let it know its done
        - sends `*Cancel` to `Subscription`

### Step 4.

- `Subscription`
    - receives the `*Cancel` event from the `Subscriber`
        - sends `*Unsubscribe` event to the `Publisher` with itself as the payload

### Step 5.

- `Publisher`
    - receives the `*Unsubscribe` event from the `Subscription`
        - sends `*OnUnsubscribe` event to `Subscription`

### Step 6.

- `Subscription`
    - receives the `*Unsubscribe` event from the `Publisher`
        - sends `*OnUnsubscribe` signal to `Subscriber`
        - sends `*SIGEXIT` to `Observer`
        - exits()

### Status

```

            :
            :       +----------------------{*SIGEXIT}-------------------------------+
            :       |                                                               |
            :       |        (5)--------{*OnUnsubscribe}-------------------------+  |
            :       |         |                                                  |  |
            :       |    [Publisher] <---------------------------+               |  |
            :       |         |                                  |               |  |
            :       |        (1)                                 |               |  |
            :       |         |                                  |               |  |
            :       |   {*OnComplete}                            |               |  |
            :       |         |                                  |               |  |
            :       |         V                                  |               |  |
            :       +---> [Observer]                             |               |  |
            :                 |                                  |               |  |
            :               (2)[/]                 {*Unsubscribe, $subscription} |  |
            :                 |                                  |               |  |
            :           {*OnComplete}                           (4)              |  |
            :                 |                                  |               |  |
            :                 V                                  |               |  |
[Sink] <--<done>--(3.a)--[Subscriber]--(3.b)--{*Cancel}--> [Subscription] <------+  |
            :                 ^                                  |                  |
            :                 |                                  |                  |
            :                 +-------{*OnUnsubscribe}---(6.a)--(6)--(6.b)----------+
            :

Legend:
:   - async boundary
()  - Step
[]  - Actor
{}  - Event
<>  - action
[/] - circuit breaker

```

### Appendix

### Step 7.

- `Publisher`
    - if `*GetNext` is called and:
        - the `Observer` process is not alive
            - throw error??
        - otherwise, send `*OnError` to `Observer`
        - all subsequent calls will be ignored because of a circuit breaker

```

            :
            :               |
            :       <in flight request>
            :               |
            :      {*GetNext, $observer}
            :               |
            :               V
            :          [Publisher]
            :               |
            :              (7)[/]---<ignore>-->*
            :               |
            :      <is_alive $observer>
            :         |            |
            :       <YES>         <NO>
            :         |            |
            :    {*OnError}     <ignore>
            :         |
            :         V
            :    [$observer]
            :

Legend:
:   - async boundary
()  - Step
[]  - Actor
{}  - Event
<>  - action
[/] - circuit breaker
```

<!-------------------------------------------------------->
## Phase 4 - ERROR
<!-------------------------------------------------------->



<!-------------------------------------------------------->




