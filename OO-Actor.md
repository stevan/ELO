
type PID;

type Event { name: String, body: Any }

type Msg { to: PID, from: PID, event: Event };


role Actor {

    sub receive (Msg $msg) -> ();

}


class ActorRef {

    has Actor   : actor;
    has Process : process;

}
