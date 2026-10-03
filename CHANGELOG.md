# Changelog

Versions are `year.minor.patch`. The version lives in one place: `alias ns.ver` in `neon.mrc`.

## 2026.17.0

* **Holiday themes**: New Year's Eve, Valentine's Day, St. Patrick's Day, Easter (a light one), Memorial Day, Juneteenth, Independence Day,
  Labor Day, Halloween, Thanksgiving, Hanukkah and Christmas - each with exact colours (its own 16 first colours, restored when you
  switch away), a picture of the day in the gallery and a group of its own in the Theme Studio. Made by `tools/make_holiday_themes.py`
  (contrast-checked), pictures by `tools/make_assets.py thumbs h_`.
* **Theme Studio** (`/neon themeedit`, native helper; the old dialog is still there without it): a whole-window live preview - toolbar, tree
  bar, chat in modern / retro / minimal / MTS-template style, nick list, edit box - where you click what you want to change and then a
  colour: mIRC's 99, any colour (closest match, or exact in the theme's own 16 colours), nick colours, accents, undo, reset item.
  **Imported MTS themes can be edited**: the colours change and the rest of the file (templates, fonts, palette, every byte of it) is carried
  into a copy named `<name>.mts`; the original is never touched. The first 16 colours of a theme can now be its own (`rgb=` in
  `themes_user.ini`, exact RGB), the way MTS themes have always had them.
* **A theme change now reaches everything**: window frames and menu borders (light/dark, accent), the tree bar's text colour (pushed to the
  tree itself and repainted) and every channel's nick-list rank colours follow the new theme at once; the old behaviour left the rank
  colours of the previous theme on the nick lists. `/neon ui treecolors` shows what the tree bar really draws, `/neon ui treefix` repaints it.
* **Instant, not polled** (neonui 1.3): dialogs get their theme frame and right-click menus their accent border the moment they appear. The native
  helper now watches window creation on mIRC's own UI thread; the two-second poll that used to tint a menu after it was already on screen
  ("the colours take a second to render in") is only a safety net now. A new channel window's nick list gets its rank icons and avatars
  from the very first row and is fitted to its width within a few milliseconds of the names arriving (it used to wait for the next poll),
  and tree bar pills show 150 ms after a message instead of a second. `/neon ui menus off` keeps the window frames but drops the menu border.
* **Frames and menus**: the frame tint is for windows with a title bar only; a pop-up menu gets nothing but the border colour.
* **A stale helper is swapped automatically**: a neonui.dll that an older session still has loaded (Windows never replaces a loaded DLL) is
  let go and the file on disk loaded when the helper starts or after `/neon reload` - no more `/neon ui off`, `on`.
* Menu labels with an ampersand: the admin symbol in "Give admin (&)" / "Auto-admin (&)" and the "Servers & networks" entry were eaten as
  menu accelerator keys ("Give admin ()"); they are escaped now.
* **Tree bar pills** turn red for a window mIRC itself shows in its highlight colour (its own highlight words), not only for NeonScript's mention words.
* **Commands menu** (menu bar) gained the newer tools: Mentions inbox, Log viewer, Ignore manager, Emoji picker, Dictate, AI helpers, Native UI helper, Settings sync.

* **Tree bar counts** (native helper, Control Panel > Native UI): a red pill with the number of unread mentions - or a blue one with the unread
  messages - at the right edge of each channel, query and window entry in mIRC's tree bar; looking at the window clears it.
* **Theme-matched window frames** (native helper): title bar, caption text, border colour and scroll bars of mIRC and its dialogs follow the NeonScript
  theme (Windows 11; mIRC 7.85's own dark mode keeps handling menus). Switch off with the Native UI checkbox.

* **Log viewer** (`/neon logs`, toolbar Logs button, right-click menus): all of mIRC's logs sorted into categories - by type (channels, private
  messages, status windows, other), by network and by age - with name filter and sort, opened in a coloured window of their own, searched (one log
  or every listed log, wildcards or regex) with double-click-to-open-at-the-hit, `/neon logs here` for the window you are in, delete to the
  recycle bin. Files stay where mIRC wrote them.
* **Toolbar icon size** (Customize Toolbar > Small / Large / Actual) now really changes the icons: mIRC's /toolbar -z switch does not rescale PNG
  pictures, so the 16 px and 24 px copies (`assets\s16`, `assets\s24`, made by `tools\make_icon_sizes.py`) are chosen instead. Default is Actual (32 px).
* Debug pass: two more `hdel` calls guarded; the whole test suite (31 scripts) was run with the status window captured - no script errors.
* **Highlights-only ignore** (Ignore Manager: "Only stop them highlighting me", `/neon nohl <nick>`, nick-list menu "Never highlight me"):
  a person or bot you keep reading but who must not highlight you. Their channel lines never reach the mentions inbox, toasts,
  speech, the taskbar badge, the highlight sound, "mention" rules or the mention counter, and mIRC's own highlight (colour, flash,
  sound) is bypassed - NeonScript draws those lines itself in plain style. Private messages are untouched. Works with a time limit
  and "only this network" like other entries.
* **Auto nick list width** (Control Panel > Native UI > Nick list width): "Fit the longest nickname" sizes every channel's nick list to exactly what
  its longest name, the icons and the scroll bar need (between a min and a max you choose), or "Fixed width" for all of them; it follows joins,
  parts and window resizes. Default: fit. "Leave it to mIRC" gives mIRC's own widths back.
* **MTS themes with `!script` templates** (e.g. negative-entropy, whose lines are produced by its own script) no longer print the code
  (`!script $ct.outtext(...)`) in every window: those templates are skipped and NeonScript's built-in style draws the line.
* **No more status-window spam**: lag is now measured with a probe whose reply NeonScript can hide (the old PING came back as "PONG from ..." lines
  that no script event can suppress), and the IRCv3 raw lines NeonScript handles (read markers, accounts, tags, deletions) are never printed.
  The toolbar Favorites button no longer sends an unknown "FAVORITES" command to the server: it presses Favorites > Manage Favorites (needs the
  native helper; otherwise it says Alt+J). The Mentions window remembers "Only show what I have not read yet".
* **Native helper**: every channel's nick list now looks the same - the icons and avatars are no longer dropped in narrow lists (that
  made some channels show both, some only rank icons and some none). Control Panel > Native UI has "Hide them in narrow nick lists" if you
  prefer readable names over a uniform look (it is off by default).
* **Native helper**: the nick list icon cell no longer turns into a block of the nick's colour on rows whose name runs to the edge of a narrow
  list (the row background is now the majority of ten samples along the row's top and bottom edge instead of one pixel);
  icons are kept on narrower lists, so windows look alike. `/neon ui off` now unloads `neonui.dll`, and a replaced DLL is
  renamed out of the way when the old one is still loaded (`/neon ui off` then `on` picks up the new one).

## 2026.15.0

* **Dictation** (`/dictate`, `/neon dictate`): speech to text through the Windows speech recogniser, text lands in the editbox, never
  auto-sent, off after every restart. Completes the Phase 8 list (the unread badge and taskbar progress came with the native helper).

## 2026.14.0

* **Settings sync** (`/neon sync`, Control Panel > Sync): three-way, key-by-key merge of your settings through a folder you
  choose, with conflict copies, an automatic backup before applying, first-sync adoption and no secrets in the folder.

## 2026.13.0

* **Native UI helper** (`neonui.dll`, source in `native/`, off by default - Control Panel > Native UI or `/neon ui on`): rank icons
  and coloured-initial avatars in the nick list, an unread-mentions badge on the taskbar button. Verified by SHA-256 before it is
  loaded; only touches mIRC's own windows. `/neon ui status` shows its state, the self-test checks it.
* **HTML panels** through WebView2 (`neonui.dll` 1.1): `/emoji` picker and a card window for AI answers
  (`ai panel` setting). Panels load only `data\ui` files; links, new windows, downloads and permission requests are handled by NeonScript or refused.
  `tools/make_emoji.py` regenerates the emoji list.
* Two prompts with literal commas in `$input` (restore backup, restore original look) no longer lose their buttons.

## 2026.12.0

* **AI helpers** (`/ai`, Control Panel > AI helpers, right-click menus): catch me up, unread-mentions summary, translate a line,
  moderation check (suggestions only) and plain-English commands with a command preview. Off by default and strictly on request;
  every request shows where it goes and exactly what is sent. Providers: Ollama (local), OpenAI-compatible, Anthropic.
  The API key lives in `aikey.ini` (DPAPI-protected, excluded from backups and releases). Nicknames are anonymised in what is sent.
* `ns.card` can now send a card to a named window (`%ns.card.win`), so a slow answer lands where the command was typed.

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
