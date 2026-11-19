# Numerical tests of engine/clip.bend, engine/blend.bend and
# engine/gait.bend, on the test arm (projects/character/arm.bend).

import Base
import ../engine/vec.bend as V
import ../engine/quat.bend as Q
import ../engine/transform.bend as Tr
import ../engine/skeleton.bend as Sk
import ../engine/pose.bend as P
import ../engine/clip.bend as C
import ../engine/blend.bend as B
import ../engine/gait.bend as G
import ../projects/character/arm.bend as Arm
import ../engine/helpers.bend as H
import ../engine/hand.bend as Hand

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

def closeq(+a: Q.Q, +b: Q.Q) -> Bool:
  close(F32.abs(Q.dot(a, b)), 1.0)

def quarter() -> Q.Q:
  Q.axis_angle(V.V3{0.0, 0.0, 1.0}, 1.5707964)

def eighth() -> Q.Q:
  Q.axis_angle(V.V3{0.0, 0.0, 1.0}, 0.7853982)

# A one-second clip that turns the forearm (bone 2) a quarter around Z.
def bend() -> C.Clip:
  C.Clip{"bend", 1.0, 0.0, [C.Turns{2, [C.Turn{0.0, Q.identity()}, C.Turn{1.0, quarter()}]}]}

def rest() -> P.Pose:
  P.rest(Arm.skeleton())

def forearm(+p: P.Pose) -> Q.Q:
  Tr.rotation(P.local_at(p, 2))

def hand(+p: P.Pose) -> V.V3:
  P.head(P.m4_at(P.model(Arm.skeleton(), p), 4))

def fingertip(+p: P.Pose) -> V.V3:
  P.tail(P.m4_at(P.model(Arm.skeleton(), p), 7), 0.03)

def track_count(+c: C.Clip) -> U32:
  U32.from_nat(List.length(&2, U32, C.bones(c)))

def checks() -> List<&2, Check>:
  [Check{"time past the end loops: 2.5 s of a 1 s clip is 0.5 s",
     close(C.wrap(2.5, 1.0), 0.5)},
   Check{"at a key's time, the pose is that key",
     closeq(forearm(C.sample(bend(), rest(), 0.0)), Q.identity())},
   Check{"halfway between two keys, the rotation is halfway along the arc",
     closeq(forearm(C.sample(bend(), rest(), 0.5)), eighth())},
   Check{"bones without a track keep the base pose",
     close3(Tr.position(P.local_at(C.sample(bend(), rest(), 0.5), 4)), V.V3{0.0, 0.25, 0.0})},
   Check{"mixing with weight 0 gives the first pose",
     close3(hand(B.mix(rest(), C.sample(bend(), rest(), 0.99), 0.0)), hand(rest()))},
   Check{"mixing with weight 1 gives the second pose",
     close3(hand(B.mix(rest(), C.sample(bend(), rest(), 0.5), 1.0)), hand(C.sample(bend(), rest(), 0.5)))},
   Check{"the walk drives the arm's two animated arm slots",
     U32.is_eq(track_count(G.walk(Arm.skeleton())), 2)},
   Check{"the walk comes back to where it started after one cycle",
     close3(hand(C.sample(G.walk(Arm.skeleton()), rest(), 0.0)), hand(C.sample(G.walk(Arm.skeleton()), rest(), 0.9999)))},
   Check{"the elbow support turns half as much as the elbow bends",
     closeq(Tr.rotation(P.local_at(H.apply(H.prepare(Arm.skeleton(), Arm.rules()), C.sample(bend(), rest(), 0.9999)), 5)), eighth())},
   Check{"at rest, every helper stays at rest",
     closeq(Tr.rotation(P.local_at(H.apply(H.prepare(Arm.skeleton(), Arm.rules()), rest()), 3)), Q.identity())},
   Check{"a fist brings the fingertip closer to the hand",
     F32.is_lt(V.dist(fingertip(Hand.grip(Arm.skeleton(), rest(), 1.0)), hand(rest())), V.dist(fingertip(rest()), hand(rest())))},
   Check{"grip 0 leaves the fingers as they are",
     close3(fingertip(Hand.grip(Arm.skeleton(), rest(), 0.0)), fingertip(rest()))},
   Check{"in the idle the arm hangs: the hand is below the shoulder",
     F32.is_lt(V.y(hand(C.sample(G.idle(Arm.skeleton()), rest(), 0.0))), 1.2)}]
