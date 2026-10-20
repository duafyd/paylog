{{flutter_js}}
{{flutter_build_config}}
// Phase 1 is online-only. Do not register a caching service worker.
_flutter.loader.load().catch(() => {
  const status = document.getElementById('loading');
  if (status) status.textContent = '앱을 불러오지 못했어요. 연결을 확인하고 새로고침해 주세요.';
});
