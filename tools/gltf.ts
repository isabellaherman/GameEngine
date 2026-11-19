// The glTF importer: reads a character (.glb) and writes it in the engine's
// rig standard (engine/skeleton.bend).
//
//   bun tools/gltf.ts <character.glb> <rig.json> <out dir>
//
// It writes five files into <out dir>:
// - skeleton.bend  the skeleton as a Bend value: def skeleton() -> Sk.Skeleton.
//                  `bun run check` and the laws read it like any Bend code.
// - rules.bend     one rule per Twist and Support bone (engine/helpers.bend),
//                  from rig.json's rules.
// - weights.bend   every vertex's 4 joints and 4 weights again, as Bend, so
//                  the laws can check them (engine/skin.bend).
// - skin.bin + skin.json  the mesh: positions, normals, UVs, 4 joints and
//                  4 weights per vertex, and triangles. Too many numbers to
//                  pass through Bend each frame; main.js hands them to the GPU.
//
// rig.json says how to read this rig (see refs/sora/rig.json):
// - drop     nodes that are not bones of the character (scene roots, sockets)
// - parents  new parents (a loose spine hung from the hips; "root" is the
//            root bone this importer creates on the ground)
// - slots    the engine's humanoid slot of each bone ("*" = both sides:
//            "*te" means "L te" → hand.L and "R te" → hand.R)
// - roles    patterns that decide Twist, Support and Chain; a bone with a
//            slot is Deform
//
// The importer is the gate of the rig standard. It fixes what it can and
// refuses the rest:
// - creates one root at index 0, on the ground, and hangs every loose bone
//   from it (or from the bone rig.json names);
// - orders bones so every parent comes before its children, and rewrites
//   every vertex's joint indices to match;
// - drops the "_end" tips, keeping their distance as the bone's length;
// - stores each vertex's 4 weights as 16-bit integers that sum to exactly
//   65535, giving the rounding remainder to the largest;
// - refuses a vertex with no weight, a weight on a dropped bone, more than 4
//   influences, or a bone it cannot give a role.
//
// Limits now:
// - Reads only what the reference needs: one skin, triangle lists,
//   JOINTS_0 and WEIGHTS_0 (the first 4 influences, as glTF allows),
//   no animations, no morph targets, no textures (the page that shows the
//   character passes its texture files to the editor).
// - Reading only JOINTS_0/WEIGHTS_0 means a file with more than 4
//   influences per vertex silently loses the rest; the "more than 4" check
//   can only fire once JOINTS_1 is read.
// - The rest pose must have scale 1 (within 0.001): the engine inverts rest
//   matrices as rotation + translation (engine/skin.bend).

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

type M = number[]; // 4×4, column-major

const [glbPath, rigPath, outDir] = process.argv.slice(2);
if (!glbPath || !rigPath || !outDir) {
  console.error("usage: bun tools/gltf.ts <character.glb> <rig.json> <out dir>");
  process.exit(1);
}

// Reading the file
// ================

const glb = readFileSync(glbPath);
const jsonLen = glb.readUInt32LE(12);
const gltf = JSON.parse(glb.subarray(20, 20 + jsonLen).toString("utf8"));
const binStart = 20 + jsonLen + 8;
const bin = glb.subarray(binStart);
const rig = JSON.parse(readFileSync(rigPath, "utf8"));

const SIZE: Record<number, number> = { 5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4 };
const COMPONENTS: Record<string, number> = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };

// An accessor as rows of numbers.
function read(index: number): number[][] {
  const a = gltf.accessors[index];
  const v = gltf.bufferViews[a.bufferView];
  const n = COMPONENTS[a.type], size = SIZE[a.componentType];
  const stride = v.byteStride || n * size;
  const base = (v.byteOffset || 0) + (a.byteOffset || 0);
  const rows: number[][] = [];
  for (let i = 0; i < a.count; i++) {
    const row: number[] = [];
    for (let k = 0; k < n; k++) {
      const at = base + i * stride + k * size;
      switch (a.componentType) {
        case 5126: row.push(bin.readFloatLE(at)); break;
        case 5125: row.push(bin.readUInt32LE(at)); break;
        case 5123: row.push(bin.readUInt16LE(at)); break;
        case 5121: row.push(bin.readUInt8(at)); break;
        default: throw new Error(`component type ${a.componentType} not read`);
      }
    }
    rows.push(row);
  }
  return rows;
}

// Matrices
// ========

function mul(a: M, b: M): M {
  const o = new Array(16).fill(0);
  for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++)
    for (let k = 0; k < 4; k++) o[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k];
  return o;
}

function compose(t = [0, 0, 0], q = [0, 0, 0, 1], s = [1, 1, 1]): M {
  const [x, y, z, w] = q;
  return [
    (1 - 2 * (y * y + z * z)) * s[0], 2 * (x * y + w * z) * s[0], 2 * (x * z - w * y) * s[0], 0,
    2 * (x * y - w * z) * s[1], (1 - 2 * (x * x + z * z)) * s[1], 2 * (y * z + w * x) * s[1], 0,
    2 * (x * z + w * y) * s[2], 2 * (y * z - w * x) * s[2], (1 - 2 * (x * x + y * y)) * s[2], 0,
    t[0], t[1], t[2], 1,
  ];
}

function invert(m: M): M {
  // General 4×4 inverse (cofactors).
  const inv = new Array(16);
  const [a00, a01, a02, a03, a10, a11, a12, a13, a20, a21, a22, a23, a30, a31, a32, a33] = m;
  const b00 = a00 * a11 - a01 * a10, b01 = a00 * a12 - a02 * a10, b02 = a00 * a13 - a03 * a10;
  const b03 = a01 * a12 - a02 * a11, b04 = a01 * a13 - a03 * a11, b05 = a02 * a13 - a03 * a12;
  const b06 = a20 * a31 - a21 * a30, b07 = a20 * a32 - a22 * a30, b08 = a20 * a33 - a23 * a30;
  const b09 = a21 * a32 - a22 * a31, b10 = a21 * a33 - a23 * a31, b11 = a22 * a33 - a23 * a32;
  const det = 1 / (b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06);
  inv[0] = (a11 * b11 - a12 * b10 + a13 * b09) * det; inv[1] = (a02 * b10 - a01 * b11 - a03 * b09) * det;
  inv[2] = (a31 * b05 - a32 * b04 + a33 * b03) * det; inv[3] = (a22 * b04 - a21 * b05 - a23 * b03) * det;
  inv[4] = (a12 * b08 - a10 * b11 - a13 * b07) * det; inv[5] = (a00 * b11 - a02 * b08 + a03 * b07) * det;
  inv[6] = (a32 * b02 - a30 * b05 - a33 * b01) * det; inv[7] = (a20 * b05 - a22 * b02 + a23 * b01) * det;
  inv[8] = (a10 * b10 - a11 * b08 + a13 * b06) * det; inv[9] = (a01 * b08 - a00 * b10 - a03 * b06) * det;
  inv[10] = (a30 * b04 - a31 * b02 + a33 * b00) * det; inv[11] = (a21 * b02 - a20 * b04 - a23 * b00) * det;
  inv[12] = (a11 * b07 - a10 * b09 - a12 * b06) * det; inv[13] = (a00 * b09 - a01 * b07 + a02 * b06) * det;
  inv[14] = (a31 * b01 - a30 * b03 - a32 * b00) * det; inv[15] = (a20 * b03 - a21 * b01 + a22 * b00) * det;
  return inv;
}

// Translation, rotation (quaternion), scale of a matrix without shear.
function decompose(m: M) {
  const t = [m[12], m[13], m[14]];
  const s = [Math.hypot(m[0], m[1], m[2]), Math.hypot(m[4], m[5], m[6]), Math.hypot(m[8], m[9], m[10])];
  const r = [m[0] / s[0], m[1] / s[0], m[2] / s[0], m[4] / s[1], m[5] / s[1], m[6] / s[1], m[8] / s[2], m[9] / s[2], m[10] / s[2]];
  // r is column-major 3×3: r[c*3 + row]
  const R = (row: number, c: number) => r[c * 3 + row];
  const tr = R(0, 0) + R(1, 1) + R(2, 2);
  let q: number[];
  if (tr > 0) {
    const S = Math.sqrt(tr + 1) * 2;
    q = [(R(2, 1) - R(1, 2)) / S, (R(0, 2) - R(2, 0)) / S, (R(1, 0) - R(0, 1)) / S, 0.25 * S];
  } else if (R(0, 0) > R(1, 1) && R(0, 0) > R(2, 2)) {
    const S = Math.sqrt(1 + R(0, 0) - R(1, 1) - R(2, 2)) * 2;
    q = [0.25 * S, (R(0, 1) + R(1, 0)) / S, (R(0, 2) + R(2, 0)) / S, (R(2, 1) - R(1, 2)) / S];
  } else if (R(1, 1) > R(2, 2)) {
    const S = Math.sqrt(1 + R(1, 1) - R(0, 0) - R(2, 2)) * 2;
    q = [(R(0, 1) + R(1, 0)) / S, 0.25 * S, (R(1, 2) + R(2, 1)) / S, (R(0, 2) - R(2, 0)) / S];
  } else {
    const S = Math.sqrt(1 + R(2, 2) - R(0, 0) - R(1, 1)) * 2;
    q = [(R(0, 2) + R(2, 0)) / S, (R(1, 2) + R(2, 1)) / S, 0.25 * S, (R(1, 0) - R(0, 1)) / S];
  }
  const n = Math.hypot(...q);
  return { t, q: q.map((x) => x / n), s };
}

const IDENTITY = compose();

// The node tree
// =============

const nodes: any[] = gltf.nodes;
const parentOf = new Map<number, number>();
nodes.forEach((n, i) => (n.children || []).forEach((c: number) => parentOf.set(c, i)));
const global = new Map<number, M>();
function globalOf(i: number): M {
  if (global.has(i)) return global.get(i)!;
  const n = nodes[i];
  const local = n.matrix || compose(n.translation, n.rotation, n.scale);
  const p = parentOf.get(i);
  const g = p === undefined ? local : mul(globalOf(p), local);
  global.set(i, g);
  return g;
}

if (gltf.skins.length !== 1) throw new Error("expected one skin");
const skin = gltf.skins[0];
const jointNodes: number[] = skin.joints;
const isJoint = new Set(jointNodes);
const byName = new Map<string, number>();
nodes.forEach((n, i) => byName.set(n.name, i));

// Which bones stay, and their roles and slots
// ===========================================

const drop = new Set<string>(rig.drop);
const isTip = (name: string) => name.endsWith("_end");
const kept = jointNodes.filter((j) => !drop.has(nodes[j].name) && !isTip(nodes[j].name));

function slotOf(name: string): string {
  if (rig.slots[name]) return rig.slots[name];
  const side = name.match(/^([LR]) (.*)$/);
  if (side && rig.slots["*" + side[2]]) return `${rig.slots["*" + side[2]]}.${side[1]}`;
  return "";
}

function roleOf(name: string, slot: string): string {
  if (slot) return "Deform";
  for (const r of rig.roles) if (new RegExp(r.match).test(name)) return r.role;
  throw new Error(`no role for bone "${name}": add a slot or a role pattern to rig.json`);
}

// New parents: the bone's nearest kept ancestor, unless rig.json says otherwise.
function keptParent(j: number): string {
  const name = nodes[j].name;
  if (rig.parents[name]) return rig.parents[name];
  for (let p = parentOf.get(j); p !== undefined; p = parentOf.get(p)) {
    if (kept.includes(p)) return nodes[p].name;
    if (!isJoint.has(p) || drop.has(nodes[p].name)) break;
  }
  return "root";
}

type Bone = { name: string; source: number; slot: string; role: string; parent: string; global: M };
const bones = new Map<string, Bone>();
bones.set("root", { name: "root", source: -1, slot: "root", role: "Root", parent: "root", global: IDENTITY });
for (const j of kept) {
  const name = nodes[j].name;
  const slot = slotOf(name);
  bones.set(name, { name, source: j, slot, role: roleOf(name, slot), parent: keptParent(j), global: globalOf(j) });
}

// Order: depth first from the root, children in the file's order.
const children = new Map<string, string[]>();
for (const b of bones.values()) if (b.name !== "root") {
  if (!bones.has(b.parent)) throw new Error(`bone "${b.name}" hangs from "${b.parent}", which is not a bone`);
  children.set(b.parent, [...(children.get(b.parent) || []), b.name]);
}
const order: string[] = [];
(function visit(n: string) { order.push(n); for (const c of children.get(n) || []) visit(c); })("root");
if (order.length !== bones.size) throw new Error("some bones are not reachable from the root");
const index = new Map(order.map((n, i) => [n, i]));

// Length: the distance to the tip (_end) child, else to the first child with
// a slot (the next body bone), else to the farthest child.
function lengthOf(b: Bone): number {
  if (b.source < 0) return 0;
  const kids: number[] = nodes[b.source].children || [];
  const tip = kids.find((c) => isTip(nodes[c].name));
  if (tip !== undefined) return Math.hypot(...(nodes[tip].translation || [0, 0, 0]));
  const dist = (c: number) => Math.hypot(...(nodes[c].translation || [0, 0, 0]));
  const body = kids.find((c) => kept.includes(c) && slotOf(nodes[c].name));
  if (body !== undefined) return dist(body);
  const far = kids.filter((c) => kept.includes(c)).map(dist);
  return far.length ? Math.max(...far, 0.03) : 0.03;
}

// The Deform rule, checked here too so the importer refuses early.
for (const n of order) {
  const b = bones.get(n)!;
  const p = bones.get(b.parent)!;
  if (b.role === "Deform" && !(p.role === "Deform" || p.role === "Root"))
    throw new Error(`Deform bone "${n}" hangs from ${p.role} bone "${p.name}"`);
}

// The rest pose matches the file's bind pose?
const ibm = read(skin.inverseBindMatrices);
let bindError = 0, scaleError = 0;
jointNodes.forEach((j, k) => {
  if (!kept.includes(j)) return;
  const m = mul(globalOf(j), ibm[k]);
  for (let i = 0; i < 16; i++) bindError = Math.max(bindError, Math.abs(m[i] - IDENTITY[i]));
  for (const s of decompose(globalOf(j)).s) scaleError = Math.max(scaleError, Math.abs(s - 1));
});
if (scaleError > 0.001) throw new Error(`rest pose has scale ${scaleError + 1}: the engine needs scale 1`);

// Writing skeleton.bend
// =====================

const num = (x: number) => {
  const v = Math.abs(x) < 5e-7 ? 0 : x;
  const s = Math.abs(v).toFixed(6);
  return v < 0 ? `neg(${s})` : s;
};
const str = (s: string) => JSON.stringify(s);
const lines: string[] = [];
for (const n of order) {
  const b = bones.get(n)!;
  const p = bones.get(b.parent)!;
  const local = n === "root" ? IDENTITY : mul(invert(p.global), b.global);
  const { t, q } = decompose(local);
  const name = b.slot && b.slot !== "root" ? b.slot : b.name;
  lines.push(`    bone(${str(name)}, ${str(b.slot === "root" ? "root" : b.slot)}, Sk.${b.role}{}, ${index.get(b.parent)}, ` +
    `${t.map(num).join(", ")}, ${q.map(num).join(", ")}, ${num(lengthOf(b))})`);
}

const outBend = `# GENERATED by tools/gltf.ts from ${glbPath.split("/").pop()} and rig.json. Do not edit:
# change rig.json and run the importer again.
#
# ${rig.credit}
# Study reference only: refs/ never ships.

import Base
import ../../../engine/vec.bend as V
import ../../../engine/quat.bend as Q
import ../../../engine/transform.bend as Tr
import ../../../engine/skeleton.bend as Sk

def neg(+x: F32) -> F32: (0.0 - x : F32)

def bone(+name: String, +slot: String, +role: Sk.Role, +parent: U32, +x: F32, +y: F32, +z: F32, +qx: F32, +qy: F32, +qz: F32, +qw: F32, +len: F32) -> Sk.Bone:
  Sk.Bone{name, slot, role, parent, Tr.Transform{V.V3{x, y, z}, Q.Q{qx, qy, qz, qw}, V.V3{1.0, 1.0, 1.0}}, len}

def skeleton() -> Sk.Skeleton:
  Sk.Skeleton{[
${lines.join(",\n")}]}
`;

mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "skeleton.bend"), outBend);

// Writing the helper rules
// ========================
// rig.json gives each Twist and Support bone a rule (engine/helpers.bend):
// [part, driver, amount]. "*name" means the same side as the bone.

function ruleFor(name: string): [string, string, number] | null {
  if (rig.rules?.[name]) return rig.rules[name];
  const side = name.match(/^([LR]) (.*)$/);
  if (side && rig.rules?.["*" + side[2]]) {
    const [part, driver, amount] = rig.rules["*" + side[2]];
    return [part, driver.startsWith("*") ? `${side[1]} ${driver.slice(1)}` : driver, amount];
  }
  return null;
}

const ruleLines: string[] = [];
for (const n of order) {
  const b = bones.get(n)!;
  if (b.role !== "Twist" && b.role !== "Support") continue;
  const r = ruleFor(n);
  if (!r) throw new Error(`helper bone "${n}" has no rule: add one to rig.json's rules`);
  const [part, driver, amount] = r;
  if (!index.has(driver)) throw new Error(`rule of "${n}": driver "${driver}" is not a bone`);
  if (bones.get(driver)!.role !== "Deform") throw new Error(`rule of "${n}": driver "${driver}" is not a Deform bone`);
  ruleLines.push(`    H.Rule{${index.get(n)}, ${index.get(driver)}, H.${part}{}, ${num(amount)}}`);
}
writeFileSync(join(outDir, "rules.bend"), `# GENERATED by tools/gltf.ts from rig.json's rules. Do not edit.
# One rule per Twist and Support bone (engine/helpers.bend).
# ${rig.credit}

import Base
import ../../../engine/helpers.bend as H

def neg(+x: F32) -> F32: (0.0 - x : F32)

def rules() -> List<&2, H.Rule>:
  [
${ruleLines.join(",\n")}]
`);

// Writing the skin
// ================

const jointToBone = jointNodes.map((j) => (bones.has(nodes[j].name) ? index.get(nodes[j].name)! : -1));
const STRIDE = 48; // pos 3f, normal 3f, uv 2f, joints 4×u16, weights 4×u16
const parts: { name: string; first: number; count: number }[] = [];
const vertexChunks: Buffer[] = [];
const indexChunks: Buffer[] = [];
let vertexBase = 0, indexBase = 0, fixed = 0;

for (const node of nodes.filter((n) => n.mesh !== undefined && n.skin === 0)) {
  for (const prim of gltf.meshes[node.mesh].primitives) {
    if ((prim.mode ?? 4) !== 4) throw new Error("only triangle lists are read");
    const a = prim.attributes;
    const P = read(a.POSITION), N = read(a.NORMAL), T = read(a.TEXCOORD_0);
    const J = read(a.JOINTS_0), W = read(a.WEIGHTS_0), I = read(prim.indices);
    const buf = Buffer.alloc(P.length * STRIDE);
    for (let v = 0; v < P.length; v++) {
      const o = v * STRIDE;
      [...P[v], ...N[v], ...T[v]].forEach((x, k) => buf.writeFloatLE(x, o + k * 4));
      const pairs = J[v].map((j, k) => ({ bone: jointToBone[j], w: W[v][k] })).filter((p) => p.w > 0);
      if (pairs.length === 0) throw new Error(`vertex ${v} has no weight`);
      if (pairs.length > 4) throw new Error(`vertex ${v} has more than 4 influences`);
      for (const p of pairs) if (p.bone < 0) throw new Error(`vertex ${v} is weighted to a dropped bone`);
      const total = pairs.reduce((s, p) => s + p.w, 0);
      const q = pairs.map((p) => Math.round((p.w / total) * 65535));
      const rest = 65535 - q.reduce((s, x) => s + x, 0);
      if (rest !== 0) fixed++;
      q[q.indexOf(Math.max(...q))] += rest;
      for (let k = 0; k < 4; k++) {
        buf.writeUInt16LE(k < pairs.length ? pairs[k].bone : 0, o + 32 + k * 2);
        buf.writeUInt16LE(k < pairs.length ? q[k] : 0, o + 40 + k * 2);
      }
    }
    vertexChunks.push(buf);
    const ib = Buffer.alloc(I.length * 4);
    I.forEach((row, k) => ib.writeUInt32LE(row[0] + vertexBase, k * 4));
    indexChunks.push(ib);
    parts.push({ name: node.name, first: indexBase, count: I.length });
    vertexBase += P.length;
    indexBase += I.length;
  }
}

const vertexBytes = Buffer.concat(vertexChunks);

// The weights again, as Bend: 8 whole numbers per vertex (4 joints, then
// 4 weights), so the laws can check every vertex (engine/skin.bend).
const ws: number[] = [];
for (let v = 0; v < vertexBase; v++) {
  for (let k = 0; k < 4; k++) ws.push(vertexBytes.readUInt16LE(v * STRIDE + 32 + k * 2));
  for (let k = 0; k < 4; k++) ws.push(vertexBytes.readUInt16LE(v * STRIDE + 40 + k * 2));
}
// In chunks of 256 numbers (32 vertices): one literal of every number is
// too large for the checker to expand.
const CHUNK = 256;
const chunks: string[] = [];
for (let i = 0; i < ws.length; i += CHUNK) chunks.push(`def part_${i / CHUNK}() -> List<&2, U32>:\n  [${ws.slice(i, i + CHUNK).join(", ")}]\n`);
const all = chunks.map((_, k) => `Skin.weights_ok(part_${k}(), bones())`);
writeFileSync(join(outDir, "weights.bend"), `# GENERATED by tools/gltf.ts. Do not edit.
# Every vertex of the skin: 4 joints, then 4 weights (summing to 65535),
# in parts of 32 vertices.
# ${rig.credit}

import Base
import ../../../engine/skin.bend as Skin

def bones() -> U32: ${order.length}

${chunks.join("\n")}
# Every part keeps the weight laws (engine/skin.bend, weights_ok).
def all_ok() -> Bool:
  (${all.join(" &&\n   ")})
`);
const indexBytes = Buffer.concat(indexChunks);
writeFileSync(join(outDir, "skin.bin"), Buffer.concat([vertexBytes, indexBytes]));
writeFileSync(join(outDir, "skin.json"), JSON.stringify({
  generatedBy: "tools/gltf.ts", credit: rig.credit,
  stride: STRIDE, vertices: vertexBase, indices: indexBase, indexOffset: vertexBytes.length,
  layout: { position: 0, normal: 12, uv: 24, joints: 32, weights: 40 },
  bones: order.length, parts, textures: rig.textures || [],
}, null, 2));

const counts: Record<string, number> = {};
for (const b of bones.values()) counts[b.role] = (counts[b.role] || 0) + 1;
console.log(`skeleton: ${order.length} bones ${JSON.stringify(counts)}`);
console.log(`skin: ${vertexBase} vertices, ${indexBase / 3} triangles, ${parts.length} parts; ${fixed} vertices got a rounding fix`);
console.log(`rest pose vs the file's bind pose: largest difference ${bindError.toExponential(2)}`);
