import Base
import ./vec3.bend as V

type Sphere is Data:
  Sphere{center: V.Vec3, radius: F32}

def positive(+near: F32, +far: F32) -> F32:
  Bool.pick(F32, F32.is_gt(near, 0.001), near,
    Bool.pick(F32, F32.is_gt(far, 0.001), far, F32.neg(1.0)))

def roots(hit: Bool, b: F32, discriminant: F32) -> F32:
  match hit:
    case False{}:
      F32.neg(1.0)
    case True{}:
      +root = F32.sqrt(discriminant)
      +base = F32.neg(b)
      positive((base - root : F32), (base + root : F32))

# A direção deve estar normalizada. Retorna F32.neg(1.0) quando não há interseção.
def intersect(sphere: Sphere, origin: V.Vec3, direction: V.Vec3) -> F32:
  Sphere{center, +radius} = sphere
  +offset = V.sub(origin, center)
  +b = V.dot(offset, direction)
  c = (V.dot(offset, offset) - radius * radius : F32)
  +disc = (b * b - c : F32)
  roots(F32.is_ge(disc, 0.0), b, disc)

def unit() -> Sphere:
  Sphere{V.Vec3{0.0, 0.0, 0.0}, 1.0}
