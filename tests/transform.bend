# Numerical tests of engine/transform.bend (see tests/quat.bend for why
# float math is tested here and not by laws).
#
# Limits now:
# - A test is checked at a few chosen values, not for every value as a law
#   is. It catches mistakes; it does not prove there are none.

import Base
import ../engine/vec.bend as V
import ../engine/quat.bend as Q
import ../engine/transform.bend as T

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

def p() -> V.V3: V.V3{0.5, 2.0, (0.0 - 1.5 : F32)}

# Moved, turned a quarter around Y, and stretched.
def moved() -> T.Transform:
  T.Transform{V.V3{3.0, 1.0, (0.0 - 2.0 : F32)}, Q.axis_angle(V.V3{0.0, 1.0, 0.0}, 1.5707964), V.V3{2.0, 1.0, 0.5}}

# A point through the matrix (w = 1, so the position counts).
def by_matrix(+t: T.Transform, +v: V.V3) -> V.V3:
  V.xyz(V.apply(T.to_m4(t), V.V4{V.x(v), V.y(v), V.z(v), 1.0}))

def checks() -> List<&2, Check>:
  [Check{"identity leaves a point where it is",
     close3(T.point(T.identity(), p()), p())},
   Check{"at(position) only moves",
     close3(T.point(T.at(V.V3{1.0, 2.0, 3.0}), p()), V.V3{1.5, 4.0, 1.5})},
   Check{"the matrix places a point as point() does",
     close3(by_matrix(moved(), p()), T.point(moved(), p()))},
   Check{"scale, then turn, then move: (1, 0, 0) goes to (3, 1, -4)",
     close3(T.point(moved(), V.V3{1.0, 0.0, 0.0}), V.V3{3.0, 1.0, (0.0 - 4.0 : F32)})},
   Check{"the origin of the thing lands on its position",
     close3(T.point(moved(), V.V3{0.0, 0.0, 0.0}), V.V3{3.0, 1.0, (0.0 - 2.0 : F32)})},
   Check{"the identity matrix places a point where it is",
     close3(by_matrix(T.identity(), p()), p())}]
