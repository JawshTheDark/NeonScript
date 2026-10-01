; ============================================================================
;  NeonScript 2026  ::  away system
;  /neon away [reason]   /neon back   /away <reason>   /back
;  Nick suffix, announcements, auto-away on idle (+ auto-back when you type)
;  and a log of every mention and private message you missed.
; ============================================================================

alias ns.away.log return $+($scriptdir,awaylog.txt)

; ---------------------------------------------------------------- going away / coming back
; /neon away          opens the Away dialog
; /neon away <text>   goes away straight away
alias neon.away {
  if ($1- == $null) {
    ns.dlg ns_away ns_away
    return
  }
  ns.away.set $1-
}
; make plain /away use the same machinery (!away is mIRC's own command)
alias away {
  if ($1- == $null) {
    if ($away) ns.away.back
    else ns.dlg ns_away ns_away
    return
  }
  ns.away.set $1-
}
alias afk neon.away $1-
alias back ns.away.back
alias neon.back ns.away.back

alias ns.away.set {
  var %r = $1-, %i = $scon(0), %c
  if (%r == $null) %r = $ns.msg(away)
  if (%r == $null) %r = Away
  set %ns.away.since $ctime
  set %ns.away.reason %r
  if ($ns.flag(away,log,1) == 1) write -c $qt($ns.away.log)
  while (%i) {
    %c = $scon(%i)
    scid %c if ($status == connected) !away %r
    if ($ns.flag(away,nicksuffix,0)) scid %c ns.away.nick on
    dec %i
  }
  if ($ns.flag(away,announce,0)) ame is away: %r
  ns.say you are now away: $+($ns.ec(value),%r,$ns.o)
  .signal -n ns.sync
}
alias ns.away.back {
  if (!$away) && (!%ns.away.since) {
    ns.say you are not away.
    return
  }
  var %i = $scon(0), %c, %dur = $duration($calc($ctime - %ns.away.since))
  while (%i) {
    %c = $scon(%i)
    scid %c if ($away) !away
    scid %c ns.away.nick off
    dec %i
  }
  if ($ns.flag(away,announce,0)) ame is back after %dur
  ns.say welcome back! you were away for %dur $+ .
  unset %ns.away.since %ns.away.reason %ns.away.auto
  ns.away.summary
  .signal -n ns.sync
}
; add / remove the nick suffix on the current connection ($1 = on | off)
alias ns.away.nick {
  var %k = $+(%ns.away.nick.,$cid)
  if ($1 == on) {
    if (%ns.away.nick. [ $+ [ $cid ] ] == $null) {
      set %ns.away.nick. $+ $cid $me
      nick $+($me,$ns.get(away,suffix,$+($chr(124),away)))
    }
  }
  else {
    if (%ns.away.nick. [ $+ [ $cid ] ] != $null) {
      nick %ns.away.nick. [ $+ [ $cid ] ]
      unset %ns.away.nick. [ $+ [ $cid ] ]
    }
  }
}

; ---------------------------------------------------------------- the missed-message log
alias -l logit {
  if (!$away) return
  if ($isalias(ns.bnc.q)) && ($ns.bnc.q) return
  if (!$ns.flag(away,log,1)) return
  write $qt($ns.away.log) $+($time(HH:nn),$chr(124),$1,$chr(124),$2,$chr(124),$3-)
}
on *:TEXT:*:?:{ logit pm $nick $1- }
on *:ACTION:*:?:{ logit pm $nick $1- }
on *:TEXT:*:#:{
  if ($me isin $1-) logit mention $+($chan,$chr(32),$chr(60),$nick,$chr(62)) $1-
}
on *:ACTION:*:#:{
  if ($me isin $1-) logit mention $+($chan,$chr(32),$chr(42),$nick) $1-
}
alias ns.away.summary {
  var %f = $ns.away.log, %n = $lines(%f)
  if (!$exists(%f)) || (%n < 1) return
  ns.say you missed $+($chr(2),%n,$chr(2)) message(s) while away - type $+($ns.cc(11),/neon awaylog,$ns.o) to read them.
  if ($ns.flag(away,showlog,1)) .timer -o 1 1 neon awaylog
}
alias neon.awaylog {
  var %w = @AwayLog, %f = $ns.away.log, %i = 1, %n = $lines(%f), %l, %who
  if ($window(%w)) window -c %w
  window -Cz %w 120 90 700 380
  titlebar %w Messages you missed
  if (!$exists(%f)) || (%n < 1) {
    echo -c info %w $+($ns.ec(dim),Nothing missed - no mentions or private messages logged.,$ns.o)
    return
  }
  while (%i <= %n) {
    %l = $read(%f,n,%i)
    inc %i
    %who = $gettok(%l,3,124)
    echo -c info %w $+($ns.ec(dim),$gettok(%l,1,124),$ns.o,$chr(32),$iif($gettok(%l,2,124) == pm,$+($ns.ec(invite),PM,$ns.o),$+($ns.ec(mode),@,$ns.o)),$chr(32),$ns.ec(nick),$ns.b,%who,$ns.b,$ns.o) $+ $chr(32) $+ $gettok(%l,4-,124)
  }
}

; ---------------------------------------------------------------- auto-away / auto-back
alias ns.away.tick {
  if (!$ns.flag(away,auto,0)) return
  if ($away) return
  var %min = $ns.get(away,auto_min,15)
  if ($idle >= $calc(%min * 60)) {
    set %ns.away.auto 1
    ns.away.set Auto-away - idle for %min minutes
  }
}
on *:INPUT:*:{
  if (!%ns.away.auto) return
  if (!$ns.flag(away,autoback,1)) return
  ns.away.back
}
on *:SIGNAL:ns.boot:{ .timer.nsaway 0 30 ns.away.tick }
on *:LOAD:{ .timer.nsaway 0 30 ns.away.tick }
on *:SIGNAL:ns.uninstall:{ .timer.nsaway off }

; ---------------------------------------------------------------- Away dialog
dialog ns_away {
  title "Go away"
  size -1 -1 232 134
  option dbu
  icon 1, 0 0 232 30, $mircexe, 0, noborder
  text "Reason (pick one or write your own):", 2, 6 36 220 9
  combo 3, 6 46 220 90, drop edit
  check "Add a suffix to my nick while away", 4, 6 64 220 9
  check "Announce it in my channels", 5, 6 76 220 9
  check "Keep a log of mentions and private messages", 6, 6 88 220 9
  button "Go away", 7, 114 108 52 13, default
  button "Cancel", 8, 172 108 54 13, ok cancel
  button "Away reasons...", 9, 6 108 66 13
}
on *:DIALOG:ns_away:init:*:{
  did -g ns_away 1 $ns.asset(header_away.png)
  var %f = $ns.msg.file(away), %i = 1
  while (%i <= $lines(%f)) {
    did -a ns_away 3 $read(%f,n,%i)
    inc %i
  }
  did -c ns_away 3 1
  if ($ns.flag(away,nicksuffix,0)) did -c ns_away 4
  if ($ns.flag(away,announce,0)) did -c ns_away 5
  if ($ns.flag(away,log,1)) did -c ns_away 6
}
on *:DIALOG:ns_away:sclick:7:{
  ns.set away nicksuffix $did(ns_away,4).state
  ns.set away announce $did(ns_away,5).state
  ns.set away log $did(ns_away,6).state
  var %r = $did(ns_away,3).text
  dialog -x ns_away
  .timer -o 1 0 ns.away.set %r
}
on *:DIALOG:ns_away:sclick:9:{ neon messages away }
