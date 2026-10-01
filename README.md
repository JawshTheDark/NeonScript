# NeonScript 2026

A complete script pack for **mIRC 7.85+** in the spirit of the classic full-remake scripts
(LudrioScript and friends), built for 2026: a custom icon toolbar, a themed dialog for everything,
restyled events with **all five channel ranks** (`~` owner, `&` admin, `@` op, `%` halfop, `+` voice),
MTS theme support, a Channel Control module that replaces mIRC's Channel Central, and
Lurker / ZNC / soju bouncer support.

Pure mSL. One small, optional helper DLL (see *Security*) protects saved passwords; nothing else
needs anything outside mIRC.

Licence: MIT (see `LICENSE`). Changes: `CHANGELOG.md`.

---

## Install

**From a release ZIP** (any PC): unzip, close mIRC, then run

```
powershell -ExecutionPolicy Bypass -File install.ps1
```

It asks for the folder that contains `mirc.ini` (a normal install: `%APPDATA%\mIRC`; a portable one:
the mIRC program folder), copies the pack to `scripts\neonscript`, and adds it to mIRC's autoload
list after backing up `mirc.ini`. Prefer to do it by hand? Copy the `neonscript` folder to
`<settings folder>\scripts\` and, in mIRC, type `//load -rs scripts\neonscript\neon.mrc` once.

**First run:** a splash, then the Setup Wizard (identity, network, theme, event style).
**Remove it:** `/neon uninstall` (offers to put mIRC's original colours back).

## First steps

| Type | What you get |
|------|--------------|
| `/neon` | Control Panel - every setting, eight pages |
| `/neonhelp` | Every command, in a window |
| `/neon servers` | Servers & Networks - profiles, logins (NickServ/SASL), perform, auto-join |
| `/neon themes` | Theme gallery (8 built-in themes + MTS themes) |
| `/neon toolbar` / `/neon button` | Customize the toolbar / add your own button |
| `/channel` or `/neon cc` | Channel Control (replaces Channel Central) |
| `/neon selftest` | Check the install and get a plain list of what is wrong |

Right-click any toolbar button for its own menu.

## What is in the box

* **Toolbar** - 23 icon buttons with live state icons, and **custom buttons** you can add, edit and delete.
* **Media controls** - previous / play-pause / next buttons on the toolbar that control whatever Windows is playing
  (Spotify, a browser tab, VLC, foobar2000 ...), with the track name in the tooltip, and `/np` to say what you are
  listening to. Uses Windows' own media transport controls through a small hidden PowerShell helper
  (`data\media.ps1`, plain text); switch it off in Control Panel > Sounds & notifications.
* **Colourful events** - joins, parts, quits, kicks, nicks, topics, invites, modes and a styled **WHOIS card**.
  Every user gets a rank glyph and colour. Styles: modern, retro, minimal, MTS, native.
* **Ranks everywhere** - the mode parser understands `+q +a +o +h +v` (and bans, exceptions, invites, quiets,
  keys, limits). Kick, ban, protection, userlist, bot commands and menus check the ranks the server supports and
  *your* rank before acting.
* **MTS themes** - [mIRC Theme Standard](https://github.com/mIRC-Scripters/MTS-Themes) `.mts` files:
  palette, fonts, event and chat templates. `/neon mts import | preview | apply | off`.
* **Channel Control** - topic (with history), modes/key/limit (ticking a switch applies it, with a result line that
  reports server refusals), users with rank-aware buttons, ban/exception/invite/quiet lists, per-channel protection.
* **Userlist & protection** - auto owner/admin/op/halfop/voice, auto-kick, protected users; flood, CTCP, PM-spam,
  mass-highlight and banned-word protection (never touches ranked users).
* **Servers & bouncers** - profiles, reconnect, keep-alive, perform lines, SASL/SCRAM/EXTERNAL.
* **Away / sound / DND**, **text effects**, **symbol map**, **F-key hotkeys**, **clone scanner**, **dashboard**,
  small games and a channel bot (`!roll !8ball !seen ...`).

## Chat and reading

* **Mentions inbox** - `/neon mentions` or the @ button: every highlight and private message from all networks,
  unread badge on the button, double-click an entry to jump to the window (re-opened if you closed it).
  Add your own trigger words in Control Panel > Chat & reading.
* **"new messages" line** - a divider before the first message that arrives while you are away from a window.
* **Nick-list colours** - rank colours from the theme; away users dimmed.
* **Replies and reactions** - IRCv3 message tags shown as small context lines (needs a server that relays tags).
* **Link and image previews** - `/preview <url>` or Shift + double-click a link: a card with title, description,
  site, type, size and picture, plus a picture window for images. Previews only ever load when you ask.
* **Right-click menus** are organised into categories and replace mIRC's default menus (`/neon menus off` brings
  mIRC's back).

## Lurker (and ZNC, soju) bouncer support

Lurker has a ZNC- and soju-compatible bouncer built in. mIRC attaches over TLS and signs in as
`<user>` (no network - Lurker answers with a **list of your networks**) or `<user>/<network>` (one network, what
mIRC uses day to day), with your password or, better, a revocable read-write **API token** (SASL PLAIN, or
`user/network:token` as the server password).

```
/neon bnc add Lurker <host> 6697 <username>
```

opens the Bouncer dialog - paste your token there, then press **Discover networks...** (or run `/neon bnc discover`).
NeonScript logs in as just `<username>`, reads Lurker's "Not attached to a network ... Available: a, b, c" notice and
offers to create one profile per network (`Lurker/libera`, ...), optionally opening each in its own status window.
Truncated lists ("+3 more") are completed through soju's `BOUNCER LISTNETWORKS`, and you can type missing names.

Also: certificate pinning for self-signed bouncers, replayed history shown dimmed with its original time, a "stay
quiet during replay" switch (no sounds, away log, protections, auto-op, greetings or bot replies for old messages),
and an optional ZNC `*playback` request on attach. Port 6697 is the usual TLS bouncer port.

## Maintenance

| Command | Purpose |
|---------|---------|
| `/neon selftest` | Checks mIRC, TLS, scripts, data files, artwork, toolbar, theme, every documented command, profiles, secrets |
| `/neon debug` | Debug console: recent internal messages and a report you can paste into a bug report (no passwords or tokens) |
| `/neon export`, `/neon import [file]`, `/neon backup` | Back up / restore settings as a ZIP. **Passwords and tokens are never included**; restoring keeps the ones you have |
| `/neon repair` | Reload missing modules, re-create missing data files, rebuild the toolbar, then self-test |
| `/neon repair stock` | Put mIRC's original colours, toolbar and stock aliases back (NeonScript stays installed) |
| `/neon update`, `/neon update url <https://...>` | Check a release feed for a newer version. Only runs when you ask (`/neon update auto on` for a check at start-up). Nothing is installed automatically |
| `/neon secure [on\|off]` | Protect saved passwords/tokens with Windows DPAPI, or show the status |

Automatic safety backups are written to `backup\` before upgrades, restores and repairs (the newest ten are kept).

## Security and privacy

* **Saved passwords and tokens** (`profiles.ini`: `pass`, `srvpass`, `bnctoken`) are encrypted with **Windows DPAPI**
  when `neonsec.dll` is present - a 5 KB helper whose full source (`tools\dll\neonsec.c`, about 150 lines, only
  `kernel32` and `crypt32`) and build script (`tools\dll\build.cmd`) are included. NeonScript only loads it if its
  SHA-256 matches `data\neonsec.sha256`. DPAPI ties the data to your Windows account on this PC: a copied
  `profiles.ini` is useless elsewhere (you simply enter the token again). It does *not* protect against other
  programs running as you. Without the DLL everything still works and secrets stay plain text, as in stock mIRC -
  `/neon selftest` tells you which case you are in. Rebuild the DLL yourself if you would rather not trust a binary.
* Bouncer **tokens beat passwords**: a Lurker API token can be revoked on its own.
* The debug log never contains the server command (which can carry a token); exports never contain secrets.
* `/weather`, `/define` and `/neon update` contact web services - and only when you run them.
* There is no telemetry.

## Files

```
neon.mrc              core: settings, helpers, module loader, /neon dispatcher
neon_system.mrc       self-test, debug console, backup/restore, repair, update check, stock snapshot
neon_secure.mrc       password/token protection (DPAPI via neonsec.dll)
neon_chat.mrc         mentions inbox, new-messages line, nick-list colours, replies/reactions
neon_web.mrc          link and image previews
neon_theme.mrc  neon_mts.mrc  neon_toolbar.mrc  neon_events.mrc  neon_dialogs.mrc
neon_servers.mrc  neon_bnc.mrc  neon_chan.mrc  neon_protect.mrc  neon_hud.mrc  neon_tools.mrc
neon_away.mrc  neon_sound.mrc  neon_media.mrc  neon_fun.mrc  neon_alias.mrc
neonsec.dll           the optional protection helper (32-bit, like mIRC)
data/                 themes, networks, message lists, command reference, MTS samples, media.ps1 (media helper)
assets/               icons, banners, headers (generated by tools/make_assets.py)
tools/                make_assets.py, build_release.py, install.ps1, mock_irc.py, dll/ (helper source)
backup/               automatic and manual backups, the stock-colour snapshot (created on first run)
```

Your settings are written next to the scripts: `neon.ini`, `profiles.ini`, `custom.ini`, `access.ini`, `chan.ini`.

## Developing

* `python tools/make_assets.py` regenerates every icon, banner and header (needs Pillow).
* `tools\dll\build.cmd` rebuilds `neonsec.dll` (Visual Studio C++ tools) and updates `data\neonsec.sha256`.
* `python tools/build_release.py` writes `dist\NeonScript-<version>.zip`, a `latest.txt` update feed and `SHA256SUMS.txt`.
* `python tools/mock_web.py 8766` serves pages, pictures, redirects and a big file for testing the previews.
* `python tools/mock_irc.py 6667` runs a tiny local IRC server (rank-heavy scenarios, WHOIS, a Lurker emulation) used to
  test the scripts end to end without touching a real network.
