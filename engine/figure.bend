# Figure: the component that makes a thing a character.
#
# A figure has a skeleton (engine/skeleton.bend), the skin drawn over it
# (the path of a mesh file the browser loads, or "" for bones only), and
# its animation parameters: named numbers the editor shows in the Details
# panel (time, speed…), stored like a material's values so the same panel
# code shows and edits them.
#
# The pose a figure takes is a pure function of the figure (its skeleton
# and parameters): nothing about animation is hidden in state. That is what
# lets a networked game rebuild any character's pose from a few numbers.
#
# Limits now:
# - The skin is a path, read by main.js; the mesh itself never passes
#   through Bend (too many numbers). Its laws are checked when it is made
#   (tools/gltf.ts) and by tests.
# - No parameters yet: the pose is the rest pose.

import Base
import ./skeleton.bend as Sk
import ./pose.bend as P
import ./material.bend as Mat
import ./transform.bend as Tr

type Figure is Data:
  Figure{skeleton: Sk.Skeleton, skin: String, params: List<&2, Mat.Value>}

def skeleton(f: Figure) -> Sk.Skeleton:
  Figure{s, _, _} = f
  s

def skin(f: Figure) -> String:
  Figure{_, k, _} = f
  k

def params(f: Figure) -> List<&2, Mat.Value>:
  Figure{_, _, ps} = f
  ps

def with_params(f: Figure, ps: List<&2, Mat.Value>) -> Figure:
  Figure{s, k, _} = f
  Figure{s, k, ps}

# The pose the figure takes now.
def pose(f: Figure) -> P.Pose:
  P.rest(skeleton(f))

# The figure's bones as lines in the World (6 floats per end), standing
# where `place` puts it.
def lines(+f: Figure, +place: Tr.Transform) -> List<&2, F32>:
  P.lines(skeleton(f), pose(f), place)
