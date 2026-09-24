import {vec3} from 'gl-matrix';
import Stats from 'stats-js';
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

import lambertVertSource from './shaders/lambert-vert.glsl?raw';
import lambertFragSource from './shaders/lambert-frag.glsl?raw';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  grow: 0.0,
  relax: 0.0,
  heat: 0.0,
  tesselations: 5,
  'Reset': reset,
  'Load Scene': loadScene, // A function pointer, essentially
};

let time = 0;
let GROW = 0.0;
let RELAX = 0.0;
let HEAT = 0.0;

let icosphere: Icosphere;
let square: Square;
let prevTesselations: number = 5;
let prevGrow: number = 0.0;
let prevRelax: number = 0.0;
let prevHeat: number = 0.0;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
}

function reset() {
  GROW = 0.0;
  RELAX = 0.0;
  HEAT = 0.0;
  prevGrow = 0.0;
  prevRelax = 0.0;
  prevHeat = 0.0;

  controls.grow = GROW;
  controls.relax = RELAX;
  controls.heat = HEAT;
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'grow', 0, 10).step(.25).listen();
  gui.add(controls,'relax', 0, 1).step(0.1).listen();
  gui.add(controls, 'heat', 0, 1).step(0.1).listen();
  gui.add(controls, 'Load Scene');
  gui.add(controls, 'Reset');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();
  reset();

  const camera = new Camera(vec3.fromValues(2, 0, 5), vec3.fromValues(0, 1, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, lambertVertSource),
    new Shader(gl.FRAGMENT_SHADER, lambertFragSource),
  ]);

  // This function will be called every frame
  function tick() {
    time += .001;
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }
    if(controls.grow != prevGrow)
    {
      prevGrow = controls.grow;
      GROW = prevGrow;
    }
    if(controls.relax != prevRelax)
    {
      prevRelax = controls.relax;
      RELAX = prevRelax;
    }
    if(controls.heat != prevHeat)
    {
      prevHeat = controls.heat;
      HEAT = prevHeat;
    }
    renderer.render(camera, lambert, [
      icosphere], time, GROW, RELAX, HEAT
      // square,
    );
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
