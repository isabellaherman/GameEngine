# The engine's own test character: a left arm, written by hand.
#
# Eight bones, one of each role but Chain, laid out like the reference rig's
# arm: shoulder → upper arm → forearm → hand → two index segments, with a twist bone halfway
# down the forearm and a support bone at the elbow. It lets every
# animation step be tested without the reference rig (refs/), which never
# ships.
#
# Bones point along their own +Y, as in Blender and glTF: a child sits at
# (0, length, 0) of its parent. The upper arm is turned a quarter around Z,
# so the arm points along the World's +X at shoulder height.
#
# Limits now:
# - No mesh: the arm is drawn as lines.

import Base
import ../../engine/vec.bend as V
import ../../engine/quat.bend as Q
import ../../engine/transform.bend as Tr
import ../../engine/skeleton.bend as Sk
import ../../engine/helpers.bend as H

def along(+y: F32) -> Tr.Transform:
  Tr.at(V.V3{0.0, y, 0.0})

def skeleton() -> Sk.Skeleton:
  Sk.Skeleton{[
    Sk.Bone{"root", "root", Sk.Root{}, 0, Tr.identity(), 0.0},
    Sk.Bone{"upper arm", "upper_arm.L", Sk.Deform{}, 0,
      Tr.Transform{V.V3{0.2, 1.4, 0.0}, Q.axis_angle(V.V3{0.0, 0.0, 1.0}, (0.0 - 1.5707964 : F32)), V.V3{1.0, 1.0, 1.0}}, 0.3},
    Sk.Bone{"forearm", "lower_arm.L", Sk.Deform{}, 1, along(0.3), 0.25},
    Sk.Bone{"forearm twist", "", Sk.Twist{}, 2, along(0.12), 0.08},
    Sk.Bone{"hand", "hand.L", Sk.Deform{}, 2, along(0.25), 0.1},
    Sk.Bone{"elbow fix", "", Sk.Support{}, 1, along(0.3), 0.06},
    Sk.Bone{"index 1", "index_1.L", Sk.Deform{}, 4, along(0.1), 0.04},
    Sk.Bone{"index 2", "index_2.L", Sk.Deform{}, 6, along(0.04), 0.03}]}

# The helpers' rules: the forearm twist takes half the hand's roll, and the
# elbow support turns half as much as the elbow bends.
def rules() -> List<&2, H.Rule>:
  [H.Rule{3, 4, H.Roll{}, 0.5},
   H.Rule{5, 2, H.Full{}, 0.5}]
