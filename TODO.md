# NeonScript - to fix later

## Done (2026-10-02)
- [x] **Flat menus** - the `NeonScript >` submenu is gone from the channel, nicklist, query and status
  popups and from the Commands menu; items sit directly in the menu. Give/Take rank items appear
  only when the server has the mode and your rank allows it, and the label follows what the nick
  already holds ("Give op (@)" / "Take op (@)"). (`neon_alias.mrc`, `neon.mrc`)
- [x] **Banners edge to edge** - every dialog header spans the full dialog width; the header images are
  now rendered at each dialog's exact aspect ratio (`tools/make_assets.py`, `HEADERS`), including a
  new About banner and separate Bouncer / Lurker networks headers.
- [x] **`/neonhelp` layout** - no more cut-off labels: short labels use two columns with wrapped
  descriptions hanging under the description column, long labels get their own line with the
  description indented below. Commands are bold/bright, descriptions use the theme's label colour.
  The `/neon messages [...]` entry no longer contains a `|` that broke the column split.
- [x] **Channel Control mode switches** - ticking n/t/i/m/s/p/c/r/S now applies the change a second
  later (several ticks go out as one MODE line); key and limit use *Apply modes*. A result bar at
  the bottom of the dialog (visible on every tab) reports: what was sent, "Done - #chan is now +nti",
  or "Not applied: +S - the server said: ... not channel operator" (numerics 467, 472, 477, 482,
  484, 485, 489, 520), and tells you when you are not an op / not on a channel / not connected.
  The Users and Lists tabs report in the same bar instead of the hidden active window.
  Tested against the mock server for success and refusal; **not yet re-tested on a real network**.
- [x] **Doubled first letter in MTS chat** (`<NNova>`) - fixed earlier.

## Phase 1 (2026.2.0) - done
Self-test, debug console, backup/restore, repair, original-look restore, settings versioning, update check, token
protection (DPAPI), release packaging, MIT licence. See CHANGELOG.md.

## Phase 2 (2026.3.0) - done
Mentions inbox, new-messages line, nick-list colours + away dimming, replies/reactions, link and image previews,
categorised right-click menus (mIRC's stock ones replaced). Tested against the mock servers; right-click menus
were loaded and their label logic checked but **not yet seen drawn** (my test harness cannot open mIRC's popups).

## Phases 3-10 (2026.4.0 - 2026.12.0) - done, tested on the mock servers only
Moderation tools, Windows integration, automation rules, bouncer dashboard, icon sets and sound packs, theme editor, channel
extras and web cards, IRCv3 extras, opt-in AI helpers. See CHANGELOG.md. None of it has met a real network yet: please try
`/neon selftest`, a Lurker connect, `/neon ircextras`, and (if you want it) `/ai test` against your own Ollama or API key.

## Still open
* AI helpers were tested against a stand-in service only - the first real Ollama / OpenAI / Anthropic call may need a tweak
  (model name, address). `/ai test` is the quickest check; `/neon debug` shows what failed.
* If Channel Control still misbehaves on a real network, note the network, the channel and your
  rank: the result bar should now say why (refused / reverted / not an op).
* Setup Wizard changes the alternate nickname but `$mnick` (mIRC's main nick) stays unchanged.
* Lurker discovery is verified against the mock server only, not the real chat.irc.so.
* Popup menus were checked for load errors and label logic, but I have not looked at them rendered
  on screen - right-click a nick, a channel, a query and the status window and tell me what looks off.
* Release prep still needs YOUR input: the copyright name in `LICENSE` (placeholder "NeonScript authors"), where releases
  will be hosted (for `/neon update url`), and a name check for "NeonScript".
* Your mIRC server list already has chat.irc.so on a TLS port (1025), so use that port rather than 6697:
  `/neon bnc add Lurker chat.irc.so 1025 <username>`.
