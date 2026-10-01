; ============================================================================
;  NeonScript 2026  ::  bouncer support  (Lurker, ZNC, soju)
;
;  Lurker (github.com/amiantos/lurker) has a ZNC- and soju-compatible bouncer
;  built in.  A client attaches over TLS on its bouncer port and signs in as
;     <user>            every network at once (clients with soju.im/bouncer-networks)
;     <user>/<network>  ONE network - this is what mIRC uses
;  with the account password or, better, a revocable read-write API token.
;
;  What NeonScript adds on top of mIRC:
;    * bouncer profiles: account / network / token, SASL or user/net:pass login
;    * certificate pinning for self-signed bouncers (warn + disconnect on change)
;    * replay awareness: history replayed on attach (messages carrying an old
;      server-time tag) is dimmed and shown with its original time, and it never
;      triggers sounds, the away log, flood/word protection, auto-op, greetings,
;      mode locks, auto-rejoin or channel-bot replies.
;    * optional ZNC *playback request on attach
;    * network discovery: logged in as just <user>, Lurker answers with a NOTICE
;        "Not attached to a network - log in as <user>/<network> to attach. Available: a, b, c"
;      NeonScript reads that list and offers to create (and open) one profile per
;      network.  If the list is cut short ("+N more") it also asks for the
;      soju.im/bouncer-networks list (BOUNCER LISTNETWORKS) as a second source.
; ============================================================================

; ---------------------------------------------------------------- profile helpers
alias ns.bnc.type return $ns.srv.get($1,bnc,none)
alias ns.bnc.tname {
  var %t = $1
  if (%t == lurker) return Lurker
  if (%t == znc) return ZNC
  if (%t == soju) return soju
  return Bouncer
}
; "brad" or "brad/libera"
alias ns.bnc.account {
  var %u = $ns.srv.get($1,bncuser), %n = $ns.srv.get($1,bncnet)
  if (%ns.bnc.ctl == $1) return %u
  if (%n) return $+(%u,/,%n)
  return %u
}
; server password for the /server command (only the ZNC-style "user/net:token" login uses it)
alias ns.bnc.srvpass {
  if ($ns.srv.get($1,bncauth,sasl) == pass) return $+($ns.bnc.account($1),:,$ns.srv.get($1,bnctoken))
  return $null
}
; extra /server switches for SASL PLAIN:  -l sasl <token> -lname <user[/network]>
alias ns.bnc.login {
  if ($ns.srv.get($1,bncauth,sasl) != sasl) return $null
  return -l sasl $ns.srv.get($1,bnctoken) -lname $ns.bnc.account($1)
}
; the bouncer profile of the connection I am on (or nothing)
alias ns.bnc.cur {
  var %id = $ns.srv.cur
  if (%id) && ($ns.bnc.type(%id) != none) return %id
  return $null
}

; ---------------------------------------------------------------- replay detection
; a line is replayed history when its server-time tag is clearly older than now
alias ns.bnc.isreplay {
  var %t = $msgstamp
  if (!%t) return 0
  return $iif($calc($ctime - %t) > $ns.get(bnc,replaysecs,20),1,0)
}
; ---------------------------------------------------------------- Lurker re-sends its buffer on every connect
; Lurker (unlike ZNC/soju) does not mark history as delivered, so each time mIRC attaches the same backlog
; comes back - already read, but lighting up every window red again.  Two things deal with that:
;   1. a "newest message I have seen" time is kept for every window (marks, saved in data\bncmarks.dat);
;      a replayed line that is not newer than the mark is dropped before it is shown
;   2. whatever activity colour the genuinely new part of a replay leaves behind in the tree / switchbar is
;      cleared once the replay has settled, unless something live arrived in that window meanwhile
alias ns.bnc.net return $iif($network,$network,$iif($server,$server,local))
alias ns.bnc.markfile return $ns.data(bncmarks.dat)
; 1 = this line is a replay of something already seen on an earlier connect (drop it)
alias ns.bnc.dupe {
  ; $1 = window  $2 = nick  $3 = md5 of the text.  The mark is the newest server time seen in that window; a
  ; replayed line older than it was already read.  Several lines can share the mark's second, so the lines seen
  ; in that very second are remembered too (key + "!"): same second AND already seen = read, otherwise new.
  if (!$ns.flag(bnc,dedupe,1)) return 0
  var %t = $msgstamp, %k, %m, %id, %ids
  if (!%t) return 0
  %k = $+($ns.bnc.net,:,$lower($1))
  %m = $hget(ns.bncmark,%k)
  %id = $+($2,.,$left($3,8))
  %ids = $hget(ns.bncmark,$+(%k,!))
  if ($ns.bnc.isreplay) && (%m != $null) && ((%t < %m) || ((%t == %m) && ($istok(%ids,%id,32)))) {
    set -u2 %ns.bnc.skip $+($cid,.,%t,.,$2,.,$3)
    hinc -m ns.bncdup $cid
    ns.bnc.rp $1
    .timer.nsbncdn $+ $cid 1 $calc($ns.get(bnc,clearwait,6) + 1) scid $cid ns.bnc.dupnote
    return 1
  }
  if (%m == $null) || (%t > %m) {
    hadd -m ns.bncmark %k %t
    hadd -m ns.bncmark $+(%k,!) %id
  }
  elseif (%t == %m) {
    %ids = $ns.trim(%ids %id)
    if ($numtok(%ids,32) > 30) %ids = $gettok(%ids,$+($calc($numtok(%ids,32) - 29),-),32)
    hadd -m ns.bncmark $+(%k,!) %ids
  }
  return 0
}
; later handlers (MTS chat lines, the replay marker ...) ask this for the line being processed: nick + text length
alias ns.bnc.skipping return $iif(%ns.bnc.skip == $+($cid,.,$msgstamp,.,$1,.,$2),1,0)
alias ns.bnc.dupnote {
  var %n = $hget(ns.bncdup,$cid)
  if (!%n) return
  hdel ns.bncdup $cid
  ns.dbg bnc hid %n already-read replayed message(s)
  if ($ns.flag(bnc,dupenote,1)) echo -cst info $+($ns.pfx,$chr(32),$ns.ec(dim),hid,$chr(32),%n,$chr(32),replayed message(s) you already read on an earlier connect,$ns.o)
}
; a replayed line that was shown: note the window so its leftover activity colour can be cleared
alias ns.bnc.rp {
  if (!$ns.flag(bnc,clearact,1)) return
  var %k = $+($cid,.,$1)
  if (!$hget(ns.bncrp,%k)) hadd -m ns.bncrp %k $ctime
  .timer.nsbnccl $+ $cid 1 $ns.get(bnc,clearwait,6) scid $cid ns.bnc.settle
}
; something live (not a replay) arrived in this window
alias ns.bnc.real hadd -m ns.bncreal $+($cid,.,$1) $ctime
alias ns.bnc.settle {
  var %p = $+($cid,.), %n = $hget(ns.bncrp,0).item, %i = 1, %keys, %k, %w, %done = 0, %real
  while (%i <= %n) {
    %k = $hget(ns.bncrp,%i).item
    inc %i
    if ($left(%k,$len(%p)) == %p) %keys = %keys %k
  }
  %i = 1
  while ($gettok(%keys,%i,32) != $null) {
    %k = $v1
    inc %i
    %w = $mid(%k,$calc($len(%p) + 1))
    if ($window(%w)) {
      %real = $hget(ns.bncreal,%k)
      if (!%real) || (%real < $hget(ns.bncrp,%k)) {
        window -g0 %w
        inc %done
      }
    }
    hdel ns.bncrp %k
    hdel ns.bncreal %k
  }
  if (%done) ns.dbg bnc cleared the replay activity colour in %done window(s)
}
on *:SIGNAL:ns.boot:{
  if ($exists($ns.bnc.markfile)) && (!$hget(ns.bncmark)) hload -m ns.bncmark $qt($ns.bnc.markfile)
  .timer.nsbncsv 0 300 ns.bnc.savemarks
}
on *:SIGNAL:ns.exit:{ ns.bnc.savemarks }
alias ns.bnc.savemarks {
  if ($hget(ns.bncmark)) hsave -o ns.bncmark $qt($ns.bnc.markfile)
}

; "stay quiet" version used by protections, sounds, bots ...
alias ns.bnc.q {
  if (!$ns.flag(bnc,quiet,1)) return 0
  return $ns.bnc.isreplay
}

; ---------------------------------------------------------------- on connect: pin the certificate, ask ZNC for playback
on *:CONNECT:{
  var %id = $ns.bnc.cur
  if (!%id) return
  var %t = $ns.bnc.tname($ns.bnc.type(%id))
  if ($ssl) {
    var %fp = $sslhash(sha256,s), %pin = $ns.srv.get(%id,bncpin)
    if (%pin == $null) && ($ns.srv.get(%id,bnctrust,0) == 1) && (%fp) {
      ns.srv.set %id bncpin %fp
      ns.say pinned the $+(%t,$chr(32),certificate) $+ $chr(58) $+ $chr(32) $+ $ns.ec(dim) $+ $left(%fp,23) $+ ... $+ $ns.o
    }
    elseif (%pin != $null) && (%fp) && (%pin != %fp) {
      echo -cat info $+($ns.ec(kick),$chr(2),WARNING,$chr(2),$ns.o) $+($ns.ec(kick),the %t certificate has CHANGED since you trusted it.,$ns.o)
      echo -cat info $+($ns.ec(dim),was ,$left(%pin,23),... now ,$left(%fp,23),...,$ns.o)
      if ($ns.flag(bnc,pindrop,1)) {
        ns.err disconnecting. If you expected this, run /neon bnc and press Forget before reconnecting.
        .timer -o 1 0 scid $cid disconnect
        return
      }
    }
  }
  if ($ns.bnc.type(%id) == znc) && ($ns.get(bnc,zncplayback,0) > 0) {
    .timer -o 1 2 scid $cid msg *playback play * $calc($ctime - $ns.get(bnc,zncplayback,0) * 3600)
  }
  if ($ns.srv.mode == ctl) ns.say attached to $+($chr(2),%t,$chr(2)) as $+($chr(2),$ns.srv.get(%id,bncuser),$chr(2)) - asking for your networks...
  elseif ($ns.srv.get(%id,bncnet) == $null) ns.say attached to $+($chr(2),%t,$chr(2)) as $+($chr(2),$ns.srv.get(%id,bncuser),$chr(2)) with no network chosen - $+($ns.cc(11),/neon bnc discover,$ns.o) adds a profile per network.
  else ns.say attached to $+($chr(2),%t,$chr(2)) as $+($chr(2),$ns.bnc.account(%id),$chr(2))
}

; ---------------------------------------------------------------- replayed history: dimmed, original time
alias -l plain return $iif($ns.get(events,style,modern) == mts,0,1)
on ^*:TEXT:*:#:{
  if ($ns.bnc.skipping($nick,$md5($1-))) return
  if ($ns.bnc.isreplay) ns.bnc.rp $chan
  if (!$ns.flag(bnc,replaymark,1)) || (!$ns.bnc.isreplay) || (!$plain) return
  echo -c $+ mt $+ $msgstamp $+ i2 gray $chan $+($ns.ec(dim),$chr(8635),$chr(32),$chr(60),$ns.rk.of($chan,$nick),$nick,$chr(62),$chr(32),$1-,$ns.o)
  haltdef
}
on ^*:ACTION:*:#:{
  if ($ns.bnc.skipping($nick,$md5($1-))) return
  if ($ns.bnc.isreplay) ns.bnc.rp $chan
  if (!$ns.flag(bnc,replaymark,1)) || (!$ns.bnc.isreplay) || (!$plain) return
  echo -c $+ mt $+ $msgstamp $+ i2 gray $chan $+($ns.ec(dim),$chr(8635),$chr(32),$chr(42),$chr(32),$nick,$chr(32),$1-,$ns.o)
  haltdef
}
on ^*:TEXT:*:?:{
  if ($ns.bnc.skipping($nick,$md5($1-))) return
  if ($ns.bnc.isreplay) ns.bnc.rp $nick
  if (!$ns.flag(bnc,replaymark,1)) || (!$ns.bnc.isreplay) || (!$plain) return
  if (!$query($nick)) return
  echo -c $+ mt $+ $msgstamp $+ i2 gray $nick $+($ns.ec(dim),$chr(8635),$chr(32),$chr(60),$nick,$chr(62),$chr(32),$1-,$ns.o)
  haltdef
}

; ---------------------------------------------------------------- network discovery
; Lurker, for a client that logs in as plain <user> (no /network) and does not speak
; soju.im/bouncer-networks, sends one server NOTICE listing the networks:
;   :lurker.bouncer NOTICE me :Not attached to a network - log in as <user>/<network> to attach. Available: alpha, beta, +2 more
; (or "No IRC networks configured yet - add one in the web UI, then reconnect.")
on ^*:NOTICE:*Not attached to a network*:?:{ ns.bnc.gotlist $strip($1-) }
on ^*:SNOTICE:*Not attached to a network*:{ ns.bnc.gotlist $strip($1-) }
on ^*:NOTICE:*No IRC networks configured yet*:?:{ ns.bnc.gotnone }
on ^*:SNOTICE:*No IRC networks configured yet*:{ ns.bnc.gotnone }

; split the "Available:" tail into names; returns "<hidden count> name,name,..."
alias ns.bnc.parse {
  var %t = $1-, %p = $pos(%t,Available:,1), %l, %i = 1, %n, %o, %more = 0
  if (!%p) return $null
  %l = $ns.trim($mid(%t,$calc(%p + 10)))
  %l = $replace(%l,$chr(44) $+ $chr(32),$chr(44))
  while ($gettok(%l,%i,44) != $null) {
    %n = $ns.trim($v1)
    if ($regex(%n,/^\+(\d+) more\.?$/i)) %more = $regml(1)
    elseif (%n) %o = %o $+ $iif(%o,$chr(44)) $+ %n
    inc %i
  }
  return %more %o
}

alias ns.bnc.gotlist {
  if ($hget(ns.bncdisc,$+(done.,$cid))) return
  var %r = $ns.bnc.parse($1-), %more = $gettok(%r,1,32), %names = $gettok(%r,2-,32)
  if (!%names) return
  var %user = $ns.srv.get($ns.srv.cur,bncuser)
  if ($regex($1-,/log in as (\S+?)\/<network>/i)) %user = $regml(1)
  hadd -mu60 ns.bncdisc $+(done.,$cid) 1
  hadd -mu600 ns.bncdisc cid $cid
  hadd -mu600 ns.bncdisc prof $ns.srv.cur
  hadd -mu600 ns.bncdisc user %user
  hadd -mu600 ns.bncdisc names $replace(%names,$chr(44),$chr(32))
  hadd -mu600 ns.bncdisc more %more
  ns.say $+($chr(2),$ns.bnc.tname($ns.bnc.type($ns.srv.cur)),$chr(2)) lists $numtok($replace(%names,$chr(44),$chr(32)),32) network(s) for $+($chr(2),%user,$chr(2)) $+ $chr(58) $replace(%names,$chr(44),$chr(44) $+ $chr(32)) $+ $iif(%more,$chr(44) $+ $chr(32) $+ + $+ %more more)
  ; the list was cut short: also ask the soju way (BOUNCER LISTNETWORKS)
  if (%more) .timer -o 1 1 ns.bnc.sojulist $cid
  if ($ns.flag(bnc,autodiscover,1)) ns.later ns.bnc.dlgopen
}
alias ns.bnc.gotnone {
  ns.err Lurker has no networks for this account yet - add one in the Lurker web UI, then run $+($ns.cc(11),/neon bnc discover,$ns.o) again.
  if ($ns.srv.mode == ctl) .timer -o 1 1 scid $cid disconnect
}

; second source: soju.im/bouncer-networks  ->  BOUNCER NETWORK <id> name=alpha;state=connected
alias ns.bnc.sojulist {
  scid $1 raw CAP REQ :soju.im/bouncer-networks
  scid $1 raw BOUNCER LISTNETWORKS
}
raw BOUNCER:*NETWORK*:{
  if (!$regex($1-,/NETWORK\s+\S+\s+:?(\S+)/i)) return
  var %attrs = $regml(1), %name
  if (!$regex(%attrs,/(?:^|;)name=([^;]+)/i)) return
  %name = $replace($regml(1),\s,_,\:,;,\\,\)
  if (!$istok($hget(ns.bncdisc,names),%name,32)) {
    hadd -mu600 ns.bncdisc names $ns.trim($hget(ns.bncdisc,names) %name)
    hadd -mu600 ns.bncdisc cid $cid
    if (!$hget(ns.bncdisc,prof)) hadd -mu600 ns.bncdisc prof $ns.srv.cur
    if ($dialog(ns_bncnets)) ns.bnc.dlgfill
    else ns.later ns.bnc.dlgopen
  }
  haltdef
}
; has this network got a profile already?
alias ns.bnc.findnet {
  var %i = 1, %id, %b = $1
  while ($ini($ns.profini,%i)) {
    %id = $v1
    inc %i
    if ($ns.bnc.type(%id) == none) continue
    if ($ns.srv.get(%id,server) != $ns.srv.get(%b,server)) continue
    if ($lower($ns.srv.get(%id,bncuser)) != $lower($ns.srv.get(%b,bncuser))) continue
    if ($lower($ns.srv.get(%id,bncnet)) == $lower($2)) return %id
  }
  return $null
}
; create a profile for one network, copying host, TLS, nick, token ... from the control profile
alias ns.bnc.addnet {
  var %b = $1, %n = $2, %id = $ns.bnc.findnet(%b,%n)
  if (%id) return %id
  %id = $ns.srv.add($+($ns.srv.get(%b,name),/,%n),$ns.srv.get(%b,server),$ns.srv.get(%b,port,6697),$ns.srv.get(%b,ssl,1),$ns.srv.get(%b,nick),$ns.srv.get(%b,anick),)
  ns.srv.set %id bnc $ns.bnc.type(%b)
  ns.srv.set %id bncuser $ns.srv.get(%b,bncuser)
  ns.srv.set %id bncnet %n
  ns.srv.set %id bnctoken $ns.srv.get(%b,bnctoken)
  ns.srv.set %id bncauth $ns.srv.get(%b,bncauth,sasl)
  ns.srv.set %id bnctrust $ns.srv.get(%b,bnctrust,0)
  ns.srv.set %id bncpin $ns.srv.get(%b,bncpin)
  return %id
}

alias ns.bnc.dlgopen {
  if ($hget(ns.bncdisc,names) == $null) return
  ns.dlg ns_bncnets ns_bncnets
}
dialog ns_bncnets {
  title "Lurker networks"
  size -1 -1 232 202
  option dbu
  icon 1, 0 0 232 30, $mircexe, 0, noborder
  text "", 2, 6 36 220 18
  list 3, 6 56 220 72, size vsbar
  text "Missing some? Type more network names, separated by commas:", 4, 6 132 220 9
  edit "", 5, 6 142 220 11, autohs
  check "Open the new profiles now - one status window each", 6, 6 158 220 9
  check "Close this control connection when done", 7, 6 169 220 9
  button "Add all new", 9, 6 181 58 13, default
  button "Add selected", 11, 68 181 58 13
  button "Close", 10, 178 181 48 13, cancel
}
on *:DIALOG:ns_bncnets:init:*:{
  did -g ns_bncnets 1 $ns.asset(header_bncnets.png)
  did -c ns_bncnets 6
  did -c ns_bncnets 7
  ns.bnc.dlgfill
}
; (re)fill the list; networks that already have a profile are marked
alias ns.bnc.dlgfill {
  var %b = $hget(ns.bncdisc,prof), %names = $hget(ns.bncdisc,names), %i = 1, %n, %have, %more = $hget(ns.bncdisc,more)
  did -r ns_bncnets 3
  while ($gettok(%names,%i,32) != $null) {
    %n = $v1
    %have = $ns.bnc.findnet(%b,%n)
    did -a ns_bncnets 3 %n $+ $iif(%have,$chr(32) $+ $chr(32) $+ $chr(40) $+ already added $+ $chr(41))
    inc %i
  }
  did -c ns_bncnets 3 1
  did -ra ns_bncnets 2 Found $numtok(%names,32) network(s) for $hget(ns.bncdisc,user) on $ns.srv.get(%b,server) $+ . $iif(%more,Lurker cut its list short ( $+ + $+ %more more) - add the rest below.,Each network becomes a profile that logs in as $hget(ns.bncdisc,user) $+ /name.)
}
on *:DIALOG:ns_bncnets:sclick:9:{ ns.bnc.addgo all }
on *:DIALOG:ns_bncnets:sclick:11:{ ns.bnc.addgo one }
; mode all = every network without a profile, one = just the highlighted line; names typed in the box always count
alias -l ns.bnc.addgo {
  var %b = $hget(ns.bncdisc,prof), %cid = $hget(ns.bncdisc,cid), %names = $hget(ns.bncdisc,names), %todo, %i = 1, %n, %id, %made = 0, %at = 1
  var %open = $did(ns_bncnets,6).state, %close = $did(ns_bncnets,7).state, %extra = $replace($did(ns_bncnets,5).text,$chr(44),$chr(32)), %sel = $did(ns_bncnets,3).sel
  if (!%b) return
  if ($1 == one) %todo = $gettok(%names,%sel,32)
  else %todo = %names
  %todo = %todo %extra
  while ($gettok(%todo,%i,32) != $null) {
    %n = $v1
    inc %i
    if ($ns.bnc.findnet(%b,%n)) continue
    %id = $ns.bnc.addnet(%b,%n)
    inc %made
    ns.say added profile $+($chr(2),$ns.srv.get(%id,name),$chr(2))
    if (%open) {
      .timer -o 1 %at ns.srv.connect %id new
      inc %at 3
    }
  }
  if (!%made) ns.say nothing new to add.
  if (%close) && (%cid) .timer -o 1 1 scid %cid disconnect
  dialog -x ns_bncnets
}

; ---------------------------------------------------------------- commands
; /neon bnc [profile]           open the bouncer settings for a profile
; /neon bnc add <name> <host> [port] <user> [network]    quick Lurker profile (then add the token in the dialog)
; /neon bnc pin                 trust the certificate of the current connection
; /neon bnc forget              forget the pinned certificate of the current bouncer
; /neon bnc discover [profile]  ask the bouncer for your networks and add a profile for each
; forget which messages were already read (the next replay shows everything once more)
alias ns.bnc.marksreset {
  if ($hget(ns.bncmark)) hfree ns.bncmark
  if ($exists($ns.bnc.markfile)) .remove $qt($ns.bnc.markfile)
}
alias neon.bnc {
  var %c = $lower($1)
  if (%c == openall) {
    ns.say opening $ns.bd.openall networks, a few seconds apart...
    return
  }
  if (%c == closeall) {
    ns.say closing $ns.bd.closeall bouncer connections.
    return
  }
  if (%c == marks) {
    if ($2 == reset) {
      ns.bnc.marksreset
      ns.say forgot which replayed messages you had read - the next replay shows them all once more.
    }
    else ns.say $hget(ns.bncmark,0).item window(s) have a read mark. /neon bnc marks reset forgets them.
    return
  }
  if (%c == discover) {
    var %p = $2
    if (!$ns.srv.exists(%p)) %p = $ns.bnc.cur
    if (!%p) {
      var %j = 1
      while ($gettok($ns.srv.ids,%j,32)) {
        if ($ns.bnc.type($v1) == lurker) && ($ns.srv.get($v1,bncnet) == $null) { %p = $v1 | break }
        inc %j
      }
    }
    if (!%p) %p = $ns.srv.default
    if (!%p) || ($ns.bnc.type(%p) == none) {
      ns.err no bouncer profile to ask - set one up with /neon bnc add <name> <host> <port> <user>.
      return
    }
    if (!$ns.srv.get(%p,bnctoken)) {
      ns.err profile $+($chr(2),$ns.srv.get(%p,name),$chr(2)) has no token yet - open /neon bnc and paste it first.
      return
    }
    ns.say asking $+($chr(2),$ns.srv.get(%p,name),$chr(2)) which networks you have...
    ns.srv.connect %p $iif($status == disconnected,-,new) ctl
    return
  }
  if (%c == add) {
    if ($4 == $null) {
      ns.err usage: /neon bnc add <name> <host> <port> <user> [network]
      return
    }
    var %id = $ns.srv.add($2,$3,$iif($4 isnum,$4,6697),1,,)
    var %user = $iif($4 isnum,$5,$4), %net = $iif($4 isnum,$6,$5)
    ns.srv.set %id bnc lurker
    ns.srv.set %id bncuser %user
    ns.srv.set %id bncnet %net
    ns.srv.set %id bncauth sasl
    ns.srv.set %id bnctrust 1
    ns.say added Lurker profile $+($chr(2),$2,$chr(2)) - opening its settings so you can paste your token.
    set -u60 %ns.bnc.id %id
    ns.dlg ns_bnc ns_bnc
    return
  }
  if (%c == pin) {
    var %p = $ns.bnc.cur
    if (!%p) || (!$ssl) {
      ns.err not connected to a bouncer profile over TLS.
      return
    }
    ns.srv.set %p bncpin $sslhash(sha256,s)
    ns.say pinned the certificate of $ns.srv.get(%p,name) $+ .
    return
  }
  if (%c == forget) {
    var %p = $ns.bnc.cur
    if (!%p) {
      ns.err not connected to a bouncer profile.
      return
    }
    ns.srv.set %p bncpin
    ns.say forgot the pinned certificate.
    return
  }
  var %id = $1
  if (!$ns.srv.exists(%id)) %id = $ns.bnc.cur
  if (!%id) %id = $ns.srv.default
  if (!%id) {
    ns.err no profile yet - create one in /neon servers, or /neon bnc add.
    return
  }
  set -u60 %ns.bnc.id %id
  ns.dlg ns_bnc ns_bnc
}

; ---------------------------------------------------------------- dialog
dialog ns_bnc {
  title "Bouncer"
  size -1 -1 264 268
  option dbu
  icon 1, 0 0 264 30, $mircexe, 0, noborder
  check "This profile connects through a bouncer", 2, 6 36 252 9
  text "Bouncer:", 3, 6 52 34 9
  combo 4, 42 50 80 60, drop
  text "", 20, 128 52 130 9
  text "Account:", 5, 6 68 34 9
  edit "", 6, 42 66 90 11, autohs
  text "Network:", 7, 138 68 32 9
  edit "", 8, 172 66 86 11, autohs
  text "Token or password:", 9, 6 84 70 9
  edit "", 10, 78 82 124 11, pass autohs
  text "Sign in with:", 11, 6 100 44 9
  combo 12, 52 98 150 50, drop
  text "", 19, 6 114 252 22
  check "Trust this server's certificate - warn and disconnect if it ever changes", 13, 6 140 252 9
  text "", 14, 6 152 252 9
  check "Mark replayed history (dimmed, with its original time)", 15, 6 166 252 9
  check "Stay quiet during replay: no sounds, away log, protections or bot replies", 16, 6 178 252 9
  check "Offer to add a profile per network when the bouncer lists them", 23, 6 190 252 9
  check "Hide replayed messages I already read on an earlier connect (Lurker re-sends its whole buffer)", 24, 6 202 252 9
  check "Clear the red activity colours a replay leaves in the window tree", 25, 6 214 252 9
  button "Forget pin", 21, 6 230 44 12
  button "Discover networks...", 22, 54 230 76 12
  button "Forget what I have read", 26, 134 230 80 12
  button "OK", 17, 154 248 50 13, ok default
  button "Cancel", 18, 208 248 50 13, cancel
}
alias -l hint {
  var %t = $1
  if (%t == lurker) return Lurker: enter your Lurker username and a read-write API token (safer than your password - it can be revoked on its own). Leave Network empty and press Discover networks: Lurker lists your networks and NeonScript adds a profile for each. mIRC attaches to one network per connection.
  if (%t == znc) return ZNC: Account is your ZNC user, Network the ZNC network name. Optionally ask ZNC to replay the last hours on attach in Control Panel > Advanced.
  if (%t == soju) return soju: Account is your soju username, Network the network name. soju replays history itself.
  return Any bouncer that accepts user/network logins.
}
on *:DIALOG:ns_bnc:init:*:{
  did -g ns_bnc 1 $ns.asset(header_bnc.png)
  var %id = %ns.bnc.id, %t = $ns.srv.get(%id,bnc,none), %n
  did -a ns_bnc 4 Lurker
  did -a ns_bnc 4 ZNC
  did -a ns_bnc 4 soju
  did -a ns_bnc 4 Other bouncer
  did -a ns_bnc 12 SASL PLAIN (recommended)
  did -a ns_bnc 12 Server password as user/network:token
  did -ra ns_bnc 20 profile: $ns.srv.get(%id,name)
  if (%t != none) did -c ns_bnc 2
  %n = $findtok(lurker znc soju other,%t,1,32)
  did -c ns_bnc 4 $iif(%n,%n,1)
  did -ra ns_bnc 6 $ns.srv.get(%id,bncuser)
  did -ra ns_bnc 8 $ns.srv.get(%id,bncnet)
  did -ra ns_bnc 10 $ns.srv.get(%id,bnctoken)
  did -c ns_bnc 12 $iif($ns.srv.get(%id,bncauth,sasl) == pass,2,1)
  if ($ns.srv.get(%id,bnctrust,0) == 1) did -c ns_bnc 13
  var %pin = $ns.srv.get(%id,bncpin)
  did -ra ns_bnc 14 $iif(%pin,Pinned SHA-256: $left(%pin,29) $+ ...,No certificate pinned yet - it is pinned on the next TLS connection.)
  if ($ns.flag(bnc,replaymark,1)) did -c ns_bnc 15
  if ($ns.flag(bnc,quiet,1)) did -c ns_bnc 16
  if ($ns.flag(bnc,autodiscover,1)) did -c ns_bnc 23
  if ($ns.flag(bnc,dedupe,1)) did -c ns_bnc 24
  if ($ns.flag(bnc,clearact,1)) did -c ns_bnc 25
  did -ra ns_bnc 19 $hint($gettok(lurker znc soju other,$did(ns_bnc,4).sel,32))
}
on *:DIALOG:ns_bnc:sclick:4:{ did -ra ns_bnc 19 $hint($gettok(lurker znc soju other,$did(ns_bnc,4).sel,32)) }
on *:DIALOG:ns_bnc:sclick:21:{
  ns.srv.set %ns.bnc.id bncpin
  did -ra ns_bnc 14 Forgotten - it will be pinned again on the next TLS connection.
}
on *:DIALOG:ns_bnc:sclick:17:{ ns.bnc.dlgsave }
on *:DIALOG:ns_bnc:sclick:26:{
  ns.bnc.marksreset
  did -ra ns_bnc 14 Forgotten - every replayed message shows once more on the next connect.
}
on *:DIALOG:ns_bnc:sclick:22:{
  var %id = %ns.bnc.id
  if (!%id) return
  if (!$did(ns_bnc,2).state) did -c ns_bnc 2
  if ($did(ns_bnc,6).text == $null) || ($did(ns_bnc,10).text == $null) {
    did -ra ns_bnc 19 Fill in the account and the token first - then Discover networks asks the bouncer for the list.
    return
  }
  ns.bnc.dlgsave
  dialog -x ns_bnc
  ns.later neon bnc discover %id
}
alias -l ns.bnc.dlgsave {
  var %id = %ns.bnc.id
  if (!%id) return
  if ($did(ns_bnc,2).state) {
    ns.srv.set %id bnc $gettok(lurker znc soju other,$did(ns_bnc,4).sel,32)
    ns.srv.set %id bncuser $did(ns_bnc,6).text
    ns.srv.set %id bncnet $did(ns_bnc,8).text
    ns.srv.set %id bnctoken $did(ns_bnc,10).text
    ns.srv.set %id bncauth $iif($did(ns_bnc,12).sel == 2,pass,sasl)
    ns.srv.set %id bnctrust $did(ns_bnc,13).state
    if (!$did(ns_bnc,13).state) ns.srv.set %id bncpin
    ; a bouncer is normally reached over TLS: default the profile to it if still on a plain port
    if ($ns.srv.get(%id,port) == 6667) && ($ns.srv.get(%id,ssl,0) == 0) ns.srv.set %id port 6697
    if ($ns.srv.get(%id,port) == 6697) ns.srv.set %id ssl 1
  }
  else ns.srv.set %id bnc none
  ns.set bnc replaymark $did(ns_bnc,15).state
  ns.set bnc quiet $did(ns_bnc,16).state
  ns.set bnc autodiscover $did(ns_bnc,23).state
  ns.set bnc dedupe $did(ns_bnc,24).state
  ns.set bnc clearact $did(ns_bnc,25).state
}

; ============================================================================
;  Bouncer dashboard   /neon bncdash        Open all   /neon bnc openall      Close all   /neon bnc closeall
;  One line per bouncer profile (Lurker / ZNC / soju network): connected or not, lag, unread mentions, with
;  buttons to connect, disconnect or reconnect each one - and to open or close every network in one go.
; ============================================================================
; bouncer profiles that name a network (the ones that make a connection of their own)
alias ns.bd.ids {
  var %i = 1, %id, %o
  while ($gettok($ns.srv.ids,%i,32) != $null) {
    %id = $v1
    inc %i
    if ($ns.bnc.type(%id) != none) && ($ns.srv.get(%id,bncnet) != $null) %o = %o %id
  }
  return %o
}
; the connection id open for a profile ("" if none)
alias ns.bd.cid {
  var %i = 1, %c
  while (%i <= $scon(0)) {
    %c = $scon(%i).cid
    inc %i
    if ($hget(ns.cidprof,%c) == $1) return %c
  }
  return $null
}
alias ns.bd.status {
  var %c = $ns.bd.cid($1), %i = 1
  if (!%c) return not open
  while (%i <= $scon(0)) {
    if ($scon(%i).cid == %c) return $scon(%i).status
    inc %i
  }
  return not open
}
; unread mentions of the network a connection is on
alias ns.bd.unread {
  var %c = $ns.bd.cid($1), %i = 1, %net, %n = $hget(ns.mi,n), %k, %v, %cnt = 0
  if (!%c) return 0
  while (%i <= $scon(0)) {
    if ($scon(%i).cid == %c) %net = $scon(%i).network
    inc %i
  }
  if (%net == $null) || (!%n) return 0
  %k = $max(1,$calc(%n - 199))
  while (%k <= %n) {
    %v = $hget(ns.mi,%k)
    if (%v != $null) && ($gettok(%v,6,9) == 0) && ($gettok(%v,2,9) == %net) inc %cnt
    inc %k
  }
  return %cnt
}
; connect every bouncer network that is not open yet, a few seconds apart
alias ns.bd.openall {
  var %ids = $ns.bd.ids, %i = 1, %id, %at = 0, %n = 0
  while ($gettok(%ids,%i,32) != $null) {
    %id = $v1
    inc %i
    if ($ns.bd.status(%id) == connected) || ($ns.bd.status(%id) == connecting) continue
    inc %n
    if (%at == 0) && ($status == disconnected) && (!$ns.bd.cid(%id)) {
      ns.srv.connect %id
      %at = 1
    }
    else {
      inc %at 3
      .timer -o 1 %at ns.srv.connect %id new
    }
  }
  return %n
}
alias ns.bd.closeall {
  var %ids = $ns.bd.ids, %i = 1, %id, %c, %n = 0
  while ($gettok(%ids,%i,32) != $null) {
    %id = $v1
    inc %i
    %c = $ns.bd.cid(%id)
    if (%c) && ($ns.bd.status(%id) isin connected connecting) {
      scid %c disconnect
      inc %n
    }
  }
  return %n
}
alias neon.bncdash ns.dlg ns_bncdash ns_bncdash
dialog ns_bncdash {
  title "Bouncer Dashboard"
  size -1 -1 330 214
  option dbu
  icon 1, 0 0 330 30, $mircexe, 0, noborder
  text "One line per bouncer network.  Lag is measured every 30 seconds.", 2, 6 36 318 9
  list 3, 6 48 318 108, size vsbar hsbar
  button "Connect", 4, 6 160 50 13
  button "Disconnect", 5, 60 160 50 13
  button "Reconnect", 6, 114 160 50 13
  button "Open all", 7, 6 178 50 13
  button "Close all", 8, 60 178 50 13
  button "Refresh", 9, 114 178 50 13
  button "Bouncer settings...", 10, 170 160 76 13
  text "", 11, 6 196 250 9
  button "Close", 12, 276 196 48 13, ok cancel
}
on *:DIALOG:ns_bncdash:init:*:{
  did -g ns_bncdash 1 $ns.asset(header_bncdash.png)
  if ($isalias(ns.lag.ping)) ns.lag.ping
  ns.bd.fill
  .timer.nsbd 0 5 ns.bd.fill
}
on *:DIALOG:ns_bncdash:close:*:{ .timer.nsbd off }
alias ns.bd.fill {
  if (!$dialog(ns_bncdash)) { .timer.nsbd off | return }
  var %ids = $ns.bd.ids, %i = 1, %id, %st, %c, %lag, %un, %glyph, %sel = $did(ns_bncdash,3).sel
  did -r ns_bncdash 3
  while ($gettok(%ids,%i,32) != $null) {
    %id = $v1
    inc %i
    %st = $ns.bd.status(%id)
    %c = $ns.bd.cid(%id)
    %lag = $iif(%c && $hget(ns.lag,%c) != $null,$hget(ns.lag,%c) $+ ms,-)
    %un = $ns.bd.unread(%id)
    %glyph = $iif(%st == connected,$chr(9679) up,$iif(%st == connecting,$chr(9684) connecting,$chr(9675) %st))
    did -a ns_bncdash 3 $+(%glyph,$chr(32),$chr(32),$ns.srv.get(%id,name),$chr(32),$chr(32),$chr(40),$ns.bnc.tname($ns.bnc.type(%id)),$chr(47),$ns.srv.get(%id,bncnet),$chr(41),$chr(32),$chr(32),lag %lag,$chr(32),$chr(32),%un unread)
  }
  if (!$did(ns_bncdash,3).lines) did -a ns_bncdash 3 (no bouncer networks yet - /neon bnc add, then Discover networks)
  elseif (%sel) did -c ns_bncdash 3 %sel
  did -ra ns_bncdash 11 $numtok(%ids,32) bouncer network(s) $+ $chr(44) $calc($numtok($ns.bd.live,32)) connected.
}
alias ns.bd.live {
  var %ids = $ns.bd.ids, %i = 1, %o
  while ($gettok(%ids,%i,32) != $null) {
    if ($ns.bd.status($v1) == connected) %o = %o $v1
    inc %i
  }
  return %o
}
alias -l bdsel return $gettok($ns.bd.ids,$did(ns_bncdash,3).sel,32)
on *:DIALOG:ns_bncdash:sclick:4:{
  var %id = $bdsel, %c
  if (!%id) return
  %c = $ns.bd.cid(%id)
  if (%c) scid %c ns.srv.connect %id
  else ns.srv.connect %id new
  .timer.nsbdr -o 1 4 ns.bd.fill
}
on *:DIALOG:ns_bncdash:sclick:5:{
  var %id = $bdsel, %c = $ns.bd.cid($bdsel)
  if (%id) && (%c) scid %c disconnect
  .timer.nsbdr -o 1 2 ns.bd.fill
}
on *:DIALOG:ns_bncdash:sclick:6:{
  var %id = $bdsel, %c = $ns.bd.cid($bdsel)
  if (!%id) return
  if (%c) {
    scid %c disconnect
    .timer -o 1 2 scid %c ns.srv.connect %id
  }
  else ns.srv.connect %id new
  .timer.nsbdr -o 1 6 ns.bd.fill
}
on *:DIALOG:ns_bncdash:sclick:7:{
  did -ra ns_bncdash 11 Opening $ns.bd.openall network(s)...
  .timer.nsbdr -o 1 5 ns.bd.fill
}
on *:DIALOG:ns_bncdash:sclick:8:{
  did -ra ns_bncdash 11 Closing $ns.bd.closeall connection(s)...
  .timer.nsbdr -o 1 3 ns.bd.fill
}
on *:DIALOG:ns_bncdash:sclick:9:{ ns.bd.fill }
on *:DIALOG:ns_bncdash:sclick:10:{ if ($bdsel) neon bnc $bdsel }
