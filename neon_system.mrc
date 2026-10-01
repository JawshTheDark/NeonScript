; ============================================================================
;  NeonScript 2026  ::  system tools   (loaded first)
;  Settings schema + migration, debug console, self-test, backup / restore,
;  repair, "stock mIRC" snapshot and the update check.
;  Nothing here talks to the network unless you run /neon update yourself
;  (or switch the automatic check on).
; ============================================================================

alias ns.schema return 2
alias ns.bakdir return $+($scriptdir,backup\)
alias ns.stock.file return $+($ns.bakdir,stock.ini)
alias ns.stock.alfile return $+($ns.bakdir,aliases.stock.ini)

; $ns.vercmp(a,b) -> -1 / 0 / 1 for dotted versions such as 2026.2.0
alias ns.vercmp {
  var %i = 1, %a, %b
  while (%i <= 4) {
    %a = $gettok($1,%i,46)
    %b = $gettok($2,%i,46)
    if (%a !isnum) %a = 0
    if (%b !isnum) %b = 0
    if (%a < %b) return -1
    if (%a > %b) return 1
    inc %i
  }
  return 0
}

; ---------------------------------------------------------------- boot: snapshot the stock look, migrate settings
on *:SIGNAL:ns.boot:{
  ns.stock.snapshot
  ns.migrate
  ns.log sys booted $ns.tag
  if ($ns.flag(update,auto,0)) .timer.nsupd -o 1 25 ns.update.check auto
}
on *:CONNECT:{ ns.log net connected }
on *:DISCONNECT:{ ns.log net disconnected }

; ---------------------------------------------------------------- settings schema + migration
; Every change to how settings are stored gets a number here and an ns.mig.<n> alias that
; upgrades the previous layout.  A backup is written before any migration runs.
alias ns.migrate {
  var %v = $ns.get(general,schema,0), %to = $ns.schema
  if (%v >= %to) return
  if (!$exists($ns.ini)) {
    ns.set general schema %to
    return
  }
  ns.bak.export before-upgrade
  while (%v < %to) {
    inc %v
    if ($isalias($+(ns.mig.,%v))) $+(ns.mig.,%v)
    ns.set general schema %v
    ns.log sys settings migrated to layout %v
  }
}
; layout 1 = the first public layout: nothing to change
alias ns.mig.1 noop
; layout 2 = Mentions toolbar button: add it after Notify when the toolbar order was customised
alias ns.mig.2 {
  var %o = $ns.get(toolbar,order)
  if (%o == $null) || ($istok(%o,mentions,32)) return
  if ($istok(%o,notify,32)) ns.set toolbar order $instok(%o,mentions,$calc($findtok(%o,notify,1,32) + 1),32)
  else ns.set toolbar order %o mentions
}

; ---------------------------------------------------------------- stock mIRC snapshot
; The first time NeonScript runs, before it changes anything, remember mIRC's own colours so
; /neon repair stock and /neon uninstall can put them back.
alias ns.stock.snapshot {
  if ($exists($ns.stock.file)) return
  ; a theme was already applied by an earlier install: the real stock look is no longer known
  if ($ns.get(theme,current) != $null) return
  .mkdir $qt($ns.bakdir)
  var %f = $ns.stock.file, %items = $ns.theme.items, %i = 1, %n = $numtok(%items,44)
  while (%i <= %n) {
    writeini -n $qt(%f) colors $replace($gettok(%items,%i,44),$chr(32),_) $color($gettok(%items,%i,44))
    inc %i
  }
  %i = 0
  while (%i < 16) {
    writeini -n $qt(%f) palette %i $color(%i)
    inc %i
  }
  writeini -n $qt(%f) meta created $asctime($ctime,yyyy-mm-dd HH:nn)
  writeini -n $qt(%f) meta version $ns.ver
  ns.log sys stock mIRC colours saved
}
; put mIRC's own colours, toolbar and aliases back (NeonScript stays installed)
alias ns.stock.restore {
  var %f = $ns.stock.file, %items = $ns.theme.items, %i = 1, %n = $numtok(%items,44), %v, %done = 0
  if ($exists(%f)) {
    while (%i <= %n) {
      %v = $readini(%f,n,colors,$replace($gettok(%items,%i,44),$chr(32),_))
      if (%v isnum) {
        color $gettok(%items,%i,44) %v
        inc %done
      }
      inc %i
    }
    %i = 0
    while (%i < 16) {
      %v = $readini(%f,n,palette,%i)
      if (%v isnum) color %i %v
      inc %i
    }
  }
  toolbar -r
  background -lx
  background -hx
  ns.stock.aliases
  if ($isalias(ns.menus.restore)) ns.menus.restore
  ns.set toolbar enabled 0
  ns.say original mIRC look restored $iif(%done,( $+ %done colours $+ ),(no colour snapshot was saved, so your colours were left alone)) $+ .
}
; the stock aliases NeonScript removed when it took over /j /p /k ... : put them back
alias ns.stock.aliases {
  var %f = $ns.stock.alfile, %list = op dop j p n w k q send chat ping s, %i = 1, %name, %def
  while ($gettok(%list,%i,32) != $null) {
    %name = $gettok(%list,%i,32)
    inc %i
    if ($isalias(%name)) && ($isalias(%name).ftype == alias) continue
    %def = $readini(%f,n,aliases,%name)
    if (%def == $null) %def = $ns.alias.stockfull(%name)
    if (%def != $null) alias $+(/,%name) %def
  }
}
; mIRC's shipped definitions, used when the exact original text was not recorded
alias ns.alias.stockfull {
  var %n = $1
  if (%n == op) return /mode # +ooo $$1 $2 $3
  if (%n == dop) return /mode # -ooo $$1 $2 $3
  if (%n == j) return /join #$$1
  if (%n == p) return /part #
  if (%n == n) return /names #
  if (%n == w) return /whois $$1
  if (%n == k) return /kick # $$1
  if (%n == q) return /query $$1
  if (%n == send) return /dcc send $$1
  if (%n == chat) return /dcc chat $$1
  if (%n == ping) return /ctcp $$1 ping
  if (%n == s) return /server $$1-
  return $null
}

; ---------------------------------------------------------------- debug report (no secrets, no hostnames)
alias ns.rep.build {
  var %mods = $ns.modules, %i = 1, %loaded = 0, %prof = 0, %bnc = 0, %id, %others, %c, %line
  ns.ml.new
  while ($gettok(%mods,%i,32) != $null) {
    if ($ns.isloaded($+($scriptdir,$gettok(%mods,%i,32),.mrc))) inc %loaded
    inc %i
  }
  %i = 1
  while ($gettok($ns.srv.ids,%i,32) != $null) {
    %id = $gettok($ns.srv.ids,%i,32)
    inc %prof
    if ($ns.srv.get(%id,bnc,none) != none) inc %bnc
    inc %i
  }
  %i = 1
  while (%i <= $script(0)) {
    if ($left($nopath($script(%i)),5) != neon_) && ($nopath($script(%i)) != neon.mrc) %others = %others $nopath($script(%i))
    inc %i
  }
  ns.ml.add $ns.tag (layout $ns.get(general,schema,0) $+ )
  ns.ml.add mIRC $version on Windows $os $+ $iif($portable,$chr(44) portable) $+ , TLS: $iif($sslready,ready $sslversion,not available)
  ns.ml.add Theme: $ns.theme.current ( $+ $ns.get(theme,mode,dark) $+ ), event style: $ns.get(events,style,modern) $+ , symbols: $ns.get(events,symbols,unicode)
  ns.ml.add Modules loaded: %loaded $+ / $+ $numtok(%mods,32) $+ , toolbar: $iif($ns.flag(toolbar,enabled,1),on ( $+ $toolbar(0) buttons),off) $+ , custom buttons: $numtok($ns.cb.ids,32)
  ns.ml.add Profiles: %prof ( $+ %bnc via a bouncer) $+ , connections now: $scon(0)
  ns.ml.add Other scripts loaded: $iif(%others,$ns.trim(%others),none)
  ns.ml.add Last self-test: $iif($ns.get(system,lasttest),$ns.get(system,lasttest),never run)
  ns.ml.add $chr(160)
  ns.ml.add --- last debug lines (newest last) ---
  var %n = $hget(ns.dbglog,n), %from = $calc(%n - 120)
  if (%from < 1) %from = 1
  %c = %from
  while (%c <= %n) {
    %line = $hget(ns.dbglog,%c)
    if (%line != $null) ns.ml.add $replace(%line,$chr(9),$chr(32) $+ $chr(124) $+ $chr(32))
    inc %c
  }
}

alias neon.debug ns.dlg ns_dbg ns_dbg
dialog ns_dbg {
  title "NeonScript debug console"
  size -1 -1 330 214
  option dbu
  icon 1, 0 0 330 30, $mircexe, 0, noborder
  edit "", 2, 6 36 318 142, read multi return vsbar hsbar
  button "Refresh", 3, 6 184 44 13
  button "Copy report", 4, 54 184 54 13
  button "Self-test", 5, 112 184 44 13
  button "Clear log", 6, 160 184 44 13
  text "The report never contains passwords or tokens - safe to paste into a bug report.", 7, 6 200 270 9
  button "Close", 8, 278 197 46 13, ok cancel
}
on *:DIALOG:ns_dbg:init:*:{
  did -g ns_dbg 1 $ns.asset(header_debug.png)
  ns.dbg.fill
}
alias ns.dbg.fill {
  if (!$dialog(ns_dbg)) return
  ns.rep.build
  ns.ml.set ns_dbg 2
}
on *:DIALOG:ns_dbg:sclick:3:{ ns.dbg.fill }
on *:DIALOG:ns_dbg:sclick:4:{
  var %n = $hget(ns.ml,n), %i = 1
  clipboard
  while (%i <= %n) {
    clipboard -an $hget(ns.ml,%i)
    inc %i
  }
  did -ra ns_dbg 7 Copied $calc(%n) lines to the clipboard.
}
on *:DIALOG:ns_dbg:sclick:5:{ neon selftest }
on *:DIALOG:ns_dbg:sclick:6:{
  if ($hget(ns.dbglog)) hfree ns.dbglog
  ns.dbg.fill
}

; ---------------------------------------------------------------- self-test
alias -l ns.st.line {
  ; $1 = ok | warn | fail   $2- = text
  var %k = $1, %tag, %col
  if (%k == ok) { %tag = $chr(91) $+ $chr(32) $+ OK $+ $chr(32) $+ $chr(32) $+ $chr(93) | %col = $ns.ec(join) }
  elseif (%k == warn) { %tag = $chr(91) $+ WARN $+ $chr(93) | %col = $ns.ec(hi) }
  else { %tag = $chr(91) $+ FAIL $+ $chr(93) | %col = $ns.ec(kick) }
  hinc -m ns.st %k
  echo -c info @NeonSelfTest $+(%col,%tag,$ns.o,$chr(32),$ns.ec(value),$2-,$ns.o)
  ns.log test %k $2-
}
alias -l ns.st.head {
  echo -c info @NeonSelfTest $chr(160)
  echo -c info @NeonSelfTest $+($ns.cc($ns.get(theme,accent,13)),$chr(2),$1-,$chr(2),$ns.o)
}
alias neon.selftest {
  var %w = @NeonSelfTest, %i, %id, %f, %n, %v, %lab, %tok, %k, %sub, %missing
  if ($window(%w)) window -c %w
  window -Cz %w 120 70 800 540
  titlebar %w NeonScript self-test
  if ($hget(ns.st)) hfree ns.st
  hmake ns.st 4
  hadd ns.st ok 0
  hadd ns.st warn 0
  hadd ns.st fail 0
  echo -c info %w $+($ns.cc($ns.get(theme,accent,13)),$chr(2),$ns.tag,$chr(2),$ns.o,$chr(32),$ns.ec(dim),- self-test,$ns.o)

  ns.st.head Environment
  if ($version >= 7.85) ns.st.line ok mIRC $version
  elseif ($version >= 7.8) ns.st.line warn mIRC $version works, but 7.85 or newer is recommended
  else ns.st.line fail mIRC $version is too old - NeonScript needs 7.85 or newer
  if ($sslready) ns.st.line ok TLS is available ( $+ $sslversion $+ )
  else ns.st.line warn TLS is not available - encrypted connections (bouncers, most networks) will fail
  %f = $+($scriptdir,selftest.tmp)
  write $qt(%f) test
  if ($exists(%f)) { ns.st.line ok the script folder is writable | .remove $qt(%f) }
  else ns.st.line fail cannot write to the script folder - settings cannot be saved
  ns.set system selftest 1
  if ($ns.get(system,selftest) == 1) ns.st.line ok settings file reads and writes
  else ns.st.line fail settings file could not be read back
  ns.del system selftest
  if ($exists($ns.stock.file)) ns.st.line ok mIRC's original colours are saved (/neon repair stock restores them)
  else ns.st.line warn no copy of mIRC's original colours - /neon repair stock cannot restore them
  if ($isalias(ns.menus.types)) {
    var %mn = 0, %mj = 1
    while ($gettok($ns.menus.types,%mj,32) != $null) {
      if ($ns.get(menus,$+(took_,$gettok($ns.menus.types,%mj,32))) == 1) inc %mn
      inc %mj
    }
    ns.st.line ok right-click menus: mIRC's default menus replaced for %mn of $numtok($ns.menus.types,32) window types (/neon menus)
  }
  %v = $ns.get(general,schema,0)
  if (%v == $ns.schema) ns.st.line ok settings layout $ns.schema
  else ns.st.line warn settings layout is %v (current is $ns.schema $+ ) - run /neon repair

  ns.st.head Scripts
  %i = 1
  %n = $numtok($ns.modules,32)
  while (%i <= %n) {
    %id = $gettok($ns.modules,%i,32)
    %f = $+($scriptdir,%id,.mrc)
    if (!$exists(%f)) ns.st.line fail module %id is missing ( $+ %id $+ .mrc)
    elseif (!$ns.isloaded(%f)) ns.st.line fail module %id is not loaded - run /neon repair
    else ns.st.line ok module %id
    inc %i
  }
  if ($ns.isloaded($+($scriptdir,neon.mrc))) ns.st.line ok core (neon.mrc)
  else ns.st.line fail the core script is not loaded
  var %others, %s = 1
  while (%s <= $script(0)) {
    %f = $nopath($script(%s))
    if ($left(%f,5) != neon_) && (%f != neon.mrc) %others = %others %f
    inc %s
  }
  if (%others) ns.st.line ok other scripts loaded: $ns.trim(%others) (they share events and menus with NeonScript)

  ns.st.head Data files
  %i = 1
  while ($gettok(themes.ini networks.ini commands.txt popups_none.ini msg_quit.txt msg_part.txt msg_kick.txt msg_slap.txt msg_away.txt,%i,32) != $null) {
    %lab = $gettok(themes.ini networks.ini commands.txt popups_none.ini msg_quit.txt msg_part.txt msg_kick.txt msg_slap.txt msg_away.txt,%i,32)
    inc %i
    if ($exists($ns.data(%lab))) ns.st.line ok data\ $+ %lab
    else ns.st.line fail data\ $+ %lab is missing - run /neon repair
  }
  if ($findfile($ns.data(mts\),*.mts,0,1)) ns.st.line ok $findfile($ns.data(mts\),*.mts,0,1) MTS theme(s) in data\mts
  else ns.st.line warn no MTS themes in data\mts

  ns.st.head Artwork
  %missing = $null
  %i = 1
  while ($gettok($ns.tb.all,%i,32) != $null) {
    %k = $gettok($ns.tb.all,%i,32)
    if (%k == dnd) { if (!$exists($ns.asset(dnd_off.png))) %missing = %missing dnd_off.png | if (!$exists($ns.asset(dnd_on.png))) %missing = %missing dnd_on.png }
    elseif (%k == sound) { if (!$exists($ns.asset(sound_on.png))) %missing = %missing sound_on.png | if (!$exists($ns.asset(sound_off.png))) %missing = %missing sound_off.png }
    elseif (!$exists($ns.asset(%k $+ .png))) %missing = %missing %k $+ .png
    inc %i
  }
  %i = 1
  while ($gettok(banner.png splash.bmp bg_dark.bmp bg_light.bmp neon.ico header_options.png header_servers.png header_cc.png header_debug.png header_backup.png header_mentions.png header_link.png mentions_new.png banner_about.png,%i,32) != $null) {
    %lab = $gettok(banner.png splash.bmp bg_dark.bmp bg_light.bmp neon.ico header_options.png header_servers.png header_cc.png header_debug.png header_backup.png banner_about.png,%i,32)
    inc %i
    if (!$exists($ns.asset(%lab))) %missing = %missing %lab
  }
  if (%missing) ns.st.line fail missing artwork: $ns.trim(%missing)
  else ns.st.line ok toolbar icons, headers and backgrounds are all present

  ns.st.head Look and toolbar
  %v = $ns.theme.current
  if ($left(%v,4) == mts:) {
    if ($exists($ns.data($+(mts\,$mid(%v,5))))) ns.st.line ok MTS theme %v
    else ns.st.line fail the active MTS theme file is missing ( $+ %v $+ )
  }
  elseif ($ns.theme.name(%v)) ns.st.line ok theme $ns.theme.name(%v)
  else ns.st.line fail unknown theme $qt(%v)
  if (!$ns.flag(toolbar,enabled,1)) ns.st.line ok toolbar: mIRC's own toolbar is in use
  elseif ($toolbar(0) > 0) ns.st.line ok toolbar has $toolbar(0) buttons
  else ns.st.line warn the NeonScript toolbar has no buttons - run /neon toolbar rebuild
  if ($ns.rk.chars) ns.st.line ok rank symbols: $ns.rk.chars (modes: $ns.rk.modes $+ )
  else ns.st.line fail no rank symbols known

  ns.st.head Commands
  %i = 1
  %n = $lines($ns.data(commands.txt))
  %missing = $null
  while (%i <= %n) {
    %lab = $gettok($read($ns.data(commands.txt),n,%i),1,124)
    inc %i
    if ($left(%lab,1) != $chr(47)) continue
    var %j = 1, %c1 = $regex(csub,%lab,/\/neon\s+([a-z]+)/gi), %c2
    while (%j <= %c1) {
      %sub = $regml(csub,%j)
      if (!$isalias($+(neon.,%sub))) %missing = %missing /neon %sub
      inc %j
    }
    %j = 1
    %c2 = $regex(ccmd,%lab,/(?:^|\s)\/([a-z0-9]+)/gi)
    while (%j <= %c2) {
      %tok = $regml(ccmd,%j)
      if (%tok != neon) && (!$isalias(%tok)) %missing = %missing / $+ %tok
      inc %j
    }
  }
  if (%missing) ns.st.line warn commands in the reference without an alias: $ns.trim(%missing)
  else ns.st.line ok every command in /neonhelp has an implementation

  ns.st.head Servers and bouncers
  %i = 1
  %n = $numtok($ns.srv.ids,32)
  if (!%n) ns.st.line warn no server profiles yet - add one in /neon servers
  if ($isalias(ns.srv.autolist)) {
    %v = $ns.srv.autolist
    if (%v != $null) ns.st.line ok connects when mIRC starts: $numtok(%v,32) profile(s)
    elseif ($ns.flag(conn,autoconnect,0)) ns.st.line warn "connect on start-up" is on but there is no default profile to connect
    else ns.st.line ok nothing is set to connect when mIRC starts
  }
  while ($gettok($ns.srv.ids,%i,32) != $null) {
    %id = $gettok($ns.srv.ids,%i,32)
    inc %i
    %v = $ns.srv.get(%id,name)
    if ($ns.srv.get(%id,server) == $null) { ns.st.line fail profile $+($qt(%v)) has no server address | continue }
    if ($ns.srv.get(%id,port,6667) !isnum 1-65535) { ns.st.line fail profile $+($qt(%v)) has an invalid port | continue }
    if ($ns.srv.get(%id,bnc,none) != none) {
      if ($ns.srv.get(%id,bncuser) == $null) ns.st.line warn bouncer profile $+($qt(%v)) has no account name
      elseif ($readini($ns.profini,n,%id,bnctoken) == $null) ns.st.line warn bouncer profile $+($qt(%v)) has no token or password yet
      elseif ($ns.srv.get(%id,bnctoken) == $null) ns.st.line fail bouncer profile $+($qt(%v)) has a protected token that cannot be unlocked here - enter it again in /neon bnc
      elseif ($ns.srv.get(%id,ssl,0) != 1) ns.st.line warn bouncer profile $+($qt(%v)) does not use TLS
      else ns.st.line ok bouncer profile $+($qt(%v))
    }
    else ns.st.line ok profile $+($qt(%v))
  }

  ns.st.head Secrets
  if (!$exists($ns.sec.dll)) ns.st.line warn neonsec.dll is not installed - passwords and tokens stay plain text in profiles.ini (optional helper)
  elseif (!$ns.sec.ready) ns.st.line fail neonsec.dll does not match data\neonsec.sha256 - it is not used (modified or a different build?)
  else {
    ns.st.line ok neonsec.dll verified (SHA-256 matches the published build)
    %v = $dll($ns.sec.dll,Protect,neon-selftest-secret)
    if ($left(%v,6) == dpapi:) && ($dll($ns.sec.dll,Unprotect,%v) == neon-selftest-secret) ns.st.line ok protect/unprotect round trip works
    else ns.st.line fail protect/unprotect round trip failed ( $+ %v $+ )
  }
  if ($ns.sec.count(plain) > 0) {
    if ($ns.sec.on) ns.st.line warn $ns.sec.count(plain) stored secret(s) are still plain text - run /neon secure on
    else ns.st.line warn $ns.sec.count(plain) stored secret(s) are plain text in profiles.ini
  }
  else ns.st.line ok no plain-text secrets stored ( $+ $ns.sec.count(protected) protected)

  ns.st.head Result
  var %ok = $hget(ns.st,ok), %warn = $hget(ns.st,warn), %fail = $hget(ns.st,fail)
  echo -c info %w $chr(160)
  echo -c info %w $+($iif(%fail,$ns.ec(kick),$ns.ec(join)),$chr(2),%ok passed,$chr(44) %warn warning(s),$chr(44) %fail failed,$chr(2),$ns.o)
  if (%fail) echo -c info %w $+($ns.ec(dim),Try /neon repair - it reloads missing modules and re-creates missing data files.,$ns.o)
  ns.set system lasttest $asctime($ctime,yyyy-mm-dd HH:nn) - %ok ok $+ $chr(44) %warn warn $+ $chr(44) %fail fail
  ns.log test finished: %ok ok, %warn warn, %fail fail
  if ($dialog(ns_dbg)) ns.dbg.fill
}

; ---------------------------------------------------------------- backup / restore
; A backup is one ZIP of your settings.  Saved passwords and tokens are NEVER written into it.
alias ns.bak.secrets return pass srvpass bnctoken
; files that make up "your settings" (paths relative to the script folder)
alias ns.bak.files {
  var %o = neon.ini profiles.ini custom.ini access.ini chan.ini data\topics.txt, %i, %n
  %n = $findfile($ns.data(),msg_*.txt,0,1)
  %i = 1
  while (%i <= %n) {
    %o = %o data\ $+ $nopath($findfile($ns.data(),msg_*.txt,%i,1))
    inc %i
  }
  %n = $findfile($ns.data(),cbmenu_*.txt,0,1)
  %i = 1
  while (%i <= %n) {
    %o = %o data\ $+ $nopath($findfile($ns.data(),cbmenu_*.txt,%i,1))
    inc %i
  }
  %n = $findfile($ns.data(mts\),*.mts,0,1)
  %i = 1
  while (%i <= %n) {
    %o = %o data\mts\ $+ $nopath($findfile($ns.data(mts\),*.mts,%i,1))
    inc %i
  }
  return %o
}
; mIRC caches ini writes in memory: push them to disk before files are copied or zipped
alias ns.flushall {
  flushini $ns.ini
  flushini $ns.profini
  flushini $ns.cb.ini
  flushini $+($scriptdir,access.ini)
  flushini $+($scriptdir,chan.ini)
}
; ns.bak.export [tag] [zipfile]  ->  path of the zip (empty on failure)
alias ns.bak.export {
  var %tag = $iif($1,$1,manual), %zip = $iif($2,$2,$+($ns.bakdir,neonscript-,$asctime($ctime,yyyymmdd-HHnnss),-,%tag,.zip))
  var %st = $+($ns.bakdir,_stage\), %root = $+(%st,neonscript-backup\), %list = $ns.bak.files, %i = 1, %rel, %src, %dst, %made = 0, %sec, %j, %s
  ns.flushall
  .mkdir $qt($ns.bakdir)
  .mkdir $qt(%st)
  .mkdir $qt(%root)
  .mkdir $qt($+(%root,data))
  .mkdir $qt($+(%root,data\mts))
  while ($gettok(%list,%i,32) != $null) {
    %rel = $gettok(%list,%i,32)
    inc %i
    %src = $+($scriptdir,%rel)
    %dst = $+(%root,%rel)
    if (!$exists(%src)) continue
    .copy -o $qt(%src) $qt(%dst)
    inc %made
    if (%rel == profiles.ini) {
      ns.bak.strip %dst
      flushini %dst
    }
  }
  writeini -n $qt($+(%root,manifest.ini)) manifest version $ns.ver
  writeini -n $qt($+(%root,manifest.ini)) manifest schema $ns.get(general,schema,$ns.schema)
  writeini -n $qt($+(%root,manifest.ini)) manifest created $asctime($ctime,yyyy-mm-dd HH:nn)
  writeini -n $qt($+(%root,manifest.ini)) manifest files %made
  writeini -n $qt($+(%root,manifest.ini)) manifest secrets 0
  flushini $+(%root,manifest.ini)
  if ($exists(%zip)) .remove $qt(%zip)
  var %ok = $zip(%zip,c,$+($ns.bakdir,_stage\neonscript-backup))
  ns.bak.clean %list
  if (!%ok) || (!$exists(%zip)) {
    ns.log bak export failed
    return $null
  }
  ns.log bak exported %made files to $nopath(%zip)
  return %zip
}
; blank every password / token in a staged copy of profiles.ini
alias -l ns.bak.strip {
  var %f = $1, %i = 1, %sec, %k, %item
  while ($ini(%f,%i) != $null) {
    %sec = $ini(%f,%i)
    inc %i
    %k = 1
    while ($gettok($ns.bak.secrets,%k,32) != $null) {
      %item = $gettok($ns.bak.secrets,%k,32)
      inc %k
      if ($readini(%f,n,%sec,%item) != $null) remini $qt(%f) %sec %item
    }
  }
}
alias -l ns.rmdir {
  if ($isdir($1)) .rmdir $qt($1)
}
alias -l ns.bak.clean {
  var %st = $+($ns.bakdir,_stage\), %root = $+(%st,neonscript-backup\), %i = 1, %f
  while ($gettok($1-,%i,32) != $null) {
    %f = $+(%root,$gettok($1-,%i,32))
    inc %i
    if ($exists(%f)) .remove $qt(%f)
  }
  if ($exists($+(%root,manifest.ini))) .remove $qt($+(%root,manifest.ini))
  ns.rmdir $+(%root,data\mts)
  ns.rmdir $+(%root,data)
  ns.rmdir %root
  ns.rmdir %st
}
; a safety copy before something risky (upgrade, import, repair); keeps the newest 10
alias ns.bak.auto {
  var %z = $ns.bak.export($iif($1,$1,auto)), %n, %i
  %n = $findfile($ns.bakdir,*-auto*.zip;*-before*.zip,0,1)
  %i = 1
  while (%n > 10) {
    .remove $qt($findfile($ns.bakdir,*-auto*.zip;*-before*.zip,1,1))
    dec %n
  }
  return %z
}

; ns.bak.check <zipfile> -> "" when it looks like a NeonScript backup, otherwise the reason it does not
alias ns.bak.check {
  var %z = $1, %n, %i = 1, %e, %manifest = 0, %bad
  if (!$exists(%z)) return the file does not exist
  if ($zip(%z,t) != 1) return the file is not a readable ZIP (or it is damaged)
  %n = $zip(%z,l,0)
  if (!%n) return the ZIP is empty
  while (%i <= %n) {
    %e = $zip(%z,l,%i)
    inc %i
    if (!$regex(%e,/^neonscript-backup\\/i)) return it is not a NeonScript backup (unexpected entry $qt(%e) $+ )
    if ($pos(%e,..)) || ($pos(%e,:)) || ($pos(%e,/)) return the backup contains an unsafe path ( $+ %e $+ )
    if ($right(%e,1) == $chr(92)) continue
    if (%e == neonscript-backup\manifest.ini) { %manifest = 1 | continue }
    if (!$ns.bak.allowed($mid(%e,19))) return the backup contains a file NeonScript does not use ( $+ %e $+ )
  }
  if (!%manifest) return it has no manifest - it was not made by /neon export
  return $null
}
; only the settings files /neon export writes may be restored
alias ns.bak.allowed {
  var %r = $1
  if ($istok(neon.ini profiles.ini custom.ini access.ini chan.ini data\topics.txt,%r,32)) return 1
  if ($regex(%r,/^data\\msg_[a-z]+\.txt$/i)) return 1
  if ($regex(%r,/^data\\cbmenu_[a-z0-9]+\.txt$/i)) return 1
  if ($regex(%r,/^data\\mts\\[a-z0-9 _.\-]+\.mts$/i)) return 1
  return 0
}
; ns.bak.import <zipfile> - restore settings from a backup (the caller has already confirmed)
alias ns.bak.import {
  var %z = $1, %why = $ns.bak.check(%z)
  if (%why) {
    ns.err cannot restore: %why
    return 0
  }
  ns.bak.auto before-restore
  ns.flushall
  var %st = $+($ns.bakdir,_import\), %root = $+(%st,neonscript-backup\), %n = $zip(%z,l,0), %i = 1, %e, %rel, %kept = $ns.bak.holdsecrets, %made = 0
  .mkdir $qt($ns.bakdir)
  .mkdir $qt(%st)
  if (!$zip(%z,eo,%st)) {
    ns.err cannot restore: the backup could not be unpacked
    ns.bak.cleanimport
    return 0
  }
  while (%i <= %n) {
    %e = $zip(%z,l,%i)
    inc %i
    if ($right(%e,1) == $chr(92)) || (%e == neonscript-backup\manifest.ini) continue
    %rel = $mid(%e,19)
    if (!$exists($+(%st,%e))) continue
    .copy -o $qt($+(%st,%e)) $qt($+($scriptdir,%rel))
    inc %made
  }
  ns.bak.restoresecrets %kept
  ns.bak.cleanimport
  ns.log bak restored %made files from $nopath(%z)
  return %made
}
; passwords/tokens are not in a backup, so remember the current ones and put them back after the restore
alias -l ns.bak.holdsecrets {
  var %i = 1, %sec, %k, %o, %v, %item
  while ($ini($ns.profini,%i) != $null) {
    %sec = $ini($ns.profini,%i)
    inc %i
    %k = 1
    while ($gettok($ns.bak.secrets,%k,32) != $null) {
      %item = $gettok($ns.bak.secrets,%k,32)
      inc %k
      %v = $readini($ns.profini,n,%sec,%item)
      if (%v != $null) hadd -mu120 ns.bakkeep $+(%sec,.,%item) %v
    }
  }
  return 1
}
alias -l ns.bak.restoresecrets {
  var %i = 1, %sec, %k, %item, %v
  while ($ini($ns.profini,%i) != $null) {
    %sec = $ini($ns.profini,%i)
    inc %i
    %k = 1
    while ($gettok($ns.bak.secrets,%k,32) != $null) {
      %item = $gettok($ns.bak.secrets,%k,32)
      inc %k
      %v = $hget(ns.bakkeep,$+(%sec,.,%item))
      if ($readini($ns.profini,n,%sec,%item) == $null) && (%v != $null) writeini -n $qt($ns.profini) %sec %item %v
    }
  }
  if ($hget(ns.bakkeep)) hfree ns.bakkeep
}
alias -l ns.bak.cleanimport {
  var %st = $+($ns.bakdir,_import\), %root = $+(%st,neonscript-backup\), %i = 1
  var %n = $findfile(%root,*.*,0), %f
  while (%n > 0) {
    %f = $findfile(%root,*.*,1)
    if (%f == $null) break
    .remove $qt(%f)
    dec %n
  }
  ns.rmdir $+(%root,data\mts)
  ns.rmdir $+(%root,data)
  ns.rmdir %root
  ns.rmdir %st
}

; /neon export  - save a backup now   /neon import [file]  - restore one   /neon backup - the dialog
alias neon.export {
  var %z = $ns.bak.export(manual)
  if (!%z) { ns.err the backup could not be created. }
  else ns.say backup saved: $qt(%z) $+ $chr(32) $+ ( $+ $bytes($file(%z).size,b) $+ ) - no passwords or tokens are included.
  if ($dialog(ns_bak)) ns.bak.fill
}
alias neon.import {
  var %z = $1-
  if (!%z) %z = $sfile($+($ns.bakdir,*.zip),Choose a NeonScript backup,Restore)
  if (!%z) return
  var %why = $ns.bak.check(%z)
  if (%why) { ns.err cannot restore: %why | return }
  if (!$input(Restore your NeonScript settings from $nopath(%z) $+ ? $+ $crlf $+ $crlf $+ Your current settings are saved first, and your saved passwords and tokens are kept.,yq,Restore backup)) return
  var %n = $ns.bak.import(%z)
  if (!%n) return
  ns.say restored %n files. Reloading...
  .timer -o 1 1 neon reload
  if ($dialog(ns_bak)) ns.bak.fill
}
alias neon.backup ns.dlg ns_bak ns_bak
dialog ns_bak {
  title "Backup & restore"
  size -1 -1 300 188
  option dbu
  icon 1, 0 0 300 30, $mircexe, 0, noborder
  text "Backups are ZIP files of your NeonScript settings, themes and custom buttons. Saved passwords and tokens are never included.", 2, 6 36 288 18
  list 3, 6 56 288 80, size vsbar
  text "", 4, 6 140 288 9
  button "Back up now", 5, 6 154 60 13
  button "Restore file...", 6, 70 154 60 13
  button "Restore selected", 7, 134 154 66 13
  button "Delete selected", 8, 204 154 66 13
  button "Close", 9, 246 170 48 13, ok cancel
}
on *:DIALOG:ns_bak:init:*:{
  did -g ns_bak 1 $ns.asset(header_backup.png)
  ns.bak.fill
}
alias ns.bak.fill {
  if (!$dialog(ns_bak)) return
  var %n = $findfile($ns.bakdir,neonscript-*.zip,0,1), %i = 1, %f
  did -r ns_bak 3
  hfree -w ns.bakls*
  while (%i <= %n) {
    %f = $findfile($ns.bakdir,neonscript-*.zip,%i,1)
    hadd -m ns.bakls %i %f
    did -a ns_bak 3 $nopath(%f) $+ $chr(32) $+ $chr(32) $+ $chr(40) $+ $bytes($file(%f).size,b) $+ $chr(41)
    inc %i
  }
  did -ra ns_bak 4 %n backup(s) in the backup folder
}
on *:DIALOG:ns_bak:sclick:5:{ neon export }
on *:DIALOG:ns_bak:sclick:6:{ ns.later neon import }
on *:DIALOG:ns_bak:sclick:7:{
  var %f = $hget(ns.bakls,$did(ns_bak,3).sel)
  if (!%f) return
  ns.later neon import %f
}
on *:DIALOG:ns_bak:sclick:8:{
  var %f = $hget(ns.bakls,$did(ns_bak,3).sel)
  if (!%f) return
  ns.later ns.bak.delete %f
}
alias ns.bak.delete {
  if ($nofile($1) != $ns.bakdir) return
  if (!$input(Delete $nopath($1) $+ ?,yq,Delete backup)) return
  .remove -b $qt($1)
  ns.bak.fill
}

; ---------------------------------------------------------------- repair
; /neon repair          reload missing modules, re-create missing data files, rebuild the toolbar, then self-test
; /neon repair stock    put mIRC's original colours / toolbar / aliases back (keeps NeonScript installed)
alias neon.repair {
  if ($1 == stock) {
    if (!$input(Put mIRC's original colours, toolbar and stock aliases back? $+ $crlf $+ NeonScript stays installed - /neon themes brings the look back.,yq,Restore the original look)) return
    ns.stock.restore
    return
  }
  ns.say repairing...
  ns.bak.auto before-repair
  ns.loadall
  var %i = 1, %f, %restored, %lab
  while ($gettok(quit part kick slap away,%i,32) != $null) {
    %lab = $gettok(quit part kick slap away,%i,32)
    inc %i
    %f = $ns.msg.file(%lab)
    if (!$exists(%f)) && ($exists($ns.data($+(defaults\msg_,%lab,.txt)))) {
      .copy $qt($ns.data($+(defaults\msg_,%lab,.txt))) $qt(%f)
      %restored = %restored msg_ $+ %lab $+ .txt
    }
  }
  if (%restored) ns.say re-created: $ns.trim(%restored)
  if ($hget(ns.stage)) hfree ns.stage
  if ($ns.get(general,schema,0) != $ns.schema) ns.migrate
  if ($ns.flag(toolbar,enabled,1)) ns.tb.build
  ns.theme.apply $ns.theme.current
  ns.say done - running the self-test.
  neon selftest
}

; ---------------------------------------------------------------- update check
; The feed is a small text file (ini format) you host with your releases:
;   [latest]
;   version=2026.3.0
;   released=2026-11-01
;   url=https://example.org/neonscript/releases
;   notes=What is new in one line
; Nothing is downloaded or installed automatically - you only get told, with a link.
alias ns.update.url return $ns.get(update,url)
alias neon.update {
  if ($1 == url) {
    if ($2 == $null) { ns.say update feed address: $iif($ns.update.url != $null,$ns.update.url,not set) | return }
    if ($left($2,8) != https://) { ns.err the update address must start with https:// | return }
    ns.set update url $2
    ns.say update feed address saved.
    return
  }
  if ($1 == auto) {
    ns.set update auto $iif($2 == on,1,0)
    ns.say checking for updates at start-up: $iif($ns.flag(update,auto,0),on,off)
    return
  }
  ns.update.check manual
}
alias ns.update.check {
  var %u = $ns.update.url, %f = $ns.data(latest.tmp)
  if (!%u) {
    if ($1 == manual) ns.say no update feed is set. Use $+($ns.cc(11),/neon update url https://...,$ns.o) when you have one.
    return
  }
  if ($exists(%f)) .remove $qt(%f)
  set -u60 %ns.upd.mode $1
  if ($1 == manual) ns.say checking for updates...
  if (!$urlget(%u,gf,%f,ns.update.done)) ns.err could not start the update check.
}
alias ns.update.done {
  var %f = $urlget($1).target, %code = $gettok($urlget($1).reply,1,32), %v, %when, %url, %notes
  if (%code == HTTP/1.0) || (%code == HTTP/1.1) || (%code == HTTP/2) %code = $gettok($urlget($1).reply,2,32)
  if (%code != 200) && (%code != $null) {
    if (%ns.upd.mode == manual) ns.err the update feed replied %code
    return
  }
  if (!$exists(%f)) {
    if (%ns.upd.mode == manual) ns.err no answer from the update feed.
    return
  }
  %v = $readini(%f,n,latest,version)
  %when = $readini(%f,n,latest,released)
  %url = $readini(%f,n,latest,url)
  %notes = $readini(%f,n,latest,notes)
  .remove $qt(%f)
  if (%v == $null) {
    if (%ns.upd.mode == manual) ns.err the update feed is not in the expected format.
    return
  }
  ns.set update lastcheck $ctime
  if ($ns.vercmp(%v,$ns.ver) > 0) {
    ns.say $+($ns.ec(join),$chr(2),NeonScript %v is available,$chr(2),$ns.o) (you have $ns.ver $+ ) $iif(%when,- released %when)
    if (%notes) ns.say what is new: %notes
    if (%url) ns.say get it here: %url
  }
  elseif (%ns.upd.mode == manual) ns.say you have the latest version ( $+ $ns.ver $+ ).
}
