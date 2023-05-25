<!-------------------------------------------------------->
# ELO Streams
<!-------------------------------------------------------->

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


<!-------------------------------------------------------->
## Phase 1 - Connect
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


                        +------------ (3)------------+--(3a.)--<spawn>-->[Subscription]
                        |                            |
[ Source ] --(1)--> [Publisher]                    (3b.)
                        ^                            |
                        |                            |
             {*Subscribe, $subscriber}   {*OnSubscribe, $subscription}
                        |                            |
                       (2)                           |
                        |                            |
  [ Sink ] --(1)--> [Subscriber] <-------------------+


Legend:
() - Step
[] - Actor
{} - Event
<> - action

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

### Step 5.

- `Subscriber`
    - receives the `*OnNext`, `*OnComplete` & `*OnError` events response from `Observer`
        - `drip` values into the `Sink`

### Status

```

                                  {*OnNext, $val}
      +---------------------------{*OnComplete, }-------------------------------------+
      |                           {*OnError,  $e}                                     |
      |                                                                              (4)
      V                                                                               |
[Subscriber] --(1)--{*Request, $n}--> [Subscription] --(2)--+--(2a.)--<spawns>--> [Observer] <-----+
      |                                                     |                                      |
     (5)                                                  (2b.)                                    |
      |                                                     |                                      |
    <drip>                                             <repeat $n>                                 |
      |                                                     |                                {*OnNext, $val}
      V                                            {*GetNext, $observer}                     {*OnComplete, }
    [Sink]                                                  |                                {*OnError,  $e}
                                                            V                                      |
                                                        [Publisher]                                |
                                                            |                                      |
                                                           (3)--+--(3.a)--<get_next>->[Source]     |
                                                                |                                  |
                                                              (3.b)--------------------------------+


Legend:
() - Step
[] - Actor
{} - Event
<> - action

```

<!-------------------------------------------------------->
## Phase 3 - COMPLETE
<!-------------------------------------------------------->




<!-------------------------------------------------------->




