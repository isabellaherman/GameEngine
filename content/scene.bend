# The scene the engine opens with: every thing in the World, in order.
#
# This is content. The types (Scene, Thing, Look) are engine code, in
# engine/scene.bend. A scene is a Bend value, so a saved scene is a .bend
# file like this one, and the laws check it like any other code.
#
# Limits now:
# - One scene, written by hand. Loading another, or saving changes made in
#   the editor back to this file, does not exist yet.
# - The editor shows things in this order; there is no other id.

import Base
import ../engine/scene.bend as S
import ../engine/transform.bend as Tr
import ./water.bend as Water

def start() -> S.Scene:
  S.Scene{[
    S.Thing{"Water", Tr.identity(), S.Shown{Water.shape(), Water.material()}}]}
