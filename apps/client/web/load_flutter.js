Promise.resolve(window.nicogymLegacyCacheCleanup).finally(() => {
  const bootstrap = document.createElement('script');
  bootstrap.src = 'flutter_bootstrap.js';
  bootstrap.async = true;
  document.head.append(bootstrap);
});
