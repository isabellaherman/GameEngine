import Base
import ./engine/camera.bend as C
import ./engine/editor.bend as E
import ./engine/ui.bend as U

# px, py: onde o mouse está (-1, -1 fora da janela), para o hover.
# selected: o objeto da cena mostrado no Inspector (0 Camera, 1 Light, 2 Sphere, 3 Floor).
type State is Data:
  State{angle: F32, paused: Bool, time: Nat, px: F32, py: F32, selected: U32,
    palette: U.Palette}

def view(state: State) -> State & Image:
  State{+angle, +paused, time, +px, +py, +selected, +palette} = state
  ui = {U.Ui{palette, paused, U.hit(px, py), selected, angle} : U.Ui}
  (State{angle, paused, time, px, py, selected, palette}, E.frame(ui, C.orbit(angle)))

def advance(paused: Bool, angle: F32, dt: F32) -> F32:
  match paused:
    case True{}:
      angle
    case False{}:
      ((angle + dt * 0.35) % 6.2831853 : F32)

def reset_angle() -> F32: 0.45

# Um clique em: 1 play/pause, 2 reset, 10 + k a linha k do outline; 0 nada.
def click(target: U32, state: State) -> State:
  State{angle, paused, time, px, py, selected, palette} = state
  +t = target
  +p = paused
  State{Bool.pick(F32, U32.is_eq(t, 2), reset_angle(), angle),
    Bool.pick(Bool, U32.is_eq(t, 1), Bool.not(p), p), time, px, py,
    Bool.pick(U32, U32.is_ge(t, 10), (t - 10 : U32), selected), palette}

def point(x: F32, y: F32, state: State) -> State:
  State{angle, paused, time, _, _, selected, palette} = state
  State{angle, paused, time, x, y, selected, palette}

def tick(events: List<Event>, state: State) -> IO(Maybe<State>):
  match events:
    case Nil{}:
      State{angle, +paused, previous, px, py, selected, palette} = state
      do IO<Maybe<State>>:
        now : Nat <- IO.now()
        +current : Nat = now
        dt : F32 = F32.min((F32.from_nat(Nat.sub(current, previous)) / 1000.0 : F32), 0.1)
        return Some{State{advance(paused, angle, dt), paused, current, px, py, selected,
          palette}}
    case Con{Close{}, _}:
      IO.pure(Maybe<State>, None{})
    case Con{Key{27, True{}}, _}:
      IO.pure(Maybe<State>, None{})
    case Con{Key{32, True{}}, rest}:
      tick(rest, click(1, state))
    case Con{Key{114, True{}}, rest}:
      tick(rest, click(2, state))
    case Con{Move{_, _, x, y, _}, rest}:
      tick(rest, point(x, y, state))
    case Con{Leave{_}, rest}:
      tick(rest, point(F32.neg(1.0), F32.neg(1.0), state))
    case Con{Press{_, _, +x, +y, _, 0, True{}}, rest}:
      tick(rest, click(U.hit(x, y), point(x, y, state)))
    case Con{_, rest}:
      tick(rest, state)

def main() -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    App.run(~State, ~App{view, tick},
      "Bend GameEngine | Scene", U.width(), U.height(),
      State{reset_angle(), True{}, start, F32.neg(1.0), F32.neg(1.0), 2, U.palette()})
