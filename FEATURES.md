# NeonScript - feature wish list

Tick what you want, then give the file back. Everything here is doable in pure mSL (no DLLs)
unless the item says otherwise.

**How to fill it in**
* `[x]` = yes, build it. Leave `[ ]` = not interested / not now.
* Put `!` after the box (`[x]!`) for "do this first".
* Anything after `//` on the line is your comment - change, rename or reshape freely.
* Effort: **S** about an hour, **M** a session, **L** several sessions.
* Tags: `(cap)` needs the server to support an IRCv3 capability, `(web)` contacts an
  outside service when you use it, `(exp)` experimental - mIRC may not expose enough to do it well.

Already done (so you do not have to ask): toolbar + custom buttons, themes + MTS import,
colourful events with `~&@%+` everywhere, Channel Control, userlist/protection, away/sound/DND,
text effects, symbol map, hotkeys, dashboard, wizard, Lurker/ZNC/soju profiles with network discovery.
Known fixes already queued: flat menus, full-width dialog banners, `/neonhelp` layout, Channel Control
mode checkboxes (see [TODO.md](TODO.md)).

---

## 1. Chat and reading

- [x] **Mentions inbox** - one window collecting every highlight and PM from all networks, click to jump. `M`
- [x] **Unread line marker** - a "new messages" divider where you left off in each channel. `M`
- [x] **Channel activity colours** - switchbar/treebar colour by what happened (message, mention, event). `S`
- [x] **Link previews** - hover or `/preview` a URL: page title, size, type in a small card. `M` `(web)`
- [x] **Image/GIF preview window** - show an image link in a floating window instead of opening the browser. `M` `(web)`
- [ ] **Search all logs** - one search box over every channel/query log with context and jump. `M`
- [ ] **Emoji shortcodes** - type `:smile:` and it becomes the emoji. `S`
- [ ] **Input formatting** - `*bold*`, `_underline_`, `/spoiler text` while typing. `S`
- [#] **Reply and reaction display** - show IRCv3 replies ("replying to Nova: ...") and reactions as small lines. `M` `(cap)` `(exp)`
- [ ] **Typing indicators** - show "Nova is typing..." in the title bar. `M` `(cap)` `(exp)`
- [ ] **Paste helper** - long or multi-line paste goes to a paste service / Lurker filehost and posts the link. `M` `(web)`
- [ ] **Per-nick colour override** - pick a colour for a particular person. `S`
- [ ] **Nick highlight list** - extra words that count as a mention (your name, project names). `S`
- [ ] **Quick translate** - `/translate <lang> <text>` and "translate last message". `S` `(web)`

## 2. Windows, layout and navigation

- [ ] **Quick switcher (Ctrl+K)** - type a few letters, jump to any channel or query on any network. `M`
- [ ] **Next/previous unread hotkeys** - cycle through windows that have something new. `S`
- [ ] **Per-channel notification level** - normal / mentions only / muted, with a toolbar toggle. `M`
- [ ] **Window layout presets** - save and restore arrangements of status, channels and queries. `M`
- [ ] **Compact mode** - tighter spacing, smaller toolbar, no banners, for small screens. `S`
- [x] **Nicklist polish** - rank colours, dim away users, optional rank headings. custom nicklist icons `M`
- [ ] **Tray notifications** - balloon/tray alert for mentions and PMs while mIRC is minimised. `S`
- [ ] **Do-not-disturb schedule** - quiet hours that switch sounds and tray alerts off automatically. `S`

## 3. Channel management

- [ ] **Timed bans** - ban for N minutes/hours, auto-unban. Works from Channel Control and `/b`. `M`
- [ ] **Ban templates** - saved ban types and kick reasons ("spam", "flood", "off-topic"). `S`
- [x] **Mass actions** - kick/ban/voice everyone matching a host or pattern, with a preview. `M`
- [x] **Quiet/mute shortcut** - `/mute nick [time]` using `+q`/`+b ~q:` where the server supports it. `S`
- [x] **Channel stats** - lines per user, busiest hours, joins/parts; shown in Channel Control. `M`
- [x] **Topic templates** - saved topic patterns with variables (date, event, link). `S`
- [ ] **Auto-join manager** - per-network channel list with keys, order and "only when I am away from X". `M`
- [ ] **Op request helper** - one click asks ChanServ/X/Q for ops/voice and handles each network's syntax. `M`
- [x] **Staff log** - a log of every kick/ban/mode I (or the userlist) did, with who and why. `S`

## 4. Bouncers and networks

- [x] **Open all** - one button/command that opens every Lurker network profile at once, staggered. `S`
- [x] **Bouncer dashboard card** - which networks are attached, lag per network, reconnect buttons. `M`
- [ ] **Chat history on demand** - scroll up / `/history` to pull older messages from the bouncer. `L` `(cap)` `(exp)`
- [x] **Read-marker sync** - keep "read up to here" in step with your other devices. `L` `(cap)` `(exp)`
- [ ] **Ask for the token each time** - do not store it in `profiles.ini`; prompt on connect. `S`
- [ ] **Profile groups** - folders ("Work", "Friends") in the server list and connect menu. `S`
- [ ] **Network colour tags** - each network gets a colour used in the switchbar and mention inbox. `S`
- [x] **Auto NickServ/SASL helper** - ghost/recover/identify flows per network without writing perform lines. `M`
- [ ] **Connection health** - detect a stale connection (no PONG) and reconnect automatically. `S`

## 5. Safety and privacy

- [x] **Ignore manager** - a dialog for ignores with expiry, scope (channel/network) and notes. `M`
- [ ] **Link safety** - warn before opening shortened or look-alike URLs. `M`
- [x] **CTCP privacy** - choose exactly what to answer to VERSION/TIME/PING (or nothing). `S`
- [x] **Per-channel flood limits** - thresholds and actions per channel instead of global. `S`
- [x] **Settings backup/restore** - `/neon export` to one folder or zip, `/neon import` on another PC. `S`
- [ ] **Redact secrets in logs** - mask tokens and passwords that get typed or echoed by mistake. `S`

## 6. Automation

- [ ] **Reminders** - `/remind 15m check the oven`, repeat and per-channel reminders. `S`
- [ ] **Scheduled messages** - send a message or command at a time, once or weekly. `S`
- [x] **Auto-replies** - rules: "if PM contains X, answer Y" with cool-downs. `M`
- [x] **Aliases and popups editor** - add your own `/commands` and menu items from a dialog, no script editing. `M`
- [x] **Event actions** - when X joins / a word is said / a network connects, run Y (a friendly trigger editor). `M`
- [ ] **Notify list dialog** - friends online/offline alerts with a proper UI and sounds per person. `M`
- [ ] **Away presets** - "Lunch", "Meeting", "Sleeping" with timers and auto-back. `S`
- [ ] **Command palette** - `/neon <anything>` fuzzy-search over every NeonScript command and setting. `M`

## 7. Look and feel

- [x] **Theme editor** - build your own theme with live preview and export it as an `.mts` file. `L`
- [ ] **Follow Windows light/dark** - switch theme automatically with the system. `S`
- [x] **Icon sets** - alternative toolbar icon styles (flat, outline, mono) and sizes. `M`
- [ ] **More built-in themes** - tell me the vibes (e.g. Solarized, Gruvbox, Dracula, Nord, retro CRT). `S` // which ones: 
- [ ] **Animated splash/banner options** - or none at all. `S`
- [ ] **Font presets** - one-click font/size sets for chat, nicklist and editbox. `S`
- [x] **Custom event templates** - edit join/part/kick/mode lines with the same tokens MTS uses, per event. `M`

## 8. Fun and extras

- [x] **Quote database** - `!quote add/get/random` for the channel bot plus a viewer. `M`
- [x] **Karma / seen / last-spoke** - `thanks nick++`, `!karma`, `!lastspoke`. `S`
- [x] **Small games** - hangman, trivia, dice duels, with scores per channel. `M`
- [x] **Now playing** - `/np` shares what Spotify/foobar/VLC is playing (read from the window title). `S`
- [x] **Sound packs** - switch whole sets of event sounds; ship two or three. `M`
- [x] **Weather/define/translate cards** - show results in a styled card instead of plain lines. `S` `(web)`
- [x] **Poll command** - `/poll "Pizza?" yes no maybe`, votes counted by the bot. `M`

## 9. Housekeeping and platform

- [x] **Update checker** - `/neon update` looks for a newer NeonScript release and shows what changed. `M` `(web)`
- [x] **Debug console** - a window of internal events and errors you can copy into a bug report. `S`
- [x] **Uninstall/repair tool** - restore stock mIRC settings, or re-create missing files. `S`
- [x] **Self-test** - `/neon selftest` checks the install (files, events, toolbar, themes) and reports. `S`
- [ ] **Localisation** - make every label translatable, ship a language file format. `L`
- [x] **Portable packaging** - one ZIP with a README and installer script for sharing the pack. `S`

---
## Decisions I need from you

1. Stay **pure mSL** (current, safe, portable), or allow **one or two DLLs/helpers** for things mSL cannot do well
   (real encryption for tokens, true toast notifications, image previews, file uploads)?
   - [ ] pure mSL only  
   - [x] DLLs are fine if they are small and open source 
   - [x] DLLs are fine also if you make them
2. Who is this for?  
- [X] me too 
- [ ] friends  
- [x] public release (then docs, updater and packaging jump up the list)
3. Which networks do you use most? (so I can test the right services' quirks)   // 
4. Anything in the current pack you **don't** use and want removed or hidden? // 

## Your own ideas

- [ ] 
- [ ] 
- [ ] 

## Annoyances / bugs you have noticed (beyond TODO.md)

- 
- 
