# The projects this engine knows, and the one it opens.
#
# A project is a folder in projects/ with a scene.bend whose start() gives
# the scene the editor opens with. The engine (engine/) and the editor
# (editor/) are shared by every project.
#
# Why a written list and not "every folder in projects/": a Bend import is
# fixed, and a project nobody imports does not exist for the compiler. The
# gain: one law checks every project's first scene at once, and adding a
# project makes the compiler point at every match below that misses it.
#
# Limits now:
# - Which project opens is this file's open(); there is no project picker
#   in the editor.
# - The build (bun run build) bundles every project listed here. Nothing
#   from refs/ may ever be listed: refs/ holds third-party reference assets
#   that never ship (tools/check.ts fails if anything outside refs/ imports
#   from it).

import Base
import ./engine/scene.bend as S
import ./engine/camera.bend as Cam
import ./projects/water/scene.bend as WaterScene
import ./projects/character/scene.bend as CharacterScene

type Project is Data:
  Water{}
  Character{}

# Which project opens. Change this one line.
def open() -> Project: Character{}

def name(p: Project) -> String:
  match p:
    case Water{}:
      "Water"
    case Character{}:
      "Character"

def start(p: Project) -> S.Scene:
  match p:
    case Water{}:
      WaterScene.start()
    case Character{}:
      CharacterScene.start()

# The scene the editor opens with.
def opening() -> S.Scene:
  start(open())

# Where the editor's camera starts: the whole Water, or a person up close.
def camera(p: Project) -> Cam.Cam:
  match p:
    case Water{}:
      Cam.start()
    case Character{}:
      Cam.close_up()

def opening_camera() -> Cam.Cam:
  camera(open())
