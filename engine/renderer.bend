import Base
import ./vec3.bend as V
import ./camera.bend as C
import ./sphere.bend as S

def channel(v: F32) -> U32:
  F32.to_u32((F32.sqrt(F32.clamp(v, 0.0, 1.0)) * 255.0 : F32))

# A janela nativa lê cores no formato 0xRRGGBB; gamma aproximado de 2.0.
def rgb(r: F32, g: F32, b: F32) -> U32:
  ((channel(r) << 16n) .|. (channel(g) << 8n) .|. channel(b) : U32)

# Direção (normalizada) da luz; o Inspector mostra este mesmo valor.
def light() -> V.Vec3:
  V.Vec3{F32.neg(0.43643578), 0.87287156, 0.21821789}

# Altura do piso; o Inspector mostra este mesmo valor.
def floor_y() -> F32:
  F32.neg(1.05)

def sky(direction: V.Vec3) -> U32:
  V.Vec3{_, +y, _} = direction
  +t = F32.clamp((0.5 + y * 0.5 : F32), 0.0, 1.0)
  rgb((0.018 + t * 0.035 : F32), (0.027 + t * 0.050 : F32),
    (0.055 + t * 0.080 : F32))

def sphere_color(+point: V.Vec3, direction: V.Vec3) -> U32:
  +normal = V.normalize(point)
  +view = V.scale(direction, F32.neg(1.0))
  diffuse = F32.max(V.dot(normal, light()), 0.0)
  half = V.normalize(V.add(light(), view))
  spec = F32.pow(F32.max(V.dot(normal, half), 0.0), 64.0)
  rim = F32.pow((1.0 - F32.max(V.dot(normal, view), 0.0) : F32), 4.0)
  +brightness = (0.13 + 0.87 * diffuse : F32)
  +highlight = (0.75 * spec : F32)
  +edge = (0.18 * rim : F32)
  rgb((0.025 * brightness + highlight + edge * 0.3 : F32),
    (0.46 * brightness + highlight + edge : F32),
    (0.60 * brightness + highlight + edge : F32))

def floor_color(+point: V.Vec3, +distance: F32) -> U32:
  V.Vec3{+x, _, +z} = point
  ix = F32.to_u32(F32.floor((x + 1024.0 : F32)))
  iz = F32.to_u32(F32.floor((z + 1024.0 : F32)))
  checker = U32.is_eq(((ix + iz) .&. 1 : U32), 0)
  base = Bool.pick(F32, checker, 0.105, 0.17)
  shadow_ray = S.intersect(S.unit(), V.add(point, V.Vec3{0.0, 0.005, 0.0}), light())
  shadow = Bool.pick(F32, F32.is_gt(shadow_ray, 0.0), 0.25, 1.0)
  contact = (1.0 - 0.38 * F32.exp((0.0 - (x * x + z * z) * 1.4 : F32)) : F32)
  +lit = (base * shadow * contact : F32)
  +fog = F32.clamp((distance * 0.025 : F32), 0.0, 1.0)
  rgb(F32.lerp((lit * 0.75 : F32), 0.035, fog),
    F32.lerp((lit * 0.85 : F32), 0.05, fog), F32.lerp(lit, 0.085, fog))

def ground_hit(hit: Bool, origin: V.Vec3, direction: V.Vec3, +distance: F32) -> U32:
  match hit:
    case True{}:
      floor_color(V.add(origin, V.scale(direction, distance)), distance)
    case False{}:
      sky(direction)

def ground_facing(down: Bool, +origin: V.Vec3, +direction: V.Vec3) -> U32:
  match down:
    case False{}:
      sky(direction)
    case True{}:
      V.Vec3{_, oy, _} = origin
      V.Vec3{_, dy, _} = direction
      +distance = ((floor_y() - oy) / dy : F32)
      ground_hit(F32.is_gt(distance, 0.001), origin, direction, distance)

def surface(hit: Bool, +origin: V.Vec3, +direction: V.Vec3, +distance: F32) -> U32:
  match hit:
    case True{}:
      sphere_color(V.add(origin, V.scale(direction, distance)), direction)
    case False{}:
      V.Vec3{_, +dy, _} = direction
      ground_facing(F32.is_lt(dy, F32.neg(0.0001)), origin, direction)

def ray_pixel(ray: V.Vec3 & V.Vec3) -> U32:
  (+origin, +direction) = ray
  +distance = S.intersect(S.unit(), origin, direction)
  surface(F32.is_gt(distance, 0.0), origin, direction, distance)

# A cor do pixel (x, y) da viewport de 512 x 512.
def scene(camera: C.Camera, x: U32, y: U32) -> U32:
  ray_pixel(C.ray(camera, x, y))
