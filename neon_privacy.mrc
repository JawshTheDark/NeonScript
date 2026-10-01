; ============================================================================
;  NeonScript 2026  ::  privacy
;    Ignore manager   /neon ignores   notes, expiry and scope on top of mIRC's own ignore engine
;    CTCP privacy     decide what you answer to VERSION, TIME, FINGER ... and to whom
;
;  Ignoring is done by mIRC itself (its /ignore list), because that is the only way an ignored person is
;  really invisible - script events cannot stop other scripts' handlers.  NeonScript keeps the extras
;  mIRC has no place for (a note, when it was added, "this network only") in ignores.ini and re-applies
;  every entry when mIRC starts and when you connect, so nothing is lost on a restart.
; ============================================================================

; ============================================================================
;  IGNORE MANAGER
; ============================================================================
alias ns.ig.ini return $+($scriptdir,ignores.ini)
alias ns.ig.ids {
  var %i = 1, %o
  while ($ini($ns.ig.ini,%i)) {
    %o = %o $v1
    inc %i
  }
  return %o
}
alias ns.ig.get return $readini($ns.ig.ini,n,$1,$2)
alias ns.ig.set {
  if ($3- == $null) writeini -nz $qt($ns.ig.ini) $1 $2
  else writeini -n $qt($ns.ig.ini) $1 $2 $3-
}
alias ns.ig.newid {
  var %n = 1
  while ($ini($ns.ig.ini,$+(g,%n))) inc %n
  return $+(g,%n)
}
alias ns.ig.net return $iif($network,$network,$iif($server,$server,local))
; the connection id of a network I am connected to ("" if none)
alias ns.ig.cidfor {
  var %i = 1
  while (%i <= $scon(0)) {
    if ($scon(%i).network == $1) && ($scon(%i).status == connected) return $scon(%i).cid
    inc %i
  }
  return $null
}
; seconds left: -1 = never expires, 0 = already over
alias ns.ig.left {
  var %u = $ns.ig.get($1,until)
  if (!%u) return -1
  return $iif(%u > $ctime,$calc(%u - $ctime),0)
}
; which of mIRC's /ignore switches an entry's types map to (p c n t i d)
alias ns.ig.flags return $regsubex($1,/[^pcntid]/g,)
; put one entry into mIRC's own ignore list
alias ns.ig.push {
  var %id = $1, %m = $ns.ig.get(%id,mask), %t = $ns.ig.flags($ns.ig.get(%id,types)), %l = $ns.ig.left(%id), %sc = $ns.ig.get(%id,scope), %sw, %cid
  if (%m == $null) return
  if (%l == 0) {
    ns.ig.del %id
    return
  }
  if (%t == $null) return
  %sw = $+(-,%t,$iif(%sc == all,w),$iif(%l > 0,$+(u,%l)))
  if (%sc == all) .ignore %sw %m
  else {
    %cid = $ns.ig.cidfor($ns.ig.get(%id,net))
    if (%cid) scid %cid .ignore %sw %m
  }
}
; take one entry out of mIRC's list
alias ns.ig.pull {
  var %id = $1, %m = $ns.ig.get(%id,mask), %sc = $ns.ig.get(%id,scope), %cid
  if (%m == $null) return
  if (%sc == all) .ignore $+(-r,w) %m
  else {
    %cid = $ns.ig.cidfor($ns.ig.get(%id,net))
    if (%cid) scid %cid .ignore -r %m
  }
}
; ns.ig.add <mask> <types> <all|net> <seconds, 0 = for good> <note...>   -> the new id
alias ns.ig.add {
  var %id = $ns.ig.newid
  ns.ig.set %id mask $1
  ns.ig.set %id types $2
  ns.ig.set %id scope $3
  ns.ig.set %id net $iif($3 == net,$ns.ig.net,*)
  ns.ig.set %id until $iif($4 > 0,$calc($ctime + $4),0)
  ns.ig.set %id note $5-
  ns.ig.set %id added $ctime
  ns.ig.push %id
  return %id
}
alias ns.ig.del {
  ns.ig.pull $1
  remini $qt($ns.ig.ini) $1
}
; re-apply everything (after mIRC starts, and for a network's own entries when it connects)
alias ns.ig.sync {
  var %i = 1
  while ($gettok($ns.ig.ids,%i,32) != $null) {
    ns.ig.push $v1
    inc %i
  }
}
alias ns.ig.sync.net {
  var %i = 1, %id
  while ($gettok($ns.ig.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    if ($ns.ig.get(%id,scope) == net) && ($ns.ig.get(%id,net) == $ns.ig.net) ns.ig.push %id
  }
}
; once a minute: forget entries whose time is up
alias ns.ig.tick {
  var %i = 1, %id
  while ($gettok($ns.ig.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    if ($ns.ig.left(%id) == 0) ns.ig.del %id
  }
}
on *:SIGNAL:ns.boot:{
  .timer.nsigb -o 1 4 ns.ig.sync
  .timer.nsigt 0 60 ns.ig.tick
}
on *:CONNECT:{ .timer.nsigc $+ $cid -o 1 3 scid $cid ns.ig.sync.net }

; "10m" "2h" "1d" -> seconds ; "" -> 0
alias ns.ig.secs {
  if ($1 == $null) return 0
  if (!$regex(ns.igd,$1,/^(\d+)([smhdw]?)$/i)) return -1
  var %n = $regml(ns.igd,1), %u = $lower($regml(ns.igd,2))
  if (%u == m) return $calc(%n * 60)
  if (%u == h) return $calc(%n * 3600)
  if (%u == d) return $calc(%n * 86400)
  if (%u == w) return $calc(%n * 604800)
  return %n
}
alias ns.ig.left.text {
  var %l = $ns.ig.left($1)
  if (%l < 0) return for good
  if (%l >= 86400) return $calc(%l // 86400) $+ d left
  if (%l >= 3600) return $calc(%l // 3600) $+ h left
  if (%l >= 60) return $calc(%l // 60) $+ m left
  return %l $+ s left
}
; the usual way in: a nick or a mask
alias ns.ig.maskfor return $iif($pos($1,!) || $pos($1,@),$1,$ns.mask($1))

; /neon ignores               the manager
; /neon ignore <nick|mask> [10m|2h|1d] [note]        ignore everything from them (this network if no time is given: all networks)
; /neon unignore <nick|mask>
alias neon.ignores ns.dlg ns_ign ns_ign
alias neon.ignore {
  var %t = $1, %secs = 0, %note, %m
  if (%t == $null) {
    ns.err usage: /neon ignore <nick|mask> [10m|2h|1d] [note]   (/neon ignores opens the manager)
    return
  }
  if ($2 != $null) && ($ns.ig.secs($2) > 0) {
    %secs = $ns.ig.secs($2)
    %note = $3-
  }
  else %note = $2-
  %m = $ns.ig.maskfor(%t)
  ns.ig.add %m pcnti all %secs %note
  ns.say ignoring $+($ns.b,%m,$ns.b) $+ $iif(%secs > 0,$chr(32) $+ for $ns.mod.dur(%secs)) $+ . /neon ignores manages the list.
}
alias neon.unignore {
  if ($1 == $null) {
    ns.err usage: /neon unignore <nick|mask>
    return
  }
  var %m = $ns.ig.maskfor($1), %i = 1, %id, %n = 0
  while ($gettok($ns.ig.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    if ($ns.ig.get(%id,mask) == %m) || ($ns.ig.get(%id,mask) == $1) {
      ns.ig.del %id
      inc %n
    }
  }
  if (!%n) .ignore -rw %m
  ns.say no longer ignoring $+($ns.b,%m,$ns.b) $+ .
}

dialog ns_ign {
  title "Ignore Manager"
  size -1 -1 336 228
  option dbu
  icon 1, 0 0 336 30, $mircexe, 0, noborder
  list 2, 6 36 324 90, size vsbar hsbar
  text "", 3, 6 128 324 9
  text "Who:", 4, 6 144 22 9
  edit "", 5, 30 142 160 11, autohs
  text "For:", 6, 196 144 16 9
  edit "", 7, 214 142 34 11, autohs
  text "10m, 2h, 1d - empty = for good", 8, 252 144 80 18
  text "Note:", 9, 6 160 22 9
  edit "", 10, 30 158 218 11, autohs
  text "Ignore:", 11, 6 176 26 9
  check "Private", 12, 34 175 38 9
  check "Channel", 13, 76 175 40 9
  check "Notices", 14, 120 175 38 9
  check "CTCP", 15, 162 175 32 9
  check "Invites", 16, 198 175 36 9
  text "Where:", 17, 6 192 26 9
  combo 18, 34 190 120 50, drop
  button "Add", 19, 160 189 40 12
  button "Update", 20, 204 189 40 12
  button "Remove", 21, 248 189 40 12
  button "Adopt mIRC's list", 22, 6 208 78 13
  button "Close", 23, 282 208 48 13, ok cancel
}
on *:DIALOG:ns_ign:init:*:{
  did -g ns_ign 1 $ns.asset(header_ignore.png)
  did -a ns_ign 18 All networks
  did -a ns_ign 18 Only $ns.ig.net
  did -c ns_ign 18 1
  did -c ns_ign 12
  did -c ns_ign 13
  did -c ns_ign 14
  did -c ns_ign 15
  did -c ns_ign 16
  igfill
}
alias -l igtypes {
  return $+($iif($did(ns_ign,12).state,p),$iif($did(ns_ign,13).state,c),$iif($did(ns_ign,14).state,n),$iif($did(ns_ign,15).state,t),$iif($did(ns_ign,16).state,i))
}
alias -l igfill {
  var %i = 1, %id, %n
  did -r ns_ign 2
  while ($gettok($ns.ig.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    did -a ns_ign 2 $+($ns.ig.get(%id,mask),$chr(32),$chr(32),$chr(91),$ns.ig.get(%id,types),$chr(93),$chr(32),$chr(32),$iif($ns.ig.get(%id,scope) == all,everywhere,only $ns.ig.get(%id,net)),$chr(32),$chr(32),$ns.ig.left.text(%id),$iif($ns.ig.get(%id,note) != $null,$chr(32) $+ $chr(32) $+ - $ns.ig.get(%id,note)))
  }
  %n = $ignore(0)
  did -ra ns_ign 3 $numtok($ns.ig.ids,32) entries here $+ $iif(%n > 0,$chr(59) mIRC's own list also has %n - press Adopt to bring them in) $+ $chr(46)
}
alias -l igpick {
  var %id = $gettok($ns.ig.ids,$1,32), %t
  if (!%id) return
  %t = $ns.ig.get(%id,types)
  did -ra ns_ign 5 $ns.ig.get(%id,mask)
  did -ra ns_ign 10 $ns.ig.get(%id,note)
  did -r ns_ign 7
  did $iif($pos(%t,p),-c,-u) ns_ign 12
  did $iif($pos(%t,c),-c,-u) ns_ign 13
  did $iif($pos(%t,n),-c,-u) ns_ign 14
  did $iif($pos(%t,t),-c,-u) ns_ign 15
  did $iif($pos(%t,i),-c,-u) ns_ign 16
  did -c ns_ign 18 $iif($ns.ig.get(%id,scope) == all,1,2)
}
on *:DIALOG:ns_ign:sclick:2:{ igpick $did(ns_ign,2).sel }
on *:DIALOG:ns_ign:sclick:19:{
  var %m = $ns.ig.maskfor($did(ns_ign,5).text), %secs = $ns.ig.secs($did(ns_ign,7).text), %t = $igtypes
  if ($did(ns_ign,5).text == $null) {
    did -ra ns_ign 3 Type a nick or an address mask first.
    return
  }
  if (%secs < 0) {
    did -ra ns_ign 3 The time must look like 10m, 2h or 1d.
    return
  }
  if (%t == $null) {
    did -ra ns_ign 3 Tick at least one kind of message to ignore.
    return
  }
  ns.ig.add %m %t $iif($did(ns_ign,18).sel == 1,all,net) %secs $did(ns_ign,10).text
  igfill
}
on *:DIALOG:ns_ign:sclick:20:{
  var %id = $gettok($ns.ig.ids,$did(ns_ign,2).sel,32), %secs = $ns.ig.secs($did(ns_ign,7).text), %t = $igtypes
  if (!%id) {
    did -ra ns_ign 3 Select an entry first.
    return
  }
  if (%secs < 0) {
    did -ra ns_ign 3 The time must look like 10m, 2h or 1d.
    return
  }
  ns.ig.pull %id
  ns.ig.set %id mask $ns.ig.maskfor($did(ns_ign,5).text)
  ns.ig.set %id types %t
  ns.ig.set %id scope $iif($did(ns_ign,18).sel == 1,all,net)
  ns.ig.set %id net $iif($did(ns_ign,18).sel == 1,*,$ns.ig.net)
  ns.ig.set %id note $did(ns_ign,10).text
  if ($did(ns_ign,7).text != $null) ns.ig.set %id until $iif(%secs > 0,$calc($ctime + %secs),0)
  ns.ig.push %id
  igfill
}
on *:DIALOG:ns_ign:sclick:21:{
  var %id = $gettok($ns.ig.ids,$did(ns_ign,2).sel,32)
  if (!%id) {
    did -ra ns_ign 3 Select an entry first.
    return
  }
  ns.ig.del %id
  igfill
}
; bring mIRC's own ignore entries in (they stay in mIRC's list too; here they get a note, a time and a scope)
on *:DIALOG:ns_ign:sclick:22:{
  var %i = 1, %n = $ignore(0), %a, %new = 0, %j, %dup, %nid
  while (%i <= %n) {
    %a = $ignore(%i)
    inc %i
    if (%a == $null) continue
    %dup = 0
    %j = 1
    while ($gettok($ns.ig.ids,%j,32) != $null) {
      if ($ns.ig.get($v1,mask) == %a) %dup = 1
      inc %j
    }
    if (%dup) continue
    %nid = $ns.ig.newid
    ns.ig.set %nid mask %a
    ns.ig.set %nid types pcnti
    ns.ig.set %nid scope all
    ns.ig.set %nid net *
    ns.ig.set %nid until 0
    ns.ig.set %nid note adopted from mIRC's list
    ns.ig.set %nid added $ctime
    inc %new
  }
  did -ra ns_ign 3 Adopted %new entr $+ $iif(%new == 1,y,ies) $+ $chr(46) Give them a note or a time with Update.
  igfill
}

; ============================================================================
;  CTCP PRIVACY
;  Settings (Control Panel > Privacy, section "privacy"):
;    ctcp_mode      normal  = leave it to mIRC (it also answers FINGER with your real name / e-mail setting)
;                   generic = (the default) TIME is answered in UTC (not your local clock), PING normally, nothing else
;                   silent  = nothing is answered except PING
;    ctcp_strangers 1 = only answer people who share a channel with me, have a private chat open or are on notify
;    ctcp_chan      1 = answer CTCP sent to a whole channel (default 0: those are never answered)
;    ctcp_rate      at most this many answers per minute (default 5), after that silence
;    ctcp_note      1 = say in the status window when a request was hidden
;  What mIRC allows: its CTCP events are "ctcp <level>:<text>:<*|#|?>:" lines (not "on CTCP"), /halt in one stops
;  the standard reply - except for VERSION, which mIRC always answers itself and no script can stop.
; ============================================================================
ctcp *:*:*:{
  if ($ns.ctcp.handle($1,$2-)) halt
}
alias ns.ctcp.known {
  if ($comchan($1,0) > 0) return 1
  if ($query($1)) return 1
  if ($notify($1)) return 1
  return 0
}
alias ns.ctcp.note {
  if ($ns.flag(privacy,ctcp_note,1)) echo -cst info $+($ns.pfx,$chr(32),$ns.ec(dim),CTCP,$chr(32),$1,$chr(32),from,$chr(32),$nick,$chr(58),$chr(32),$2-,$ns.o)
}
; returns 1 when the request was dealt with here (hidden or answered), 0 to let mIRC answer as usual
alias ns.ctcp.handle {
  var %t = $upper($1), %mode = $ns.get(privacy,ctcp_mode,generic), %rate = $ns.get(privacy,ctcp_rate,5), %hide = 0
  if ($nick == $me) return 0
  if ($istok(ACTION DCC,%t,32)) return 0
  ; why this request would be hidden, if it can be
  if ($target ischan) && (!$ns.flag(privacy,ctcp_chan,0)) %hide = sent to a whole channel
  elseif ($ns.flag(privacy,ctcp_strangers,1)) && (!$ns.ctcp.known($nick)) %hide = they share no channel with me
  elseif (%rate isnum) && (%rate > 0) {
    hinc -mu60 ns.ctcprate $cid
    if ($hget(ns.ctcprate,$cid) > %rate) %hide = more than %rate a minute
  }
  if (%t == VERSION) {
    if (%hide) ns.ctcp.note VERSION cannot be hidden - mIRC always answers it ( $+ %hide $+ )
    return 0
  }
  if (%hide) {
    ns.ctcp.note %t not answered ( $+ %hide $+ )
    return 1
  }
  if (%mode == normal) return 0
  if (%t == PING) return 0
  if (%mode == generic) && (%t == TIME) && ($ns.get(privacy,ctcp_time,utc) == utc) {
    .notice $nick $+($chr(1),TIME,$chr(32),$asctime($gmt,ddd mmm dd HH:nn:ss yyyy),$chr(32),UTC,$chr(1))
    ns.ctcp.note TIME answered in UTC
    return 1
  }
  ns.ctcp.note %t hidden (not answered)
  return 1
}
; /neon privacy  opens the Privacy page of the Control Panel
alias neon.privacy neon options privacy
