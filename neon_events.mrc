; ============================================================================
;  NeonScript 2026  ::  event display
;  Restyles join / part / quit / kick / nick / mode / topic / invite and the
;  WHOIS reply.  Styles: modern (glyphs), retro (irssi-like -!-), minimal, mts
;  (imported MTS theme templates) and off (native mIRC).
;
;  Colours come from the active theme's event palette (never from mIRC's colour
;  scheme), nicknames get stable per-nick colours, and every channel prefix the
;  server supports (~ & @ % +) is shown and coloured by rank.
;
;  NOTE: free text (reasons, topics, masks) is never passed through identifier
;  parameters - mIRC would split it on commas.  It travels in the ns.evv hash
;  table and is appended with $+.
; ============================================================================

alias ns.ev.on return $iif($ns.get(events,style,modern) == off,$false,$true)
alias -l st return $ns.get(events,style,modern)
alias -l brl return $iif($st == retro,$chr(91),$chr(40))
alias -l brr return $iif($st == retro,$chr(93),$chr(41))
alias -l dim return $ns.ec(dim)
alias -l xv return $hget(ns.evv,$1)

; ---------------------------------------------------------------- symbols
; $ns.sym(name) -> glyph for the chosen symbol set (unicode | cp1252 | ascii)
alias ns.sym {
  var %n = $findtok(join part quit kick nick mode topic invite notice ctcp away info action,$1,1,32)
  var %m = $ns.get(events,symbols,unicode)
  if (!%n) return $chr(183)
  if (%m == unicode) return $chr($gettok(8594 8592 10005 10006 8644 10022 9998 9993 9670 9889 9790 8505 9733,%n,32))
  if (%m == cp1252) return $chr($gettok(187 171 171 215 183 42 42 43 183 33 122 105 42,%n,32))
  return $gettok(--> <-- <<< X ~ * * + - ! z i *,%n,32)
}
alias -l ev.mini return $gettok(+ - - ! ~ * * + - ! z i *,$findtok(join part quit kick nick mode topic invite notice ctcp away info action,$1,1,32),32)
; coloured leading glyph, per style
alias -l pre {
  if ($st == retro) return $+($dim,-!-,$ns.o)
  if ($st == minimal) return $+($ns.ec($1),$ev.mini($1),$ns.o)
  return $+($ns.ec($1),$ns.sym($1),$ns.o)
}
alias -l verb {
  var %r = $iif($st == retro,1,0)
  if ($1 == join) return $iif(%r,has joined,joined)
  if ($1 == part) return $iif(%r,has left,left)
  if ($1 == quit) return $iif(%r,has quit,quit)
  return $1
}

; ---------------------------------------------------------------- nick / host fragments
; $nk(chan,nick): rank glyph + bold per-nick colour.  chan may be $null (no prefix lookup)
alias -l nk {
  var %p = $iif($1,$ns.rk.glyph($ns.rk.of($1,$2)))
  return $+(%p,$ns.cc($ns.nickcol($2)),$ns.b,$2,$ns.b,$ns.o)
}
; $hm(user@host) -> dim "(user@host)"
alias -l hm return $+($dim,$brl,$1,$brr,$ns.o)

; hide join/part/quit noise in big channels (events quiet = N users, 0 = never)
alias ns.ev.quiet {
  var %q = $ns.get(events,quiet,0)
  if (%q <= 0) return $false
  return $iif($nick($1,0) >= %q,$true,$false)
}

; ---------------------------------------------------------------- the emit pipeline
; ns.ev.reset                         clear the event variable table
; ns.ev.emit <type> <target|-a|-s>    format the event (MTS template or built-in) and print it
alias ns.ev.reset {
  if ($hget(ns.evv)) hdel -w ns.evv *
}
alias ns.ev.emit {
  var %t = $1, %tg = $2, %line, %cn = $ns.ev.cname($1)
  if ($st == mts) && ($isalias(ns.mts.render)) {
    %line = $ns.mts.render(%t)
    if (%line == $null) %line = $ev.build(%t)
  }
  else %line = $ev.build(%t)
  if (%line == $null) return
  var %st = $iif($msgstamp,$msgstamp,$null)
  if (%tg == -a) echo -cat $+ %st $+ i2 %cn %line
  elseif (%tg == -s) echo -cst $+ %st $+ i2 %cn %line
  else echo -ct $+ %st $+ i2 %cn %tg %line
}
; mIRC colour-scheme item used as the base colour of each event line
alias ns.ev.cname {
  var %t = $1
  if (%t == joinself) return join
  if (%t == kickself) return kick
  if (%t == nickself) return nick
  return $iif($findtok(join part quit kick nick mode topic invite,%t,1,32),%t,info)
}

; ---------------------------------------------------------------- built-in line builder
alias -l ev.build {
  var %t = $1, %s, %r, %a
  if (%t == join) || (%t == joinself) {
    %a = $xv(account)
    if (%t == joinself) {
      %s = $pre(join) $+ $chr(32) $+ $ns.ec(join) $+ You joined $ns.b $+ $xv(chan) $+ $ns.b $+ $ns.o
      return %s
    }
    %s = $pre(join) $+ $chr(32) $+ $nk($null,$xv(nick))
    if ($ns.flag(events,showhost,1)) %s = %s $+ $chr(32) $+ $hm($xv(address))
    if (%a) && (%a != *) && (%a != 0) %s = %s $+ $chr(32) $+ $dim $+ $chr(8226) $+ $chr(32) $+ $ns.ec(join) $+ %a $+ $ns.o
    %s = %s $+ $chr(32) $+ $ns.ec(join) $+ $verb(join) $+ $iif($st == retro,$chr(32) $+ $xv(chan)) $+ $ns.o
    return %s
  }
  if (%t == part) || (%t == quit) {
    %r = $xv(text)
    %s = $pre(%t) $+ $chr(32) $+ $nk($xv(chan),$xv(nick))
    if ($ns.flag(events,showhost,1)) %s = %s $+ $chr(32) $+ $hm($xv(address))
    %s = %s $+ $chr(32) $+ $ns.ec(%t) $+ $verb(%t)
    if ($st == retro) && (%t == part) %s = %s $+ $chr(32) $+ $xv(chan)
    %s = %s $+ $ns.o
    if (%r) %s = %s $+ $chr(32) $+ $dim $+ $chr(40) $+ %r $+ $chr(41) $+ $ns.o
    return %s
  }
  if (%t == kick) || (%t == kickself) {
    %r = $xv(text)
    %s = $pre(kick)
    if (%t == kickself) %s = %s $+ $chr(32) $+ $ns.ec(kick) $+ $ns.b $+ You were kicked $ns.b $+ from $ns.b $+ $xv(chan) $+ $ns.b $+ $chr(32) $+ by $chr(32) $+ $nk($xv(chan),$xv(nick)) $+ $ns.o
    else %s = %s $+ $chr(32) $+ $nk($xv(chan),$xv(knick)) $+ $chr(32) $+ $ns.ec(kick) $+ $ns.b $+ was kicked $ns.b $+ by $chr(32) $+ $nk($xv(chan),$xv(nick)) $+ $ns.o
    if (%r) %s = %s $+ $chr(32) $+ $dim $+ $chr(40) $+ $ns.ec(kick) $+ %r $+ $dim $+ $chr(41) $+ $ns.o
    return %s
  }
  if (%t == nick) || (%t == nickself) {
    %s = $pre(nick) $+ $chr(32) $+ $nk($xv(chan),$xv(nick)) $+ $chr(32) $+ $ns.ec(nick) $+ is now known as $+ $ns.o $+ $chr(32) $+ $nk($xv(chan),$xv(newnick))
    return %s
  }
  if (%t == mode) {
    %s = $pre(mode) $+ $chr(32) $+ $nk($xv(chan),$xv(nick)) $+ $chr(32) $+ $ev.modetext
    return %s
  }
  if (%t == topic) {
    %s = $pre(topic) $+ $chr(32) $+ $nk($xv(chan),$xv(nick)) $+ $chr(32) $+ $ns.ec(topic) $+ changed the topic to: $+ $ns.o $+ $chr(32) $+ $ns.ec(value) $+ $xv(text) $+ $ns.o
    return %s
  }
  if (%t == invite) {
    %s = $pre(invite) $+ $chr(32) $+ $nk($null,$xv(nick)) $+ $chr(32) $+ $ns.ec(invite) $+ invited you to $+ $ns.o $+ $chr(32) $+ $ns.b $+ $ns.ec(invite) $+ $xv(chan) $+ $ns.o
    return %s
  }
  return $null
}

; ---------------------------------------------------------------- mode parser (all prefixes)
; Describes a mode change in words.  Reads chan/modes from ns.evv.
;   +q ~ owner   +a & admin   +o @ op   +h % halfop   +v + voice   (whatever the server's PREFIX says)
;   +b/-b bans, +e/+I lists, +k key, +l limit, and plain flags (+m moderated ...)
alias -l ev.modetext {
  var %all = $xv(modes), %ms = $gettok(%all,1,32), %pi = 2, %i = 1, %out, %c, %arg, %p, %sign = +, %ch, %nm
  var %cm = $chanmodes, %eq = $pos(%cm,$chr(61))
  if (%eq) %cm = $mid(%cm,$calc(%eq + 1))
  var %A = $gettok(%cm,1,44), %B = $gettok(%cm,2,44), %C = $gettok(%cm,3,44)
  var %pm = $ns.rk.modes, %pc = $ns.rk.chars, %sep = $+($chr(32),$dim,$chr(183),$ns.o)
  var %up = $ns.ec(mode), %plus = $chr(43)
  while (%i <= $len(%ms)) {
    %c = $mid(%ms,%i,1)
    if (%c == $chr(43)) || (%c == $chr(45)) {
      %sign = %c
      inc %i
      continue
    }
    %p = $null
    if ($pos(%pm,%c)) {
      ; prefix modes: q a o h v and anything else the server defines
      %arg = $gettok(%all,%pi,32)
      inc %pi
      %ch = $mid(%pc,$pos(%pm,%c),1)
      %nm = $ns.rk.lname(%c)
      if (!%nm) %nm = mode $+ $chr(32) $+ %c
      %p = $+(%up,$iif(%sign == %plus,gives,takes),$ns.o,$chr(32),$ns.rk.glyph(%ch),$ns.ec($iif($pos(qaohv,%c),%c,o)),%nm,$ns.o,$chr(32),%up,$iif(%sign == %plus,to,from),$ns.o,$chr(32),$nk($xv(chan),%arg))
    }
    elseif ($pos(%A,%c)) || ($pos(%B,%c)) {
      %arg = $gettok(%all,%pi,32)
      inc %pi
      %p = $ev.modelist(%c,%sign,%arg)
    }
    elseif ($pos(%C,%c)) {
      %arg = $null
      if (%sign == %plus) {
        %arg = $gettok(%all,%pi,32)
        inc %pi
      }
      %p = $ev.modelist(%c,%sign,%arg)
    }
    else %p = $ev.modelist(%c,%sign,$null)
    if (%p != $null) {
      if (%out != $null) %out = %out $+ %sep $+ $chr(32) $+ %p
      else %out = %p
    }
    inc %i
  }
  if (%out == $null) return $+(%up,sets mode: ,$ns.o,$chr(32),$ns.ec(value),%all,$ns.o)
  return %out
}
; one non-prefix mode change: $ev.modelist(letter,sign,arg)
alias -l ev.modelist {
  var %c = $1, %on = $iif($2 == $chr(43),1,0), %arg = $3, %up = $ns.ec(mode), %val = $ns.ec(value), %o = $ns.o, %nm
  if (%c === b) return $+(%up,$iif(%on,bans,unbans),%o,$chr(32),%val,$ns.b,%arg,$ns.b,%o)
  if (%c === e) return $+(%up,$iif(%on,exempts,removes exempt for),%o,$chr(32),%val,%arg,%o)
  if (%c === I) return $+(%up,$iif(%on,invite-exempts,removes invite-exempt for),%o,$chr(32),%val,%arg,%o)
  if (%c === q) return $+(%up,$iif(%on,quiets,unquiets),%o,$chr(32),%val,%arg,%o)
  if (%c === k) return $+(%up,$iif(%on,sets the channel key to,removes the channel key),%o,$iif(%on,$+($chr(32),%val,$ns.b,%arg,$ns.b,%o)))
  if (%c === l) return $+(%up,$iif(%on,limits the channel to,removes the user limit),%o,$iif(%on,$+($chr(32),%val,$ns.b,%arg,$ns.b,%o,$chr(32),%up,users,%o)))
  if (%c === m) %nm = moderated
  elseif (%c === n) %nm = no outside messages
  elseif (%c === t) %nm = topic lock
  elseif (%c === i) %nm = invite only
  elseif (%c === s) %nm = secret
  elseif (%c === p) %nm = private
  elseif (%c === c) %nm = no colours
  elseif (%c === C) %nm = no CTCP
  elseif (%c === r) %nm = registered only
  elseif (%c === R) %nm = registered speak only
  elseif (%c === S) %nm = TLS only
  return $+(%up,$iif(%on,sets,clears),%o,$chr(32),%val,$ns.b,$iif(%on,$chr(43),$chr(45)),%c,$ns.b,%o,$iif(%nm,$+($chr(32),$dim,$chr(40),%nm,$chr(41),%o)),$iif(%arg,$+($chr(32),%val,%arg,%o)))
}

; ---------------------------------------------------------------- JOIN / PART / QUIT
on ^*:JOIN:#:{
  if (!$ns.ev.on) return
  if ($nick != $me) && ($ns.ev.quiet($chan)) {
    haltdef
    return
  }
  ns.ev.reset
  hadd -m ns.evv nick $nick
  hadd -m ns.evv address $address
  hadd -m ns.evv chan $chan
  hadd -m ns.evv account $ial($fulladdress).account
  hadd -m ns.evv cmode $ns.rk.of($chan,$nick)
  ns.ev.emit $iif($nick == $me,joinself,join) $chan
  haltdef
}
on ^*:PART:#:{
  if (!$ns.ev.on) return
  if ($nick == $me) return
  if ($ns.ev.quiet($chan)) {
    haltdef
    return
  }
  ns.ev.reset
  hadd -m ns.evv nick $nick
  hadd -m ns.evv address $address
  hadd -m ns.evv chan $chan
  hadd -m ns.evv text $1-
  hadd -m ns.evv cmode $ns.rk.of($chan,$nick)
  ns.ev.emit part $chan
  haltdef
}
on ^*:QUIT:{
  if (!$ns.ev.on) return
  var %n = $comchan($nick,0), %i = 1, %c
  while (%i <= %n) {
    %c = $comchan($nick,%i)
    if (!$ns.ev.quiet(%c)) {
      ns.ev.reset
      hadd -m ns.evv nick $nick
      hadd -m ns.evv address $address
      hadd -m ns.evv chan %c
      hadd -m ns.evv text $1-
      hadd -m ns.evv cmode $ns.rk.of(%c,$nick)
      ns.ev.emit quit %c
    }
    inc %i
  }
  haltdef
}

; ---------------------------------------------------------------- KICK / NICK / MODE / TOPIC / INVITE
on ^*:KICK:#:{
  if (!$ns.ev.on) return
  ns.ev.reset
  hadd -m ns.evv nick $nick
  hadd -m ns.evv address $address
  hadd -m ns.evv knick $knick
  hadd -m ns.evv chan $chan
  hadd -m ns.evv text $1-
  hadd -m ns.evv cmode $ns.rk.of($chan,$nick)
  ns.ev.emit $iif($knick == $me,kickself,kick) $chan
  haltdef
}
on ^*:NICK:{
  if (!$ns.ev.on) return
  var %n = $comchan($newnick,0), %i = 1, %c
  while (%i <= %n) {
    %c = $comchan($newnick,%i)
    ns.ev.reset
    hadd -m ns.evv nick $nick
    hadd -m ns.evv newnick $newnick
    hadd -m ns.evv address $address
    hadd -m ns.evv chan %c
    hadd -m ns.evv cmode $ns.rk.of(%c,$newnick)
    ns.ev.emit $iif($nick == $me,nickself,nick) %c
    inc %i
  }
  haltdef
}
on ^*:RAWMODE:#:{
  if (!$ns.ev.on) return
  if (!$ns.flag(events,modes,1)) return
  ns.ev.reset
  hadd -m ns.evv nick $nick
  hadd -m ns.evv address $address
  hadd -m ns.evv chan $chan
  hadd -m ns.evv modes $1-
  hadd -m ns.evv cmode $ns.rk.of($chan,$nick)
  ns.ev.emit mode $chan
  haltdef
}
on ^*:TOPIC:#:{
  if (!$ns.ev.on) return
  ns.ev.reset
  hadd -m ns.evv nick $nick
  hadd -m ns.evv address $address
  hadd -m ns.evv chan $chan
  hadd -m ns.evv text $1-
  hadd -m ns.evv cmode $ns.rk.of($chan,$nick)
  ns.ev.emit topic $chan
  haltdef
}
on ^*:INVITE:#:{
  if (!$ns.ev.on) return
  ns.ev.reset
  hadd -m ns.evv nick $nick
  hadd -m ns.evv address $address
  hadd -m ns.evv chan $chan
  ns.ev.emit invite -a
  haltdef
}

; ---------------------------------------------------------------- WHOIS card
; Raw events collect into a small coloured box in the window where /whois was typed.
; Channel lists are rank coloured for every prefix the server knows (~ & @ % +).
alias -l boxv return $iif($ns.get(events,symbols,unicode) == unicode,$chr(9474),$iif($ns.get(events,symbols,unicode) == cp1252,$chr(166),$chr(124)))
alias -l boxt return $iif($ns.get(events,symbols,unicode) == unicode,$chr(9484) $+ $chr(9472),$chr(43) $+ $chr(45))
alias -l boxe return $iif($ns.get(events,symbols,unicode) == unicode,$chr(9492) $+ $str($chr(9472),24),$chr(43) $+ $str($chr(45),24))
alias -l wacc return $ns.cc($ns.get(theme,accent,13))
alias -l wtxt {
  var %t = $1-
  if ($left(%t,1) == :) %t = $mid(%t,2)
  return %t
}
; a labelled row:  | label     <value from ns.evv row>
alias -l wrow {
  echo -cai2 whois $+($wacc,$boxv,$ns.o,$chr(32),$ns.ec(label),$replace($left($+($1-,$str($chr(1),10)),10),$chr(1),$chr(32)),$ns.o,$chr(32)) $+ $hget(ns.evv,row)
}
; rank-coloured channel list: "@#a +#b #c" -> glyphs + coloured names (text in ns.evv)
alias -l wchans {
  var %tok = 1, %out, %t, %lead, %f, %pc = $ns.rk.chars, %col, %val = $ns.ec(value)
  while ($gettok($hget(ns.evv,text),%tok,32) != $null) {
    %t = $v1
    %lead = $null
    %col = %val
    while ($left(%t,1) != $null) && ($pos(%pc,$left(%t,1))) {
      %f = $left(%t,1)
      %lead = %lead $+ $ns.rk.glyph(%f)
      if (%col == %val) %col = $ns.ec($ns.rk.letter(%f))
      %t = $mid(%t,2)
    }
    if (%out != $null) %out = %out $+ $chr(32) $+ %lead $+ %col $+ %t $+ $ns.o
    else %out = %lead $+ %col $+ %t $+ $ns.o
    inc %tok
  }
  return %out
}
alias -l wi.ok return $iif($ns.flag(events,whois,1),$iif($ns.ev.on,1,0),0)

raw 311:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 311 $2- | if ($result) halt }
  ns.ev.reset
  hadd -m ns.evv nick $2
  hadd -m ns.evv user $3
  hadd -m ns.evv host $4
  hadd -m ns.evv address $3 $+ @ $+ $4
  hadd -m ns.evv realname $wtxt($6-)
  echo -cati2 whois $+($wacc,$boxt,$ns.o,$chr(32),$ns.cc($ns.nickcol($2)),$ns.b,$2,$ns.b,$ns.o,$chr(32),$ns.ec(dim),$chr(40),$3,@,$4,$chr(41),$ns.o)
  hadd -m ns.evv row $ns.ec(value) $+ $hget(ns.evv,realname) $+ $ns.o
  wrow name
  halt
}
raw 312:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 312 $2- | if ($result) halt }
  hadd -m ns.evv row $ns.ec(topic) $+ $3 $+ $ns.o $+ $chr(32) $+ $ns.ec(dim) $+ $chr(40) $+ $wtxt($4-) $+ $chr(41) $+ $ns.o
  wrow server
  halt
}
raw 313:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 313 $2- | if ($result) halt }
  hadd -m ns.evv row $ns.ec(kick) $+ $ns.b $+ IRC operator $+ $ns.b $+ $ns.o
  wrow oper
  halt
}
raw 317:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 317 $2- | if ($result) halt }
  hadd -m ns.evv row $ns.ec(mode) $+ $duration($3) $+ $ns.o $+ $chr(32) $+ $ns.ec(dim) $+ $chr(183) $+ $chr(32) $+ signed on $+ $ns.o $+ $chr(32) $+ $ns.ec(value) $+ $asctime($4,ddd mmm d HH:nn) $+ $ns.o
  wrow idle
  halt
}
raw 319:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 319 $2- | if ($result) halt }
  hadd -m ns.evv text $wtxt($3-)
  hadd -m ns.evv row $wchans
  wrow channels
  halt
}
raw 330:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 330 $2- | if ($result) halt }
  hadd -m ns.evv row $ns.ec(join) $+ $3 $+ $ns.o
  wrow account
  halt
}
raw 301:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 301 $2- | if ($result) halt }
  hadd -m ns.evv row $ns.ec(part) $+ $wtxt($3-) $+ $ns.o
  wrow away
  halt
}
raw 671:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 671 $2- | if ($result) halt }
  hadd -m ns.evv row $ns.ec(join) $+ using a TLS connection $+ $ns.o
  wrow secure
  halt
}
raw 307:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 307 $2- | if ($result) halt }
  hadd -m ns.evv row $ns.ec(join) $+ nickname is registered $+ $ns.o
  wrow registered
  halt
}
raw 335:*:{
  if (!$wi.ok) return
  hadd -m ns.evv row $ns.ec(invite) $+ is a bot $+ $ns.o
  wrow bot
  halt
}
raw 338:*:{
  if (!$wi.ok) return
  hadd -m ns.evv row $ns.ec(dim) $+ $3 $+ $ns.o
  wrow real host
  halt
}
raw 378:*:{
  if (!$wi.ok) return
  hadd -m ns.evv row $ns.ec(dim) $+ $wtxt($3-) $+ $ns.o
  wrow host
  halt
}
raw 318:*:{
  if (!$wi.ok) return
  if ($isalias(ns.mts.raw)) { ns.mts.raw 318 $2- | if ($result) halt }
  echo -cai2 whois $+($wacc,$boxe,$ns.o)
  halt
}

; ---------------------------------------------------------------- nick colours + timestamps
; auto-colour every nickname using mIRC's built-in nick colour engine
alias ns.ev.nickcolors {
  if ($1 == on) {
    cnick -f * *
    cnick on
  }
  else cnick -r *
}
; timestamp modes: 0 off, 1 [HH:nn], 2 [HH:nn:ss], 3 (HH:nn), 4 HH:nn
alias ns.stampfmt {
  if ($1 == 1) return $+($chr(91),HH:nn,$chr(93))
  if ($1 == 2) return $+($chr(91),HH:nn:ss,$chr(93))
  if ($1 == 3) return $+($chr(40),HH:nn,$chr(41))
  return HH:nn
}
alias ns.ev.applystamp {
  var %m = $ns.get(events,stampmode,1)
  if (%m == 0) {
    timestamp off
    return
  }
  timestamp -f $ns.stampfmt(%m)
  timestamp on
}
; /neon stamp <0-4>
alias neon.stamp {
  if ($1 !isnum 0-4) { ns.err usage: /neon stamp 0 (off) $+ $chr(44) 1 [HH:nn] $+ $chr(44) 2 [HH:nn:ss] $+ $chr(44) 3 (HH:nn) $+ $chr(44) 4 HH:nn | return }
  ns.set events stampmode $1
  ns.ev.applystamp
  ns.say timestamps: $iif($1 == 0,off,$ns.stampfmt($1))
}

; ---------------------------------------------------------------- commands
; /neon style modern|retro|minimal|mts|off   /neon symbols unicode|cp1252|ascii
alias neon.style {
  if (!$findtok(modern retro minimal mts off,$1,1,32)) {
    ns.err usage: /neon style modern, retro, minimal, mts or off
    return
  }
  ns.set events style $1
  ns.say event style set to $1
}
alias neon.symbols {
  if (!$findtok(unicode cp1252 ascii,$1,1,32)) {
    ns.err usage: /neon symbols unicode, cp1252 or ascii
    return
  }
  ns.set events symbols $1
  ns.say symbol set changed to $1 $+ : $ns.sym(join) $ns.sym(part) $ns.sym(quit) $ns.sym(kick) $ns.sym(nick) $ns.sym(mode)
}
