# Changelog

Versions are `year.minor.patch`. The version lives in one place: `alias ns.ver` in `neon.mrc`.

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
