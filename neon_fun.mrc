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
; /weather, /define and /translate send what you typed to a public web service, and only when you run them:
;   weather   wttr.in            the city name
;   define    dictionaryapi.dev  the word
;   translate api.mymemory.translated.net   the text (free service, small daily limit)
; Results appear as a "card" in the window you ran it in; with -s they are said in the channel as one line instead.
; (The service addresses can be changed in neon.ini [web]: weather_base, define_base, translate_base.)

; a framed card:  ns.card <title> <line> <line> ...   (lines separated by chr(1) in $2-)
alias ns.card {
  ; $1- = title chr(1) line chr(1) line ...
  var %t = $gettok($1-,1,1), %lines = $gettok($1-,2-,1), %i = 1, %a = $ns.cc($ns.get(theme,accent,13)), %o = $ns.o, %n = $numtok(%lines,1)
  echo -cat info $+(%a,$chr(9484),$chr(9472),$chr(9472),$chr(32),$ns.b,%t,$ns.b,$chr(32),$str($chr(9472),$max(2,$calc(34 - $len(%t)))),%o)
  while (%i <= %n) {
    echo -cat info $+(%a,$chr(9474),%o,$chr(32),$gettok(%lines,%i,1))
    inc %i
  }
  echo -cat info $+(%a,$chr(9492),$str($chr(9472),36),%o)
}
; percent-encode text for a URL (UTF-8)
alias ns.urlenc {
  var %t = $utfencode($1-), %i = 1, %o, %c
  while (%i <= $len(%t)) {
    %c = $mid(%t,%i,1)
    inc %i
    if ($regex(ns.ue,%c,/^[A-Za-z0-9\-_.~]$/)) %o = %o $+ %c
    else %o = %o $+ $chr(37) $+ $base($asc(%c),10,16,2)
  }
  return %o
}
; JSON string escapes -> text
alias ns.json.unesc {
  var %t = $1-
  %t = $regsubex(%t,/\\u([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])/g,$chr($base(\1,16,10)))
  %t = $replace(%t,\",",\n,$chr(32),\/,/,\\,\)
  return %t
}
; the HTTP status code of a finished $urlget transfer ($urlget().reply is the whole status line)
alias ns.web.status return $gettok($gettok($urlget($1).reply,1,10),2,32)
alias ns.web.read {
  var %f = $1, %sz = $file(%f).size
  if (!%sz) return $null
  if (%sz > 20000) %sz = 20000
  bread $qt(%f) 0 %sz &nsweb
  return $bvar(&nsweb,1,%sz).text
}
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
  set -u30 %ns.weather.city %city
  if (!$urlget($+($ns.get(web,weather_base,https://wttr.in/),$ns.urlenc(%city),$+(?format=,$replace(@l@7C@C@7C@t@7C@f@7C@h@7C@w,@,$chr(37)))),gf,$ns.data(weather.tmp),ns.weather.done)) ns.err could not start the request.
}
alias ns.weather.done {
  var %f = $urlget($1).target, %t
  if ($ns.web.status($1) != 200) {
    ns.err the weather service answered $ns.web.status($1) $+ .
    return
  }
  %t = $ns.web.read(%f)
  %t = $gettok($remove(%t,$cr,$lf),1,10)
  if (%t == $null) || ($numtok(%t,124) < 6) {
    ns.err no weather found for %ns.weather.city $+ .
    return
  }
  if (%ns.weather.say) && (%ns.weather.win) {
    msg %ns.weather.win $+($gettok(%t,1,124),:,$chr(32),$gettok(%t,2,124),$chr(44),$chr(32),$gettok(%t,3,124),$chr(32),$chr(40),feels $gettok(%t,4,124),$chr(41),$chr(44),$chr(32),$gettok(%t,5,124),$chr(32),humidity,$chr(44),$chr(32),wind,$chr(32),$gettok(%t,6,124))
    return
  }
  ns.card Weather - $gettok(%t,1,124) $+ $chr(1) $+ $gettok(%t,2,124) $+ $chr(1) $+ Temperature $+ $chr(58) $gettok(%t,3,124) $+ $chr(32) $+ $chr(40) $+ feels like $gettok(%t,4,124) $+ $chr(41) $+ $chr(1) $+ Humidity $+ $chr(58) $gettok(%t,5,124) $+ $chr(44) wind $gettok(%t,6,124)
}
alias define {
  var %say = 0, %w = $1
  if ($1 == -s) {
    %say = 1
    %w = $2
  }
  if (!%w) { ns.err usage: /define [-s] <word> | return }
  set -u30 %ns.define.word %w
  set -u30 %ns.define.say %say
  set -u30 %ns.define.win $active
  if (!$urlget($+($ns.get(web,define_base,https://api.dictionaryapi.dev/api/v2/entries/en/),$ns.urlenc(%w)),gf,$ns.data(define.tmp),ns.define.done)) ns.err could not start the request.
}
alias ns.define.done {
  var %f = $urlget($1).target, %t, %n, %i = 1, %lines, %pos
  if (!$exists(%f)) || ($ns.web.status($1) != 200) { ns.err no definition found for %ns.define.word $+ . | return }
  %t = $ns.web.read(%f)
  %n = $regex(ns.dd,%t,/"definition":"((?:[^"\\]|\\.)*)"/g)
  if (!%n) {
    ns.err no definition found for %ns.define.word $+ .
    return
  }
  %pos = $iif($regex(ns.dp,%t,/"partOfSpeech":"([^"]+)"/),$regml(ns.dp,1))
  if (%ns.define.say) && (%ns.define.win) {
    msg %ns.define.win $+(%ns.define.word,$chr(32),$chr(40),%pos,$chr(41),$chr(58),$chr(32),$ns.json.unesc($regml(ns.dd,1)))
    return
  }
  while (%i <= 3) && (%i <= %n) {
    %lines = $+(%lines,$iif(%lines,$chr(1)),%i,.,$chr(32),$ns.json.unesc($regml(ns.dd,%i)))
    inc %i
  }
  ns.card %ns.define.word $+ $iif(%pos,$chr(32) $+ $chr(40) $+ %pos $+ $chr(41)) $+ $chr(1) $+ %lines
}
; /translate [-s] <language code> <text>     e.g. /translate es good morning
alias translate {
  var %say = 0, %lang = $1, %text = $2-
  if ($1 == -s) {
    %say = 1
    %lang = $2
    %text = $3-
  }
  if (!$regex(ns.tl,%lang,/^[A-Za-z][A-Za-z]([-_][A-Za-z][A-Za-z])?$/)) || (%text == $null) {
    ns.err usage: /translate [-s] <language code> <text>   e.g. /translate es good morning  (the text is sent to api.mymemory.translated.net)
    return
  }
  set -u30 %ns.tl.say %say
  set -u30 %ns.tl.win $active
  set -u30 %ns.tl.lang %lang
  set -u30 %ns.tl.text $left(%text,300)
  if (!$urlget($+($ns.get(web,translate_base,https://api.mymemory.translated.net/get),?q=,$ns.urlenc($left(%text,300)),&langpair=Autodetect,$chr(37),7C,%lang),gf,$ns.data(translate.tmp),ns.tl.done)) ns.err could not start the request.
}
alias tl translate $1-
alias ns.tl.done {
  var %f = $urlget($1).target, %t
  if (!$exists(%f)) || ($ns.web.status($1) != 200) { ns.err the translation service did not answer (status $ns.web.status($1) $+ ). | return }
  %t = $ns.web.read(%f)
  if (!$regex(ns.tr,%t,/"translatedText":"((?:[^"\\]|\\.)*)"/)) {
    ns.err the translation service gave no result (it has a small daily limit).
    return
  }
  var %r = $ns.json.unesc($regml(ns.tr,1))
  if (%ns.tl.say) && (%ns.tl.win) {
    msg %ns.tl.win %r
    return
  }
  ns.card Translate - %ns.tl.lang $+ $chr(1) $+ %ns.tl.text $+ $chr(1) $+ $ns.b $+ %r $+ $ns.b $+ $chr(1) $+ $ns.ec(dim) $+ via MyMemory $+ $ns.o
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
  var %cmd = $lower($1), %ext = $iif($isalias(ns.bot2.cmds) && $istok($ns.bot2.cmds,%cmd,32),1,0)
  if (!$findtok(!roll !8ball !coin !time !uptime !help !seen !ops !rank,%cmd,1,32)) && (!%ext) return
  hadd -mu $+ $ns.get(bot,cooldown,5) ns.botcd $+($cid,.,$nick) 1
  if (%ext) {
    ns.bot2.run %chan %nick %cmd $2-
    return
  }
  if (%cmd == !roll) ns.bot.reply $chan $nick $nick $+ : $ns.roll($2)
  elseif (%cmd == !8ball) ns.bot.reply $chan $nick $nick $+ : $gettok(Yes.;No.;Maybe.;Ask again later.;Definitely.;Not a chance.;Signs point to yes.;Very doubtful.,$rand(1,8),59)
  elseif (%cmd == !coin) ns.bot.reply $chan $nick $nick $+ : $iif($rand(0,1),Heads,Tails)
  elseif (%cmd == !time) ns.bot.reply $chan $nick It is $asctime(ddd d mmm yyyy HH:nn) (bot local time).
  elseif (%cmd == !uptime) ns.bot.reply $chan $nick I have been running for $duration($uptime(mirc,3)) $+ .
  elseif (%cmd == !help) ns.bot.reply $chan $nick Commands: !roll [NdM] !8ball !coin !time !uptime !seen <nick> !ops !rank <nick> !quote !addquote !karma !top !poll !vote !results !guess !rps !hangman
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
