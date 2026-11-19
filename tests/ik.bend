# Numerical tests of engine/ik.bend on the test arm: shoulder (bone 1),
# elbow (bone 2), hand (bone 4).

import Base
import ../engine/vec.bend as V
import ../engine/skeleton.bend as Sk
import ../engine/pose.bend as P
import ../engine/ik.bend as IK
import ../projects/character/arm.bend as Arm

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.001)

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

def head(+p: P.Pose, +i: U32) -> V.V3:
  P.head(P.m4_at(P.model(Arm.skeleton(), p), i))

def reach(+target: V.V3) -> P.Pose:
  IK.two_bone(Arm.skeleton(), P.rest(Arm.skeleton()), 1, 2, 4, target)

def near() -> V.V3: V.V3{0.5, 1.2, 0.2}
def far() -> V.V3: V.V3{2.0, 1.4, 0.0}

def checks() -> List<&2, Check>:
  [Check{"the hand reaches a target within reach",
     close3(head(reach(near()), 4), near())},
   Check{"the shoulder stays where it was",
     close3(head(reach(near()), 1), V.V3{0.2, 1.4, 0.0})},
   Check{"the upper arm keeps its length (0.3 m)",
     close(IK.len(V.sub(head(reach(near()), 2), head(reach(near()), 1))), 0.3)},
   Check{"the forearm keeps its length (0.25 m)",
     close(IK.len(V.sub(head(reach(near()), 4), head(reach(near()), 2))), 0.25)},
   Check{"a target out of reach stretches the arm straight toward it",
     close3(head(reach(far()), 4), V.V3{0.75, 1.4, 0.0})},
   Check{"solving again for the same target changes nothing",
     close3(head(IK.two_bone(Arm.skeleton(), reach(near()), 1, 2, 4, near()), 2), head(reach(near()), 2))}]
