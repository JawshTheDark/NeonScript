; ============================================================================
;  NeonScript 2026  ::  more IRCv3
;
;  mIRC already negotiates server-time, message-tags, away-notify, account-notify, extended-join, multi-prefix
;  and batch by itself.  Three newer capabilities it does not ask for, so NeonScript asks (a few seconds after
;  connecting, only if the server offers them):
;      draft/read-marker        what you have read follows you between clients       (MARKREAD)
;      draft/chathistory        load older messages on demand                         /neon history
;      draft/message-redaction  messages someone deleted are shown as deleted          (REDACT)
;  and it makes use of what message-tags already delivers:
;      typing indicators        a nick in the nick list lights up while that person types
;      edited messages          "edited" lines for +draft/edit messages
;      account names            who is logged in to services  (/neon accounts, the WHOIS card)
;
;  Everything is passive except the capability request, MARKREAD (when you read a window) and /neon history.
;  Switch the lot off in Control Panel > Chat & reading (IRCv3 extras).
; ============================================================================

alias ns.v3.on return $ns.flag(v3,on,1)
alias ns.v3.wanted return draft/read-marker draft/chathistory draft/message-redaction
alias ns.v3.has return $iif($istok($hget(ns.v3on,$cid),$1,32),1,0)

; ---------------------------------------------------------------- capability negotiation
on *:CONNECT:{
  if ($ns.v3.on) .timer.nsv3 $+ $cid -o 1 4 scid $cid ns.v3.ask
}
on *:DISCONNECT:{
  if ($hget(ns.v3on)) hdel ns.v3on $cid
  if ($hget(ns.v3adv)) hdel ns.v3adv $cid
}
alias ns.v3.ask {
  if ($status != connected) return
  .raw CAP LS 302
}
; raw CAP lines:  <nick|*> LS [*] :caps...    ACK :caps    NEW :caps    DEL :caps
raw CAP:*:{
  ns.v3.cap $1-
  halt
}
alias ns.v3.cap {
  var %sub = $upper($2), %txt = $3-, %i = 1, %adv, %c, %req, %n
  if ($left(%txt,1) == $chr(42)) %txt = $gettok(%txt,2-,32)
  %txt = $remove($left(%txt,1),$chr(58)) $+ $mid(%txt,2)
  %txt = $ns.trim(%txt)
  if (%sub == LS) || (%sub == NEW) {
    while ($gettok(%txt,%i,32) != $null) {
      %c = $gettok($gettok(%txt,%i,32),1,61)
      inc %i
      %adv = %adv %c
    }
    hadd -m ns.v3adv $cid $ns.trim($hget(ns.v3adv,$cid) %adv)
    if (!$ns.v3.on) return
    %i = 1
    while ($gettok($ns.v3.wanted,%i,32) != $null) {
      %c = $gettok($ns.v3.wanted,%i,32)
      inc %i
      if ($istok(%adv,%c,32)) && (!$ns.v3.has(%c)) %req = %req %c
    }
    if (%req) .raw CAP REQ $+(:,$ns.trim(%req))
    return
  }
  if (%sub == ACK) {
    hadd -m ns.v3on $cid $ns.trim($hget(ns.v3on,$cid) %txt)
    ns.dbg ircv3 enabled: %txt
    if ($ns.v3.has(draft/read-marker)) .timer.nsv3rm $+ $cid -o 1 2 scid $cid ns.rm.sync
    return
  }
  if (%sub == DEL) {
    hadd -m ns.v3on $cid $ns.trim($remtok($hget(ns.v3on,$cid),%txt,0,32))
  }
}
alias neon.ircextras {
  var %c = $lower($1)
  if (%c == on) { ns.set v3 on 1 | ns.say IRCv3 extras on. | return }
  if (%c == off) { ns.set v3 on 0 | ns.say IRCv3 extras off. | return }
  ns.say IRCv3 extras are $iif($ns.v3.on,on,off) $+ ; this connection offers: $iif($hget(ns.v3adv,$cid) != $null,$hget(ns.v3adv,$cid),nothing yet) $+ ; enabled by NeonScript: $iif($hget(ns.v3on,$cid) != $null,$hget(ns.v3on,$cid),none)
}

; ---------------------------------------------------------------- ISO 8601 <-> ctime (UTC)
; "2026-09-30T08:00:00.000Z" -> seconds since 1970 (UTC), 0 if it does not parse
alias ns.v3.iso2ctime {
  if (!$regex(ns.iso,$1,/^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/)) return 0
  var %y = $regml(ns.iso,1), %m = $regml(ns.iso,2), %d = $regml(ns.iso,3), %h = $regml(ns.iso,4), %n = $regml(ns.iso,5), %s = $regml(ns.iso,6), %days
  ; days from 1970-01-01 (civil calendar, proleptic Gregorian)
  if (%m <= 2) dec %y
  var %era = $int($calc(%y / 400)), %yoe = $calc(%y - %era * 400), %mp = $calc((%m + 9) % 12), %doy = $calc((153 * %mp + 2) // 5 + %d - 1), %doe = $calc(%yoe * 365 + %yoe // 4 - %yoe // 100 + %doy)
  %days = $calc(%era * 146097 + %doe - 719468)
  return $calc(%days * 86400 + %h * 3600 + %n * 60 + %s)
}
; a real epoch value -> the UTC clock as ISO 8601 ($gmt - $ctime is the offset of the local clock from UTC)
alias ns.v3.ctime2iso {
  var %t = $calc($1 + $gmt - $ctime)
  return $+($asctime(%t,yyyy-mm-dd),T,$asctime(%t,HH:nn:ss),.000Z)
}
alias ns.v3.now return $ctime

; ---------------------------------------------------------------- read markers
; I read a window  ->  tell the server (and so my other clients);  the server says someone else read  ->  catch up
alias ns.rm.target return $iif($ns.ischan($1),$1,$1)
alias ns.rm.send {
  var %w = $1
  if (!$ns.v3.on) || (!$ns.flag(v3,readmarker,1)) || (!$ns.v3.has(draft/read-marker)) return
  if (%w == $null) || ($window(%w).type !isin channel query) return
  ; at most one per window per 5 seconds
  if ($hget(ns.rmcd,$+($cid,.,%w))) return
  hadd -mu5 ns.rmcd $+($cid,.,%w) 1
  .raw MARKREAD %w $+(timestamp=,$ns.v3.ctime2iso($ns.v3.now))
}
on *:ACTIVE:*:{
  if ($appactive) && ($activecid == $cid) ns.rm.send $active
}
; ask for the stored marker of every channel/query I am in (the server also sends them on join)
alias ns.rm.sync {
  var %i = 1
  while (%i <= $chan(0)) {
    .raw MARKREAD $chan(%i)
    inc %i
  }
}
raw MARKREAD:*:{
  haltdef
  if (!$ns.v3.on) return
  var %t = $1, %ts = $2, %c = 0
  if ($left(%ts,10) == timestamp=) %c = $ns.v3.iso2ctime($mid(%ts,11))
  if (!%c) return
  hadd -m ns.rm $+($cid,.,%t) %c
  ns.rm.apply %t %c
}
; everything up to the marker counts as read: mentions in the inbox, and the activity colour if nothing live came later
alias ns.rm.apply {
  var %w = $1, %c = $2, %net = $iif($network,$network,$server), %n = $hget(ns.mi,n), %k = $max(1,$calc(%n - 199)), %v, %done = 0
  while (%k <= %n) {
    %v = $hget(ns.mi,%k)
    if (%v != $null) && ($gettok(%v,6,9) == 0) && ($gettok(%v,4,9) == %w) && ($gettok(%v,2,9) == %net) && ($gettok(%v,1,9) <= %c) {
      hadd ns.mi %k $puttok(%v,1,6,9)
      inc %done
    }
    inc %k
  }
  if (%done) && ($isalias(ns.mi.changed)) ns.mi.changed
  if ($window(%w)) && ($window(%w).sbcolor != $null) && ($hget(ns.bncreal,$+($cid,.,%w)) < %c) window -g0 %w
}

; ---------------------------------------------------------------- typing indicators (incoming)
; called from the TAGMSG handler: ns.v3.typing <window> <nick> <active|paused|done>
alias ns.v3.typing {
  var %w = $1, %n = $2, %state = $3
  if (!$ns.v3.on) || (!$ns.flag(v3,typing,1)) return
  if (%n == $me) || (!$ns.ischan(%w)) || (!$nick(%w,%n)) return
  if (%state == active) || (%state == paused) {
    if (!$hget(ns.typing)) hmake ns.typing 10
    hadd -mu8 ns.typing $+($cid,.,%w,.,%n) 1
    cline $ns.ecn(hi) %w %n
    .timer.nsty $+ $cid $+ . $+ %w $+ . $+ %n -o 1 7 scid $cid ns.nl.color %w %n
  }
  else {
    .timer.nsty $+ $cid $+ . $+ %w $+ . $+ %n off
    ns.nl.color %w %n
  }
}

; ---------------------------------------------------------------- redaction and edits
; REDACT <target> <msgid> [:reason]    - the server (or the author) deleted a message
raw REDACT:*:{
  haltdef
  if (!$ns.v3.on) || (!$ns.flag(v3,redact,1)) return
  var %t = $1, %id = $2, %why = $3-, %orig = $hget(ns.mid,$+($cid,.,%id)), %who = $gettok(%orig,1,9), %what = $gettok(%orig,2-,9), %w
  %w = $iif($ns.ischan(%t),%t,$iif($query($nick),$nick,%t))
  if (!$window(%w)) return
  haltdef
  echo -cgn info %w $+($ns.ec(kick),$chr(9986),$chr(32),$ns.ec(dim),$iif(%who,$+($chr(2),%who,$chr(2),$chr(39),s) message,a message) was deleted by $+($chr(2),$nick,$chr(2)),$iif(%why != $null,$chr(32) $+ $chr(40) $+ $remove(%why,$chr(58)) $+ $chr(41)),$iif(%what != $null,$chr(58) $+ $chr(32) $+ $chr(34) $+ $left(%what,70) $+ $iif($len(%what) > 70,...) $+ $chr(34)),$ns.o)
  if (%orig != $null) hdel ns.mid $+($cid,.,%id)
}
; called for every chat line (from neon_chat's dispatcher): a message that edits an earlier one
alias ns.v3.edit {
  var %w = $1, %who = $2
  if (!$ns.v3.on) || (!$ns.flag(v3,redact,1)) return
  if (!$msgtags(+draft/edit)) return
  var %id = $msgtags(+draft/edit).key, %orig = $hget(ns.mid,$+($cid,.,%id)), %what = $gettok(%orig,2-,9)
  if (!$window(%w)) return
  echo -cgn info %w $+($ns.ec(dim),$chr(9998),$chr(32),$+($chr(2),%who,$chr(2)) edited a message $iif(%what != $null,$+($chr(40),was,$chr(58),$chr(32),$left(%what,60),$iif($len(%what) > 60,...),$chr(41))),$ns.o)
}

; ---------------------------------------------------------------- account names
; account-notify: ACCOUNT <name|*>      extended-join: JOIN <#chan> <account|*> :<realname>
raw ACCOUNT:*:{
  haltdef
  if (!$ns.v3.on) return
  if ($1 == $chr(42)) { if ($hget(ns.acct)) hdel ns.acct $+($cid,.,$nick) }
  else hadd -m ns.acct $+($cid,.,$nick) $1
}
alias ns.v3.acct return $hget(ns.acct,$+($cid,.,$1))
; the WHOIS card (neon_events) reports 330 <me> <nick> <account> :is logged in as  - remember it too
alias ns.v3.note330 hadd -m ns.acct $+($cid,.,$1) $2
; who is (not) logged in on a channel
alias neon.accounts {
  var %c = $iif($ns.ischan($1),$1,$active), %i = 1, %n, %in, %out, %unk
  if (!$ns.ischan(%c)) { ns.err open a channel window first (or /neon accounts #channel). | return }
  %n = $nick(%c,0)
  while (%i <= %n) {
    var %nk = $nick(%c,%i), %a = $ns.v3.acct(%nk)
    inc %i
    if (%a != $null) %in = %in %nk $+ $chr(40) $+ %a $+ $chr(41)
    else %unk = %unk %nk
  }
  ns.say %c $+ : logged in (known): $iif(%in,$ns.trim(%in),none) $+ $chr(59) not known to be logged in: $iif(%unk,$ns.trim(%unk),nobody)
  ns.say (account names only arrive on servers with account-notify; people who were already here before you joined show up once they change status or you /whois them)
}

; ---------------------------------------------------------------- chat history on demand
; /neon history [n] [#channel]   the latest n messages (default 50, at most 200)
alias neon.history {
  var %n = 50, %c = $active
  if ($1 isnum) {
    %n = $min(200,$1)
    if ($ns.ischan($2)) %c = $2
  }
  elseif ($ns.ischan($1)) %c = $1
  if (!$ns.ischan(%c)) && (!$query(%c)) { ns.err open a channel or private message window first. | return }
  if (!$ns.v3.has(draft/chathistory)) {
    ns.err this server does not offer chat history (draft/chathistory) - /neon ircextras shows what it offers.
    return
  }
  ; the lines come back as ordinary (old) messages: let them through even if they were read before
  hadd -mu20 ns.v3h $+($cid,.,%c) 1
  .raw CHATHISTORY LATEST %c * %n
  ns.say asking the server for the last %n messages of %c $+ ...
}
