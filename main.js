// The browser side of the engine. It only reads the mouse and draws what
// Bend returns: the World (engine/world.bend) and the camera
// (engine/camera.bend) decide every number, engine/shader/glsl.bend writes
// the shaders and engine/material.bend gives the values of their parameters.

import { theme } from "bend-ui";
import { createKeys } from "bend-ui/keys";
import Keys from "./KEYS.bend";
import World from "./engine/world.bend";
import Water from "./engine/water.bend";
import Camera from "./engine/camera.bend";
import Glsl from "./engine/shader/glsl.bend";
import Material from "./engine/material.bend";
import { mountDefaults } from "./editor/defaults/defaults.js";

theme({ mode: "dark", radius: "pill" });   // every button and segmented in the layout is a pill

// A Bend list arrives as cons cells; the GPU wants a flat array.
// Limit: this copies every number once; fine at start-up, too slow per frame.
const flat = (list) => {
  const out = [];
  for (let l = list; l.$ === "Con"; l = l.tail) out.push(l.head);
  return out;
};

// GPU setup
// =========

const canvas = document.getElementById("scene");
const gl = canvas.getContext("webgl2", { antialias: true });

// The shaders are written by Bend (engine/shader/glsl.bend); JS only hands
// the text to the GPU driver.
function shader(type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src);
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
  return s;
}

function program(vert, frag) {
  const p = gl.createProgram();
  gl.attachShader(p, shader(gl.VERTEX_SHADER, vert));
  gl.attachShader(p, shader(gl.FRAGMENT_SHADER, frag));
  gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
  return p;
}

const prog = program(Glsl.line_vert(), Glsl.line_frag());

const u = {
  vp: gl.getUniformLocation(prog, "u_vp"),
  eye: gl.getUniformLocation(prog, "u_eye"),
  fade: gl.getUniformLocation(prog, "u_fade"),
};

// The ground: built once by world.bend, 6 floats per vertex (x y z r g b).
const lines = new Float32Array(flat(World.lines()));
const vao = gl.createVertexArray();
gl.bindVertexArray(vao);
gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
gl.bufferData(gl.ARRAY_BUFFER, lines, gl.STATIC_DRAW);
const pos = gl.getAttribLocation(prog, "a_pos");
const col = gl.getAttribLocation(prog, "a_col");
gl.enableVertexAttribArray(pos);
gl.vertexAttribPointer(pos, 3, gl.FLOAT, false, 24, 0);
gl.enableVertexAttribArray(col);
gl.vertexAttribPointer(col, 3, gl.FLOAT, false, 24, 12);

// The water (engine/water.bend): its shape is a mesh built once (3 floats
// per vertex, 3 indices per triangle); its material is a graph that Bend
// writes into the shader, plus values for the graph's parameters.
const waterMat = Water.material();
const meshProg = program(Glsl.mesh_vert(), Material.frag(waterMat));
const mu = {
  vp: gl.getUniformLocation(meshProg, "u_vp"),
};

// A material's values go to their uniforms; material.bend names each one.
// Setting a value never compiles anything.
function setValues(p, values) {
  for (let l = values; l.$ === "Con"; l = l.tail) {
    const loc = gl.getUniformLocation(p, Material.uniform(l.head));
    const xs = flat(Material.numbers(l.head));
    if (xs.length === 1) gl.uniform1f(loc, xs[0]);
    else if (xs.length === 3) gl.uniform3fv(loc, xs);
  }
}
gl.useProgram(meshProg);
setValues(meshProg, Material.values(waterMat));
const water = Water.shape();
const waterIdx = new Uint32Array(flat(water.indices));
const waterVao = gl.createVertexArray();
gl.bindVertexArray(waterVao);
gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(flat(water.vertices)), gl.STATIC_DRAW);
const meshPos = gl.getAttribLocation(meshProg, "a_pos");
gl.enableVertexAttribArray(meshPos);
gl.vertexAttribPointer(meshPos, 3, gl.FLOAT, false, 12, 0);
gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, waterIdx, gl.STATIC_DRAW);

const [skyR, skyG, skyB] = flat(World.sky());

// Frame
// =====

let cam = Camera.start();
let queued = false;

const defaults = mountDefaults(document.getElementById("editor-defaults"), {
  getCam: () => cam,
  setCam: (c) => { cam = c; redraw(); },
  orbit: (c, dx, dy) => Camera.orbit(c, dx, dy),
});

// Shortcuts: the keymap and what each view looks from are KEYS.bend.
{
  const handlers = {};
  for (let l = Keys.keymap(); l.$ === "Con"; l = l.tail) {
    const action = l.head.action;
    handlers[action] = Keys.is_home(action) ? () => defaults.home() : () => defaults.look(Keys.view_handle(action));
  }
  createKeys(Keys.keymap(), handlers);
}

function draw() {
  queued = false;
  const w = canvas.width, h = canvas.height;
  const frame = flat(Camera.frame(cam, w / Math.max(h, 1)));
  gl.viewport(0, 0, w, h);
  gl.clearColor(skyR, skyG, skyB, 1);
  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  // The water first, then the grid over it: both lie on y = 0, so
  // drawing order decides who shows (there is no depth test yet).
  gl.useProgram(meshProg);
  gl.uniformMatrix4fv(mu.vp, false, frame.slice(0, 16));
  gl.bindVertexArray(waterVao);
  gl.drawElements(gl.TRIANGLES, waterIdx.length, gl.UNSIGNED_INT, 0);
  gl.useProgram(prog);
  gl.uniformMatrix4fv(u.vp, false, frame.slice(0, 16));
  gl.uniform3fv(u.eye, frame.slice(16, 19));
  gl.uniform2fv(u.fade, flat(World.fade(cam)));
  gl.bindVertexArray(vao);
  gl.drawArrays(gl.LINES, 0, lines.length / 6);
  defaults.draw();
}

const redraw = () => { if (!queued) { queued = true; requestAnimationFrame(draw); } };

new ResizeObserver(() => {
  const dpr = devicePixelRatio || 1;
  canvas.width = Math.round(canvas.clientWidth * dpr);
  canvas.height = Math.round(canvas.clientHeight * dpr);
  redraw();
}).observe(canvas);

// Input: drag orbits, right-drag or Shift-drag pans, the wheel zooms.
// =====

let drag = null;
canvas.addEventListener("contextmenu", (e) => e.preventDefault());
canvas.addEventListener("pointerdown", (e) => {
  drag = { x: e.clientX, y: e.clientY, pan: e.button !== 0 || e.shiftKey };
  canvas.setPointerCapture(e.pointerId);
});
canvas.addEventListener("pointermove", (e) => {
  if (!drag) return;
  const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
  drag.x = e.clientX; drag.y = e.clientY;
  cam = drag.pan ? Camera.pan(cam, dx, dy, canvas.clientHeight) : Camera.orbit(cam, dx, dy);
  redraw();
});
const release = () => { drag = null; };
canvas.addEventListener("pointerup", release);
canvas.addEventListener("pointercancel", release);
canvas.addEventListener("wheel", (e) => {
  e.preventDefault();
  cam = Camera.zoom(cam, e.deltaY);
  redraw();
}, { passive: false });
