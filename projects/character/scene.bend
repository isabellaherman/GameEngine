# The Character project: a clean place to build and test the engine's
# animation system, one step at a time.
#
# This is content. It uses only the engine's own test character, a short
# arm written by hand (arm.bend). The reference character lives in refs/
# and is never imported from here: refs/ is not part of the engine and
# never ships.
#
# Limits now:
# - The arm has no skin: it is drawn as lines, one per bone, colored by
#   role (engine/pose.bend).

import Base
import ../../engine/scene.bend as S
import ../../engine/transform.bend as Tr
import ../../engine/figure.bend as Fig
import ./arm.bend as Arm

def start() -> S.Scene:
  S.Scene{[
    S.Thing{"Arm", Tr.identity(), S.Rigged{Fig.make(Arm.skeleton(), "", Arm.rules())}}]}
