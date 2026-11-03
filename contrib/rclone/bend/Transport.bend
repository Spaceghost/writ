import Base
import ./Wire.bend as Wire

# One bounded ASCII request per connection. Byte IO avoids UTF-8 replacement or
# split-codepoint behavior creating a second interpretation of an envelope.
type Reading is Type:
  Pending{socket: Socket, buffer: String}
  Complete{socket: Socket, line: String}
  Failed{socket: Socket}

def ascii_value(+value: U32) -> Bool:
  U32.is_eq(value, 9) || U32.is_eq(value, 10) ||
    (U32.is_ge(value, 32) && U32.is_le(value, 126))

def ascii(xs: List<&2, U32>) -> Maybe<&2, String>:
  match xs:
    case []:
      Some{SNil{}}
    case 10 <> _:
      # Stop before validating or counting trailing connection data. Framing
      # must have the same interpretation for coalesced and split TCP packets.
      Some{"\n"}
    case +head <> tail:
      do Maybe<&2, String>:
        _ : Unit <- Wire.require(ascii_value(head))
        rest : String <- ascii(tail)
        return SCon{Char.from_u32(head), rest}

def pending_size(socket: Socket, buffer: String, allowed: Bool) -> Reading:
  match allowed:
    case True{}:
      Pending{socket, buffer}
    case False{}:
      Failed{socket}

def complete_size(socket: Socket, line: String, allowed: Bool) -> Reading:
  match allowed:
    case True{}:
      Complete{socket, line}
    case False{}:
      Failed{socket}

# Split only a receive chunk (at most 4096 bytes), never the accumulated large
# payload. ascii already discards everything after the first LF. Count that LF
# in the frame limit even though the parser receives only the preceding line.
def append_lines(socket: Socket, buffer: String, lines: List<&2, String>) -> Reading:
  match lines:
    case [part]:
      +all = buffer ++ part
      pending_size(socket, all, Wire.bounded(all, Wire.max_frame()))
    case [part, ""]:
      +line = buffer ++ part
      complete_size(socket, line, Wire.bounded(line, (Wire.max_frame() - 1 : U32)))
    case _:
      Failed{socket}

def append(socket: Socket, buffer: String, chunk: Maybe<&2, String>) -> Reading:
  match chunk:
    case Some{part}:
      append_lines(socket, buffer, String.lines(part))
    case None{}:
      Failed{socket}

def received(buffer: String, result: Socket & Poll<&1, &1,
  Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>) -> Reading:
  (socket, read) = result
  match read:
    case Ready{Done{Some{bytes}}}:
      append(socket, buffer, ascii(bytes))
    case _:
      Failed{socket}

def read_before(socket: Socket, buffer: String, remaining: U32, expired: Bool) -> IO(Reading):
  match expired:
    case True{}:
      IO.pure(Reading, Failed{socket})
    case False{}:
      do IO<Reading>:
        result : Socket & Poll<&1, &1,
          Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>
          <- TCP.try_recv_bytes(socket, 4096, remaining)
        return received(buffer, result)

def read_step(socket: Socket, buffer: String, deadline: Nat) -> IO(Reading):
  do IO<Reading>:
    +now : Nat <- IO.now()
    +until : Nat = deadline
    read_before(socket, buffer, U32.from_nat(Nat.min(5000n, Nat.sub(until, now))),
      Nat.is_ge(now, until))

# The first LF ends the single frame. Any later connection data is discarded,
# whether it arrived in the same receive or a later packet; pipelining is absent.
# Both total time and fragmentation have a bound. A client sending one byte per
# packet cannot keep the single reference-service worker forever.
def read_loop(fuel: Nat, state: Reading, +deadline: Nat) -> IO(Reading):
  match fuel state:
    case 0n Pending{socket, _}:
      IO.pure(Reading, Failed{socket})
    case 1n+rest Pending{socket, buffer}:
      do IO<Reading>:
        next : Reading <- read_step(socket, buffer, deadline)
        read_loop(rest, next, deadline)
    case _ final:
      IO.pure(Reading, final)

def read(socket: Socket) -> IO(Reading):
  do IO<Reading>:
    now : Nat <- IO.now()
    read_loop(1024n, Pending{socket, SNil{}}, Nat.add(now, 5000n))

def close_sent(result: Socket & Poll<&1, &1,
  Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, List<&2, U32>>) -> IO(Unit):
  (socket, _) = result
  Socket.close(socket)

def reply_bounded(socket: Socket, response: String, allowed: Bool) -> IO(Unit):
  match allowed:
    case True{}:
      do IO<Unit>:
        sent : Socket & Poll<&1, &1,
          Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, List<&2, U32>>
          <- TCP.try_send(socket, response, 5000)
        close_sent(sent)
    case False{}:
      do IO<Unit>:
        sent : Socket & Poll<&1, &1,
          Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, List<&2, U32>>
          <- TCP.try_send(socket, Wire.error("LIMIT"), 5000)
        close_sent(sent)

def frame_success(response: String, success: Bool) -> String:
  match success:
    case True{}:
      response ++ "END\n"
    case False{}:
      response

def frame_response(+response: String) -> String:
  frame_success(response, String.starts_with(response, "OK\n"))

# A final marker distinguishes a complete listing from a connection lost after
# an otherwise valid row. The client must reject an unfinished success response.
def reply(socket: Socket, response: String) -> IO(Unit):
  +framed = frame_response(response)
  reply_bounded(socket, framed, Wire.bounded(framed, Wire.max_response()))
