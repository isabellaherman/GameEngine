# Numerical tests of engine/pose.bend on the test arm
# (projects/character/arm.bend).
#
# Limits now:
# - Checked at a few chosen poses, not proven for all.

import Base
import ../engine/vec.bend as V
import ../engine/quat.bend as Q
import ../engine/transform.bend as Tr
import ../engine/skeleton.bend as Sk
import ../engine/pose.bend as P
import ../projects/character/arm.bend as Arm

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

# Bone i's head in a pose of the arm.
def head(+p: P.Pose, +i: U32) -> V.V3:
  P.head(P.m4_at(P.model(Arm.skeleton(), p), i))

def rest() -> P.Pose:
  P.rest(Arm.skeleton())

# The forearm bent a quarter turn around its own Z: it now points up.
def bent() -> P.Pose:
  P.set(rest(), 2, Tr.Transform{V.V3{0.0, 0.3, 0.0}, Q.axis_angle(V.V3{0.0, 0.0, 1.0}, 1.5707964), V.V3{1.0, 1.0, 1.0}})

def checks() -> List<&2, Check>:
  [Check{"the root sits at the origin",
     close3(head(rest(), 0), V.V3{0.0, 0.0, 0.0})},
   Check{"at rest the upper arm starts at the shoulder",
     close3(head(rest(), 1), V.V3{0.2, 1.4, 0.0})},
   Check{"at rest the arm points along +X: the elbow is 0.3 m out",
     close3(head(rest(), 2), V.V3{0.5, 1.4, 0.0})},
   Check{"at rest the hand is 0.55 m out",
     close3(head(rest(), 4), V.V3{0.75, 1.4, 0.0})},
   Check{"a child follows its parent: the twist bone is on the forearm",
     close3(head(rest(), 3), V.V3{0.62, 1.4, 0.0})},
   Check{"bending the forearm up lifts the hand above the elbow",
     close3(head(bent(), 4), V.V3{0.5, 1.65, 0.0})},
   Check{"bending the forearm leaves the elbow where it was",
     close3(head(bent(), 2), V.V3{0.5, 1.4, 0.0})}]
