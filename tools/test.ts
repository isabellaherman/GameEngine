// Runs the numerical tests in tests/*.bend. Each file's checks() returns a
// list of Check{name, ok}; Bend computes every case and decides whether it
// passed. This only runs the lists and prints them, and exits with an error
// when any fails, so `bun run check` stops.
//
// Limit: it loads Bend's plugin from the clone beside this project
// (../bend/bend2/main.ts), the same one bunfig.toml points at.

import plugin from "../../bend/bend2/main.ts";
import { readdirSync } from "node:fs";

Bun.plugin(plugin);

const dir = new URL("../tests/", import.meta.url);
let failed = 0;
let total = 0;

for (const file of readdirSync(dir).filter((f) => f.endsWith(".bend")).sort()) {
  const mod = (await import(new URL(file, dir).href)).default;
  console.log(file);
  for (let l = mod.checks(); l.$ === "Con"; l = l.tail) {
    const { name, ok } = l.head;
    total++;
    if (!ok) failed++;
    console.log(`  ${ok ? "ok  " : "FAIL"} ${name}`);
  }
}

console.log(failed ? `${failed} of ${total} TESTS FAIL` : `ALL ${total} TESTS PASS`);
process.exit(failed ? 1 : 0);
