import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { Water } from 'three/addons/objects/Water.js';

// make accessible from standard JS
window.initThreeJS = initThreeJS;
window.resizeThreeJS = resizeThreeJS;
window.drawThreeJS = drawThreeJS;

let renderer;
let camera;
let scene;
let water;

export function initThreeJS() {
    renderer = new THREE.WebGLRenderer({ canvas: $canvasgl });
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.setClearColor(0xFFFFFF);
    // renderer.autoClear = false;
    // renderer.setPixelRatio(devicePixelRatio);
    // renderer.setSize($canvasgl.width / devicePixelRatio, $canvasgl.height / devicePixelRatio);

    scene = new THREE.Scene();

    const amb = new THREE.AmbientLight(0xFFFFFF, 0.8); // soft white light
    scene.add(amb);

    const light = new THREE.DirectionalLight(0xffffff, 1);
    light.position.set(0.70707 * 10, 0.70707 * 20, 0);
    light.castShadow = true;
    light.shadow.mapSize.width = 1024;
    light.shadow.mapSize.height = 1024;
    light.shadow.bias = -0.0008;
    light.shadow.camera.top = 10;
    light.shadow.camera.bottom = -10;
    light.shadow.camera.left = -10;
    light.shadow.camera.right = 10;
    scene.add(light);

    // const helper = new THREE.CameraHelper(light.shadow.camera);
    // scene.add(helper);

    const loader = new GLTFLoader();
    loader.load('models/island.glb', (gltf) => {
        gltf.scene.rotation.y = Math.PI;
        gltf.scene.traverse(function (node) {
            if (node.isMesh) {
                if (node.material) node.material.metalness = 0;
                node.castShadow = true;
                node.receiveShadow = true;
            }
        });
        scene.add(gltf.scene);
    });
    loader.load('models/ball.glb', (gltf) => {
        gltf.scene.position.y = 6;
        gltf.scene.position.z = 5;
        scene.add(gltf.scene);
    });
    loader.load('models/net.glb', (gltf) => {
        gltf.scene.position.z = 5;
        gltf.scene.scale.set(4, 4, 4);
        scene.add(gltf.scene);
    });

    const waterGeometry = new THREE.PlaneGeometry(10000, 10000);
    water = new Water(
        waterGeometry,
        {
            textureWidth: 512,
            textureHeight: 512,
            waterNormals: new THREE.TextureLoader().load('textures/waternormals.jpg', function (texture) {
                texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
            }),
            sunDirection: new THREE.Vector3(),
            sunColor: 0xffffff,
            waterColor: 0x001e0f,
            distortionScale: 2,
            fog: scene.fog !== undefined
        }
    );
    water.rotation.x = - Math.PI / 2;
    water.material.uniforms['sunDirection'].value.set(0.70707, 0.70707, 0);
    scene.add(water);

    scene.background = new THREE.CubeTextureLoader().setPath('textures/skybox/').load(['px.png', 'nx.png', 'py.png', 'ny.png', 'pz.png', 'nz.png']);

    camera = new THREE.PerspectiveCamera(75, 4 / 3, 0.1, 1000);
    camera.position.set(0, 3, 12);
}

export function resizeThreeJS(width, height, pixelRatio) {
    renderer.setSize(width, height);
    renderer.setPixelRatio(pixelRatio);
}

export function drawThreeJS() {
    const time = Date.now() * 0.001;
    const alpha = 0.5 * time * 0;
    camera.rotation.y = alpha;
    camera.position.x = Math.sin(alpha) * 14;
    camera.position.z = Math.cos(alpha) * 14;

    water.material.uniforms.time.value = performance.now() * 0.001 * 0.1;

    renderer.resetState();
    renderer.render(scene, camera);
    renderer.resetState();
    const gl = renderer.getContext();
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
}