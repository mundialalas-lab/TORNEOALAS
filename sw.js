const CACHE_NAME = 'alas-mundial-v14';
const ASSETS_TO_CACHE = [
  './',
  './ALAS-MUNDIAL.html',
  './ALAS.png',
  './ALAS_blanco.png',
  './ICONO DE GOL SIN FONDO.png',
  './PELOTA.jpg',
  './FIFA.jpg',
  './manifest.json'
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
