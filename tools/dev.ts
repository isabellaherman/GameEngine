// Dev server that sees every .bend file. Bun's own watcher only sees the
// .bend files JS imports directly, not the ones they import in turn
// (ACCESSIBILITY.bend, TOKENS.bend…). This runs `bun index.html` and starts
// it again when any .bend file in the project changes; reload the page after.

import { spawn, type Subprocess } from "bun";
import { existsSync, readdirSync, watch } from "node:fs";

const PORT = "3100";

// Reference characters' pages (refs/*/index.html), served beside the
// engine's page when they exist. refs/ is gitignored and never built.
const REFERENCE_PAGES = existsSync("refs")
  ? readdirSync("refs").map((d) => `refs/${d}/index.html`).filter((p) => existsSync(p))
  : [];

let server: Subprocess | null = null;

function start() {
  server = spawn(["bun", `--port=${PORT}`, "index.html", ...REFERENCE_PAGES], { stdout: "inherit", stderr: "inherit" });
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

for (const dir of [".", "engine", "projects", "editor", ...(existsSync("refs") ? ["refs"] : [])]) {
  watch(dir, { recursive: dir !== "." }, (_, file) => {
    if (file && file.endsWith(".bend") && !file.includes("node_modules")) restart(file);
  });
}

process.on("SIGINT", () => { server?.kill(); process.exit(0); });
start();
