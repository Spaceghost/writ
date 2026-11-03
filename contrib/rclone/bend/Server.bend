import Base
import ./Wire.bend as Wire
import ./Transport.bend as Transport
import ./Model.bend as Model
import ./Application.bend as Application

# Bounded single-worker reference: every accepted state transition completes
# before another request starts. Nothing is persisted across a process restart.
def publish(socket: Socket, reply: Application.Reply) -> IO(Model.State):
  Application.Reply{state, response} = reply
  do IO<Model.State>:
    Transport.reply(socket, response)
    return state

def handle(frame: Transport.Reading, token: String, state: Model.State) -> IO(Model.State):
  match frame:
    case Transport.Complete{socket, line}:
      publish(socket, Application.accept(Wire.parse(line), token, state))
    case Transport.Failed{socket}:
      do IO<Model.State>:
        Transport.reply(socket, Wire.error("INVALID"))
        return state
    case Transport.Pending{socket, _}:
      do IO<Model.State>:
        Transport.reply(socket, Wire.error("LIMIT"))
        return state

def serve_accepted(result: Listener & Result<&1, &1, U32 & String, Socket>,
  token: String, state: Model.State) -> IO(Listener & Model.State):
  (listener, accepted) = result
  match accepted:
    case Done{socket}:
      do IO<Listener & Model.State>:
        frame : Transport.Reading <- Transport.read(socket)
        next : Model.State <- handle(frame, token, state)
        return (listener, next)
    case Fail{_}:
      IO.pure(Listener & Model.State, (listener, state))

def serve(fuel: Nat, pair: Listener & Model.State, +token: String) -> IO(Unit):
  match fuel pair:
    case 0n Tuple{listener, _}:
      do IO<Unit>:
        Listener.close(listener)
        IO.print("Writ reference request limit reached; memory-only instance closed.")
    case 1n+rest Tuple{listener, state}:
      do IO<Unit>:
        accepted : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
        next : Listener & Model.State <- serve_accepted(accepted, token, state)
        serve(rest, next, token)

def configured_port(env: Result<&1, &1, U32 & String, String>) -> Maybe<&2, U32>:
  match env:
    case Fail{_}:
      Some{8787}
    case Done{value}:
      do Maybe<&2, U32>:
        +port : U32 <- Wire.decimal(value)
        _ : Unit <- Wire.require(U32.is_gt(port, 0) && U32.is_le(port, 65535))
        return port

def start_port(port: Maybe<&2, U32>, +token: String) -> IO(Unit):
  match port:
    case Some{+number}:
      do IO<Unit>:
        listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", number))
        IO.print("Writ reference ready at 127.0.0.1:" ++ U32.show(number) ++
          "; memory-only; plaintext reads denied.")
        serve(10000n, (listener, Model.empty()), token)
    case None{}:
      IO.die(Unit, 2, "WRIT_RCLONE_PORT must be a canonical decimal port in 1..65535.")

def start_token(allowed: Bool, token: String) -> IO(Unit):
  match allowed:
    case True{}:
      do IO<Unit>:
        port : Result<&1, &1, U32 & String, String> <- IO.get_env("WRIT_RCLONE_PORT")
        start_port(configured_port(port), token)
    case False{}:
      IO.die(Unit, 2, "WRIT_RCLONE_TOKEN must be 64 lowercase hex characters from 32 random bytes.")

def main() -> IO(Unit):
  do IO<Unit>:
    +token : String <- IO.try(String, IO.get_env("WRIT_RCLONE_TOKEN"))
    start_token(Wire.token_ok(token), token)
