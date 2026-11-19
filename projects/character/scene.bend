# The Character project: a clean place to build and test the engine's
# animation system, one step at a time (see docs in the GameEngine Docs
# project, "Animation").
#
# This is content. It uses only the engine's own test character (a short
# arm written by hand, added with the skeleton). The reference character
# lives in refs/ and is never imported from here: refs/ is not part of the
# engine and never ships.
#
# Limits now:
# - The scene is empty: the first thing in it comes with engine/skeleton.bend.

import Base
import ../../engine/scene.bend as S

def start() -> S.Scene:
  S.Scene{Nil{}}
