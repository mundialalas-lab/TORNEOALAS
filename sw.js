const CACHE_NAME = 'alas-mundial-v40';

// Lo que vive en esta carpeta.
const ASSETS_PROPIOS = [
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

// Las librerias que la app carga del CDN. NO son opcionales:
//
//   supabase-js se usa en el nivel superior del script principal
//   (window.supabase.createClient). Si falta, el HTML ya trae una guarda que
//   evita que muera la app entera, pero se pierde la sincronizacion y el
//   ingreso de capitanes y admin.
//
//   gsap mueve casi toda la interfaz. Sin el, varias funciones de render
//   tiran ReferenceError y quedan pantallas a medio dibujar.
//
// El service worker era "network first": las bajaba de internet cada vez y
// solo quedaban en cache DESPUES del primer uso con senal. Al costado de la
// cancha, sin datos, la primera apertura del dia se encontraba sin ellas.
// Precachearlas al instalar es lo que cierra ese agujero.
const ASSETS_EXTERNOS = [
  'https://cdn.jsdelivr.net/npm/gsap@3.12.5/dist/gsap.min.js',
  'https://cdn.jsdelivr.net/npm/gsap@3.12.5/dist/ScrollTrigger.min.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.0/dist/umd/supabase.min.js',
  // Las hojas de las tipografias. Los archivos .woff2 que estas piden salen
  // de otro dominio y varian segun el navegador, asi que esos los junta el
  // cacheo en caliente del fetch de mas abajo, con el primer uso con senal.
  'https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap',
  'https://fonts.googleapis.com/css2?family=Anton&family=Saira+Condensed:wght@500;600;700;800&family=Oswald:wght@500;600;700&display=swap'
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // Uno por uno, con su propio catch, y NO con addAll().
      //
      // addAll() es todo-o-nada: si UNO solo de los archivos falla, rechaza
      // entero y no guarda ninguno. Aca habia un .catch() alrededor que se
      // tragaba ese rechazo en silencio, asi que un 404 en cualquier imagen
      // dejaba la app sin NADA precacheado y nadie se enteraba. Con veinte
      // archivos en la lista, y cinco de ellos de otro dominio, eso era una
      // loteria en cada instalacion.
      return Promise.all(
        ASSETS_PROPIOS.concat(ASSETS_EXTERNOS).map((url) =>
          cache.add(url).catch(() => {})
        )
      );
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
