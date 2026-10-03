/* NeonScript Theme Studio - the front end.  NeonScript (neon_tedit.mrc) sends the theme being edited and its sample templates;
 * everything here is drawing and picking.  Messages to NeonScript are plain text lines:
 *   ready | load <id> | save|apply|export <payload> | delete <id> | close
 * and its answers are JSON objects: list, tplreset, tpl, edit (the theme), status.  Nothing a page sends is trusted on the other side. */
(function () {
  'use strict';

  /* ------------------------------------------------------------------ data */
  var LABEL = ['Background', 'Action text', 'CTCP text', 'Highlight text', 'Info text', 'Info 2 text', 'Invite text', 'Join text', 'Kick text', 'Mode text',
    'Nick text', 'Normal text', 'Notice text', 'Notify text', 'Other text', 'Own text', 'Part text', 'Quit text', 'Topic text', 'Wallops text', 'Whois text',
    'Edit box', 'Edit box text', 'Nick list', 'Nick list text', 'Gray text (times)', 'Window title text', 'Inactive title', 'Tree bar', 'Tree bar text', 'Window area'];
  var HINT = {
    1: 'Behind all chat text', 2: '/me lines', 3: 'CTCP requests and replies', 4: 'Lines that match your highlight words', 5: 'Server and info messages',
    6: 'Secondary info messages', 7: 'Invitations', 8: 'Joins (mIRC and MTS lines)', 9: 'Kicks (mIRC and MTS lines)', 10: 'Mode changes (mIRC and MTS lines)',
    11: 'Nick changes (mIRC and MTS lines)', 12: 'Ordinary chat text', 13: 'Notices', 14: 'Notify list messages', 15: 'Anything else', 16: 'What you type yourself',
    17: 'Parts (mIRC and MTS lines)', 18: 'Quits (mIRC and MTS lines)', 19: 'Topic changes (mIRC and MTS lines)', 20: 'Wallops', 21: 'WHOIS replies',
    22: 'Background of the text box', 23: 'Text you type', 24: 'Background of the nick list', 25: 'Names in the nick list', 26: 'Time stamps and quiet text',
    27: 'Title text of windows', 28: 'Inactive title bars', 29: 'Background of the tree bar', 30: 'Text in the tree bar', 31: 'Area behind the windows'
  };
  var EV = [['join', 'Join lines'], ['part', 'Part lines'], ['quit', 'Quit lines'], ['kick', 'Kick lines'], ['mode', 'Mode lines'], ['topic', 'Topic lines'],
    ['nick', 'Nick changes'], ['invite', 'Invites'], ['label', 'Labels'], ['value', 'Values'], ['dim', 'Dim text (hosts, reasons)'], ['hi', 'Highlight'],
    ['q', 'Owner (~) names'], ['a', 'Admin (&) names'], ['o', 'Op (@) names'], ['h', 'Halfop (%) names'], ['v', 'Voice (+) names']];
  var EVI = {};
  EV.forEach(function (p, i) { EVI[p[0]] = i; });
  var RANK = { '~': 'q', '&': 'a', '@': 'o', '%': 'h', '+': 'v' };
  var GROUPS = [
    ['Chat', ['c:12', 'c:16', 'c:2', 'c:13', 'c:3', 'c:4', 'c:21', 'c:15', 'c:20', 'c:14', 'c:5', 'c:6', 'c:26']],
    ['Event lines', ['c:8', 'c:17', 'c:18', 'c:9', 'c:10', 'c:19', 'c:11', 'c:7']],
    ['Windows', ['c:1', 'c:22', 'c:23', 'c:24', 'c:25', 'c:29', 'c:30', 'c:31', 'c:27', 'c:28']],
    ['NeonScript lines', ['e:join', 'e:part', 'e:quit', 'e:kick', 'e:mode', 'e:topic', 'e:nick', 'e:invite', 'e:label', 'e:value', 'e:dim', 'e:hi']],
    ['Nick list ranks', ['e:q', 'e:a', 'e:o', 'e:h', 'e:v']],
    ['Accents', ['accent', 'acc1', 'acc2']]
  ];
  /* MTS themes carry the first 26 mIRC colours and one accent; the rest is derived when they are applied */
  var MTS_HIDDEN = /^(c:2[7-9]|c:3[01]|e:.*|n:\d+|acc1|acc2)$/;
  var FIXED = ('470000 472100 474700 324700 004700 00472c 004747 002747 000047 2e0047 470047 47002a 740000 743a00 747400 517400 007400 007449 007474 004074 ' +
    '000074 4b0074 740074 740045 b50000 b56300 b5b500 7db500 00b500 00b571 00b5b5 0063b5 0000b5 7500b5 b500b5 b5006b ff0000 ff8c00 ffff00 b2ff00 00ff00 ' +
    '00ffa0 00ffff 008cff 0000ff a500ff ff00ff ff0098 ff5959 ffb459 ffff71 cfff60 6fff6f 65ffc9 6dffff 59b4ff 5959ff c459ff ff66ff ff59bc ff9c9c ffd39c ' +
    'ffff9c e2ff9c 9cff9c 9cffdb 9cffff 9cd3ff 9c9cff dc9cff ff9cff ff94d3 000000 131313 282828 363636 4d4d4d 656565 818181 9f9f9f bcbcbc e2e2e2 ffffff').split(' ');
  var MIRC_PAL = ['ffffff', '000000', '00007f', '009300', 'ff0000', '7f0000', '9c009c', 'fc7f00', 'ffff00', '00fc00', '009393', '00ffff', '0000fc', 'ff00ff', '7f7f7f', 'd2d2d2'];
  var GLYPH = { join: '→', part: '←', quit: '✕', kick: '✖', nick: '⇄', mode: '✦', topic: '✎', invite: '✉' };
  var MINI = { join: '+', part: '-', quit: '-', kick: '!', nick: '~', mode: '*', topic: '*', invite: '+' };
  var BOLD = '\x02', COL = '\x03', RESET = '\x0f', REV = '\x16', ITAL = '\x1d', UND = '\x1f';
  var DEF_EV = [68, 77, 85, 64, 65, 81, 71, 69, 94, 97, 93, 54, 74, 64, 68, 71, 66];
  var DEF_NICK = [64, 65, 66, 68, 69, 70, 71, 73, 74, 75, 77, 80, 84, 85];

  /* ------------------------------------------------------------------ state */
  var S = null, BASE = null, LIST = [], TPL = {}, sel = 'c:12', hist = [], style = 'modern', slotMode = false;
  var $ = function (id) { return document.getElementById(id); };

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function two(n) { return (n < 10 ? '0' : '') + n; }
  function clone(o) { return JSON.parse(JSON.stringify(o)); }
  function hex6(h) { return /^#?[0-9a-fA-F]{6}$/.test(String(h)) ? String(h).replace('#', '').toLowerCase() : null; }
  function palHex(i) {
    i = +i;
    if (i >= 0 && i < 16) return '#' + (S ? S.pal[i] : MIRC_PAL[i]);
    if (i >= 16 && i <= 98) return '#' + FIXED[i - 16];
    return '#ffffff';
  }
  function rgb(h) { h = h.replace('#', ''); return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)]; }
  function dist(a, b) {
    var rm = (a[0] + b[0]) / 2, dr = a[0] - b[0], dg = a[1] - b[1], db = a[2] - b[2];
    return (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db;
  }
  function nearest(h) {
    var t = rgb(h), best = 0, bd = 1e12;
    for (var i = 0; i <= 98; i++) {
      var d = dist(t, rgb(palHex(i)));
      if (d < bd) { bd = d; best = i; }
    }
    return best;
  }
  var crcT = null;
  function crc32(s) {
    if (!crcT) { crcT = []; for (var n = 0; n < 256; n++) { var c = n; for (var k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); crcT[n] = c >>> 0; } }
    var crc = 0xFFFFFFFF;
    for (var i = 0; i < s.length; i++) crc = crcT[(crc ^ s.charCodeAt(i)) & 255] ^ (crc >>> 8);
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }
  /* the same pick NeonScript makes: crc32 of the lower-case nick modulo the number of nick colours */
  function nickSlot(nick) { return crc32(nick.toLowerCase()) % (S.nick.length || 1); }
  function nickIdx(nick) { return S.nick[nickSlot(nick)]; }

  /* a key is "c:12" (mIRC item), "e:join" (NeonScript line colour), "accent" (palette index) or "acc1"/"acc2" (any colour) */
  function isHexKey(k) { return k === 'acc1' || k === 'acc2'; }
  function idxOf(k, from) {
    var o = from || S;
    if (k.charAt(0) === 'c') return o.c[+k.substr(2) - 1];
    if (k.charAt(0) === 'e') return o.e[EVI[k.substr(2)]];
    if (k.charAt(0) === 'n') return o.nick[+k.substr(2)];
    if (k === 'accent') return o.accent;
    return -1;
  }
  function hexOf(k) { return isHexKey(k) ? '#' + S[k] : palHex(idxOf(k)); }
  function nameOf(k) {
    if (k.charAt(0) === 'c') return LABEL[+k.substr(2) - 1];
    if (k.charAt(0) === 'e') return EV[EVI[k.substr(2)]][1];
    if (k.charAt(0) === 'n') return 'Nick colour ' + (+k.substr(2) + 1) + ' of ' + S.nick.length;
    return { accent: 'Highlight accent', acc1: 'Accent 1 (gradients, frames)', acc2: 'Accent 2 (gradients)' }[k];
  }
  function hintOf(k) {
    if (k.charAt(0) === 'c') return HINT[+k.substr(2)] || '';
    if (k.charAt(0) === 'e') return 'NeonScript\'s own event lines and nick list';
    if (k.charAt(0) === 'n') return 'Names get one of these colours, picked by a hash of the nick';
    return { accent: 'NeonScript highlights, menus and boxes (a palette colour)', acc1: 'Toolbar glow, window frame and menu border', acc2: 'Second colour of NeonScript gradients' }[k];
  }
  function visible(k) { return !(S && S.kind === 'mts' && MTS_HIDDEN.test(k)); }
  function setIdx(k, v) {
    if (k.charAt(0) === 'c') S.c[+k.substr(2) - 1] = v;
    else if (k.charAt(0) === 'e') S.e[EVI[k.substr(2)]] = v;
    else if (k.charAt(0) === 'n') S.nick[+k.substr(2)] = v;
    else if (k === 'accent') { S.accent = v; S.acc1 = palHex(v).substr(1); }
    if (S.kind === 'mts') derive();
  }
  /* what ns.mts.apply derives from the 26 colours: title text, inactive, tree bar, tree bar text, window area */
  function derive() {
    S.c[26] = S.c[11]; S.c[27] = S.c[25]; S.c[28] = S.c[0]; S.c[29] = S.c[11]; S.c[30] = S.c[0];
    var b = S.base4 || (S.base4 = [15, 12, 8, 14]), t = b[0], nk = S.accent, hi = b[2], br = b[3];
    b[1] = nk;
    S.e = [9, 7, 4, 4, hi, 11, nk, 10, br, t, br, hi, 13, 4, 9, 11, 8];
    var l = rgb(palHex(S.c[0]));
    S.mode = (l[0] + l[1] + l[2]) < 384 ? 'dark' : 'light';
  }

  /* ------------------------------------------------------------------ undo / dirty */
  function snap() { return JSON.stringify({ c: S.c, e: S.e, accent: S.accent, acc1: S.acc1, acc2: S.acc2, nick: S.nick, pal: S.pal, pc: S.pc, mode: S.mode, name: S.name }); }
  function push() { hist.push(snap()); if (hist.length > 60) hist.shift(); }
  function undo() {
    if (!hist.length) return;
    var o = JSON.parse(hist.pop());
    for (var k in o) S[k] = o[k];
    $('name').value = S.name;
    syncMode();
    refresh(true, true);
  }
  function dirty() { return !!BASE && snap() !== BASE.snap; }
  function changed(k) {
    if (!BASE) return false;
    return isHexKey(k) ? S[k] !== BASE.o[k] : idxOf(k) !== idxOf(k, BASE.o);
  }

  /* ------------------------------------------------------------------ left column: the items */
  function buildItems() {
    var box = $('items');
    box.textContent = '';
    GROUPS.forEach(function (g) {
      var keys = g[1].filter(visible);
      if (!keys.length) return;
      box.appendChild(el('h3', null, g[0]));
      keys.forEach(function (k) {
        var r = el('div', 'row');
        r.setAttribute('data-k', k);
        r.title = hintOf(k);
        r.appendChild(el('span', 'sw')); r.appendChild(el('span', 'nm', nameOf(k))); r.appendChild(el('span', 'ix')); r.appendChild(el('span', 'chg'));
        box.appendChild(r);
      });
    });
    if (S.kind !== 'mts') {
      box.appendChild(el('h3', null, 'Nick colours'));
      var chips = el('div', 'chips');
      S.nick.forEach(function (v, i) { var c = el('span', 'chip'); c.setAttribute('data-k', 'n:' + i); chips.appendChild(c); });
      box.appendChild(chips);
      box.appendChild(el('div', 'note', 'Every name gets one of these, picked by a hash of the nick. Click a name in the picture to see which.'));
    }
    paintItems();
  }
  function paintItems() {
    Array.prototype.forEach.call($('items').querySelectorAll('.chip'), function (c) {
      var k = c.getAttribute('data-k');
      c.style.setProperty('--c', hexOf(k));
      c.className = 'chip' + (k === sel ? ' on' : '') + (changed(k) ? ' chg' : '');
      c.title = idxOf(k) + '  ' + hexOf(k);
    });
    Array.prototype.forEach.call($('items').querySelectorAll('.row'), function (r) {
      var k = r.getAttribute('data-k');
      r.children[0].style.setProperty('--c', hexOf(k));
      r.children[2].textContent = isHexKey(k) ? '#' + S[k] : idxOf(k);
      r.children[3].className = 'chg' + (changed(k) ? ' on' : '');
      r.className = 'row' + (k === sel ? ' on' : '');
    });
  }

  /* ------------------------------------------------------------------ right column: picking */
  function buildPalette() {
    var c = $('custom'), g = $('grid'), i;
    c.textContent = ''; g.textContent = '';
    for (i = 0; i < 16; i++) { var s = el('div', 'pc slot'); s.setAttribute('data-i', i); c.appendChild(s); }
    for (i = 16; i <= 98; i++) { var t = el('div', 'pc'); t.setAttribute('data-i', i); g.appendChild(t); }
  }
  function paintPalette() {
    var cur = (sel && !isHexKey(sel)) ? idxOf(sel) : -1;
    Array.prototype.forEach.call(document.querySelectorAll('.pc'), function (p) {
      var i = +p.getAttribute('data-i');
      p.style.setProperty('--c', palHex(i));
      p.className = 'pc' + (i < 16 ? ' slot' : '') + (i === cur ? ' cur' : '') + (i < 16 && !S.pc ? ' off' : '');
      p.title = i + '  ' + palHex(i) + (i < 16 && S.pc && slotMode ? '  (click to change this colour)' : '');
    });
    $('pc').checked = !!S.pc;
    $('slotMode').className = (S.pc ? '' : 'hide ') + (slotMode ? 'on' : '');
    $('palNote').textContent = S.pc
      ? (slotMode ? 'Click one of colours 0-15 to change what it looks like.' : 'These 16 belong to this theme. "Use exactly" adds a colour that is not in the list; "Change a colour" edits one of them directly.')
      : 'The first 16 colours are the ones most chat uses. Give this theme its own set to use exact colours - anything else that uses those numbers changes with them.';
  }
  function paintCurrent(sync) {
    var k = sel, h = hexOf(k);
    $('curSw').style.setProperty('--c', h);
    $('curName').textContent = nameOf(k);
    $('curVal').textContent = isHexKey(k) ? h : idxOf(k) + '  ·  ' + h;
    $('curHint').textContent = hintOf(k);
    $('curHint').title = hintOf(k);
    if (sync) { $('picker').value = h; $('hex').value = h; }
    anyUpdate();
  }
  function anyUpdate() {
    var h = $('picker').value, n = nearest(h);
    $('nearSw').style.setProperty('--c', palHex(n));
    $('nearTxt').textContent = 'closest: ' + n + '  ' + palHex(n);
    $('useNear').disabled = isHexKey(sel);
    $('useExact').disabled = isHexKey(sel);
  }

  /* ------------------------------------------------------------------ editing */
  function assign(k, i) {
    if (i < 0 || i > 98) return;
    push();
    if (isHexKey(k)) S[k] = palHex(i).substr(1); else setIdx(k, i);
    refresh(false, true);
  }
  function setHexKey(k, h) {
    h = hex6(h);
    if (!h || !isHexKey(k)) return;
    S[k] = h;
    refresh(false, false);
  }
  /* the exact colour goes into a custom slot: the item's own when nothing else uses it, else the least used one */
  function usage(i) {
    var n = 0, f = function (v) { if (v === i) n++; };
    S.c.forEach(f); S.e.forEach(f); f(S.accent); S.nick.forEach(f); (S.base4 || []).forEach(f);
    return n;
  }
  function exactSlot(k) {
    var cur = idxOf(k), best = 0, bu = 1e9, i;
    if (cur >= 0 && cur < 16 && usage(cur) <= 1) return cur;
    for (i = 0; i < 16; i++) { var u = usage(i); if (u < bu) { bu = u; best = i; } }
    return best;
  }
  function useExact(h) {
    h = hex6(h);
    if (!h || isHexKey(sel)) return;
    push();
    S.pc = true;
    var slot = exactSlot(sel);
    S.pal[slot] = h;
    setIdx(sel, slot);
    refresh(false, true);
    status('Colour ' + slot + ' is now #' + h + ' (one of this theme\'s own 16 colours).', true);
  }
  function select(k) {
    if (!k || !visible(k)) return;
    sel = k;
    paintItems(); paintPalette(); paintCurrent(true); markSel();
    var row = $('items').querySelector('.row.on');
    if (row && row.scrollIntoView) row.scrollIntoView({ block: 'nearest' });
  }
  function refresh(full, sync) {
    if (full) buildItems();
    paintItems(); paintPalette(); paintCurrent(!!sync); renderMock();
    $('dirty').className = dirty() ? 'on' : '';
    $('del').disabled = !S.mine;
  }
  function syncMode() {
    Array.prototype.forEach.call($('mode').children, function (b) { b.className = b.getAttribute('data-v') === S.mode ? 'on' : ''; });
  }

  /* ------------------------------------------------------------------ the mock-up */
  function setVars() {
    var m = $('mock'), i;
    for (i = 1; i <= 31; i++) m.style.setProperty('--c' + i, palHex(S.c[i - 1]));
    EV.forEach(function (p, j) { m.style.setProperty('--e-' + p[0], palHex(S.e[j])); });
    m.style.setProperty('--acc1', '#' + S.acc1);
    m.style.setProperty('--acc2', '#' + S.acc2);
    m.style.setProperty('--acc', palHex(S.accent));
    m.style.fontFamily = (S.font ? '"' + S.font.replace(/[^A-Za-z0-9 _-]/g, '') + '", ' : '') + 'Consolas, "Cascadia Mono", monospace';
  }
  function sp(parent, text, k, color, cls) {
    var s = el('span', cls || null, text);
    if (k) s.setAttribute('data-k', k);
    if (color) s.style.color = color;
    parent.appendChild(s);
    return s;
  }
  function evc(parent, text, key, cls) { return sp(parent, text, 'e:' + key, 'var(--e-' + key + ')', cls); }
  function nk(parent, nick, rank) {
    if (rank) evc(parent, rank, RANK[rank]);
    return sp(parent, nick, 'n:' + nickSlot(nick), palHex(nickIdx(nick)), 'nick');
  }
  function pre(parent, type) {
    if (style === 'retro') return evc(parent, '-!- ', 'dim');
    return evc(parent, (style === 'minimal' ? MINI[type] : GLYPH[type]) + ' ', type);
  }
  function host(parent, h) {
    var retro = style === 'retro';
    evc(parent, ' ' + (retro ? '[' : '(') + h + (retro ? ']' : ')'), 'dim');
  }

  /* mIRC control codes -> spans (the way an MTS template is drawn) */
  function codes(parent, str, defKey) {
    var fg = null, bg = null, b = false, u = false, r = false, it = false, i = 0, buf = '';
    function flush() {
      if (!buf) return;
      var s = el('span', null, buf), f = fg, g = bg;
      if (r) { var t = f; f = g; g = t; if (f == null) f = S.c[0]; if (g == null) g = S.c[11]; }
      if (f != null) s.style.color = palHex(f);
      if (g != null) s.style.backgroundColor = palHex(g);
      s.className = (b ? 'b ' : '') + (u ? 'u' : '');
      if (it) s.style.fontStyle = 'italic';
      s.setAttribute('data-k', defKey);
      parent.appendChild(s);
      buf = '';
    }
    function num(v) { v = +v; return v === 99 || v > 98 ? null : v; }
    while (i < str.length) {
      var ch = str.charAt(i);
      if (ch === COL) {
        flush();
        var m = /^(\d{1,2})(?:,(\d{1,2}))?/.exec(str.substr(i + 1));
        if (m) { i += 1 + m[0].length; fg = num(m[1]); if (m[2] != null) bg = num(m[2]); }
        else { i++; fg = null; bg = null; }
        continue;
      }
      if (ch === BOLD) { flush(); b = !b; i++; continue; }
      if (ch === UND) { flush(); u = !u; i++; continue; }
      if (ch === REV) { flush(); r = !r; i++; continue; }
      if (ch === ITAL) { flush(); it = !it; i++; continue; }
      if (ch === RESET) { flush(); fg = bg = null; b = u = r = it = false; i++; continue; }
      buf += ch; i++;
    }
    flush();
  }

  /* the MTS token engine, as in neon_mts.mrc */
  var KNOWN = 'lt gt c1 c2 c3 c4 nick address chan cmode cnick target knick kaddress newnick modes text parentext ctcp pre timestamp comments numeric value fromserver users away realname isoper operline isregd wserver serverinfo idletime signontime b u r o k'.split(' ');
  function tokVal(t, v) {
    switch (t) {
      case 'lt': return '<'; case 'gt': return '>';
      case 'b': return BOLD; case 'u': return UND; case 'r': return REV; case 'o': return RESET; case 'k': return COL;
      case 'c1': case 'c2': case 'c3': case 'c4': return COL + two((S.base4 || [15, 12, 8, 14])[+t.charAt(1) - 1]);
      case 'pre': return S.prefix || '*';
      case 'timestamp': return '12:01';
      case 'cnick': return two(nickIdx(v.nick || 'Nova'));
      case 'parentext': return v.text ? '(' + v.text + ')' : '';
      case 'comments': return '';
      default: return v[t] != null ? v[t] : '';
    }
  }
  function expand(tpl, v) {
    var out = '', i = 0;
    while (i < tpl.length) {
      var lt = tpl.indexOf('<', i);
      if (lt < 0) { out += tpl.substr(i); break; }
      out += tpl.substring(i, lt);
      var gt = tpl.indexOf('>', lt), tok = (gt > 0 && gt - lt <= 13) ? tpl.substring(lt + 1, gt) : '';
      if (tok && tok.indexOf(' ') < 0 && KNOWN.indexOf(tok.toLowerCase()) >= 0) { out += tokVal(tok.toLowerCase(), v); i = gt + 1; }
      else { out += '<'; i = lt + 1; }
    }
    return out;
  }
  function vals(o) {
    var v = { nick: 'Nova', address: 'nova@host.example', chan: '#neon', cmode: '@', target: '#neon', knick: 'Zed', kaddress: 'zed@zed.example', newnick: 'Nova2', modes: '+o Kira', ctcp: 'VERSION',
      text: '', numeric: '311', value: 'sample', fromserver: 'irc.example.net', users: '@Kira +Zed Nova', away: 'gone for a while', realname: 'Nova Example', wserver: 'irc.example.net',
      serverinfo: 'Example IRC network', idletime: '2 mins', signontime: 'Fri Oct 02 12:00', isoper: '', operline: '', isregd: '' };
    for (var k in o) v[k] = o[k];
    return v;
  }
  function tplOf(t) { return TPL[t] || TPL[t.replace(/self$/, '')] || ''; }

  /* one sample line.  r = { t: template key, ts, k: item, o: token values, modern: function (line) } */
  function addLine(box, r) {
    var useT = style === 'mts' && tplOf(r.t), d = el('div', 'ln');
    d.setAttribute('data-k', r.k);
    d.style.color = hexOf(r.k);
    sp(d, r.ts, 'c:26', null, 'ts');
    if (useT) codes(d, expand(tplOf(r.t), vals(r.o)), r.tk || r.k);
    else r.modern(d);
    box.appendChild(d);
  }
  var ROWS = [
    { t: 'join', ts: '12:01', k: 'e:join', tk: 'c:8', o: { nick: 'Nova', cmode: '' }, modern: function (d) { pre(d, 'join'); nk(d, 'Nova'); host(d, 'nova@host.example'); evc(d, ' ' + (style === 'retro' ? 'has joined #neon' : 'joined'), 'join'); } },
    { t: 'textchan', ts: '12:01', k: 'c:12', o: { nick: 'Nova', cmode: '', text: 'hey everyone, nice to be here' }, modern: function (d) { sp(d, '<', 'c:12'); nk(d, 'Nova'); sp(d, '> hey everyone, nice to be here', 'c:12'); } },
    { t: 'textchan', ts: '12:02', k: 'c:16', tk: 'c:12', o: { nick: 'TestNick', cmode: '@', text: 'thanks, glad to be here' }, modern: function (d) { sp(d, '<', 'c:16'); sp(d, 'TestNick', 'c:16', null, 'nick'); sp(d, '> thanks, glad to be here', 'c:16'); } },
    { t: 'textchan', ts: '12:03', k: 'c:4', tk: 'c:12', o: { nick: 'Kira', cmode: '@', text: 'TestNick: your build is ready' }, modern: function (d) { sp(d, '<', 'c:4'); sp(d, 'Kira', 'c:4', null, 'nick'); sp(d, '> TestNick: your build is ready', 'c:4'); } },
    { t: 'actionchan', ts: '12:04', k: 'c:2', o: { nick: 'Nova', text: 'raises a glass' }, modern: function (d) { sp(d, '* Nova raises a glass', 'c:2'); } },
    { t: 'mode', ts: '12:05', k: 'e:mode', tk: 'c:10', o: { nick: 'Owner', cmode: '~', modes: '+o Nova' }, modern: function (d) {
      pre(d, 'mode'); nk(d, 'Owner', '~'); evc(d, ' gives ', 'mode'); evc(d, '@ ', 'o'); evc(d, 'op', 'o'); evc(d, ' to ', 'mode'); nk(d, 'Nova'); } },
    { t: 'topic', ts: '12:06', k: 'e:topic', tk: 'c:19', o: { nick: 'Nova', cmode: '@', text: 'Welcome to NeonScript' }, modern: function (d) {
      pre(d, 'topic'); nk(d, 'Nova', '@'); evc(d, ' changed the topic to: ', 'topic'); evc(d, 'Welcome to NeonScript', 'value'); } },
    { t: 'kick', ts: '12:07', k: 'e:kick', tk: 'c:9', o: { nick: 'Owner', cmode: '~', knick: 'Kira', text: 'behave' }, modern: function (d) {
      pre(d, 'kick'); nk(d, 'Kira'); evc(d, ' was kicked by ', 'kick', 'b'); nk(d, 'Owner', '~'); evc(d, ' (', 'dim'); evc(d, 'behave', 'kick'); evc(d, ')', 'dim'); } },
    { t: 'noticechan', ts: '12:08', k: 'c:13', o: { nick: 'Admin', cmode: '', text: 'maintenance at midnight' }, modern: function (d) { sp(d, '-Admin:#neon- maintenance at midnight', 'c:13'); } },
    { t: 'part', ts: '12:09', k: 'e:part', tk: 'c:17', o: { nick: 'Kira', address: 'kira@irc.example', text: 'Gone fishing' }, modern: function (d) {
      pre(d, 'part'); nk(d, 'Kira'); host(d, 'kira@irc.example'); evc(d, ' ' + (style === 'retro' ? 'has left #neon' : 'left'), 'part'); evc(d, ' (Gone fishing)', 'dim'); } },
    { t: 'quit', ts: '12:10', k: 'e:quit', tk: 'c:18', o: { nick: 'Zed', address: 'zed@zed.example', text: 'Ping timeout' }, modern: function (d) {
      pre(d, 'quit'); nk(d, 'Zed'); host(d, 'zed@zed.example'); evc(d, ' ' + (style === 'retro' ? 'has quit' : 'quit'), 'quit'); evc(d, ' (Ping timeout)', 'dim'); } },
    { t: 'nick', ts: '12:11', k: 'e:nick', tk: 'c:11', o: { nick: 'Nova', newnick: 'Nova2' }, modern: function (d) { pre(d, 'nick'); nk(d, 'Nova'); evc(d, ' is now known as ', 'nick'); nk(d, 'Nova2'); } },
    { t: 'invite', ts: '12:12', k: 'e:invite', tk: 'c:7', o: { nick: 'Kira', chan: '#staff', cmode: '' }, modern: function (d) { pre(d, 'invite'); nk(d, 'Kira'); evc(d, ' invited you to ', 'invite'); evc(d, '#staff', 'invite', 'b'); } },
    { t: 'x', ts: '12:13', k: 'c:26', modern: function (d) { sp(d, '(gray text: time stamps and other quiet bits)', 'c:26'); } }
  ];
  function renderLines() {
    var box = $('mock').querySelector('.m-lines');
    box.textContent = '';
    ROWS.forEach(function (r) { addLine(box, r); });
  }
  function renderMock() {
    var m = $('mock');
    if (!S) return;
    setVars();
    m.textContent = '';
    var light = S.mode === 'light';
    var t = el('div', 'm-title blk' + (light ? ' light' : '')); t.setAttribute('data-k', 'c:27');
    t.appendChild(el('span', 'dot')); t.lastChild.setAttribute('data-k', 'c:28');
    t.appendChild(el('span', null, 'mIRC NeonScript :: MockNet - #neon'));
    m.appendChild(t);
    var bar = el('div', 'm-bar' + (light ? ' light' : ''));
    ['acc1', 'acc2', 'accent', 'acc1', 'acc2', null, 'accent', 'acc1', 'acc2', 'accent', null, 'acc1', 'acc2', 'accent'].forEach(function (c) {
      var i = el('span', c ? 'ic' : 'gap');
      if (c) { i.style.setProperty('--ic', c === 'accent' ? 'var(--acc)' : 'var(--' + c + ')'); i.setAttribute('data-k', c); }
      bar.appendChild(i);
    });
    m.appendChild(bar);
    var work = el('div', 'm-work');
    var tree = el('div', 'm-tree blk'); tree.setAttribute('data-k', 'c:29');
    [['MockNet  TestNick', '', ''], ['Status', 'ind', ''], ['#neon', 'ind cur', 'r2'], ['#staff', 'ind', 'b14'], ['Kira', 'ind', 'b3']].forEach(function (r) {
      var d = el('div', 't ' + r[1]), n = el('span', null, r[0]); n.setAttribute('data-k', 'c:30'); d.appendChild(n);
      if (r[2]) d.appendChild(el('span', 'pill ' + r[2].charAt(0), r[2].substr(1)));
      tree.appendChild(d);
    });
    work.appendChild(tree);
    var mdi = el('div', 'm-mdi blk'); mdi.setAttribute('data-k', 'c:31');
    var win = el('div', 'm-win');
    var wt = el('div', 'm-wtitle blk', '#neon (9) [+nt]: Welcome to NeonScript'); wt.setAttribute('data-k', 'c:28'); win.appendChild(wt);
    var chat = el('div', 'm-chat'), lines = el('div', 'm-lines blk'), nicks = el('div', 'm-nicks blk');
    lines.setAttribute('data-k', 'c:1'); nicks.setAttribute('data-k', 'c:24');
    [['~', 'Owner'], ['&', 'Admin'], ['@', 'Kira'], ['@', 'TestNick'], ['%', 'Half'], ['+', 'Zed', 1], ['', 'Nova'], ['', 'Clone1']].forEach(function (n) {
      var d = el('div', 'n' + (n[2] ? ' away' : ''));
      if (n[0]) evc(d, n[0], RANK[n[0]]);
      sp(d, n[1], n[2] ? 'c:26' : 'c:25');
      nicks.appendChild(d);
    });
    chat.appendChild(lines); chat.appendChild(nicks); win.appendChild(chat);
    var edit = el('div', 'm-edit blk'); edit.setAttribute('data-k', 'c:22');
    sp(edit, '/neon themeedit', 'c:23'); edit.appendChild(el('span', 'caret'));
    win.appendChild(edit);
    mdi.appendChild(win); work.appendChild(mdi); m.appendChild(work);
    renderLines();
    markSel();
  }
  function markSel() {
    Array.prototype.forEach.call($('mock').querySelectorAll('.sel'), function (e) { e.classList.remove('sel'); });
    Array.prototype.forEach.call($('mock').querySelectorAll('[data-k="' + sel + '"]'), function (e) { e.classList.add('sel'); });
  }

  /* ------------------------------------------------------------------ themes in and out */
  function fillBase(cur) {
    var b = $('base'), names = { builtin: 'Built-in', holiday: 'Holidays', user: 'My themes', mts: 'Imported (MTS)' }, g = {};
    b.textContent = '';
    LIST.forEach(function (t) {
      var kind = (t.kind === 'builtin' && /^h_/.test(t.id)) ? 'holiday' : t.kind;      /* the holiday themes have their own group */
      var og = g[kind];
      if (!og) { og = el('optgroup'); og.label = names[kind] || kind; g[kind] = og; b.appendChild(og); }
      var o = el('option', null, (t.mine ? '* ' : '') + t.name);
      o.value = t.id;
      og.appendChild(o);
    });
    if (cur) b.value = cur;
  }
  function loadTheme(t) {
    var ints = function (a, min, d, max) { var r = (a || []).map(Number).filter(function (x) { return x >= 0 && x <= 98 && x === Math.floor(x); }); return r.length >= min ? r.slice(0, max) : d.slice(); };
    S = {
      id: String(t.id), kind: t.kind, mine: !!t.mine, name: String(t.name || ''), desc: String(t.desc || ''), mode: t.mode === 'light' ? 'light' : 'dark',
      c: ints(t.c, 31, new Array(31).fill(0), 31), e: ints(t.e, 17, DEF_EV, 17), accent: Math.max(0, Math.min(98, +t.accent || 0)),
      acc1: hex6(t.acc1) || 'ff2e88', acc2: hex6(t.acc2) || '2ee6ff', nick: ints(t.nick, 1, DEF_NICK, 24),
      pal: (t.pal && t.pal.length === 16) ? t.pal.map(function (h) { return hex6(h) || '000000'; }) : MIRC_PAL.slice(), pc: !!t.pc,
      pal0: (t.pal0 && t.pal0.length === 16) ? t.pal0.map(function (h) { return hex6(h) || '000000'; }) : MIRC_PAL.slice(),
      base4: t.base4 && t.base4.length === 4 ? t.base4.map(Number) : null, prefix: String(t.prefix || '').slice(0, 12), font: String(t.font || '')
    };
    if (S.kind === 'mts') derive();
    BASE = { o: clone({ c: S.c, e: S.e, accent: S.accent, acc1: S.acc1, acc2: S.acc2, nick: S.nick }), snap: snap() };
    hist = [];
    var haveT = Object.keys(TPL).length > 0;
    style = S.kind === 'mts' && haveT ? 'mts' : (style === 'mts' ? 'modern' : style);
    $('name').value = S.name;
    $('tag').textContent = S.kind === 'mts' ? 'Imported MTS theme - its line layouts stay, the colours are yours to change.'
      : (S.kind === 'user' ? 'Your own theme.' : 'Built-in theme - saving makes your own copy.');
    $('modegrp').className = 'grp' + (S.kind === 'mts' ? ' hide' : '');
    $('save').textContent = S.kind === 'mts' ? 'Save as MTS copy' : 'Save';
    $('base').value = S.id;
    if (!visible(sel)) sel = 'c:12';
    syncMode();
    Array.prototype.forEach.call($('style').children, function (b) {
      var v = b.getAttribute('data-v');
      b.className = (v === 'mts' && S.kind !== 'mts' ? 'hide ' : '') + (v === style ? 'on' : '');
    });
    slotMode = false;
    buildItems();
    buildPalette();
    refresh(false, true);
    select(sel);
  }

  function payload() {
    var f = function (a) { return a.join(','); };
    return 'kind=' + S.kind + ' base=' + S.id + ' mode=' + S.mode + ' accent=' + S.accent + ' acc1=' + S.acc1 + ' acc2=' + S.acc2 + ' pc=' + (S.pc ? 1 : 0) +
      ' c=' + f(S.c) + ' e=' + f(S.e) + ' pal=' + f(S.pal) + ' nick=' + f(S.nick) + ' name=' + S.name.replace(/[\u0000-\u001f]/g, ' ').trim();
  }
  function status(text, ok) {
    var s = $('status');
    s.textContent = text || '';
    s.className = ok === true ? 'ok' : (ok === false ? 'bad' : '');
  }
  function veil(text, yes) {
    $('veilTxt').textContent = text;
    $('veil').className = 'on';
    $('veilYes').onclick = function () { $('veil').className = ''; yes(); };
    $('veilNo').onclick = function () { $('veil').className = ''; };
  }
  function guarded(next) {
    if (S && dirty()) veil('You have unsaved changes to "' + S.name + '". Discard them?', next); else next();
  }
  function typing() {
    var a = document.activeElement;
    return !!a && (a.tagName === 'INPUT' && a.type === 'text' || a.tagName === 'SELECT' || a.tagName === 'TEXTAREA');
  }

  /* ------------------------------------------------------------------ wiring */
  function wire() {
    $('items').addEventListener('click', function (e) { var r = e.target.closest && e.target.closest('.row, .chip'); if (r) select(r.getAttribute('data-k')); });
    $('mock').addEventListener('click', function (e) { var n = e.target.closest && e.target.closest('[data-k]'); if (n) select(n.getAttribute('data-k')); });
    $('side').addEventListener('click', function (e) {
      var p = e.target.closest && e.target.closest('.pc');
      if (!p || !S) return;
      var i = +p.getAttribute('data-i');
      if (i < 16 && S.pc && slotMode) { editSlot(i); return; }
      assign(sel, i);
    });
    $('side').addEventListener('mouseover', function (e) {
      var p = e.target.closest && e.target.closest('.pc');
      if (p && S && !isHexKey(sel)) $('curVal').textContent = 'colour ' + p.getAttribute('data-i') + '  ·  ' + palHex(+p.getAttribute('data-i'));
    });
    $('side').addEventListener('mouseout', function (e) { if (S && e.target.closest && e.target.closest('.pc')) paintCurrent(false); });
    var pk = $('picker');
    pk.addEventListener('input', function () {
      if (!S) return;
      var slot = pk.getAttribute('data-slot'), h = hex6(pk.value);
      if (!h) return;
      if (slot) { S.pal[+slot] = h; refresh(false, false); return; }
      $('hex').value = '#' + h;
      anyUpdate();
      if (isHexKey(sel)) setHexKey(sel, h);
    });
    pk.addEventListener('mousedown', function () { pk.removeAttribute('data-slot'); if (S && isHexKey(sel)) push(); });
    $('hex').addEventListener('input', function () {
      var h = hex6($('hex').value);
      if (!h || !S) return;
      $('picker').value = '#' + h;
      anyUpdate();
      if (isHexKey(sel)) { push(); setHexKey(sel, h); }
    });
    $('useNear').addEventListener('click', function () { if (S) assign(sel, nearest($('picker').value)); });
    $('useExact').addEventListener('click', function () { if (S) useExact($('picker').value); });
    $('slotMode').addEventListener('click', function () { if (S && S.pc) { slotMode = !slotMode; paintPalette(); } });
    $('pc').addEventListener('change', function () {
      if (!S) return;
      push();
      S.pc = $('pc').checked;
      if (!S.pc) { S.pal = S.pal0.slice(); slotMode = false; }
      refresh(false, true);
    });
    $('undo').addEventListener('click', undo);
    $('reset').addEventListener('click', function () {
      if (!BASE || !S) return;
      push();
      if (isHexKey(sel)) S[sel] = BASE.o[sel];
      else setIdx(sel, idxOf(sel, BASE.o));
      refresh(false, true);
    });
    $('name').addEventListener('input', function () { if (S) { S.name = $('name').value; $('dirty').className = dirty() ? 'on' : ''; } });
    $('mode').addEventListener('click', function (e) {
      var v = e.target.getAttribute && e.target.getAttribute('data-v');
      if (!v || !S) return;
      push(); S.mode = v; syncMode(); refresh(false, false);
    });
    $('style').addEventListener('click', function (e) {
      var v = e.target.getAttribute && e.target.getAttribute('data-v');
      if (!v || !S) return;
      style = v;
      Array.prototype.forEach.call($('style').children, function (b) { b.className = (b.className.indexOf('hide') >= 0 ? 'hide ' : '') + (b.getAttribute('data-v') === style ? 'on' : ''); });
      renderMock();
    });
    $('base').addEventListener('change', function () {
      var id = $('base').value, back = S ? S.id : id;
      if (S && dirty()) { $('base').value = back; veil('You have unsaved changes to "' + S.name + '". Discard them?', function () { neon.send('load ' + id); }); }
      else neon.send('load ' + id);
    });
    $('save').addEventListener('click', function () { if (S) { status('Saving...'); neon.send('save ' + payload()); } });
    $('apply').addEventListener('click', function () { if (S) { status('Saving and applying...'); neon.send('apply ' + payload()); } });
    $('export').addEventListener('click', function () { if (S) neon.send('export ' + payload()); });
    $('del').addEventListener('click', function () { if (S && S.mine) veil('Delete "' + S.name + '" for good?', function () { neon.send('delete ' + S.id); }); });
    $('close').addEventListener('click', function () { guarded(function () { neon.send('close'); }); });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {            /* never close with unsaved work by accident (common.js would send "close") */
        e.stopPropagation();
        if ($('veil').className === 'on') { $('veil').className = ''; return; }
        guarded(function () { neon.send('close'); });
        return;
      }
      if ((e.ctrlKey || e.metaKey) && (e.key === 'z' || e.key === 'Z') && !typing()) { e.preventDefault(); undo(); return; }
      if ((e.key === 'e' || e.key === 'E') && !e.ctrlKey && !e.metaKey && !typing() && S && S.pc) { slotMode = !slotMode; paintPalette(); }
    }, true);
  }
  /* change one of the 16 custom colours with the system colour picker */
  function editSlot(i) {
    var pk = $('picker');
    slotMode = false;
    pk.setAttribute('data-slot', i);
    pk.value = palHex(i);
    paintPalette();
    pk.click();
  }

  /* ------------------------------------------------------------------ NeonScript talking to us */
  var PEND = {};
  function nums(s) { return String(s || '').split(',').filter(function (x) { return x !== ''; }).map(Number); }
  function strs(s) { return String(s || '').split(',').filter(function (x) { return x !== ''; }); }
  neon.onmessage = function (m) {
    if (m.type === 'listreset') { LIST = []; }
    else if (m.type === 'item') { LIST.push({ id: String(m.id), name: String(m.name), kind: String(m.kind), mine: +m.mine }); }
    else if (m.type === 'listend') { fillBase(m.cur); }
    else if (m.type === 'tplreset') { TPL = {}; }
    else if (m.type === 'tpl') { if (/^[a-z]+$/.test(String(m.k))) TPL[m.k] = String(m.v); }
    else if (m.type === 'set') { PEND[String(m.k)] = String(m.v); }
    else if (m.type === 'editend') {
      var P = PEND;
      PEND = {};
      loadTheme({ id: P.id, kind: P.kind, mine: +P.mine, name: P.name, desc: P.desc, mode: P.mode, accent: +P.accent, acc1: P.acc1, acc2: P.acc2,
        c: nums(P.c), e: nums(P.e), nick: nums(P.nick), pal: strs(P.pal), pal0: strs(P.pal0), pc: +P.pc, base4: nums(P.base4), prefix: P.prefix, font: P.font });
    }
    else if (m.type === 'edit') loadTheme(m.t || {});
    else if (m.type === 'status') status(m.text, m.ok === 1 ? true : (m.ok === 0 ? false : undefined));
  };

  wire();
  /* a small handle for the test harness (and for poking at the page from the browser's console) */
  window.__ted = {
    state: function () {
      return JSON.stringify({ id: S && S.id, kind: S && S.kind, name: S && S.name, dirty: dirty(), sel: sel, style: style, c1: S && S.c[0], c12: S && S.c[11], accent: S && S.accent,
        pc: S && S.pc, pal2: S && S.pal[2], tpl: Object.keys(TPL).length, rows: document.querySelectorAll('#items .row').length, base: $('base').value,
        status: $('status').textContent, list: LIST.length, save: $('save').textContent, del: $('del').disabled });
    },
    pick: function (k) { select(k); },
    assign: function (i) { assign(sel, i); },
    name: function (n) { $('name').value = n; if (S) S.name = n; },
    click: function (id) { $(id).click(); },
    exact: function (h) { useExact(h); },
    mode: function (m) { style = m; renderMock(); }
  };
  neon.send('ready');

  /* opened in an ordinary browser (no NeonScript behind it): feed a sample so the page can be looked at and styled */
  if (!(window.chrome && window.chrome.webview)) {
    setTimeout(function () {
      LIST = [{ id: 'neonnight', name: 'Neon Night', kind: 'builtin', mine: 0 }, { id: 'u_mine', name: 'My theme', kind: 'user', mine: 1 }, { id: 'mts:demo.mts', name: 'Demo MTS', kind: 'mts', mine: 0 }];
      fillBase('neonnight');
      neon.onmessage({ type: 'tplreset' });
      neon.onmessage({ type: 'tpl', k: 'join', v: '<c3><pre> <k><cnick><nick> <c1>(<address>) joined <chan>' });
      neon.onmessage({ type: 'tpl', k: 'textchan', v: '<c1><lt><k><cnick><cmode><nick><c1><gt> <text>' });
      neon.onmessage({ type: 'edit', t: {
        id: 'neonnight', kind: 'builtin', mine: 0, name: 'Neon Night copy', mode: 'dark', accent: 75, acc1: 'ff59bc', acc2: '2ee6ff', pc: false,
        c: [89, 5, 5, 74, 70, 82, 69, 68, 64, 65, 71, 97, 73, 76, 95, 83, 77, 85, 81, 75, 84, 90, 91, 88, 97, 80, 75, 88, 88, 97, 88],
        e: DEF_EV, pal: MIRC_PAL, pal0: MIRC_PAL
      } });
    }, 30);
  }
})();
