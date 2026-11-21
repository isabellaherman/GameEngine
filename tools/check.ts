// `bun run check`: every check the engine has, in order. It stops at the
// first one that fails.
//
// 1. Laws: `bend PROOF.bend` (and the editor's own) must print ALL PROOFS CHECK.
// 2. Types: every engine, project and editor file compiles (--check-only).
// 3. Tests: the numerical tests in tests/*.bend (tools/test.ts).
// 4. Reference characters in refs/, when present (local only).
// 5. Fences: nothing outside refs/ imports from refs/, so third-party
//    reference assets can never reach a build.
//
// Limits now:
// - The file list below is written by hand: a new .bend file must be added.

import { $ } from "bun";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const typed = [
  "engine/vec.bend", "engine/world.bend", "engine/camera.bend", "engine/gizmo.bend",
  "engine/shader/glsl.bend", "engine/time.bend", "engine/mesh.bend", "engine/quat.bend",
  "engine/transform.bend", "engine/shader/node.bend", "engine/shader/compile.bend",
  "engine/material.bend", "engine/scene.bend", "engine/skeleton.bend", "engine/pose.bend", "engine/clip.bend", "engine/blend.bend", "engine/gait.bend", "engine/skin.bend", "engine/helpers.bend", "engine/ik.bend", "engine/hand.bend", "engine/figure.bend", "engine/locomotion.bend",
  "projects/water/water.bend", "projects/water/scene.bend", "projects/character/scene.bend", "projects/character/arm.bend",
  "PROJECT.bend", "editor/panels/panels.bend", "editor/panels/view.bend", "editor/defaults/view.bend",
  "tests/quat.bend", "tests/transform.bend", "tests/pose.bend", "tests/clip.bend", "tests/locomotion.bend", "tests/ik.bend", "tests/panels.bend",
];

function step(title: string) { console.log(`\n== ${title}`); }

step("laws");
await $`bend PROOF.bend`;
await $`bend editor/defaults/PROOF.bend`;

step("types");
for (const f of typed) await $`bend ${f} --check-only`.quiet();
console.log(`${typed.length} files compile`);

step("tests");
await $`bun tools/test.ts`;

// Reference characters (refs/, gitignored): their own laws, when they are
// on this machine. Each has a PROOF.bend next to its generated skeleton.
if (existsSync("refs")) {
  step("reference characters (local only)");
  for (const d of readdirSync("refs")) {
    if (existsSync(`refs/${d}/PROOF.bend`)) { await $`bend refs/${d}/PROOF.bend`.quiet(); console.log(`refs/${d}: laws hold`); }
  }
}

step("fences");
const offenders: string[] = [];
function walk(dir: string) {
  for (const name of readdirSync(dir)) {
    if ([".git", "node_modules", "refs", "dist", "tothinkabout"].includes(name)) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(bend|js|ts|html)$/.test(name) && /^\s*import\s[^\n]*refs\/|from\s+["'][^"']*refs\/|src=["'][^"']*refs\//m.test(readFileSync(p, "utf8"))) offenders.push(p);
  }
}
walk(".");
if (offenders.length) { console.error("these files import from refs/:", offenders); process.exit(1); }
console.log("nothing outside refs/ imports from refs/");
console.log("\nALL CHECKS PASS");
