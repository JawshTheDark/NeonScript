; ============================================================================
;  NeonScript 2026  ::  Channel Control   (replaces mIRC's Channel Central)
;
;  /channel [#chan]  and everything that used to open Channel Central (the
;  channel popup's "Channel Modes", the toolbar button, /neon cc) now opens this:
;    General     topic + topic history, mode switches, key, limit
;    Users       find, whois/query/kick/ban, give or take ~ & @ % + (rank aware)
;    Lists       bans / exceptions / invites / quiets with who set them and when
;    Protection  mode lock, topic protect, greeting, auto-voice, auto-rejoin
;    Info        modes, creation time, topic author, rank breakdown
;  Settings are remembered per network + channel in chan.ini.
; ============================================================================

alias channel ns.cc.open $1
alias neon.cc ns.cc.open $1
alias neon.chan ns.cc.open $1

alias ns.cc.open {
  var %c = $iif($ns.ischan($1),$1,$active), %was = $dialog(ns_cc)
  if (!$ns.ischan(%c)) {
    ns.err open a channel window first (or type /channel #name).
    return
  }
  set %ns.cc.chan %c
  ns.dlg ns_cc ns_cc
  if (%was) ns.cc.pick %c
}

; ---------------------------------------------------------------- per-channel settings (chan.ini)
alias ns.ch.ini return $+($scriptdir,chan.ini)
alias ns.ch.sec return $+($iif($network,$network,$iif($server,$server,local)),:,$lower($1))
alias ns.ch.get {
  var %v = $readini($ns.ch.ini,n,$ns.ch.sec($1),$2)
  if ($len(%v) == 0) return $3-
  return %v
}
alias ns.ch.set {
  if ($3- == $null) writeini -nz $qt($ns.ch.ini) $ns.ch.sec($1) $2
  else writeini -n $qt($ns.ch.ini) $ns.ch.sec($1) $2 $3-
}
alias ns.ch.hasmode return $regex($1,$+(/,$2,/))

; ---------------------------------------------------------------- topic history + channel facts from raws
alias ns.ch.histfile return $ns.data(topics.txt)
alias ns.ch.hist {
  ; ns.ch.hist <chan> <nick> <topic...>
  if ($3- == $null) return
  if ($ns.ch.lasttopic($1) == $3-) return
  write $qt($ns.ch.histfile) $+($ctime,$chr(9),$ns.ch.sec($1),$chr(9),$2,$chr(9),$3-)
}
alias ns.ch.lasttopic {
  var %f = $ns.ch.histfile, %i = $lines(%f), %sec = $ns.ch.sec($1), %l, %stop = $calc($lines(%f) - 300)
  while (%i > 0) && (%i > %stop) {
    %l = $read(%f,n,%i)
    if ($gettok(%l,2,9) == %sec) return $gettok(%l,4-,9)
    dec %i
  }
  return $null
}
raw 332:*:{ ns.ch.hist $2 (on join) $3- }
raw 333:*:{
  hadd -m ns.chinfo $+($cid,.,$2,.by) $3
  hadd -m ns.chinfo $+($cid,.,$2,.when) $4
}
raw 329:*:{ hadd -m ns.chinfo $+($cid,.,$2,.created) $3 }
on *:TOPIC:#:{
  ns.ch.hist $chan $nick $1-
  ns.cc.touch $chan
  ; topic protect (not for my own changes, replayed history, or protected users)
  if ($nick == $me) return
  if ($ns.bnc.q) return
  if ($ns.ch.get($chan,topicprotect,0) != 1) return
  if ($ns.acc.safe($nick,$chan)) return
  .timer. $+ $md5($+($cid,$chan,topic)) -o 1 1 scid $cid ns.ch.enforce $chan
}

; refresh the open dialog (debounced) when something changes in its channel
alias ns.cc.touch {
  if ($dialog(ns_cc)) && (%ns.cc.chan == $1) .timer.nsccr -o 1 1 ns.cc.refresh
}
on *:RAWMODE:#:{
  ns.cc.touch $chan
  ; mode lock
  if ($nick == $me) return
  if ($ns.bnc.q) return
  if ($ns.ch.get($chan,modelock_on,0) != 1) return
  .timer. $+ $md5($+($cid,$chan,modelock)) -o 1 1 scid $cid ns.ch.enforce $chan
}
on *:PART:#:{ ns.cc.touch $chan }
on *:QUIT:{
  var %i = $comchan($nick,0)
  while (%i) {
    ns.cc.touch $comchan($nick,%i)
    dec %i
  }
}
on *:KICK:#:{
  ns.cc.touch $chan
  ; rejoin after a kick: per channel setting, or the global one in Control Panel > Connection
  if ($knick != $me) return
  if ($ns.bnc.q) return
  if ($ns.ch.get($chan,rejoin,0) != 1) && (!$ns.flag(conn,rejoin,0)) return
  .timer -o 1 $ns.get(conn,rejoin_delay,3) scid $cid join $chan $chan($chan).key
}
on *:BAN:#:{ ns.cc.touch $chan }
on *:UNBAN:#:{ ns.cc.touch $chan }
on *:NICK:{
  var %i = $comchan($newnick,0)
  while (%i) {
    ns.cc.touch $comchan($newnick,%i)
    dec %i
  }
}

; ---------------------------------------------------------------- the dialog
dialog ns_cc {
  title "Channel Control"
  size -1 -1 340 232
  option dbu
  icon 1, 0 0 340 30, $mircexe, 0, noborder
  text "Channel:", 2, 6 37 32 9
  combo 3, 40 35 110 80, drop
  text "", 4, 156 37 178 9
  tab "General", 10, 6 50 328 158
  tab "Users", 11
  tab "Lists", 12
  tab "Protection", 13
  tab "Info", 14

  ; ---- General
  text "Topic:", 20, 14 70 30 9, tab 10
  edit "", 21, 14 80 312 11, autohs tab 10
  button "Set topic", 22, 14 95 46 12, tab 10
  button "Clear", 23, 64 95 34 12, tab 10
  combo 24, 102 95 168 90, drop tab 10
  button "Templates...", 27, 274 95 52 12, tab 10
  text "", 25, 14 111 312 9, tab 10
  box "Channel modes", 26, 14 122 312 82, tab 10
  check "n  no outside messages", 30, 22 134 96 9, tab 10
  check "t  only ops set the topic", 31, 22 146 96 9, tab 10
  check "i  invite only", 32, 22 158 96 9, tab 10
  check "m  moderated", 33, 128 134 96 9, tab 10
  check "s  secret", 34, 128 146 96 9, tab 10
  check "p  private", 35, 128 158 96 9, tab 10
  check "c  no colours", 36, 232 134 90 9, tab 10
  check "r  registered users only", 37, 232 146 90 9, tab 10
  check "S  TLS users only", 38, 232 158 90 9, tab 10
  check "Key:", 40, 22 174 28 9, tab 10
  edit "", 41, 52 172 70 11, autohs tab 10
  check "Limit:", 42, 132 174 34 9, tab 10
  edit "", 43, 168 172 36 11, autohs limit 5 tab 10
  button "Apply modes", 44, 252 171 66 12, tab 10
  text "", 45, 22 188 296 9, tab 10

  ; ---- Users
  text "Find:", 50, 14 70 24 9, tab 11
  edit "", 51, 40 68 118 11, autohs tab 11
  list 52, 14 84 144 118, size extsel vsbar tab 11
  button "Whois", 53, 168 68 50 12, tab 11
  button "Query", 54, 222 68 50 12, tab 11
  button "Slap", 55, 276 68 50 12, tab 11
  button "Kick", 56, 168 84 50 12, tab 11
  button "Ban", 57, 222 84 50 12, tab 11
  button "Kick + ban", 58, 276 84 50 12, tab 11
  text "Give:", 59, 168 104 24 9, tab 11
  button "", 60, 194 102 24 12, tab 11
  button "", 61, 220 102 24 12, tab 11
  button "", 62, 246 102 24 12, tab 11
  button "", 63, 272 102 24 12, tab 11
  button "", 64, 298 102 24 12, tab 11
  text "Take:", 65, 168 120 24 9, tab 11
  button "", 66, 194 118 24 12, tab 11
  button "", 67, 220 118 24 12, tab 11
  button "", 68, 246 118 24 12, tab 11
  button "", 69, 272 118 24 12, tab 11
  button "", 70, 298 118 24 12, tab 11
  button "Kick && ban dialog...", 71, 168 138 158 12, tab 11
  button "Add to userlist...", 72, 168 154 158 12, tab 11
  text "", 73, 168 172 158 30, tab 11

  ; ---- Lists
  text "List:", 80, 14 70 22 9, tab 12
  combo 81, 38 68 120 70, drop tab 12
  button "Refresh", 82, 166 67 46 12, tab 12
  text "", 83, 216 70 110 9, tab 12
  list 84, 14 84 312 84, size extsel vsbar hsbar tab 12
  edit "", 85, 14 174 218 11, autohs tab 12
  button "Add", 86, 236 173 40 12, tab 12
  button "Remove", 87, 280 173 46 12, tab 12
  text "Needs halfop or higher. Type a mask like *!*@host or a nick.", 88, 14 190 262 9, tab 12
  button "Clear all...", 89, 280 188 46 12, tab 12

  ; ---- Protection
  text "Remembered per network and channel. Most actions need ops.", 90, 14 68 312 9, tab 13
  check "Lock these modes (re-applied if changed, while I am an op):", 91, 14 82 230 9, tab 13
  edit "", 92, 250 80 76 11, autohs tab 13
  check "Protect the topic - restore it when someone else changes it", 93, 14 98 230 9, tab 13
  button "Use current", 94, 250 96 76 12, tab 13
  check "Greet people who join:", 95, 14 114 84 9, tab 13
  edit "", 96, 100 112 226 11, autohs tab 13
  check "send the greeting as a notice  (placeholders: <nick> <chan>)", 97, 100 126 226 9, tab 13
  check "Give everyone voice (+v) when they join", 98, 14 142 230 9, tab 13
  check "Rejoin automatically if I am kicked from here", 99, 14 156 230 9, tab 13
  check "Own flood limit here:", 102, 14 170 74 9, tab 13
  edit "", 103, 90 168 18 11, autohs limit 3 tab 13
  text "lines in", 104, 111 170 28 9, tab 13
  edit "", 105, 140 168 18 11, autohs limit 3 tab 13
  text "sec", 106, 161 170 14 9, tab 13
  combo 107, 178 168 148 60, drop tab 13
  button "Save", 100, 14 190 46 12, tab 13
  text "", 101, 64 192 262 9, tab 13

  ; ---- Info
  edit "", 110, 14 68 312 120, read multi vsbar tab 14
  button "Refresh", 111, 14 190 46 12, tab 14
  button "Channel stats...", 112, 64 190 70 12, tab 14
  button "Staff log...", 113, 138 190 60 12, tab 14

  text "", 6, 6 215 276 9
  button "Close", 120, 286 212 48 13, ok cancel
}

alias -l cur return $did(ns_cc,3).text

on *:DIALOG:ns_cc:init:*:{
  did -g ns_cc 1 $ns.asset(header_cc.png)
  var %i = 1, %n = $chan(0), %sel = 1
  while (%i <= %n) {
    did -a ns_cc 3 $chan(%i)
    if ($chan(%i) == %ns.cc.chan) %sel = %i
    inc %i
  }
  did -c ns_cc 3 %sel
  ; list types
  did -a ns_cc 81 Bans (+b)
  did -c ns_cc 81 1
  if ($status == connected) mode $cur
  fillall
}
alias ns.cc.pick {
  if (!$dialog(ns_cc)) return
  var %i = 1, %n = $did(ns_cc,3).lines
  while (%i <= %n) {
    if ($did(ns_cc,3,%i) == $1) did -c ns_cc 3 %i
    inc %i
  }
  set %ns.cc.chan $1
  fillall
}
alias ns.cc.refresh {
  if (!$dialog(ns_cc)) return
  if (!$ns.ischan($cur)) return
  fillall
}
alias -l fillall {
  var %c = $cur
  if (!$ns.ischan(%c)) {
    did -ra ns_cc 4 not on that channel any more
    return
  }
  set %ns.cc.chan %c
  var %rk = $ns.rk.of(%c,$me), %me = a regular user
  if (%rk) %me = $ns.rk.name(%rk) $+ $chr(32) $+ $chr(40) $+ %rk $+ $chr(41)
  did -ra ns_cc 4 %c $+ $chr(32) $+ $chr(183) $+ $chr(32) $+ $nick(%c,0) users $+ $chr(32) $+ $chr(183) $+ $chr(32) $+ you are %me
  fillgen
  fillusers
  filllists
  fillprot
  fillinfo
}
on *:DIALOG:ns_cc:sclick:3:{ fillall }

; ---------------------------------------------------------------- General tab
alias -l fid {
  ; flag letter -> checkbox id
  var %l = $1
  if (%l === n) return 30
  if (%l === t) return 31
  if (%l === i) return 32
  if (%l === m) return 33
  if (%l === s) return 34
  if (%l === p) return 35
  if (%l === c) return 36
  if (%l === r) return 37
  if (%l === S) return 38
  return 0
}
alias -l flags return n t i m s p c r S
alias -l fillgen {
  var %c = $cur, %m = $gettok($chan(%c).mode,1,32), %op = $ns.rk.atleast(%c,$me,o), %by = $hget(ns.chinfo,$+($cid,.,%c,.by)), %when = $hget(ns.chinfo,$+($cid,.,%c,.when))
  var %i = 1, %l, %cm = $chanmodes, %eq = $pos(%cm,$chr(61)), %dflags
  if (%eq) %cm = $mid(%cm,$calc(%eq + 1))
  %dflags = $gettok(%cm,4,44)
  did -ra ns_cc 21 $chan(%c).topic
  if (%by) did -ra ns_cc 25 Topic set by %by $iif(%when,on $asctime(%when,ddd d mmm yyyy HH:nn))
  else did -ra ns_cc 25 $chr(160)
  fillhist
  while ($gettok($flags,%i,32)) {
    %l = $v1
    did $iif($ns.ch.hasmode(%m,%l),-c,-u) ns_cc $fid(%l)
    ; hide switches this server does not have (when connected and the 005 list is known)
    if ($status == connected) && (%dflags != $null) && (!$ns.ch.hasmode(%dflags,%l)) did -h ns_cc $fid(%l)
    else did -v ns_cc $fid(%l)
    inc %i
  }
  did $iif($chan(%c).key,-c,-u) ns_cc 40
  did -ra ns_cc 41 $chan(%c).key
  did $iif($chan(%c).limit,-c,-u) ns_cc 42
  did -ra ns_cc 43 $chan(%c).limit
  if (%op) {
    did -e ns_cc 30-38,40-44
    did -ra ns_cc 45 You are an op here. Tick a switch to apply it; key and limit use the Apply modes button.
  }
  else {
    did -b ns_cc 30-38,40-44
    did -ra ns_cc 45 Channel modes can only be changed by ops ( $+ $ns.rk.char(o) $+ ) or higher.
  }
  ; setting the topic: ops always, everyone if the channel is not +t
  did $iif((%op) || (!$ns.ch.hasmode(%m,t)),-e,-b) ns_cc 22,23
}
; topic history combo (newest first)
alias -l fillhist {
  var %c = $cur, %f = $ns.ch.histfile, %i = $lines(%f), %stop = $calc($lines(%f) - 400), %sec = $ns.ch.sec(%c), %l, %n = 0, %t
  did -r ns_cc 24
  if ($hget(ns.cctop)) hfree ns.cctop
  hmake ns.cctop 20
  did -a ns_cc 24 Topic history...
  while (%i > 0) && (%i > %stop) && (%n < 15) {
    %l = $read(%f,n,%i)
    if ($gettok(%l,2,9) == %sec) {
      inc %n
      %t = $gettok(%l,4-,9)
      did -a ns_cc 24 $asctime($gettok(%l,1,9),HH:nn) $gettok(%l,3,9) $+ : $left(%t,70)
      hadd -m ns.cctop $calc(%n + 1) %t
    }
    dec %i
  }
  did -c ns_cc 24 1
}
on *:DIALOG:ns_cc:sclick:24:{
  var %n = $did(ns_cc,24).sel, %t = $hget(ns.cctop,%n)
  if (%n > 1) && (%t != $null) did -ra ns_cc 21 %t
}
on *:DIALOG:ns_cc:sclick:22:{
  var %c = $cur, %t = $did(ns_cc,21).text
  if (!$ns.ischan(%c)) return
  topic %c %t
  if ($ns.ch.get(%c,topicprotect,0) == 1) ns.ch.set %c topicsaved %t
}
on *:DIALOG:ns_cc:sclick:23:{
  var %c = $cur
  if ($ns.ischan(%c)) raw TOPIC %c $+ $chr(32) $+ $chr(58)
  did -r ns_cc 21
}
; result line at the bottom of the dialog (always visible, whatever tab is open)
alias -l ccsay did -ra ns_cc 6 $left($1-,95)
; ticking a mode switch applies it a second after the last tick, so several ticks go out as one MODE
; line.  Key and limit need text first, so those wait for the Apply button.
on *:DIALOG:ns_cc:sclick:30-38:{
  if (!$ns.rk.atleast($cur,$me,o)) {
    ccsay You need ops ( $+ $ns.rk.char(o) $+ ) in $cur to change channel modes.
    fillgen
    return
  }
  ccsay Applying the mode change...
  .timer.nsccap -o 1 1 ns.cc.apply
}
on *:DIALOG:ns_cc:sclick:40,42:{ ccsay Key / limit changed - press Apply modes to send it. }
on *:DIALOG:ns_cc:edit:41,43:{ ccsay Key / limit changed - press Apply modes to send it. }
on *:DIALOG:ns_cc:sclick:44:{
  .timer.nsccap off
  ns.cc.apply 1
}
; work out what differs between the switches and the channel, send it, then check the server did it
alias ns.cc.apply {
  if (!$dialog(ns_cc)) return
  var %c = $cur, %m = $gettok($chan(%c).mode,1,32), %i = 1, %l, %plus, %minus, %pp, %mp, %want, %have, %key = $chan(%c).key, %lim = $chan(%c).limit
  if (!$ns.ischan(%c)) {
    ccsay Pick a channel you are on first.
    return
  }
  if ($status != connected) {
    ccsay Not connected to a server.
    return
  }
  if (!$ns.rk.atleast(%c,$me,o)) {
    ccsay You need ops ( $+ $ns.rk.char(o) $+ ) in %c to change channel modes.
    return
  }
  while ($gettok($flags,%i,32)) {
    %l = $v1
    %want = $did(ns_cc,$fid(%l)).state
    %have = $ns.ch.hasmode(%m,%l)
    if (%want) && (!%have) %plus = %plus $+ %l
    elseif (!%want) && (%have) %minus = %minus $+ %l
    inc %i
  }
  ; key
  if ($did(ns_cc,40).state) && ($did(ns_cc,41).text != $null) && ($did(ns_cc,41).text != %key) {
    %plus = %plus $+ k
    %pp = %pp $did(ns_cc,41).text
  }
  elseif (!$did(ns_cc,40).state) && (%key) {
    %minus = %minus $+ k
    %mp = %mp %key
  }
  elseif ($did(ns_cc,40).state) && ($did(ns_cc,41).text == $null) && (!%key) {
    ccsay Type the key in the box next to Key: first.
    return
  }
  ; limit
  if ($did(ns_cc,42).state) && ($did(ns_cc,43).text isnum) && ($did(ns_cc,43).text != %lim) {
    %plus = %plus $+ l
    %pp = %pp $did(ns_cc,43).text
  }
  elseif (!$did(ns_cc,42).state) && (%lim) %minus = %minus $+ l
  elseif ($did(ns_cc,42).state) && ($did(ns_cc,43).text !isnum) {
    ccsay The limit must be a number.
    return
  }
  if (!%plus) && (!%minus) {
    ccsay $iif($1,Nothing to change - the channel already has these modes.,$chr(160))
    return
  }
  ; remember what was asked for so ns.cc.verify can compare it with what the server did
  hadd -mu30 ns.ccwant chan %c
  hadd -mu30 ns.ccwant plus %plus
  hadd -mu30 ns.ccwant minus %minus
  hadd -mu30 ns.ccwant key $iif($did(ns_cc,40).state,$did(ns_cc,41).text)
  hadd -mu30 ns.ccwant lim $iif($did(ns_cc,42).state,$did(ns_cc,43).text)
  hadd -mu30 ns.ccwant err
  var %line = $iif(%plus,+ $+ %plus) $+ $iif(%minus,- $+ %minus) %pp %mp
  mode %c %line
  ccsay Sent: mode %c %line - waiting for the server...
  .timer.nsccv -o 1 2 ns.cc.verify
}
; did the channel end up with the modes we asked for?
alias ns.cc.verify {
  if (!$dialog(ns_cc)) return
  var %c = $hget(ns.ccwant,chan)
  if (!%c) return
  var %m = $gettok($chan(%c).mode,1,32), %p = $hget(ns.ccwant,plus), %n = $hget(ns.ccwant,minus), %err = $hget(ns.ccwant,err), %bad, %i = 1, %l
  while (%i <= $len(%p)) {
    %l = $mid(%p,%i,1)
    inc %i
    if (%l == k) { if ($chan(%c).key != $hget(ns.ccwant,key)) %bad = %bad +k }
    elseif (%l == l) { if ($chan(%c).limit != $hget(ns.ccwant,lim)) %bad = %bad +l }
    elseif (!$ns.ch.hasmode(%m,%l)) %bad = %bad + $+ %l
  }
  %i = 1
  while (%i <= $len(%n)) {
    %l = $mid(%n,%i,1)
    inc %i
    if (%l == k) { if ($chan(%c).key) %bad = %bad -k }
    elseif (%l == l) { if ($chan(%c).limit) %bad = %bad -l }
    elseif ($ns.ch.hasmode(%m,%l)) %bad = %bad - $+ %l
  }
  if (%bad) && (%err) ccsay Not applied: $ns.trim(%bad) - the server said: %err
  elseif (%bad) ccsay Not applied: $ns.trim(%bad) - refused, or put back by services or a mode lock.
  else ccsay Done - %c is now $iif(%m,%m,(no modes)) $+ .
  hdel ns.ccwant chan
  if (!$timer(nsccap)) fillall
}
; the server refusing a mode change: show its words in the dialog
raw 467:*:{ ns.cc.err $2- }
raw 472:*:{ ns.cc.err $2- }
raw 477:*:{ ns.cc.err $2- }
raw 482:*:{ ns.cc.err $2- }
raw 484:*:{ ns.cc.err $2- }
raw 485:*:{ ns.cc.err $2- }
raw 489:*:{ ns.cc.err $2- }
raw 520:*:{ ns.cc.err $2- }
alias ns.cc.err {
  var %t = $regsubex($1-,/^(\S+) :/,\1 $+ $chr(32))
  if ($hget(ns.ccwant,chan)) hadd -mu30 ns.ccwant err %t
  if ($dialog(ns_cc)) ccsay Server: %t
}

; ---------------------------------------------------------------- Users tab
alias -l fillusers {
  var %c = $cur, %f = $did(ns_cc,51).text, %i = 1, %n = $nick(%c,0), %list, %nk, %m = $ns.rk.modes, %k, %l, %ch, %g, %t
  did -r ns_cc 52
  while (%i <= %n) {
    %nk = $nick(%c,%i)
    if (%f == $null) || ($+(*,%f,*) iswm %nk) {
      did -a ns_cc 52 $nick(%c,%i).pnick
      %list = %list %nk
    }
    inc %i
  }
  set -u3600 %ns.cc.nicks %list
  ; privilege buttons follow the server PREFIX and what my own rank may grant
  %k = 1
  while (%k <= 5) {
    %l = $mid(qaohv,%k,1)
    %ch = $ns.rk.char(%l)
    %g = $calc(59 + %k)
    %t = $calc(65 + %k)
    if ($pos(%m,%l)) {
      did -ra ns_cc %g + $+ $ns.esc(%ch)
      did -ra ns_cc %t - $+ $ns.esc(%ch)
      did -v ns_cc %g
      did -v ns_cc %t
      if ($ns.rk.cangive(%c,%l)) {
        did -e ns_cc %g
        did -e ns_cc %t
      }
      else {
        did -b ns_cc %g
        did -b ns_cc %t
      }
    }
    else {
      did -h ns_cc %g
      did -h ns_cc %t
    }
    inc %k
  }
  var %rk = 0, %cnt
  did -ra ns_cc 73 $ns.cc.rankline(%c)
}
; "~ 1  & 2  @ 3  % 0  + 5  (none) 40"
alias ns.cc.rankline {
  var %c = $1, %chars = $ns.rk.chars, %k = 1, %n = $nick(%c,0), %i, %o, %cnt, %reg = 0
  while (%k <= $len(%chars)) {
    %cnt = 0
    %i = 1
    while (%i <= %n) {
      if ($ns.rk.of(%c,$nick(%c,%i)) == $mid(%chars,%k,1)) inc %cnt
      inc %i
    }
    %o = %o $+ $iif(%o,$chr(32)) $+ $mid(%chars,%k,1) $+ %cnt
    inc %k
  }
  %i = 1
  while (%i <= %n) {
    if (!$ns.rk.of(%c,$nick(%c,%i))) inc %reg
    inc %i
  }
  return $ns.trim(%o) $+ $chr(32) $+ $chr(32) $+ regular %reg
}
; selected nicknames (the list is filtered, so map line numbers back through %ns.cc.nicks)
alias -l ccnicks {
  var %sels = $ns.did.sels(ns_cc,52), %k = 1, %o
  while ($gettok(%sels,%k,32)) {
    %o = %o $gettok(%ns.cc.nicks,$v1,32)
    inc %k
  }
  return $ns.trim(%o)
}
on *:DIALOG:ns_cc:edit:51:{ fillusers }
on *:DIALOG:ns_cc:sclick:53:{
  var %l = $ccnicks, %k = 1
  while ($gettok(%l,%k,32)) {
    whois $v1 $v1
    inc %k
  }
}
on *:DIALOG:ns_cc:sclick:54:{
  var %n = $gettok($ccnicks,1,32)
  if (%n) query %n
}
on *:DIALOG:ns_cc:sclick:55:{
  var %n = $gettok($ccnicks,1,32), %line = $ns.msg(slap)
  if (!%n) return
  if (%line == $null) %line = slaps $+($chr(37),t) around a bit with a large trout
  describe $cur $replace(%line,$+($chr(37),t),%n)
}
; kick / ban / kick+ban every selected nick, skipping anyone who outranks me
alias -l ccmod {
  var %c = $cur, %l = $ccnicks, %k = 1, %nk, %done = 0, %r = $ns.msg(kick), %t = $ns.get(kb,bantype,2)
  if (!$ns.rk.cankick(%c)) {
    ccsay You need halfop ( $+ $ns.rk.char(h) $+ ) or higher in %c $+ .
    return
  }
  while ($gettok(%l,%k,32)) {
    %nk = $v1
    if (%nk == $me) ccsay Skipped yourself.
    elseif ($ns.rk.outranks(%c,%nk,$me)) ccsay Skipped %nk - outranks you.
    else {
      if ($1 == kick) kick %c %nk %r
      elseif ($1 == ban) ban %c %nk %t
      else ban -k %c %nk %t %r
      inc %done
    }
    inc %k
  }
  if (!%done) ccsay Select someone in the list first.
  else {
    ccsay Sent: $iif($1 == kick,kick,$iif($1 == ban,ban,kick + ban)) for %done $iif(%done == 1,user,users) - waiting for the server...
    .timer.nsccr -o 1 2 ns.cc.refresh
  }
}
on *:DIALOG:ns_cc:sclick:56:{ ccmod kick }
on *:DIALOG:ns_cc:sclick:57:{ ccmod ban }
on *:DIALOG:ns_cc:sclick:58:{ ccmod kickban }
on *:DIALOG:ns_cc:sclick:60-70:{
  var %id = $did, %c = $cur, %l, %sign, %nicks = $ccnicks
  if (%id == 65) return
  %l = $mid(qaohv,$iif(%id <= 64,$calc(%id - 59),$calc(%id - 65)),1)
  %sign = $iif(%id <= 64,+,-)
  if (!%nicks) {
    ccsay Select someone in the list first.
    return
  }
  if (!$ns.rk.cangive(%c,%l)) {
    ccsay You do not have the rank to change $ns.rk.lname(%l) $+ s in %c $+ .
    return
  }
  mode %c %sign $+ $str(%l,$numtok(%nicks,32)) %nicks
  ccsay Sent: mode %c %sign $+ $str(%l,$numtok(%nicks,32)) %nicks - waiting for the server...
  .timer.nsccr -o 1 2 ns.cc.refresh
}
on *:DIALOG:ns_cc:sclick:71:{ neon kb $cur $gettok($ccnicks,1,32) }
on *:DIALOG:ns_cc:sclick:72:{
  var %n = $gettok($ccnicks,1,32)
  if (%n) ns.acc.quick o %n $cur
  neon users
}

; ---------------------------------------------------------------- Lists tab
alias -l ltypes {
  var %cm = $chanmodes, %eq = $pos(%cm,$chr(61)), %a
  if (%eq) %cm = $mid(%cm,$calc(%eq + 1))
  %a = $gettok(%cm,1,44)
  var %o = b
  if ($status != connected) || ($ns.ch.hasmode(%a,e)) %o = %o e
  if ($status != connected) || ($ns.ch.hasmode(%a,I)) %o = %o I
  if ($ns.ch.hasmode(%a,q)) %o = %o q
  return %o
}
alias -l lname {
  if ($1 === b) return Bans (+b)
  if ($1 === e) return Ban exceptions (+e)
  if ($1 === I) return Invite exceptions (+I)
  return Quiets (+q)
}
alias -l lcount {
  var %l = $1, %c = $2
  if (%l === b) return $ibl(%c,0)
  if (%l === e) return $iel(%c,0)
  if (%l === I) return $iil(%c,0)
  return $iql(%c,0)
}
alias -l lmask {
  var %l = $1, %c = $2, %n = $3
  if (%l === b) return $ibl(%c,%n)
  if (%l === e) return $iel(%c,%n)
  if (%l === I) return $iil(%c,%n)
  return $iql(%c,%n)
}
alias -l lby {
  var %l = $1, %c = $2, %n = $3
  if (%l === b) return $ibl(%c,%n).by
  if (%l === e) return $iel(%c,%n).by
  if (%l === I) return $iil(%c,%n).by
  return $iql(%c,%n).by
}
alias -l ldate {
  var %l = $1, %c = $2, %n = $3
  if (%l === b) return $ibl(%c,%n).ctime
  if (%l === e) return $iel(%c,%n).ctime
  if (%l === I) return $iil(%c,%n).ctime
  return $iql(%c,%n).ctime
}
alias -l curtype return $gettok($ltypes,$did(ns_cc,81).sel,32)
alias -l filllists {
  var %c = $cur, %sel = $did(ns_cc,81).sel, %i = 1, %t = $ltypes, %l, %n, %k = 1, %by, %d
  did -r ns_cc 81
  while ($gettok(%t,%i,32)) {
    did -a ns_cc 81 $lname($v1)
    inc %i
  }
  did -c ns_cc 81 $iif((%sel) && (%sel <= $numtok(%t,32)),%sel,1)
  %l = $curtype
  did -r ns_cc 84
  %n = $lcount(%l,%c)
  while (%k <= %n) {
    %by = $lby(%l,%c,%k)
    %d = $ldate(%l,%c,%k)
    did -a ns_cc 84 $lmask(%l,%c,%k) $iif(%by,- set by $gettok(%by,1,33)) $iif(%d,on $asctime(%d,ddd d mmm HH:nn))
    inc %k
  }
  did -ra ns_cc 83 %n entr $+ $iif(%n == 1,y,ies)
  did $iif($ns.rk.cankick(%c),-e,-b) ns_cc 85-87,89
}
on *:DIALOG:ns_cc:sclick:81:{ filllists }
on *:DIALOG:ns_cc:sclick:82:{
  var %c = $cur, %l = $curtype
  if ($status == connected) mode %c + $+ %l
  .timer.nsccr -o 1 2 ns.cc.refresh
}
; the masks of the selected lines (the display text is "mask - set by ..." so the mask is token 1)
alias -l lsel {
  var %sels = $ns.did.sels(ns_cc,84), %k = 1, %o
  while ($gettok(%sels,%k,32)) {
    %o = %o $gettok($did(ns_cc,84,$v1),1,32)
    inc %k
  }
  return $ns.trim(%o)
}
on *:DIALOG:ns_cc:sclick:86:{
  var %c = $cur, %l = $curtype, %m = $did(ns_cc,85).text
  if (!%m) return
  if (!$pos(%m,!)) && (!$pos(%m,@)) {
    if ($address(%m,$ns.get(kb,bantype,2))) %m = $v1
    else %m = %m $+ !*@*
  }
  mode %c + $+ %l %m
  did -r ns_cc 85
  .timer.nsccr -o 1 2 ns.cc.refresh
}
on *:DIALOG:ns_cc:sclick:87:{
  var %c = $cur, %l = $curtype, %list = $lsel, %per = $iif($modespl > 0,$modespl,4), %i = 1, %n = $numtok(%list,32), %j, %chunk
  if (!%list) {
    ccsay Select an entry in the list first.
    return
  }
  while (%i <= %n) {
    %j = $calc(%i + %per - 1)
    %chunk = $gettok(%list,$+(%i,-,%j),32)
    mode %c - $+ $str(%l,$numtok(%chunk,32)) %chunk
    %i = $calc(%j + 1)
  }
  .timer.nsccr -o 1 2 ns.cc.refresh
}
on *:DIALOG:ns_cc:sclick:89:{ ns.later ns.cc.clearlist }
alias ns.cc.clearlist {
  if (!$dialog(ns_cc)) return
  var %c = $cur, %l = $curtype, %n = $lcount(%l,%c), %i = 1, %all, %per = $iif($modespl > 0,$modespl,4), %j, %chunk
  if (!%n) return
  if (!$input(Remove all $+(%n,$chr(32),$lname(%l)) from %c $+ ?,yq,Clear list)) return
  while (%i <= %n) {
    %all = %all $lmask(%l,%c,%i)
    inc %i
  }
  %all = $ns.trim(%all)
  %i = 1
  while (%i <= %n) {
    %j = $calc(%i + %per - 1)
    %chunk = $gettok(%all,$+(%i,-,%j),32)
    mode %c - $+ $str(%l,$numtok(%chunk,32)) %chunk
    %i = $calc(%j + 1)
  }
  .timer.nsccr -o 1 2 ns.cc.refresh
}

; ---------------------------------------------------------------- Protection tab
alias -l fillprot {
  var %c = $cur
  did $iif($ns.ch.get(%c,modelock_on,0) == 1,-c,-u) ns_cc 91
  did -ra ns_cc 92 $ns.ch.get(%c,modelock)
  did $iif($ns.ch.get(%c,topicprotect,0) == 1,-c,-u) ns_cc 93
  did $iif($ns.ch.get(%c,greet_on,0) == 1,-c,-u) ns_cc 95
  did -ra ns_cc 96 $ns.ch.get(%c,greet)
  did $iif($ns.ch.get(%c,greet_notice,0) == 1,-c,-u) ns_cc 97
  did $iif($ns.ch.get(%c,autovoice,0) == 1,-c,-u) ns_cc 98
  did $iif($ns.ch.get(%c,rejoin,0) == 1,-c,-u) ns_cc 99
  var %fo = $ns.ch.get(%c,flood_on,0), %fa = $ns.ch.get(%c,flood_action,ignore)
  did -r ns_cc 107
  did -a ns_cc 107 Ignore them
  did -a ns_cc 107 Kick them (if I am an op)
  did -a ns_cc 107 Ignore and kick
  did -a ns_cc 107 No flood protection in this channel
  did -c ns_cc 107 $iif(%fo == 2,4,$iif(%fa == kick,2,$iif(%fa == both,3,1)))
  did $iif(%fo > 0,-c,-u) ns_cc 102
  did -ra ns_cc 103 $ns.ch.get(%c,flood_lines,$ns.get(protect,flood_lines,6))
  did -ra ns_cc 105 $ns.ch.get(%c,flood_secs,$ns.get(protect,flood_secs,4))
  did -ra ns_cc 101 $chr(160)
}
on *:DIALOG:ns_cc:sclick:94:{
  var %c = $cur
  ns.ch.set %c topicsaved $chan(%c).topic
  did -ra ns_cc 101 Saved the current topic as the protected one.
}
on *:DIALOG:ns_cc:sclick:100:{
  var %c = $cur
  ns.ch.set %c modelock_on $did(ns_cc,91).state
  ns.ch.set %c modelock $did(ns_cc,92).text
  ns.ch.set %c topicprotect $did(ns_cc,93).state
  if ($did(ns_cc,93).state) && ($ns.ch.get(%c,topicsaved) == $null) ns.ch.set %c topicsaved $chan(%c).topic
  ns.ch.set %c greet_on $did(ns_cc,95).state
  ns.ch.set %c greet $did(ns_cc,96).text
  ns.ch.set %c greet_notice $did(ns_cc,97).state
  ns.ch.set %c autovoice $did(ns_cc,98).state
  ns.ch.set %c rejoin $did(ns_cc,99).state
  var %fs = $did(ns_cc,107).sel
  ns.ch.set %c flood_on $iif($did(ns_cc,102).state,$iif(%fs == 4,2,1),0)
  ns.ch.set %c flood_lines $iif($did(ns_cc,103).text isnum,$did(ns_cc,103).text,6)
  ns.ch.set %c flood_secs $iif($did(ns_cc,105).text isnum,$did(ns_cc,105).text,4)
  ns.ch.set %c flood_action $gettok(ignore kick both ignore,%fs,32)
  did -ra ns_cc 101 Saved for %c $+ .
  ns.ch.enforce %c
}

; ---------------------------------------------------------------- Info tab
alias -l fillinfo {
  var %c = $cur, %cr = $hget(ns.chinfo,$+($cid,.,%c,.created)), %by = $hget(ns.chinfo,$+($cid,.,%c,.by)), %when = $hget(ns.chinfo,$+($cid,.,%c,.when))
  var %modes = $chan(%c).mode, %key = $chan(%c).key, %lim = $chan(%c).limit, %top = $chan(%c).topic, %rk = $ns.rk.of(%c,$me)
  ns.ml.new
  ns.ml.add Channel: %c on $iif($network,$network,$server)
  ns.ml.add Modes: $iif(%modes,%modes,none)
  if (%key) ns.ml.add Key: %key
  if (%lim) ns.ml.add User limit: %lim
  ns.ml.add Created: $iif(%cr,$asctime(%cr,ddd d mmm yyyy HH:nn),unknown - press Refresh)
  ns.ml.add Topic: $iif(%top,%top,none)
  if (%by) ns.ml.add Topic set by: %by $iif(%when,on $asctime(%when,ddd d mmm yyyy HH:nn))
  ns.ml.add Users: $nick(%c,0) $+ $chr(32) $+ $chr(40) $+ $ns.cc.rankline(%c) $+ $chr(41)
  if (%rk) ns.ml.add Your rank: $ns.rk.name(%rk) $+ $chr(32) $+ $chr(40) $+ %rk $+ $chr(41)
  else ns.ml.add Your rank: regular user
  ns.ml.add Server prefixes: $ns.rk.chars $+ $chr(32) $+ $chr(40) $+ $ns.rk.modes $+ $chr(41)
  ns.ml.add Ban list: $ibl(%c,0) entries
  ns.ml.add Mode lock: $iif($ns.ch.get(%c,modelock_on,0) == 1,$ns.ch.get(%c,modelock),off) $+ $chr(44) topic protect: $iif($ns.ch.get(%c,topicprotect,0) == 1,on,off)
  ns.ml.set ns_cc 110
}
on *:DIALOG:ns_cc:sclick:27:{
  set -u60 %ns.tpl.chan $cur
  ns.tpl.seed
  ns.dlg ns_tpl ns_tpl
}
on *:DIALOG:ns_cc:sclick:112:{ neon stats $cur }
on *:DIALOG:ns_cc:sclick:113:{ neon stafflog }
on *:DIALOG:ns_cc:sclick:111:{
  if ($status == connected) mode $cur
  .timer.nsccr -o 1 2 ns.cc.refresh
}

; ---------------------------------------------------------------- enforcement (runs without the dialog)
on *:JOIN:#:{
  if ($nick == $me) {
    ; once the nicklist has settled, re-assert locks I am allowed to
    .timer -o 1 4 scid $cid ns.ch.enforce $chan
    return
  }
  if ($ns.bnc.q) return
  ns.ch.greet $chan $nick
  if ($ns.ch.get($chan,autovoice,0) == 1) .timer -o 1 1 scid $cid ns.ch.voice $chan $nick
}
; greeting with <nick> / <chan> placeholders; one greeting per person per minute
alias ns.ch.greet {
  var %c = $1, %n = $2, %g = $ns.ch.get(%c,greet)
  if ($ns.ch.get(%c,greet_on,0) != 1) || (%g == $null) return
  if ($hget(ns.greetcd,$+($cid,.,%c,.,%n))) return
  hadd -mu60 ns.greetcd $+($cid,.,%c,.,%n) 1
  %g = $replace(%g,<nick>,%n,<chan>,%c)
  if ($ns.ch.get(%c,greet_notice,0) == 1) notice %n %g
  else msg %c %g
}
; give +v to a newcomer if the server has it, my rank allows it, and they have nothing better
alias ns.ch.voice {
  var %c = $1, %n = $2
  if (!$ns.ischan(%c)) || (!$nick(%c,%n)) return
  if (!$pos($ns.rk.modes,v)) || (!$ns.rk.cangive(%c,v)) return
  if ($ns.rk.of(%c,%n)) return
  ns.sl.tag %c autovoice
  mode %c +v %n
}
; mode lock + topic protect for one channel
alias ns.ch.enforce {
  var %c = $1
  if (!$ns.ischan(%c)) || (!$me ison %c) return
  ; --- mode lock: "+nt-i" style string; flags only (k and l need parameters and are left alone)
  if ($ns.ch.get(%c,modelock_on,0) == 1) && ($ns.rk.atleast(%c,$me,o)) {
    var %lock = $ns.ch.get(%c,modelock), %m = $gettok($chan(%c).mode,1,32), %i = 1, %sign = +, %ch, %add, %rem
    while (%i <= $len(%lock)) {
      %ch = $mid(%lock,%i,1)
      if (%ch == $chr(43)) || (%ch == $chr(45)) %sign = %ch
      elseif (%ch !== k) && (%ch !== l) {
        if (%sign == $chr(43)) && (!$ns.ch.hasmode(%m,%ch)) %add = %add $+ %ch
        elseif (%sign == $chr(45)) && ($ns.ch.hasmode(%m,%ch)) %rem = %rem $+ %ch
      }
      inc %i
    }
    if (%add) || (%rem) {
      ns.sl.tag %c lock
      mode %c $iif(%add,+ $+ %add) $+ $iif(%rem,- $+ %rem)
    }
  }
  ; --- topic protect
  if ($ns.ch.get(%c,topicprotect,0) == 1) {
    var %saved = $ns.ch.get(%c,topicsaved)
    if (%saved != $null) && ($chan(%c).topic != %saved) {
      if ($ns.rk.atleast(%c,$me,o)) || (!$ns.ch.hasmode($chan(%c).mode,t)) {
        ns.sl.tag %c lock
        topic %c %saved
      }
    }
  }
}
; ---------------------------------------------------------------- menu entry
menu channel {
  Channel control...:channel $chan
}
