; ============================================================================
;  NeonScript 2026  ::  moderation tools
;    Staff log      /neon stafflog   every kick, ban, quiet, mode and topic change I make - by hand, by the
;                                    userlist, by protection or by a mass action - with who/why
;    Quiet / mute   /neon quiet <nick> [10m] [reason]   /neon unquiet <nick>   /neon quiets
;    Mass actions   /neon mass       voice, devoice, kick, ban, kick+ban or quiet everyone matching a pattern,
;                                    with a preview first, never touching ranked or protected people
;    Topic templates /neon topictpl  saved topics with {chan} {date} {old} ... placeholders
;
;  Rank rules are the same as everywhere else in NeonScript: nobody with halfop or higher, nobody flagged
;  "protected" on the userlist, never myself, and nobody who outranks me is ever touched.
; ============================================================================

; ---------------------------------------------------------------- server capabilities (raw 005)
raw 005:*:{
  var %i = 2, %t, %p, %k
  while ($gettok($1-,%i,32) != $null) {
    %t = $v1
    inc %i
    if ($left(%t,1) == $chr(58)) break
    %p = $pos(%t,=)
    if (!%p) continue
    %k = $left(%t,$calc(%p - 1))
    if ($istok(CHANMODES EXTBAN MODES TOPICLEN PREFIX NETWORK,%k,32)) hadd -m ns.isup $+($cid,.,%k) $mid(%t,$calc(%p + 1))
  }
}
alias ns.isup return $hget(ns.isup,$+($cid,.,$1))
; channel-mode groups from CHANMODES (list, key-like, limit-like, flags);  $ns.isup.cm(1) = list modes such as beI
; (a comma inside a regex literal would split the $regex parameters - hence \x2C)
alias ns.isup.cm {
  var %cm = $ns.isup(CHANMODES)
  if (%cm == $null) || (!$regex(ns.cm,%cm,/^([^\x2C]*)\x2C([^\x2C]*)\x2C([^\x2C]*)/)) return $iif($1 == 1,beI,$iif($1 == 2,k,l))
  return $regml(ns.cm,$1)
}
alias ns.mod.net return $iif($network,$network,$iif($server,$server,local))
; "10m" "2h" "1d" "90" -> seconds (0 if it is not a duration)
alias ns.mod.secs {
  if (!$regex(ns.du,$1,/^(\d+)([smhdw]?)$/i)) return 0
  var %n = $regml(ns.du,1), %u = $lower($regml(ns.du,2))
  if (%u == m) return $calc(%n * 60)
  if (%u == h) return $calc(%n * 3600)
  if (%u == d) return $calc(%n * 86400)
  if (%u == w) return $calc(%n * 604800)
  return %n
}
alias ns.mod.dur {
  var %s = $1
  if (%s >= 86400) return $calc(%s // 86400) $+ d
  if (%s >= 3600) return $calc(%s // 3600) $+ h
  if (%s >= 60) return $calc(%s // 60) $+ m
  return %s $+ s
}
; channels I am in on the current connection, for combo boxes:  ns.mod.fillchans <dialog> <id> <select>
alias ns.mod.fillchans {
  var %i = 1, %n = $chan(0), %sel = 1
  did -r $1 $2
  while (%i <= %n) {
    did -a $1 $2 $chan(%i)
    if ($chan(%i) == $3) %sel = %i
    inc %i
  }
  if (%n) did -c $1 $2 %sel
}

; ============================================================================
;  STAFF LOG
; ============================================================================
alias ns.sl.file return $ns.data(stafflog.txt)
; a script action says what it is about to do, so the log can say "by the userlist" instead of "by hand"
alias ns.sl.tag { if ($2) hadd -mu3 ns.slsrc $+($cid,.,$lower($1)) $2 }
alias ns.sl.src {
  var %v = $hget(ns.slsrc,$+($cid,.,$lower($1)))
  return $iif(%v != $null,%v,manual)
}
; ns.sl.add <chan> <kind> <target> <detail...>      kinds: kick ban unban quiet unquiet mode topic
alias ns.sl.add {
  if (!$ns.flag(staff,log,1)) return
  if ($ns.bnc.q) return
  var %t = $iif($3 != $null,$3,-), %d = $iif($4- != $null,$4-,-)
  write $qt($ns.sl.file) $+($ctime,$chr(9),$ns.mod.net,$chr(9),$1,$chr(9),$2,$chr(9),$remove(%t,$chr(9)),$chr(9),$remove(%d,$chr(9)),$chr(9),$ns.sl.src($1))
  inc %ns.sl.n
  if (%ns.sl.n >= 100) {
    unset %ns.sl.n
    ns.sl.trim
  }
}
; keep the newest 2000 lines once the file passes 3000
alias ns.sl.trim {
  var %f = $ns.sl.file, %n = $lines(%f), %tmp = $+(%f,.new), %i
  if (%n <= 3000) return
  if ($exists(%tmp)) .remove $qt(%tmp)
  %i = $calc(%n - 1999)
  while (%i <= %n) {
    write $qt(%tmp) $read(%f,n,%i)
    inc %i
  }
  .remove $qt(%f)
  .rename $qt(%tmp) $qt(%f)
}
; split a mode string into one log line per mode:  ns.sl.mode <chan> <modes> <args...>
alias ns.sl.mode {
  var %c = $1, %m = $2, %args = $3-, %i = 1, %a = 1, %sign = +, %ch, %arg, %takes
  var %la = $ns.isup.cm(1), %lb = $ns.isup.cm(2), %lc = $ns.isup.cm(3), %pm = $ns.rk.modes
  while (%i <= $len(%m)) {
    %ch = $mid(%m,%i,1)
    inc %i
    if (%ch == +) || (%ch == $chr(45)) {
      %sign = %ch
      continue
    }
    %takes = 0
    if ($pos(%pm,%ch)) %takes = 1
    elseif ($pos(%la,%ch)) %takes = 1
    elseif ($pos(%lb,%ch)) %takes = 1
    elseif ($pos(%lc,%ch)) && (%sign == +) %takes = 1
    %arg = $null
    if (%takes) {
      %arg = $gettok(%args,%a,32)
      inc %a
    }
    ns.sl.one %c %sign %ch %arg
  }
}
alias ns.sl.one {
  var %c = $1, %s = $2, %ch = $3, %arg = $4, %kind = mode, %tgt = $4, %det = $+($2,$3)
  if (%ch == b) {
    if ($left(%arg,3) == ~q:) || ($left(%arg,2) == m:) {
      %kind = $iif(%s == +,quiet,unquiet)
      %tgt = $mid(%arg,$calc($pos(%arg,:) + 1))
    }
    else %kind = $iif(%s == +,ban,unban)
  }
  elseif (%ch == q) && ($pos($ns.isup.cm(1),q)) %kind = $iif(%s == +,quiet,unquiet)
  ns.sl.add %c %kind %tgt %det
}
on *:KICK:#:{ if ($nick == $me) ns.sl.add $chan kick $knick $1- }
on *:TOPIC:#:{ if ($nick == $me) ns.sl.add $chan topic - $1- }
on *:RAWMODE:#:{ if ($nick == $me) ns.sl.mode $chan $1- }

alias neon.stafflog ns.dlg ns_slog ns_slog
alias neon.staff ns.dlg ns_slog ns_slog
dialog ns_slog {
  title "Staff Log"
  size -1 -1 340 222
  option dbu
  icon 1, 0 0 340 30, $mircexe, 0, noborder
  text "Show:", 2, 6 38 22 9
  combo 3, 28 36 82 80, drop
  combo 4, 114 36 62 80, drop
  text "Find:", 6, 182 38 20 9
  edit "", 5, 204 36 86 11, autohs
  button "Refresh", 7, 294 35 40 12
  list 8, 6 52 328 130, size vsbar hsbar extsel
  text "", 9, 6 186 328 9
  button "Copy", 10, 6 202 50 13
  button "Export...", 11, 60 202 50 13
  button "Clear log...", 12, 114 202 56 13
  button "Close", 13, 286 202 48 13, ok cancel
}
on *:DIALOG:ns_slog:init:*:{
  did -g ns_slog 1 $ns.asset(header_slog.png)
  did -a ns_slog 3 All channels
  var %i = 1
  while (%i <= $chan(0)) {
    did -a ns_slog 3 $chan(%i)
    inc %i
  }
  did -c ns_slog 3 1
  did -a ns_slog 4 Everything
  did -a ns_slog 4 kick
  did -a ns_slog 4 ban
  did -a ns_slog 4 unban
  did -a ns_slog 4 quiet
  did -a ns_slog 4 unquiet
  did -a ns_slog 4 mode
  did -a ns_slog 4 topic
  did -c ns_slog 4 1
  slfill
}
alias -l slfill {
  var %f = $ns.sl.file, %n = $lines(%f), %i = %n, %shown = 0, %l, %chan = $did(ns_slog,3).text, %kind = $did(ns_slog,4).text, %q = $did(ns_slog,5).text, %line, %src, %ts
  did -r ns_slog 8
  if (%chan == All channels) %chan = $null
  if (%kind == Everything) %kind = $null
  while (%i > 0) && (%shown < 600) {
    %l = $read(%f,n,%i)
    dec %i
    if (%l == $null) continue
    if (%chan) && ($gettok(%l,3,9) != %chan) continue
    if (%kind) && ($gettok(%l,4,9) != %kind) continue
    if (%q) && ($+(*,%q,*) !iswm %l) continue
    %ts = $asctime($gettok(%l,1,9),mm-dd HH:nn)
    %line = $+(%ts,$chr(32),$chr(32),$gettok(%l,3,9),$chr(32),$chr(32),$upper($gettok(%l,4,9)),$chr(32),$chr(32),$gettok(%l,5,9),$chr(32),$chr(32),$gettok(%l,6,9),$chr(32),$chr(32),$chr(91),$gettok(%l,7,9),$chr(93))
    did -a ns_slog 8 %line
    inc %shown
  }
  did -ra ns_slog 9 %shown of %n entries shown $+ $iif(%shown == 600,$chr(32) $+ (newest 600) $+ $chr(44) newest first,$chr(44) newest first) $+ $chr(46) Source in [brackets]: manual / userlist / flood / mass / mute / lock ...
}
on *:DIALOG:ns_slog:sclick:3,4,7:{ slfill }
on *:DIALOG:ns_slog:edit:5:{ slfill }
on *:DIALOG:ns_slog:sclick:10:{
  var %n = $did(ns_slog,8).sel, %k = 1, %o
  if (!%n) {
    did -ra ns_slog 9 Select one or more lines first.
    return
  }
  while (%k <= %n) {
    %o = %o $+ $iif(%o,$crlf) $+ $did(ns_slog,8,$did(ns_slog,8,%k).sel).text
    inc %k
  }
  clipboard %o
  did -ra ns_slog 9 Copied %n line(s).
}
on *:DIALOG:ns_slog:sclick:11:{
  var %f = $sfile($+($mircdir,stafflog-,$asctime(yyyymmdd),.txt),Export the staff log,Save)
  if (!%f) return
  var %i = 1, %n = $did(ns_slog,8).lines
  if ($exists(%f)) .remove $qt(%f)
  while (%i <= %n) {
    write $qt(%f) $did(ns_slog,8,%i).text
    inc %i
  }
  did -ra ns_slog 9 Exported %n line(s) to %f
}
on *:DIALOG:ns_slog:sclick:12:{ ns.later ns.sl.clear }
alias ns.sl.clear {
  if (!$input(Delete the whole staff log? This cannot be undone.,yq,Clear staff log)) return
  if ($exists($ns.sl.file)) .remove $qt($ns.sl.file)
  if ($dialog(ns_slog)) slfill
  ns.say staff log cleared.
}

; ============================================================================
;  QUIET / MUTE
;  "quiet" is a ban that only stops talking.  Servers have two flavours: a real quiet list mode
;  (+q <mask> - Libera/Solanum, Ergo ...) or an extended ban (+b ~q:<mask> on UnrealIRCd, m:<mask> on
;  InspIRCd).  Which one is read from the server's own 005 line.
; ============================================================================
alias ns.mute.ini return $+($scriptdir,mutes.ini)
; mode | ext | none
alias ns.mute.kind {
  if ($pos($ns.isup.cm(1),q)) return mode
  if ($ns.mute.extban != $null) return ext
  return none
}
; "~q:" or "m:" - the extended-ban prefix for a quiet, or nothing
alias ns.mute.extban {
  var %eb = $ns.isup(EXTBAN), %pre, %ty
  if (%eb == $null) return $null
  if (!$regex(ns.eb,%eb,/^(.?)\x2C(.*)$/)) return $null
  %pre = $regml(ns.eb,1)
  %ty = $regml(ns.eb,2)
  if (%pre != $null) && ($pos(%ty,q)) return $+(%pre,q,:)
  if ($pos(%ty,m)) return $+(m,:)
  return $null
}
alias ns.mute.ids {
  var %i = 1, %o
  while ($ini($ns.mute.ini,%i)) {
    %o = %o $v1
    inc %i
  }
  return %o
}
alias ns.mute.get {
  var %v = $readini($ns.mute.ini,n,$1,$2)
  return %v
}
; send +q / +b ~q: for a mask (no safety checks - callers do those)
alias ns.mute.apply {
  var %c = $1, %m = $2, %secs = $3, %why = $4-, %k = $ns.mute.kind, %id
  if (%k == none) return
  ns.sl.tag %c mute
  if (%k == mode) mode %c +q %m
  else mode %c +b $+($ns.mute.extban,%m)
  %id = $+(m,$ctime,$r(10,99))
  writeini -n $qt($ns.mute.ini) %id net $ns.mod.net
  writeini -n $qt($ns.mute.ini) %id chan %c
  writeini -n $qt($ns.mute.ini) %id kind %k
  writeini -n $qt($ns.mute.ini) %id mask %m
  writeini -n $qt($ns.mute.ini) %id until $iif(%secs > 0,$calc($ctime + %secs),0)
  writeini -n $qt($ns.mute.ini) %id reason %why
  if ($ns.mute.extban != $null) writeini -n $qt($ns.mute.ini) %id ext $ns.mute.extban
}
; ns.mute.do <chan> <nick|mask> [seconds] [reason...]   - the checked, user-facing version
alias ns.mute.do {
  var %c = $1, %t = $2, %secs = $3, %why = $4-, %mask, %isnick = 1
  if (!$ns.ischan(%c)) {
    ns.err quiet: $1 is not a channel window.
    return
  }
  if ($ns.mute.kind == none) {
    ns.err this server has no quiet mode (it would need +q or an extended ban of type q) - use /kick or a ban instead.
    return
  }
  if (!$ns.rk.cankick(%c)) {
    ns.err I need halfop or higher in %c to quiet anyone.
    return
  }
  if ($pos(%t,!)) || ($pos(%t,@)) %isnick = 0
  if (%isnick) {
    if (%t == $me) {
      ns.err I will not quiet myself.
      return
    }
    if ($nick(%c,%t)) {
      if ($ns.rk.outranks(%c,%t,$me)) {
        ns.err %t outranks me in %c $+ .
        return
      }
      if ($ns.acc.safe(%t,%c)) {
        ns.err %t is protected (halfop or higher, or flagged protected on the userlist) - not quieted.
        return
      }
    }
    %mask = $ns.mask(%t)
  }
  else %mask = %t
  ns.mute.apply %c %mask %secs %why
  ns.say quiet set on $+($ns.b,%mask,$ns.b) in %c $+ $iif(%secs > 0,$chr(32) $+ for $ns.mod.dur(%secs)) $+ $iif(%why,$chr(32) $+ - %why) $+ .
}
; take a quiet off:  by mask, or by nick (matching what was recorded, else the nick's *!*@host)
alias ns.mute.undo {
  var %c = $1, %t = $2, %i = 1, %id, %m, %found = 0, %k
  if (!$ns.ischan(%c)) {
    ns.err unquiet: $1 is not a channel window.
    return
  }
  if (!$ns.rk.cankick(%c)) {
    ns.err I need halfop or higher in %c to lift a quiet.
    return
  }
  %k = $ns.mute.kind
  while ($gettok($ns.mute.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    if ($ns.mute.get(%id,net) != $ns.mod.net) || ($ns.mute.get(%id,chan) != %c) continue
    %m = $ns.mute.get(%id,mask)
    if (%t == %m) || (%t iswm %m) || ($ns.mask(%t) == %m) || ($+(%t,!*@*) == %m) {
      ns.mute.lift %c %id
      inc %found
    }
  }
  if (!%found) {
    ; not one of mine (set by someone else or in an earlier session): send the removal anyway
    %m = $iif($pos(%t,!) || $pos(%t,@),%t,$ns.mask(%t))
    if (%k == none) {
      ns.err this server has no quiet mode.
      return
    }
    ns.sl.tag %c mute
    if (%k == mode) mode %c -q %m
    else mode %c -b $+($ns.mute.extban,%m)
    ns.say quiet removed for $+($ns.b,%m,$ns.b) in %c $+ .
  }
}
; remove the mode for a recorded entry and forget it
alias ns.mute.lift {
  var %c = $1, %id = $2, %m = $ns.mute.get(%id,mask), %kind = $ns.mute.get(%id,kind), %ext = $ns.mute.get(%id,ext)
  ns.sl.tag %c mute
  if (%kind == mode) mode %c -q %m
  else mode %c -b $+(%ext,%m)
  remini $qt($ns.mute.ini) %id
}
; every minute: lift quiets whose time is up (only on networks I am connected to, in channels I am still in)
alias ns.mute.tick {
  var %i = 1, %id, %u, %n, %c, %s
  while ($gettok($ns.mute.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    %u = $ns.mute.get(%id,until)
    if (!%u) || (%u > $ctime) continue
    %n = $ns.mute.get(%id,net)
    %c = $ns.mute.get(%id,chan)
    %s = 1
    while (%s <= $scon(0)) {
      if ($scon(%s).network == %n) && ($scon(%s).status == connected) {
        scid $scon(%s).cid ns.mute.expire %id
        break
      }
      inc %s
    }
  }
}
alias ns.mute.expire {
  var %id = $1, %c = $ns.mute.get(%id,chan)
  if (!$ns.ischan(%c)) || (!$ns.rk.cankick(%c)) return
  ns.mute.lift %c %id
  ns.say quiet on $+($ns.b,$ns.mute.get(%id,mask),$ns.b) in %c has expired - lifted.
}
alias neon.quiet {
  var %c = $active, %t = $1, %secs = 0, %why
  if (%t == $null) {
    ns.err usage: /neon quiet <nick|mask> [10m|2h|1d] [reason]   (in a channel window)
    return
  }
  if ($2 != $null) && ($ns.mod.secs($2) > 0) {
    %secs = $ns.mod.secs($2)
    %why = $3-
  }
  else %why = $2-
  ns.mute.do %c %t %secs %why
}
alias neon.unquiet {
  if ($1 == $null) {
    ns.err usage: /neon unquiet <nick|mask>
    return
  }
  ns.mute.undo $active $1
}
alias neon.quiets {
  var %i = 1, %id, %n = 0, %u
  while ($gettok($ns.mute.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    %u = $ns.mute.get(%id,until)
    ns.say quiet $+($ns.mute.get(%id,chan),:) $ns.mute.get(%id,mask) $+($chr(40),$ns.mute.get(%id,net),$iif(%u,$chr(44) ends $asctime(%u,ddd HH:nn),$chr(44) until lifted),$chr(41))
    inc %n
  }
  if (!%n) ns.say no quiets set by NeonScript (set one with /neon quiet <nick> [10m]).
}
on *:SIGNAL:ns.boot:{
  .timer.nsmute 0 60 ns.mute.tick
  .timer.nsmq off
}

; ============================================================================
;  MASS ACTIONS
; ============================================================================
; --- a throttled queue, so a mass action never floods the server off ------------------------------
alias ns.mq.add {
  ; ns.mq.add <chan> <source> <command...>
  hinc -m ns.mq t
  hadd ns.mq $hget(ns.mq,t) $+($cid,$chr(9),$1,$chr(9),$2,$chr(9),$3-)
  if (!$timer(nsmq)) .timer.nsmq -m 1 100 ns.mq.pop
}
alias ns.mq.pending return $calc($hget(ns.mq,t) - $hget(ns.mq,h))
alias ns.mq.pop {
  var %h = $calc($hget(ns.mq,h) + 1), %l = $hget(ns.mq,%h), %cid, %c, %src, %cmd
  if (%l == $null) {
    ns.mq.stop
    return
  }
  hadd -m ns.mq h %h
  hdel ns.mq %h
  %cid = $gettok(%l,1,9)
  %c = $gettok(%l,2,9)
  %src = $gettok(%l,3,9)
  %cmd = $gettok(%l,4-,9)
  scid %cid ns.sl.tag %c %src
  scid %cid %cmd
  if ($ns.mq.pending > 0) .timer.nsmq -m 1 $ns.get(mass,gap,700) ns.mq.pop
  else {
    ns.mq.stop
    ns.say mass action finished.
  }
}
alias ns.mq.stop {
  .timer.nsmq off
  if ($hget(ns.mq)) hfree ns.mq
}

; --- choosing who -------------------------------------------------------------------------------
; does <nick> match one of the patterns?  patterns: nick wildcards, address masks (contain ! or @),
; the words clones / norank, and re:<regex> (matched against nick!user@host)
alias ns.mass.match {
  var %c = $1, %nk = $2, %k = 1, %p, %addr = $address(%nk,5)
  if (%addr == $null) %addr = $+(%nk,!*@*)
  while ($gettok($3-,%k,32) != $null) {
    %p = $v1
    inc %k
    if (%p == *) return 1
    if (%p == clones) {
      if ($ialchan($address(%nk,2),%c,0) >= 2) return 1
      continue
    }
    if (%p == norank) {
      if (!$ns.rk.of(%c,%nk)) return 1
      continue
    }
    if (%p == unauth) {
      if ($isalias(ns.v3.acct)) && ($ns.v3.acct(%nk) == $null) return 1
      continue
    }
    if ($left(%p,3) == re:) {
      if ($len(%p) < 80) && ($regex(ns.mp,%addr,$+(/,$mid(%p,4),/i))) return 1
      continue
    }
    if ($pos(%p,!)) || ($pos(%p,@)) {
      if (%p iswm %addr) return 1
      continue
    }
    if (%p iswm %nk) return 1
  }
  return 0
}
; why a matching nick must be left alone for this action ("" = fine)
alias ns.mass.skipwhy {
  var %c = $1, %nk = $2, %act = $3, %opt = $4
  if (%nk == $me) return self
  if (%act == voice) {
    if ($ns.rk.of(%c,%nk)) return has-rank
    return $null
  }
  if (%act == devoice) {
    if (!$ns.rk.has(%c,%nk,v)) return no-voice
    if ($ns.rk.of(%c,%nk) != $ns.rk.char(v)) return has-rank
    return $null
  }
  if ($ns.rk.outranks(%c,%nk,$me)) return outranks-me
  if ($pos($ns.acc.flags(%nk,%c),p)) return protected
  if ($ns.rk.atleast(%c,%nk,h)) || ($ns.rk.atleast(%c,%nk,o)) return ops
  if (r isin %opt) && ($ns.rk.of(%c,%nk)) return has-rank
  if (u isin %opt) && ($ns.acc.firstid(%nk) != $null) return on-userlist
  return $null
}
; fills hash ns.mres: list (nicks to act on), skip (nick(reason) ...), count, nskip
;   ns.mass.pick <chan> <action> <opts> <patterns...>      opts: r = only people without a rank, u = skip userlist
alias ns.mass.pick {
  var %c = $1, %act = $2, %opt = $3, %pat = $4-, %i = 1, %n = $nick(%c,0), %nk, %why, %list, %skip
  if ($hget(ns.mres)) hfree ns.mres
  hmake ns.mres 5
  if (%pat == $null) %pat = *
  while (%i <= %n) {
    %nk = $nick(%c,%i)
    inc %i
    if (!$ns.mass.match(%c,%nk,%pat)) continue
    %why = $ns.mass.skipwhy(%c,%nk,%act,%opt)
    if (%why) %skip = %skip %nk $+ $chr(40) $+ %why $+ $chr(41)
    else %list = %list %nk
  }
  %list = $ns.trim(%list)
  %skip = $ns.trim(%skip)
  hadd ns.mres list %list
  hadd ns.mres skip %skip
  hadd ns.mres count $numtok(%list,32)
  hadd ns.mres nskip $numtok(%skip,32)
}
alias ns.mass.label {
  if ($1 == voice) return give voice
  if ($1 == devoice) return take voice from
  if ($1 == kick) return kick
  if ($1 == ban) return ban
  if ($1 == kickban) return kick and ban
  if ($1 == mute) return quiet
  return $1
}
; --- doing it -----------------------------------------------------------------------------------
; acts on the list from the last ns.mass.pick:  ns.mass.exec <chan> <action> <seconds-for-quiet> <reason...>
alias ns.mass.exec {
  var %c = $1, %act = $2, %secs = $3, %why = $4-, %list = $hget(ns.mres,list), %n = $numtok(%list,32), %i = 1, %nk
  var %t = $ns.get(kb,bantype,2), %lim = $iif($modespl > 0,$modespl,4), %chunk, %cnt, %sign
  if (!%n) {
    ns.err mass action: nobody to act on.
    return 0
  }
  if (%act == voice) || (%act == devoice) {
    if (!$ns.rk.cangive(%c,v)) {
      ns.err I need halfop or higher in %c to change voice.
      return 0
    }
    %sign = $iif(%act == voice,+,-)
    while (%i <= %n) {
      %chunk = $gettok(%list,$+(%i,-,$calc(%i + %lim - 1)),32)
      %cnt = $numtok(%chunk,32)
      ns.mq.add %c mass mode %c %sign $+ $str(v,%cnt) %chunk
      inc %i %lim
    }
  }
  else {
    if (!$ns.rk.cankick(%c)) {
      ns.err I need halfop or higher in %c for that.
      return 0
    }
    if (%act == mute) && ($ns.mute.kind == none) {
      ns.err this server has no quiet mode - choose kick or ban instead.
      return 0
    }
    if (%why == $null) %why = $ns.msg(kick)
    while (%i <= %n) {
      %nk = $gettok(%list,%i,32)
      inc %i
      if (%act == kick) ns.mq.add %c mass kick %c %nk %why
      elseif (%act == ban) ns.mq.add %c mass ban %c %nk %t
      elseif (%act == kickban) ns.mq.add %c mass ban -k %c %nk %t %why
      elseif (%act == mute) ns.mq.add %c mass ns.mute.apply %c $ns.mask(%nk) %secs %why
    }
  }
  ns.say mass action in %c $+ : $ns.mass.label(%act) %n $iif(%n == 1,person,people) - sending slowly so the server is not flooded ( $+ /neon mass stop cancels).
  return %n
}
; /neon mass                      the dialog
; /neon mass stop                 cancel what is still queued
; /neon mass <voice|devoice|kick|ban|kickban|quiet> <pattern...> [-r reason] [-t 10m] [-n] [-a] [-y]
;      patterns: nick wildcards (Clone*), masks (*!*@host), clones, norank, re:<regex>.
;      -n only people without a rank   -a include people on my userlist   -y do it (without it you get a preview)
alias neon.mass {
  var %act = $lower($1), %c = $active, %i = 2, %tok, %pat, %why, %dur, %y = 0, %opt = u, %mode = pat
  if (%act == $null) {
    set -u60 %ns.mass.chan $iif($ns.ischan($active),$active)
    ns.dlg ns_mass ns_mass
    return
  }
  if (%act == stop) {
    ns.mq.stop
    ns.say mass action stopped.
    return
  }
  if (%act == quiet) %act = mute
  if (%act == kick+ban) %act = kickban
  if (!$istok(voice devoice kick ban kickban mute,%act,32)) {
    ns.err usage: /neon mass <voice|devoice|kick|ban|kickban|quiet> <pattern...> [-r reason] [-t 10m] [-n] [-a] [-y]
    return
  }
  if (!$ns.ischan(%c)) {
    ns.err open the channel window first.
    return
  }
  while ($gettok($1-,%i,32) != $null) {
    %tok = $v1
    inc %i
    if (%tok == -y) { %y = 1 | continue }
    if (%tok == -n) { %opt = %opt $+ r | continue }
    if (%tok == -a) { %opt = $remove(%opt,u) | continue }
    if (%tok == -r) { %mode = why | continue }
    if (%tok == -t) {
      %dur = $gettok($1-,%i,32)
      inc %i
      continue
    }
    if (%mode == why) %why = %why %tok
    else %pat = %pat %tok
  }
  %pat = $ns.trim(%pat)
  ns.mass.pick %c %act %opt %pat
  ns.say mass $ns.mass.label(%act) in %c $+ : $hget(ns.mres,count) match $+ $iif($hget(ns.mres,count) > 0,$chr(58) $hget(ns.mres,list)) $+ $iif($hget(ns.mres,nskip) > 0,$chr(59) $hget(ns.mres,nskip) left alone: $hget(ns.mres,skip)) $+ .
  if (!$hget(ns.mres,count)) return
  if (%y) ns.mass.exec %c %act $ns.mod.secs(%dur) %why
  else ns.say that was only a preview - add -y to do it.
}

dialog ns_mass {
  title "Mass Actions"
  size -1 -1 320 238
  option dbu
  icon 1, 0 0 320 30, $mircexe, 0, noborder
  text "Channel:", 2, 6 38 32 9
  combo 3, 40 36 100 80, drop
  text "", 4, 146 38 168 9
  text "Action:", 5, 6 54 32 9
  combo 6, 40 52 100 80, drop
  text "Who:", 7, 6 70 32 9
  edit "", 8, 40 68 274 11, autohs
  text "Nick patterns (Clone*, *bot), address masks (*!*@host.example), the words clones or norank, or re:<regex>. Separate several with spaces.", 9, 40 81 274 18
  text "Reason:", 10, 6 102 32 9
  edit "", 11, 40 100 274 11, autohs
  text "Quiet for:", 12, 6 118 32 9
  edit "", 13, 40 116 40 11, autohs
  text "e.g. 10m or 2h - empty means until I lift it (quiet only)", 14, 86 118 228 9
  check "Only people without any rank", 15, 6 132 150 9
  check "Skip people on my userlist", 16, 160 132 154 9
  button "Preview", 17, 6 146 50 12
  list 18, 6 162 308 48, size vsbar extsel
  text "", 19, 6 213 308 9
  button "Run it", 20, 208 222 50 13
  button "Stop queue", 21, 6 222 52 13
  button "Close", 22, 264 222 50 13, ok cancel
}
on *:DIALOG:ns_mass:init:*:{
  did -g ns_mass 1 $ns.asset(header_mass.png)
  ns.mod.fillchans ns_mass 3 %ns.mass.chan
  did -a ns_mass 6 Give voice (+v)
  did -a ns_mass 6 Take voice (-v)
  did -a ns_mass 6 Kick
  did -a ns_mass 6 Ban
  did -a ns_mass 6 Kick + ban
  did -a ns_mass 6 Quiet (mute)
  did -c ns_mass 6 1
  did -c ns_mass 16
  did -b ns_mass 20
  massinfo
}
alias -l mkeys return voice devoice kick ban kickban mute
alias -l mact return $gettok($mkeys,$did(ns_mass,6).sel,32)
alias -l mopts return $iif($did(ns_mass,15).state,r)$iif($did(ns_mass,16).state,u)
alias -l massinfo {
  var %c = $did(ns_mass,3).text, %rk = $ns.rk.of(%c,$me)
  if (!$ns.ischan(%c)) {
    did -ra ns_mass 4 not on a channel - open one first
    return
  }
  did -ra ns_mass 4 $nick(%c,0) users $+ $chr(44) you are $iif(%rk,$ns.rk.name(%rk),a regular user)
}
alias -l massdirty {
  did -b ns_mass 20
  did -ra ns_mass 19 Press Preview to see who would be affected.
}
on *:DIALOG:ns_mass:sclick:3:{ massinfo | massdirty }
on *:DIALOG:ns_mass:sclick:6,15,16:{ massdirty }
on *:DIALOG:ns_mass:edit:8,11,13:{ massdirty }
on *:DIALOG:ns_mass:sclick:17:{
  var %c = $did(ns_mass,3).text, %act = $mact, %i = 1, %list, %n
  did -r ns_mass 18
  if (!$ns.ischan(%c)) {
    did -ra ns_mass 19 Pick a channel you are in.
    return
  }
  ns.mass.pick %c %act $mopts $did(ns_mass,8).text
  %list = $hget(ns.mres,list)
  %n = $numtok(%list,32)
  while (%i <= %n) {
    did -a ns_mass 18 $+($ns.rk.of(%c,$gettok(%list,%i,32)),$gettok(%list,%i,32))
    inc %i
  }
  if (!%n) did -ra ns_mass 19 Nobody matches $+ $iif($hget(ns.mres,nskip) > 0,$chr(59) $hget(ns.mres,nskip) left alone: $left($hget(ns.mres,skip),120)) $+ .
  else {
    did -ra ns_mass 19 %n will be affected $+ $iif($hget(ns.mres,nskip) > 0,$chr(59) $hget(ns.mres,nskip) left alone: $left($hget(ns.mres,skip),110)) $+ .
    did -e ns_mass 20
  }
}
on *:DIALOG:ns_mass:sclick:20:{ ns.later ns.mass.confirm }
alias ns.mass.confirm {
  if (!$dialog(ns_mass)) return
  var %c = $did(ns_mass,3).text, %act = $mact, %n = $hget(ns.mres,count)
  if (!%n) return
  if (!$input($upper($left($ns.mass.label(%act),1)) $+ $mid($ns.mass.label(%act),2) %n $iif(%n == 1,person,people) in %c $+ $chr(63) $+ $crlf $+ $left($hget(ns.mres,list),200),yq,Mass action)) return
  if ($ns.mass.exec(%c,%act,$ns.mod.secs($did(ns_mass,13).text),$did(ns_mass,11).text)) {
    did -ra ns_mass 19 Sent to the queue - $hget(ns.mq,t) command(s). Stop queue cancels what is left.
    did -b ns_mass 20
  }
}
on *:DIALOG:ns_mass:sclick:21:{
  ns.mq.stop
  did -ra ns_mass 19 Queue cleared.
}

; ============================================================================
;  TOPIC TEMPLATES
; ============================================================================
alias ns.tpl.ini return $+($scriptdir,topic_tpl.ini)
alias ns.tpl.ids {
  var %i = 1, %o
  while ($ini($ns.tpl.ini,%i)) {
    %o = %o $v1
    inc %i
  }
  return %o
}
alias ns.tpl.seed {
  if ($exists($ns.tpl.ini)) return
  var %p = $chr(32) $+ $chr(124) $+ $chr(32)
  writeini -n $qt($ns.tpl.ini) t1 name Welcome
  writeini -n $qt($ns.tpl.ini) t1 text Welcome to {chan} - be kind and have fun
  writeini -n $qt($ns.tpl.ini) t2 name Event
  writeini -n $qt($ns.tpl.ini) t2 text $+(EVENT: something fun on {date} at {time},%p,{old})
  writeini -n $qt($ns.tpl.ini) t3 name Maintenance
  writeini -n $qt($ns.tpl.ini) t3 text $+(Maintenance tonight - expect short interruptions,%p,{old})
  writeini -n $qt($ns.tpl.ini) t4 name Away
  writeini -n $qt($ns.tpl.ini) t4 text $+({me} is away - back soon,%p,{old})
}
; fill in the placeholders for a channel:  $ns.tpl.fill(<chan>,<text...>)
alias ns.tpl.fill {
  var %c = $1
  return $replace($2-,{chan},%c,{me},$me,{date},$asctime(ddd d mmm yyyy),{time},$asctime(HH:nn),{network},$ns.mod.net,{users},$nick(%c,0),{old},$chan(%c).topic)
}
alias ns.tpl.byname {
  var %i = 1, %id
  while ($gettok($ns.tpl.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    if ($readini($ns.tpl.ini,n,%id,name) == $1-) return %id
  }
  return $null
}
alias ns.tpl.maxlen return $iif($ns.isup(TOPICLEN) isnum,$ns.isup(TOPICLEN),300)
; set the topic from a template (checks length and that I may):  ns.tpl.apply <chan> <text...>
alias ns.tpl.apply {
  var %c = $1, %txt = $ns.tpl.fill(%c,$2-)
  if (!$ns.ischan(%c)) {
    ns.err topic: $1 is not a channel I am in.
    return 0
  }
  if ($len(%txt) > $ns.tpl.maxlen) {
    ns.err that topic is $len(%txt) characters but this server allows $ns.tpl.maxlen $+ .
    return 0
  }
  if (!$ns.rk.atleast(%c,$me,h)) && ($ns.ch.hasmode($gettok($chan(%c).mode,1,32),t)) {
    ns.err the topic is locked (+t) and I am not an op in %c $+ .
    return 0
  }
  topic %c %txt
  return 1
}
; /neon topictpl            the dialog     /neon topictpl <name>     apply that template in this channel
alias neon.topictpl {
  ns.tpl.seed
  if ($1 == $null) {
    set -u60 %ns.tpl.chan $iif($ns.ischan($active),$active)
    ns.dlg ns_tpl ns_tpl
    return
  }
  var %id = $ns.tpl.byname($1-)
  if (!%id) {
    ns.err no topic template called $qt($1-) $+ . /neon topictpl lists them.
    return
  }
  if (!$ns.ischan($active)) {
    ns.err open the channel window first.
    return
  }
  if ($ns.tpl.apply($active,$readini($ns.tpl.ini,n,%id,text))) ns.say topic set from the template $qt($1-) $+ .
}
dialog ns_tpl {
  title "Topic Templates"
  size -1 -1 304 206
  option dbu
  icon 1, 0 0 304 30, $mircexe, 0, noborder
  list 2, 6 36 84 118, size vsbar
  text "Name:", 3, 96 38 24 9
  edit "", 4, 122 36 176 11, autohs
  text "Template:", 5, 96 52 36 9
  edit "", 6, 96 62 202 11, autohs
  text "Placeholders: {chan} {me} {date} {time} {network} {users} {old} (the current topic). Use the | sign to separate parts.", 7, 96 76 202 18
  text "Result in the channel:", 8, 96 98 100 9
  edit "", 9, 96 108 202 28, read multi vsbar
  text "", 10, 96 138 202 9
  text "Channel:", 11, 6 160 30 9
  combo 12, 38 158 52 70, drop
  button "Save", 13, 96 156 44 12
  button "Delete", 14, 144 156 44 12
  button "New", 15, 192 156 44 12
  button "Set as topic", 16, 6 176 60 13
  text "", 17, 70 178 160 9
  button "Close", 18, 250 190 48 13, ok cancel
}
on *:DIALOG:ns_tpl:init:*:{
  did -g ns_tpl 1 $ns.asset(header_tpl.png)
  ns.tpl.seed
  ns.mod.fillchans ns_tpl 12 %ns.tpl.chan
  tplfill
  tplpick 1
}
alias -l tplfill {
  var %i = 1, %id
  did -r ns_tpl 2
  while ($gettok($ns.tpl.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    did -a ns_tpl 2 $readini($ns.tpl.ini,n,%id,name)
  }
}
alias -l tplpick {
  var %id = $gettok($ns.tpl.ids,$1,32)
  if (!%id) {
    did -r ns_tpl 4
    did -r ns_tpl 6
    tplpreview
    return
  }
  did -c ns_tpl 2 $1
  did -ra ns_tpl 4 $readini($ns.tpl.ini,n,%id,name)
  did -ra ns_tpl 6 $readini($ns.tpl.ini,n,%id,text)
  tplpreview
}
alias -l tplpreview {
  var %c = $did(ns_tpl,12).text, %t = $did(ns_tpl,6).text, %r
  %r = $ns.tpl.fill(%c,%t)
  did -ra ns_tpl 9 %r
  did -ra ns_tpl 10 $len(%r) characters $+ $iif($len(%r) > $ns.tpl.maxlen,$chr(32) $+ - TOO LONG: this server allows $ns.tpl.maxlen,$chr(32) $+ (this server allows $ns.tpl.maxlen $+ $chr(41)))
}
on *:DIALOG:ns_tpl:sclick:2:{ tplpick $did(ns_tpl,2).sel }
on *:DIALOG:ns_tpl:edit:6:{ tplpreview }
on *:DIALOG:ns_tpl:sclick:12:{ tplpreview }
on *:DIALOG:ns_tpl:sclick:13:{
  var %n = $did(ns_tpl,4).text, %t = $did(ns_tpl,6).text, %id
  if (%n == $null) || (%t == $null) {
    did -ra ns_tpl 17 Give it a name and some text first.
    return
  }
  %id = $ns.tpl.byname(%n)
  if (!%id) {
    var %k = 1
    while ($readini($ns.tpl.ini,n,$+(t,%k),name) != $null) inc %k
    %id = $+(t,%k)
  }
  writeini -n $qt($ns.tpl.ini) %id name %n
  writeini -n $qt($ns.tpl.ini) %id text %t
  tplfill
  tplpick $findtok($ns.tpl.ids,%id,1,32)
  did -ra ns_tpl 17 Saved.
}
on *:DIALOG:ns_tpl:sclick:14:{
  var %id = $gettok($ns.tpl.ids,$did(ns_tpl,2).sel,32)
  if (!%id) return
  remini $qt($ns.tpl.ini) %id
  tplfill
  tplpick 1
  did -ra ns_tpl 17 Deleted.
}
on *:DIALOG:ns_tpl:sclick:15:{
  did -r ns_tpl 4
  did -r ns_tpl 6
  tplpreview
  did -ra ns_tpl 17 Type a name and the text, then Save.
}
on *:DIALOG:ns_tpl:sclick:16:{
  var %c = $did(ns_tpl,12).text, %t = $did(ns_tpl,6).text
  if (!%t) {
    did -ra ns_tpl 17 Nothing to set.
    return
  }
  if ($ns.tpl.apply(%c,%t)) did -ra ns_tpl 17 Topic sent to %c $+ .
  else did -ra ns_tpl 17 Not set - see the status window.
}
