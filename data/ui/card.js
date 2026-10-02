/* NeonScript card viewer: shows {type:"card", title, sub, text} with a small, safe markdown subset.
 * Nothing is ever put in with innerHTML - every piece of text becomes a text node. */
(function () {
  var body = document.getElementById('body'), title = document.getElementById('title'), sub = document.getElementById('sub');
  var note = document.getElementById('note'), plain = '';

  function inline(parent, s) {
    // **bold**, *italic*, `code`, [text](https://url) and bare http(s) links
    var re = /(\*\*([^*]+)\*\*|`([^`]+)`|\*([^*\s][^*]*)\*|\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|(https?:\/\/[^\s<>"']+[^\s<>"'.,;:!?)]))/g;
    var last = 0, m;
    while ((m = re.exec(s)) !== null) {
      if (m.index > last) parent.appendChild(document.createTextNode(s.slice(last, m.index)));
      var el;
      if (m[2] !== undefined) { el = document.createElement('b'); el.textContent = m[2]; }
      else if (m[3] !== undefined) { el = document.createElement('code'); el.textContent = m[3]; }
      else if (m[4] !== undefined) { el = document.createElement('i'); el.textContent = m[4]; }
      else if (m[5] !== undefined) { el = document.createElement('a'); el.textContent = m[5]; el.setAttribute('href', m[6]); }
      else { el = document.createElement('a'); el.textContent = m[7]; el.setAttribute('href', m[7]); }
      parent.appendChild(el);
      last = re.lastIndex;
    }
    if (last < s.length) parent.appendChild(document.createTextNode(s.slice(last)));
  }

  function render(text) {
    body.textContent = '';
    var lines = String(text).replace(/\r/g, '').split('\n'), list = null, listType = '', para = null;
    function endBlocks() { list = null; para = null; }
    lines.forEach(function (raw) {
      var line = raw.replace(/\s+$/, ''), m;
      if (!line.trim()) { endBlocks(); return; }
      if ((m = /^\s*(#{1,4})\s+(.*)$/.exec(line))) {
        endBlocks();
        var h = document.createElement('h4'); inline(h, m[2]); body.appendChild(h); return;
      }
      if ((m = /^\s*[-*•]\s+(.*)$/.exec(line)) || (m = /^\s*(\d+)[.)]\s+(.*)$/.exec(line))) {
        var ordered = m.length > 2, t = ordered ? 'ol' : 'ul';
        if (!list || listType !== t) { list = document.createElement(t); listType = t; body.appendChild(list); para = null; }
        var li = document.createElement('li'); inline(li, ordered ? m[2] : m[1]); list.appendChild(li); return;
      }
      list = null;
      if (!para) { para = document.createElement('p'); body.appendChild(para); }
      else para.appendChild(document.createElement('br'));
      inline(para, line);
    });
  }

  function copyText() {
    var ta = document.createElement('textarea');
    ta.value = plain;
    ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    note.textContent = ok ? 'Copied' : 'Could not copy';
    setTimeout(function () { note.textContent = ''; }, 1800);
  }

  neon.onmessage = function (m) {
    if (m.type !== 'card') return;
    title.textContent = String(m.title || 'NeonScript');
    sub.textContent = String(m.sub || '');
    plain = String(m.text || '');
    render(plain);
    document.title = title.textContent;
  };
  document.getElementById('copy').addEventListener('click', copyText);
  document.getElementById('close').addEventListener('click', function () { neon.send('close'); });
  neon.send('ready');
})();
