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
| `/neon` | Control Panel - every setting, ten pages |
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

## More IRCv3

* **Read markers** (`draft/read-marker`): when you read a window NeonScript tells the server, and when another client reads
  something the matching mentions in your inbox are marked read and the activity colour clears.
* **Chat history** (`/neon history [n]`, `draft/chathistory`): load the latest messages from the server's own history.
* **Deleted and edited messages** (`REDACT`, `+draft/edit`): shown as "deleted by ..." / "edited" lines.
* **Typing indicators**: a nick lights up in the nick list while that person types.
* **Accounts** (`/neon accounts`): who is logged in to services; the mass-action pattern `unauth` picks everyone not known to be.
  mIRC already asks for server-time, message-tags, away-notify, account-notify, extended-join, multi-prefix and batch itself;
  NeonScript asks for the three draft ones when the server offers them (`/neon ircextras` shows what is on).

## AI helpers (optional, off by default)

* **Nothing happens until you ask.** `/ai catchup` summarises a window you were away from, `/ai mentions` your unread mentions,
  `/ai translate <language> [nick]` the last line, `/ai mod` looks for spam, flooding and harassment (it only suggests), and
  `/ai do <request>` turns a plain-English request ("kick the flooder and quiet Zed for ten minutes") into commands.
  A confirmation shows the destination and the exact text before anything is sent; the commands from `/ai do` are checked against a
  short list of allowed shapes, shown, and need a second yes before they go into the normal throttled queue.
* **Your choice of model**: Ollama on this PC or your network (the default - nothing leaves it), any OpenAI-compatible service, or
  Anthropic. Control Panel > AI helpers holds the provider, model, address and key. The key is kept in `aikey.ini`, protected with
  Windows DPAPI when `neonsec.dll` is installed, and is never part of a backup or a release.
* Nicknames are replaced by `User1`, `User2` ... in the chat that is sent and put back in the answer (switchable).

## Native helper (optional)

* `neonui.dll` is a small 32-bit helper (source in `native/`, MIT) for what plain mIRC script cannot do. It is **off by default**:
  Control Panel > Native UI, or `/neon ui on`. NeonScript compares its SHA-256 with `data\neonui.sha256` before it is ever loaded.
* **Nick list icons and avatars** - an icon for owner, admin, op, halfop and voice, and a coloured initial for everyone. mIRC
  still paints the nick (colours, away dimming, selection); the helper only adds the icons on the left. A narrow nick list
  drops the avatars first, then the icons, so names never get squeezed.
* **Taskbar badge** - the number of unread mentions on mIRC's taskbar button.
* **HTML panels** (WebView2, which ships with Windows 11 and Edge) - small windows with pages from `data\ui`: the **emoji picker**
  (`/emoji`: search by name, groups, recently used, inserts at the cursor) and a **card** window that shows AI answers with
  formatting, a Copy button and links that ask before they open (Control Panel > AI helpers > "window of their own").
  The panels can only load NeonScript's own files; every other address is refused, and what a page sends back is treated as untrusted text.
* Apart from the panels' WebView2 profile folder (`data\ui\profile`) it touches nothing but mIRC's own windows. `/neon ui off` puts everything back.

## Settings sync (optional)

* `/neon sync folder <path>` then `/neon sync on` (or Control Panel > Sync): NeonScript keeps your settings in step through a
  folder that OneDrive, Dropbox, Syncthing or a git checkout already shares between your PCs. Nothing else is used.
* It merges **key by key** against the state of the last sync, so a change on one PC survives a different change on another.
  The same key changed on both: the newer file wins and the other copy goes to `backup\sync-conflicts`. A new PC adopts what the
  folder already holds. A normal backup is taken before NeonScript changes anything because of the folder.
* **Passwords, tokens and the AI key never go into the folder**; neither do machine-specific sections (paths, helper switches,
  update checks) or logs, the mentions inbox and stats. Perform lines and custom buttons are commands - only share a folder you control.
  Your own mSL aliases (`usercode.ini`) are synced only if you set `[sync] code=1` in `sync.ini`.

## Fun and extras

* **Channel extras** (part of the channel bot - switch it on in Control Panel > Channel commands): `!addquote` / `!quote [n | words]`
  / `!delquote` (ops), karma with `nick++` / `nick--` plus `!karma` and `!top`, polls (`!poll [5m] Question? | a | b`, `!vote`,
  `!results`, `!endpoll`), and small games: `!guess`, `!rps`, `!hangman` with `!h <letter>`.
  `/neon quote add|find|list|del` manages the quote book from your own window. Everything is stored on your PC.
* **Cards** - `/weather <city>`, `/define <word>` and `/translate <code> <text>` (alias `/tl`) show a framed card; with `-s`
  they say one line in the channel instead. They contact wttr.in, dictionaryapi.dev and api.mymemory.translated.net, only
  when you run them, and send only what you typed.

## Look and feel

* **Icon sets** - Control Panel > Display > Toolbar icons: Glossy (default), Flat, Outline or Mono; applied live
  (`assets\icons_<set>`, generated by `tools\make_assets.py`).
* **Sound packs** - Control Panel > Sounds & notifications > Sound pack: Windows sounds (default) or three packs made for
  NeonScript - Chime, Arcade and Soft (`assets\sounds\<pack>`, synthesised by `tools\make_assets.py`, no third-party audio).
  Per-event sounds you chose in the Sound manager still win.

* **Theme editor** (`/neon themeedit`) - every mIRC colour item and every NeonScript event colour (48 in all) with a live
  picture of what chat will look like and the full 99-colour palette; save it as your own theme (it joins the gallery),
  apply it, or export it as a classic `.mts` file.
* **Event templates** (`/neon templates`) - how each kind of line looks (channel message, action, notice, private message,
  join, part, quit, kick, nick, mode, topic, invite) written with the MTS `<tokens>`; preview window, then apply. Saved as
  `data\mts\my_templates.mts`, an ordinary MTS theme.

## Automation

* **Rules** (`/neon rules`) - *when* something happens (a message, a mention, a private message, a join, part, quit, kick,
  nick change, topic, invite, connect ...), *where* (network, channels), *from whom* (nick/address wildcards, `ops`,
  `voice`, `norank`, `userlist`, `!ops` ...), *matching what* (wildcards or `re:<regex>`), with a cool-down, "only while
  away / here" and a chance, *then* a list of actions: `say`, `reply`, `msg`, `notice`, `action`, `echo`, `kick`, `ban`,
  `kickban`, `quiet`, `voice`, `mode`, `join`, `part`, `away`, `ignore`, `toast`, `speak`, `sound`, `wait`, `stop`, `log`.
  Auto-replies are just rules. Starter templates are built in; **Test** shows what a rule would send without sending it.
  Text from other people is only ever substituted as data (a nick like `x|quit` cannot run anything), rules never
  answer your own lines, actions go out through a throttled queue, and a breaker pauses every rule for five minutes if
  they fire more than 40 times a minute (`/neon rule resume`).
* **Aliases and popups** (`/neon aliases`) - your own commands and right-click / menubar items, written out as ordinary
  script files (`user_alias.mrc`, `user_menu.mrc`). Names are checked so you cannot replace mIRC's commands.
* **NickServ ghost** - the server profile switch "Take my nick back if a ghost holds it": when your nick is taken and mIRC
  falls back to the alternate, NeonScript asks NickServ to GHOST the old session, changes back and identifies again.
  The commands are quiet, so the password never shows in a window.

## Windows integration

* **Toast notifications** (`/neon toast on`) - mentions and private messages as real Windows notifications while mIRC is
  in the background; click one to jump to that conversation. Respects Windows' Focus assist and NeonScript's Do not
  disturb; limited to one toast per conversation every 6 seconds. Off until you switch it on; switching it on adds the
  name "NeonScript" to Windows' notification settings (HKCU only), switching it off removes it.
* **Speech** (`/neon speak on`) - mentions and private messages read aloud with the Windows voices (`/neon speak voices`).
* **`/paste`** - uploads a file, the clipboard text or the clipboard picture to an `https://` address *you* configure
  (nothing is set by default, and it asks before sending) and puts the link in your editbox.
* All of it runs through a small hidden PowerShell helper (`data\win.ps1`, plain text) that quits with mIRC.

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

## Channel tools and privacy

* **Mass actions** (`/neon mass`) - voice, devoice, kick, ban, kick + ban or quiet everyone who matches a pattern
  (`Clone*`, `*!*@host`, the words `clones` / `norank`, or `re:<regex>`), with a **preview first**. Nobody with
  halfop or higher, nobody flagged protected, nobody who outranks you and never yourself. Commands go out slowly
  (a queue) so the server does not flood you off; `/neon mass stop` cancels the rest.
* **Quiet / mute** (`/neon quiet <nick> [10m] [reason]`, `/neon unquiet`, `/neon quiets`) - uses whichever the server
  has: a real quiet mode (`+q`) or an extended-ban quiet (`+b ~q:`), read from the server's own capabilities. Timed
  quiets lift themselves, even after a restart.
* **Staff log** (`/neon stafflog`) - every kick, ban, quiet, mode and topic change *you* make, and what caused it:
  by hand, the userlist, flood protection, a mode lock, a mass action ... Searchable, exportable.
* **Channel stats** (`/neon stats`) - lines and words per person and a messages-by-hour chart, per channel, counted
  live (never from a bouncer's replayed history) and kept on your PC only.
* **Topic templates** (`/neon topictpl`) - saved topics with `{chan} {date} {time} {me} {users} {old}` placeholders,
  length-checked against the server's limit.
* **Per-channel flood limits** - Channel Control > Protection: its own lines/seconds/action for one channel, or
  flood protection switched off there.
* **Ignore manager** (`/neon ignores`, `/neon ignore <nick> [2h] [note]`) - who, which kinds of message, for how
  long, where (all networks or just one), with a note. mIRC's own ignore list does the actual ignoring; NeonScript
  re-applies your entries after a restart.
* **CTCP privacy** (Control Panel > Privacy & safety) - FINGER, USERINFO, CLIENTINFO and the like are not answered, TIME
  is answered in UTC, only people who share a channel with you get replies, nothing is answered to a whole channel, and
  a per-minute limit. (mIRC always answers VERSION itself - no script can stop that.)

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

**Bouncer dashboard** (`/neon bncdash`, status-window right-click) lists every bouncer network with its state, lag and unread
mentions and lets you connect, disconnect or reconnect each one; `/neon bnc openall` / `closeall` do all of them, a few
seconds apart.

**Lurker re-sends its whole buffer on every connect** (it does not mark history as delivered), which lights every
channel red again each time. NeonScript remembers the newest message you have seen in each window and drops replayed
lines that are not newer (`/neon bnc marks reset` forgets that), and clears the activity colour a replay leaves behind
unless something live arrived in that window. Both can be switched off in the Bouncer dialog.

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
neon_win.mrc          Windows toasts, speech, /paste
neon_auto.mrc         automation rules      neon_usr.mrc   alias and popup editor
neon_mod.mrc          staff log, quiet/mute, mass actions, topic templates
neon_stats.mrc        channel stats
neon_privacy.mrc      ignore manager, CTCP privacy
neonsec.dll           the optional protection helper (32-bit, like mIRC)
neon_ui.mrc  neonui.dll  the optional native helper (nick list icons, taskbar badge); source in native/
neon_ai.mrc           opt-in AI helpers (/ai)
data/                 themes, networks, message lists, command reference, MTS samples, media.ps1 (media helper)
assets/               icons, banners, headers (generated by tools/make_assets.py)
tools/                make_assets.py, build_release.py, install.ps1, mock_irc.py, dll/ (helper source)
backup/               automatic and manual backups, the stock-colour snapshot (created on first run)
```

Your settings are written next to the scripts: `neon.ini`, `profiles.ini`, `custom.ini`, `access.ini`, `chan.ini`.

## Developing

* `python tools/make_assets.py` regenerates every icon, banner and header (needs Pillow).
* `native\build.cmd` rebuilds `neonui.dll` (Visual Studio C++ tools and the WebView2 NuGet package) and updates `data\neonui.sha256`.
* `tools\dll\build.cmd` rebuilds `neonsec.dll` (Visual Studio C++ tools) and updates `data\neonsec.sha256`.
* `python tools/build_release.py` writes `dist\NeonScript-<version>.zip`, a `latest.txt` update feed and `SHA256SUMS.txt`.
* `python tools/mock_web.py 8766` serves pages, pictures, redirects and a big file for testing the previews.
* `python tools/mock_irc.py 6667` runs a tiny local IRC server (rank-heavy scenarios, WHOIS, a Lurker emulation) used to
  test the scripts end to end without touching a real network.
