; ============================================================================
;  NeonScript 2026  ::  alias pack, hotkeys and popup menus
;  Everything privilege-related understands owner (~), admin (&), op (@),
;  halfop (%) and voice (+): commands check what the server supports (PREFIX)
;  and what YOUR rank lets you grant before they try.
; ============================================================================

; ---------------------------------------------------------------- take over the stock alias file (only if untouched)
; mIRC's default aliases.ini defines /op /dop /j /p /n /w /k /q /send /chat /ping /s.  Alias files
; win over script aliases, so ours would never run.  If a definition still starts with its stock
; command we remove it (anything you customised is left alone).  The stock text is written without
; the $ placeholders because mIRC would evaluate them inside this script.
alias ns.alias.takeover {
  var %list = op dop j p n w k q send chat ping s, %i = 1, %name, %def, %stock
  while ($gettok(%list,%i,32)) {
    %name = $v1
    if ($isalias(%name)) && ($isalias(%name).ftype == alias) {
      %def = $isalias(%name).alias
      %stock = $ns.alias.stock(%name)
      if ($left(%def,$len(%stock)) == %stock) || ($left(%def,$calc($len(%stock) + $len(%name) + 2)) == $+(/,%name,$chr(32),%stock)) {
        .mkdir $qt($ns.bakdir)
        if ($readini($ns.stock.alfile,n,aliases,%name) == $null) writeini -n $qt($ns.stock.alfile) aliases %name %def
        alias $+(/,%name)
        ns.dbg took over stock alias /name
      }
    }
    inc %i
  }
}
alias ns.alias.stock {
  var %n = $1
  if (%n == op) return /mode # +ooo
  if (%n == dop) return /mode # -ooo
  if (%n == j) return /join #
  if (%n == p) return /part #
  if (%n == n) return /names #
  if (%n == w) return /whois
  if (%n == k) return /kick #
  if (%n == q) return /query
  if (%n == send) return /dcc send
  if (%n == chat) return /dcc chat
  if (%n == ping) return /ctcp
  if (%n == s) return /server
  return $null
}
on *:SIGNAL:ns.boot:{
  ns.alias.takeover
  ns.menus.takeover
}

; ---------------------------------------------------------------- shortcuts
alias j {
  var %c = $1
  if (!%c) {
    ns.err usage: /j <channel> [key]
    return
  }
  if ($left(%c,1) !isin $remove($chantypes,CHANTYPES=)) %c = $chr(35) $+ %c
  join %c $2-
}
alias p {
  var %c = $iif($ns.ischan($1),$1,$active), %m = $iif($ns.ischan($1),$2-,$1-)
  if (!$ns.ischan(%c)) {
    ns.err usage: /p [#channel] [message]
    return
  }
  if (%m == $null) %m = $ns.msg(part)
  part %c %m
}
alias cycle {
  var %c = $iif($ns.ischan($1),$1,$active)
  if (!$ns.ischan(%c)) return
  part %c Cycling
  .timer -o 1 1 join %c
}
alias n names $iif($1,$1,$active)
alias w whois $$1 $$1
alias q query $$1 $2-
alias cl clear
alias clr clearall
alias ver ctcp $$1 version
alias ping ctcp $$1 ping
alias lag ns.say lag to $server $+ : $+($ns.b,$ns.lag,$ns.b)
alias up uptime
alias send dcc send $1 $2-
alias chat dcc chat $1
alias ign {
  if (!$1) {
    ns.err usage: /ign <nick>
    return
  }
  ns.ig.add $ns.mask($1) pcnti all 3600 quick ignore (menu)
  ns.say ignoring $+($ns.b,$1,$ns.b) for an hour. /neon ignores manages the list.
}
alias unign {
  if (!$1) {
    ns.err usage: /unign <nick>
    return
  }
  neon unignore $1
}
; services shortcuts
alias ns msg NickServ $$1-
alias cs msg ChanServ $$1-
alias ms msg MemoServ $$1-
alias hs msg HostServ $$1-
alias bs msg BotServ $$1-
alias os msg OperServ $$1-
alias identify msg NickServ IDENTIFY $$1-
alias ghost msg NickServ GHOST $$1-
alias recover msg NickServ RECOVER $$1-

; ---------------------------------------------------------------- kick / ban helpers (rank aware)
alias k {
  var %c = $iif($ns.ischan($1),$1,$active), %nk = $iif($ns.ischan($1),$2,$1), %r = $iif($ns.ischan($1),$3-,$2-)
  if (!$ns.ischan(%c)) || (!%nk) {
    ns.err usage: /k [#channel] <nick> [reason]
    return
  }
  if (!$ns.rk.cankick(%c)) {
    ns.err you need halfop or higher in %c
    return
  }
  if ($ns.rk.outranks(%c,%nk,$me)) {
    ns.err %nk outranks you - the server would refuse.
    return
  }
  if (%r == $null) %r = $ns.msg(kick)
  kick %c %nk %r
}
alias kb {
  var %c = $iif($ns.ischan($1),$1,$active), %nk = $iif($ns.ischan($1),$2,$1), %r = $iif($ns.ischan($1),$3-,$2-)
  if (!$ns.ischan(%c)) || (!%nk) {
    ns.err usage: /kb [#channel] <nick> [reason]
    return
  }
  if (!$ns.rk.cankick(%c)) {
    ns.err you need halfop or higher in %c
    return
  }
  if ($ns.rk.outranks(%c,%nk,$me)) {
    ns.err %nk outranks you - the server would refuse.
    return
  }
  if (%r == $null) %r = $ns.msg(kick)
  ban -k %c %nk $ns.get(kb,bantype,2) %r
}
alias b {
  var %c = $iif($ns.ischan($1),$1,$active), %nk = $iif($ns.ischan($1),$2,$1)
  if (!$ns.ischan(%c)) || (!%nk) {
    ns.err usage: /b [#channel] <nick>
    return
  }
  ban %c %nk $ns.get(kb,bantype,2)
}
alias ub {
  var %c = $iif($ns.ischan($1),$1,$active), %nk = $iif($ns.ischan($1),$2,$1)
  if (!$ns.ischan(%c)) || (!%nk) {
    ns.err usage: /ub [#channel] <nick>
    return
  }
  ban -r %c %nk $ns.get(kb,bantype,2)
}

; ---------------------------------------------------------------- privileges: ~ & @ % +
; ns.priv <+|-> <q|a|o|h|v> <nick> [nick ...]   works on the active channel
alias ns.priv {
  var %sign = $1, %l = $2, %c = $active, %list = $3-
  if (!$ns.ischan(%c)) {
    ns.err use this in a channel window.
    return
  }
  if (!%list) {
    ns.err give at least one nickname.
    return
  }
  if (!$pos($ns.rk.modes,%l)) {
    ns.err this server has no $ns.rk.lname(%l) mode ( $+ $ns.rk.char(%l) $+ ).
    return
  }
  if (!$ns.rk.cangive(%c,%l)) {
    ns.err you do not have the rank to change $ns.rk.lname(%l) $+ s in %c $+ .
    return
  }
  var %per = $iif($modespl > 0,$modespl,4), %i = 1, %n = $numtok(%list,32), %j, %chunk
  while (%i <= %n) {
    %j = $calc(%i + %per - 1)
    %chunk = $gettok(%list,$+(%i,-,%j),32)
    mode %c %sign $+ $str(%l,$numtok(%chunk,32)) %chunk
    %i = $calc(%j + 1)
  }
}
alias op ns.priv + o $$1-
alias deop ns.priv - o $$1-
alias dop ns.priv - o $$1-
alias hp ns.priv + h $$1-
alias dhp ns.priv - h $$1-
alias voice ns.priv + v $$1-
alias v ns.priv + v $$1-
alias devoice ns.priv - v $$1-
alias dv ns.priv - v $$1-
alias adm ns.priv + a $$1-
alias deadm ns.priv - a $$1-
alias own ns.priv + q $$1-
alias disown ns.priv - q $$1-

; userlist quick-add:  /aq /aa /ao /ah /av nick [#chan]   /ak nick   /ua nick
alias aq ns.acc.quick q $1-
alias aa ns.acc.quick a $1-
alias ao ns.acc.quick o $1-
alias ah ns.acc.quick h $1-
alias av ns.acc.quick v $1-
alias ak {
  if (!$1) {
    ns.err usage: /ak <nick> [#channel]
    return
  }
  var %m = $ns.mask($1)
  ns.acc.add %m k $iif($2,$2,$iif($ns.ischan($active),$active,*)) auto-kick added $date
  ns.say auto-kick set for $+($ns.b,$1,$ns.b)
}
alias ua {
  if (!$1) {
    ns.err usage: /ua <nick or mask>
    return
  }
  var %i = 1, %id, %gone = 0, %m
  while ($gettok($ns.acc.ids,%i,32)) {
    %id = $v1
    %m = $ns.acc.get(%id,mask)
    if (%m iswm $1) || ($1 iswm %m) || (%m == $address($1,2)) {
      remini $qt($ns.acc.ini) %id
      inc %gone
    }
    inc %i
  }
  ns.say removed %gone userlist entr $+ $iif(%gone == 1,y,ies) matching $1
}

; ---------------------------------------------------------------- function keys (edit them with /neon hotkeys)
alias F1 ns.fk.run F1 $1
alias F2 ns.fk.run F2 $1
alias F3 ns.fk.run F3 $1
alias F4 ns.fk.run F4 $1
alias F5 ns.fk.run F5 $1
alias F6 ns.fk.run F6 $1
alias F7 ns.fk.run F7 $1
alias F8 ns.fk.run F8 $1
alias F9 ns.fk.run F9 $1
alias F10 ns.fk.run F10 $1
alias F11 ns.fk.run F11 $1
alias F12 ns.fk.run F12 $1
alias sF1 ns.fk.run sF1 $1
alias sF2 ns.fk.run sF2 $1
alias sF3 ns.fk.run sF3 $1
alias sF4 ns.fk.run sF4 $1
alias sF5 ns.fk.run sF5 $1
alias sF6 ns.fk.run sF6 $1
alias sF7 ns.fk.run sF7 $1
alias sF8 ns.fk.run sF8 $1
alias sF9 ns.fk.run sF9 $1
alias sF10 ns.fk.run sF10 $1
alias sF11 ns.fk.run sF11 $1
alias sF12 ns.fk.run sF12 $1
alias cF1 ns.fk.run cF1 $1
alias cF2 ns.fk.run cF2 $1
alias cF3 ns.fk.run cF3 $1
alias cF4 ns.fk.run cF4 $1
alias cF5 ns.fk.run cF5 $1
alias cF6 ns.fk.run cF6 $1
alias cF7 ns.fk.run cF7 $1
alias cF8 ns.fk.run cF8 $1
alias cF9 ns.fk.run cF9 $1
alias cF10 ns.fk.run cF10 $1
alias cF11 ns.fk.run cF11 $1
alias cF12 ns.fk.run cF12 $1

; ---------------------------------------------------------------- stock right-click menus
; mIRC ships default menus for the nick list, channel, query and status windows (Info / Whois / Query /
; Control > / CTCP > / DCC > / Slap! ...).  NeonScript has its own, organised into categories, and
; showing both gives a long list with duplicates.  So - once, and only for a menu that is still exactly
; mIRC's original - the stock one is switched off by loading an empty popup file in its place.
; Anything you customised yourself is left alone.  /neon menus off (or /neon repair stock) brings the
; originals back: they are never deleted, mIRC is just pointed back at its own popups file.
alias ns.menus.types return c q n s
alias ns.menus.section {
  if ($1 == c) return cpopup
  if ($1 == q) return qpopup
  if ($1 == n) return lpopup
  if ($1 == s) return mpopup
  return $null
}
; SHA-256 of mIRC's original definition of each menu (the lines joined with chr(1))
alias ns.menus.stockfp {
  if ($1 == c) return b65627a107c5f530df3b345853b11412f37254e57c4c76d5605daab6a1ebee0d
  if ($1 == q) return 1fa3fbebb6e8be00a394d5fb5865f4a1668a5845c54419425d73e8b2c54b44e7
  if ($1 == n) return 04a857777efe1ce391800dfea2692fca39cbdc333182eb5a5cdd678960350d76
  if ($1 == s) return 09d574e42ed9fb55f05ef724ccf62b22caf907049746288eed2b21883a0e4cb2
  return $null
}
alias ns.menus.fp {
  var %i = 0, %v = $readini($1,n,$2,n0), %t = %v
  if (%v == $null) return $null
  inc %i
  %v = $readini($1,n,$2,$+(n,%i))
  while (%v != $null) {
    %t = %t $+ $chr(1) $+ %v
    inc %i
    %v = $readini($1,n,$2,$+(n,%i))
  }
  return $sha256(%t)
}
alias ns.menus.takeover {
  if (!$ns.flag(menus,takeover,1)) return
  var %i = 0, %paths, %p, %t, %k, %f, %sec, %n = 0, %j = 1
  while (%i < 6) {
    %p = $readini($mircini,n,pfiles,$+(n,%i))
    inc %i
    if (%p != $null) && (!$istok(%paths,%p,124)) %paths = %paths $+ $iif(%paths,$chr(124)) $+ %p
  }
  while ($gettok($ns.menus.types,%j,32) != $null) {
    %t = $gettok($ns.menus.types,%j,32)
    inc %j
    if ($ns.get(menus,$+(took_,%t)) == 1) continue
    %sec = $ns.menus.section(%t)
    %k = 1
    while ($gettok(%paths,%k,124) != $null) {
      %f = $gettok(%paths,%k,124)
      inc %k
      if ($mid(%f,2,1) != $chr(58)) %f = $+($mircdir,%f)
      if (!$exists(%f)) continue
      if ($ns.menus.fp(%f,%sec) == $ns.menus.stockfp(%t)) {
        ns.set menus $+(stock_,%t) %f
        .load $+(-p,%t) $qt($ns.data(popups_none.ini))
        ns.set menus $+(took_,%t) 1
        inc %n
        break
      }
    }
  }
  if (%n) ns.log menus replaced %n stock popup menu(s)
}
; give mIRC its own menus back; returns how many were restored
alias ns.menus.restore {
  var %j = 1, %t, %f, %n = 0
  while ($gettok($ns.menus.types,%j,32) != $null) {
    %t = $gettok($ns.menus.types,%j,32)
    inc %j
    %f = $ns.get(menus,$+(stock_,%t))
    if (%f != $null) && ($exists(%f)) {
      .load $+(-p,%t) $qt(%f)
      inc %n
    }
    ns.del menus $+(took_,%t)
  }
  ns.set menus takeover 0
  return %n
}
; /neon menus [on|off|status]
alias neon.menus {
  var %c = $lower($1), %n = 0, %j = 1
  if (%c == off) {
    ns.say mIRC's own right-click menus are back ( $+ $ns.menus.restore $+ ) - they show next to NeonScript's. Restart mIRC if they do not appear.
    return
  }
  if (%c == on) {
    ns.set menus takeover 1
    ns.menus.takeover
    ns.say mIRC's default right-click menus are replaced by NeonScript's.
    return
  }
  while ($gettok($ns.menus.types,%j,32) != $null) {
    if ($ns.get(menus,$+(took_,$gettok($ns.menus.types,%j,32))) == 1) inc %n
    inc %j
  }
  ns.say stock right-click menus replaced: %n of $numtok($ns.menus.types,32) $+ . Use /neon menus on or off.
}

; ---------------------------------------------------------------- popup menus
; Organised into categories (. and .. submenus).  Privilege items only show when the server supports that
; mode and your rank allows it, and the Give / Take label follows what the nick already holds.

; "Give op (@)" / "Take op (@)" for letter $1 on nick $2 - empty when the server lacks the mode or I may not
; (the admin symbol is an ampersand, which a menu label would swallow as an accelerator key: ns.esc doubles it)
alias ns.mn.priv {
  var %l = $1, %n = $2, %c = $iif($chan,$chan,$active)
  if (!$pos($ns.rk.modes,%l)) || (!$ns.rk.cangive(%c,%l)) return $null
  return $+($iif($ns.rk.has(%c,%n,%l),Take,Give),$chr(32),$ns.rk.lname(%l),$chr(32),$chr(40),$ns.esc($ns.rk.char(%l)),$chr(41))
}
; label only when the server has a quiet mode and I may use it
alias ns.mn.q return $iif($ns.mute.kind != none && $ns.rk.cankick($iif($chan,$chan,$active)),$1-)
alias ns.mn.sign return $iif($ns.rk.has($iif($chan,$chan,$active),$2,$1),-,+)
; "Auto-op (@)" - shown when the server has that rank
alias ns.mn.auto {
  if (!$pos($ns.rk.modes,$1)) return $null
  return $+(Auto-,$ns.rk.lname($1),$chr(32),$chr(40),$ns.esc($ns.rk.char($1)),$chr(41))
}
menu nicklist {
  Whois:whois $$1 $$1
  Query:query $$1
  Slap!:slap $$1
  -
  Control
  .Kick && ban...:neon kb $chan $$1
  .Kick (random reason):k $chan $$1
  .Ban:b $chan $$1
  .$ns.mn.q(Quiet for 10 minutes):neon quiet $$1 10m
  .$ns.mn.q(Quiet until I lift it):neon quiet $$1
  .$ns.mn.q(Lift the quiet):neon unquiet $$1
  .-
  .Mass actions...:neon mass
  .-
  .Rank
  ..$ns.mn.priv(q,$1):ns.priv $ns.mn.sign(q,$1) q $$1
  ..$ns.mn.priv(a,$1):ns.priv $ns.mn.sign(a,$1) a $$1
  ..$ns.mn.priv(o,$1):ns.priv $ns.mn.sign(o,$1) o $$1
  ..$ns.mn.priv(h,$1):ns.priv $ns.mn.sign(h,$1) h $$1
  ..$ns.mn.priv(v,$1):ns.priv $ns.mn.sign(v,$1) v $$1
  Userlist
  .$ns.mn.auto(q):ns.acc.quick q $$1 $chan
  .$ns.mn.auto(a):ns.acc.quick a $$1 $chan
  .$ns.mn.auto(o):ns.acc.quick o $$1 $chan
  .$ns.mn.auto(h):ns.acc.quick h $$1 $chan
  .$ns.mn.auto(v):ns.acc.quick v $$1 $chan
  .Auto-kick:ak $$1 $chan
  .Remove from userlist:ua $$1
  .-
  .Open the userlist...:neon users
  CTCP
  .Version:ctcp $$1 version
  .Ping:ctcp $$1 ping
  .Time:ctcp $$1 time
  DCC
  .Chat:dcc chat $$1
  .Send file...:dcc send $$1
  Ignore
  .For an hour:ign $$1
  .Until I stop it:neon ignore $$1
  .Never highlight me (still show them):neon nohl $$1
  .Stop ignoring:unign $$1
  .Ignore manager...:neon ignores
}
menu channel {
  Moderation
  .Kick && ban...:neon kb $chan
  .Clone scanner:neon clones $chan
  .Userlist...:neon users
  .Who has what?:echo -cat info $ns.pfx $ns.bot.ops($chan)
  .Mass actions...:neon mass
  .Quiets I have set:neon quiets
  .Staff log...:neon stafflog
  .Channel stats...:neon stats $chan
  Tools
  .Topic templates...:neon topictpl
  .Ignore manager...:neon ignores
  .Dashboard:neon dash
  .Text effects...:neon fx
  .Symbol map...:neon chars
  .Preview a link...:preview $$?="Link to preview (http:// or https://):"
  .Emoji picker...:emoji
  .Dictate (speech to text):dictate
  Logs
  .This channel's log:neon logs here
  .Log viewer...:neon logs
  .Search all logs...:neon logs search $$?="Search every log for:"
  AI helpers (opt-in)
  .Catch me up on this channel:ai catchup
  .Look for trouble (suggestions only):ai mod
  .Plain-English command...:ai do $$?="What should be done in this channel?"
  .Translate the last line...:ai translate $$?="Translate into which language?"
  .AI settings...:ai settings
}
menu query {
  Whois:whois $$1 $$1
  Userlist
  .Add as protected:ns.acc.add $ns.mask($$1) p * protected added $date
  Ignore
  .For an hour:ign $$1
  .Until I stop it:neon ignore $$1
  .Stop ignoring:unign $$1
  .Ignore manager...:neon ignores
  Tools
  .Text effects...:neon fx
  .Emoji picker...:emoji
  .Dictate (speech to text):dictate
  Logs
  .This conversation's log:neon logs here
  .Log viewer...:neon logs
  AI helpers (opt-in)
  .Translate the last line...:ai translate $$?="Translate into which language?"
  .AI settings...:ai settings
}
menu status {
  Connect:ns.tb.connect
  Servers && networks...:neon servers
  Away...:neon away
  Mentions inbox...:neon mentions
  Bouncer dashboard...:neon bncdash
  Look
  .Themes...:neon themes
  .Dashboard:neon dash
  .Control panel...:neon
  Privacy
  .Ignore manager...:neon ignores
  .Staff log...:neon stafflog
  .Channel stats...:neon stats
  .CTCP privacy...:neon privacy
  AI helpers (opt-in)
  .Summarise my unread mentions:ai mentions
  .Ask a question...:ai ask $$?="Question for the AI service:"
  .AI settings...:ai settings
  Logs
  .Log viewer...:neon logs
  .Search all logs...:neon logs search $$?="Search every log for:"
  Maintenance
  .Self-test:neon selftest
  .Debug console:neon debug
  .Backup && restore...:neon backup
}
