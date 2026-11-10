// The browser side of the engine. It only reads the mouse and draws what
// Bend returns: the World (engine/world.bend) and the camera
// (engine/camera.bend) decide every number.

import { theme } from "bend-ui";
import World from "./engine/world.bend";
import Camera from "./engine/camera.bend";

theme({ mode: "dark" });

// A Bend list arrives as cons cells; the GPU wants a flat array.
const flat = (list) => {
  const out = [];
  for (let l = list; l.$ === "Con"; l = l.tail) out.push(l.head);
  return out;
};

// GPU setup
// =========

const canvas = document.getElementById("scene");
const gl = canvas.getContext("webgl2", { antialias: true });

const VERT = `#version 300 es
uniform mat4 u_vp;
in vec3 a_pos;
in vec3 a_col;
out vec3 v_pos;
out vec3 v_col;
void main() {
  v_pos = a_pos;
  v_col = a_col;
  gl_Position = u_vp * vec4(a_pos, 1.0);
}`;

const FRAG = `#version 300 es
precision highp float;
uniform vec3 u_eye;
uniform vec2 u_fade;
in vec3 v_pos;
in vec3 v_col;
out vec4 color;
void main() {
  float a = 1.0 - smoothstep(u_fade.x, u_fade.y, distance(v_pos, u_eye));
  color = vec4(v_col, a);
}`;

function shader(type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src);
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
  return s;
}

const prog = gl.createProgram();
gl.attachShader(prog, shader(gl.VERTEX_SHADER, VERT));
gl.attachShader(prog, shader(gl.FRAGMENT_SHADER, FRAG));
gl.linkProgram(prog);
if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));

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

const [skyR, skyG, skyB] = flat(World.sky());

// Frame
// =====

let cam = Camera.start();
let queued = false;

function draw() {
  queued = false;
  const w = canvas.width, h = canvas.height;
  const frame = flat(Camera.frame(cam, w / Math.max(h, 1)));
  gl.viewport(0, 0, w, h);
  gl.clearColor(skyR, skyG, skyB, 1);
  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.useProgram(prog);
  gl.uniformMatrix4fv(u.vp, false, frame.slice(0, 16));
  gl.uniform3fv(u.eye, frame.slice(16, 19));
  gl.uniform2fv(u.fade, flat(World.fade(cam)));
  gl.bindVertexArray(vao);
  gl.drawArrays(gl.LINES, 0, lines.length / 6);
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
