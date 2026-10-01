; ============================================================================
;  NeonScript 2026  ::  fun commands, channel commands (!roll !seen !ops ...)
;  and the seen database.
;  /weather and /define call public web APIs only when YOU run them.
; ============================================================================

; reply to whatever window is active (channel/query: say it, otherwise just show it)
alias -l out {
  if ($ns.ischan($active)) || ($query($active)) msg $active $1-
  else echo -cat info $ns.pfx $1-
}

; ---------------------------------------------------------------- fun commands
alias 8ball {
  var %a = It is certain;Without a doubt;Yes, definitely;Most likely;Outlook good;Signs point to yes;Reply hazy, try again;Ask again later;Better not tell you now;Cannot predict now;Don't count on it;My reply is no;Outlook not so good;Very doubtful
  out $iif($1-,$+($chr(34),$1-,$chr(34),$chr(32),$chr(8594),$chr(32))) $+ $gettok(%a,$rand(1,14),59)
}
alias coin out $+($chr(40),flips a coin,$chr(41),$chr(32)) $+ $iif($rand(0,1),Heads,Tails)
alias roll out $ns.roll($1)
; $ns.roll(2d6) -> "rolled 2d6: 3 + 5 = 8"
alias ns.roll {
  var %n = 1, %m = 6, %i, %sum = 0, %parts
  if ($regex($1,/^(\d{1,2})d(\d{1,4})$/i)) {
    %n = $regml(1)
    %m = $regml(2)
  }
  elseif ($1 isnum) %m = $1
  if (%n < 1) || (%m < 2) return rolled nothing (try 2d6 or 1d20)
  %i = 1
  while (%i <= %n) {
    var %r = $rand(1,%m)
    %sum = $calc(%sum + %r)
    if (%parts == $null) %parts = %r
    else %parts = $+(%parts,$chr(32),$chr(183),$chr(32),%r)
    inc %i
  }
  return rolled $+(%n,d,%m) $+ : %parts $iif(%n > 1,= %sum)
}
; /choose pizza or tacos or sushi
alias choose {
  if (!$1-) { ns.err usage: /choose pizza or tacos or sushi | return }
  var %t = $replace($1-,$chr(32) $+ or $+ $chr(32),$chr(1)), %n = $numtok(%t,1)
  out $+(I choose:,$chr(32),$chr(2),$gettok(%t,$rand(1,%n),1),$chr(2))
}
alias slap {
  var %t = $iif($1,$1,$snick($active,1)), %l = $ns.msg(slap)
  if (!%t) { ns.err usage: /slap <nick> | return }
  if (%l == $null) %l = slaps $+($chr(37),t) around a bit with a large trout
  var %line = $replace(%l,$+($chr(37),t),%t)
  if ($ns.ischan($active)) || ($query($active)) describe $active %line
  else ns.err open a channel or query window first.
}
alias calc {
  if (!$1-) { ns.err usage: /calc 12 * (3 + 4) | return }
  echo -cat info $ns.pfx $1- $+ $chr(32) $+ $chr(61) $+ $chr(32) $+ $ns.b $+ $calc($1-) $+ $ns.b
}
alias uptime echo -cat info $ns.pfx mIRC $duration($uptime(mirc,3)) $+ , system $duration($uptime(system,3)) $+ $iif($status == connected,$chr(44) connection $duration($uptime(server,3)))

; ---------------------------------------------------------------- web lookups (explicit commands only)
alias weather {
  var %say = 0, %city = $1-
  if ($1 == -s) {
    %say = 1
    %city = $2-
  }
  if (!%city) {
    ns.err usage: /weather [-s] <city>   (-s says the result in the window)
    return
  }
  set -u30 %ns.weather.say %say
  set -u30 %ns.weather.win $active
  if (!$urlget($+(https://wttr.in/,$replace(%city,$chr(32),+),?format=3),gf,$ns.data(weather.tmp),ns.weather.done)) ns.err could not start the request.
}
alias ns.weather.done {
  var %f = $urlget($1).target, %t
  if ($urlget($1).reply != 200) && ($urlget($1).reply != $null) {
    ns.err weather service replied $urlget($1).reply
    return
  }
  %t = $read(%f,n,1)
  if (!%t) { ns.err no weather found. | return }
  if (%ns.weather.say) && (%ns.weather.win) msg %ns.weather.win %t
  else echo -cat info $ns.pfx %t
}
alias define {
  if (!$1) { ns.err usage: /define <word> | return }
  set -u30 %ns.define.word $1
  if (!$urlget($+(https://api.dictionaryapi.dev/api/v2/entries/en/,$1),gf,$ns.data(define.tmp),ns.define.done)) ns.err could not start the request.
}
alias ns.define.done {
  var %f = $urlget($1).target, %t, %def, %pos
  if (!$exists(%f)) { ns.err no definition found. | return }
  bread $qt(%f) 0 6000 &nsdef
  %t = $bvar(&nsdef,1,$bvar(&nsdef,0)).text
  %pos = $regex(%t,/"partOfSpeech":"([^"]+)".*?"definition":"([^"]+)"/)
  if (!%pos) {
    ns.err no definition found for %ns.define.word $+ .
    return
  }
  echo -cat info $ns.pfx $+($ns.b,%ns.define.word,$ns.b,$chr(32),$ns.ec(dim),$chr(40),$regml(1),$chr(41),$ns.o,$chr(32)) $+ $regml(2)
}

; ---------------------------------------------------------------- seen database
alias ns.seen.file return $ns.data(seen.dat)
alias ns.seen.set {
  ; ns.seen.set <nick> <chan> <what...>
  if ($hget(ns.seen) == $null) hmake ns.seen 500
  hadd -m ns.seen $lower($1) $iif($msgstamp,$msgstamp,$ctime) $+ $chr(9) $+ $2 $+ $chr(9) $+ $left($3-,80)
}
alias ns.seen.save { if ($hget(ns.seen)) hsave -o ns.seen $qt($ns.seen.file) }
alias ns.seen.load {
  if ($hget(ns.seen) == $null) hmake ns.seen 500
  if ($exists($ns.seen.file)) hload ns.seen $qt($ns.seen.file)
}
on *:SIGNAL:ns.boot:{
  ns.seen.load
  .timer.nsseen 0 300 ns.seen.save
}
on *:SIGNAL:ns.exit:{ ns.seen.save }
on *:TEXT:*:#:{
  ns.seen.set $nick $chan saying: $1-
  if ($left($1,1) == !) ns.bot.run $chan $nick $1-
}
on *:ACTION:*:#:{ ns.seen.set $nick $chan doing: $1- }
on *:JOIN:#:{ ns.seen.set $nick $chan joining }
on *:PART:#:{ ns.seen.set $nick $chan leaving ( $+ $1- $+ ) }
on *:QUIT:{ ns.seen.set $nick - quitting ( $+ $1- $+ ) }
on *:NICK:{ ns.seen.set $nick - changing nick to $newnick }
alias ns.seen.say {
  var %v = $hget(ns.seen,$lower($1))
  if (%v == $null) return I have not seen $1 yet.
  var %when = $duration($calc($ctime - $gettok(%v,1,9)))
  var %w = $gettok(%v,2,9)
  return $1 was last seen %when ago $iif(%w != -,in %w $+ $chr(44)) $gettok(%v,3,9)
}

; ---------------------------------------------------------------- channel commands
alias ns.bot.allowed {
  var %l = $ns.get(bot,channels,*), %k = 1
  if (%l == *) return 1
  while ($gettok(%l,%k,44)) {
    if ($v1 iswm $1) return 1
    inc %k
  }
  return 0
}
alias ns.bot.reply {
  ; ns.bot.reply <chan> <nick> <text...>
  if ($ns.flag(bot,notice,0)) notice $2 $3-
  else msg $1 $3-
}
; rank summary for !ops  ->  "~ owner Nova | & admin ... "
alias ns.bot.ops {
  var %c = $1, %i = 1, %n = $nick(%c,0), %o, %l, %ch, %list, %k
  var %letters = qaohv, %pm = $ns.rk.modes
  %k = 1
  while (%k <= 5) {
    %l = $mid(qaohv,%k,1)
    if ($pos(%pm,%l)) {
      %ch = $ns.rk.char(%l)
      %list = $null
      %i = 1
      while (%i <= %n) {
        if ($ns.rk.of(%c,$nick(%c,%i)) == %ch) %list = %list $nick(%c,%i)
        inc %i
      }
      if (%list) %o = %o $+ $iif(%o,$chr(32) $+ $chr(124) $+ $chr(32)) $+ %ch $+ $ns.rk.lname(%l) $+ $chr(58) $+ $chr(32) $+ $replace($ns.trim(%list),$chr(32),$chr(44) $+ $chr(32))
    }
    inc %k
  }
  return $iif(%o,%o,nobody has special privileges here.)
}
alias ns.bot.run {
  ; ns.bot.run <chan> <nick> <text...>  - called from the TEXT handler above
  if ($ns.bnc.q) return
  if (!$ns.flag(bot,enabled,0)) return
  var %chan = $1, %nick = $2
  if (!$ns.bot.allowed(%chan)) return
  if (%nick == $me) return
  if ($hget(ns.botcd,$+($cid,.,%nick))) return
  tokenize 32 $3-
  var %cmd = $lower($1)
  if (!$findtok(!roll !8ball !coin !time !uptime !help !seen !ops !rank,%cmd,1,32)) return
  hadd -mu $+ $ns.get(bot,cooldown,5) ns.botcd $+($cid,.,$nick) 1
  if (%cmd == !roll) ns.bot.reply $chan $nick $nick $+ : $ns.roll($2)
  elseif (%cmd == !8ball) ns.bot.reply $chan $nick $nick $+ : $gettok(Yes.;No.;Maybe.;Ask again later.;Definitely.;Not a chance.;Signs point to yes.;Very doubtful.,$rand(1,8),59)
  elseif (%cmd == !coin) ns.bot.reply $chan $nick $nick $+ : $iif($rand(0,1),Heads,Tails)
  elseif (%cmd == !time) ns.bot.reply $chan $nick It is $asctime(ddd d mmm yyyy HH:nn) (bot local time).
  elseif (%cmd == !uptime) ns.bot.reply $chan $nick I have been running for $duration($uptime(mirc,3)) $+ .
  elseif (%cmd == !help) ns.bot.reply $chan $nick Commands: !roll [NdM] !8ball !coin !time !uptime !seen <nick> !ops !rank <nick>
  elseif (%cmd == !seen) {
    if (!$2) ns.bot.reply $chan $nick usage: !seen <nick>
    elseif ($2 == $nick) ns.bot.reply $chan $nick Looking good, $nick $+ !
    elseif ($2 ison $chan) ns.bot.reply $chan $nick $2 is right here.
    else ns.bot.reply $chan $nick $ns.seen.say($2)
  }
  elseif (%cmd == !ops) ns.bot.reply $chan $nick $ns.bot.ops($chan)
  elseif (%cmd == !rank) {
    var %t = $iif($2,$2,$nick), %r = $ns.rk.of($chan,%t)
    if (!%t ison $chan) ns.bot.reply $chan $nick %t is not on $chan $+ .
    elseif (%r) ns.bot.reply $chan $nick %t holds $+($ns.rk.name(%r),$chr(32),$chr(40),%r,$chr(41)) in $chan $+ .
    else ns.bot.reply $chan $nick %t has no special privileges in $chan $+ .
  }
}
