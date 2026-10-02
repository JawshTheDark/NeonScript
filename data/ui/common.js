/* NeonScript HTML panels - messaging with NeonScript.
 *   neon.send(text)          text goes to NeonScript (always treated there as untrusted data)
 *   neon.onmessage = f(obj)  NeonScript sends JSON objects: {type: "...", ...}; type "theme" is handled here
 * Panels may only load files from this folder (the helper cancels every other navigation).                     */
(function () {
  var wv = window.chrome && window.chrome.webview;
  var api = {
    onmessage: null,
    send: function (s) { if (wv) wv.postMessage(String(s)); },
    applyTheme: function (v) {
      var root = document.documentElement.style;
      for (var k in v) {
        if (/^[a-z0-9-]+$/.test(k) && /^#[0-9a-fA-F]{3,8}$/.test(String(v[k]))) root.setProperty('--' + k, v[k]);
      }
    }
  };
  window.neon = api;
  if (wv) {
    wv.addEventListener('message', function (e) {
      var m;
      try { m = JSON.parse(e.data); } catch (x) { return; }
      if (!m || typeof m !== 'object') return;
      if (m.type === 'theme') api.applyTheme(m.vars || {});
      else if (api.onmessage) api.onmessage(m);
    });
  }
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') api.send('close');
  });
  window.addEventListener('contextmenu', function (e) { e.preventDefault(); });
})();
