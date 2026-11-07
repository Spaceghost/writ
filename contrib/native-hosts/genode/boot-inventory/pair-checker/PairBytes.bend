import Base

# Fixed grammar limit. These helpers validate public untrusted byte descriptions;
# no native identity, authority or release is implied by a successful result.
# Only manifest_hex stages its public bound; direct helper calls require
# caller-bounded inputs and are not authority entrypoints.
def max_manifest() -> U32: 1466

def count_next_checked(count: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: Some{(count + 1 : U32)}

def count_next(+count: U32, maximum: U32) -> Maybe<&2, U32>:
  count_next_checked(count, U32.is_lt(count, maximum))

def within(bytes: +List<U32>, +maximum: U32, count: Maybe<&2, U32>) -> Bool:
  match bytes count:
    case _ None{}: False{}
    case Nil{} Some{_}: True{}
    case Con{_, rest} Some{count}:
      within(rest, maximum, count_next(count, maximum))

def ascii(bytes: +List<U32>, valid: Bool) -> Bool:
  match bytes valid:
    case _ False{}: False{}
    case Nil{} True{}: True{}
    case Con{value, rest} True{}: ascii(rest, U32.is_le(value, 127))

def hex_char_checked(value: U32, digit: Bool) -> Char:
  match digit:
    case True{}: Char.from_u32((value + 48 : U32))
    case False{}: Char.from_u32((value + 87 : U32))

def hex_char(+value: U32) -> Char:
  hex_char_checked(value, U32.is_lt(value, 10))

def reverse_string(s: String, result: String) -> String:
  match s:
    case SNil{}: result
    case SCon{c, rest}: reverse_string(rest, SCon{c, result})

def hex_reversed(bytes: +List<U32>, result: String) -> String:
  match bytes:
    case Nil{}: result
    case Con{+value, rest}:
      hex_reversed(rest, SCon{hex_char((value .&. 15 : U32)),
        SCon{hex_char(U32.shrn(value, 4n)), result}})

def hex_ascii_checked(bytes: +List<U32>, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case False{}: None{}
    case True{}: Some{reverse_string(hex_reversed(bytes, ""), "")}

def hex_cap_checked(+bytes: +List<U32>, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case False{}: None{}
    case True{}: hex_ascii_checked(bytes, ascii(bytes, True{}))

# Public checked entry: the cap and byte range are staged before conversion.
def manifest_hex(+bytes: +List<U32>) -> Maybe<&2, String>:
  hex_cap_checked(bytes, within(bytes, max_manifest(), Some{0}))
