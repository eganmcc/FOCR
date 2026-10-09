{{flutter_js}}
{{flutter_build_config}}

// FOCR: load Flutter WITHOUT its default service worker. The default registers
// flutter_service_worker.js, a stub that unregisters itself and would replace our offline worker
// (web/sw.js). Offline support is handled entirely by sw.js.
_flutter.loader.load();
