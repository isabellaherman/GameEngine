# Scene: everything that exists in the World, as one value.
#
# The engine's object model is data-oriented, the ECS way (see the study
# "Objetos no mundo"): a thing is only data, its parts are components, and
# what things do will be pure functions that take the scene and give back
# the next one. Nothing in a thing points at another thing, and nothing is
# changed in place, which is how Bend works and what lets it run independent
# things in parallel.
#
# A thing has:
# - a name, shown in the editor (the Outliner);
# - a place (engine/transform.bend): where it is, how it is turned, its size;
# - a look: Shown with a shape (a mesh) and a material, or Hidden for a
#   thing that is not drawn.
#
# This file is engine code: the types every scene uses. A real scene, with
# its things, is content and lives in content/ (content/scene.bend).
#
# Limits now:
# - The scene is a plain list of things. That is enough for a few things;
#   with many, storing each component in its own column (full ECS) is an
#   internal change that leaves this file's meaning the same.
# - No behaviors yet: nothing moves by itself, so there is no frame(scene,
#   time) → scene function. It comes with the first thing that moves (the
#   water's waves are in its material, on the GPU, and need none).
# - No parent and child: every place is measured from the World's origin.
# - A thing has no id but its place in the list. Two things may share a
#   name; the editor tells them apart by place, so reordering the list
#   changes which is which.
# - "Thing" is a working name. It shows in the editor, so it can still
#   change (Entity, Actor, Object…).

import Base
import ./mesh.bend as M
import ./material.bend as Mat
import ./transform.bend as Tr
import ./shader/node.bend as N

type Look is Data:
  Hidden{}
  Shown{shape: M.Mesh, material: Mat.Material}

type Thing is Data:
  Thing{name: String, place: Tr.Transform, look: Look}

type Scene is Data:
  Scene{things: List<&2, Thing>}

def things(s: Scene) -> List<&2, Thing>:
  Scene{xs} = s
  xs

def name(t: Thing) -> String:
  Thing{n, _, _} = t
  n

def place(t: Thing) -> Tr.Transform:
  Thing{_, p, _} = t
  p

def look(t: Thing) -> Look:
  Thing{_, _, l} = t
  l

# Is the thing drawn? (main.js asks before it reads the shape and material.)
def is_shown(t: Thing) -> Bool:
  Thing{_, _, l} = t
  match l:
    case Shown{_, _}:
      True{}
    case Hidden{}:
      False{}

def shape(l: Look) -> M.Mesh:
  match l:
    case Shown{s, _}:
      s
    case Hidden{}:
      M.Mesh{Nil{}, Nil{}}

def material(l: Look) -> Mat.Material:
  match l:
    case Shown{_, m}:
      m
    case Hidden{}:
      Mat.Material{N.Rgb{0.0, 0.0, 0.0}, Nil{}}

def pick_thing(c: Bool, a: Thing, b: Thing) -> Thing:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_list(c: Bool, a: List<&2, Thing>, b: List<&2, Thing>) -> List<&2, Thing>:
  match c:
    case True{}:
      a
    case False{}:
      b

# Thing i of a list (the first is 0). Past the end: a hidden thing with no
# name, so a wrong index never breaks the editor.
def at_go(xs: List<&2, Thing>, +i: U32) -> Thing:
  match xs:
    case Nil{}:
      Thing{"", Tr.identity(), Hidden{}}
    case +h <> +t:
      pick_thing(U32.is_eq(i, 0), h, at_go(t, (i - 1 : U32)))

def at(s: Scene, +i: U32) -> Thing:
  Scene{xs} = s
  at_go(xs, i)

# The same list with thing i replaced. Past the end, nothing changes.
def put_go(xs: List<&2, Thing>, +i: U32, +x: Thing) -> List<&2, Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      pick_list(U32.is_eq(i, 0), x <> t, h <> put_go(t, (i - 1 : U32), x))

def put(s: Scene, +i: U32, +x: Thing) -> Scene:
  Scene{xs} = s
  Scene{put_go(xs, i, x)}

def count(s: Scene) -> Nat:
  Scene{xs} = s
  List.length(&2, Thing, xs)

# Every drawn thing's material has a value for each of its parameters.
def complete_look(l: Look) -> Bool:
  match l:
    case Shown{_, m}:
      Mat.complete(m)
    case Hidden{}:
      True{}

def all_complete(xs: List<&2, Thing>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      (complete_look(look(h)) && all_complete(t))

def complete(s: Scene) -> Bool:
  Scene{xs} = s
  all_complete(xs)
