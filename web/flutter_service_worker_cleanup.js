// One-release cleanup worker for PartMo's retired Flutter PWA cache.
// It deliberately does not cache or intercept any requests.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map((name) => caches.delete(name)));
    await self.clients.claim();
    await self.registration.unregister();

    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    await Promise.all(windows.map((client) => client.navigate(client.url)));
  })());
});
