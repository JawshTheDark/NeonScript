; ============================================================================
;  NeonScript 2026  ::  main dialogs
;  Control Panel (8 pages), About box and the first-run Setup Wizard.
;  Settings are declared once in the registry below; the dialog loads and
;  saves them generically.
; ============================================================================

; ---------------------------------------------------------------- settings registry
; id -> section;item;default;type[;values]   (default _ = empty: $gettok skips empty tokens)     types: c check, e edit, m multi-edit, s combo
alias -l opt.ids return 412 413 1201 1202 1203 1205 1206 1208 1210 1212 1214 1215 1102 1105 1106 1108 1110 1111 1112 1001 1002 1003 1004 1005 1006 1007 1008 1009 101 102 103 104 105 107 201 202 203 205 206 208 301 302 303 304 305 306 307 308 401 402 403 404 501 502 504 506 507 508 509 510 511 512 513 601 602 603 604 606 607 608 701 703 705 707 801
alias -l reg {
  var %i = $1
  if (%i == 1102) return privacy;ctcp_mode;generic;s;normal,generic,silent
  if (%i == 1201) return toast;on;0;c
  if (%i == 1202) return toast;bg;1;c
  if (%i == 1203) return toast;text;1;c
  if (%i == 1205) return speak;on;0;c
  if (%i == 1206) return speak;bg;1;c
  if (%i == 1208) return speak;voice;_;e
  if (%i == 1210) return speak;rate;0;e
  if (%i == 1212) return paste;url;_;e
  if (%i == 1214) return paste;field;file;e
  if (%i == 1215) return paste;method;POST;s;POST,PUT
  if (%i == 1105) return privacy;ctcp_strangers;1;c
  if (%i == 1106) return privacy;ctcp_chan;0;c
  if (%i == 1108) return privacy;ctcp_rate;5;e
  if (%i == 1110) return privacy;ctcp_note;1;c
  if (%i == 1111) return staff;log;1;c
  if (%i == 1112) return stats;on;1;c
  if (%i == 412) return media;watch;1;c
  if (%i == 413) return media;format;is listening to <artist> - <title>;e
  if (%i == 1001) return chat;mentions;1;c
  if (%i == 1002) return chat;mpm;1;c
  if (%i == 1003) return chat;mwords;_;e
  if (%i == 1004) return chat;unread;1;c
  if (%i == 1005) return chat;nlcolors;1;c
  if (%i == 1006) return chat;nlaway;1;c
  if (%i == 1007) return chat;nlwho;1;c
  if (%i == 1008) return chat;replies;1;c
  if (%i == 1009) return web;shiftdbl;1;c
  if (%i == 101) return general;splash;1;c
  if (%i == 102) return general;welcome;1;c
  if (%i == 103) return hud;autoopen;0;c
  if (%i == 104) return toolbar;enabled;1;c
  if (%i == 105) return general;reconnect;0;c
  if (%i == 107) return general;reconnect_delay;10;e
  if (%i == 201) return conn;autoconnect;0;c
  if (%i == 202) return conn;keepalive;0;c
  if (%i == 203) return conn;rejoin;0;c
  if (%i == 205) return conn;rejoin_delay;3;e
  if (%i == 206) return conn;ajinvite;0;c
  if (%i == 208) return conn;perform;_;m
  if (%i == 301) return events;style;modern;s;modern,retro,minimal,off
  if (%i == 302) return events;symbols;unicode;s;unicode,cp1252,ascii
  if (%i == 303) return events;showhost;1;c
  if (%i == 304) return events;modes;1;c
  if (%i == 305) return events;whois;1;c
  if (%i == 306) return events;nickcolors;1;c
  if (%i == 307) return events;quiet;0;e
  if (%i == 308) return events;stampmode;1;s;0,1,2,3,4
  if (%i == 401) return sound;enabled;1;c
  if (%i == 402) return sound;highlight;1;c
  if (%i == 403) return sound;pm;1;c
  if (%i == 404) return sound;connect;1;c
  if (%i == 501) return protect;flood;0;c
  if (%i == 502) return protect;flood_lines;6;e
  if (%i == 504) return protect;flood_secs;4;e
  if (%i == 506) return protect;flood_action;ignore;s;ignore,kick,both
  if (%i == 507) return protect;ctcpflood;1;c
  if (%i == 508) return protect;pmspam;1;c
  if (%i == 509) return protect;autoop;1;c
  if (%i == 510) return protect;masshl;0;c
  if (%i == 511) return protect;masshl_n;6;e
  if (%i == 512) return protect;badwords;0;c
  if (%i == 513) return protect;clonewarn;0;c
  if (%i == 601) return away;nicksuffix;0;c
  if (%i == 602) return away;suffix;$+($chr(124),away);e
  if (%i == 603) return away;auto;0;c
  if (%i == 604) return away;auto_min;15;e
  if (%i == 606) return away;log;1;c
  if (%i == 607) return away;announce;0;c
  if (%i == 608) return away;autoback;1;c
  if (%i == 701) return bot;enabled;0;c
  if (%i == 703) return bot;channels;*;e
  if (%i == 705) return bot;cooldown;5;e
  if (%i == 707) return bot;notice;0;c
  if (%i == 801) return advanced;debug;0;c
}
; display names for combo boxes (; separated, same order as the stored values)
alias -l optnames {
  if ($1 == 301) return Modern (glyphs);Retro (irssi-like);Minimal;Native mIRC
  if ($1 == 302) return Unicode symbols;Windows (ANSI) symbols;ASCII only
  if ($1 == 308) return Off;[HH:nn];[HH:nn:ss];(HH:nn);HH:nn
  if ($1 == 506) return Ignore them;Kick them (if I am an op);Ignore and kick
  if ($1 == 1215) return POST (form upload);PUT (raw upload)
  if ($1 == 1102) return Answer normally (mIRC's default);Hide them - TIME is answered in UTC;Never answer anything (except PING)
}

; ---------------------------------------------------------------- Control Panel dialog
dialog ns_opt {
  title "NeonScript Control Panel"
  size -1 -1 352 234
  option dbu
  icon 1, 0 0 352 33, $mircexe, 0, noborder
  list 2, 6 38 70 150, size vsbar
  text "", 903, 6 194 70 18
  button "OK", 900, 196 216 46 13, ok default
  button "Cancel", 901, 246 216 46 13, cancel
  button "Apply", 902, 296 216 46 13

  ; ---- page 1 : General
  box "General", 100, 82 38 266 172
  check "Show the splash screen when mIRC starts", 101, 92 52 250 9
  check "Show the welcome banner in the status window", 102, 92 65 250 9
  check "Open the dashboard window at startup", 103, 92 78 250 9
  check "Use the NeonScript toolbar instead of mIRC's default one", 104, 92 91 250 9
  check "Reconnect automatically after a dropped connection,", 105, 92 104 180 9
  text "wait", 106, 274 105 16 9
  edit "", 107, 292 103 22 11, limit 3
  text "sec", 108, 318 105 20 9
  button "Customize toolbar...", 110, 92 126 78 13
  button "Setup wizard...", 111, 174 126 78 13
  button "Use mIRC's toolbar", 112, 256 126 86 13
  text "Tip: right-click any toolbar button for its own menu.", 113, 92 150 250 9

  ; ---- page 2 : Connection
  box "Connection", 200, 82 38 266 172
  check "Connect to my default profile when mIRC starts", 201, 92 52 250 9
  check "Keep connections alive (ping the server every 2 minutes)", 202, 92 65 250 9
  check "Rejoin a channel after I am kicked, waiting", 203, 92 78 150 9
  edit "", 205, 244 76 20 11, limit 2
  text "sec", 204, 268 78 24 9
  check "Join channels automatically when I am invited", 206, 92 91 250 9
  text "Perform on connect - one command per line, runs on every network:", 207, 92 108 250 9
  edit "", 208, 92 119 248 44, multi return vsbar autovs
  text "Logins and per-network perform lines live in Servers && Networks.", 209, 92 168 250 9
  button "Servers && Networks...", 210, 92 184 100 13

  ; ---- page 3 : Display
  box "Display", 300, 82 38 266 172
  text "Event style:", 310, 92 54 58 9
  combo 301, 152 52 100 60, drop
  text "Symbols:", 311, 92 69 58 9
  combo 302, 152 67 100 60, drop
  text "Timestamps:", 312, 92 84 58 9
  combo 308, 152 82 100 60, drop
  check "Show the address on join, part and quit", 303, 92 99 250 9
  check "Show channel mode changes", 304, 92 112 250 9
  check "Use the styled WHOIS card", 305, 92 125 250 9
  check "Colour nicknames automatically", 306, 92 138 250 9
  text "Hide join/part/quit when a channel has at least", 313, 92 155 136 9
  edit "", 307, 230 153 22 11, limit 4
  text "users (0 = never)", 314, 256 155 84 9
  button "Theme gallery...", 315, 92 176 78 13

  ; ---- page 4 : Sounds
  box "Sounds && notifications", 400, 82 38 266 172
  check "Enable NeonScript sounds", 401, 92 52 250 9
  check "Play a sound when my nickname is mentioned", 402, 92 65 250 9
  check "Play a sound when I receive a private message", 403, 92 78 250 9
  check "Play connect and disconnect sounds", 404, 92 91 250 9
  check "Do not disturb (silence sounds and flashing)", 405, 92 104 250 9
  button "Sound manager...", 410, 92 126 78 13
  button "Test sound", 411, 174 126 60 13
  check "Media buttons: watch what Windows is playing (runs a small hidden PowerShell helper)", 412, 92 150 254 9
  text "/np says:", 414, 92 166 34 9
  edit "", 413, 128 164 214 11

  ; ---- page 5 : Protection
  box "Protection", 500, 82 38 266 172
  check "Flood protection:", 501, 92 52 66 9
  edit "", 502, 160 50 18 11, limit 2
  text "lines in", 503, 182 52 26 9
  edit "", 504, 210 50 18 11, limit 2
  text "sec", 505, 232 52 16 9
  combo 506, 252 50 90 60, drop
  check "Auto-ignore CTCP floods", 507, 92 66 250 9
  check "Warn about spam and invite links in private messages", 508, 92 79 250 9
  check "Auto-op and auto-voice people on my userlist", 509, 92 92 250 9
  check "Kick mass-highlight spam, nicks per line:", 510, 92 105 136 9
  edit "", 511, 230 103 18 11, limit 2
  check "Kick people who say a banned word", 512, 92 118 250 9
  check "Warn me about clones when I join a channel", 513, 92 131 250 9
  button "Userlist...", 520, 92 152 66 13
  button "Banned words...", 521, 162 152 76 13
  button "Clone scanner", 522, 242 152 66 13

  ; ---- page 6 : Away
  box "Away", 600, 82 38 266 172
  check "Add a suffix to my nickname while away:", 601, 92 52 150 9
  edit "", 602, 246 50 50 11, limit 12
  check "Go away automatically after", 603, 92 66 104 9
  edit "", 604, 198 64 20 11, limit 3
  text "minutes of inactivity", 605, 222 66 100 9
  check "Keep a log of mentions and private messages while away", 606, 92 80 250 9
  check "Announce going away and coming back in my channels", 607, 92 93 250 9
  check "Come back automatically when I start typing", 608, 92 106 250 9
  button "Away reasons...", 610, 92 128 80 13
  button "Away log", 611, 176 128 60 13

  ; ---- page 7 : Channel commands
  box "Channel commands", 700, 82 38 266 172
  check "Enable channel commands (!seen, !roll, !8ball, !time, !help ...)", 701, 92 52 250 9
  text "Only in these channels (comma separated, * = every channel):", 702, 92 66 250 9
  edit "", 703, 92 77 150 11
  text "Cooldown per user:", 704, 92 94 70 9
  edit "", 705, 166 92 20 11, limit 3
  text "seconds", 706, 190 94 40 9
  check "Answer with notices instead of channel messages", 707, 92 108 250 9
  button "Quit, part, kick and slap messages...", 710, 92 130 130 13

  ; ---- page 9 : Chat & reading  (ids 1000-1099: 900-903 are the OK / Cancel / Apply buttons)
  box "Chat && reading", 1000, 82 38 266 172
  check "Collect mentions and private messages in the Mentions inbox", 1001, 92 52 250 9
  check "Include private messages", 1002, 108 65 230 9
  text "Extra words that count as a mention (comma separated):", 1010, 92 79 250 9
  edit "", 1003, 92 89 240 11
  check "Show a 'new messages' line where I left off in a window", 1004, 92 106 250 9
  check "Colour nicknames in the nick list by rank", 1005, 92 119 250 9
  check "Dim away users in the nick list", 1006, 108 132 230 9
  check "Ask the server who is away when I join (channels under 150 users)", 1007, 108 145 234 9
  check "Show replies and reactions (IRCv3 - when the server supports them)", 1008, 92 158 250 9
  check "Shift + double-click a link to preview it", 1009, 92 171 250 9
  button "Open the mentions inbox", 1011, 92 189 100 13

  ; ---- page 10 : Privacy & safety  (ids 1100-1199)
  box "Privacy && safety", 1100, 82 38 266 172
  text "CTCP requests (VERSION, TIME, FINGER ...) - how should I answer?", 1101, 92 52 250 9
  combo 1102, 92 62 180 60, drop
  text "mIRC always answers VERSION itself - a script cannot stop that. Everything else follows these rules:", 1103, 92 78 250 18
  check "Only answer people who share a channel with me or have a chat open", 1105, 92 98 250 9
  check "Never answer a CTCP that was sent to a whole channel", 1106, 92 111 250 9
  text "Answer at most", 1107, 92 126 50 9
  edit "", 1108, 144 124 20 11, limit 2
  text "requests a minute", 1109, 168 126 100 9
  check "Tell me in the status window when a request is hidden", 1110, 92 139 250 9
  check "Keep a staff log of the kicks, bans, modes and topics I set", 1111, 92 155 250 9
  check "Count lines per person in channels (Channel stats)", 1112, 92 168 250 9
  button "Ignore manager...", 1113, 92 188 76 13
  button "Staff log...", 1114, 172 188 56 13
  button "Channel stats...", 1115, 232 188 70 13

  ; ---- page 11 : Windows integration  (ids 1200-1299)
  box "Windows integration", 1200, 82 38 266 172
  check "Windows notifications (toasts) for mentions and private messages", 1201, 92 50 250 9
  check "only while mIRC is in the background", 1202, 108 62 230 9
  check "show the message text in the notification", 1203, 108 74 230 9
  text "Windows' own Do not disturb / Focus assist is respected, and so is NeonScript's. Switching this on adds the name NeonScript to Windows' notification settings; switching it off removes it again.", 1204, 92 87 250 27
  check "Read mentions and private messages aloud", 1205, 92 116 250 9
  check "only while mIRC is in the background", 1206, 108 128 230 9
  text "Voice:", 1207, 108 142 24 9
  edit "", 1208, 134 140 100 11
  text "Speed (-10 to 10):", 1209, 240 142 60 9
  edit "", 1210, 302 140 24 11, limit 3
  text "Upload address for /paste (https://...):", 1211, 92 158 150 9
  edit "", 1212, 92 168 250 11
  text "Form field:", 1213, 92 184 36 9
  edit "", 1214, 130 182 50 11
  combo 1215, 186 182 90 50, drop
  button "Test notification", 1216, 92 196 70 12
  button "Test voice", 1217, 166 196 50 12
  button "List voices", 1218, 220 196 50 12

  ; ---- page 8 : Advanced
  box "Advanced", 800, 82 38 266 172
  check "Write a debug log (neon.log)", 801, 92 52 250 9
  button "Open script folder", 810, 92 72 80 13
  button "Reload NeonScript", 811, 176 72 80 13
  button "Hotkeys...", 812, 260 72 78 13
  button "Reset all settings...", 813, 92 90 80 13
  button "Export settings...", 814, 176 90 80 13
  button "Uninstall...", 815, 260 90 78 13
  text "NeonScript keeps its settings in neon.ini inside its own folder, so the whole pack stays portable.", 816, 92 112 250 20
}

alias -l pagekeys return general connection display sounds protection away commands advanced chat privacy windows

on *:DIALOG:ns_opt:init:*:{
  did -g ns_opt 1 $ns.asset(header_options.png)
  did -a ns_opt 2 General
  did -a ns_opt 2 Connection
  did -a ns_opt 2 Display
  did -a ns_opt 2 Sounds
  did -a ns_opt 2 Protection
  did -a ns_opt 2 Away
  did -a ns_opt 2 Channel commands
  did -a ns_opt 2 Advanced
  did -a ns_opt 2 Chat & reading
  did -a ns_opt 2 Privacy & safety
  did -a ns_opt 2 Windows integration
  did -ra ns_opt 903 $ns.tag $+ $crlf $+ mIRC $version
  optload
  var %p = $findtok($pagekeys,%ns.optpage,1,32)
  if (%ns.optpage == protect) %p = 5
  if (!%p) %p = 1
  did -c ns_opt 2 %p
  showpage %p
}
on *:DIALOG:ns_opt:sclick:2:{ showpage $did(ns_opt,2).sel }
alias -l showpage {
  var %n = $1, %i = 1
  if (!%n) return
  ; hide everything first, then show the page - otherwise the shown page is erased by the hides
  while (%i <= 8) {
    ns.didr -h ns_opt $+(%i,00) $+(%i,99)
    inc %i
  }
  ns.didr -h ns_opt 1000 1299
  if (%n == 9) ns.didr -v ns_opt 1000 1099
  elseif (%n == 10) ns.didr -v ns_opt 1100 1199
  elseif (%n == 11) ns.didr -v ns_opt 1200 1299
  else ns.didr -v ns_opt $+(%n,00) $+(%n,99)
}

; generic load / save --------------------------------------------------------
alias -l optload {
  var %n = $numtok($opt.ids,32), %i = 1, %id, %r, %sec, %it, %def, %t, %vals, %cur, %k, %line
  while (%i <= %n) {
    %id = $gettok($opt.ids,%i,32)
    %r = $reg(%id)
    %sec = $gettok(%r,1,59)
    %it = $gettok(%r,2,59)
    %def = $gettok(%r,3,59)
    if (%def == _) %def = $null
    %t = $gettok(%r,4,59)
    if (%t == c) did $iif($ns.flag(%sec,%it,%def),-c,-u) ns_opt %id
    elseif (%t == e) did -ra ns_opt %id $ns.get(%sec,%it,%def)
    elseif (%t == m) {
      ns.ml.new
      %cur = $ns.get(%sec,%it,%def)
      %k = 1
      while ($gettok(%cur,%k,124) != $null) {
        ns.ml.add $v1
        inc %k
      }
      ns.ml.set ns_opt %id
    }
    elseif (%t == s) {
      %vals = $gettok(%r,5,59)
      %k = 1
      while ($gettok($optnames(%id),%k,59) != $null) {
        did -a ns_opt %id $v1
        inc %k
      }
      %cur = $findtok($replace(%vals,$chr(44),$chr(32)),$ns.get(%sec,%it,%def),1,32)
      did -c ns_opt %id $iif(%cur,%cur,1)
    }
    inc %i
  }
  did $iif($donotdisturb,-c,-u) ns_opt 405
}
alias -l optsave {
  var %n = $numtok($opt.ids,32), %i = 1, %id, %r, %sec, %it, %def, %t, %vals, %k, %line, %txt
  while (%i <= %n) {
    %id = $gettok($opt.ids,%i,32)
    %r = $reg(%id)
    %sec = $gettok(%r,1,59)
    %it = $gettok(%r,2,59)
    %def = $gettok(%r,3,59)
    if (%def == _) %def = $null
    %t = $gettok(%r,4,59)
    if (%t == c) ns.set %sec %it $did(ns_opt,%id).state
    elseif (%t == e) {
      %txt = $did(ns_opt,%id).text
      if (%def isnum) && (%txt !isnum) %txt = %def
      ns.set %sec %it %txt
    }
    elseif (%t == m) {
      %txt = $null
      %k = 1
      while (%k <= $did(ns_opt,%id).lines) {
        %line = $did(ns_opt,%id,%k)
        if (%line != $null) %txt = %txt $+ $iif(%txt,$chr(124)) $+ %line
        inc %k
      }
      ns.set %sec %it %txt
    }
    elseif (%t == s) {
      %vals = $replace($gettok(%r,5,59),$chr(44),$chr(32))
      ns.set %sec %it $gettok(%vals,$did(ns_opt,%id).sel,32)
    }
    inc %i
  }
  if ($did(ns_opt,405).state != $donotdisturb) donotdisturb $iif($did(ns_opt,405).state,on,off)
  ns.opt.after
}

on *:DIALOG:ns_opt:sclick:900,902:{ optsave }
on *:DIALOG:ns_opt:sclick:110:{ neon toolbar edit }
on *:DIALOG:ns_opt:sclick:111:{ neon wizard }
on *:DIALOG:ns_opt:sclick:112:{
  did -u ns_opt 104
  ns.set toolbar enabled 0
  toolbar -r
}
on *:DIALOG:ns_opt:sclick:210:{ neon servers }
on *:DIALOG:ns_opt:sclick:315:{ neon themes }
on *:DIALOG:ns_opt:sclick:410:{ neon sounds }
on *:DIALOG:ns_opt:sclick:411:{ neon testsound }
on *:DIALOG:ns_opt:sclick:520:{ neon users }
on *:DIALOG:ns_opt:sclick:521:{ neon words }
on *:DIALOG:ns_opt:sclick:522:{ neon clones }
on *:DIALOG:ns_opt:sclick:610:{ neon messages away }
on *:DIALOG:ns_opt:sclick:1011:{ neon mentions }
on *:DIALOG:ns_opt:sclick:1113:{ neon ignores }
on *:DIALOG:ns_opt:sclick:1216:{ optsave | neon toast test }
on *:DIALOG:ns_opt:sclick:1217:{ optsave | neon speak test }
on *:DIALOG:ns_opt:sclick:1218:{ optsave | neon speak voices }
on *:DIALOG:ns_opt:sclick:1114:{ neon stafflog }
on *:DIALOG:ns_opt:sclick:1115:{ neon stats }
on *:DIALOG:ns_opt:sclick:611:{ neon awaylog }
on *:DIALOG:ns_opt:sclick:710:{ neon messages }
on *:DIALOG:ns_opt:sclick:810:{ run explorer $qt($scriptdir) }
on *:DIALOG:ns_opt:sclick:811:{ neon reload }
on *:DIALOG:ns_opt:sclick:812:{ neon hotkeys }
on *:DIALOG:ns_opt:sclick:813:{ ns.later neon reset }
alias neon.reset {
  if ($input(Reset every NeonScript setting to its default? Profiles and message lists are kept.,yq,Reset settings)) {
    .remove $qt($ns.ini)
    ns.opt.after
    if ($dialog(ns_opt)) dialog -x ns_opt
    ns.say settings reset to defaults.
  }
}
on *:DIALOG:ns_opt:sclick:814:{
  var %f = $sfile($+($mircdir,neon_settings.ini),Export NeonScript settings,Save)
  if (%f) {
    .copy -o $qt($ns.ini) $qt(%f)
    ns.say settings exported to %f
  }
}
on *:DIALOG:ns_opt:sclick:815:{ ns.later neon uninstall }

; side effects of changed settings
alias ns.opt.after {
  ns.ev.nickcolors $iif($ns.flag(events,nickcolors,1),on,off)
  ns.ev.applystamp
  ajinvite $iif($ns.flag(conn,ajinvite,0),on,off)
  if ($ns.flag(toolbar,enabled,1)) ns.tb.build
  else toolbar -r
  .signal -n ns.opts
}

; ---------------------------------------------------------------- About box
dialog ns_about {
  title "About NeonScript"
  size -1 -1 250 172
  option dbu
  icon 1, 0 0 250 60, $mircexe, 0, noborder
  text "", 2, 6 64 238 10, center
  text "A ground-up remake of the classic full-feature mIRC script packs, rebuilt for mIRC 7.85 and the modern IRC: IRCv3, dark mode, TLS and Unicode, with no DLLs.", 3, 12 76 226 22, center
  edit "", 4, 6 102 238 44, read multi vsbar
  button "Command reference", 5, 6 152 76 13
  button "OK", 6, 190 152 54 13, ok default cancel
}
on *:DIALOG:ns_about:init:*:{
  did -g ns_about 1 $ns.asset(banner_about.png)
  did -ra ns_about 2 $ns.name $ns.ver
  ns.ml.new
  ns.ml.add mIRC $version on Windows $os $iif($portable,(portable))
  ns.ml.add Theme: $ns.theme.name($ns.theme.current) $+ , events: $ns.get(events,style,modern)
  ns.ml.add Modules loaded: $ns.modcount $+ / $+ $numtok($ns.modules,32)
  ns.ml.add TLS: $iif($sslready,ready - $sslversion,not available)
  ns.ml.add Folder: $scriptdir
  ns.ml.set ns_about 4
}
on *:DIALOG:ns_about:sclick:5:{ neonhelp }
alias ns.modcount {
  var %i = 1, %c = 0
  while ($gettok($ns.modules,%i,32)) {
    if ($ns.isloaded($+($scriptdir,$v1,.mrc))) inc %c
    inc %i
  }
  return %c
}
alias neon.about ns.dlg ns_about ns_about

; ---------------------------------------------------------------- Setup Wizard
dialog ns_wiz {
  title "NeonScript Setup"
  size -1 -1 300 214
  option dbu
  icon 1, 0 0 300 30, $mircexe, 0, noborder

  ; ---- page 1 : welcome
  box "", 10, 6 34 288 150
  text "Welcome to NeonScript!", 11, 16 46 268 10
  text "This quick setup takes about a minute. It will:", 12, 16 62 268 10
  text "- set your identity (nickname, real name)", 13, 22 76 262 10
  text "- add your first network and its channels", 14, 22 88 262 10
  text "- pick a look: theme, toolbar and event style", 15, 22 100 262 10
  text "Everything can be changed later from the Control Panel (type /neon). Nothing is sent anywhere - all settings stay in this folder.", 16, 16 122 268 24

  ; ---- page 2 : identity
  box "Who are you?", 20, 6 34 288 150
  text "Nickname:", 21, 16 52 70 9
  edit "", 22, 90 50 110 11
  text "Alternative nick:", 23, 16 68 70 9
  edit "", 24, 90 66 110 11
  text "Real name:", 25, 16 84 70 9
  edit "", 26, 90 82 150 11
  text "Email (optional):", 27, 16 100 70 9
  edit "", 28, 90 98 150 11
  text "Your alternative nick is used when the first one is taken.", 29, 16 120 268 9

  ; ---- page 3 : network
  box "Where do you chat?", 30, 6 34 288 150
  list 31, 16 48 100 120, size vsbar
  text "Channels to join (comma separated):", 32, 124 48 160 9
  edit "", 33, 124 59 160 11
  check "Connect with TLS (encrypted)", 34, 124 76 160 9
  check "Connect as soon as I click Finish", 35, 124 90 160 9
  check "Connect automatically when mIRC starts", 36, 124 104 160 9
  text "", 37, 124 124 160 36

  ; ---- page 4 : look
  box "Pick a look", 40, 6 34 288 150
  list 41, 16 48 70 100, size vsbar
  icon 42, 92 48 142 83, $mircexe, 0, noborder
  check "Use the NeonScript toolbar", 43, 92 136 140 9
  text "Event style:", 44, 92 150 44 9
  combo 45, 138 148 96 50, drop
  check "Show the splash screen", 46, 16 154 70 9

  ; ---- page 5 : finish
  box "All set", 50, 6 34 288 150
  text "Click Finish to apply your choices.", 51, 16 48 268 10
  text "", 52, 16 64 268 50
  check "Open the Control Panel afterwards", 53, 16 126 268 9

  button "< Back", 90, 132 192 50 13
  button "Next >", 91, 186 192 50 13, default
  button "Cancel", 92, 244 192 50 13, cancel
}
alias -l wizmax return 5
on *:DIALOG:ns_wiz:init:*:{
  did -g ns_wiz 1 $ns.asset(header_wizard.png)
  set -u3600 %ns.wizpage 1
  did -ra ns_wiz 22 $iif($mnick,$mnick,$me)
  did -ra ns_wiz 24 $iif($anick,$anick,$+($me,_))
  did -ra ns_wiz 26 $fullname
  did -ra ns_wiz 28 $emailaddr
  var %i = 1, %f = $ns.data(networks.ini)
  while ($gettok($replace($readini(%f,n,networks,order),$chr(44),$chr(32)),%i,32)) {
    did -a ns_wiz 31 $readini(%f,n,$v1,name)
    inc %i
  }
  did -c ns_wiz 31 1
  wiznet
  did -c ns_wiz 34
  %i = 1
  while ($gettok($ns.theme.ids,%i,32)) {
    did -a ns_wiz 41 $ns.theme.name($v1)
    inc %i
  }
  var %tn = $findtok($ns.theme.ids,$ns.theme.current,1,32)
  did -c ns_wiz 41 $iif(%tn,%tn,1)
  wizprev
  did -c ns_wiz 43
  did -a ns_wiz 45 Modern (glyphs)
  did -a ns_wiz 45 Retro (irssi-like)
  did -a ns_wiz 45 Minimal
  did -a ns_wiz 45 Native mIRC
  did -c ns_wiz 45 1
  did -c ns_wiz 46
  wizshow 1
}
alias -l wizshow {
  var %p = $1, %i = 1
  set -u3600 %ns.wizpage %p
  while (%i <= $wizmax) {
    ns.didr -h ns_wiz $+(%i,0) $+(%i,9)
    inc %i
  }
  ns.didr -v ns_wiz $+(%p,0) $+(%p,9)
  did $iif(%p == 1,-b,-e) ns_wiz 90
  did -ra ns_wiz 91 $iif(%p == $wizmax,Finish,Next >)
  if (%p == $wizmax) wizsummary
}
alias -l wiznet {
  var %n = $did(ns_wiz,31).sel, %f = $ns.data(networks.ini), %id = $gettok($replace($readini(%f,n,networks,order),$chr(44),$chr(32)),%n,32)
  if (!%id) return
  did $iif($readini(%f,n,%id,ssl) == 1,-c,-u) ns_wiz 34
  did -ra ns_wiz 37 $readini(%f,n,%id,server) $+ : $+ $readini(%f,n,%id,port)
}
alias -l wizprev {
  var %id = $gettok($ns.theme.ids,$did(ns_wiz,41).sel,32)
  if (%id) did -g ns_wiz 42 $ns.asset(theme_ $+ %id $+ .png)
}
alias -l wizsummary {
  var %f = $ns.data(networks.ini), %id = $gettok($replace($readini(%f,n,networks,order),$chr(44),$chr(32)),$did(ns_wiz,31).sel,32)
  did -r ns_wiz 52
  did -ra ns_wiz 52 Identity: $did(ns_wiz,22).text $+ $chr(32) $+ $chr(40) $+ $did(ns_wiz,24).text $+ $chr(41) $+ $crlf $+ Network: $readini(%f,n,%id,name) $+ , channels: $iif($did(ns_wiz,33).text != $null,$did(ns_wiz,33).text,none) $+ $crlf $+ Theme: $ns.theme.name($gettok($ns.theme.ids,$did(ns_wiz,41).sel,32)) $+ $crlf $+ Toolbar: $iif($did(ns_wiz,43).state,NeonScript,mIRC default)
}
on *:DIALOG:ns_wiz:sclick:31:{ wiznet }
on *:DIALOG:ns_wiz:sclick:41:{ wizprev }
on *:DIALOG:ns_wiz:sclick:90:{ if (%ns.wizpage > 1) wizshow $calc(%ns.wizpage - 1) }
on *:DIALOG:ns_wiz:sclick:91:{
  if (%ns.wizpage < $wizmax) { wizshow $calc(%ns.wizpage + 1) | return }
  wizfinish
}
on *:DIALOG:ns_wiz:close:*:{ ns.set general wizard 1 }
alias -l wizfinish {
  var %nick = $did(ns_wiz,22).text, %anick = $did(ns_wiz,24).text
  if (%nick) mnick %nick
  if (%anick) anick %anick
  if ($did(ns_wiz,26).text) fullname $did(ns_wiz,26).text
  if ($did(ns_wiz,28).text) emailaddr $did(ns_wiz,28).text
  ; look
  var %theme = $gettok($ns.theme.ids,$did(ns_wiz,41).sel,32)
  var %style = $gettok(modern retro minimal off,$did(ns_wiz,45).sel,32)
  ns.set events style %style
  ns.set general splash $did(ns_wiz,46).state
  ns.set toolbar enabled $did(ns_wiz,43).state
  ; network profile
  var %f = $ns.data(networks.ini), %nid = $gettok($replace($readini(%f,n,networks,order),$chr(44),$chr(32)),$did(ns_wiz,31).sel,32)
  var %pid = $ns.srv.add($readini(%f,n,%nid,name),$readini(%f,n,%nid,server),$readini(%f,n,%nid,port),$did(ns_wiz,34).state,%nick,%anick,$replace($did(ns_wiz,33).text,$chr(44),$chr(32)))
  if ($did(ns_wiz,36).state) ns.set conn autoconnect 1
  var %open = $did(ns_wiz,53).state, %now = $did(ns_wiz,35).state
  ns.set general wizard 1
  ; apply after the dialog has closed
  .timer.nswiz -o 1 0 ns.wizapply %theme %pid %now %open
  dialog -x ns_wiz
}
alias ns.wizapply {
  ns.theme.apply $1
  if ($ns.flag(toolbar,enabled,1)) ns.tb.build
  else toolbar -r
  ns.opt.after
  ns.say setup complete - enjoy! Type $+($ns.cc(11),/neon,$ns.o) to tweak anything.
  if ($3) && ($2) ns.srv.connect $2
  if ($4) neon options
}
alias neon.wizard ns.dlg ns_wiz ns_wiz
