; ============================================================================
;  NeonScript 2026  ::  extras for channels
;    Quote database   !addquote !quote !delquote          /neon quote
;    Karma            nick++  nick--  !karma  !top
;    Polls            !poll 5m Question? | one | two      !vote N   !results   !endpoll
;    Games            !guess   !rps   !hangman / !h <letter>
;    Cards            /weather  /define  /translate        (web - only when you run them)
;
;  The channel commands are part of the channel bot (Control Panel > Channel commands): they only answer
;  when it is switched on, in the channels you allow, with the same per-person cool-down.  Everything stays
;  on this PC (data\quotes.txt, data\karma.dat); nothing is looked up on the web except /weather, /define and
;  /translate, and only when YOU type them.
; ============================================================================

alias ns.bot2.cmds return !addquote !quote !delquote !karma !top !poll !vote !results !endpoll !guess !rps !hangman !h
alias ns.x.key return $+($ns.mod.net,|,$lower($1))
; may this nick run moderator-ish commands (halfop or higher, or flagged o/a/q on the userlist)?
alias ns.bot2.priv {
  if ($ns.rk.atleast($1,$2,h)) || ($ns.rk.atleast($1,$2,o)) return 1
  var %f = $ns.acc.flags($2,$1)
  if ($pos(%f,o)) || ($pos(%f,a)) || ($pos(%f,q)) return 1
  return 0
}
; one tidy line, no control codes, not too long
alias ns.x.clean return $left($remove($strip($1-),$chr(9),$chr(13),$chr(10)),$iif($ns.get(extra,maxlen,300) isnum,$ns.get(extra,maxlen,300),300))

; ---------------------------------------------------------------- dispatcher (called by the channel bot)
alias ns.bot2.run {
  ; ns.bot2.run <chan> <nick> <command> <args...>
  var %c = $1, %n = $2, %cmd = $3, %a = $4-
  if (%cmd == !addquote) { ns.q.botadd %c %n %a | return }
  if (%cmd == !quote) { ns.q.botget %c %n %a | return }
  if (%cmd == !delquote) { ns.q.botdel %c %n %a | return }
  if (%cmd == !karma) { ns.karma.say %c %n $iif(%a != $null,$gettok(%a,1,32),%n) | return }
  if (%cmd == !top) { ns.karma.top %c %n | return }
  if (%cmd == !poll) { ns.poll.start %c %n %a | return }
  if (%cmd == !vote) { ns.poll.vote %c %n %a | return }
  if (%cmd == !results) { ns.poll.show %c %n | return }
  if (%cmd == !endpoll) { ns.poll.end %c %n | return }
  if (%cmd == !guess) { ns.game.guess %c %n %a | return }
  if (%cmd == !rps) { ns.game.rps %c %n %a | return }
  if (%cmd == !hangman) { ns.game.hang %c %n | return }
  if (%cmd == !h) { ns.game.hangletter %c %n %a | return }
}

; ============================================================================
;  QUOTES      data\quotes.txt:  id TAB net|#chan TAB ctime TAB added-by TAB text
; ============================================================================
alias ns.q.file return $ns.data(quotes.txt)
alias ns.q.nextid {
  var %f = $ns.q.file, %n = $lines(%f), %max = 0, %i = 1, %v
  while (%i <= %n) {
    %v = $gettok($read(%f,n,%i),1,9)
    if (%v isnum) && (%v > %max) %max = %v
    inc %i
  }
  return $calc(%max + 1)
}
; every quote line of a channel, newest last
alias ns.q.lines {
  var %f = $ns.q.file, %n = $lines(%f), %i = 1, %l, %key = $ns.x.key($1), %o
  while (%i <= %n) {
    %l = $read(%f,n,%i)
    if ($gettok(%l,2,9) == %key) %o = %o $+ $iif(%o,$chr(124)) $+ %i
    inc %i
  }
  return %o
}
alias ns.q.add {
  var %t = $ns.x.clean($3-), %id
  if (%t == $null) return 0
  if ($lines($ns.q.file) > 3000) return 0
  %id = $ns.q.nextid
  write $qt($ns.q.file) $+(%id,$chr(9),$ns.x.key($1),$chr(9),$ctime,$chr(9),$2,$chr(9),%t)
  return %id
}
alias ns.q.show return $+($chr(35),$gettok($1,1,9),$chr(58),$chr(32),$gettok($1,5-,9),$chr(32),$chr(40),added by $gettok($1,4,9),$chr(41))
; pick: a number = that quote, words = a random match, nothing = a random one
alias ns.q.pick {
  var %chan = $1, %q = $2-, %f = $ns.q.file, %idx = $ns.q.lines(%chan), %i = 1, %n = $numtok(%idx,124), %l, %hits, %w, %ok, %j
  if (!%n) return $null
  if (%q == $null) return $read(%f,n,$gettok(%idx,$rand(1,%n),124))
  if (%q isnum) return $ns.q.byid(%chan,%q)
  while (%i <= %n) {
    %l = $read(%f,n,$gettok(%idx,%i,124))
    %ok = 1
    %j = 1
    while ($gettok(%q,%j,32) != $null) {
      if (!$pos($gettok(%l,5-,9),$gettok(%q,%j,32))) %ok = 0
      inc %j
    }
    if (%ok) %hits = %hits $+ $iif(%hits,$chr(124)) $+ $gettok(%l,1,9)
    inc %i
  }
  if (!%hits) return $null
  %i = $gettok(%hits,$rand(1,$numtok(%hits,124)),124)
  return $ns.q.byid(%chan,%i)
}
; the quote with this number in this channel ("" if none)
alias ns.q.byid {
  var %f = $ns.q.file, %idx = $ns.q.lines($1), %n = $numtok(%idx,124), %i = 1, %l
  while (%i <= %n) {
    %l = $read(%f,n,$gettok(%idx,%i,124))
    if ($gettok(%l,1,9) == $2) return %l
    inc %i
  }
  return $null
}
alias ns.q.botadd {
  var %id = $ns.q.add($1,$2,$3-)
  if (!%id) ns.bot.reply $1 $2 usage: !addquote <something memorable>
  else ns.bot.reply $1 $2 quote $+($chr(35),%id) added.
}
alias ns.q.botget {
  var %l = $ns.q.pick($1,$3-)
  if (%l == $null) ns.bot.reply $1 $2 $iif($3- != $null,no quote matches that.,no quotes yet - add one with !addquote.)
  else ns.bot.reply $1 $2 $ns.q.show(%l)
}
alias ns.q.botdel {
  var %l = $ns.q.pick($1,$3)
  if (!$ns.bot2.priv($1,$2)) { ns.bot.reply $1 $2 only ops can delete quotes. | return }
  if ($3 !isnum) || (%l == $null) { ns.bot.reply $1 $2 usage: !delquote <number> | return }
  ns.q.remove $gettok(%l,1,9)
  ns.bot.reply $1 $2 quote $+($chr(35),$3) deleted.
}
alias ns.q.remove {
  var %f = $ns.q.file, %tmp = $+(%f,.new), %n = $lines(%f), %i = 1, %l
  if ($exists(%tmp)) .remove $qt(%tmp)
  while (%i <= %n) {
    %l = $read(%f,n,%i)
    inc %i
    if ($gettok(%l,1,9) != $1) write $qt(%tmp) %l
  }
  .remove $qt(%f)
  if ($exists(%tmp)) .rename $qt(%tmp) $qt(%f)
}
; /neon quote add <text> | find <words> | <n> | del <n> | list       (in a channel window)
alias neon.quote {
  var %c = $active, %sub = $lower($1)
  if (!$ns.ischan(%c)) { ns.err open a channel window first. | return }
  if (%sub == add) {
    var %id = $ns.q.add(%c,$me,$2-)
    if (%id) ns.say quote $+($chr(35),%id) saved.
    else ns.err usage: /neon quote add <text>
    return
  }
  if (%sub == del) {
    if ($2 !isnum) { ns.err usage: /neon quote del <number> | return }
    var %l = $ns.q.pick(%c,$2)
    if (%l == $null) { ns.err no such quote here. | return }
    ns.q.remove $2
    ns.say quote $+($chr(35),$2) deleted.
    return
  }
  if (%sub == list) {
    var %idx = $ns.q.lines(%c), %i = 1
    if (!%idx) { ns.say no quotes in %c yet. | return }
    while ($gettok(%idx,%i,124) != $null) {
      ns.say $ns.q.show($read($ns.q.file,n,$gettok(%idx,%i,124)))
      inc %i
    }
    return
  }
  var %l = $ns.q.pick(%c,$iif(%sub == find,$2-,$1-))
  if (%l == $null) ns.say no quote found.
  else ns.say $ns.q.show(%l)
}

; ============================================================================
;  KARMA        nick++ / nick--      data\karma.dat
; ============================================================================
alias ns.karma.file return $ns.data(karma.dat)
on *:SIGNAL:ns.boot:{
  if ($exists($ns.karma.file)) && (!$hget(ns.karma)) hload -m ns.karma $qt($ns.karma.file)
  .timer.nskarma 0 300 ns.karma.save
}
on *:SIGNAL:ns.exit:{ ns.karma.save }
alias ns.karma.save { if ($hget(ns.karma)) hsave -o ns.karma $qt($ns.karma.file) }
alias ns.karma.get {
  var %v = $hget(ns.karma,$+($ns.x.key($1),|,$lower($2)))
  return $iif(%v isnum,%v,0)
}
on *:TEXT:*:#:{
  if (!$ns.flag(extra,karma,1)) return
  if ($ns.bnc.q) return
  if ($nick == $me) return
  if ($regex(ns.kr,$1-,/^([^\s]+?)(\+\+|--)\s*$/)) ns.karma.give $chan $nick $regml(ns.kr,1) $regml(ns.kr,2)
}
alias ns.karma.give {
  var %c = $1, %from = $2, %to = $remove($3,$chr(58),$chr(44)), %dir = $iif($4 == $+(+,+),1,-1), %k, %cd
  if (%to == $null) || (%to == %from) || (!$nick(%c,%to)) return
  %cd = $+($cid,.,%c,.,%from,.,%to)
  if ($hget(ns.karmacd,%cd)) return
  hadd -mu60 ns.karmacd %cd 1
  %k = $+($ns.x.key(%c),|,$lower(%to))
  hadd -m ns.karma %k $calc($ns.karma.get(%c,%to) + %dir)
  if ($ns.flag(bot,enabled,0)) && ($ns.bot.allowed(%c)) && ($ns.flag(extra,karmareply,1)) ns.bot.reply %c %from %to $+ $chr(39) $+ s karma: $ns.karma.get(%c,%to)
}
alias ns.karma.say {
  ns.bot.reply $1 $2 $3 has karma $ns.karma.get($1,$3) $+ .
}
alias ns.karma.top {
  var %c = $1, %n = $hget(ns.karma,0).item, %i = 1, %k, %pre = $+($ns.x.key(%c),|), %list, %o, %best, %bv, %j, %cur, %cnt = 0
  while (%i <= %n) {
    %k = $hget(ns.karma,%i).item
    inc %i
    if ($left(%k,$len(%pre)) == %pre) %list = %list $+($mid(%k,$calc($len(%pre) + 1)),:,$hget(ns.karma,%k))
  }
  while (%cnt < 5) && ($gettok(%list,1,32) != $null) {
    %best = $gettok(%list,1,32)
    %bv = $gettok(%best,2,58)
    %j = 2
    while ($gettok(%list,%j,32) != $null) {
      %cur = $gettok(%list,%j,32)
      if ($gettok(%cur,2,58) > %bv) {
        %best = %cur
        %bv = $gettok(%cur,2,58)
      }
      inc %j
    }
    %o = $+(%o,$iif(%o,$chr(44) $+ $chr(32)),$iif($nick(%c,$gettok(%best,1,58)),$nick(%c,$nick(%c,$gettok(%best,1,58))),$gettok(%best,1,58)),$chr(32),$chr(40),%bv,$chr(41))
    %list = $remtok(%list,%best,1,32)
    inc %cnt
  }
  ns.bot.reply %c $2 $iif(%o,top karma: %o,nobody has any karma yet - try nick++)
}

; ============================================================================
;  POLLS         !poll [5m] Question? | one | two | three
; ============================================================================
alias ns.poll.key return $+($ns.x.key($1),.)
alias ns.poll.get return $hget(ns.poll,$+($ns.poll.key($1),$2))
alias ns.poll.start {
  var %c = $1, %n = $2, %txt = $3-, %secs = 0, %q, %opts, %i = 1, %k = $ns.poll.key(%c)
  if (!$ns.bot2.priv(%c,%n)) { ns.bot.reply %c %n only ops can start a poll. | return }
  if ($ns.poll.get(%c,q) != $null) { ns.bot.reply %c %n a poll is already running - !results, or !endpoll to close it. | return }
  if ($ns.mod.secs($gettok(%txt,1,32)) > 0) {
    %secs = $ns.mod.secs($gettok(%txt,1,32))
    %txt = $gettok(%txt,2-,32)
  }
  %txt = $ns.x.clean(%txt)
  %q = $ns.trim($gettok(%txt,1,124))
  %opts = $null
  %i = 2
  while ($gettok(%txt,%i,124) != $null) {
    %opts = $+(%opts,$iif(%opts,$chr(9)),$ns.trim($gettok(%txt,%i,124)))
    inc %i
  }
  if (%q == $null) || ($numtok(%opts,9) < 2) || ($numtok(%opts,9) > 8) {
    ns.bot.reply %c %n usage: !poll [5m] Question? $+ $chr(32) $+ $chr(124) $+ $chr(32) $+ one $+ $chr(32) $+ $chr(124) $+ $chr(32) $+ two (2 to 8 options)
    return
  }
  hadd -m ns.poll $+(%k,q) %q
  hadd -m ns.poll $+(%k,o) %opts
  hadd -m ns.poll $+(%k,by) %n
  hadd -m ns.poll $+(%k,start) $ctime
  ns.bot.reply %c %n poll: %q
  %i = 1
  while ($gettok(%opts,%i,9) != $null) {
    ns.bot.reply %c %n $+($chr(32),$chr(32),%i,.,$chr(32),$gettok(%opts,%i,9))
    inc %i
  }
  ns.bot.reply %c %n vote with !vote <number> $+ $iif(%secs > 0,$chr(32) $+ - open for $ns.mod.dur(%secs))
  if (%secs > 0) .timer $+ ns.poll $+ $md5(%k) -o 1 %secs scid $cid ns.poll.end %c $me
}
alias ns.poll.vote {
  var %c = $1, %n = $2, %v = $3, %k = $ns.poll.key(%c), %opts = $ns.poll.get(%c,o)
  if (%opts == $null) { ns.bot.reply %c %n there is no poll right now. | return }
  if (%v !isnum) || (%v < 1) || (%v > $numtok(%opts,9)) { ns.bot.reply %c %n vote with a number from 1 to $numtok(%opts,9) $+ . | return }
  hadd -m ns.poll $+(%k,v.,$lower(%n)) %v
  ns.bot.reply %c %n thanks, vote counted for $gettok(%opts,%v,9) $+ .
}
alias ns.poll.tally {
  var %c = $1, %k = $ns.poll.key(%c), %pre = $+(%k,v.), %i = 1, %n = $hget(ns.poll,0).item, %it, %v, %o
  var %cnt = $ns.trim($str($+(0,$chr(32)),$numtok($ns.poll.get(%c,o),9)))
  while (%i <= %n) {
    %it = $hget(ns.poll,%i).item
    inc %i
    if ($left(%it,$len(%pre)) != %pre) continue
    %v = $hget(ns.poll,%it)
    %cnt = $puttok(%cnt,$calc($gettok(%cnt,%v,32) + 1),%v,32)
  }
  return %cnt
}
alias ns.poll.show {
  var %c = $1, %opts = $ns.poll.get(%c,o), %cnt = $ns.poll.tally(%c), %i = 1, %total = 0, %o
  if (%opts == $null) { ns.bot.reply %c $2 there is no poll right now. | return }
  while ($gettok(%cnt,%i,32) != $null) {
    inc %total $gettok(%cnt,%i,32)
    inc %i
  }
  %i = 1
  while ($gettok(%opts,%i,9) != $null) {
    %o = $+(%o,$iif(%o,$chr(32) $+ $chr(124) $+ $chr(32)),$gettok(%opts,%i,9),$chr(32),$gettok(%cnt,%i,32))
    inc %i
  }
  ns.bot.reply %c $2 $ns.poll.get(%c,q) $+ $chr(32) $+ - %total vote(s): %o
}
alias ns.poll.end {
  var %c = $1, %n = $2, %k = $ns.poll.key(%c), %it, %i = 1, %cnt = $hget(ns.poll,0).item, %del
  if ($ns.poll.get(%c,q) == $null) { ns.bot.reply %c %n there is no poll right now. | return }
  if (%n != $me) && (%n != $ns.poll.get(%c,by)) && (!$ns.bot2.priv(%c,%n)) { ns.bot.reply %c %n only the person who started it, or an op, can end the poll. | return }
  ns.poll.show %c %n
  ns.bot.reply %c %n poll closed.
  while (%i <= %cnt) {
    %it = $hget(ns.poll,%i).item
    inc %i
    if ($left(%it,$len(%k)) == %k) %del = %del %it
  }
  %i = 1
  while ($gettok(%del,%i,32) != $null) {
    hdel ns.poll $gettok(%del,%i,32)
    inc %i
  }
}

; ============================================================================
;  GAMES        !guess   !rps   !hangman
; ============================================================================
alias ns.game.guess {
  var %c = $1, %n = $2, %g = $3, %k = $+($ns.x.key(%c),.guess), %secret = $hget(ns.game,%k)
  if (%secret == $null) {
    hadd -m ns.game %k $rand(1,100)
    hadd -m ns.game $+(%k,.t) 0
    ns.bot.reply %c %n I am thinking of a number from 1 to 100 - !guess <number>
    return
  }
  if (%g !isnum) { ns.bot.reply %c %n guess a number from 1 to 100: !guess <number> | return }
  hinc -m ns.game $+(%k,.t)
  if (%g < %secret) ns.bot.reply %c %n %g is too low.
  elseif (%g > %secret) ns.bot.reply %c %n %g is too high.
  else {
    ns.bot.reply %c %n %n got it! The number was %secret - $hget(ns.game,$+(%k,.t)) guesses. !guess starts a new game.
    hdel ns.game %k
    hdel ns.game $+(%k,.t)
  }
}
alias ns.game.rps {
  var %me = $gettok(rock paper scissors,$rand(1,3),32), %you = $lower($3), %r
  if (!$istok(rock paper scissors,%you,32)) { ns.bot.reply $1 $2 usage: !rps rock, paper or scissors | return }
  if (%me == %you) %r = a draw.
  elseif ($+(%you,>,%me) isin rock>scissors paper>rock scissors>paper) %r = you win!
  else %r = I win!
  ns.bot.reply $1 $2 I chose %me - %r
}
alias ns.game.words return planet rocket bridge castle jungle puzzle garden silver thunder window pirate dragon canyon whisper marble harbor island lantern meadow orchard pencil quartz ribbon shadow temple velvet wizard yellow zephyr anchor beacon candle desert ember falcon glacier hammer ivory jigsaw kettle legend magnet nectar oyster pepper quiver river saddle tunnel unicorn violin walnut
alias ns.game.mask {
  var %w = $1, %g = $2, %i = 1, %o, %ch
  while (%i <= $len(%w)) {
    %ch = $mid(%w,%i,1)
    %o = %o $iif($pos(%g,%ch),%ch,$chr(95))
    inc %i
  }
  return $ns.trim(%o)
}
alias ns.game.hang {
  var %c = $1, %n = $2, %k = $+($ns.x.key(%c),.hang), %w = $hget(ns.game,%k)
  if (%w == $null) {
    %w = $gettok($ns.game.words,$rand(1,$numtok($ns.game.words,32)),32)
    hadd -m ns.game %k %w
    hadd -m ns.game $+(%k,.g) $null
    hadd -m ns.game $+(%k,.m) 0
    ns.bot.reply %c %n hangman: $ns.game.mask(%w,$null) $+ $chr(32) $+ $chr(40) $+ $len(%w) letters, 6 misses allowed $+ $chr(41) $+ $chr(32) $+ - !h <letter>
    return
  }
  ns.bot.reply %c %n hangman: $ns.game.mask(%w,$hget(ns.game,$+(%k,.g))) $+ $chr(32) $+ $chr(40) $+ $hget(ns.game,$+(%k,.m)) $+ /6 missed $+ $iif($hget(ns.game,$+(%k,.g)),$chr(44) tried $hget(ns.game,$+(%k,.g))) $+ $chr(41)
}
alias ns.game.hangletter {
  var %c = $1, %n = $2, %l = $lower($left($3,1)), %k = $+($ns.x.key(%c),.hang), %w = $hget(ns.game,%k), %g = $hget(ns.game,$+(%k,.g)), %m
  if (%w == $null) { ns.bot.reply %c %n no game running - !hangman starts one. | return }
  if (!$regex(ns.hl,%l,/^[a-z]$/)) { ns.bot.reply %c %n give one letter: !h e | return }
  if ($pos(%g,%l)) { ns.bot.reply %c %n %l was already tried. | return }
  %g = %g $+ %l
  hadd -m ns.game $+(%k,.g) %g
  if (!$pos(%w,%l)) {
    hinc -m ns.game $+(%k,.m)
    %m = $hget(ns.game,$+(%k,.m))
    if (%m >= 6) {
      ns.bot.reply %c %n out of misses! The word was %w $+ . !hangman starts again.
      hdel ns.game %k
      return
    }
  }
  if ($ns.game.mask(%w,%g) == $ns.game.mask(%w,%w)) {
    ns.bot.reply %c %n %n solved it: %w $+ ! !hangman starts again.
    hdel ns.game %k
    return
  }
  ns.game.hang %c %n
}
