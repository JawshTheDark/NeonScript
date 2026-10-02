; ============================================================================
;  NeonScript 2026  ::  chat and reading
;  * Mentions inbox      every highlight and private message, across all networks
;  * New-messages line   where you left off in a window you were not looking at
;  * Nick-list colours   by rank, away users dimmed
;  * Replies/reactions   IRCv3 message tags shown as small context lines
;
;  mIRC already negotiates server-time, message-tags and away-notify on its own when the server
;  offers them, so nothing here needs a special capability request.
;  Loaded before the other event modules so its lines come out in front of the message they describe.
; ============================================================================

; ---------------------------------------------------------------- is a window being looked at right now?
alias ns.ur.seen return $iif($appactive && $active == $1 && $activecid == $cid,1,0)

; ---------------------------------------------------------------- message events (one dispatcher per event)
; (a bouncer such as Lurker re-sends its whole buffer on every connect: lines already read on an earlier connect
;  are dropped here, before anything else sees them - see ns.bnc.dupe in neon_bnc.mrc)
on ^*:TEXT:*:#:{
  if ($isalias(ns.bnc.dupe)) && ($ns.bnc.dupe($chan,$nick,$md5($1-))) halt
  ns.chat.line $chan $nick $1-
}
on ^*:ACTION:*:#:{
  if ($isalias(ns.bnc.dupe)) && ($ns.bnc.dupe($chan,$nick,$md5($1-))) halt
  ns.chat.line $chan $nick $1-
}
on ^*:NOTICE:*:#:{
  if ($isalias(ns.bnc.dupe)) && ($ns.bnc.dupe($chan,$nick,$md5($1-))) halt
  ns.chat.line $chan $nick $1-
}
on ^*:TEXT:*:?:{
  if ($isalias(ns.bnc.dupe)) && ($ns.bnc.dupe($nick,$nick,$md5($1-))) halt
  ns.chat.line $nick $nick $1-
}
on ^*:ACTION:*:?:{
  if ($isalias(ns.bnc.dupe)) && ($ns.bnc.dupe($nick,$nick,$md5($1-))) halt
  ns.chat.line $nick $nick $1-
}
; in the other direction: a later non-^ pass for the mentions inbox (the line is already on screen)
on *:TEXT:*:#:{ ns.mi.msg c $chan $nick $1- }
on *:ACTION:*:#:{ ns.mi.msg a $chan $nick $1- }
on *:TEXT:*:?:{ ns.mi.msg p $nick $nick $1- }
on *:ACTION:*:?:{ ns.mi.msg q $nick $nick $1- }

; $1 = window  $2 = who said it  $3- = the text
alias ns.chat.line {
  if ($2 == $me) return
  if ($isalias(ns.bnc.isreplay)) && ($ns.bnc.isreplay) return
  if ($isalias(ns.bnc.real)) ns.bnc.real $1
  if ($isalias(ns.v3.edit)) ns.v3.edit $1 $2
  ns.ur.touch $1
  ns.rp.context $1 $2 $3-
  ns.rp.remember $2 $3-
}

; ---------------------------------------------------------------- "new messages" line
; The line goes in before the first message that arrives while you are away from the window, and
; not again until you have looked at the window.  Nothing is ever added to a window you are reading.
alias ns.ur.touch {
  if (!$ns.flag(chat,unread,1)) return
  var %w = $1, %k = $+($cid,.,%w)
  if (!$window(%w)) return
  if ($ns.ur.seen(%w)) return
  if ($hget(ns.ur,%k)) return
  hadd -m ns.ur %k 1
  echo -cgn info %w $+($ns.cc($ns.get(theme,accent,13)),$str($chr(9472),10),$chr(32),new messages,$chr(32),$str($chr(9472),10),$ns.o)
}
alias ns.ur.clear {
  if ($hget(ns.ur)) hdel ns.ur $+($activecid,.,$1)
}
on *:ACTIVE:*:{
  ns.ur.clear $active
  ns.mi.seen $active
}
on *:APPACTIVE:{
  if ($appactive) {
    ns.ur.clear $active
    ns.mi.seen $active
  }
}

; ---------------------------------------------------------------- mentions inbox
; ns.mi item k = <ctime> TAB <network> TAB <kind> TAB <target> TAB <nick> TAB <read 0|1> TAB <text>
;   kind: c = channel message, a = channel action, p = private message, q = private action
alias ns.mi.file return $ns.data(mentions.dat)
on *:SIGNAL:ns.boot:{
  if ($exists($ns.mi.file)) && (!$hget(ns.mi)) hload -m ns.mi $qt($ns.mi.file)
}
on *:EXIT:{ ns.mi.save }
alias ns.mi.save {
  if ($hget(ns.mi)) hsave -o ns.mi $qt($ns.mi.file)
}
; the words that count as a mention: my nicknames plus the user's own list
alias ns.mi.words return $ns.trim($replace($me $anick $ns.get(chat,mwords),$chr(44),$chr(32)))
alias ns.mi.hit {
  var %t = $regsubex($lower($strip($1-)),/[^a-z0-9_\[\]\\`^{}|-]+/g,$chr(1)), %w = $ns.mi.words, %i = 1, %x
  while ($gettok(%w,%i,32) != $null) {
    %x = $lower($gettok(%w,%i,32))
    inc %i
    if ($istok(%t,%x,1)) return 1
  }
  return 0
}
; kind target nick text...
alias ns.mi.msg {
  var %kind = $1, %tgt = $2, %nick = $3
  if (!$ns.flag(chat,mentions,1)) return
  if (%nick == $me) return
  if ($isalias(ns.bnc.q)) && ($ns.bnc.q) return
  ; a "highlights only" entry (Ignore Manager): their channel lines never count as mentions
  if (%kind isin ca) && ($isalias(ns.hl.muted)) && ($ns.hl.muted($fulladdress)) return
  if (%kind isin pq) {
    if (!$ns.flag(chat,mpm,1)) return
  }
  elseif (!$ns.mi.hit($4-)) return
  ns.mi.add %kind %tgt %nick $ns.ur.seen(%tgt) $4-
}
; kind target nick seen text...
alias ns.mi.add {
  var %n = $calc($hget(ns.mi,n) + 1), %net = $iif($network,$network,$iif($server,$server,-)), %seen = $4
  hadd -m ns.mi n %n
  hadd ns.mi %n $+($ctime,$chr(9),%net,$chr(9),$1,$chr(9),$2,$chr(9),$3,$chr(9),$iif(%seen,1,0),$chr(9),$left($remove($strip($5-),$chr(9)),300))
  if (%n > 200) hdel ns.mi $calc(%n - 200)
  if (!%seen) && ($window($2)) window -g2 $2
  ns.mi.changed
  if ($isalias(ns.win.notify)) ns.win.notify %n $1 $2 $3 %seen $5-
}
alias ns.mi.item return $hget(ns.mi,$1)
alias ns.mi.unread {
  var %n = $hget(ns.mi,n), %k = $max(1,$calc(%n - 199)), %c = 0, %v
  while (%k <= %n) {
    %v = $hget(ns.mi,%k)
    if (%v != $null) && ($gettok(%v,6,9) == 0) inc %c
    inc %k
  }
  return %c
}
; something changed: refresh the toolbar badge and the dialog, and save soon
alias ns.mi.changed {
  if ($isalias(ns.tb.resync)) ns.tb.resync
  if ($isalias(ns.ui.badge)) ns.ui.badge
  if ($dialog(ns_mi)) ns.mi.fill
  .timer.nsmisave -o 1 20 ns.mi.save
}
; the user is looking at <window>: its mentions are read
alias ns.mi.seen {
  var %w = $1, %net = $network, %n = $hget(ns.mi,n), %k = $max(1,$calc(%n - 199)), %v, %done = 0
  if (%w == $null) || (!%n) return
  while (%k <= %n) {
    %v = $hget(ns.mi,%k)
    if (%v != $null) && ($gettok(%v,6,9) == 0) && ($gettok(%v,4,9) == %w) && ($gettok(%v,2,9) == %net) {
      hadd ns.mi %k $puttok(%v,1,6,9)
      inc %done
    }
    inc %k
  }
  if (%done) ns.mi.changed
}
alias ns.mi.markall {
  var %n = $hget(ns.mi,n), %k = $max(1,$calc(%n - 199)), %v
  while (%k <= %n) {
    %v = $hget(ns.mi,%k)
    if (%v != $null) hadd ns.mi %k $puttok(%v,1,6,9)
    inc %k
  }
  ns.mi.changed
}
alias ns.mi.clear {
  if ($hget(ns.mi)) hfree ns.mi
  if ($exists($ns.mi.file)) .remove $qt($ns.mi.file)
  ns.mi.changed
}
; the connection id of a network by name ($null when not connected to it)
alias ns.mi.cid {
  var %i = 1, %n = $scon(0)
  while (%i <= %n) {
    if ($scon(%i).network == $1) || ($scon(%i).server == $1) return $scon(%i).cid
    inc %i
  }
  return $null
}
alias ns.mi.jump {
  var %v = $hget(ns.mi,$1), %net = $gettok(%v,2,9), %tgt = $gettok(%v,4,9), %cid
  if (%v == $null) return
  hadd ns.mi $1 $puttok(%v,1,6,9)
  %cid = $ns.mi.cid(%net)
  if (!%cid) {
    ns.err not connected to %net any more.
    ns.mi.changed
    return
  }
  scid %cid ns.mi.show %tgt
  ns.mi.changed
}
; (runs inside the right connection) bring a window to the front, re-opening it if it was closed
alias ns.mi.show {
  if ($window($1)) { window -a $1 | return }
  if ($left($1,1) isin #&) join $1
  else query $1
}
alias neon.mentions ns.dlg ns_mi ns_mi
alias mentions neon.mentions

dialog ns_mi {
  title "Mentions"
  size -1 -1 330 214
  option dbu
  icon 1, 0 0 330 30, $mircexe, 0, noborder
  list 2, 6 36 318 140, size vsbar hsbar
  check "Only show what I have not read yet", 3, 6 181 150 9
  text "", 7, 200 181 124 9, right
  button "Jump to it", 4, 6 195 52 13, default
  button "Mark all read", 5, 62 195 52 13
  button "Clear all", 6, 118 195 44 13
  button "Close", 8, 278 195 46 13, cancel
}
on *:DIALOG:ns_mi:init:*:{
  did -g ns_mi 1 $ns.asset(header_mentions.png)
  ns.mi.fill
}
; rebuild the list, newest first; ns.mil maps list line -> item key
alias ns.mi.fill {
  if (!$dialog(ns_mi)) return
  var %k = $hget(ns.mi,n), %low = $max(1,$calc($hget(ns.mi,n) - 199)), %v, %only = $did(ns_mi,3).state, %shown = 0, %when, %mark, %nick, %text
  did -r ns_mi 2
  if ($hget(ns.mil)) hfree ns.mil
  while (%k >= %low) {
    %v = $hget(ns.mi,%k)
    dec %k
    if (%v == $null) continue
    if (%only) && ($gettok(%v,6,9) == 1) continue
    inc %shown
    hadd -m ns.mil %shown $calc(%k + 1)
    %when = $iif($asctime($gettok(%v,1,9),yyyymmdd) == $asctime($ctime,yyyymmdd),$asctime($gettok(%v,1,9),HH:nn),$asctime($gettok(%v,1,9),ddd HH:nn))
    %mark = $iif($gettok(%v,6,9) == 0,$chr(9679),$chr(183))
    %nick = $gettok(%v,5,9)
    %text = $gettok(%v,7-,9)
    did -a ns_mi 2 $+(%mark,$chr(32),%when,$chr(32),$chr(32),$chr(91),$gettok(%v,2,9),$chr(93),$chr(32),$gettok(%v,4,9),$chr(32),$chr(32),$iif($gettok(%v,3,9) isin aq,$chr(42) $+ $chr(32) $+ %nick,$chr(60) $+ %nick $+ $chr(62)),$chr(32),%text)
  }
  did -ra ns_mi 7 $iif($ns.mi.unread,$ns.mi.unread unread,all read)
  if (%shown) did -c ns_mi 2 1
}
on *:DIALOG:ns_mi:sclick:3:{ ns.mi.fill }
on *:DIALOG:ns_mi:dclick:2:{ ns.mi.jumpsel }
on *:DIALOG:ns_mi:sclick:4:{ ns.mi.jumpsel }
on *:DIALOG:ns_mi:sclick:5:{ ns.mi.markall }
on *:DIALOG:ns_mi:sclick:6:{ ns.later ns.mi.askclear }
alias ns.mi.jumpsel {
  var %k = $hget(ns.mil,$did(ns_mi,2).sel)
  if (%k) ns.mi.jump %k
}
alias ns.mi.askclear {
  if ($input(Delete every message in the mentions inbox?,yq,Clear mentions)) ns.mi.clear
}
menu @nstb_mentions {
  Open the mentions inbox:neon mentions
  Mark all as read:ns.mi.markall
  -
  Settings...:neon options chat
}

; ---------------------------------------------------------------- nick-list colours (rank, away)
; mIRC colours a nick in the channel's nick list with /cline.  Ranks use the theme's event palette,
; away users the dim colour; plain users get mIRC's default back.
alias ns.nl.color {
  if (!$ns.flag(chat,nlcolors,1)) return
  var %c = $1, %n = $2, %rk = $ns.rk.of(%c,%n), %col
  if (!$nick(%c,%n)) return
  if ($ns.flag(chat,nlaway,1)) && ($hget(ns.away,$+($cid,.,%n))) %col = $ns.ecn(dim)
  elseif (%rk) %col = $ns.ecn($ns.rk.letter(%rk))
  if (%col == $null) cline -r 0 %c %n
  else cline %col %c %n
}
alias ns.nl.refresh {
  var %c = $1, %n = $nick(%c,0), %i = 1
  if (%n > $ns.get(chat,nlmax,400)) return
  while (%i <= %n) {
    ns.nl.color %c $nick(%c,%i)
    inc %i
  }
}
; several mode changes in a row -> one refresh a moment later
alias ns.nl.queue {
  if (!$ns.flag(chat,nlcolors,1)) return
  .timer. $+ nl. $+ $cid $+ . $+ $1 -o 1 1 scid $cid ns.nl.refresh $1
}
on *:JOIN:#:{
  if ($nick == $me) {
    ns.nl.queue $chan
    if ($ns.flag(chat,nlcolors,1)) && ($ns.flag(chat,nlaway,1)) && ($ns.flag(chat,nlwho,1)) .timer. $+ nlwho. $+ $cid $+ . $+ $chan -o 1 3 scid $cid ns.nl.who $chan
  }
  else ns.nl.color $chan $nick
}
on *:RAWMODE:#:{ ns.nl.queue $chan }
on *:NICK:{
  var %i = 1, %n = $comchan($newnick,0)
  if ($hget(ns.away,$+($cid,.,$nick))) {
    hadd -m ns.away $+($cid,.,$newnick) 1
    hdel ns.away $+($cid,.,$nick)
  }
  while (%i <= %n) {
    ns.nl.color $comchan($newnick,%i) $newnick
    inc %i
  }
}
on *:PART:#:{ if ($hget(ns.away)) hdel ns.away $+($cid,.,$nick) }
on *:QUIT:{ if ($hget(ns.away)) hdel ns.away $+($cid,.,$nick) }
on *:DISCONNECT:{ if ($hget(ns.away)) hdel -w ns.away $+($cid,.*) }

; away status: AWAY lines from the server (IRCv3 away-notify) and the flags in WHO replies
raw AWAY:*:{
  if (!$ns.flag(chat,nlaway,1)) return
  if ($1-) hadd -m ns.away $+($cid,.,$nick) 1
  elseif ($hget(ns.away)) hdel ns.away $+($cid,.,$nick)
  var %i = 1, %n = $comchan($nick,0)
  while (%i <= %n) {
    ns.nl.color $comchan($nick,%i) $nick
    inc %i
  }
}
alias ns.nl.who {
  if (!$ns.ischan($1)) return
  if ($nick($1,0) > 150) return
  hadd -mu15 ns.who $+($cid,.,$1) 1
  raw -q WHO $1
}
raw 352:*:{
  ; <me> <chan> <user> <host> <server> <nick> <H|G>[*][@+] :<hops> <name>
  if (!$hget(ns.who,$+($cid,.,$2))) return
  if ($left($7,1) == G) hadd -m ns.away $+($cid,.,$6) 1
  elseif ($hget(ns.away)) hdel ns.away $+($cid,.,$6)
  haltdef
}
raw 315:*:{
  if (!$hget(ns.who,$+($cid,.,$2))) return
  hdel ns.who $+($cid,.,$2)
  ns.nl.refresh $2
  haltdef
}

; ---------------------------------------------------------------- replies and reactions (IRCv3 message tags)
; Needs a server that relays message tags (Lurker, Ergo, many modern ones).  Messages that carry a
; msgid are remembered for an hour so a reply can say what it answers.
alias ns.rp.remember {
  if (!$ns.flag(chat,replies,1)) return
  if (!$msgtags(msgid)) return
  if ($hget(ns.mid,0).item > 3000) hfree ns.mid
  hadd -mu3600 ns.mid $+($cid,.,$msgtags(msgid).key) $+($1,$chr(9),$left($strip($2-),200))
}
; "replying to Nova: the build is green" in front of a message that has a +draft/reply tag
alias ns.rp.context {
  if (!$ns.flag(chat,replies,1)) return
  if (!$msgtags(+draft/reply)) return
  var %w = $1, %orig = $hget(ns.mid,$+($cid,.,$msgtags(+draft/reply).key)), %who, %what
  if (!$window(%w)) return
  %who = $gettok(%orig,1,9)
  %what = $gettok(%orig,2-,9)
  echo -cgn info %w $+($ns.ec(dim),$chr(8618),$chr(32),$iif(%who,replying to $+($chr(2),%who,$chr(2)) $+ $iif(%what,$chr(58) $left(%what,70) $+ $iif($len(%what) > 70,...)),replying to an earlier message),$ns.o)
}
; reactions arrive as TAGMSG with +draft/react (and +draft/reply naming the message)
raw TAGMSG:*:{
  ; typing indicators (+typing=active|paused|done)
  if ($msgtags(+typing)) && ($isalias(ns.v3.typing)) {
    ns.v3.typing $1 $nick $msgtags(+typing).key
    haltdef
    return
  }
  if (!$ns.flag(chat,replies,1)) return
  var %emoji = $msgtags(+draft/react).key, %target = $1, %w
  haltdef
  if (%emoji == $null) return
  %w = $iif($left(%target,1) isin $remove($chantypes,CHANTYPES=),%target,$nick)
  if (!$window(%w)) return
  var %orig = $hget(ns.mid,$+($cid,.,$msgtags(+draft/reply).key)), %who = $gettok(%orig,1,9), %what = $gettok(%orig,2-,9)
  echo -cgn info %w $+($ns.ec(dim),%emoji,$chr(32),$chr(2),$nick,$chr(2),$chr(32),reacted,$iif(%who,$chr(32) $+ to $+($chr(32),$chr(2),%who,$chr(2)) $+ $iif(%what,$chr(58) $left(%what,60) $+ $iif($len(%what) > 60,...))),$ns.o)
}
