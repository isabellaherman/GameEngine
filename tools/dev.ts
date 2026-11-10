// Dev server that sees every .bend file. Bun's own watcher only sees the
// .bend files JS imports directly, not the ones they import in turn
// (ACCESSIBILITY.bend, TOKENS.bend…). This runs `bun index.html` and starts
// it again when any .bend file in the project changes; reload the page after.

import { spawn, type Subprocess } from "bun";
import { watch } from "node:fs";

const PORT = "3100";
let server: Subprocess | null = null;

function start() {
  server = spawn(["bun", `--port=${PORT}`, "index.html"], { stdout: "inherit", stderr: "inherit" });
}

let timer: Timer | undefined;
function restart(file: string) {
  clearTimeout(timer);
  timer = setTimeout(async () => {
    console.log(`\n${file} changed: restarting (reload the page)`);
    server?.kill();
    await server?.exited;
    start();
  }, 150);
}

for (const dir of [".", "engine", "editor"]) {
  watch(dir, { recursive: dir !== "." }, (_, file) => {
    if (file && file.endsWith(".bend") && !file.includes("node_modules")) restart(file);
  });
}

process.on("SIGINT", () => { server?.kill(); process.exit(0); });
start();
