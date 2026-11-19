# Numerical tests of engine/locomotion.bend on the Character project's arm.

import Base
import ../engine/vec.bend as V
import ../engine/transform.bend as Tr
import ../engine/scene.bend as S
import ../engine/figure.bend as Fig
import ../engine/locomotion.bend as Loco
import ../projects/character/scene.bend as Ch

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.001)

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

def place(+s: S.Scene) -> Tr.Transform:
  S.place(S.at(s, 0))

def speed(+s: S.Scene) -> F32:
  Fig.param(S.figure(S.look(S.at(s, 0))), "speed")

def step(+s: S.Scene, +f: U32, +t: U32) -> S.Scene:
  Loco.drive(s, Loco.input(f, t), 0.0, True{})

# n frames of Run, 0.1 s each, with the same keys held.
def run(fuel: Nat, +s: S.Scene, +f: U32, +t: U32) -> S.Scene:
  match fuel:
    case 0n:
      s
    case 1n+k:
      run(k, Loco.drive(s, Loco.input(f, t), 0.1, False{}), f, t)

def start() -> S.Scene:
  Ch.start()

def checks() -> List<&2, Check>:
  [Check{"one step ahead moves the character 0.65 m along its +Z",
     close3(Tr.position(place(step(start(), 1, 0))), V.V3{0.0, 0.0, 0.65})},
   Check{"one step back moves it 0.65 m the other way",
     close3(Tr.position(place(step(start(), 2, 0))), V.V3{0.0, 0.0, (0.0 - 0.65 : F32)})},
   Check{"four turns left face the character's +X",
     close(Loco.heading(place(step(step(step(step(start(), 0, 1), 0, 1), 0, 1), 0, 1))), 1.5707964)},
   Check{"after a quarter turn left, a step goes along +X",
     close3(Tr.position(place(step(step(step(step(step(start(), 0, 1), 0, 1), 0, 1), 0, 1), 1, 0))), V.V3{0.65, 0.0, 0.0})},
   Check{"a step does not change the animation's speed (Step stands still)",
     close(speed(step(start(), 1, 0)), 0.0)},
   Check{"holding ahead for a second reaches the walk's speed, 1.3 m/s",
     close(speed(run(10n, start(), 1, 0)), 1.3)},
   Check{"letting go for a second slows the character to a stop",
     close(speed(run(10n, run(10n, start(), 1, 0), 0, 0)), 0.0)},
   Check{"holding ahead moves the character forward, never sideways",
     close(V.x(Tr.position(place(run(10n, start(), 1, 0)))), 0.0)}]
