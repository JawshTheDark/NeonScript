# NeonScript - roadmap from your wish list

Built from your ticks in [FEATURES.md](FEATURES.md). Phases 1-2 are done, Phase 3 is under way. Order is my
proposal - tell me what to move.

## What I took from your answers

* **47 items ticked**, none marked `!` - so the order below is mine (foundations first, then by value).
* **Audience: you and a public release.** That moves four things up the list: a self-test and debug
  console (so bug reports are useful), settings export/import and repair (so upgrades do not break
  people), packaging + update checker, and **never storing secrets in plain text** (see Tokens below).
  It also means a licence, a changelog and version numbers.
* **DLLs: allowed if small and open source, or if I write them.** Good news: this PC has Visual Studio
  (x86 cross-compiler) and your `mirc.exe` is 32-bit, so I can build a 32-bit DLL here. Plan: **avoid
  DLLs unless there is no sane alternative**, and when one is needed ship its source, a build script
  and a hash. Only one candidate so far (token protection) and it may not need a DLL at all - see below.
* **`[#]` on "Reply and reaction display"** - I do not know what `#` means (maybe / later?). Parked
  until you say.
* **Networks (#3) and "remove/hide" (#4) are blank** - fine for now.

## Phases

Effort = your S / M / L sizes (S about an hour, M a session, L several).

### Phase 1 - Release foundations  (DONE 2026-10-01, version 2026.2.0 - see CHANGELOG.md)
Debug console, self-test, export/import + settings versioning, repair and restore-original-look, update checker,
release packaging (`tools/build_release.py`, `tools/install.ps1`), MIT licence, and password/token protection
(`neonsec.dll`, DPAPI - I wrote it, ~150 lines, source in `tools/dll`). Details below are kept for reference.
| Item | Size | Notes |
|---|---|---|
| Debug console | S | A window of internal events/errors with "copy for bug report". |
| Self-test (`/neon selftest`) | S | Files, events, toolbar, themes, profile sanity; the same checks I run by hand now. |
| Settings backup/restore (`/neon export` / `import`) | S | Also add a settings **version + migration** step so later phases can change formats safely. |
| Uninstall / repair | S | Restore stock mIRC settings; re-create missing files. |
| Update checker (`/neon update`) | M `(web)` | Needs a place to host releases (a GitHub repo is the obvious one). |
| Portable packaging | S | One ZIP + README + installer script. Plus LICENSE, CHANGELOG, version numbers. |
| **Token protection** (not on your list - required for a public release) | M | See below. |

### Phase 2 - Reading experience  (DONE 2026-10-01, version 2026.3.0, fix release 2026.3.1 - except icons in the nick list, which waits on the native-code decision)
| Item | Size | Notes |
|---|---|---|
| Mentions inbox | M | One window across networks; click to jump. Shares code with Staff log / debug console windows. |
| Unread line marker | M | |
| Channel activity colours | S | Switchbar/treebar colour by message / mention / event. |
| Nicklist polish + custom nicklist icons | M | Rank colours, away dimming, icons per rank (generated like the toolbar art). **DCX** (the dialog-extension DLL in `dll examples\dcx`, BSD licence) can style menus/treebar and draw icons - evaluate it as an *optional* layer, same rules as `neonsec.dll` (hash-verified, off if missing). Needs your OK before I load that binary. |
| Link previews | M `(web)` | `/preview url` and click-to-preview card: title, type, size. Fetch only on request. |
| Image/GIF preview window | M `(web)` | PNG/JPG/static GIF work natively; **animated GIFs would need a DLL** - I would show the first frame. |

### Phase 3 - Channel tools and safety  (DONE 2026-10-01, version 2026.4.0)
| Item | Size | Notes |
|---|---|---|
| Mass actions (kick/ban/voice by pattern, with preview) | M | Builds on the existing rank checks. |
| Quiet/mute shortcut | S | `+q` / `+b ~q:` where supported. |
| Staff log | S | Every kick/ban/mode I or the userlist did. |
| Channel stats | M | Lines per user, busiest hours; in Channel Control. |
| Topic templates | S | |
| Per-channel flood limits | S | Extends the protection tab. |
| Ignore manager | M | Expiry, scope, notes. |
| CTCP privacy | S | |

### Phase 4 - Automation  (one shared rule engine, three front-ends)
| Item | Size | Notes |
|---|---|---|
| Event actions (trigger editor) | M | The engine: trigger -> conditions -> actions. |
| Auto-replies | M | A rule type on the same engine, with cool-downs. |
| Aliases and popups editor | M | Dialog over aliases/menus you define. |
| Auto NickServ/SASL helper | M | Per-network ghost/recover/identify flows. |

### Phase 5 - Bouncer polish
| Item | Size | Notes |
|---|---|---|
| Open all | S | Staggered connect of every Lurker network profile. |
| Bouncer dashboard card | M | Networks attached, lag per network, reconnect buttons. |
| Read-marker sync | L `(cap)` `(exp)` | mIRC does not let scripts request IRCv3 capabilities cleanly; I use raw `CAP REQ` / `MARKREAD`, as I did for the soju network list. Needs a real Lurker to test - the mock server will not prove it. |

### Phase 6 - Look and feel
| Item | Size | Notes |
|---|---|---|
| Theme editor + `.mts` export | L | Live preview using the existing MTS renderer. |
| Custom event templates | M | Same tokens MTS uses, per event. |
| Icon sets | M | Flat / outline / mono variants from the asset generator. |
| Sound packs | M | Two or three shipped sets; I generate the sounds. |

### Phase 7 - Fun and extras
Quote database, karma/seen/last-spoke, polls, small games (M each, S for karma), `/np` now playing
(window title via COM/PowerShell - no DLL needed), weather/define/translate cards `(web)`.

### Phase 8 - Windows integration  (added 2026-10-01 - "possible now" list, all yes)
No DLL: the same hidden-PowerShell-helper pattern the media buttons use.
| Item | Size | Notes |
|---|---|---|
| Windows toast notifications | M | Mentions and PMs as real toasts (click to jump), respects Do not disturb. |
| Speak mentions (text-to-speech) | S | SAPI voice, per-channel opt-in. |
| Speech to text (dictate into the editbox) | M `(exp)` | Windows speech recognition through the helper. |
| Paste / image upload helper | M `(web)` | `/paste`, clipboard image or file to a host you choose, link dropped in the editbox. |
| Taskbar progress and unread badge | S | |

### Phase 9 - More IRCv3  (needs the server to offer it; mock-tested, then tried on Lurker)
Typing indicators, read markers (`draft/read-marker`), message edit and redaction display, `account-notify` /
`extended-join` (account names in the nick list and WHOIS), `chathistory` on demand ("load older messages").

### Phase 10 - Opt-in AI helpers  (DONE in 2026.12.0 - nothing is sent anywhere until you ask)
| Item | Notes |
|---|---|
| Catch me up | Summarise what you missed in a window or across the mentions inbox. |
| Translate line / selection | |
| Moderation assist | Flags likely spam/flood/ban-evasion and suggests an action; never acts by itself. |
| Plain-English commands | "kick the clones and ban their host" -> a command preview you confirm. |
Provider is your choice: a local model (Ollama on localhost) or an API key kept encrypted by `neonsec.dll`.
Text leaves your PC only when you press the button, and the dialog says exactly what is being sent.

### Phase 11 - Native UI layer  (STARTED in 2026.13.0: nick list icons + avatars + taskbar badge are done; HTML panels next)  (the only phase that needs a purpose-built DLL; I write it, source in `native/`)
Avatars and rank icons in the nick list, rich message cards, an emoji picker and optional web-style panels
(WebView2 ships with Windows 11). 32-bit like mIRC, hash-checked like `neonsec.dll`, off if missing.

### Phase 12 - Sync
Settings sync through a folder you choose (OneDrive, Dropbox, a git checkout): encrypted secrets stay on the PC.

## Tokens: how to protect them without (probably) a DLL

Plain-text tokens in `profiles.ini` are fine for you, not for a public release. Options:
1. **Windows DPAPI via a hidden PowerShell call** (`ConvertFrom-SecureString`) - encrypts to *your*
   Windows account, no DLL, a few hundred ms per save/connect. My recommendation.
2. A tiny open-source **x86 DLL** that calls DPAPI directly - faster, but one more binary for users to trust.
3. **Ask for the token each connect** (already on your wish list as an option) - no storage at all.
I would ship 1 with 3 as an alternative, and keep a DLL as a later optional speed-up.

## Public-release checklist (starts in Phase 1, finishes last)
LICENSE (your choice), README for strangers (install / first run / troubleshooting), CHANGELOG,
semantic version in one place, no personal data in the pack (checked: none), screenshots,
a name check ("NeonScript" may already be used by something else), and a published release page
for the update checker to read.

## Parked (not ticked - say the word)
Search all logs, emoji shortcodes, input formatting, reply/reaction display `[#]`, typing indicators,
paste helper, per-nick colour, highlight list, translate, quick switcher, unread hotkeys, per-channel
notification levels, layout presets, compact mode, tray notifications, DND schedule, timed bans,
ban templates, auto-join manager, op-request helper, chat history on demand, ask-for-token option,
profile groups, network colour tags, connection health, link safety, secret redaction, reminders,
scheduled messages, notify list, away presets, command palette, follow Windows light/dark, more themes,
animated splash, font presets, localisation.
