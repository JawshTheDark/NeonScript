/* NeonScript emoji picker.  Sends "insert <emoji>" to NeonScript when one is clicked. */
(function () {
  var all = window.EMOJI || [], groups = window.EMOJI_GROUPS || [];
  var grid = document.getElementById('grid'), tabs = document.getElementById('tabs');
  var q = document.getElementById('q'), foot = document.getElementById('name');
  var hint = foot.textContent, current = 'recent', recent = [];
  var byChar = {};
  all.forEach(function (r) { byChar[r[0]] = r; });
  try { recent = JSON.parse(localStorage.getItem('neon.emoji.recent') || '[]').filter(function (c) { return byChar[c]; }); } catch (e) { recent = []; }

  function remember(ch) {
    recent = [ch].concat(recent.filter(function (c) { return c !== ch; })).slice(0, 36);
    try { localStorage.setItem('neon.emoji.recent', JSON.stringify(recent)); } catch (e) { /* private mode */ }
  }
  function cell(ch) {
    var d = document.createElement('div');
    d.className = 'e';
    d.textContent = ch;
    d.setAttribute('data-c', ch);
    return d;
  }
  function section(title, chars) {
    if (!chars.length) return;
    var h = document.createElement('h3'), row = document.createElement('div');
    h.textContent = title;
    row.className = 'row';
    chars.forEach(function (c) { row.appendChild(cell(c)); });
    grid.appendChild(h);
    grid.appendChild(row);
  }
  function render() {
    var term = q.value.trim().toLowerCase();
    grid.textContent = '';
    if (term) {
      var words = term.split(/\s+/);
      var hits = all.filter(function (r) { return words.every(function (w) { return r[1].indexOf(w) >= 0; }); }).map(function (r) { return r[0]; });
      if (!hits.length) { var n = document.createElement('div'); n.id = 'empty'; n.textContent = 'No emoji match "' + term + '"'; grid.appendChild(n); return; }
      section(hits.length + ' found', hits.slice(0, 400));
      return;
    }
    if (current === 'recent') {
      if (recent.length) section('Recently used', recent);
      else { var m = document.createElement('div'); m.id = 'empty'; m.textContent = 'Nothing yet - pick a group above or search.'; grid.appendChild(m); }
      return;
    }
    groups.forEach(function (g) {
      if (g[0] === current) section(g[1], all.filter(function (r) { return r[2] === g[0]; }).map(function (r) { return r[0]; }));
    });
  }
  function buildTabs() {
    var list = [['recent', '🕒']].concat(groups.map(function (g) { return [g[0], g[2]]; }));
    list.forEach(function (t) {
      var d = document.createElement('div');
      d.className = 'tab';
      d.textContent = t[1];
      d.setAttribute('data-g', t[0]);
      d.title = t[0] === 'recent' ? 'Recently used' : (groups.filter(function (g) { return g[0] === t[0]; })[0] || ['', ''])[1];
      tabs.appendChild(d);
    });
    mark();
  }
  function mark() {
    Array.prototype.forEach.call(tabs.children, function (d) { d.className = 'tab' + (d.getAttribute('data-g') === current ? ' on' : ''); });
  }
  tabs.addEventListener('click', function (e) {
    var g = e.target.getAttribute && e.target.getAttribute('data-g');
    if (!g) return;
    current = g; q.value = ''; mark(); render(); grid.scrollTop = 0;
  });
  grid.addEventListener('click', function (e) {
    var c = e.target.getAttribute && e.target.getAttribute('data-c');
    if (!c) return;
    remember(c);
    neon.send('insert ' + c);
    if (current === 'recent' && !q.value) render();
  });
  grid.addEventListener('mouseover', function (e) {
    var c = e.target.getAttribute && e.target.getAttribute('data-c');
    foot.textContent = c && byChar[c] ? byChar[c][1] : hint;
  });
  q.addEventListener('input', render);
  current = recent.length ? 'recent' : (groups[0] ? groups[0][0] : 'recent');
  buildTabs();
  render();
  q.focus();
  neon.send('ready');
})();
