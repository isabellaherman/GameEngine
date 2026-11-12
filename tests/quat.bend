# Numerical tests of engine/quat.bend.
#
# Laws are proofs, and the law checker does not compute float arithmetic,
# so float math is tested here instead: Bend computes each case and decides
# whether it passed; tools/test.ts only runs the list and prints it.
# "Close" means within 0.0001.
#
# Limits now:
# - A test is checked at a few chosen values, not for every value as a law
#   is. It catches mistakes; it does not prove there are none.

import Base
import ../engine/vec.bend as V
import ../engine/quat.bend as Q

type Check is Data:
  Check{name: String, ok: Bool}

def tol() -> F32: 0.0001

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), tol())

# Degrees come back through sines and cosines, so they are compared to
# within 0.01°.
def closed(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.01)

def close3d(+a: V.V3, +b: V.V3) -> Bool:
  (closed(V.x(a), V.x(b)) && closed(V.y(a), V.y(b)) && closed(V.z(a), V.z(b)))

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

# The same rotation: q and -q count as one.
def same_turn(+a: Q.Q, +b: Q.Q) -> Bool:
  close(F32.abs(Q.dot(a, b)), 1.0)

def pi() -> F32: 3.1415927

def up() -> V.V3: V.V3{0.0, 1.0, 0.0}
def right() -> V.V3: V.V3{1.0, 0.0, 0.0}
def some() -> V.V3: V.V3{0.3, (0.0 - 1.2 : F32), 2.5}

def quarter() -> Q.Q: Q.axis_angle(up(), (pi() / 2.0 : F32))
def eighth() -> Q.Q: Q.axis_angle(up(), (pi() / 4.0 : F32))
def tilted() -> Q.Q: Q.axis_angle(V.V3{1.0, 2.0, (0.0 - 0.5 : F32)}, 0.7)

def checks() -> List<&2, Check>:
  [Check{"identity leaves a vector alone",
     close3(Q.rotate(Q.identity(), some()), some())},
   Check{"a quarter turn around Y takes X to -Z (right-hand rule)",
     close3(Q.rotate(quarter(), right()), V.V3{0.0, 0.0, (0.0 - 1.0 : F32)})},
   Check{"a full turn comes back to the start",
     close3(Q.rotate(Q.axis_angle(up(), (2.0 * pi() : F32)), some()), some())},
   Check{"axis_angle gives length 1",
     close(Q.length(tilted()), 1.0)},
   Check{"mul(a, b) is b first, then a",
     close3(Q.rotate(Q.mul(quarter(), tilted()), some()), Q.rotate(quarter(), Q.rotate(tilted(), some())))},
   Check{"mul keeps length 1",
     close(Q.length(Q.mul(quarter(), tilted())), 1.0)},
   Check{"conj undoes the rotation",
     close3(Q.rotate(Q.conj(tilted()), Q.rotate(tilted(), some())), some())},
   Check{"the matrix turns a vector the same way",
     close3(V.xyz(V.apply(Q.to_m4(tilted()), V.V4{0.3, (0.0 - 1.2 : F32), 2.5, 1.0})), Q.rotate(tilted(), some()))},
   Check{"q and -q turn a vector the same way",
     close3(Q.rotate(Q.neg(tilted()), some()), Q.rotate(tilted(), some()))},
   Check{"slerp at 0 is the start",
     same_turn(Q.slerp(Q.identity(), tilted(), 0.0), Q.identity())},
   Check{"slerp at 1 is the end",
     same_turn(Q.slerp(Q.identity(), tilted(), 1.0), tilted())},
   Check{"slerp halfway to a quarter turn is an eighth turn",
     same_turn(Q.slerp(Q.identity(), quarter(), 0.5), eighth())},
   Check{"slerp takes the short way when given -q",
     same_turn(Q.slerp(Q.identity(), Q.neg(quarter()), 0.5), eighth())},
   Check{"nlerp halfway between a turn and itself is that turn",
     same_turn(Q.nlerp(tilted(), tilted(), 0.5), tilted())},
   Check{"slerp between two almost equal turns stays length 1",
     close(Q.length(Q.slerp(tilted(), Q.mul(tilted(), Q.axis_angle(up(), 0.00001)), 0.5)), 1.0)},
   Check{"degrees: a quarter around Y is the same turn as axis_angle",
     same_turn(Q.from_degrees(V.V3{0.0, 90.0, 0.0}), quarter())},
   Check{"degrees: Z first, then X, then Y",
     same_turn(Q.from_degrees(V.V3{20.0, 30.0, 40.0}), Q.mul(Q.axis_angle(up(), 0.5235988), Q.mul(Q.axis_angle(right(), 0.34906584), Q.axis_angle(V.V3{0.0, 0.0, 1.0}, 0.6981317))))},
   Check{"degrees come back as typed (30, -45, 60)",
     close3d(Q.to_degrees(Q.from_degrees(V.V3{30.0, (0.0 - 45.0 : F32), 60.0})), V.V3{30.0, (0.0 - 45.0 : F32), 60.0})},
   Check{"degrees come back as typed (-10, 170, -120)",
     close3d(Q.to_degrees(Q.from_degrees(V.V3{(0.0 - 10.0 : F32), 170.0, (0.0 - 120.0 : F32)})), V.V3{(0.0 - 10.0 : F32), 170.0, (0.0 - 120.0 : F32)})},
   Check{"no rotation is 0, 0, 0 degrees",
     close3d(Q.to_degrees(Q.identity()), V.V3{0.0, 0.0, 0.0})}]
