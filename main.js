// The engine's page: opens the project PROJECT.bend names in the editor
// (editor/app.js).

import Project from "./PROJECT.bend";
import { startEditor } from "./editor/app.js";

startEditor(Project.opening(), { camera: Project.opening_camera() });
