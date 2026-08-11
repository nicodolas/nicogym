(async () => {
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map((registration) => registration.unregister()));
  }
  if ('caches' in window) {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter((key) => key.startsWith('flutter-app-') || key === 'flutter-temp-cache')
        .map((key) => caches.delete(key)),
    );
  }
})().catch(() => {
  // Cache cleanup is best-effort and must never block application startup.
});
