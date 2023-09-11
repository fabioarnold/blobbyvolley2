import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { Water } from "three/addons/objects/Water.js";

let renderer;
let camera;
let scene;
let water;
let ball = new THREE.Object3D();

function initThreeJS() {
    renderer = new THREE.WebGLRenderer({ canvas: $canvasgl });
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.setClearColor(0xffffff);

    scene = new THREE.Scene();

    const amb = new THREE.AmbientLight(0xffffff, 0.8); // soft white light
    scene.add(amb);

    const light = new THREE.DirectionalLight(0xffffff, 1);
    light.position.set(0.70707 * 10, 0.70707 * 20, 0);
    light.castShadow = true;
    light.shadow.mapSize.width = 4096;
    light.shadow.mapSize.height = 4096;
    light.shadow.bias = -0.00008;
    light.shadow.camera.top = 10;
    light.shadow.camera.bottom = -10;
    light.shadow.camera.left = -10;
    light.shadow.camera.right = 10;
    scene.add(light);

    // const helper = new THREE.CameraHelper(light.shadow.camera);
    // scene.add(helper);

    const enableShadows = (object) => {
        object.traverse(function (node) {
            if (node.isMesh) {
                if (node.material) node.material.metalness = 0;
                node.castShadow = true;
                node.receiveShadow = true;
            }
        });
    };

    const loader = new GLTFLoader();
    loader.load("models/island.glb", (gltf) => {
        gltf.scene.rotation.y = Math.PI;
        enableShadows(gltf.scene);
        scene.add(gltf.scene);
    });
    const playfield = new THREE.Object3D();
    playfield.position.x = 8;
    playfield.position.y = 0.375;
    playfield.position.z = 2;
    playfield.rotation.y = -Math.PI / 4;
    scene.add(playfield);
    playfield.add(ball);
    loader.load("models/ball.glb", (gltf) => {
        gltf.scene.scale.set(0.31, 0.31, 0.31);
        enableShadows(gltf.scene);
        ball.add(gltf.scene);
    });
    loader.load("models/net.glb", (gltf) => {
        // gltf.scene.scale.set(4, 4, 4);
        gltf.scene.rotation.y = Math.PI / 2;
        gltf.scene.scale.set(1.02, 1.02, 1.02);
        enableShadows(gltf.scene);
        playfield.add(gltf.scene);
    });

    const waterGeometry = new THREE.PlaneGeometry(10000, 10000);
    water = new Water(waterGeometry, {
        textureWidth: 512,
        textureHeight: 512,
        waterNormals: new THREE.TextureLoader().load("textures/waternormals.jpg", function (texture) {
            texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
        }),
        sunDirection: new THREE.Vector3(),
        sunColor: 0xffffff,
        waterColor: 0x001e0f,
        distortionScale: 2,
        fog: scene.fog !== undefined,
    });
    water.rotation.x = -Math.PI / 2;
    water.material.uniforms["sunDirection"].value.set(0.70707, 0.70707, 0);
    scene.add(water);

    scene.background = new THREE.CubeTextureLoader()
        .setPath("textures/skybox/")
        .load(["px.png", "nx.png", "py.png", "ny.png", "pz.png", "nz.png"]);

    camera = new THREE.PerspectiveCamera(60, 4 / 3, 0.1, 1000);
    // camera.position.set(0, 3, 12);
    camera.position.set(6 + 0.2, 1.345, 4 - 0.2);
    camera.rotation.y = -Math.PI / 4;
}

function resizeThreeJS(width, height, pixelRatio) {
    renderer.setSize(width, height);
    renderer.setPixelRatio(pixelRatio);
}

function mapRange(value, low1, high1, low2, high2) {
    return low2 + ((high2 - low2) * (value - low1)) / (high1 - low1);
}

const camPosPlayfield = new THREE.Vector3(6 + 0.2, 1.345, 4 - 0.2);
const camPosIsland = new THREE.Vector3(0, 3, 16);

function easeInOutQuad(t) {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}

var cameraRotation = 0;

function drawThreeJS(gameState) {
    // camera.rotation.y = alpha;
    // camera.position.x = Math.sin(alpha) * 14;
    // camera.position.z = Math.cos(alpha) * 14;

    if (gameState.menu.alpha === 1) {
        cameraRotation += 0.01;
        if (cameraRotation > Math.PI) cameraRotation -= Math.PI * 2;
        camera.rotation.y = cameraRotation;
        camera.position.x = Math.sin(cameraRotation) * camPosIsland.z;
        camera.position.y = camPosIsland.y;
        camera.position.z = Math.cos(cameraRotation) * camPosIsland.z;
    } else {
        if (gameState.menu.alpha > 0.5) {
            const alpha = easeInOutQuad(2 * gameState.menu.alpha - 1);
            camera.rotation.y = alpha * cameraRotation;
            camera.position.x = Math.sin(alpha * cameraRotation) * camPosIsland.z;
            camera.position.y = camPosIsland.y;
            camera.position.z = Math.cos(alpha * cameraRotation) * camPosIsland.z;
        } else {
            cameraRotation = 0;
            const alpha = easeInOutQuad(1 - 2 * gameState.menu.alpha);
            camera.position.lerpVectors(camPosIsland, camPosPlayfield, alpha); // .lerp(new THREE.Vector3(0, 3, 14), alpha)
            camera.rotation.y = (-Math.PI / 4) * alpha;
        }
    }

    ball.position.x = mapRange(gameState.ball.x, 0, 800, -1.958, 1.958);
    ball.position.y = mapRange(gameState.ball.y, 0, 600, 2.44, -0.495);
    ball.rotation.z = -gameState.ball.rotation;

    water.material.uniforms.time.value = performance.now() * 0.001 * 0.1;

    renderer.resetState();
    renderer.render(scene, camera);
    renderer.resetState();
    const gl = renderer.getContext();
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
}

export {
    initThreeJS,
    resizeThreeJS,
    drawThreeJS
}