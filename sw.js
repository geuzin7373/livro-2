const CACHE_NAME = 'princesa-sem-coroa-v1';

const APP_SHELL_ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './imagens/capa.png',
  './imagens/imagemfundo.jpg'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function (cache) {
        return cache.addAll(APP_SHELL_ASSETS);
      })
      .catch(function () { })
      .then(function () {
        return self.skipWaiting();
      })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.map(function (key) {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
          return Promise.resolve();
        }));
      })
      .then(function () {
        return self.clients.claim();
      })
  );
});

self.addEventListener('fetch', function (event) {
  const request = event.request;

  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then(function (response) {
          const responseCopy = response.clone();
          caches.open(CACHE_NAME).then(function (cache) {
            cache.put('./index.html', responseCopy);
          });
          return response;
        })
        .catch(function () {
          return caches.match(request).then(function (cached) {
            return cached || caches.match('./index.html');
          });
        })
    );
    return;
  }

  event.respondWith(
    caches.match(request)
      .then(function (cached) {
        if (cached) return cached;

        return fetch(request).then(function (response) {
          if (response && response.ok) {
            const responseCopy = response.clone();
            caches.open(CACHE_NAME).then(function (cache) {
              cache.put(request, responseCopy);
            });
          }

          return response;
        });
      })
      .catch(function () {
        return new Response('', {
          status: 504,
          statusText: 'Offline'
        });
      })
  );
});
