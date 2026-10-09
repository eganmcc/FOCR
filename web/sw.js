// Offline cache for the FOCR web app (specs/001-registration-ocr/research.md R6).
// - Precaches the app shell and the self-hosted Tesseract.js assets on install.
// - The page posts the list of files it actually loaded (incl. the browser-specific Flutter
//   engine variant) and they are cached too; see the 'message' handler.
// - Navigations: network first, falling back to the cached shell when offline.
// - Other same-origin GETs: stale-while-revalidate.
// The build script (tool/build_web.sh) stamps a unique id per build, so each deploy installs a fresh
// worker and drops the previous cache.
const CACHE = 'focr-__FOCR_BUILD__';
const PRECACHE = [
  './',
  'index.html',
  'main.dart.js',
  'flutter_bootstrap.js',
  'manifest.json',
  'favicon.png',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'tesseract/tesseract.min.js',
  'tesseract/worker.min.js',
  'tesseract/core/tesseract-core-lstm.wasm.js',
  'tesseract/core/tesseract-core-simd-lstm.wasm.js',
  'tesseract/core/tesseract-core-relaxedsimd-lstm.wasm.js',
  'tesseract/lang/eng.traineddata.gz',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

// Cache exactly what the page used (see index.html). Already-cached entries are kept.
self.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'cache-urls' || !Array.isArray(event.data.urls)) return;
  const urls = event.data.urls.filter((u) => new URL(u).origin === self.location.origin);
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(urls.map((u) => cache.match(u).then((hit) => hit || cache.add(u).catch(() => {})))),
    ),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;

  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put('index.html', copy));
          return res;
        })
        .catch(() => caches.match('index.html')),
    );
    return;
  }

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(req);
      const network = fetch(req)
        .then((res) => {
          if (res.ok) cache.put(req, res.clone());
          return res;
        })
        .catch(() => cached);
      return cached || network;
    }),
  );
});
