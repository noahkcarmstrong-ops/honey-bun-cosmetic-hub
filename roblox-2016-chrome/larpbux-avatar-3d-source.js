import * as THREE from 'three';
import { MTLLoader } from 'three/addons/loaders/MTLLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const CDN = /^https:\/\/[a-z0-9-]+\.rbxcdn\.com\/[A-Za-z0-9._~%/-]+$/;
const HASH = /^[A-Za-z0-9._~-]+$/;

function shard(hash) {
  let value = 31;
  for (const char of String(hash)) value = (value ^ char.charCodeAt(0)) % 8;
  return value;
}

function assetUrl(hash) {
  if (String(hash).startsWith('https://')) return checkedUrl(hash);
  if (!HASH.test(String(hash))) throw new Error('Invalid Roblox asset hash');
  return `https://t${shard(hash)}.rbxcdn.com/${hash}`;
}

function checkedUrl(value) {
  const url = new URL(value, location.href).href;
  if (!CDN.test(url)) throw new Error('Refused non-CDN avatar asset URL');
  return url;
}

function abortError() { return new DOMException('Avatar load aborted', 'AbortError'); }

function raceAbort(promise, signal) {
  if (signal.aborted) return Promise.reject(abortError());
  let abort;
  return Promise.race([promise, new Promise((_, reject) => {
    abort = () => reject(abortError()); signal.addEventListener('abort', abort, { once: true });
  })]).finally(() => signal.removeEventListener('abort', abort));
}

function viewState(camera, controls) {
  return {
    position: camera.position.toArray(),
    target: controls.target.toArray(),
    zoom: camera.zoom,
  };
}

function applyView(camera, controls, view) {
  if (!view) return false;
  const position = view.position || view.camera?.position;
  const target = view.target || view.controls?.target;
  if (Array.isArray(position) && position.length === 3) camera.position.fromArray(position);
  if (Array.isArray(target) && target.length === 3) controls.target.fromArray(target);
  if (Number.isFinite(view.zoom)) camera.zoom = view.zoom;
  return Array.isArray(position) || Array.isArray(target) || Number.isFinite(view.zoom);
}

function descriptorView(camera) {
  const position = camera?.position;
  const direction = camera?.direction;
  if (!position || !direction) return null;
  const p = new THREE.Vector3(position.x, position.y, position.z);
  const d = new THREE.Vector3(direction.x, direction.y, direction.z);
  return { position: p.toArray(), direction: d.toArray() };
}

export function avatarMaterials(mtlText, manager) {
  const materials = new MTLLoader(manager).parse(mtlText, '');
  materials.preload();
  for (const [name, material] of Object.entries(materials.materials)) {
    const info = materials.materialsInfo[name];
    // Roblox atlases already contain clothing and skin colors. Applying the
    // exported part's Kd tint again recolors the entire atlas (e.g. white sleeves tan).
    if (material.map) material.color.setHex(0xffffff);
    // RGBA diffuse maps already supply alpha. Reusing them as map_d instead
    // multiplies opacity by the green color channel and erases dark clothing.
    if (material.alphaMap && info.map_kd && info.map_kd === info.map_d) {
      if (material.alphaMap !== material.map) material.alphaMap.dispose();
      material.alphaMap = null;
      material.transparent = material.opacity < 1;
    }
    // Cut out fully transparent texels without making solid avatar parts translucent.
    if (material.map || material.alphaMap) material.alphaTest = 0.01;
    // Keep thumbnail texture highlights from receiving an additional Phong sheen.
    material.specular.setHex(0x000000);
    material.side = THREE.DoubleSide;
  }
  return materials;
}

export async function create(host, descriptorUrl, options = {}) {
  if (!host || typeof host.append !== 'function') throw new TypeError('A host element is required');
  const internal = new AbortController();
  const signal = internal.signal;
  const external = options.signal;
  const abort = () => internal.abort();
  external?.addEventListener('abort', abort, { once: true });
  if (external?.aborted) internal.abort();
  let disposed = false;
  let renderer;
  let controls;
  let scene;
  let camera;
  let canvas;
  let resizeObserver;
  let root;
  let animationFrame;

  const ensureAlive = () => { if (disposed || signal.aborted) throw abortError(); };
  const cleanupObject = object => object?.traverse?.(node => {
    node.geometry?.dispose();
    const materials = Array.isArray(node.material) ? node.material : [node.material];
    for (const material of materials) {
      if (!material) continue;
      for (const key of ['map', 'normalMap', 'roughnessMap', 'metalnessMap', 'emissiveMap', 'alphaMap']) material[key]?.dispose?.();
      material.dispose?.();
    }
  });

  try {
    const descriptorResponse = await fetch(checkedUrl(descriptorUrl), { signal });
    if (!descriptorResponse.ok) throw new Error(`Avatar descriptor failed (${descriptorResponse.status})`);
    const descriptor = await descriptorResponse.json();
    ensureAlive();
    const objUrl = assetUrl(descriptor.obj);
    const mtlUrl = assetUrl(descriptor.mtl);
    const textureUrls = new Map((descriptor.textures || []).map(hash => [String(hash), assetUrl(hash)]));
    const [objText, mtlText] = await Promise.all([
      fetch(objUrl, { signal }).then(response => { if (!response.ok) throw new Error('Avatar OBJ failed'); return response.text(); }),
      fetch(mtlUrl, { signal }).then(response => { if (!response.ok) throw new Error('Avatar MTL failed'); return response.text(); }),
    ]);
    ensureAlive();

    const manager = new THREE.LoadingManager();
    manager.setURLModifier(raw => {
      if (String(raw).startsWith('https://')) return checkedUrl(raw);
      const name = decodeURIComponent(String(raw)).split(/[\\/]/).pop();
      const hash = name.replace(/\.[^/.]+$/, '');
      const url = textureUrls.get(name) || textureUrls.get(hash) || (HASH.test(name) ? assetUrl(name) : null);
      return checkedUrl(url || raw);
    });
    let started = false;
    let resolveReady;
    const ready = new Promise((resolve, reject) => {
      resolveReady = resolve;
      manager.onStart = () => { started = true; };
      manager.onLoad = resolve;
      manager.onError = () => reject(new Error('Roblox could not load an avatar texture.'));
    });
    const materials = avatarMaterials(mtlText, manager);
    root = new OBJLoader(manager).setMaterials(materials).parse(objText);
    if (!started) resolveReady();
    await raceAbort(ready, signal);
    ensureAlive();

    canvas = document.createElement('canvas');
    canvas.setAttribute('aria-label', '3D avatar preview');
    canvas.style.display = 'block';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.background = 'transparent';
    host.append(canvas);
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(descriptor.camera?.fov || 35, 1, 0.01, 10000);
    renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setClearColor(0xffffff, 0);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.NoToneMapping;
    // Neutral fill keeps dark clothing readable; opposing lights give the
    // model shape without a glossy hotspot. PI compensates modern Phong units.
    scene.add(new THREE.AmbientLight(0xffffff, Math.PI * 0.65));
    const keyLight = new THREE.DirectionalLight(0xffffff, Math.PI * 0.45);
    keyLight.position.set(-3, 5, 5);
    scene.add(keyLight);
    const fillLight = new THREE.DirectionalLight(0xffffff, Math.PI * 0.2);
    fillLight.position.set(3, 2, -5);
    scene.add(fillLight);
    controls = new OrbitControls(camera, canvas);
    controls.enablePan = false;
    controls.enableDamping = false;
    controls.autoRotate = !options.static;
    controls.autoRotateSpeed = 4;
    controls.mouseButtons.LEFT = THREE.MOUSE.ROTATE;
    controls.mouseButtons.RIGHT = THREE.MOUSE.ROTATE;
    controls.touches.ONE = THREE.TOUCH.ROTATE;
    scene.add(root);
    const box = new THREE.Box3().setFromObject(root);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const radius = Math.max(size.length() / 2, 0.5);
    const saved = typeof options.view === 'function' ? options.view() : options.view;
    const hadView = applyView(camera, controls, saved);
    let autoFrame = !hadView;
    if (!hadView) {
      const descriptorCamera = descriptorView(descriptor.camera);
      if (descriptorCamera) {
        camera.position.fromArray(descriptorCamera.position);
        controls.target.copy(center);
      } else camera.position.set(center.x, center.y + radius * 0.15, center.z + radius * 2.4);
      controls.target.copy(center);
    }
    camera.near = Math.max(radius / 100, 0.01);
    camera.far = Math.max(radius * 100, 100);
    controls.minDistance = Math.max(radius * 0.35, 0.05);
    controls.maxDistance = Math.max(radius * 8, 2);
    camera.updateProjectionMatrix();
    controls.update();
    const render = () => { if (!disposed) renderer.render(scene, camera); };
    controls.addEventListener('change', render);
    controls.addEventListener('start', () => { autoFrame = false; });
    const keydown = event => {
      const offset = camera.position.clone().sub(controls.target);
      const spherical = new THREE.Spherical().setFromVector3(offset);
      if (event.key === 'ArrowLeft') spherical.theta += 0.15;
      else if (event.key === 'ArrowRight') spherical.theta -= 0.15;
      else if (event.key === 'ArrowUp') spherical.phi = Math.max(0.05, spherical.phi - 0.15);
      else if (event.key === 'ArrowDown') spherical.phi = Math.min(Math.PI - 0.05, spherical.phi + 0.15);
      else if (event.key === '+' || event.key === '=') spherical.radius /= 1.1;
      else if (event.key === '-') spherical.radius *= 1.1;
      else return;
      spherical.radius = THREE.MathUtils.clamp(spherical.radius, controls.minDistance, controls.maxDistance);
      camera.position.setFromSpherical(spherical).add(controls.target);
      controls.update();
      event.preventDefault();
    };
    canvas.tabIndex = 0;
    canvas.addEventListener('keydown', keydown);
    const resize = () => {
      const width = host.clientWidth || 280;
      const height = host.clientHeight || 340;
      renderer.setSize(width, height, false);
      camera.aspect = width / height;
      if (autoFrame) {
        const fitDistance = radius / (Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * Math.min(camera.aspect, 1));
        const offset = camera.position.clone().sub(controls.target);
        const distance = Math.max(offset.length(), fitDistance * 1.08);
        camera.position.copy(controls.target).add(offset.normalize().multiplyScalar(distance));
      }
      camera.updateProjectionMatrix();
      render();
    };
    resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(host);
    resize();
    let previousTime;
    const animate = time => {
      if (disposed) return;
      const delta = previousTime === undefined ? 0 : Math.min((time - previousTime) / 1000, 0.25);
      previousTime = time;
      if (!document.hidden && host.isConnected && host.getClientRects().length) controls.update(delta);
      animationFrame = requestAnimationFrame(animate);
    };
    if (!options.static) animationFrame = requestAnimationFrame(animate);
    external?.removeEventListener('abort', abort);
    return {
      capture(kind = 'fullBody') {
        ensureAlive();
        const photoCamera = camera.clone();
        photoCamera.aspect = 1;
        if (kind === 'headshot') {
          let headBox;
          root.traverse(part => {
            if (!part.isMesh || !/^(Head|Player\d+)$/i.test(part.name)) return;
            const candidate = new THREE.Box3().setFromObject(part);
            if (!headBox || candidate.getCenter(new THREE.Vector3()).y > headBox.getCenter(new THREE.Vector3()).y) headBox = candidate;
          });
          const bottom = headBox?.min.y ?? box.min.y + size.y * 0.65;
          const top = box.max.y;
          const target = new THREE.Vector3(center.x, (bottom + top) / 2, center.z);
          const headWidth = headBox ? headBox.getSize(new THREE.Vector3()).x : size.x * 0.4;
          const photoRadius = Math.max((top - bottom) * 0.6, headWidth * 0.85, 0.25);
          const direction = camera.position.clone().sub(controls.target).normalize();
          photoCamera.position.copy(target).addScaledVector(direction, photoRadius / Math.sin(THREE.MathUtils.degToRad(photoCamera.fov / 2)));
          photoCamera.lookAt(target);
        }
        photoCamera.updateProjectionMatrix();
        const previousSize = renderer.getSize(new THREE.Vector2());
        try {
          renderer.setSize(420, 420, false);
          renderer.render(scene, photoCamera);
          return canvas.toDataURL('image/png');
        } finally {
          renderer.setSize(previousSize.x, previousSize.y, false);
          render();
        }
      },
      getView: () => viewState(camera, controls),
      getDiagnostics: () => ({version: 1, descriptorUrl, descriptor, objText, mtlText, avatarDefinition: options.definition, view: viewState(camera, controls)}),
      dispose() {
        if (disposed) return;
        disposed = true;
        cancelAnimationFrame(animationFrame);
        internal.abort();
        external?.removeEventListener('abort', abort);
        resizeObserver?.disconnect();
        controls?.dispose();
        canvas?.removeEventListener('keydown', keydown);
        cleanupObject(root);
        renderer?.dispose();
        renderer?.forceContextLoss();
        canvas?.remove();
      },
    };
  } catch (error) {
    const wasAborted = signal.aborted || error?.name === 'AbortError';
    disposed = true;
    cancelAnimationFrame(animationFrame);
    internal.abort();
    external?.removeEventListener('abort', abort);
    resizeObserver?.disconnect();
    controls?.dispose();
    cleanupObject(root);
    renderer?.dispose();
    renderer?.forceContextLoss();
    canvas?.remove();
    if (wasAborted) throw abortError();
    throw error;
  }
}
