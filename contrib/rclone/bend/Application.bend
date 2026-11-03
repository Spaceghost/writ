import Base
import ./Wire.bend as Wire
import ./Model.bend as Model
import ./Presenter.bend as Presenter

type Reply is Data:
  Reply{state: Model.State, response: String}

def mutation(result: Model.Reply, directory: String) -> Reply:
  match result:
    case Model.Reply{state, "OK", Some{record}, _}:
      Reply{state, "OK\n" ++ Presenter.file(record)}
    case Model.Reply{state, "OK", None{}, _}:
      Reply{state, "OK\n" ++ Wire.directory(directory)}
    case Model.Reply{state, status, _, _}:
      Reply{state, Wire.error(Presenter.error_code(status))}

def query_scope(+path: String) -> Bool:
  String.is_empty(path) || (Model.valid_path(path) && Model.within_scope(path))

def ordinary(request: Wire.Request) -> Bool:
  Wire.Request{_, _, _, _, dest, source, expected, body} = request
  String.is_empty(dest) && U32.is_eq(source, 0) && U32.is_eq(expected, 0) && String.is_empty(body)

def inspect(operation: String, +path: String, +state: Model.State) -> Reply:
  match operation:
    case "STAT":
      Reply{state, Presenter.stat(path, state)}
    case "LIST":
      Reply{state, Presenter.list(path, state)}
    case "POLICY":
      Reply{state, Presenter.policy(path, state)}
    case "MKDIR":
      mutation(Model.mkdir(path, state), path)
    case _:
      Reply{state, Wire.error("UNSUPPORTED")}

def inspect_allowed(allowed: Bool, operation: String, path: String, state: Model.State) -> Reply:
  match allowed:
    case True{}:
      inspect(operation, path, state)
    case False{}:
      Reply{state, Wire.error("INVALID")}

def status_allowed(allowed: Bool, +state: Model.State) -> Reply:
  match allowed:
    case True{}:
      Reply{state, Presenter.status(state)}
    case False{}:
      Reply{state, Wire.error("INVALID")}

def receipt_allowed(allowed: Bool, id: String, +state: Model.State) -> Reply:
  match allowed:
    case True{}:
      Reply{state, Presenter.receipt(id, state)}
    case False{}:
      Reply{state, Wire.error("INVALID")}

def dispatch(+request: Wire.Request, state: Model.State) -> Reply:
  match request:
    case Wire.Request{_, "PUT", _, _, _, _, _, _}:
      mutation(Model.dispatch(request, state), "")
    case Wire.Request{_, "COPY", _, _, _, _, _, _}:
      mutation(Model.dispatch(request, state), "")
    case Wire.Request{_, "OPEN", _, _, _, _, _, _}:
      Reply{state, Wire.error("DENIED")}
    case Wire.Request{_, "STATUS", _, +path, _, _, _, _}:
      status_allowed(ordinary(request) && String.is_empty(path), state)
    case Wire.Request{_, "RECEIPT", _, +id, _, _, _, _}:
      receipt_allowed(ordinary(request) && Wire.id_ok(id), id, state)
    case Wire.Request{_, operation, _, +path, _, _, _, _}:
      inspect_allowed(ordinary(request) && query_scope(path), operation, path, state)

def authenticated(allowed: Bool, request: Wire.Request, state: Model.State) -> Reply:
  match allowed:
    case True{}:
      dispatch(request, state)
    case False{}:
      Reply{state, Wire.error("DENIED")}

def accept(parsed: Maybe<&2, Wire.Request>, token: String, state: Model.State) -> Reply:
  match parsed:
    case Some{+request}:
      Wire.Request{provided, _, _, _, _, _, _, _} = request
      authenticated(String.eq(provided, token), request, state)
    case None{}:
      Reply{state, Wire.error("INVALID")}
