window.nicogymLegacyCacheCleanup = (async () => {
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    const legacyRegistrations = registrations.filter((registration) => {
      const worker = registration.active ?? registration.waiting ?? registration.installing;
      return worker?.scriptURL.endsWith('/flutter_service_worker.js') ?? false;
    });
    await Promise.allSettled(
      legacyRegistrations.map((registration) => registration.unregister()),
    );
  }
  if ('caches' in window) {
    const keys = await caches.keys();
    await Promise.allSettled(
      keys
        .filter((key) => key.startsWith('flutter-app-') || key === 'flutter-temp-cache')
        .map((key) => caches.delete(key)),
    );
  }
})().catch(() => {
  // Cache cleanup is best-effort and must never block application startup.
});
