const CACHE_NAME = 'alas-mundial-v25';
const ASSETS_TO_CACHE = [
  './',
  './ALAS-MUNDIAL.html',
  './ALAS.png',
  './ALAS_blanco.png',
  './ICONO DE GOL SIN FONDO.png',
  './PELOTA.jpg',
  './FIFA.jpg',
  './manifest.json',
  // Los iconos de instalacion. Van en la cache porque Android los vuelve a
  // pedir al crear el acceso directo, y si en ese momento no hay red el icono
  // queda generico.
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-192.png',
  './icons/icon-maskable-512.png',
  './icons/apple-touch-icon-180.png',
  // La musica de la intro y de la entrada. El nombre del segundo lleva un
  // espacio: sin codificar, la cache lo pide mal y queda afuera.
  './speed.mp3',
  './speed%202.mp3'
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE).catch(() => {});
    })
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((k) => {
          if (k !== CACHE_NAME) return caches.delete(k);
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  // Network first with cache fallback
  e.respondWith(
    fetch(e.request).then((networkResponse) => {
      if (networkResponse && networkResponse.status === 200 && e.request.method === 'GET') {
        const responseClone = networkResponse.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(e.request, responseClone).catch(() => {});
        });
      }
      return networkResponse;
    }).catch(() => caches.match(e.request))
  );
});
