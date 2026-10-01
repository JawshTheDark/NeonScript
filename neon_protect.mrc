; ============================================================================
;  NeonScript 2026  ::  protection
;  Userlist (auto owner/admin/op/halfop/voice, auto-kick, protected), flood /
;  CTCP-flood / mass-highlight / banned-word / PM-spam / clone protection.
;
;  Rank rules everywhere: NeonScript never kicks anyone holding halfop (%) or
;  higher, never touches users flagged "protected", only grants modes the
;  server supports (PREFIX) and that your own rank allows, and needs at least
;  halfop itself before it tries to kick.
; ============================================================================

; ---------------------------------------------------------------- access list (access.ini)
alias ns.acc.ini return $+($scriptdir,access.ini)
alias ns.acc.ids {
  var %i = 1, %o
  while ($ini($ns.acc.ini,%i)) {
    %o = %o $v1
    inc %i
  }
  return %o
}
alias ns.acc.get {
  var %v = $readini($ns.acc.ini,n,$1,$2)
  if ($len(%v) == 0) return $3-
  return %v
}
alias ns.acc.set {
  if ($3- == $null) writeini -nz $qt($ns.acc.ini) $1 $2
  else writeini -n $qt($ns.acc.ini) $1 $2 $3-
}
alias ns.acc.newid {
  var %n = 1
  while ($ini($ns.acc.ini,$+(u,%n))) inc %n
  return $+(u,%n)
}
; ns.acc.add <mask|nick> <flags> [channels]   e.g. ns.acc.add Nova ov #neon
alias ns.acc.add {
  var %id = $ns.acc.newid
  ns.acc.set %id mask $1
  ns.acc.set %id flags $2
  ns.acc.set %id chans $iif($3,$3,*)
  ns.acc.set %id note $4-
  return %id
}
; does entry <id> apply to <nick> on <chan>?
alias ns.acc.applies {
  var %id = $1, %n = $2, %c = $3, %m = $ns.acc.get(%id,mask), %ch = $ns.acc.get(%id,chans,*), %full = $address(%n,5), %ok = 0, %k = 1
  if (!%m) return 0
  if ($pos(%m,!)) || ($pos(%m,@)) {
    if (%m iswm %full) %ok = 1
  }
  elseif (%m iswm %n) %ok = 1
  if (!%ok) return 0
  if (%ch == *) return 1
  while ($gettok(%ch,%k,44)) {
    if ($v1 iswm %c) return 1
    inc %k
  }
  return 0
}
; union of the flags of every entry that applies
alias ns.acc.flags {
  var %i = 1, %o, %id
  while ($gettok($ns.acc.ids,%i,32)) {
    %id = $v1
    if ($ns.acc.applies(%id,$1,$2)) %o = %o $+ $ns.acc.get(%id,flags)
    inc %i
  }
  return %o
}
; a user NeonScript must leave alone: protected flag, halfop or higher, or me
alias ns.acc.safe {
  if ($1 == $me) return 1
  if ($pos($ns.acc.flags($1,$2),p)) return 1
  if ($ns.rk.atleast($2,$1,h)) return 1
  if ($ns.rk.atleast($2,$1,o)) return 1
  return 0
}

; ---------------------------------------------------------------- auto grant on join
on *:JOIN:#:{
  if ($nick == $me) return
  if ($ns.bnc.q) return
  if ($ns.flag(protect,autoop,1)) .timer -o 1 1 scid $cid ns.acc.apply $chan $nick
  if ($ns.flag(protect,clonewarn,0)) ns.clone.check $chan $nick
}
alias ns.acc.apply {
  var %c = $1, %n = $2, %f = $ns.acc.flags(%n,%c), %i = 1, %l, %give
  if (!$ns.ischan(%c)) || (!$nick(%c,%n)) || (%f == $null) return
  if ($pos(%f,k)) && ($ns.rk.cankick(%c)) && (!$pos(%f,p)) {
    ns.say auto-kick: $+($chr(2),%n,$chr(2)) is on your userlist in %c
    ns.sl.tag %c userlist
    ban -k %c %n 2 You are not welcome here.
    return
  }
  ; grant every flagged privilege the server supports, I may grant, and they do not yet hold
  while (%i <= 5) {
    %l = $mid(qaohv,%i,1)
    if ($pos(%f,%l)) && ($pos($ns.rk.modes,%l)) && ($ns.rk.cangive(%c,%l)) && (!$ns.rk.has(%c,%n,%l)) %give = %give $+ %l
    inc %i
  }
  if (!%give) return
  ns.sl.tag %c userlist
  var %nicks = %n, %k = 1
  while (%k < $len(%give)) {
    %nicks = %nicks %n
    inc %k
  }
  mode %c + $+ %give %nicks
  ns.dbg autogrant %c %n %give
}
; /ao /aa /aq /ah /av nick [#chan]   add to userlist (grants immediately when possible)
alias ns.acc.quick {
  var %l = $1, %n = $2, %c = $iif($3,$3,$iif($ns.ischan($active),$active,*))
  if (!%n) {
    ns.err usage: /a $+ $ns.rk.char(%l) nick [#channel]
    return
  }
  if (!$pos($ns.rk.modes,%l)) && ($status == connected) ns.say heads up: this server does not list mode %l ( $+ $ns.rk.lname(%l) $+ ) in PREFIX.
  var %m = $ns.mask(%n)
  ns.acc.add %m %l %c auto- $+ $ns.rk.lname(%l) $+ $chr(32) $+ added $date
  ns.say added $+($chr(2),%n,$chr(2)) to the userlist as auto- $+ $ns.rk.lname(%l) $+ $chr(32) $+ ( $+ $ns.rk.glyph($ns.rk.char(%l)) $+ ) on %c
  if ($ns.ischan(%c)) .timer -o 1 0 ns.acc.apply %c %n
}

; ---------------------------------------------------------------- flood protection
alias -l flcount {
  ; flcount <key> <secs> -> number of events in the current window
  if (!$hget(ns.fl,$1)) hadd -mu $+ $2 ns.fl $1 1
  else hinc -m ns.fl $1
  return $hget(ns.fl,$1)
}
alias ns.flood.hit {
  ; ns.flood.hit <chan> <nick> [action]   (the action defaults to the global one; a channel can have its own)
  var %c = $1, %n = $2, %act = $iif($3,$3,$ns.get(protect,flood_action,ignore))
  if (%n == $me) return
  hdel ns.fl $+($cid,.,%c,.,%n)
  if (%act == ignore) || (%act == both) {
    ignore -tu300 $address(%n,2)
    ns.say flood from $+($chr(2),%n,$chr(2)) in %c - ignored for 5 minutes.
  }
  if (%act == kick) || (%act == both) {
    if ($ns.acc.safe(%n,%c)) { ns.say flood from %n in %c - not kicked (rank or protected). | return }
    ns.sl.tag %c flood
    if ($ns.rk.cankick(%c)) kick %c %n Flooding - please slow down.
    else ns.say flood from %n in %c - I cannot kick here (need halfop or higher).
  }
}
; flood limits: the global ones (Control Panel > Protection), or this channel's own (Channel Control > Protection):
;   flood_on = 0 use the global limit, 1 use this channel's own lines/seconds/action, 2 no flood protection here
alias -l fltext {
  if ($ns.bnc.q) return
  if ($1 == $me) return
  var %own = $ns.ch.get($2,flood_on,0), %lim = $ns.get(protect,flood_lines,6), %secs = $ns.get(protect,flood_secs,4), %act
  if (%own == 2) return
  if (%own == 1) {
    %lim = $ns.ch.get($2,flood_lines,%lim)
    %secs = $ns.ch.get($2,flood_secs,%secs)
    %act = $ns.ch.get($2,flood_action)
  }
  elseif (!$ns.flag(protect,flood,0)) return
  if ($flcount($+($cid,.,$2,.,$1),%secs) >= %lim) ns.flood.hit $2 $1 %act
}
on *:TEXT:*:#:{
  if ($ns.bnc.q) return
  fltext $nick $chan
  ; mass highlight
  if ($ns.flag(protect,masshl,0)) && ($ns.rk.cankick($chan)) && (!$ns.acc.safe($nick,$chan)) {
    var %i = 1, %hits = 0, %w
    while ($gettok($1-,%i,32) != $null) {
      %w = $remove($v1,:,$chr(44),@,%,&,~,+)
      if (%w) && ($nick($chan,%w)) inc %hits
      inc %i
    }
    if (%hits >= $ns.get(protect,masshl_n,6)) {
      ns.sl.tag $chan protect
      kick $chan $nick Mass highlighting.
    }
  }
  ; banned words
  if ($ns.flag(protect,badwords,0)) && ($ns.rk.cankick($chan)) && (!$ns.acc.safe($nick,$chan)) {
    var %f = $ns.data(badwords.txt), %k = 1, %bw
    while (%k <= $lines(%f)) {
      %bw = $read(%f,n,%k)
      if (%bw) && ($+(*,%bw,*) iswm $1-) {
        ns.sl.tag $chan protect
        kick $chan $nick Watch your language.
        break
      }
      inc %k
    }
  }
}
on *:ACTION:*:#:{ fltext $nick $chan }
on *:NOTICE:*:#:{ fltext $nick $chan }

; ---------------------------------------------------------------- CTCP flood + PM spam
; (mIRC's CTCP events are "ctcp <level>:<text>:<*|#|?>:" lines - there is no "on CTCP")
ctcp *:*:*:{
  if (!$ns.flag(protect,ctcpflood,1)) return
  if ($nick == $me) return
  if ($flcount($+($cid,.ctcp.,$nick),8) >= 5) {
    ignore -tu120 $address($nick,2)
    ns.say CTCP flood from $+($chr(2),$nick,$chr(2)) - ignored for 2 minutes.
    halt
  }
}
on ^*:TEXT:*:?:{
  if ($isalias(ns.bnc.skipping)) && ($ns.bnc.skipping($nick,$md5($1-))) return
  if (!$ns.flag(protect,pmspam,1)) return
  if ($query($nick)) return
  if ($ns.acc.get($ns.acc.firstid($nick),flags) != $null) return
  if ($regex($1-,/(?i)(https?:\/\/|www\.|\bjoin\b|\bfree\b).*(#[^\s]+)|(#[^\s]+).*(https?:\/\/|www\.)/)) {
    echo -cat info $+($ns.ec(kick),$ns.sym(ctcp),$ns.o) $+($ns.ec(label),possible spam from,$ns.o) $+($ns.b,$nick,$ns.b) $+ $chr(58) $+ $ns.ec(dim) $1- $+ $ns.o
  }
}
alias ns.acc.firstid {
  var %i = 1
  while ($gettok($ns.acc.ids,%i,32)) {
    if ($ns.acc.applies($v1,$1,*)) return $v1
    inc %i
  }
  return $null
}

; ---------------------------------------------------------------- clones
alias ns.clone.check {
  var %h = $address($2,2), %cnt = $ialchan(%h,$1,0)
  if (%cnt >= 2) ns.say clone alert in $1 $+ : $+($chr(2),$2,$chr(2)) shares a host with $calc(%cnt - 1) other user(s) ( $+ $gettok(%h,2,64) $+ ).
}

; ---------------------------------------------------------------- Userlist dialog
alias neon.users ns.dlg ns_users ns_users
dialog ns_users {
  title "Userlist"
  size -1 -1 300 206
  option dbu
  icon 1, 0 0 300 30, $mircexe, 0, noborder
  list 2, 6 36 112 134, size vsbar
  text "Nick or address mask (nick!user@host, wildcards ok):", 3, 126 36 168 9
  edit "", 4, 126 46 168 11, autohs
  text "Channels (* = every channel, or #a,#b):", 5, 126 62 168 9
  edit "", 6, 126 72 168 11, autohs
  box "Automatically on join", 7, 126 88 168 68
  check "~ owner  (+q)", 10, 134 100 74 9
  check "&& admin  (+a)", 11, 134 112 74 9
  check "@ op  (+o)", 12, 134 124 74 9
  check "% halfop  (+h)", 13, 214 100 74 9
  check "+ voice  (+v)", 14, 214 112 74 9
  check "Auto-kick", 15, 214 124 74 9
  check "Protected from NeonScript's kicks", 16, 134 138 154 9
  text "Note:", 8, 126 162 24 9
  edit "", 9, 152 160 142 11, autohs
  button "New", 20, 6 176 34 13
  button "Save", 21, 44 176 34 13, default
  button "Delete", 22, 82 176 36 13
  button "Add selected nick...", 23, 126 178 76 13
  button "Close", 24, 246 188 48 13, ok cancel
  text "Modes the server does not support are greyed out while connected.", 25, 6 194 200 9
}
alias -l ulabel {
  var %m = $ns.acc.get($1,mask), %f = $ns.acc.get($1,flags), %o
  return %m $+ $chr(32) $+ $chr(91) $+ %f $+ $chr(93)
}
alias -l ufill {
  var %i = 1, %sel = $did(ns_users,2).sel
  did -r ns_users 2
  while ($gettok($ns.acc.ids,%i,32)) {
    did -a ns_users 2 $ulabel($v1)
    inc %i
  }
  if (%sel) && (%sel <= $did(ns_users,2).lines) did -c ns_users 2 %sel
}
alias -l uclear {
  did -r ns_users 4,6,9
  did -ra ns_users 6 *
  did -u ns_users 10,11,12,13,14,15,16
  set -u3600 %ns.ucur $null
}
alias -l uload {
  var %id = $1, %f = $ns.acc.get(%id,flags)
  set -u3600 %ns.ucur %id
  did -ra ns_users 4 $ns.acc.get(%id,mask)
  did -ra ns_users 6 $ns.acc.get(%id,chans,*)
  did -ra ns_users 9 $ns.acc.get(%id,note)
  did $iif($pos(%f,q),-c,-u) ns_users 10
  did $iif($pos(%f,a),-c,-u) ns_users 11
  did $iif($pos(%f,o),-c,-u) ns_users 12
  did $iif($pos(%f,h),-c,-u) ns_users 13
  did $iif($pos(%f,v),-c,-u) ns_users 14
  did $iif($pos(%f,k),-c,-u) ns_users 15
  did $iif($pos(%f,p),-c,-u) ns_users 16
}
on *:DIALOG:ns_users:init:*:{
  did -g ns_users 1 $ns.asset(header_users.png)
  ufill
  ; grey out modes this server does not have (only meaningful while connected)
  if ($status == connected) {
    var %i = 1, %l
    while (%i <= 5) {
      %l = $mid(qaohv,%i,1)
      if (!$pos($ns.rk.modes,%l)) did -b ns_users $calc(9 + %i)
      inc %i
    }
  }
  if ($ns.acc.ids) {
    did -c ns_users 2 1
    uload $gettok($ns.acc.ids,1,32)
  }
  else uclear
}
on *:DIALOG:ns_users:sclick:2:{
  var %id = $gettok($ns.acc.ids,$did(ns_users,2).sel,32)
  if (%id) uload %id
}
on *:DIALOG:ns_users:sclick:20:{
  uclear
  did -f ns_users 4
}
on *:DIALOG:ns_users:sclick:21:{
  var %mask = $did(ns_users,4).text
  if (!%mask) return
  var %id = %ns.ucur
  if (!%id) %id = $ns.acc.newid
  var %fl = $iif($did(ns_users,10).state,q) $+ $iif($did(ns_users,11).state,a) $+ $iif($did(ns_users,12).state,o) $+ $iif($did(ns_users,13).state,h) $+ $iif($did(ns_users,14).state,v) $+ $iif($did(ns_users,15).state,k) $+ $iif($did(ns_users,16).state,p)
  ns.acc.set %id mask %mask
  ns.acc.set %id flags %fl
  ns.acc.set %id chans $iif($did(ns_users,6).text != $null,$did(ns_users,6).text,*)
  ns.acc.set %id note $did(ns_users,9).text
  set -u3600 %ns.ucur %id
  ufill
  did -c ns_users 2 $findtok($ns.acc.ids,%id,1,32)
}
on *:DIALOG:ns_users:sclick:22:{
  var %id = %ns.ucur
  if (!%id) return
  remini $qt($ns.acc.ini) %id
  ufill
  if ($ns.acc.ids) {
    did -c ns_users 2 1
    uload $gettok($ns.acc.ids,1,32)
  }
  else uclear
}
on *:DIALOG:ns_users:sclick:23:{
  ; adopt the nick currently selected in the active channel's nicklist
  var %n = $snick($active,1)
  if (!%n) {
    ns.err select a nickname in the channel's nick list first.
    return
  }
  uclear
  did -ra ns_users 4 $ns.mask(%n)
  did -ra ns_users 9 added $date
}

; ---------------------------------------------------------------- banned words dialog
alias neon.words ns.dlg ns_words ns_words
dialog ns_words {
  title "Banned words"
  size -1 -1 200 150
  option dbu
  text "People who say any of these (anywhere in a line) are kicked, if protection is on and you are at least halfop. Wildcards work.", 1, 6 6 188 22
  list 2, 6 32 188 80, size vsbar
  edit "", 3, 6 116 140 11, autohs
  button "Add", 4, 150 115 44 13, default
  button "Remove selected", 5, 6 132 70 13
  button "Close", 6, 146 132 48 13, ok cancel
}
on *:DIALOG:ns_words:init:*:{
  var %f = $ns.data(badwords.txt), %i = 1
  while (%i <= $lines(%f)) {
    did -a ns_words 2 $read(%f,n,%i)
    inc %i
  }
}
alias -l wsave {
  var %f = $ns.data(badwords.txt), %i = 1
  write -c $qt(%f)
  while (%i <= $did(ns_words,2).lines) {
    write $qt(%f) $did(ns_words,2,%i)
    inc %i
  }
}
on *:DIALOG:ns_words:sclick:4:{
  var %w = $did(ns_words,3).text
  if (!%w) return
  did -a ns_words 2 %w
  did -r ns_words 3
  wsave
}
on *:DIALOG:ns_words:sclick:5:{
  var %n = $did(ns_words,2).sel
  if (!%n) return
  did -d ns_words 2 %n
  wsave
}
