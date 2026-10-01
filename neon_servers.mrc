; ============================================================================
;  NeonScript 2026  ::  servers & networks
;  Connection profiles (profiles.ini): server, TLS, login (NickServ / SASL /
;  SCRAM / EXTERNAL), channels to join and per-network perform lines.
;  Also: reconnect, keep-alive, global perform, Servers && Networks dialog.
; ============================================================================

; ---------------------------------------------------------------- profile API
alias ns.srv.count return $ini($ns.profini,0)
alias ns.srv.ids {
  var %i = 1, %o
  while ($ini($ns.profini,%i)) {
    %o = %o $v1
    inc %i
  }
  return %o
}
alias ns.srv.exists return $iif($readini($ns.profini,n,$1,server) != $null,$true,$false)
; passwords / tokens are stored protected (dpapi:...) when neonsec.dll is available - see neon_secure.mrc
alias ns.srv.get {
  var %v = $readini($ns.profini,n,$1,$2)
  if ($len(%v) == 0) return $3-
  if ($left(%v,6) == dpapi:) && ($isalias(ns.sec.dec)) {
    %v = $ns.sec.dec(%v)
    if (%v == $null) return $3-
  }
  return %v
}
alias ns.srv.set {
  var %v = $3-
  if (%v == $null) {
    writeini -nz $qt($ns.profini) $1 $2
    return
  }
  if ($istok(pass srvpass bnctoken,$2,32)) && ($isalias(ns.sec.enc)) %v = $ns.sec.enc(%v)
  writeini -n $qt($ns.profini) $1 $2 %v
}
alias ns.srv.default return $iif($ns.srv.exists($ns.get(conn,default)),$ns.get(conn,default),$gettok($ns.srv.ids,1,32))

; a unique, ini-safe id derived from a display name
alias ns.srv.mkid {
  var %b = $regsubex($lower($1-),/[^a-z0-9]/g,), %id, %n = 1
  if (%b == $null) %b = net
  %id = %b
  while ($ns.srv.exists(%id)) {
    inc %n
    %id = %b $+ %n
  }
  return %id
}

; $ns.srv.add(name,server,port,ssl,nick,anick,join list separated by spaces) -> id
alias ns.srv.add {
  var %id = $ns.srv.mkid($1)
  ns.srv.set %id name $1
  ns.srv.set %id server $2
  ns.srv.set %id port $iif($3,$3,6667)
  ns.srv.set %id ssl $iif($4 == 1,1,0)
  ns.srv.set %id nick $5
  ns.srv.set %id anick $6
  ns.srv.set %id join $replace($7-,$chr(32),$chr(44))
  ns.srv.set %id login none
  if (!$ns.srv.exists($ns.get(conn,default))) ns.set conn default %id
  return %id
}

; find a profile by the server address mIRC is connected to
alias ns.srv.byserver {
  var %i = 1, %id
  while ($ini($ns.profini,%i)) {
    %id = $v1
    if ($ns.srv.get(%id,server) == $1) return %id
    inc %i
  }
  return $null
}

; which profile does a connection belong to?  Several profiles can share one host (a
; bouncer has one profile per network), so the host alone is not enough: ns.srv.connect
; queues "<id>:<mode>" and the CONNECT event claims the first entry for that server.
alias ns.srv.claim {
  var %i = 1, %e, %id
  while ($gettok(%ns.srv.pend,%i,32)) {
    %e = $v1
    %id = $gettok(%e,1,58)
    if ($ns.srv.get(%id,server) == $servertarget) {
      set -u90 %ns.srv.pend $remtok(%ns.srv.pend,%e,1,32)
      hadd -m ns.cidprof $cid %id
      hadd -m ns.cidmode $cid $gettok(%e,2,58)
      return %id
    }
    inc %i
  }
  return $null
}
; the profile of the current connection (falls back to the first profile with that host)
alias ns.srv.cur {
  var %id = $hget(ns.cidprof,$cid)
  if (%id) && ($ns.srv.get(%id,server) == $servertarget) return %id
  %id = $ns.srv.claim
  if (%id) return %id
  return $ns.srv.byserver($servertarget)
}
; std = normal session, ctl = a bouncer control session used to discover networks
alias ns.srv.mode return $iif($hget(ns.cidmode,$cid),$v1,std)

; ---------------------------------------------------------------- connecting
; ns.srv.connect <id> [new|-] [ctl]   - new = open in a new status window, ctl = bouncer control session
alias ns.srv.connect {
  var %id = $1
  if (!$ns.srv.exists(%id)) {
    ns.err no such profile: %id
    return
  }
  if ($2 != new) {
    if ($hget(ns.cidprof)) hdel ns.cidprof $cid
    if ($hget(ns.cidmode)) hdel ns.cidmode $cid
  }
  ns.srv.pend $+(%id,:,$iif($3 == ctl,ctl,std))
  if ($3 == ctl) set -u10 %ns.bnc.ctl %id
  var %cmd = server $iif($2 == new,-m) $ns.srv.get(%id,server) $+($iif($ns.srv.get(%id,ssl,0) == 1,+),$ns.srv.get(%id,port,6667))
  var %sp = $ns.srv.get(%id,srvpass)
  var %login = $ns.srv.get(%id,login,none), %pw = $ns.srv.get(%id,pass), %acct = $ns.srv.get(%id,account), %blogin
  ; bouncer profiles (Lurker / ZNC / soju) supply their own credentials
  if ($isalias(ns.bnc.type)) && ($ns.bnc.type(%id) != none) {
    %sp = $ns.bnc.srvpass(%id)
    %blogin = $ns.bnc.login(%id)
    %login = none
  }
  if (%sp) %cmd = %cmd %sp
  if (%blogin) %cmd = %cmd %blogin
  if (%login != none) {
    %cmd = %cmd -l %login
    if (%pw) %cmd = %cmd %pw
    if (%acct) %cmd = %cmd -lname %acct
  }
  var %nick = $ns.srv.get(%id,nick), %an = $ns.srv.get(%id,anick), %em = $emailaddr
  if (!%an) %an = %nick $+ _
  if (!%em) %em = %nick $+ @localhost
  if (%nick) %cmd = %cmd -i %nick %an %em $qt($fullname)
  ns.dbg connecting with profile %id $+ $iif(%sp || %blogin || %login != none,$chr(32) $+ (login configured))
  ns.say connecting to $+($chr(2),$ns.srv.get(%id,name),$chr(2)) $+($chr(40),$ns.srv.get(%id,server),$chr(41),...)
  %cmd
  unset %ns.bnc.ctl
}
alias ns.srv.pend set -u90 %ns.srv.pend %ns.srv.pend $1
; connect the default profile, or fall back to mIRC's last server
alias ns.srv.quick {
  var %id = $ns.srv.default
  if (%id) ns.srv.connect %id
  else server
}
; popup submenu: one entry per profile
alias ns.srv.menu {
  if ($1 !isnum) return
  var %id = $gettok($ns.srv.ids,$1,32)
  if (!%id) return
  return $iif(%id == $ns.srv.default,$style(1)) $ns.srv.get(%id,name) $+ :ns.srv.connect %id
}

; remember when *I* asked to disconnect so reconnect does not fight me
alias quit {
  set -u30 %ns.manual. $+ $cid 1
  !quit $1-
}
alias disconnect {
  set -u30 %ns.manual. $+ $cid 1
  !disconnect $1-
}

; ---------------------------------------------------------------- on connect / disconnect
on *:CONNECT:{
  var %id = $ns.srv.cur
  ; a bouncer control session only lists networks: nothing to join or perform
  if ($ns.srv.mode == ctl) { .timer.nsrc $+ $cid off | return }
  ; network-specific channels + perform, then the global perform
  if (%id) {
    var %j = $ns.srv.get(%id,join)
    if (%j) join %j
    ns.srv.run $ns.srv.get(%id,perform)
    ns.srv.ghostcheck %id
  }
  ns.srv.run $ns.get(conn,perform)
  if ($ns.flag(conn,keepalive,0)) ns.srv.kaon
  .timer.nsrc $+ $cid off
}
on *:DISCONNECT:{
  if (%ns.manual. [ $+ [ $cid ] ]) return
  if (!$ns.flag(general,reconnect,0)) return
  var %d = $ns.get(general,reconnect_delay,10)
  ns.say disconnected - reconnecting in %d seconds...
  .timer.nsrc $+ $cid 1 %d scid $cid ns.srv.reconnect
}
; ---------------------------------------------------------------- take my nick back from a ghost
; Network profile switch "Take my nick back if a ghost holds it": when the main nick is in use and mIRC fell back to
; the alternate one, ask NickServ to GHOST the old session, then change back (and identify again if the profile uses
; NickServ).  Needs a password in the profile; never echoes it (the commands are quiet).
alias ns.srv.ghostcheck {
  var %id = $1, %want = $ns.srv.get(%id,nick), %pw = $ns.srv.get(%id,pass), %lg = $ns.srv.get(%id,login,none)
  ns.dbg ghostcheck id= $+ %id want= $+ %want me= $+ $me login= $+ %lg ghost= $+ $ns.srv.get(%id,ghost,0) haspw= $+ $iif(%pw,yes,no)
  if ($ns.srv.get(%id,ghost,0) != 1) || (%want == $null) || (%pw == $null) return
  if (!$istok(nickserv sasl scram,%lg,32)) return
  if ($me == %want) return
  hadd -mu40 ns.ghost $cid 1
  ns.say my nick $+($chr(2),%want,$chr(2)) is held by someone else - asking NickServ to ghost it...
  .timer.nsgh $+ $cid -o 1 4 scid $cid ns.srv.ghostgo
  .timer.nsgf $+ $cid -o 1 16 scid $cid ns.srv.ghostfinish
}
alias ns.srv.ghostgo {
  var %id = $ns.srv.cur, %want = $ns.srv.get(%id,nick), %pw = $ns.srv.get(%id,pass)
  if (!%id) || (%pw == $null) || ($me == %want) return
  .msg NickServ GHOST %want %pw
}
alias ns.srv.ghostfinish {
  if (!$hget(ns.ghost,$cid)) return
  hdel ns.ghost $cid
  .timer.nsgf $+ $cid off
  var %id = $ns.srv.cur, %want = $ns.srv.get(%id,nick)
  if (!%id) || ($me == %want) return
  nick %want
  if ($ns.srv.get(%id,login,none) == nickserv) .timer.nsgi $+ $cid -o 1 2 scid $cid ns.srv.ghostident
}
alias ns.srv.ghostident {
  var %id = $ns.srv.cur
  if (%id) && ($ns.srv.get(%id,pass) != $null) .msg NickServ IDENTIFY $ns.srv.get(%id,pass)
}
on *:NOTICE:*:?:{
  if (!$hget(ns.ghost,$cid)) return
  if ($nick != NickServ) && ($nick != Nickserv) && ($nick != nickserv) return
  var %t = $strip($1-)
  if ($regex(ns.gh,%t,/(?i)(ghost|killed|released|disconnected)/)) && (!$regex(ns.gh2,%t,/(?i)(not online|no such|isn.t|incorrect|denied|invalid)/)) {
    .timer.nsgh $+ $cid off
    .timer.nsgw $+ $cid -o 1 1 scid $cid ns.srv.ghostfinish
    return
  }
  if ($regex(ns.gh2,%t,/(?i)(incorrect|denied|invalid)/)) {
    hdel ns.ghost $cid
    .timer.nsgf $+ $cid off
    ns.err NickServ refused the ghost request - check the password in this profile.
  }
}
alias ns.srv.reconnect {
  if ($status == connected) || ($status == connecting) return
  var %id = $ns.srv.cur
  if (%id) ns.srv.connect %id
  else server
}
; run a '|' separated list of commands
alias ns.srv.run {
  var %i = 1
  while ($gettok($1-,%i,124) != $null) {
    $v1
    inc %i
  }
}
; keep-alive ping on every connection
alias ns.srv.kaon {
  if (!$timer(nska)) .timer.nska 0 120 ns.srv.ka
}
alias ns.srv.ka {
  var %i = $scon(0)
  while (%i) {
    scid $scon(%i) if ($status == connected) raw -q PING :neonscript
    dec %i
  }
}

; ---------------------------------------------------------------- connect when mIRC starts
; Two switches lead here: "Connect when mIRC starts" on a profile (Servers & Networks) and, in the
; Control Panel, "Connect to my default profile when mIRC starts".  Every profile that should connect is
; collected - the default one first, so it gets the main window - and the rest open in their own status
; windows a few seconds apart.  Profiles that are already connected are skipped, and it only ever runs
; once per mIRC start (a /neon reload does not reconnect anything you disconnected).
alias ns.srv.autolist {
  var %i = 1, %id, %o
  while ($gettok($ns.srv.ids,%i,32) != $null) {
    %id = $gettok($ns.srv.ids,%i,32)
    inc %i
    if ($ns.srv.get(%id,auto,0) == 1) %o = %o %id
  }
  if ($ns.flag(conn,autoconnect,0)) && ($ns.srv.default != $null) && (!$istok(%o,$ns.srv.default,32)) %o = $ns.srv.default %o
  if ($ns.srv.default != $null) && ($istok(%o,$ns.srv.default,32)) %o = $ns.srv.default $remtok(%o,$ns.srv.default,1,32)
  return $ns.trim(%o)
}
; is a connection to this profile already open (or opening)?
alias ns.srv.live {
  var %i = 1, %n = $scon(0), %c, %st
  while (%i <= %n) {
    %c = $scon(%i).cid
    %st = $scon(%i).status
    inc %i
    if (%st != connected) && (%st != connecting) continue
    if ($hget(ns.cidprof,%c) == $1) return 1
    ; a connection mIRC opened by itself: same server counts, unless this profile is one of several on a bouncer
    if ($hget(ns.cidprof,%c) == $null) && ($ns.srv.get($1,bnc,none) == none) && ($scon($calc(%i - 1)).servertarget == $ns.srv.get($1,server)) return 1
  }
  return 0
}
alias ns.srv.autorun {
  if (%ns.autodone) return
  set %ns.autodone 1
  var %list = $ns.srv.autolist, %i = 1, %id, %at = 0, %first = 1, %n = 0, %live
  if (%list == $null) return
  ; which of them are connected already?  Decided up front, before this script opens connections of its own
  while ($gettok(%list,%i,32) != $null) {
    %id = $gettok(%list,%i,32)
    inc %i
    if ($ns.srv.live(%id)) %live = %live %id
  }
  %i = 1
  while ($gettok(%list,%i,32) != $null) {
    %id = $gettok(%list,%i,32)
    inc %i
    if ($istok(%live,%id,32)) continue
    inc %n
    if (%first) && ($status == disconnected) {
      ns.srv.connect %id
      %first = 0
    }
    else {
      inc %at 3
      .timer -o 1 %at ns.srv.connect %id new
      %first = 0
    }
  }
  if (%n) ns.log boot connecting %n profile(s)
}
on *:SIGNAL:ns.boot:{
  if ($ns.flag(conn,keepalive,0)) ns.srv.kaon
  if ($ns.srv.autolist != $null) .timer.nsauto 1 3 ns.srv.autorun
}

; ---------------------------------------------------------------- Servers && Networks dialog
alias neon.servers ns.dlg ns_srv ns_srv
dialog ns_srv {
  title "Servers & Networks"
  size -1 -1 362 252
  option dbu
  icon 1, 0 0 362 33, $mircexe, 0, noborder
  list 10, 6 38 92 132, size vsbar
  button "New", 20, 6 174 44 13
  button "Delete", 21, 54 174 44 13
  text "Add a known network:", 22, 6 192 92 9
  combo 23, 6 202 92 80, drop

  box "Profile", 30, 104 38 252 162
  text "Name:", 31, 112 52 36 9
  edit "", 32, 150 50 100 11
  text "Server:", 33, 112 67 36 9
  edit "", 34, 150 65 100 11
  text "Port:", 35, 254 67 18 9
  edit "", 36, 274 65 28 11, limit 5
  check "TLS", 37, 308 67 40 9
  text "Nick:", 38, 112 82 36 9
  edit "", 39, 150 80 70 11
  text "Alt:", 40, 224 82 16 9
  edit "", 41, 242 80 70 11
  text "Login:", 42, 112 97 36 9
  combo 43, 150 95 100 60, drop
  text "Account:", 44, 254 97 30 9
  edit "", 45, 286 95 62 11
  text "Password:", 46, 112 112 36 9
  edit "", 47, 150 110 100 11, pass
  text "Server pw:", 48, 254 112 30 9
  edit "", 49, 286 110 62 11, pass
  text "Channels:", 50, 112 127 36 9
  edit "", 51, 150 125 198 11
  check "Connect when mIRC starts", 52, 112 142 120 9
  check "Default profile", 53, 240 142 70 9
  check "Take my nick back if a ghost holds it (NickServ GHOST)", 56, 112 155 240 9
  text "Perform (one command per line):", 54, 112 168 150 9
  edit "", 55, 112 178 236 18, multi return vsbar autovs

  button "Save", 60, 104 206 50 13
  button "Connect", 61, 158 206 50 13
  button "New window", 62, 212 206 56 13
  button "Bouncer", 65, 270 206 34 13
  button "Close", 63, 306 206 50 13, ok cancel
  text "Passwords are stored in profiles.ini next to the script (protected with Windows DPAPI when neonsec.dll is present). Leave blank to be asked by the network instead.", 64, 104 224 252 24
}
on *:DIALOG:ns_srv:init:*:{
  did -g ns_srv 1 $ns.asset(header_servers.png)
  did -a ns_srv 43 None
  did -a ns_srv 43 NickServ
  did -a ns_srv 43 SASL PLAIN
  did -a ns_srv 43 SASL EXTERNAL
  did -a ns_srv 43 SASL SCRAM
  var %i = 1, %f = $ns.data(networks.ini)
  did -a ns_srv 23 (choose...)
  while ($gettok($replace($readini(%f,n,networks,order),$chr(44),$chr(32)),%i,32)) {
    did -a ns_srv 23 $readini(%f,n,$v1,name)
    inc %i
  }
  did -c ns_srv 23 1
  srvlist
  var %d = $ns.srv.default, %n = $findtok($ns.srv.ids,%d,1,32)
  if (!%n) %n = 1
  if ($ns.srv.count) {
    did -c ns_srv 10 %n
    srvload $gettok($ns.srv.ids,%n,32)
  }
  else srvclear
}
alias -l srvlist {
  did -r ns_srv 10
  var %i = 1
  while ($gettok($ns.srv.ids,%i,32)) {
    did -a ns_srv 10 $ns.srv.get($v1,name)
    inc %i
  }
}
alias -l srvclear {
  did -r ns_srv 32,34,36,39,41,45,47,49,51,55
  did -c ns_srv 43 1
  did -u ns_srv 37,52,53,56
  set -u3600 %ns.srvcur $null
}
alias -l srvload {
  var %id = $1
  set -u3600 %ns.srvcur %id
  did -ra ns_srv 32 $ns.srv.get(%id,name)
  did -ra ns_srv 34 $ns.srv.get(%id,server)
  did -ra ns_srv 36 $ns.srv.get(%id,port,6667)
  did $iif($ns.srv.get(%id,ssl,0) == 1,-c,-u) ns_srv 37
  did -ra ns_srv 39 $ns.srv.get(%id,nick)
  did -ra ns_srv 41 $ns.srv.get(%id,anick)
  var %m = $findtok(none nickserv sasl external scram,$ns.srv.get(%id,login,none),1,32)
  did -c ns_srv 43 $iif(%m,%m,1)
  did -ra ns_srv 45 $ns.srv.get(%id,account)
  did -ra ns_srv 47 $ns.srv.get(%id,pass)
  did -ra ns_srv 49 $ns.srv.get(%id,srvpass)
  did -ra ns_srv 51 $replace($ns.srv.get(%id,join),$chr(44),$chr(44) $+ $chr(32))
  did $iif($ns.srv.get(%id,auto,0) == 1,-c,-u) ns_srv 52
  did $iif($ns.srv.get(%id,ghost,0) == 1,-c,-u) ns_srv 56
  did $iif($ns.srv.default == %id,-c,-u) ns_srv 53
  ns.ml.new
  var %k = 1, %p = $ns.srv.get(%id,perform)
  while ($gettok(%p,%k,124) != $null) {
    ns.ml.add $v1
    inc %k
  }
  ns.ml.set ns_srv 55
}
alias -l srvsave {
  var %id = %ns.srvcur
  if (!%id) {
    if ($did(ns_srv,32).text == $null) return
    %id = $ns.srv.mkid($did(ns_srv,32).text)
    set -u3600 %ns.srvcur %id
  }
  ns.srv.set %id name $did(ns_srv,32).text
  ns.srv.set %id server $did(ns_srv,34).text
  ns.srv.set %id port $iif($did(ns_srv,36).text isnum,$did(ns_srv,36).text,6667)
  ns.srv.set %id ssl $did(ns_srv,37).state
  ns.srv.set %id nick $did(ns_srv,39).text
  ns.srv.set %id anick $did(ns_srv,41).text
  ns.srv.set %id login $gettok(none nickserv sasl external scram,$did(ns_srv,43).sel,32)
  ns.srv.set %id account $did(ns_srv,45).text
  ns.srv.set %id pass $did(ns_srv,47).text
  ns.srv.set %id srvpass $did(ns_srv,49).text
  ns.srv.set %id join $replace($remove($did(ns_srv,51).text,$chr(32)),$chr(59),$chr(44))
  ns.srv.set %id auto $did(ns_srv,52).state
  ns.srv.set %id ghost $did(ns_srv,56).state
  var %k = 1, %txt
  while (%k <= $did(ns_srv,55).lines) {
    if ($did(ns_srv,55,%k) != $null) %txt = %txt $+ $iif(%txt,$chr(124)) $+ $did(ns_srv,55,%k)
    inc %k
  }
  ns.srv.set %id perform %txt
  if ($did(ns_srv,53).state) ns.set conn default %id
  srvlist
  did -c ns_srv 10 $findtok($ns.srv.ids,%id,1,32)
}
on *:DIALOG:ns_srv:sclick:10:{
  var %id = $gettok($ns.srv.ids,$did(ns_srv,10).sel,32)
  if (%id) srvload %id
}
on *:DIALOG:ns_srv:sclick:20:{
  srvclear
  did -ra ns_srv 32 New network
  did -c ns_srv 53
  did -f ns_srv 34
}
on *:DIALOG:ns_srv:sclick:21:{ ns.later ns.srv.delcur }
alias ns.srv.delcur {
  var %id = %ns.srvcur
  if (!%id) || (!$dialog(ns_srv)) return
  if (!$input(Delete the profile $qt($ns.srv.get(%id,name)) $+ ?,yq,Delete profile)) return
  remini $qt($ns.profini) %id
  srvlist
  if ($ns.srv.count) {
    did -c ns_srv 10 1
    srvload $gettok($ns.srv.ids,1,32)
  }
  else srvclear
}
on *:DIALOG:ns_srv:sclick:23:{
  var %n = $calc($did(ns_srv,23).sel - 1), %f = $ns.data(networks.ini)
  if (%n < 1) return
  var %id = $gettok($replace($readini(%f,n,networks,order),$chr(44),$chr(32)),%n,32)
  srvclear
  did -ra ns_srv 32 $readini(%f,n,%id,name)
  did -ra ns_srv 34 $readini(%f,n,%id,server)
  did -ra ns_srv 36 $readini(%f,n,%id,port)
  did $iif($readini(%f,n,%id,ssl) == 1,-c,-u) ns_srv 37
  did -f ns_srv 39
}
on *:DIALOG:ns_srv:sclick:60:{ srvsave }
on *:DIALOG:ns_srv:sclick:61:{
  srvsave
  if (%ns.srvcur) ns.srv.connect %ns.srvcur
}
on *:DIALOG:ns_srv:sclick:62:{
  srvsave
  if (%ns.srvcur) ns.srv.connect %ns.srvcur new
}
on *:DIALOG:ns_srv:sclick:65:{
  srvsave
  if (%ns.srvcur) {
    set -u60 %ns.bnc.id %ns.srvcur
    ns.dlg ns_bnc ns_bnc
  }
}
