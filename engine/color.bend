# Colors: Bend-UI tokens ("#rrggbb") read as RGB in 0..1, the way the GPU takes them.

import Base
import ./vec.bend as V

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# One hex digit: 0-9, a-f or A-F.
def digit(c: Char) -> U32:
  +n = Char.to_u32(c)
  pick(U32.is_lt(n, 58), (n - 48 : U32), pick(U32.is_lt(n, 71), (n - 55 : U32), (n - 87 : U32)))

def byte(hi: Char, lo: Char) -> F32:
  (U32.to_f32((digit(hi) * 16 + digit(lo) : U32)) / 255.0 : F32)

# "#rrggbb" to RGB. Anything else is black.
def rgb(s: String) -> V.V3:
  match s:
    case SCon{_, SCon{r1, SCon{r2, SCon{g1, SCon{g2, SCon{b1, SCon{b2, _}}}}}}}:
      V.V3{byte(r1, r2), byte(g1, g2), byte(b1, b2)}
    case _:
      V.V3{0.0, 0.0, 0.0}
