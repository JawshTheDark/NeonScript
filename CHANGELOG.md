# Changelog

Versions are `year.minor.patch`. The version lives in one place: `alias ns.ver` in `neon.mrc`.

## 2026.11.0

* **IRCv3 extras**: read markers, chat history on demand, deleted/edited message display, typing indicators in the nick list,
  account tracking (`/neon accounts`, mass-action pattern `unauth`). The draft capabilities are requested after connect when the
  server offers them. Control Panel > Chat & reading has the switch; `/neon ircextras` shows the state.

## 2026.10.0

* **Channel extras**: quotes (`!addquote`, `!quote`, `!delquote`, `/neon quote`), karma (`nick++`, `!karma`, `!top`), polls with
  timers, and the games `!guess`, `!rps` and `!hangman`.
* **Web cards**: `/weather`, `/define` and new `/translate` (`/tl`) as framed cards, or one line with `-s`. The old `/weather` and
  `/define` never reported HTTP errors properly (they compared a whole status line to 200); fixed.

## 2026.9.0

* **Theme editor** (`/neon themeedit`, Theme Gallery > Theme editor...): all 31 mIRC colour items and the 17 NeonScript event
  colours with a live preview and palette, saved as your own themes (`themes_user.ini`), exportable as `.mts`.
* **Event templates** (`/neon templates`, Control Panel > Display): edit how every kind of line is written, using the MTS
  tokens, with a preview window; saved as `my_templates.mts`.
* The picture windows used for charts and previews now ask for the frame's 16 x 39 pixels extra, so images come out at the
  size they were designed for.

## 2026.8.0

* **Icon sets**: flat, outline and mono variants of every toolbar icon, switchable live in Control Panel > Display.
* **Sound packs**: Chime, Arcade and Soft (synthesised, original), selectable in Control Panel > Sounds & notifications.

## 2026.7.0

* **Bouncer dashboard** (`/neon bncdash`): every Lurker / ZNC / soju network profile with its state, lag and unread
  mentions, connect / disconnect / reconnect buttons, **Open all** and **Close all** (`/neon bnc openall|closeall`).

## 2026.6.0

* **Automation rules** (`/neon rules`): triggers, conditions, a fixed vocabulary of actions, auto-replies, cool-downs,
  a dry-run **Test**, an activity log (`/neon rule log`) and a safety breaker.
* **Alias and popup-menu editor** (`/neon aliases`).
* **NickServ ghost / recover** per server profile.

## 2026.5.0

* **Windows toast notifications** for mentions and private messages (`/neon toast`), click-to-jump, background-only,
  rate-limited, text optional; **speech** (`/neon speak`); **`/paste`** upload to an address you set. Control Panel >
  Windows integration. A second small hidden PowerShell helper (`data\win.ps1`) does the Windows calls.
* Text sent to the helpers is written as UTF-8 correctly (media titles and notifications with non-English text).

## 2026.4.0

Channel tools, privacy, media buttons and a fix for Lurker's repeated buffer.

* **Lurker (and any bouncer that re-sends its buffer) no longer lights everything up on every connect.** The newest
  message seen in each window is remembered (saved between sessions, `data\bncmarks.dat`); replayed lines that are not
  newer are dropped before anything shows them, and the activity colour that genuinely new replayed lines leave in the
  tree / switchbar is cleared once the replay settles - unless something live arrived in that window meanwhile. Two
  switches in the Bouncer dialog, `/neon bnc marks [reset]`.
* **Mass actions** (`/neon mass`): voice, devoice, kick, ban, kick + ban, quiet by pattern with a preview; throttled queue.
* **Quiet / mute** (`/neon quiet`, `unquiet`, `quiets`): `+q` or `+b ~q:` as the server supports; timed quiets lift themselves.
* **Staff log** (`/neon stafflog`): kicks, bans, quiets, modes and topics you set, with the source (manual, userlist,
  flood, lock, mass, mute ...). Menus and Control Panel entries for it.
* **Channel stats** (`/neon stats`): per-person lines/words and a messages-by-hour chart. Switch off in Privacy & safety.
* **Topic templates** (`/neon topictpl`, Channel Control > General > Templates...).
* **Per-channel flood limits** (Channel Control > Protection).
* **Ignore manager** (`/neon ignores`, `/neon ignore`, `/neon unignore`): kinds, expiry, scope, note; drives mIRC's own
  ignore list (so ignored people are really invisible) and re-applies it after a restart. The nick-list Ignore items use it.
* **CTCP privacy** and a new Control Panel page **Privacy & safety**. Fixed: the CTCP flood guard never fired - mIRC's
  CTCP events are `ctcp ...:` lines, there is no `on CTCP`.
* **Media controls** on the toolbar (see below), `/np`.
* Self-test checks every artwork file (it silently skipped most before), the media helper and all new modules.

* **Media controls** on the toolbar: previous, play / pause and next buttons that control whatever Windows is
  playing (the same System Media Transport Controls the keyboard media keys use), the play button turns into a
  pause button while something plays, the tooltip shows the track, and right-click gives Stop, `/np`, copy track.
  `/np` says what you are listening to in the current channel or query. A small hidden PowerShell helper
  (`data\media.ps1`) does the talking; it quits with mIRC, and `/neon media off` (or Control Panel > Sounds) stops it.
* Self-test now checks every artwork file (it silently skipped most of them before) and the media helper.

## 2026.3.1

* **Connect when mIRC starts now works.** The "Connect when mIRC starts" tick on a server profile was saved but never
  acted on - only the Control Panel switch did anything, and only for the default profile. Now every ticked profile
  connects (the default one first, in the main window; the others in their own status windows a few seconds apart).
  Profiles that are already connected are skipped, it runs once per mIRC start, and `/neon selftest` lists how many
  profiles will connect.

## 2026.3.0

Chat and reading experience.

* **Mentions inbox** (`/neon mentions`, toolbar @ button): every highlight and private message from every network,
  with an unread badge on the toolbar, double-click to jump (re-opens a closed window), saved between sessions.
  Your own extra words are supported; replayed bouncer history never counts.
* **"new messages" line**: placed before the first message that arrives while you are away from a window (or
  while mIRC is in the background), once, never in a window you are reading.
* **Nick-list colours**: nicknames coloured by rank from the theme, away users dimmed (IRCv3 away-notify, plus a
  WHO check when you join a small channel).
* **Replies and reactions** (IRCv3 message tags): "replying to Nova: ..." in front of a reply and a small line for
  each reaction, when the server relays tags (Lurker, Ergo, ...).
* **Link and image previews** (`/preview <url>`, Shift + double-click a link): title, description, site, type, size
  and picture. Only on request; http(s) only; local/private addresses refused; 64 KB of a page, 8 MB of a
  picture at most; redirects followed by hand (4 max, each hop checked); nothing saved outside `data\tmp`.
* **Right-click menus** reorganised into categories (Control, Rank, Userlist, CTCP, DCC, Ignore ...). mIRC's default
  nick list / channel / query / status menus are switched off - only while they are still exactly mIRC's originals;
  `/neon menus off` or `/neon repair stock` brings them back.
* New Control Panel page **Chat & reading**; toolbar **Mentions** button (added automatically after Notify).

## 2026.2.0

Release foundations - things that make NeonScript safe to install, upgrade and report bugs on.

* **Self-test** (`/neon selftest`): checks mIRC version, TLS, scripts, data files, artwork, toolbar, theme, every command in
  `/neonhelp`, server/bouncer profiles and stored secrets.
* **Debug console** (`/neon debug`): recent internal messages plus a report with no passwords or tokens.
* **Backup & restore** (`/neon export`, `/neon import`, `/neon backup`): ZIP backups of settings, themes and custom
  buttons. Passwords and tokens are never included; restoring keeps the ones you already have. Automatic backups before
  upgrades, restores and repairs.
* **Repair** (`/neon repair`) and **restore the original look** (`/neon repair stock`, also offered by `/neon uninstall`):
  mIRC's own colours, toolbar and stock aliases are remembered on first run and can be put back.
* **Settings layout versioning** with migrations (`general schema`), so future releases can change formats safely.
* **Password / token protection**: Windows DPAPI via the optional, open-source `neonsec.dll` (source and build script in
  `tools\dll`, MIT). Verified against `data\neonsec.sha256` before use. `/neon secure`.
* **Update check** (`/neon update`): reads a small feed you host; only runs when you ask (or if you switch it on).
  Nothing is downloaded or installed automatically.
* Release packaging: `tools\build_release.py` and an installer script.
* Dialog headers now run edge to edge; flat popup menus; `/neonhelp` layout; Channel Control mode switches apply on tick
  with a result line; fixed doubled first letter in MTS chat lines.
* The server command (which can contain a token) is no longer written to the debug log.

## 2026.1.0

First release: toolbar with custom buttons, themes and MTS import, coloured events with all channel ranks, Channel
Control, userlist and protection, away/sound/DND, text effects, hotkeys, dashboard, wizard, Lurker/ZNC/soju bouncer
profiles with network discovery.
