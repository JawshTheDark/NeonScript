; ============================================================================
;  NeonScript 2026  ::  automation rules  (event actions + auto-replies)
;
;  A rule is:  WHEN something happens  (a message, a join, a kick, a connect ...)
;              WHERE / FROM WHOM / MATCHING WHAT  (network, channels, people, text)
;              plus limits  (cool-down, only while away, chance)
;              THEN a list of actions  (say, reply, notice, kick, wait, toast ...)
;  Auto-replies are simply rules whose action is "say" or "reply".   /neon rules
;
;  Rules are stored in rules.ini; the active ones are cached in the ns.arules hash.
;  Safety: text that comes from other people is only ever substituted into a command as DATA - the
;  commands are built from a fixed vocabulary of actions, so a nick or message can never inject a command.
;  Actions go out through the same throttled queue as mass actions, rules cannot answer themselves
;  (no rule fires on my own lines), and a runaway is stopped by a breaker (40 firings a minute pauses
;  every rule for five minutes).
; ============================================================================

alias ns.auto.ini return $+($scriptdir,rules.ini)
alias ns.auto.ids {
  var %i = 1, %o
  while ($ini($ns.auto.ini,%i)) {
    %o = %o $v1
    inc %i
  }
  return %o
}
alias ns.auto.triggers return text mention pm action notice join part quit kick nick topic invite connect disconnect
alias ns.auto.fields return name on trig net chan from match cool away chance
; raw ini access (the editor works on the file; matching works on the cache)
alias ns.auto.rd return $readini($ns.auto.ini,n,$1,$2)
alias ns.auto.wr {
  if ($3- == $null) writeini -nz $qt($ns.auto.ini) $1 $2
  else writeini -n $qt($ns.auto.ini) $1 $2 $3-
}
alias ns.auto.newid {
  var %n = 1
  while ($ini($ns.auto.ini,$+(r,%n))) inc %n
  return $+(r,%n)
}
; the cache: <id>.<field>, <id>.a1.. (actions), trigs = triggers of enabled rules, ids = enabled rules
alias ns.auto.load {
  if ($hget(ns.arules)) hfree ns.arules
  hmake ns.arules 200
  var %i = 1, %id, %f, %k, %v, %n, %trigs, %ids
  while ($ini($ns.auto.ini,%i)) {
    %id = $v1
    inc %i
    %k = 1
    while ($gettok($ns.auto.fields,%k,32) != $null) {
      %f = $gettok($ns.auto.fields,%k,32)
      inc %k
      hadd ns.arules $+(%id,.,%f) $ns.auto.rd(%id,%f)
    }
    %n = 1
    %v = $ns.auto.rd(%id,a1)
    while (%v != $null) {
      hadd ns.arules $+(%id,.a,%n) %v
      inc %n
      %v = $ns.auto.rd(%id,$+(a,%n))
    }
    if ($ns.auto.rd(%id,on) == 1) {
      %ids = %ids %id
      %trigs = $addtok(%trigs,$ns.auto.rd(%id,trig),32)
    }
  }
  hadd ns.arules ids $ns.trim(%ids)
  hadd ns.arules trigs $ns.trim(%trigs)
}
on *:SIGNAL:ns.boot:{ ns.auto.load }
alias ns.auto.on return $ns.flag(rules,on,1)
alias ns.auto.has return $iif($ns.auto.on && !%ns.auto.paused && $istok($hget(ns.arules,trigs),$1,32),1,0)

; ---------------------------------------------------------------- events -> rules
; context is collected in the ns.actx hash:  type window nick text addr net  (+ knick reason newnick ...)
alias ns.auto.begin {
  if ($hget(ns.actx)) hfree ns.actx
  hmake ns.actx 10
  hadd ns.actx type $1
  hadd ns.actx window $iif($2 != $null,$2,-)
  hadd ns.actx nick $iif($3 != $null,$3,-)
  hadd ns.actx text $4-
  hadd ns.actx addr $fulladdress
  hadd ns.actx net $iif($network,$network,$iif($server,$server,-))
  hadd ns.actx cid $cid
}
alias ns.auto.ctx hadd ns.actx $1 $2-
alias ns.auto.go {
  var %i = 1, %id, %type = $hget(ns.actx,type)
  if ($ns.bnc.q) return
  while ($gettok($hget(ns.arules,ids),%i,32) != $null) {
    %id = $v1
    inc %i
    if ($hget(ns.arules,$+(%id,.trig)) != %type) continue
    if ($ns.auto.test(%id)) ns.auto.fire %id
  }
}
on *:TEXT:*:#:{
  if ($ns.auto.has(text)) {
    ns.auto.begin text $chan $nick $1-
    ns.auto.go
  }
  if ($ns.auto.has(mention)) && ($ns.mi.hit($1-)) && (!$ns.hl.muted($fulladdress)) {
    ns.auto.begin mention $chan $nick $1-
    ns.auto.go
  }
}
on *:TEXT:*:?:{
  if ($ns.auto.has(pm)) {
    ns.auto.begin pm $nick $nick $1-
    ns.auto.go
  }
}
on *:ACTION:*:#:{
  if ($ns.auto.has(action)) {
    ns.auto.begin action $chan $nick $1-
    ns.auto.go
  }
}
on *:NOTICE:*:#:{
  if ($ns.auto.has(notice)) {
    ns.auto.begin notice $chan $nick $1-
    ns.auto.go
  }
}
on *:JOIN:#:{
  if ($ns.auto.has(join)) {
    ns.auto.begin join $chan $nick
    ns.auto.go
  }
}
on *:PART:#:{
  if ($ns.auto.has(part)) {
    ns.auto.begin part $chan $nick $1-
    ns.auto.go
  }
}
on *:QUIT:{
  if ($ns.auto.has(quit)) {
    ns.auto.begin quit - $nick $1-
    ns.auto.go
  }
}
on *:KICK:#:{
  if ($ns.auto.has(kick)) {
    ns.auto.begin kick $chan $nick $1-
    ns.auto.ctx knick $knick
    ns.auto.ctx reason $1-
    ns.auto.go
  }
}
on *:NICK:{
  if ($ns.auto.has(nick)) {
    ns.auto.begin nick - $nick $newnick
    ns.auto.ctx newnick $newnick
    ns.auto.go
  }
}
on *:TOPIC:#:{
  if ($ns.auto.has(topic)) {
    ns.auto.begin topic $chan $nick $1-
    ns.auto.go
  }
}
on *:INVITE:#:{
  if ($ns.auto.has(invite)) {
    ns.auto.begin invite $chan $nick $chan
    ns.auto.go
  }
}
on *:CONNECT:{
  if ($ns.auto.has(connect)) {
    ns.auto.begin connect - $me
    ns.auto.go
  }
}
on *:DISCONNECT:{
  if ($ns.auto.has(disconnect)) {
    ns.auto.begin disconnect - $me
    ns.auto.go
  }
}

; ---------------------------------------------------------------- conditions
; a comma separated list of wildcards; empty / * matches everything
alias ns.auto.wild {
  var %l = $1, %t = $2-, %i = 1, %p
  if (%l == $null) || (%l == *) return 1
  while ($gettok(%l,%i,44) != $null) {
    %p = $ns.trim($gettok(%l,%i,44))
    inc %i
    if (%p iswm %t) return 1
  }
  return 0
}
; text patterns: comma separated; plain words mean "contains"; re:<regex> is a regular expression
alias ns.auto.tmatch {
  var %l = $1, %t = $2-, %i = 1, %p
  if (%l == $null) return 1
  if ($left(%l,3) == re:) {
    if ($len(%l) > 120) return 0
    return $iif($regex(ns.arx,%t,$+(/,$mid(%l,4),/i)),1,0)
  }
  while ($gettok(%l,%i,44) != $null) {
    %p = $ns.trim($gettok(%l,%i,44))
    inc %i
    if (!$pos(%p,*)) && (!$pos(%p,$chr(63))) %p = $+(*,%p,*)
    if (%p iswm %t) return 1
  }
  return 0
}
; who: nick/address wildcards plus the words ops voice norank userlist - a leading ! negates
alias ns.auto.who {
  var %l = $1, %nick = $hget(ns.actx,nick), %win = $hget(ns.actx,window), %addr = $hget(ns.actx,addr), %i = 1, %p, %neg, %hit, %any = 0, %ok = 0
  if (%l == $null) || (%l == *) return 1
  while ($gettok($replace(%l,$chr(44),$chr(32)),%i,32) != $null) {
    %p = $gettok($replace(%l,$chr(44),$chr(32)),%i,32)
    inc %i
    %neg = 0
    if ($left(%p,1) == !) {
      %neg = 1
      %p = $mid(%p,2)
    }
    if (%p == ops) %hit = $iif($ns.rk.atleast(%win,%nick,h) || $ns.rk.atleast(%win,%nick,o),1,0)
    elseif (%p == voice) %hit = $ns.rk.has(%win,%nick,v)
    elseif (%p == norank) %hit = $iif(!$ns.rk.of(%win,%nick),1,0)
    elseif (%p == userlist) %hit = $iif($ns.acc.firstid(%nick) != $null,1,0)
    elseif ($pos(%p,!)) || ($pos(%p,@)) %hit = $iif(%p iswm %addr,1,0)
    else %hit = $iif(%p iswm %nick,1,0)
    if (%neg) {
      if (%hit) return 0
    }
    else {
      %any = 1
      if (%hit) %ok = 1
    }
  }
  if (!%any) return 1
  return %ok
}
; does rule <id> apply to the event in ns.actx?
alias ns.auto.test {
  var %id = $1, %g = $+(%id,.)
  if ($hget(ns.actx,nick) == $me) return 0
  if (!$ns.auto.wild($hget(ns.arules,$+(%g,net)),$hget(ns.actx,net))) return 0
  if ($hget(ns.actx,window) != -) && ($left($hget(ns.actx,window),1) isin $chantypes) && (!$ns.auto.wild($hget(ns.arules,$+(%g,chan)),$hget(ns.actx,window))) return 0
  if (!$ns.auto.who($hget(ns.arules,$+(%g,from)))) return 0
  if (!$ns.auto.tmatch($hget(ns.arules,$+(%g,match)),$hget(ns.actx,text))) return 0
  var %aw = $hget(ns.arules,$+(%g,away))
  if (%aw == away) && (!$away) return 0
  if (%aw == present) && ($away) return 0
  var %ch = $hget(ns.arules,$+(%g,chance))
  if (%ch isnum) && (%ch > 0) && (%ch < 100) && ($rand(1,100) > %ch) return 0
  if (%ch == 0) return 0
  ; cool-down per rule + conversation + person
  var %cool = $hget(ns.arules,$+(%g,cool)), %key = $+(%id,.,$cid,.,$lower($hget(ns.actx,window)),.,$lower($hget(ns.actx,nick)))
  if (%cool !isnum) %cool = 5
  if (%cool > 0) {
    if ($hget(ns.acool,%key)) return 0
    hadd -mu $+ %cool ns.acool %key 1
  }
  return 1
}

; ---------------------------------------------------------------- doing it
alias ns.auto.log {
  var %n = $calc($hget(ns.alog,n) + 1)
  hadd -m ns.alog n %n
  hadd ns.alog %n $+($asctime(HH:nn:ss),$chr(32),$1-)
  if (%n > 100) hdel ns.alog $calc(%n - 100)
}
; fill the {tokens} of one action line with data from the event
alias ns.auto.expand {
  var %a = $1-, %t = $hget(ns.actx,text), %i = 1, %m, %lb = $chr(123), %rb = $chr(125)
  %a = $replace(%a,{nick},$hget(ns.actx,nick),{chan},$hget(ns.actx,window),{window},$hget(ns.actx,window),{text},%t,{me},$me,{net},$hget(ns.actx,net),{newnick},$hget(ns.actx,newnick),{knick},$hget(ns.actx,knick),{reason},$hget(ns.actx,reason),{time},$asctime(HH:nn),{date},$asctime(ddd d mmm yyyy),{addr},$hget(ns.actx,addr))
  while (%i <= 9) {
    %a = $replace(%a,$+(%lb,%i,-,%rb),$gettok(%t,$+(%i,-),32),$+(%lb,%i,%rb),$gettok(%t,%i,32))
    inc %i
  }
  ; {pick:a;b;c} - one of them at random
  while ($regex(ns.apk,%a,/\x7Bpick:([^\x7D]*)\x7D/)) {
    %m = $regml(ns.apk,1)
    %a = $replace(%a,$+(%lb,pick:,%m,%rb),$gettok(%m,$rand(1,$numtok(%m,59)),59))
  }
  return %a
}
; breaker + run
alias ns.auto.fire {
  var %id = $1, %i = 1, %line, %verb, %arg, %delay = 0, %w = $hget(ns.actx,window), %nick = $hget(ns.actx,nick), %cid = $hget(ns.actx,cid), %cmd, %dry = $iif($2 == dry,1,0), %tag = rule
  if (!%dry) {
    hinc -mu60 ns.afire all
    if ($hget(ns.afire,all) > 40) {
      set -u300 %ns.auto.paused 1
      ns.say automation rules paused for 5 minutes - they fired more than 40 times in a minute. Check /neon rules.
      ns.auto.log BREAKER: rules paused for 5 minutes
      return
    }
  }
  ns.auto.log $+($hget(ns.arules,$+(%id,.name)),$chr(32),$chr(40),$hget(ns.actx,type),$chr(41),$chr(32),$hget(ns.actx,nick),$iif(%w != -,$chr(32) $+ in %w),$iif(%dry,$chr(32) $+ [test]))
  while ($hget(ns.arules,$+(%id,.a,%i)) != $null) {
    %line = $ns.auto.expand($hget(ns.arules,$+(%id,.a,%i)))
    inc %i
    %verb = $lower($gettok(%line,1,32))
    %arg = $gettok(%line,2-,32)
    %cmd = $null
    if (%verb == stop) break
    if (%verb == wait) {
      if ($ns.mod.secs(%arg) > 0) inc %delay $ns.mod.secs(%arg)
      continue
    }
    if (%verb == say) %cmd = msg %w %arg
    elseif (%verb == reply) %cmd = msg %w $iif($left(%w,1) isin $chantypes,$+(%nick,$chr(58),$chr(32))) $+ %arg
    elseif (%verb == msg) %cmd = msg $gettok(%arg,1,32) $gettok(%arg,2-,32)
    elseif (%verb == notice) %cmd = notice $gettok(%arg,1,32) $gettok(%arg,2-,32)
    elseif (%verb == action) %cmd = describe %w %arg
    elseif (%verb == echo) %cmd = echo -c info %w %arg
    elseif (%verb == kick) %cmd = ns.auto.kick %w $iif($gettok(%arg,1,32) != $null,$gettok(%arg,1,32),%nick) $gettok(%arg,2-,32)
    elseif (%verb == ban) %cmd = ns.auto.ban %w $iif(%arg != $null,%arg,%nick)
    elseif (%verb == kickban) %cmd = ns.auto.kickban %w $iif($gettok(%arg,1,32) != $null,$gettok(%arg,1,32),%nick) $gettok(%arg,2-,32)
    elseif (%verb == quiet) %cmd = ns.auto.quiet %w $iif($gettok(%arg,1,32) != $null,$gettok(%arg,1,32),%nick) $gettok(%arg,2-,32)
    elseif (%verb == voice) %cmd = ns.auto.priv %w + v $iif(%arg != $null,%arg,%nick)
    elseif (%verb == devoice) %cmd = ns.auto.priv %w - v $iif(%arg != $null,%arg,%nick)
    elseif (%verb == mode) %cmd = ns.auto.mode %w %arg
    elseif (%verb == join) %cmd = join %arg
    elseif (%verb == part) %cmd = part $iif(%arg != $null,%arg,%w)
    elseif (%verb == away) %cmd = away %arg
    elseif (%verb == back) %cmd = away
    elseif (%verb == ignore) %cmd = ns.auto.ignore $iif($gettok(%arg,1,32) != $null,$gettok(%arg,1,32),%nick) $gettok(%arg,2-,32)
    elseif (%verb == toast) %cmd = ns.auto.toast %arg
    elseif (%verb == speak) %cmd = ns.auto.speak %arg
    elseif (%verb == sound) %cmd = ns.auto.sound %arg
    elseif (%verb == flash) %cmd = flash %arg
    elseif (%verb == log) %cmd = ns.auto.note %arg
    elseif (%verb == cmd) %cmd = $hget(ns.arules,$+(%id,.a,$calc(%i - 1)))
    else {
      ns.auto.log unknown action $qt(%verb) in rule $hget(ns.arules,$+(%id,.name))
      continue
    }
    if (%cmd == $null) continue
    if (%dry) {
      echo -a $+($ns.pfx,$chr(32),$ns.ec(dim),would run:,$ns.o,$chr(32),$iif(%delay,after $+(%delay,s:)),$chr(32),%cmd)
      continue
    }
    if (%delay > 0) .timer -o 1 %delay scid %cid ns.mq.add %w $+(rule:,%id) %cmd
    else scid %cid ns.mq.add %w $+(rule:,%id) %cmd
  }
}

; ---- actions that need a safety check first (they run inside the connection the event came from) ----
alias ns.auto.kick {
  var %c = $1, %n = $2, %why = $3-
  if (!$ns.ischan(%c)) || (!$nick(%c,%n)) return
  if (!$ns.rk.cankick(%c)) || ($ns.acc.safe(%n,%c)) || ($ns.rk.outranks(%c,%n,$me)) return
  kick %c %n $iif(%why != $null,%why,$ns.msg(kick))
}
alias ns.auto.ban {
  var %c = $1, %n = $2
  if (!$ns.ischan(%c)) || (!$ns.rk.cankick(%c)) return
  if ($nick(%c,%n)) && (($ns.acc.safe(%n,%c)) || ($ns.rk.outranks(%c,%n,$me))) return
  ban %c %n $ns.get(kb,bantype,2)
}
alias ns.auto.kickban {
  var %c = $1, %n = $2, %why = $3-
  if (!$ns.ischan(%c)) || (!$nick(%c,%n)) return
  if (!$ns.rk.cankick(%c)) || ($ns.acc.safe(%n,%c)) || ($ns.rk.outranks(%c,%n,$me)) return
  ban -k %c %n $ns.get(kb,bantype,2) $iif(%why != $null,%why,$ns.msg(kick))
}
alias ns.auto.quiet {
  var %secs = $ns.mod.secs($3)
  ns.mute.do $1 $2 %secs $iif(%secs > 0,$4-,$3-)
}
alias ns.auto.priv {
  var %c = $1, %s = $2, %l = $3, %n = $4
  if (!$ns.ischan(%c)) || (!$nick(%c,%n)) || (!$ns.rk.cangive(%c,%l)) return
  if (%s == +) && ($ns.rk.of(%c,%n)) return
  mode %c $+(%s,%l) %n
}
alias ns.auto.mode {
  var %c = $1
  if (!$ns.ischan(%c)) || (!$ns.rk.cankick(%c)) return
  mode %c $2-
}
alias ns.auto.ignore {
  var %secs = $ns.ig.secs($2)
  if (%secs < 0) %secs = 0
  ns.ig.add $ns.ig.maskfor($1) pcnti all %secs added by a rule
}
alias ns.auto.toast {
  if ($isalias(ns.win.start)) {
    ns.win.start
    ns.win.new
    ns.win.set id $r(1000,999999)
    ns.win.set title NeonScript rule
    ns.win.set body $1-
    ns.win.set key 0
    ns.win.go toast
  }
}
alias ns.auto.speak {
  if ($isalias(ns.win.start)) {
    ns.win.start
    ns.win.new
    ns.win.set text $left($1-,200)
    ns.win.set voice $ns.get(speak,voice)
    ns.win.set rate $ns.get(speak,rate,0)
    ns.win.go speak
  }
}
alias ns.auto.sound {
  if ($exists($1-)) splay -w $qt($1-)
  elseif ($isalias(ns.snd)) ns.snd $1
}
alias ns.auto.note ns.log rule $1-

; ---------------------------------------------------------------- the editor
alias neon.rules ns.dlg ns_rules ns_rules
alias neon.rule {
  ; /neon rule on|off <name>   /neon rule log   /neon rule resume
  var %c = $lower($1), %i = 1, %id, %n = 0
  if (%c == log) {
    var %k = $max(1,$calc($hget(ns.alog,n) - 19))
    while (%k <= $hget(ns.alog,n)) {
      ns.say rule log: $hget(ns.alog,%k)
      inc %k
    }
    if (!$hget(ns.alog,n)) ns.say no rule has fired yet.
    return
  }
  if (%c == resume) {
    unset %ns.auto.paused
    hdel ns.afire all
    ns.say rules resumed.
    return
  }
  if (%c == on) || (%c == off) {
    while ($gettok($ns.auto.ids,%i,32) != $null) {
      %id = $v1
      inc %i
      if ($ns.auto.rd(%id,name) == $2-) {
        ns.auto.wr %id on $iif(%c == on,1,0)
        inc %n
      }
    }
    ns.auto.load
    ns.say %n rule(s) switched %c $+ .
    return
  }
  ns.err usage: /neon rule on <name>, off <name>, log or resume   (/neon rules opens the editor)
}

dialog ns_rules {
  title "Automation Rules"
  size -1 -1 372 262
  option dbu
  icon 1, 0 0 372 30, $mircexe, 0, noborder
  text "Tick a rule to switch it on.", 2, 6 36 108 9
  list 3, 6 46 108 128, check size vsbar
  button "New", 4, 6 178 34 12
  button "Copy", 5, 44 178 34 12
  button "Delete", 6, 82 178 32 12
  text "Start from:", 7, 6 196 36 9
  combo 8, 6 206 108 80, drop
  text "Name:", 10, 122 38 24 9
  edit "", 11, 148 36 110 11, autohs
  text "When:", 12, 264 38 22 9
  combo 13, 288 36 78 90, drop
  text "Network:", 14, 122 54 28 9
  edit "", 15, 152 52 60 11, autohs
  text "Channels:", 16, 218 54 30 9
  edit "", 17, 250 52 116 11, autohs
  text "From:", 18, 122 70 22 9
  edit "", 19, 148 68 218 11, autohs
  text "Text matches:", 20, 122 86 44 9
  edit "", 21, 168 84 198 11, autohs
  text "Cool-down:", 22, 122 102 34 9
  edit "", 23, 158 100 22 11, autohs limit 4
  text "s", 24, 182 102 8 9
  text "Only:", 25, 196 102 20 9
  combo 26, 218 100 62 60, drop
  text "Chance:", 27, 286 102 26 9
  edit "", 28, 314 100 22 11, autohs limit 3
  text "%", 29, 338 102 8 9
  text "Actions - one per line (say, reply, msg, notice, action, echo, kick, ban, kickban, quiet, voice, mode, join, part, away, ignore, toast, speak, sound, wait, stop, log, cmd):", 30, 122 116 244 18
  edit "", 31, 122 136 244 62, multi return vsbar
  text "Fill-ins: {nick} {chan} {text} {1} {2} {2-} {me} {net} {time} {date} {newnick} {knick} {reason} {pick:a;b;c}.  Text matches and From take comma separated wildcards (From also: ops voice norank userlist, !ops ...).", 32, 122 200 244 27
  button "Save", 33, 122 232 44 13
  button "Test", 34, 170 232 44 13
  button "Show log", 35, 218 232 44 13
  text "", 36, 6 232 112 18
  button "Close", 37, 318 232 48 13, ok cancel
}
on *:DIALOG:ns_rules:init:*:{
  did -g ns_rules 1 $ns.asset(header_rules.png)
  var %i = 1
  while ($gettok($ns.auto.triggers,%i,32) != $null) {
    did -a ns_rules 13 $gettok($ns.auto.triggers,%i,32)
    inc %i
  }
  did -a ns_rules 26 anyone
  did -a ns_rules 26 while away
  did -a ns_rules 26 while here
  did -a ns_rules 8 (blank rule)
  %i = 1
  while ($gettok($ns.auto.tplnames,%i,124) != $null) {
    did -a ns_rules 8 $gettok($ns.auto.tplnames,%i,124)
    inc %i
  }
  did -c ns_rules 8 1
  rfill
  if ($did(ns_rules,3).lines) {
    did -c ns_rules 3 1
    rpick 1
  }
  else rblank
}
alias -l rfill {
  var %i = 1, %id, %n = 0
  did -r ns_rules 3
  while ($gettok($ns.auto.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    did -a ns_rules 3 $iif($ns.auto.rd(%id,name) != $null,$ns.auto.rd(%id,name),%id)
    inc %n
    if ($ns.auto.rd(%id,on) == 1) did -s ns_rules 3 %n
  }
}
; the id behind a list line
alias -l rid return $gettok($ns.auto.ids,$1,32)
alias -l rblank {
  did -r ns_rules 11
  did -c ns_rules 13 1
  did -r ns_rules 15
  did -r ns_rules 17
  did -r ns_rules 19
  did -r ns_rules 21
  did -ra ns_rules 23 5
  did -c ns_rules 26 1
  did -ra ns_rules 28 100
  did -r ns_rules 31
  did -ra ns_rules 11 New rule
}
alias -l rpick {
  var %id = $rid($1), %n = 1, %v, %t
  if (!%id) return
  did -c ns_rules 3 $1
  did -ra ns_rules 11 $ns.auto.rd(%id,name)
  %t = $findtok($ns.auto.triggers,$ns.auto.rd(%id,trig),1,32)
  did -c ns_rules 13 $iif(%t,%t,1)
  did -ra ns_rules 15 $iif($ns.auto.rd(%id,net) != $null,$ns.auto.rd(%id,net),*)
  did -ra ns_rules 17 $iif($ns.auto.rd(%id,chan) != $null,$ns.auto.rd(%id,chan),*)
  did -ra ns_rules 19 $ns.auto.rd(%id,from)
  did -ra ns_rules 21 $ns.auto.rd(%id,match)
  did -ra ns_rules 23 $iif($ns.auto.rd(%id,cool) isnum,$ns.auto.rd(%id,cool),5)
  did -c ns_rules 26 $iif($ns.auto.rd(%id,away) == away,2,$iif($ns.auto.rd(%id,away) == present,3,1))
  did -ra ns_rules 28 $iif($ns.auto.rd(%id,chance) isnum,$ns.auto.rd(%id,chance),100)
  ns.ml.new
  %v = $ns.auto.rd(%id,a1)
  while (%v != $null) {
    ns.ml.add %v
    inc %n
    %v = $ns.auto.rd(%id,$+(a,%n))
  }
  ns.ml.set ns_rules 31
  did -ra ns_rules 36 $chr(160)
}
on *:DIALOG:ns_rules:sclick:4:{
  set -u600 %ns.rules.new 1
  rblank
  did -ra ns_rules 36 New rule - fill it in and press Save.
}
; save the editor into the selected rule (a new rule when nothing matches the name / "New rule")
alias -l rsave {
  var %sel = $did(ns_rules,3).sel, %id = $rid(%sel), %k = 1, %n = 0, %line, %aw = $did(ns_rules,26).sel
  if (%ns.rules.new) %id = $null
  unset %ns.rules.new
  if ($did(ns_rules,11).text == $null) {
    did -ra ns_rules 36 Give the rule a name first.
    return 0
  }
  if (!%id) %id = $ns.auto.newid
  if ($ini($ns.auto.ini,%id)) remini $qt($ns.auto.ini) %id
  ns.auto.wr %id name $did(ns_rules,11).text
  ns.auto.wr %id on $iif($ns.auto.rd(%id,on) == 0,0,1)
  ns.auto.wr %id trig $did(ns_rules,13).text
  ns.auto.wr %id net $did(ns_rules,15).text
  ns.auto.wr %id chan $did(ns_rules,17).text
  ns.auto.wr %id from $did(ns_rules,19).text
  ns.auto.wr %id match $did(ns_rules,21).text
  ns.auto.wr %id cool $iif($did(ns_rules,23).text isnum,$did(ns_rules,23).text,5)
  ns.auto.wr %id away $gettok(any away present,%aw,32)
  ns.auto.wr %id chance $iif($did(ns_rules,28).text isnum,$did(ns_rules,28).text,100)
  while (%k <= $did(ns_rules,31).lines) {
    %line = $did(ns_rules,31,%k)
    inc %k
    if (%line == $null) continue
    inc %n
    ns.auto.wr %id $+(a,%n) %line
  }
  ns.auto.load
  rfill
  %k = $findtok($ns.auto.ids,%id,1,32)
  if (%k) did -c ns_rules 3 %k
  return 1
}
on *:DIALOG:ns_rules:sclick:33:{
  if ($rsave) did -ra ns_rules 36 Saved.
}
; ticking a rule switches it on or off straight away
on *:DIALOG:ns_rules:sclick:3:{
  var %i = 1, %n = $did(ns_rules,3).lines, %id
  while (%i <= %n) {
    %id = $rid(%i)
    if (%id) && ($ns.auto.rd(%id,on) != $did(ns_rules,3,%i).cstate) ns.auto.wr %id on $did(ns_rules,3,%i).cstate
    inc %i
  }
  ns.auto.load
  unset %ns.rules.new
  if ($did(ns_rules,3).sel) rpick $did(ns_rules,3).sel
}
on *:DIALOG:ns_rules:sclick:5:{
  var %id = $rid($did(ns_rules,3).sel), %new, %f, %k = 1, %n = 1
  if (!%id) return
  %new = $ns.auto.newid
  while ($gettok($ns.auto.fields,%k,32) != $null) {
    %f = $gettok($ns.auto.fields,%k,32)
    inc %k
    ns.auto.wr %new %f $ns.auto.rd(%id,%f)
  }
  ns.auto.wr %new name $+($ns.auto.rd(%id,name),$chr(32),copy)
  ns.auto.wr %new on 0
  while ($ns.auto.rd(%id,$+(a,%n)) != $null) {
    ns.auto.wr %new $+(a,%n) $ns.auto.rd(%id,$+(a,%n))
    inc %n
  }
  ns.auto.load
  rfill
  did -c ns_rules 3 $findtok($ns.auto.ids,%new,1,32)
  rpick $findtok($ns.auto.ids,%new,1,32)
}
on *:DIALOG:ns_rules:sclick:6:{
  var %id = $rid($did(ns_rules,3).sel)
  if (!%id) return
  remini $qt($ns.auto.ini) %id
  ns.auto.load
  rfill
  if ($did(ns_rules,3).lines) {
    did -c ns_rules 3 1
    rpick 1
  }
  else rblank
  did -ra ns_rules 36 Deleted.
}
; a dry run: shows the commands the rule would send (nothing is sent) for an imagined event
on *:DIALOG:ns_rules:sclick:34:{
  if (!$rsave) return
  var %id = $rid($did(ns_rules,3).sel), %t = $did(ns_rules,13).text, %w = $iif($ns.ischan($active),$active,$iif($query($active),$active,#test))
  ns.auto.begin %t %w TestUser $iif($gettok($did(ns_rules,21).text,1,44) != $null && $left($did(ns_rules,21).text,3) != re:,$replace($gettok($did(ns_rules,21).text,1,44),*,$null) hello there,hello there)
  ns.auto.ctx knick TestVictim
  ns.auto.ctx reason test reason
  ns.auto.ctx newnick TestUser2
  ns.auto.fire %id dry
  did -ra ns_rules 36 Dry run done - see the active window. Nothing was sent.
}
on *:DIALOG:ns_rules:sclick:35:{ neon rule log }
on *:DIALOG:ns_rules:sclick:8:{
  var %s = $did(ns_rules,8).sel
  if (%s < 2) return
  ns.auto.tplfill $gettok($ns.auto.tplnames,$calc(%s - 1),124)
  did -c ns_rules 8 1
}

; ---------------------------------------------------------------- starter templates
alias ns.auto.tplnames return Away auto-reply|Greet people who join|Answer !help|Thank people|Warn about a word|Highlight alert
alias ns.auto.tplfill {
  var %t = $1-
  did -c ns_rules 26 1
  did -ra ns_rules 15 *
  did -ra ns_rules 17 *
  did -r ns_rules 19
  did -r ns_rules 21
  did -ra ns_rules 23 600
  did -ra ns_rules 28 100
  if (%t == Away auto-reply) {
    did -ra ns_rules 11 Away auto-reply
    did -c ns_rules 13 $findtok($ns.auto.triggers,pm,1,32)
    did -c ns_rules 26 2
    did -ra ns_rules 31 I'm away right now ({time}) - I'll answer when I'm back.
  }
  elseif (%t == Greet people who join) {
    did -ra ns_rules 11 Greeting
    did -c ns_rules 13 $findtok($ns.auto.triggers,join,1,32)
    did -ra ns_rules 17 #yourchannel
    did -ra ns_rules 23 30
    did -ra ns_rules 31 notice {nick} Welcome to {chan}, {nick}!
  }
  elseif (%t == Answer !help) {
    did -ra ns_rules 11 Answer !help
    did -c ns_rules 13 $findtok($ns.auto.triggers,text,1,32)
    did -ra ns_rules 21 !help
    did -ra ns_rules 23 30
    did -ra ns_rules 31 reply Ask in the channel and someone will help - or read the topic.
  }
  elseif (%t == Thank people) {
    did -ra ns_rules 11 You're welcome
    did -c ns_rules 13 $findtok($ns.auto.triggers,text,1,32)
    did -ra ns_rules 21 thanks bot,thank you bot
    did -ra ns_rules 23 20
    did -ra ns_rules 31 reply {pick:you're welcome!;anytime!;no problem}
  }
  elseif (%t == Warn about a word) {
    did -ra ns_rules 11 Warn about a word
    did -c ns_rules 13 $findtok($ns.auto.triggers,text,1,32)
    did -ra ns_rules 19 !ops,!voice
    did -ra ns_rules 21 badword
    did -ra ns_rules 23 30
    did -ra ns_rules 31 notice {nick} Please watch your language.
  }
  elseif (%t == Highlight alert) {
    did -ra ns_rules 11 Highlight alert
    did -c ns_rules 13 $findtok($ns.auto.triggers,mention,1,32)
    did -c ns_rules 26 2
    did -ra ns_rules 23 60
    did -ra ns_rules 31 toast {nick} in {chan}: {text}
  }
  did -ra ns_rules 36 Template filled in - press Save to keep it.
}
